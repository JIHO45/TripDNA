"""핵심 경험 A/B 실험. 계획: data/exploration/core-experience-ab/plan.md

도시·등급·시즌·해석된 조건·카드 순서를 코드와 사례 파일로 고정하고, 카드 설명(이유·유의점)만 모델이 쓴다.
A는 사용자 메시지에 도시별 "핵심 경험" 줄을 넣고, B는 넣지 않는다. 지침은 같다.
    python3 scripts/run_core_ab.py                       # 가짜 응답 검사
    python3 scripts/run_core_ab.py --show F10            # 그 사례의 A·B 메시지 출력
    .venv/bin/python scripts/run_core_ab.py --dry-run    # 호출 목록과 최대 추정 비용
    .venv/bin/python scripts/run_core_ab.py --run        # 호출. GEMINI_API_KEY, ANTHROPIC_API_KEY 필요. 기록된 호출은 건너뛴다
    python3 scripts/run_core_ab.py --report              # 코드 검사 집계
    python3 scripts/run_core_ab.py --export              # 블라인드 판독표(judging.md)와 정답 키(judging_key.json)
"""
import argparse
import hashlib
import json
import random
import sys
import time

import check_contract as cc

BASE = cc.fd.rp.EXP / "core-experience-ab"
SCHEMA = json.loads((BASE / "schema.json").read_text())
LOG = BASE / "responses.jsonl"
ARMS = ("A", "B")
REPS = 2
MAX_USD = 0.80
cc.MAX_TOKENS = 4096  # 카드 3장의 설명만 쓴다
EVENTS = cc.EVENTS


def load():
    """사례 파일의 고정 해석에 계약 확인 실험의 요청(실행 2까지의 사례)을 붙인다."""
    pool = {c["id"]: c for c in cc.load_cases(2)}
    return [dict(pool[c["id"]], fixed=c["conditions"]) for c in json.loads((BASE / "cases.json").read_text())["cases"]]


def cards(case):
    """코드의 기준 순서에서 제외를 반영한 상위 3곳. 두 방식에 같다."""
    off = cc.excluded(case)
    return [cid for cid in cc.base_order(case) if cid not in off][:3]


def message(case, arm):
    month, main = case["month"], case["detail"] or case["main"]
    head = cc.user_message(case).split("\n도시 표:")[0]  # 컨셉, 앱 조건, 사용자 데이터, 제외는 계약 확인과 같다
    fixed = case["fixed"]
    out = [head, "\n이번 요청의 해석(앱이 정함):\n" + ("\n".join(
        f"- [{c['level']}] {c['text']}: {c['status']}" for c in fixed) or "- 따로 정한 조건 없음")]
    rows = []
    for n, cid in enumerate(cards(case), 1):
        c = cc.fd.CITIES[cid]
        # 주 컨셉(또는 세부)과 부 컨셉의 세부. 큰 컨셉이면 그 아래 세부를 모두 본다. 핵심 경험·시즌은 세부별로 저장돼 있다
        relevant = {s for k in [main, *case["subs"]] for s in [k, *cc.fd.CONCEPTS.get(k, {}).get("sub", {})]}
        subs = "; ".join(f"{cc.fd.LABEL[s]} {cc.NAMES[cc.level(c, s, month)]}" for s in case["subs"])
        season = [f"{cc.fd.LABEL[s]} {', '.join(map(str, sorted(m)))}월" for s, m in c["season"].items() if s in relevant]
        unverified = [cc.fd.LABEL[s] for s in c["season_unverified"] if s in cc.fd.LABEL and s in relevant]
        core = [f"{cc.fd.LABEL[s]}: {t}" for s, t in c["core"].items() if s in cc.fd.LABEL and s in relevant]
        rows.append("\n".join(filter(None, [
            f"카드 {n} | {cid} {c['name']['ko']} | {c['country']}",
            f"{cc.fd.LABEL[main]}: {cc.NAMES[cc.level(c, main, month)]}" + (f" | 부 컨셉: {subs}" if subs else ""),
            season and "시즌: " + "; ".join(season),
            unverified and "시즌 미확인 세부: " + ", ".join(unverified),
            arm == "A" and core and "핵심 경험: " + " / ".join(core)])))
    out.append("\n카드(앱이 고른 도시와 순서):\n\n" + "\n\n".join(rows))
    return "\n".join(out)


def system_prompt():
    body = (BASE / "prompt.md").read_text().split("\n---\n", 1)[1].strip()
    return f"{body}\n\nSchema:\n{json.dumps(SCHEMA, ensure_ascii=False)}"


def check(case, text):
    """형식, 카드 ID와 순서, 보이는 문장의 내부 표현. 문장의 사실은 판독이 맡는다."""
    data = cc.fd.parse(text)
    errors = cc.schema_errors(SCHEMA, data) if data is not None else ["JSON을 읽지 못함"]
    if errors:
        return None, [f"형식 실패: {e}" for e in errors]
    problems, want = [], cards(case)
    got = [c["id"] for c in data["cards"]]
    if got != want:
        problems.append(f"카드 불일치: 기대 {want}, 응답 {got}")
    for c in data["cards"]:
        for term in cc.internal_terms(f"{c['reason']} {c['caveat']}"):
            problems.append(f"내부 표현 {c['id']}: {term}")
    if case["detail"] in EVENTS and case["month"]:  # 단어로만 센다. 맞는 안내인지는 판독한다
        for c in data["cards"]:
            if not any(w in c["caveat"] for w in ("날짜", "일정", "일자", "기간")):
                problems.append(f"날짜 확인 안내 없음(단어 기준): {c['id']}")
    return data, problems


def todo():
    return [(case, arm, model, r) for case in load() for arm in ARMS for model in cc.ARMS for r in range(1, REPS + 1)]


def key(case, arm, model, rep):
    return f"{case['id']}:{arm}:{model}:r{rep}"


def run(dry):
    system, done, total = system_prompt(), {r["key"] for r in cc.fd.read_log(LOG)}, 0.0
    client = None
    if not dry:
        import anthropic
        client = anthropic.Anthropic(max_retries=0)
    for case, arm, model, rep in todo():
        k, mid, user = key(case, arm, model, rep), cc.ARMS[model]["model"], message(case, arm)
        worst = cc.worst_usd(mid, system, user)
        if dry:
            total += worst
            print(f"{k:16s} 입력 {len(system) + len(user):6d}자  최대 ${worst:.4f}")
            continue
        if k in done:
            continue
        spent = cc.fd.rp.cost(cc.fd.read_log(LOG))
        if spent + worst > MAX_USD:  # 다음 호출의 추정 비용을 포함해 상한 초과가 예상되면 호출하지 않는다
            sys.exit(f"stopped: spent ${spent:.4f}, next call could add ${worst:.4f}, over ${MAX_USD}")
        row = {"key": k, "case": case["id"], "arm": arm, "arm_model": model, "rep": rep, "model": mid,
               "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
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
        print(k, f"문제 {len(check(case, row['final_text'])[1])}", f"{row['latency_s']}s")
    if dry:
        print(f"호출 {len(todo())}회, 최대 합계 ${total:.2f} (상한 ${MAX_USD})")


def report():
    cases = {c["id"]: c for c in load()}
    rows = [r for r in cc.fd.read_log(LOG) if "error" not in r]
    for model in cc.ARMS:
        for arm in ARMS:
            rs = [r for r in rows if r["arm_model"] == model and r["arm"] == arm]
            if not rs:
                continue
            kinds = {}
            for r in rs:
                for p in {p.split(":")[0].split("(")[0].strip() for p in check(cases[r["case"]], r["final_text"])[1]}:
                    kinds[p] = kinds.get(p, 0) + 1
            print(f"[{model} {arm}] 응답 {len(rs)} | 입력 토큰 평균 {sum(r['input_tokens'] for r in rs) // len(rs)} | "
                  f"출력 평균 {sum(r['output_tokens'] for r in rs) // len(rs)} | 추정 비용 ${cc.fd.rp.cost(rs):.4f} | "
                  f"지연 평균 {sum(r['latency_s'] for r in rs) / len(rs):.1f}s | 문제가 있던 응답 {kinds or '없음'}")


def export():
    """같은 사례·모델·반복의 A와 B를 짝지어 무작위 순서로 '가'·'나'를 붙인다. 정답 키는 따로 저장한다."""
    cases = {c["id"]: c for c in load()}
    rows = {r["key"]: r for r in cc.fd.read_log(LOG) if "error" not in r}
    out, answer = ["# 핵심 경험 A/B 판독표\n", "어느 쪽이 A인지 보지 않고 판독한다. 정답 키는 judging_key.json에 있다. 판독 항목은 plan.md의 '판독'을 따른다.\n"], {}
    for case in load():
        for model in cc.ARMS:
            for rep in range(1, REPS + 1):
                pair = [rows.get(key(case, arm, model, rep)) for arm in ARMS]
                if not all(pair):
                    continue
                pid = f"{case['id']}-{model}-r{rep}"
                order = list(ARMS)
                random.Random(hashlib.sha256(pid.encode()).hexdigest()).shuffle(order)
                answer[pid] = dict(zip(("가", "나"), order))
                head = cc.user_message(case).split("\n도시 표:")[0].replace("\n\n", "\n")
                out.append(f"\n## {pid}\n\n요청:\n```\n{head}\n여행 월: {case['month'] or '없음'} | 고정 해석: {case['fixed'] or '없음'}\n```")
                for label, arm in answer[pid].items():
                    data, _ = check(cases[case["id"]], rows[key(case, arm, model, rep)]["final_text"])
                    out.append(f"\n**{label}**\n")
                    for c in (data or {}).get("cards", []) or [{"id": "(형식 실패)", "reason": "", "caveat": ""}]:
                        out.append(f"- {c['id']}\n  - 이유: {c['reason']}\n  - 유의: {c['caveat']}")
                out.append("\n| 항목 | 가 | 나 |\n|---|---|---|\n| 확인 결과 틀린 사실 |  |  |\n| 확인할 수 없는 사실 |  |  |\n"
                           "| 여행 시기와 맞지 않는 계절·행사·운영 주장 |  |  |\n| 요청에 맞는 구체적인 이유(1~3) |  |  |\n| 더 나은 쪽 |  |  |")
    (BASE / "judging.md").write_text("\n".join(out) + "\n")
    (BASE / "judging_key.json").write_text(json.dumps(answer, ensure_ascii=False, indent=1))
    print(f"판독표 {len(answer)}쌍: {BASE / 'judging.md'}")


def self_check():
    case = next(c for c in load() if c["id"] == "F10")
    a, b = message(case, "A"), message(case, "B")
    assert "핵심 경험:" in a and "핵심 경험:" not in b
    assert [l for l in a.split("\n") if not l.startswith("핵심 경험:")] == b.split("\n")  # 차이는 핵심 경험 줄뿐
    assert "[보조] 축제 기간에 맞춰 방문: 확인 필요" in a and "시즌: 축제" in a
    assert "축제: 10월 말에서 11월 초의 죽은 자의 날" in a and any(f"{cc.fd.LABEL[s]}:" in a for s in cc.fd.CONCEPTS["food"]["sub"])  # 부 컨셉(미식)의 세부도 들어간다
    assert cards(next(c for c in load() if c["id"] == "X1")) == ["fr-paris", "th-bangkok", "us-new-york"]  # 일본 제외 반영
    ok = {"cards": [{"id": i, "reason": "축제를 본다", "caveat": "정확한 날짜를 확인하세요"} for i in cards(case)]}
    assert check(case, json.dumps(ok, ensure_ascii=False)) == (ok, [])
    swapped = {"cards": list(reversed(ok["cards"]))}
    assert any(p.startswith("카드 불일치") for p in check(case, json.dumps(swapped, ensure_ascii=False))[1])
    leak = {"cards": [dict(ok["cards"][0], reason="jp-kyoto 등급이 높다")] + ok["cards"][1:]}
    assert any(p.startswith("내부 표현") for p in check(case, json.dumps(leak, ensure_ascii=False))[1])
    no_date = {"cards": [dict(c, caveat="") for c in ok["cards"]]}
    assert sum(p.startswith("날짜 확인 안내 없음") for p in check(case, json.dumps(no_date, ensure_ascii=False))[1]) == 3
    assert check(case, '{"cards": [{"id": "x"}]}')[1][0].startswith("형식 실패")
    assert len(todo()) == len(load()) * len(ARMS) * len(cc.ARMS) * REPS
    print("self_check ok")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--show")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--run", action="store_true")
    p.add_argument("--report", action="store_true")
    p.add_argument("--export", action="store_true")
    args = p.parse_args()
    self_check()
    if args.show:
        case = next(c for c in load() if c["id"] == args.show)
        for arm in ARMS:
            print(f"===== {arm}\n{message(case, arm)}\n")
    if args.dry_run or args.run:
        run(args.dry_run)
    if args.report:
        report()
    if args.export:
        export()


if __name__ == "__main__":
    main()
