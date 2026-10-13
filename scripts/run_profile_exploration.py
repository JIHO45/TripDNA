#!/usr/bin/env python3
"""List-vs-profile exploration runner (docs/evaluation/profile-exploration.md, plan v4).

  python3 scripts/run_profile_exploration.py --dry-run          # build requests, no network
  python3 scripts/run_profile_exploration.py --limit 4          # S1 on both arms, check usage
  python3 scripts/run_profile_exploration.py                    # the remaining base calls
  python3 scripts/run_profile_exploration.py --cases S1,S4 --rep 2   # repeat for split cases
  python3 scripts/run_profile_exploration.py --sheet            # blind review sheet for the base run
  python3 scripts/run_profile_exploration.py --sheet --rep 2    # separate sheet for a repeat
  python3 scripts/run_profile_exploration.py --run 2 --dry-run  # second run: list vs constraints-only notes
  python3 scripts/run_profile_exploration.py --run 3 --dry-run  # third run: three system prompts, cases N1-N6
  python3 scripts/run_profile_exploration.py --run 4 --dry-run  # fourth run: same prompts, cases C1-C6
  python3 scripts/run_profile_exploration.py --run 5 --dry-run  # fifth run: web search, notes, Sonnet; cases R1-R12
  python3 scripts/run_profile_exploration.py --run 5 --cases R5 # one case on all four arms, to measure cost first
  python3 scripts/run_profile_exploration.py --run 5 --cases R9 --arms HS,HSC --rep 1  # repeat a split pair
  python3 scripts/run_profile_exploration.py --run 6 --dry-run  # sixth run: Gemini only, the run-5 design on Flash and Pro

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
# Run 1: list (A) vs full profile (B). Run 2: list (A) vs scope + constraints only (C, "B-prime" in the plan).
# Run 3: three system prompts on the list-only input with development cases N1-N6
# (docs/evaluation/guideline-comparison.md). G0 is the run 1-2 prompt; its task text gains `note`.
RUNS = {
    1: dict(arms=("A", "B"), profiles="profiles.json", dir="runs"),
    2: dict(arms=("A", "C"), profiles="profiles-constraints.json", dir="runs2"),
    3: dict(arms=("G0", "G1", "G2"), profiles=None, dir="runs3", cases="cases-n.json", note=True,
            guidelines={"G1": "guidelines/g1-claude.md", "G2": "guidelines/g2-codex.md"}),
    # Run 4: the same three prompts, unchanged, on confirmation cases C1-C6.
    4: dict(arms=("G0", "G1", "G2"), profiles=None, dir="runs4", cases="cases-c.json", note=True,
            guidelines={"G1": "guidelines/g1-claude.md", "G2": "guidelines/g2-codex.md"}),
    # Run 5 (docs/evaluation/run5-plan.md): list only vs web search vs web search + notes vs Sonnet with web search.
    5: dict(arms=("H0", "HS", "HSC", "SS"), profiles="profiles-constraints.json", dir="runs5", cases="cases-r5.json",
            note=True, n_cases=12, max_tokens=4096, max_calls=160, agents="guidelines/r5-agents.md", arm_cfg="R5_ARMS"),
    # Run 6 (docs/evaluation/run6-plan.md): Gemini only. Flash with search, Flash with search + notes, Pro with search.
    6: dict(arms=("FS", "FSC", "PS"), profiles="profiles-constraints.json", dir="runs6", cases="cases-r5.json",
            note=True, n_cases=12, max_tokens=4096, max_calls=120, agents="guidelines/r6-agents.md", arm_cfg="R6_ARMS"),
}
HAIKU, SONNET = "claude-haiku-4-5", "claude-sonnet-5-5"
FLASH, PRO = "gemini-3.8-flash", "gemini-3.1-pro-preview"
# Run 5 arms. `system` and `notes` name blocks in the agents file; `search` is the web search tool type.
R5_ARMS = {
    "H0": dict(model=HAIKU, system="list"),
    "HS": dict(model=HAIKU, system="search", search="web_search_20250305"),
    "HSC": dict(model=HAIKU, system="search", search="web_search_20250305", notes="constraints-header"),
    "SS": dict(model=SONNET, system="search", search="web_search_20260209",
               extra=dict(thinking={"type": "adaptive"}, output_config={"effort": "medium"})),
}
# Gemini takes no cap on searches; its thinking cannot be switched off, so both models run at their lowest level.
_GEMINI = dict(system="search2", search="google_search", provider="gemini", thinking_level="low")
R6_ARMS = {
    "FS": dict(model=FLASH, **_GEMINI),
    "FSC": dict(model=FLASH, notes="constraints-header", **_GEMINI),
    "PS": dict(model=PRO, **_GEMINI),
}
MAX_USES = {"recommend": 5, "detail": 3}
SOURCES_TASK = (
    "\nSentences that state a searched fact end with its source number, like [1].\n"
    'sources: [{"n": 1, "title": "<page title>", "url": "<url>", "published": "<YYYY-MM-DD or unknown>"}], '
    "only pages returned by your searches; [] if you searched nothing."
)
ARM_CFG, BLOCKS, N_CASES = {}, {}, 6  # empty for runs 1-4
ARMS, PROFILE_FILE, CASES_FILE, NOTE, SYSTEMS = ("A", "B"), "profiles.json", "cases.json", False, {}
C_HEADER = (
    "Destination notes. `scope` is what the app recommends under each destination id; do not present "
    "out-of-scope places as part of that destination. The notes are not a limit on what you may explain: "
    "answer questions about any place from your own knowledge. Never mention these notes, a profile or a "
    "scope to the user. A missing item means not recorded, not absent."
)

MODEL = HAIKU
MAX_TOKENS = 1024
MAX_CALLS = 72  # plan: 24 base + up to 48 repeats
# USD per 1M tokens, platform.claude.com/docs/en/about-claude/pricing, checked 2026-10-06.
PRICE_IN, PRICE_OUT = 1.00, 5.00
# Run 5. Sonnet price and the web search fee ($10 per 1,000 searches) from the same page, checked 2026-10-07.
# Gemini: ai.google.dev/gemini-api/docs/pricing, checked 2026-10-07. Flash rate is valid to 2026-12-31; output
# includes thinking. Searches are billed per query at $14 per 1,000 after 5,000 free a month; the free quota
# is ignored here so the budget guard errs high.
PRICES = {HAIKU: (PRICE_IN, PRICE_OUT), SONNET: (2.00, 10.00), FLASH: (0.75, 3.75), PRO: (2.00, 12.00)}
SEARCH_USD = 0.01
SEARCH_FEE = {FLASH: 0.014, PRO: 0.014}
# Assumed input tokens one search adds, for the --max-usd guard only. Unmeasured; replace after the first calls.
SEARCH_TOKENS = 15000

SYSTEM = """You help a traveller choose among a fixed list of destinations for a travel app.

Rules:
- Recommend only destinations from the allowed list, by their exact id.
- Respect every condition the user states. If no destination fits, return fewer or none.
- Never assert prices, opening hours, booking requirements or availability, conditions on a particular day, or safety. Say what must be checked instead. General seasonal patterns may be described as general patterns.
- Do not output links.
- Write the sentences in the user's language. One fact per sentence.
- Reply with a single JSON object only, no markdown fence and no other text."""

NOTE_TASK = (
    "Recommend at most 2 destinations for this user.\n"
    'JSON shape: {"candidates": [{"id": "<allowed id>", "facts": ["<sentence>", "<sentence>"], '
    '"caveat": "<sentence>"}], "note": "<sentence>"}\n'
    "facts: at most 2 sentences about the destination that support the recommendation "
    "and connect to what the user said. caveat: exactly 1 sentence the user should know or check. "
    "note: 1 sentence giving the actual reason when fewer than 2 destinations are returned; "
    "otherwise leave it out."
)

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


RECOMMEND_TASK = TASKS["recommend"]


def configure(run):
    """Point the module at one run's arms, inputs, prompts and log."""
    global ARMS, PROFILE_FILE, CASES_FILE, NOTE, SYSTEMS, LOG, ARM_CFG, BLOCKS, MAX_TOKENS, MAX_CALLS, N_CASES
    cfg = RUNS[run]
    N_CASES, MAX_TOKENS, MAX_CALLS = cfg.get("n_cases", 6), cfg.get("max_tokens", 1024), cfg.get("max_calls", 72)
    if "agents" in cfg:  # one file, one fenced block per piece of model-facing text
        ARM_CFG = globals()[cfg["arm_cfg"]]
        BLOCKS = dict(re.findall(r"```text (\S+)\n(.*?)\n```", (EXP / cfg["agents"]).read_text(), re.S))
    ARMS, PROFILE_FILE, NOTE = cfg["arms"], cfg["profiles"], cfg.get("note", False)
    CASES_FILE = cfg.get("cases", "cases.json")
    LOG = EXP / cfg["dir"] / "responses.jsonl"
    # A guideline file holds notes for people above a line of three dashes; the model gets the rest.
    SYSTEMS = {arm: (EXP / f).read_text().split("\n---\n", 1)[1].strip() for arm, f in cfg.get("guidelines", {}).items()}
    SYSTEMS.update({arm: BLOCKS[c["system"]] for arm, c in ARM_CFG.items()})
    TASKS["recommend"] = NOTE_TASK if NOTE else RECOMMEND_TASK


def load_inputs():
    cand = json.loads((ROOT / "data/planning/destination-candidates.json").read_text())
    pilots = [c for c in cand["candidates"] if c.get("pilot")]
    cities = [
        {"id": c.get("recommendation_destination_id") or c["id"], "name": c["name_ko"], "country": c["country_code"]}
        for c in pilots
    ]
    profiles = json.loads((EXP / PROFILE_FILE).read_text()) if PROFILE_FILE else {}
    cases = json.loads((EXP / CASES_FILE).read_text())["cases"]
    ids = [c["id"] for c in cities]
    assert len(ids) == 20 and len(set(ids)) == 20, "expected 20 distinct pilot destinations"
    assert not PROFILE_FILE or list(profiles) == ids, "profile keys must match the candidate ids in order"
    assert len(cases) == N_CASES
    return cities, profiles, cases


def build_user(arm, task, case, cities, profiles):
    cfg = ARM_CFG.get(arm, {})
    # Run 5 gives every arm the call date, which the search rules need to judge how recent a page is.
    lines = [f"Today: {time.strftime('%Y-%m-%d')}", ""] if ARM_CFG else []
    lines += ["Allowed destinations (id | name | country):"]
    lines += [f"{c['id']} | {c['name']} | {c['country']}" for c in cities]
    if arm == "B":
        lines += ["", "Destination profiles (drafts; a missing item means not recorded, not absent):",
                  json.dumps(profiles, ensure_ascii=False)]
    if arm == "C":
        lines += ["", C_HEADER, json.dumps(profiles, ensure_ascii=False)]
    if cfg.get("notes"):
        lines += ["", BLOCKS[cfg["notes"]], json.dumps(profiles, ensure_ascii=False)]
    lines += ["", "User:", case["user"]]
    if task == "detail":
        lines += ["", "Follow-up question:", case["detail"]]
    lines += ["", TASKS[task] + (SOURCES_TASK if cfg.get("search") else "")]
    return "\n".join(lines)


def worst_usd(arm, task, system, user):
    """Upper bound for one call: 2 tokens per character in, a full max_tokens out, every allowed search used."""
    cfg = ARM_CFG.get(arm, {})
    price_in, price_out = PRICES[cfg.get("model", MODEL)]
    searches = MAX_USES[task] if cfg.get("search") else 0
    return (((len(system) + len(user)) * 2 + searches * SEARCH_TOKENS) * price_in + MAX_TOKENS * price_out) / 1e6 \
        + searches * SEARCH_FEE.get(cfg.get("model", MODEL), SEARCH_USD)


def plan(cases, only, rep):
    """Rotate the arm order from case to case (A/B then B/A for two arms); both tasks per arm."""
    out = []
    for i, case in enumerate(cases):
        if only and case["id"] not in only:
            continue
        k = i % len(ARMS)
        for arm in ARMS[k:] + ARMS[:k]:
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
    return sum((r.get("input_tokens", 0) * PRICES[r["model"]][0] + r.get("output_tokens", 0) * PRICES[r["model"]][1]) / 1e6
               + r.get("search_requests", 0) * SEARCH_FEE.get(r["model"], SEARCH_USD) for r in rows)


class GeminiError(Exception):
    pass


def call_gemini(model, system, user, thinking_level, search=True):
    """One Interactions API call over plain HTTP. Returns the fields run() logs; the whole reply is kept as `content`."""
    import os
    import ssl
    import urllib.error
    import urllib.request
    body = {"model": model, "input": user, "system_instruction": system, "store": False,
            **({"tools": [{"type": "google_search"}]} if search else {}),
            "generation_config": {"max_output_tokens": MAX_TOKENS, "thinking_level": thinking_level}}
    req = urllib.request.Request("https://generativelanguage.googleapis.com/v1beta/interactions",
                                 data=json.dumps(body).encode(), method="POST",
                                 headers={"x-goog-api-key": os.environ["GEMINI_API_KEY"], "Content-Type": "application/json"})
    # python.org builds on macOS ship without root certificates; the system bundle is there on every Mac.
    system_ca = "/etc/ssl/cert.pem"
    tls = ssl.create_default_context(cafile=system_ca if os.path.exists(system_ca) else None)
    try:
        with urllib.request.urlopen(req, timeout=180, context=tls) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raise GeminiError(f"HTTP {e.code}: {e.read().decode(errors='replace')[:500]}")
    except (urllib.error.URLError, TimeoutError, ValueError) as e:
        raise GeminiError(f"{type(e).__name__}: {e}")
    steps = data.get("steps") or []
    texts = lambda step: [c for c in step.get("content") or [] if c.get("type") == "text"]
    last_other = max((i for i, st in enumerate(steps) if st.get("type") != "model_output"), default=-1)
    final = "".join(c.get("text", "") for st in steps[last_other + 1:] for c in texts(st))
    queries = [q for st in steps if st.get("type") == "google_search_call" for q in (st.get("arguments") or {}).get("queries") or []]
    # In practice the result step carries only Google's search-suggestion HTML; pages come from the citations below.
    found = [{"url": r.get("url"), "title": r.get("title")} for st in steps if st.get("type") == "google_search_result"
             for r in st.get("result") or [] if isinstance(r, dict) and r.get("url")]
    # Pages the model cited inline also count as retrieved, in case the result step lists fewer than it read.
    found += [{"url": a.get("url"), "title": a.get("title")} for st in steps for c in texts(st)
              for a in c.get("annotations") or [] if a.get("type") == "url_citation"]
    usage = data.get("usage") or {}
    return dict(text="".join(c.get("text", "") for st in steps for c in texts(st)), final_text=final,
                stop_reason=data.get("status"), content=data, usage=usage,
                input_tokens=usage.get("total_input_tokens", 0) + usage.get("total_tool_use_tokens", 0),
                # Thinking is billed at the output rate; count it even if the API reports it separately.
                output_tokens=usage.get("total_output_tokens", 0) + usage.get("total_thought_tokens", 0),
                searches=[{"input": {"queries": queries}, "results": found}], search_requests=len(queries))


def _url(u):
    return str(u).split("#")[0].rstrip("/").lower()


def read_content(content):
    """Split a reply into its final text, all text, the searches made and a copy of the blocks for the log."""
    blocks = [b.model_dump(mode="json") if hasattr(b, "model_dump") else b for b in content]
    last_other = max((i for i, b in enumerate(blocks) if b["type"] != "text"), default=-1)
    final = "".join(b["text"] for b in blocks[last_other + 1:])
    searches, by_id = [], {}
    for b in blocks:
        # Sonnet's tool version searches from inside code execution; those blocks are logged but are not searches.
        if b["type"] == "server_tool_use" and b.get("name") == "web_search":
            searches.append({"input": b.get("input"), "results": []})
            by_id[b.get("id")] = searches[-1]
        elif b["type"] == "web_search_tool_result":
            res = b.get("content")
            # Parallel searches arrive as all calls first, then all results: match by id, not by position.
            entry = by_id.get(b.get("tool_use_id")) or {"input": None, "results": []}
            if isinstance(res, list):  # a list on success, a single error object otherwise
                entry["results"] += [{k: r.get(k) for k in ("url", "title", "page_age")} for r in res if isinstance(r, dict)]
            else:
                entry["error"] = res
            for r in res if isinstance(res, list) else []:
                r.pop("encrypted_content", None)  # large and unreadable; not needed to review the reply
    return final, "".join(b["text"] for b in blocks if b["type"] == "text"), searches, blocks


def _domain(u):
    return re.sub(r"^(https?://)?(www\.)?", "", str(u).lower()).split("/")[0]


def check_sources(data, texts, searches, problems, by_domain=False):
    """Every listed source must be a page a search returned; every [n] marker must have a source.
    Gemini reports what it read only as redirect links titled with the site's domain, so there
    (`by_domain`) a source passes on its domain, and a redirect link it wrote itself is marked unchecked."""
    retrieved = {_url(r["url"]) for s in searches for r in s["results"] if r.get("url")}
    domains = {_domain(r["title"]) for s in searches for r in s["results"] if r.get("title")} if by_domain else set()
    sources = data.get("sources")
    if not isinstance(sources, list):
        problems.append("no_sources_list")
        return
    numbers = set()
    for src in sources:
        if not isinstance(src, dict) or not src.get("url"):
            problems.append("source_not_object")
            continue
        numbers.add(str(src.get("n")))
        if _url(src["url"]) in retrieved or _domain(src["url"]) in domains:
            continue
        if by_domain and "grounding-api-redirect" in src["url"]:
            problems.append(f"source_redirect_unchecked:{src.get('n')}")
        else:
            problems.append(f"source_not_retrieved:{src.get('n')}")
    for n in sorted({n for t in texts if isinstance(t, str) for n in re.findall(r"\[(\d+)\]", t)} - numbers):
        problems.append(f"marker_without_source:{n}")


def _sentence(value, problems, name):
    """One non-empty sentence, no link. The sentence count is a punctuation heuristic."""
    if not isinstance(value, str) or not value.strip():
        problems.append(f"{name}_not_text")
        return
    if not re.search("[가-힣]", value):  # every case is written in Korean
        problems.append(f"{name}_not_korean")
    if "http" in value or "www." in value:
        problems.append(f"{name}_link")
    if "<cite" in value:  # the search tool's citation markup leaking into the sentence
        problems.append(f"{name}_cite_markup")
    if len(re.findall(r"[.!?。](?=\s|$)", value.strip())) > 1:
        problems.append(f"{name}_maybe_multi_sentence")


def check_output(task, text, allowed):
    """Format check only. Returns (parsed or None, list of problems)."""
    problems = []
    text = text.strip()
    fenced = re.search(r"```(?:json)?\s*(\{.*\})\s*```", text, re.S)
    if text.startswith("```"):  # still readable, but logged as a format violation
        problems.append("markdown_fence")
        text = text.strip("`").removeprefix("json").strip()
    elif fenced:  # prose around a fenced object: also readable, also a violation
        problems += ["markdown_fence", "text_outside_json"]
        text = fenced.group(1)
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
        if NOTE and data.get("note") not in (None, ""):
            _sentence(data["note"], problems, "note")
        elif NOTE and len(cands) < 2:
            problems.append("note_missing")
    else:
        answer = data.get("answer")
        if not isinstance(answer, list) or not 1 <= len(answer) <= 2:
            problems.append("answer_count")
        for a in answer if isinstance(answer, list) else []:
            _sentence(a, problems, "answer")
        _sentence(data.get("limits"), problems, "limits")
    return data, problems


def sentences(task, data):
    if task == "recommend":
        cands = [c for c in data.get("candidates") or [] if isinstance(c, dict)]
        return [f for c in cands for f in (c.get("facts") or []) + [c.get("caveat")]] + [data.get("note")]
    return (data.get("answer") or []) + [data.get("limits")]


def run(args):
    cities, profiles, cases = load_inputs()
    allowed = {c["id"] for c in cities}
    inputs_hash = hashlib.sha256(
        json.dumps([MODEL, MAX_TOKENS, cities, profiles, cases, SYSTEM, TASKS] + ([C_HEADER] if "C" in ARMS else [])
                   + [SYSTEMS[a] for a in ARMS if a in SYSTEMS]
                   # Run 5 adds its arm settings and blocks. The call date is left out so a run can span days.
                   + ([ARM_CFG, BLOCKS, MAX_USES, SOURCES_TASK] if ARM_CFG else []),
                   ensure_ascii=False, sort_keys=True).encode()
    ).hexdigest()[:16]
    logged = read_log()
    stale = {r["inputs_hash"] for r in logged} - {inputs_hash}
    if stale:
        sys.exit(f"stopped: {LOG} holds calls made with different inputs ({', '.join(sorted(stale))}; now {inputs_hash}). "
                 "Move that log aside to start a new run; do not mix them.")
    todo = plan(cases, set(args.cases.split(",")) if args.cases else None, args.rep)
    done = {r["key"] for r in logged}
    todo = [t for t in todo if key(*t) not in done and (not args.arms or t[1] in args.arms.split(","))]
    if args.limit:
        todo = todo[: args.limit]
    if len(done) + len(todo) > MAX_CALLS:
        sys.exit(f"stopped: {len(done)} logged + {len(todo)} pending exceeds the plan's {MAX_CALLS}-call limit")

    if args.dry_run:
        users = {arm: build_user(arm, "recommend", cases[0], cities, profiles) for arm in ARMS}
        assert len({u.split("\n\n")[0] for u in users.values()}) == 1, "all arms must share the same destination list"
        models = ", ".join(sorted({c["model"] for c in ARM_CFG.values()})) or MODEL
        print(f"model {models}, inputs {inputs_hash}, {len(todo)} call(s) pending, {len(done)} already logged")
        sizes = ", ".join(f"{arm} system {len(SYSTEMS.get(arm, SYSTEM))} + user {len(u)}" for arm, u in users.items())
        print(f"request size (chars): {sizes}")
        worst = sum(worst_usd(t[1], t[2], SYSTEMS.get(t[1], SYSTEM), build_user(t[1], t[2], t[0], cities, profiles))
                    for t in todo)
        print(f"worst-case cost of pending calls: ${worst:.4f} (2 tokens per character in, full max_tokens out"
              + (f", every search used at an assumed {SEARCH_TOKENS} tokens plus its fee)" if ARM_CFG else ")"))
        print("order:", " ".join(key(*t) for t in todo))
        return

    import anthropic

    client = anthropic.Anthropic(max_retries=0)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    for case, arm, task, rep in todo:
        user, system = build_user(arm, task, case, cities, profiles), SYSTEMS.get(arm, SYSTEM)
        cfg = ARM_CFG.get(arm, {})
        model = cfg.get("model", MODEL)
        worst = worst_usd(arm, task, system, user)
        spent = cost(read_log())
        if spent + worst > args.max_usd:
            sys.exit(f"stopped: spent ${spent:.4f}, next call could add ${worst:.4f}, over --max-usd {args.max_usd}")
        row = {"key": key(case, arm, task, rep), "case": case["id"], "arm": arm, "task": task, "rep": rep,
               "model": model, "inputs_hash": inputs_hash, "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
        extra = dict(cfg.get("extra", {}))
        if cfg.get("search") and cfg.get("provider") != "gemini":
            extra["tools"] = [{"type": cfg["search"], "name": "web_search", "max_uses": MAX_USES[task]}]
        start = time.monotonic()
        try:
            if cfg.get("provider") == "gemini":
                row.update(call_gemini(model, system, user, cfg["thinking_level"]))
                final, searches = row["final_text"], row["searches"]
            else:
                # No fallback model and no pause_turn continuation: the plan logs such a reply as it is.
                resp = client.messages.create(
                    model=model, max_tokens=MAX_TOKENS, system=system, messages=[{"role": "user", "content": user}], **extra,
                )
                # Raw text and usage go into the row before any checking, so a bad reply is never lost.
                final, searches = "".join(b.text for b in resp.content if b.type == "text"), []
                row.update(text=final, stop_reason=resp.stop_reason,
                           input_tokens=resp.usage.input_tokens, output_tokens=resp.usage.output_tokens)
                if ARM_CFG:  # with a search tool the answer is the text after the last tool block
                    final, row["text"], searches, row["content"] = read_content(resp.content)
                    tool_usage = getattr(resp.usage, "server_tool_use", None)
                    row.update(final_text=final, searches=searches,
                               search_requests=getattr(tool_usage, "web_search_requests", 0) or 0)
            try:
                row["parsed"], row["format_problems"] = check_output(task, final, allowed)
                if cfg.get("search") and isinstance(row["parsed"], dict):
                    check_sources(row["parsed"], sentences(task, row["parsed"]), searches, row["format_problems"],
                                  by_domain=cfg.get("provider") == "gemini")
            except Exception as e:  # a checker bug must not cost us the paid response
                row["parsed"], row["format_problems"] = None, [f"check_crashed:{type(e).__name__}"]
        except (anthropic.APIError, GeminiError) as e:
            row["error"] = f"{type(e).__name__}: {e}"
        row["latency_s"] = round(time.monotonic() - start, 2)
        with LOG.open("a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        if "error" in row:
            sys.exit(f"stopped at {row['key']}: {row['error']}\nThe failure is logged and will not be retried. "
                     "Its cost is unknown to this script: check the Console usage and lower --max-usd by that amount when resuming.")
        print(row["key"], f"in {row['input_tokens']} out {row['output_tokens']} "
              + (f"searches {row['search_requests']} " if "search_requests" in row else "")
              + f"{row['latency_s']}s {row['format_problems'] or 'ok'}")
    rows = read_log()
    print(f"logged {len(rows)} call(s), total ${cost(rows):.4f}")


def sheet(rep):
    """Shuffled responses with the arm hidden; the key goes to a separate file.
    One sheet per repeat number, never overwritten: it holds the reviewer's verdicts."""
    md, keyfile = LOG.parent / f"review-r{rep}.md", LOG.parent / f"review-key-r{rep}.json"
    if md.exists() or keyfile.exists():
        sys.exit(f"stopped: {md.name} already exists and may hold review notes. Move it aside to regenerate.")
    rows = [r for r in read_log() if r["rep"] == rep]
    if not rows:
        sys.exit(f"no logged calls with rep {rep}")
    base = N_CASES * len(ARMS) * 2
    if rep == 0 and len(rows) < base:  # the sheet cannot be extended later
        sys.exit(f"stopped: only {len(rows)} of {base} base calls are logged. Finish the base run first.")
    cases = {c["id"]: c for c in json.loads((EXP / CASES_FILE).read_text())["cases"]}
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
    p.add_argument("--arms", default="")  # run 5 repeats: only the two arms that split
    p.add_argument("--rep", type=int, default=0, choices=[0, 1, 2])
    p.add_argument("--max-usd", type=float, default=3.0)  # worst case for all 72 calls is about $2.4
    p.add_argument("--run", type=int, default=1, choices=sorted(RUNS))
    a = p.parse_args()
    configure(a.run)
    sheet(a.rep) if a.sheet else run(a)
