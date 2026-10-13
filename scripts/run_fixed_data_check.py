"""고정 자료 추천 확인. 계획: data/exploration/fixed-data-check/plan.md, run2/plan.md.

20곳 자료만 준 Gemini Flash가 등급·시즌·조건을 지키는지 본다. 실행마다 자료·사례·지침을 run{n}/에 고정한다.
실행 1은 검색 없음(off) 한 방식, 실행 2는 고친 지침으로 검색 없음(off)과 검색 있음(on)을 비교한다.
    python3 scripts/run_fixed_data_check.py --run 2 --dry-run   # 지침과 사용자 입력 출력
    python3 scripts/run_fixed_data_check.py --run 2             # 호출. GEMINI_API_KEY 필요. 기록된 호출은 건너뛴다.
    python3 scripts/run_fixed_data_check.py --run 2 --report    # LLM 원출력과 코드 검사 뒤 결과를 나눠 출력
"""
import argparse
import json
import re
import sys
import time

import run_profile_exploration as rp

BASE = rp.EXP / "fixed-data-check"
CONCEPTS = json.loads((rp.EXP / "coverage-check/grades-v2.json").read_text())["concepts"]
for c in CONCEPTS.values():  # 현지인 만나기는 정의 전까지 선택지에서 뺀다(draft.json의 rules)
    c["sub"].pop("locals", None)
LABEL = {**{t: c["label"] for t, c in CONCEPTS.items()}, **{s: n for c in CONCEPTS.values() for s, n in c["sub"].items()}}
MAX_USD = 3.0
CITIES = {}  # main()이 실행 폴더의 draft.json으로 채운다


def grade(city, sub, month):
    """시기가 주어지면 시즌 밖 세부는 0으로 본다."""
    season = city["season"].get(sub)
    return 0 if month and season and month not in season else city["grades"][sub]


def top(city, concept, month):
    return max(grade(city, s, month) for s in CONCEPTS[concept]["sub"])


def fits(cid, case):
    city, m = CITIES[cid], case["month"]
    return (grade(city, case["detail"], m) if case["detail"] else top(city, case["main"], m)) >= 2


def city_table(ids=None):
    out = []
    for cid, c in CITIES.items():
        if ids is not None and cid not in ids:
            continue
        lines = [f"{cid} {c['name']['ko']} | 범위: {c['scope']}"]
        lines.append("등급: " + "; ".join(
            f"{v['label']} {top(c, t, None)} ({', '.join(f'{n} {c['grades'][s]}' for s, n in v['sub'].items())})"
            for t, v in CONCEPTS.items()))
        if c["season"]:
            lines.append("시즌: " + "; ".join(f"{LABEL[s]} {', '.join(map(str, sorted(m)))}월" for s, m in c["season"].items()))
        if c["season_unverified"]:
            lines.append("시즌 미확인: " + ", ".join(LABEL[s] for s in c["season_unverified"]))
        if c["nearby"]:
            lines.append("근교(등급에 넣지 않음): " + "; ".join(c["nearby"]))
        lines.append("핵심 경험: " + " / ".join(f"{LABEL[s]}: {t}" for s, t in c["core"].items() if s in LABEL))
        out.append("\n".join(lines))
    return "\n\n".join(out)


def request_text(case):
    lines = [f"주 컨셉: {LABEL[case['main']]}" + (f" (세부: {LABEL[case['detail']]})" if case["detail"] else "")]
    if case["subs"]:
        lines.append("부 컨셉: " + ", ".join(LABEL[s] for s in case["subs"]))
    lines.append(f"시기: {case['month']}월" if case["month"] else "시기: 정하지 않음")
    if case["text"]:
        lines.append(f"바라는 점: {case['text']}")
    return "\n".join(lines)


def parse(text):
    m = re.search(r"\{.*\}", text or "", re.S)
    try:
        data = json.loads(m.group(0)) if m else None
    except ValueError:
        data = None
    return data if isinstance(data, dict) else None


def candidates(data):
    return [c for c in (data or {}).get("candidates") or [] if isinstance(c, dict)]


def code_check(case, data):
    """[(id, 통과 여부, 이유)]. 허용 ID와 주 컨셉 2등급 이상(시즌 적용)만 본다."""
    out = []
    for c in candidates(data):
        cid = c.get("id")
        out.append((cid, False, "목록에 없는 ID") if cid not in CITIES
                   else (cid, False, "주 컨셉 2등급 미만(시즌 적용)") if not fits(cid, case) else (cid, True, ""))
    return out


def condition_problems(case, data, arm):
    """말한 조건이 자료에 없는 사례에서 confirmed로 나온 후보의 문제. 문장 내용은 보지 않는다."""
    out = []
    for c in candidates(data):
        if c.get("status") != "confirmed":
            continue
        if c.get("id") in case.get("not_confirmed", {}):
            out.append(f"{c['id']}: confirmed로 나오면 안 됨({case['not_confirmed'][c['id']]})")
        elif case.get("stated") and arm == "off":
            out.append(f"{c.get('id')}: 검색 없이 confirmed")
        elif case.get("stated") and not c.get("sources"):
            out.append(f"{c.get('id')}: 출처 없이 confirmed")
    return out


def grade_talk(data):
    """사용자에게 보일 문장에서 등급·점수를 말한 후보 수."""
    return sum(bool(re.search(r"등급|\d\s*점", f"{c.get('reason')} {c.get('caveat')}")) for c in candidates(data))


def self_check():
    q, month = CITIES["nz-queenstown"], lambda m: dict(month=m, main="activities", detail="winter")
    assert grade(q, "winter", 1) == 0 and grade(q, "winter", 7) == 3 and grade(q, "winter", None) == 3
    assert not fits("nz-queenstown", month(1)) and fits("nz-queenstown", month(7))
    assert top(CITIES["jp-kyoto"], "event", 6) == 1 and top(CITIES["jp-kyoto"], "event", 7) == 2
    assert not fits("jp-tokyo", dict(month=None, main="nature", detail=None))
    assert parse('```json\n{"candidates": []}\n```') == {"candidates": []} and parse("없음") is None
    assert "locals" not in LABEL
    case = {"stated": "x", "not_confirmed": {"a": "왜"}}
    data = {"candidates": [{"id": "a", "status": "confirmed", "sources": ["u"]}, {"id": "b", "status": "confirmed"},
                           {"id": "c", "status": "needs_check", "reason": "등급 3"}]}
    assert len(condition_problems(case, data, "off")) == 2 and len(condition_problems(case, data, "on")) == 2
    assert condition_problems({}, data, "off") == [] and grade_talk(data) == 1


def load(run):
    d = BASE / f"run{run}"
    CITIES.update(json.loads((d / "draft.json").read_text())["cities"])
    spec = json.loads((d / "cases.json").read_text())
    parts = [p.strip() for p in (d / "prompt.md").read_text().split("\n---\n")]
    systems = {"off": parts[1], "on": "\n\n".join(parts[1:])}
    return d / "responses.jsonl", spec["cases"], spec.get("arms", ["off"]), systems


def read_log(log):
    return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []


def report(log, cases, arms):
    rows = {r["key"]: r for r in read_log(log) if "error" not in r}
    tally = {a: dict(calls=0, listed=0, dropped=0, include=[0, 0], empty=[0, 0], cond=0, talk=0) for a in arms}
    for case in cases:
        fit = sorted(c for c in CITIES if fits(c, case))
        print(f"\n## {case['id']}  {request_text(case).replace(chr(10), ' / ')}")
        print(f"자료상 주 컨셉이 맞는 도시({len(fit)}): {fit}")
        print(f"볼 점: {case['watch']}")
        for arm in arms:
            r = rows.get(f"{case['id']}:{arm}") or (rows.get(case["id"]) if arm == "off" else None)  # 실행 1의 키는 사례 ID뿐이다
            data = parse(r["final_text"]) if r else None
            if data is None:
                print(f"[{arm}] {'형식 오류: JSON을 읽지 못함' if r else '기록 없음'}")
                continue
            t = tally[arm]
            checked = code_check(case, data)
            kept = [c for c, ok, _ in checked if ok]
            status = {c.get("id"): c.get("status") for c in candidates(data)}
            t["calls"], t["listed"], t["dropped"] = t["calls"] + 1, t["listed"] + len(checked), t["dropped"] + len(checked) - len(kept)
            print(f"[{arm}] LLM 원출력: {[(c, status.get(c)) for c, _, _ in checked]}")
            print(f"[{arm}] 코드 검사 뒤: {kept}  제외: {[(c, why) for c, ok, why in checked if not ok]}")
            if data.get("excluded"):
                print(f"[{arm}] LLM이 뺀 도시: {data['excluded']}")
            if case.get("expect_empty"):
                t["empty"] = [t["empty"][0] + (not checked), t["empty"][1] + 1]
                print(f"[{arm}] 빈 결과 기대: 원출력 {'통과' if not checked else '실패'}")
            missing = sorted(set(case.get("must_include", [])) - set(kept))
            if "must_include" in case:
                t["include"] = [t["include"][0] + (not missing), t["include"][1] + 1]
                print(f"[{arm}] 있어야 하는 도시: {'모두 있음' if not missing else f'빠짐 {missing}'}")
            probs = condition_problems(case, data, arm)
            t["cond"], t["talk"] = t["cond"] + len(probs), t["talk"] + grade_talk(data)
            if case.get("stated"):
                print(f"[{arm}] 말한 조건 '{case['stated']}': {'문제 없음' if not probs else probs}")
            for c in candidates(data):
                print(f"   {c.get('id')} [{c.get('status')}] {c.get('reason')} | 유의: {c.get('caveat')}"
                      f" | 미확인: {c.get('unconfirmed')} | 출처 {len(c.get('sources') or [])}개")
            if data.get("note"):
                print(f"   note: {data['note']}")
            if r.get("search_requests"):
                print(f"   검색어 {r['search_requests']}개, {r['latency_s']}s")
    print("\n## 합계 (문장 내용은 사람이 읽어야 한다)")
    for arm, t in tally.items():
        done = [r for k, r in rows.items() if k.endswith(f":{arm}") or (arm == "off" and ":" not in k)]
        print(f"[{arm}] 호출 {t['calls']}건 | 낸 도시 {t['listed']}곳 중 코드 검사가 제외 {t['dropped']}곳 | "
              f"있어야 하는 도시가 모두 있는 사례 {t['include'][0]}/{t['include'][1]} | 빈 결과 {t['empty'][0]}/{t['empty'][1]} | "
              f"조건 승인 문제 {t['cond']}건 | 등급·점수를 말한 후보 {t['talk']}곳 | "
              f"추정 비용 ${rp.cost(done):.2f} | 지연 평균 {sum(r['latency_s'] for r in done) / max(len(done), 1):.1f}s")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--run", type=int, default=2)
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--report", action="store_true")
    args = p.parse_args()
    log, cases, arms, systems = load(args.run)
    self_check()
    if args.report:
        return report(log, cases, arms)
    rp.MAX_TOKENS = 4096
    table, done = city_table(), {r["key"] for r in read_log(log)}
    if args.dry_run:
        for arm in arms:
            print(f"=== 지침 [{arm}]\n{systems[arm]}\n")
        print(f"=== 도시 자료 {len(table)}자 (생략)\n")
    for case in cases:
        for arm in arms:
            key = f"{case['id']}:{arm}"
            if args.dry_run:
                print(f"--- {key}\n{request_text(case)}\n")
                continue
            if key in done or (args.run == 1 and case["id"] in done):
                continue
            spent = rp.cost(read_log(log))
            if spent > MAX_USD:
                sys.exit(f"stopped: spent ${spent:.2f}, over ${MAX_USD}")
            row = {"key": key, "arm": arm, "model": rp.FLASH, "user": request_text(case), "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
            start = time.monotonic()
            try:
                res = rp.call_gemini(rp.FLASH, systems[arm], f"{request_text(case)}\n\n도시 자료:\n\n{table}", "low", search=arm == "on")
                row.update({k: res[k] for k in ("final_text", "stop_reason", "input_tokens", "output_tokens", "search_requests", "searches")})
            except rp.GeminiError as e:
                row["error"] = str(e)
            row["latency_s"] = round(time.monotonic() - start, 2)
            with log.open("a") as f:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
            if "error" in row:  # 실패는 기록하고 멈춘다. 그 줄을 지우고 다시 돌리면 이어서 한다.
                sys.exit(f"stopped at {key}: {row['error']}")
            data = parse(row["final_text"])
            print(key, [(c.get("id"), c.get("status")) for c in candidates(data)], f"검색어 {row['search_requests']}", f"{row['latency_s']}s")


if __name__ == "__main__":
    main()
