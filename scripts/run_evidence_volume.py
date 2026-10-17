"""자료량 편향 실험. 계획: data/exploration/evidence-volume/plan.md

후보 7곳·등급·선호 해석을 고정하고, 대상 도시 한 곳의 문장 양만 L0~L3으로 바꾼다. 모델은 도시마다 선호의 근거를
문장 인용으로 보고하고, 코드가 인용을 입력 문장과 대조한 뒤 2026-10-17 순서 규칙으로 순위를 계산한다.
    python3 scripts/run_evidence_volume.py                        # 가짜 응답 검사
    python3 scripts/run_evidence_volume.py --show N1 tw-taipei L1 # 메시지 출력
    .venv/bin/python scripts/run_evidence_volume.py --dry-run     # 호출 목록과 최대 추정 비용
    .venv/bin/python scripts/run_evidence_volume.py --run         # 호출. GEMINI_API_KEY, ANTHROPIC_API_KEY 필요
    python3 scripts/run_evidence_volume.py --report               # 집계
"""
import argparse
import json
import sys
import time

import check_contract as cc

fd = cc.fd
BASE = fd.rp.EXP / "evidence-volume"
SCHEMA = json.loads((BASE / "schema.json").read_text())
LOG = BASE / "responses.jsonl"
LEVELS = ("L0", "L1", "L2", "L3")
REPS, N_CANDIDATES, MAX_USD = 2, 7, 0.80
cc.MAX_TOKENS = 4096
DATA_CONCEPTS = ("food", "shopping")  # 원문(L2)으로 주는 문장의 컨셉. L3은 그 밖의 컨셉 문장을 더한다


def load():
    return json.loads((BASE / "cases.json").read_text())["cases"]


def candidates(case):
    return cc.base_order(case)[:N_CANDIDATES]


def mentions(case, text):
    return any(k in text for k in case["preference"]["keywords"])


def sentences(case, cid, level="L2", target=None):
    """[(label, 문장)]. 대상 도시만 수준에 따라 바뀐다. label은 세부 이름이다."""
    core = fd.CITIES[cid]["core"]
    own = [s for k in DATA_CONCEPTS for s in fd.CONCEPTS[k]["sub"]]
    base = [(s, core[s]) for s in own if s in core]
    if cid != target or level == "L2":
        return base
    if level == "L0":
        return []
    if level == "L1":
        return [(s, t) for s, t in base if not mentions(case, t)]
    extra = [(s, t) for s, t in core.items() if s not in own and s in fd.LABEL and not mentions(case, t)]
    return base + extra  # L3: 선호 단어가 없는 다른 컨셉 문장만 더한다


def message(case, level, target):
    head = [l for l in fd.request_text(case).split("\n") if not l.startswith(("시기", "바라는 점"))]
    pref = case["preference"]
    out = head + [f"\n[사용자 데이터: 바라는 점]\n{case['text']}",
                  f"\n앱이 정한 선호 해석: [{pref['level']}] {pref['text']}", "\n도시 표:"]
    main = case["detail"] or case["main"]
    for cid in candidates(case):
        c = fd.CITIES[cid]
        lines = [f"\n{cid} {c['name']['ko']} | {c['country']} | {fd.LABEL[main]}: {cc.NAMES[cc.level(c, main, case['month'])]}"]
        ss = sentences(case, cid, level, target)
        lines += [f"  [{s}] {t}" for s, t in ss] or ["  (문장 없음)"]
        out.append("\n".join(lines))
    return "\n".join(out)


def system_prompt():
    body = (BASE / "prompt.md").read_text().split("\n---\n", 1)[1].strip()
    return f"{body}\n\nSchema:\n{json.dumps(SCHEMA, ensure_ascii=False)}"


def judge(case, level, target, text):
    """도시별 {claimed, accepted, keyword}와 문제 목록. accepted는 ref·quote가 입력 문장과 맞을 때만."""
    data = fd.parse(text)
    errors = cc.schema_errors(SCHEMA, data) if data is not None else ["JSON을 읽지 못함"]
    if errors:
        return None, [f"형식 실패: {e}" for e in errors]
    want, problems, out = candidates(case), [], {}
    if [c["id"] for c in data["cities"]] != want:
        problems.append(f"도시 불일치: {[c['id'] for c in data['cities']]}")
    for c in data["cities"]:
        cid = c["id"]
        if cid not in want:
            continue
        given = dict(sentences(case, cid, level, target))
        claimed = c["status"] == "met"
        label = c["ref"].removeprefix(f"city:{cid}#") if c["ref"].startswith(f"city:{cid}#") else None
        ok = claimed and label in given and c["quote"].strip() != "" and c["quote"].strip() in given[label]
        if claimed and not ok:
            problems.append(f"근거 대조 실패: {cid} ({c['ref']!r})")
        kw = ok and mentions(case, c["quote"])
        if ok and not kw:
            problems.append(f"선호 단어 없는 충족: {cid} ({c['quote']!r})")
        out[cid] = {"claimed": claimed, "accepted": ok, "keyword": kw}
    return out, problems


def rank(case, accepted):
    """2026-10-17 순서 규칙. 선호가 하나뿐이고 부 컨셉·티어가 없으므로
    핵심: (충족, 주 컨셉 등급), 보조: (주 컨셉 등급, 충족) 순으로 비교하고 나머지는 기준 순서를 따른다."""
    main, base = case["detail"] or case["main"], candidates(case)
    grade = lambda cid: cc.level(fd.CITIES[cid], main, case["month"])
    met = lambda cid: int(bool(accepted.get(cid)))
    if case["preference"]["level"] == "핵심":
        k = lambda cid: (-met(cid), -grade(cid), base.index(cid))
    else:
        k = lambda cid: (-grade(cid), -met(cid), base.index(cid))
    return sorted(base, key=k)


def todo():
    return [(case, target, level, model, r) for case in load() for target in case["targets"] for level in LEVELS
            for model in cc.ARMS for r in range(1, REPS + 1)]


def key(case, target, level, model, rep):
    return f"{case['id']}:{target}:{level}:{model}:r{rep}"


def run(dry):
    system, done, total, client = system_prompt(), {r["key"] for r in fd.read_log(LOG)}, 0.0, None
    if not dry:
        import anthropic
        client = anthropic.Anthropic(max_retries=0)
    for case, target, level, model, rep in todo():
        k, mid, user = key(case, target, level, model, rep), cc.ARMS[model]["model"], message(case, level, target)
        worst = cc.worst_usd(mid, system, user)
        if dry:
            total += worst
            continue
        if k in done:
            continue
        spent = fd.rp.cost(fd.read_log(LOG))
        if spent + worst > MAX_USD:  # 다음 호출의 추정 비용을 포함해 상한 초과가 예상되면 호출하지 않는다
            sys.exit(f"stopped: spent ${spent:.4f}, next call could add ${worst:.4f}, over ${MAX_USD}")
        row = {"key": k, "case": case["id"], "target": target, "level": level, "arm_model": model, "rep": rep,
               "model": mid, "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
        start = time.monotonic()
        try:
            row.update(cc.call(client, mid, system, user))
        except Exception as e:  # 실패는 기록하고 멈춘다. 그 줄을 지우고 다시 돌리면 이어서 한다
            row["error"] = f"{type(e).__name__}: {e}"
        row["latency_s"] = round(time.monotonic() - start, 2)
        with LOG.open("a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        if "error" in row:
            sys.exit(f"stopped at {k}: {row['error']}")
        res, probs = judge(case, level, target, row["final_text"])
        t = (res or {}).get(target, {})
        print(k, f"대상 주장 {t.get('claimed')} 인정 {t.get('accepted')}", f"문제 {len(probs)}", f"{row['latency_s']}s")
    if dry:
        print(f"호출 {len(todo())}회, 최대 합계 ${total:.2f} (상한 ${MAX_USD})")


def report():
    cases = {c["id"]: c for c in load()}
    rows = [r for r in fd.read_log(LOG) if "error" not in r]
    by = {}
    for r in rows:
        case = cases[r["case"]]
        res, probs = judge(case, r["level"], r["target"], r["final_text"])
        by[r["key"]] = (r, res, probs)
    print("## 대상 도시: 수준별 주장·인정·순위 (반복 합계)")
    for case in cases.values():
        for target, kind in case["targets"].items():
            for model in cc.ARMS:
                cells = []
                for level in LEVELS:
                    rs = [by[key(case, target, level, model, rep)] for rep in range(1, REPS + 1) if key(case, target, level, model, rep) in by]
                    ok = [x for x in rs if x[1]]
                    claimed = sum(x[1][target]["claimed"] for x in ok if target in x[1])
                    acc = sum(x[1][target]["accepted"] for x in ok if target in x[1])
                    ranks = [rank(case, {c: v["accepted"] for c, v in x[1].items()}).index(target) + 1 for x in ok]
                    cells.append(f"{level} 주장 {claimed}/{len(rs)} 인정 {acc} 순위 {ranks}")
                print(f"{case['id']} {target}({kind}) [{model}] " + " | ".join(cells))
    print("\n## 문제(응답 수)")
    kinds = {}
    for r, res, probs in by.values():
        for p in {p.split(":")[0] for p in probs}:
            kinds[(r["arm_model"], p)] = kinds.get((r["arm_model"], p), 0) + 1
    print(kinds or "없음")
    print("\n## 파급: 대상이 아닌 도시의 인정 여부가 같은 반복의 L2와 다른 경우")
    spill = {}
    for r, res, probs in by.values():
        if not res or r["level"] == "L2":
            continue
        base = by.get(key(cases[r["case"]], r["target"], "L2", r["arm_model"], r["rep"]))
        if not base or not base[1]:
            continue
        diff = [c for c in res if c != r["target"] and res[c]["accepted"] != base[1].get(c, {}).get("accepted")]
        spill[r["arm_model"]] = spill.get(r["arm_model"], 0) + len(diff)
    print(spill or "없음")
    for model in cc.ARMS:
        rs = [r for r, _, _ in by.values() if r["arm_model"] == model]
        if rs:
            print(f"[{model}] 응답 {len(rs)} | 추정 비용 ${fd.rp.cost(rs):.4f} | 지연 평균 {sum(r['latency_s'] for r in rs) / len(rs):.1f}s")


def self_check():
    n1, s1 = load()
    assert all(t in candidates(c) for c in (n1, s1) for t in c["targets"])
    tp = "tw-taipei"
    l2 = sentences(n1, tp, "L2", tp)
    assert any(mentions(n1, t) for _, t in l2) and not any(mentions(n1, t) for _, t in sentences(n1, tp, "L1", tp))
    assert sentences(n1, tp, "L0", tp) == [] and len(sentences(n1, tp, "L3", tp)) > len(l2)
    assert not any(mentions(n1, t) for _, t in sentences(n1, tp, "L3", tp)[len(l2):])  # 더한 문장에는 선호 단어가 없다
    assert sentences(n1, "th-bangkok", "L0", tp) == sentences(n1, "th-bangkok", "L2", tp)  # 대상이 아닌 도시는 그대로
    assert "(문장 없음)" in message(n1, "L0", tp) and "(문장 없음)" not in message(n1, "L2", tp)
    # 근거 대조: 입력에 있는 문장의 인용만 인정한다
    label, sent = next((s, t) for s, t in l2 if "야시장" in t)
    cities = [{"id": c, "status": "unknown", "ref": "", "quote": ""} for c in candidates(n1)]
    good = {"cities": [dict(c, status="met", ref=f"city:{tp}#{label}", quote="야시장") if c["id"] == tp else c for c in cities]}
    res, probs = judge(n1, "L2", tp, json.dumps(good, ensure_ascii=False))
    assert res[tp] == {"claimed": True, "accepted": True, "keyword": True} and probs == []
    res, probs = judge(n1, "L1", tp, json.dumps(good, ensure_ascii=False))  # L1에는 그 문장이 없다
    assert res[tp]["claimed"] and not res[tp]["accepted"] and probs[0].startswith("근거 대조 실패")
    vague = {"cities": [dict(c, status="met", ref=f"city:{tp}#{label}", quote=sent.split()[0]) if c["id"] == tp else c for c in cities]}
    if not mentions(n1, sent.split()[0]):
        assert any(p.startswith("선호 단어 없는 충족") for p in judge(n1, "L2", tp, json.dumps(vague, ensure_ascii=False))[1])
    assert judge(n1, "L2", tp, '{"cities": []}')[1][0].startswith("도시 불일치")
    # 순서: 핵심 선호는 등급보다 먼저, 보조 선호는 등급 다음
    base = candidates(n1)
    assert rank(n1, {})[:] == sorted(base, key=lambda c: (-cc.level(fd.CITIES[c], "street", None), base.index(c)))
    assert rank(n1, {tp: True})[0] == tp
    low = base[-1]
    assert rank(s1, {low: True}).index(low) >= rank(s1, {}).index(low) - 1  # 보조 선호는 등급을 뛰어넘지 못한다
    assert len(todo()) == 2 * 3 * len(LEVELS) * len(cc.ARMS) * REPS
    print("self_check ok")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--show", nargs=3, metavar=("CASE", "TARGET", "LEVEL"))
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--run", action="store_true")
    p.add_argument("--report", action="store_true")
    args = p.parse_args()
    self_check()
    if args.show:
        print(message(next(c for c in load() if c["id"] == args.show[0]), args.show[2], args.show[1]))
    if args.dry_run or args.run:
        run(args.dry_run)
    if args.report:
        report()


if __name__ == "__main__":
    main()
