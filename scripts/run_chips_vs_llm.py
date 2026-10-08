"""칩 선택 대 LLM 비교. 계획: data/exploration/chips-vs-llm/plan.md.

A는 충족률(호출 없음), B는 칩만, C는 칩 + 자유문장을 실행 6의 FS 방식(Gemini Flash + 검색)에 보낸다.
    python3 scripts/run_chips_vs_llm.py --dry-run   # 보낼 문장만 출력
    python3 scripts/run_chips_vs_llm.py             # 호출. GEMINI_API_KEY 필요. 이미 기록된 호출은 건너뛴다.
    python3 scripts/run_chips_vs_llm.py --report    # 기록을 표로 출력
"""
import argparse
import json
import sys
import time
from pathlib import Path

import check_coverage_match as cov
import run_profile_exploration as rp

DIR = rp.EXP / "chips-vs-llm"
LOG = DIR / "responses.jsonl"
LABELS = {c["id"]: c["label_ko"] for c in json.loads((rp.ROOT / "data/experience-categories.json").read_text())["categories"]}


def chips_text(wants):
    parts = [(title, [LABELS[k] for k, w in wants.items() if w == v])
             for title, v in (("꼭 원하는 경험", 2), ("좋아하는 경험", 1), ("피하고 싶은 것", -1))]
    return "\n".join(f"{t}: {', '.join(names)}" for t, names in parts if names) or "선택한 항목 없음"


def user_text(case, arm):
    text = chips_text(case["wants"])
    return text if arm == "B" else f"{text}\n이번 여행에 바라는 점: {case['text']}"


def read_log():
    return [json.loads(line) for line in LOG.read_text().splitlines()] if LOG.exists() else []


def picks(row):
    cands = (row.get("parsed") or {}).get("candidates") or [] if isinstance(row.get("parsed"), dict) else []
    return [c.get("id") for c in cands if isinstance(c, dict)]


def report(cases, grades):
    rows = {r["key"]: r for r in read_log() if "error" not in r}
    for case in cases:
        ranked = cov.rank(case["wants"], grades)
        top2 = {c for _, _, cities in ranked[:2] for c in cities} if case["wants"] else set()
        bad = set(case.get("violators", []))
        print(f"\n## {case['id']}  칩: {chips_text(case['wants']).replace(chr(10), ' / ')}")
        a = cov.top_n(ranked)
        print(f"A: {a if case['wants'] else '순위 없음(전부 동점)'}  위반 {sorted(set(a) & bad) if case['wants'] else '-'}")
        for arm in "BC":
            r = rows.get(f"{case['id']}:{arm}")
            if not r:
                print(f"{arm}: 기록 없음")
                continue
            p = picks(r)
            print(f"{arm}: {p}  위반 {sorted(set(p) & bad)}  A 상위 두 그룹 안 {sum(x in top2 for x in p)}/{len(p)}"
                  f"  검색어 {r.get('search_requests')}  {r.get('latency_s')}s  {r.get('format_problems') or 'ok'}")
            data = r.get("parsed") if isinstance(r.get("parsed"), dict) else {}
            for c in data.get("candidates") or []:
                print(f"   {c.get('id')}: {' '.join(c.get('facts') or [])} | 유의: {c.get('caveat')}")
            if data.get("note"):
                print(f"   note: {data['note']}")
    done = list(rows.values())
    print(f"\n호출 {len(done)}건, 스크립트 추정 비용 ${rp.cost(done):.2f} (검색 무료 한도 무시), "
          f"지연 평균 {sum(r['latency_s'] for r in done) / max(len(done), 1):.1f}s")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--report", action="store_true")
    p.add_argument("--max-usd", type=float, default=2.5)
    args = p.parse_args()

    rp.configure(6)
    cities, profiles, _ = rp.load_inputs()
    allowed = {c["id"] for c in cities}
    cases = json.loads((DIR / "cases.json").read_text())["cases"]
    # 후보 파일의 추천 ID는 th-phuket-island다. 등급표와 사례는 th-phuket으로 적혀 있어 여기서 맞춘다.
    alias = lambda i: "th-phuket-island" if i == "th-phuket" else i
    grades = {alias(k): v for k, v in json.loads((cov.DIR / "grades.json").read_text())["grades"].items()}
    for c in cases:
        c["violators"] = [alias(i) for i in c.get("violators", [])]
    assert set(grades) == allowed
    if args.report:
        return report(cases, grades)

    system, done = rp.SYSTEMS["FS"], {r["key"] for r in read_log()}
    for case in cases:
        for arm in "BC":
            key = f"{case['id']}:{arm}"
            user = rp.build_user("FS", "recommend", {"user": user_text(case, arm)}, cities, profiles)
            if args.dry_run:
                print(f"--- {key}\n{user_text(case, arm)}")
                continue
            if key in done:
                continue
            spent, worst = rp.cost(read_log()), rp.worst_usd("FS", "recommend", system, user)
            if spent + worst > args.max_usd:
                sys.exit(f"stopped: spent ${spent:.2f}, next call could add ${worst:.2f}, over --max-usd {args.max_usd}")
            row = {"key": key, "case": case["id"], "arm": arm, "model": rp.FLASH, "user": user_text(case, arm),
                   "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
            start = time.monotonic()
            try:
                row.update(rp.call_gemini(rp.FLASH, system, user, "low"))
                row["parsed"], row["format_problems"] = rp.check_output("recommend", row["final_text"], allowed)
            except rp.GeminiError as e:
                row["error"] = str(e)
            row["latency_s"] = round(time.monotonic() - start, 2)
            with LOG.open("a") as f:
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
            if "error" in row:  # 실패는 기록하고 멈춘다. 다시 돌리면 이 호출은 건너뛴다.
                sys.exit(f"stopped at {key}: {row['error']}")
            print(key, picks(row), f"{row['latency_s']}s", row["format_problems"] or "ok")


if __name__ == "__main__":
    main()
