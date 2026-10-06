#!/usr/bin/env python3
"""List-vs-profile exploration runner (docs/evaluation/profile-exploration.md, plan v4).

  python3 scripts/run_profile_exploration.py --dry-run          # build requests, no network
  python3 scripts/run_profile_exploration.py --limit 4          # S1 on both arms, check usage
  python3 scripts/run_profile_exploration.py                    # the remaining base calls
  python3 scripts/run_profile_exploration.py --cases S1,S4 --rep 2   # repeat for split cases
  python3 scripts/run_profile_exploration.py --sheet            # blind review sheet for the base run
  python3 scripts/run_profile_exploration.py --sheet --rep 2    # separate sheet for a repeat

Calls already in the log are skipped, so a run can be resumed. No automatic retry:
a failure is logged as it is and the run stops, because a failed call reports no
usage and may still have been billed. Check the Console usage before resuming.
"""
import argparse
import hashlib
import json
import random
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXP = ROOT / "data" / "exploration"
LOG = EXP / "runs" / "responses.jsonl"

MODEL = "claude-haiku-4-5"
MAX_TOKENS = 1024
MAX_CALLS = 72  # plan: 24 base + up to 48 repeats
# USD per 1M tokens, platform.claude.com/docs/en/about-claude/pricing, checked 2026-10-06.
PRICE_IN, PRICE_OUT = 1.00, 5.00

SYSTEM = """You help a traveller choose among a fixed list of destinations for a travel app.

Rules:
- Recommend only destinations from the allowed list, by their exact id.
- Respect every condition the user states. If no destination fits, return fewer or none.
- Never assert prices, opening hours, booking requirements or availability, conditions on a particular day, or safety. Say what must be checked instead. General seasonal patterns may be described as general patterns.
- Do not output links.
- Write the sentences in the user's language. One fact per sentence.
- Reply with a single JSON object only, no markdown fence and no other text."""

TASKS = {
    "recommend": (
        "Recommend at most 2 destinations for this user.\n"
        'JSON shape: {"candidates": [{"id": "<allowed id>", "facts": ["<sentence>", "<sentence>"], '
        '"caveat": "<sentence>"}]}\n'
        "facts: at most 2 sentences about the destination that support the recommendation "
        "and connect to what the user said. caveat: exactly 1 sentence the user should know or check."
    ),
    "detail": (
        "Answer the user's follow-up question.\n"
        'JSON shape: {"answer": ["<sentence>", "<sentence>"], "limits": "<sentence>"}\n'
        "answer: at most 2 sentences that answer directly. limits: exactly 1 sentence on what "
        "is unconfirmed or must be checked."
    ),
}


def load_inputs():
    cand = json.loads((ROOT / "data/planning/destination-candidates.json").read_text())
    pilots = [c for c in cand["candidates"] if c.get("pilot")]
    cities = [
        {"id": c.get("recommendation_destination_id") or c["id"], "name": c["name_ko"], "country": c["country_code"]}
        for c in pilots
    ]
    profiles = json.loads((EXP / "profiles.json").read_text())
    cases = json.loads((EXP / "cases.json").read_text())["cases"]
    ids = [c["id"] for c in cities]
    assert len(ids) == 20 and len(set(ids)) == 20, "expected 20 distinct pilot destinations"
    assert list(profiles) == ids, "profiles.json keys must match the candidate ids in order"
    assert len(cases) == 6
    return cities, profiles, cases


def build_user(arm, task, case, cities, profiles):
    lines = ["Allowed destinations (id | name | country):"]
    lines += [f"{c['id']} | {c['name']} | {c['country']}" for c in cities]
    if arm == "B":
        lines += ["", "Destination profiles (drafts; a missing item means not recorded, not absent):",
                  json.dumps(profiles, ensure_ascii=False)]
    lines += ["", "User:", case["user"]]
    if task == "detail":
        lines += ["", "Follow-up question:", case["detail"]]
    lines += ["", TASKS[task]]
    return "\n".join(lines)


def plan(cases, only, rep):
    """Per case alternate A/B and B/A; both tasks per arm."""
    out = []
    for i, case in enumerate(cases):
        if only and case["id"] not in only:
            continue
        for arm in ("AB" if i % 2 == 0 else "BA"):
            for task in ("recommend", "detail"):
                out.append((case, arm, task, rep))
    return out


def key(case, arm, task, rep):
    return f"{case['id']}-{arm}-{task}-r{rep}"


def read_log():
    if not LOG.exists():
        return []
    return [json.loads(line) for line in LOG.read_text().splitlines() if line.strip()]


def cost(rows):
    return sum(r.get("input_tokens", 0) * PRICE_IN + r.get("output_tokens", 0) * PRICE_OUT for r in rows) / 1e6


def _sentence(value, problems, name):
    """One non-empty sentence, no link. The sentence count is a punctuation heuristic."""
    if not isinstance(value, str) or not value.strip():
        problems.append(f"{name}_not_text")
        return
    if "http" in value or "www." in value:
        problems.append(f"{name}_link")
    if len(re.findall(r"[.!?。](?=\s|$)", value.strip())) > 1:
        problems.append(f"{name}_maybe_multi_sentence")


def check_output(task, text, allowed):
    """Format check only. Returns (parsed or None, list of problems)."""
    problems = []
    text = text.strip()
    if text.startswith("```"):  # still readable, but logged as a format violation
        problems.append("markdown_fence")
        text = text.strip("`").removeprefix("json").strip()
    try:
        data = json.loads(text)
    except ValueError:
        return None, problems + ["not_json"]
    if not isinstance(data, dict):
        return data, problems + ["not_object"]
    if task == "recommend":
        cands = data.get("candidates")
        if not isinstance(cands, list):
            return data, problems + ["no_candidates_list"]
        if len(cands) > 2:
            problems.append("more_than_2_candidates")
        for c in cands:
            if not isinstance(c, dict):
                problems.append("candidate_not_object")
                continue
            if c.get("id") not in allowed:
                problems.append(f"id_not_allowed:{c.get('id')}")
            facts = c.get("facts")
            if not isinstance(facts, list) or not 1 <= len(facts) <= 2:
                problems.append("facts_count")
            for f in facts if isinstance(facts, list) else []:
                _sentence(f, problems, "fact")
            _sentence(c.get("caveat"), problems, "caveat")
    else:
        answer = data.get("answer")
        if not isinstance(answer, list) or not 1 <= len(answer) <= 2:
            problems.append("answer_count")
        for a in answer if isinstance(answer, list) else []:
            _sentence(a, problems, "answer")
        _sentence(data.get("limits"), problems, "limits")
    return data, problems


def run(args):
    cities, profiles, cases = load_inputs()
    allowed = {c["id"] for c in cities}
    inputs_hash = hashlib.sha256(
        json.dumps([MODEL, MAX_TOKENS, cities, profiles, cases, SYSTEM, TASKS], ensure_ascii=False, sort_keys=True).encode()
    ).hexdigest()[:16]
    logged = read_log()
    stale = {r["inputs_hash"] for r in logged} - {inputs_hash}
    if stale:
        sys.exit(f"stopped: {LOG} holds calls made with different inputs ({', '.join(sorted(stale))}; now {inputs_hash}). "
                 "Move that log aside to start a new run; do not mix them.")
    todo = plan(cases, set(args.cases.split(",")) if args.cases else None, args.rep)
    done = {r["key"] for r in logged}
    todo = [t for t in todo if key(*t) not in done]
    if args.limit:
        todo = todo[: args.limit]
    if len(done) + len(todo) > MAX_CALLS:
        sys.exit(f"stopped: {len(done)} logged + {len(todo)} pending exceeds the plan's {MAX_CALLS}-call limit")

    if args.dry_run:
        a = build_user("A", "recommend", cases[0], cities, profiles)
        b = build_user("B", "recommend", cases[0], cities, profiles)
        assert a.split("\n\n")[0] == b.split("\n\n")[0], "A and B must share the same destination list"
        print(f"model {MODEL}, inputs {inputs_hash}, {len(todo)} call(s) pending, {len(done)} already logged")
        print(f"request size (chars): system {len(SYSTEM)}, A {len(a)}, B {len(b)}")
        print("order:", " ".join(key(*t) for t in todo))
        return

    import anthropic

    client = anthropic.Anthropic(max_retries=0)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    for case, arm, task, rep in todo:
        user = build_user(arm, task, case, cities, profiles)
        # Upper bound for the next call: 2 tokens per character in, a full max_tokens out.
        worst = ((len(SYSTEM) + len(user)) * 2 * PRICE_IN + MAX_TOKENS * PRICE_OUT) / 1e6
        spent = cost(read_log())
        if spent + worst > args.max_usd:
            sys.exit(f"stopped: spent ${spent:.4f}, next call could add ${worst:.4f}, over --max-usd {args.max_usd}")
        row = {"key": key(case, arm, task, rep), "case": case["id"], "arm": arm, "task": task, "rep": rep,
               "model": MODEL, "inputs_hash": inputs_hash, "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
        start = time.monotonic()
        try:
            resp = client.messages.create(
                model=MODEL, max_tokens=MAX_TOKENS, system=SYSTEM, messages=[{"role": "user", "content": user}],
            )
            # Raw text and usage go into the row before any checking, so a bad reply is never lost.
            row.update(text="".join(b.text for b in resp.content if b.type == "text"), stop_reason=resp.stop_reason,
                       input_tokens=resp.usage.input_tokens, output_tokens=resp.usage.output_tokens)
            try:
                row["parsed"], row["format_problems"] = check_output(task, row["text"], allowed)
            except Exception as e:  # a checker bug must not cost us the paid response
                row["parsed"], row["format_problems"] = None, [f"check_crashed:{type(e).__name__}"]
        except anthropic.APIError as e:
            row["error"] = f"{type(e).__name__}: {e}"
        row["latency_s"] = round(time.monotonic() - start, 2)
        with LOG.open("a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        if "error" in row:
            sys.exit(f"stopped at {row['key']}: {row['error']}\nThe failure is logged and will not be retried. "
                     "Its cost is unknown to this script: check the Console usage and lower --max-usd by that amount when resuming.")
        print(row["key"], f"in {row['input_tokens']} out {row['output_tokens']} "
              f"{row['latency_s']}s {row['format_problems'] or 'ok'}")
    rows = read_log()
    print(f"logged {len(rows)} call(s), total ${cost(rows):.4f}")


def sheet(rep):
    """Shuffled responses with the arm hidden; the key goes to a separate file.
    One sheet per repeat number, never overwritten: it holds the reviewer's verdicts."""
    md, keyfile = EXP / "runs" / f"review-r{rep}.md", EXP / "runs" / f"review-key-r{rep}.json"
    if md.exists() or keyfile.exists():
        sys.exit(f"stopped: {md.name} already exists and may hold review notes. Move it aside to regenerate.")
    rows = [r for r in read_log() if r["rep"] == rep]
    if not rows:
        sys.exit(f"no logged calls with rep {rep}")
    if rep == 0 and len(rows) < 24:  # the sheet cannot be extended later
        sys.exit(f"stopped: only {len(rows)} of 24 base calls are logged. Finish the base run first.")
    cases = {c["id"]: c for c in json.loads((EXP / "cases.json").read_text())["cases"]}
    random.Random(20261006).shuffle(rows)
    rows.sort(key=lambda r: (r["case"], r["task"]))  # keeps the shuffled A/B order within each group
    out, keymap = ["# 응답 검수 시트 (방식 가림)", ""], {}
    for n, r in enumerate(rows, 1):
        rid = f"R{n:02d}"
        keymap[rid] = r["key"]
        c = cases[r["case"]]
        out += [f"## {rid} — {r['case']} {r['task']}", "", f"사용자: {c['user']}"]
        if r["task"] == "detail":
            out.append(f"질문: {c['detail']}")
        body = json.dumps(r["parsed"], ensure_ascii=False, indent=2) if r.get("parsed") else r.get("error") or r.get("text")
        out += ["", "```", str(body), "```", "",
                "- 문장별 사실 판정(맞음/틀림/확인 불가)과 출처:", "- 근거 없는 단정·보장(사실 여부와 별개):",
                "- 제약 쟁점(충족/위반/판단 불가):", "- 유의점 누락:", ""]
    md.write_text("\n".join(out))
    keyfile.write_text(json.dumps(keymap, indent=2))
    print(f"wrote {md.name} ({len(rows)} responses) and {keyfile.name}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--sheet", action="store_true")
    p.add_argument("--limit", type=int, default=0)
    p.add_argument("--cases", default="")
    p.add_argument("--rep", type=int, default=0, choices=[0, 1, 2])
    p.add_argument("--max-usd", type=float, default=3.0)  # worst case for all 72 calls is about $2.4
    a = p.parse_args()
    sheet(a.rep) if a.sheet else run(a)
