"""비용 확인 단계의 시험. 계획: data/exploration/cost-check/plan.md.

추천 호출이 찾은 후보 몇 곳에 대해 검색으로 항공료와 숙박비를 찾게 하고, 코드가 예산과 비교한다.
    python3 scripts/run_cost_check.py --dry-run
    python3 scripts/run_cost_check.py           # GEMINI_API_KEY 필요. 도시마다 검색을 쓰는 호출 1건
    python3 scripts/run_cost_check.py --report
실행 2(--run 2, 기본)는 실행 1의 결과에 따라 좁혔다: 도시 한 곳, 정확한 왕복 날짜, 특정 호텔의 전체 숙박 견적.
조건에 맞는 값을 못 얻으면 평균값으로 대신하지 않고 실패로 남긴다. 실행 1을 다시 보려면 --run 1.
"""
import argparse
import json
import sys
import time

import run_fixed_data_check as fx
import run_profile_exploration as rp

DIR = rp.EXP / "cost-check"
LOG = DIR / "responses.jsonl"
MAX_USD = 1.0
# 사용자가 정한 가정(2026-10-13): 4성급, 1월 중순. 예산은 항공료 포함 300만 원. 1인 1실은 작성자의 가정이다.
TRIP = dict(period="2027년 1월 중순(1월 11일~25일 사이)", budget=3_000_000, nights=(7, 14))
CITIES = {"th-bangkok": "방콕", "tw-taipei": "타이베이", "th-phuket-island": "푸껫", "sg-singapore": "싱가포르", "jp-tokyo": "도쿄", "pt-lisbon": "리스본"}


def user_text(name):
    return f"도시: {name}\n시기: {TRIP['period']}\n인원: 성인 1명, 객실 1개\n출발: 서울(인천)"


EXACT = dict(today="2026-10-13", city="방콕", depart="2027-01-13", back="2027-01-20", nights=7)  # 실행 2의 조회 조건


def exact_text():
    return (f"오늘: {EXACT['today']}\n도시: {EXACT['city']}\n출발: 서울(인천)\n가는 날: {EXACT['depart']}\n오는 날: {EXACT['back']}\n"
            f"숙박: {EXACT['depart']} 체크인, {EXACT['back']} 체크아웃 ({EXACT['nights']}박)\n인원: 성인 1명, 객실 1개")


def exact_judge(d, budget):
    """정확한 날짜의 값이 둘 다 있을 때만 예산과 비교한다. 아니면 실패로 남긴다."""
    f, h = d.get("flight") or {}, d.get("hotel") or {}
    ok = lambda x, key: isinstance(x.get(key), (int, float)) and EXACT["depart"] in str(x.get("dates_checked")) and EXACT["back"] in str(x.get("dates_checked"))
    if not (ok(f, "price_krw") and ok(h, "total_krw")):
        return "실패: 요청한 날짜의 값을 얻지 못함", None
    total = f["price_krw"] + h["total_krw"]
    tax = "" if f.get("taxes_included") is True and h.get("taxes_included") is True else " (세금 포함 여부 미확인)"
    return ("항공+숙박이 예산 안" if total <= budget else "항공+숙박만으로 예산 초과") + tax, total


def judge(flight, hotel, nights, budget):
    """(판정, 항공+숙박 최저, 최고). 식비와 현지 지출은 넣지 않는다. 값이 하나라도 없으면 미확인.
    날짜가 정확히 맞고 세금 포함이 확인된 값이 아니면 판정하지 않고 참고 계산이라고만 적는다."""
    vals = [flight.get("low_krw"), flight.get("high_krw"), hotel.get("low_krw_per_night"), hotel.get("high_krw_per_night")]
    if any(not isinstance(v, (int, float)) for v in vals):
        return "미확인(값을 찾지 못함)", None, None
    low, high = vals[0] + nights * vals[2], vals[1] + nights * vals[3]
    fits_asked = all((x.get("match") or {}).get("dates") == "exact" and (x.get("match") or {}).get("taxes_included") is True for x in (flight, hotel))
    if not fits_asked:
        return "참고 가격으로 계산한 시나리오. 실제 예산 충족은 미확인", low, high
    verdict = "항공+숙박만으로 예산 초과" if low > budget else "항공+숙박이 예산 안" if high <= budget else "범위가 예산에 걸침"
    return verdict, low, high


def self_check():
    m = {"match": {"dates": "exact", "taxes_included": True}}
    f, h = {"low_krw": 400_000, "high_krw": 600_000, **m}, {"low_krw_per_night": 100_000, "high_krw_per_night": 200_000, **m}
    assert judge(f, h, 7, 3_000_000) == ("항공+숙박이 예산 안", 1_100_000, 2_000_000)
    assert judge(f, h, 14, 3_000_000)[0] == "범위가 예산에 걸침" and judge(f, h, 14, 1_500_000)[0] == "항공+숙박만으로 예산 초과"
    loose = dict(f, match={"dates": "same_month", "taxes_included": True})
    assert judge(loose, h, 7, 3_000_000)[0].startswith("참고 가격") and judge(dict(f, match={"dates": "exact", "taxes_included": "unknown"}), h, 7, 1)[0].startswith("참고 가격")
    dates = f"{EXACT['depart']} ~ {EXACT['back']}"
    good = {"flight": {"price_krw": 400_000, "dates_checked": dates, "taxes_included": True}, "hotel": {"total_krw": 700_000, "dates_checked": dates, "taxes_included": True}}
    assert exact_judge(good, 3_000_000) == ("항공+숙박이 예산 안", 1_100_000)
    assert exact_judge({"flight": {"price_krw": 1, "dates_checked": "2027년 1월"}, "hotel": good["hotel"]}, 1)[0].startswith("실패")
    assert judge(f, {"low_krw_per_night": None, "high_krw_per_night": 1}, 7, 1)[0].startswith("미확인")


def read_log():
    return [json.loads(line) for line in LOG.read_text().splitlines()] if LOG.exists() else []


def report2():
    for r in (x for x in read_log() if "error" not in x):
        d = fx.parse(r["final_text"]) or {}
        f, h = d.get("flight") or {}, d.get("hotel") or {}
        pages = [x.get("url") for s in r.get("searches") or [] for x in s.get("results") or []]
        queries = [q for s in r.get("searches") or [] for q in (s.get("input") or {}).get("queries") or []]
        verdict, total = exact_judge(d, TRIP["budget"])
        print(f"## {r['key']}  조회 {r['started_at']}, 검색어 {r['search_requests']}개, API가 돌려준 페이지 {len(pages)}개, {r['latency_s']}s")
        print(f"조회 조건: {exact_text().replace(chr(10), ' / ')} / 4성급 중심가 호텔\n검색어: {queries}")
        print(f"항공: {f.get('price_krw')}원 | {f.get('airline')} | 값의 날짜: {f.get('dates_checked')} | 세금 포함: {f.get('taxes_included')}\n   출처: {f.get('source')}")
        print(f"숙박: {h.get('total_krw')}원 | {h.get('name')} | 값의 날짜: {h.get('dates_checked')} | 세금 포함: {h.get('taxes_included')}\n   출처: {h.get('source')}")
        print(f"찾지 못한 것: {d.get('not_found')}")
        print(f"판정: {verdict}" + (f" (합계 {total:,}원, 예산에서 남는 돈 {TRIP['budget'] - total:,}원, 하루 {(TRIP['budget'] - total) // EXACT['nights']:,}원)" if total else ""))
        print(f"추정 비용 ${rp.cost([r]):.2f}\n")
    print("포함하지 않은 것: 식비, 현지 교통, 바·클럽 등 밤 지출, 여행자 보험, 환전 수수료.")


def report():
    rows = {r["key"]: r for r in read_log() if "error" not in r}
    won = lambda v: f"{v / 10000:.0f}만" if isinstance(v, (int, float)) else "없음"
    for cid, name in CITIES.items():
        r = rows.get(cid)
        d = fx.parse(r["final_text"]) if r else None
        if not d:
            print(f"\n## {name}: {'형식 오류' if r else '기록 없음'}")
            continue
        f, h = d.get("flight") or {}, d.get("hotel") or {}
        pages = [x.get("url") for s in r.get("searches") or [] for x in s.get("results") or []]
        print(f"\n## {name}  조회 {r['started_at']}, 검색어 {r['search_requests']}개, API가 돌려준 페이지 {len(pages)}개, {r['latency_s']}s")
        print(f"조회 조건: {user_text(name).replace(chr(10), ' / ')} / 4성급 중심가 호텔")
        print(f"항공: {won(f.get('low_krw'))}~{won(f.get('high_krw'))}원 | {f.get('basis')}\n   조건 일치: {f.get('match')}\n   모델이 적은 출처: {f.get('sources')}")
        print(f"숙박(1박): {won(h.get('low_krw_per_night'))}~{won(h.get('high_krw_per_night'))}원 | {h.get('basis')}\n   조건 일치: {h.get('match')}\n   모델이 적은 출처: {h.get('sources')}")
        if d.get("not_found"):
            print(f"찾지 못한 것: {d['not_found']}")
        for n in TRIP["nights"]:
            verdict, low, high = judge(f, h, n, TRIP["budget"])
            left = f", 남는 돈 하루 {won((TRIP['budget'] - high) / n)}~{won((TRIP['budget'] - low) / n)}원" if low is not None else ""
            print(f"{n}박: {verdict}" + (f" (항공+숙박 {won(low)}~{won(high)}원{left})" if low is not None else ""))
    done = list(rows.values())
    print(f"\n호출 {len(done)}건, 검색어 {sum(r['search_requests'] for r in done)}개, 추정 비용 ${rp.cost(done):.2f}")
    print("판정은 모델이 돌려준 값으로 코드가 계산한 것이다. 값이 맞는지는 출처를 열어 봐야 한다.")
    print("포함하지 않은 것: 식비, 현지 교통, 바·클럽 등 밤 지출, 여행자 보험, 환전 수수료.")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--report", action="store_true")
    p.add_argument("--run", type=int, default=2, choices=(1, 2))
    args = p.parse_args()
    self_check()
    global LOG
    plan = CITIES if args.run == 1 else {f"{EXACT['city']} {EXACT['depart']}~{EXACT['back']} #{i}": None for i in (1, 2)}  # 실행 2는 같은 조회를 두 번
    if args.run == 2:
        LOG = DIR / "run2" / "responses.jsonl"
    if args.report:
        return report() if args.run == 1 else report2()
    system = (LOG.parent / "prompt.md").read_text().split("\n---\n", 1)[1].strip()
    rp.MAX_TOKENS = 4096
    done = {r["key"] for r in read_log()}
    for cid, name in plan.items():
        user = user_text(name) if args.run == 1 else exact_text()
        if args.dry_run:
            print(f"--- {cid}\n{user}\n")
            continue
        if cid in done:
            continue
        if rp.cost(read_log()) > MAX_USD:
            sys.exit(f"stopped: over ${MAX_USD}")
        row = {"key": cid, "model": rp.FLASH, "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
        start = time.monotonic()
        try:
            res = rp.call_gemini(rp.FLASH, system, user, "low", search=True)
            row.update({k: res[k] for k in ("final_text", "stop_reason", "input_tokens", "output_tokens", "search_requests", "searches")})
        except rp.GeminiError as e:
            row["error"] = str(e)
        row["latency_s"] = round(time.monotonic() - start, 2)
        with LOG.open("a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        if "error" in row:  # 실패는 기록하고 멈춘다. 그 줄을 지우고 다시 돌리면 이어서 한다.
            sys.exit(f"stopped at {cid}: {row['error']}")
        print(cid, f"검색어 {row['search_requests']}", f"{row['latency_s']}s", (row["final_text"] or "")[:120].replace("\n", " "))


if __name__ == "__main__":
    main()
