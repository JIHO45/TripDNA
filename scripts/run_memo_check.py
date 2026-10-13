"""지난 여행 메모 비교. 계획: data/exploration/memo-check/plan.md.

같은 요청에서 지난 여행 메모만 바꿨을 때 추천이 타당하게 달라지는지를 세 방식으로 본다.
검색은 세 방식에 똑같이 준다. 기본은 검색 있음이고 --search off로 끈 실행을 따로 기록한다.
  A  이번 요청만 전달한 일반 질문
  B  같은 요청에 지난 여행 메모를 덧붙인 일반 질문
  T  TripDNA 방식: 개인화 지침 + 도시 자료 + 코드가 만든 후보와 기준 순서
  P  개인화 지침만: T의 지침에서 도시 자료 부분을 빼고, 도시는 이름만 준다
  N  개인화 지침 + 후보마다 강한 경험의 이름만(위 두 단계). 실행 2에서 추가
실행마다 자료·사례·지침을 고정한다. 실행 1은 memo-check/, 실행 2는 memo-check/run2/. 기본은 --run 2.
    python3 scripts/run_memo_check.py --dry-run
    python3 scripts/run_memo_check.py             # GEMINI_API_KEY 필요. 기록된 호출은 건너뛴다.
    python3 scripts/run_memo_check.py --report    # 방식별 순서와 문장
    python3 scripts/run_memo_check.py --sheet     # 방식을 가린 검수 시트와 대응표(실행 2는 run2/sheet4-on.md, key4-on.json)
"""
import argparse
import json
import random
import re
import sys
import time

import run_fixed_data_check as fx
import run_profile_exploration as rp

DIR = rp.EXP / "memo-check"
LOG = DIR / "responses-on.jsonl"  # main()이 --search에 맞춰 바꾼다
MAX_USD = 3.0
PHRASE = {"food": "미식", "relaxation": "휴양", "nature": "자연", "nightlife": "나이트라이프", "culture": "문화·역사", "activities": "액티비티", "city": "도시"}
RUN = 2  # main()이 --run에 맞춰 바꾼다
SHEET_ARMS = "BTPN"


def calls(requests):
    """(키, 방식, 요청, 변형). 실행 1의 키와 순서는 기록과 맞아야 하므로 그대로 둔다."""
    if RUN != 1:
        for req in requests:
            m0 = req["variants"][0]
            yield f"{req['id']}:M0:A", "A", req, m0
            for v in req["variants"]:
                for arm in ("TPN" if v["id"] == "M0" else "BTPN"):
                    yield f"{req['id']}:{v['id']}:{arm}", arm, req, v
        return
    for req in requests:
        m0 = req["variants"][0]
        for rep in (1, 2):
            yield f"{req['id']}:A:{rep}", "A", req, m0
        for v in req["variants"]:
            if v["id"] == "M0":
                for rep in (1, 2):
                    yield f"{req['id']}:M0:T:{rep}", "T", req, v
            else:
                yield f"{req['id']}:{v['id']}:B", "B", req, v
                yield f"{req['id']}:{v['id']}:T", "T", req, v
        for v in req["variants"]:  # 둘째 실행에서 추가. 앞선 키의 순서를 바꾸지 않으려고 뒤에 둔다
            yield f"{req['id']}:{v['id']}:P", "P", req, v


def pool(req, variant):
    visited = {m["city"] for m in variant["memos"]}
    return [c for c in fx.CITIES if fx.fits(c, req) and c not in visited]


def baseline(req, variant):
    """[(주 컨셉 등급, [도시...])] 높은 순. 부 컨셉과 티어가 없는 사례만 다루므로 주 컨셉 등급만 쓴다."""
    groups = {}
    for c in pool(req, variant):
        groups.setdefault(fx.top(fx.CITIES[c], req["main"], req["month"]), []).append(c)
    return sorted(groups.items(), reverse=True)


LEVEL_KO = {3: "여행지를 선택할 만함", 2: "일부러 시간을 낼 만함"}


def strong_text(cid, req):
    """방식 N의 도시 한 곳: 이번 주 컨셉의 단계와, 위 두 단계에 든 세부의 이름. 문장과 낮은 단계는 보내지 않는다."""
    c, m = fx.CITIES[cid], req["month"]
    lines = [f"{cid} {c['name']['ko']} | 이번 주 컨셉({fx.LABEL[req['main']]}): {LEVEL_KO[fx.top(c, req['main'], m)]}"]
    for lv, name in LEVEL_KO.items():
        groups = [f"{v['label']}({', '.join(n for s, n in v['sub'].items() if fx.grade(c, s, m) == lv)})"
                  for v in fx.CONCEPTS.values() if any(fx.grade(c, s, m) == lv for s in v["sub"])]
        if groups:
            lines.append(f"  {name}: " + ", ".join(groups))
    if c["season"]:
        lines.append("  시즌: " + "; ".join(f"{fx.LABEL[s]} {', '.join(map(str, sorted(ms)))}월" for s, ms in c["season"].items() if s in fx.LABEL))
    return "\n".join(lines)


def memo_text(variant):
    if not variant["memos"]:
        return "지난 여행 평가: 없음"
    return "지난 여행 평가:\n" + "\n".join(
        f"- {fx.CITIES[m['city']]['name']['ko']} {'★' * m['stars']} | 좋았던 점: {m['good'] or '(없음)'} | 아쉬웠던 점: {m['bad'] or '(없음)'}"
        for m in variant["memos"])


def user_text(arm, req, variant):
    if arm == "T":
        order = "\n".join(", ".join(ids) for _, ids in baseline(req, variant))
        return f"{fx.request_text(req)}\n\n{memo_text(variant)}\n\n기준 순서:\n{order}\n\n도시 자료:\n\n{fx.city_table(pool(req, variant))}"
    if arm == "N":
        return f"{fx.request_text(req)}\n\n{memo_text(variant)}\n\n도시:\n\n" + "\n\n".join(strong_text(c, req) for c in pool(req, variant))
    if arm == "P":  # 다녀온 도시는 앱이 목록에서 뺀다. 등급으로는 거르지 않는다
        visited = {m["city"] for m in variant["memos"]}
        names = "\n".join(f"- {cid} {c['name']['ko']}" for cid, c in fx.CITIES.items() if cid not in visited)
        return f"{fx.request_text(req)}\n\n{memo_text(variant)}\n\n도시 목록:\n{names}"
    text = f"{PHRASE[req['main']]} 위주의 여행을 가고 싶어." + (f" {req['text']}" if req.get("text") else "") + " 아래 도시 중에서 나한테 맞을 곳 5곳을 순서대로 추천해줘."
    if arm == "B":
        text += "\n\n참고로 내 지난 여행은 이랬어.\n" + "\n".join(
            f"- {fx.CITIES[m['city']]['name']['ko']}: 별점 {m['stars']}/5." + (f" 좋았던 점: {m['good']}" if m["good"] else "")
            + (f" 아쉬웠던 점: {m['bad']}" if m["bad"] else "") for m in variant["memos"]) + "\n다녀온 곳은 빼고 추천해줘."
    return text + "\n\n도시 목록:\n" + "\n".join(f"- {cid} {c['name']['ko']}" for cid, c in fx.CITIES.items())


def ranked(data):
    return [c for c in (data or {}).get("ranked") or [] if isinstance(c, dict)]


def self_check():
    req = dict(id="R", month=None, main="food", detail=None, subs=[], text=None)
    m0 = {"id": "M0", "memos": []}
    v = {"id": "M1", "memos": [{"city": "tr-istanbul", "stars": 4, "good": "a", "bad": ""}]}
    assert "tr-istanbul" not in pool(req, v) and "jp-tokyo" in pool(req, v) and "us-honolulu" not in pool(req, v)
    t = user_text("T", req, v)
    assert "tr-istanbul 이스탄불" not in t and "이스탄불 ★★★★ | 좋았던 점: a | 아쉬웠던 점: (없음)" in t and "기준 순서:" in t
    assert baseline(req, v)[0][0] == 3 and "jp-tokyo" in baseline(req, v)[0][1]
    a, b = user_text("A", req, m0), user_text("B", req, v)
    assert "지난 여행" not in a and "등급" not in a + b and "이스탄불: 별점 4/5. 좋았던 점: a\n다녀온 곳은 빼고" in b
    keys = [k for k, *_ in calls([dict(req, variants=[m0, v])])]
    assert keys == (["R:A:1", "R:A:2", "R:M0:T:1", "R:M0:T:2", "R:M1:B", "R:M1:T", "R:M0:P", "R:M1:P"] if RUN == 1 else
                    ["R:M0:A", "R:M0:T", "R:M0:P", "R:M0:N", "R:M1:B", "R:M1:T", "R:M1:P", "R:M1:N"])
    n = user_text("N", req, v)
    assert "jp-tokyo 도쿄 | 이번 주 컨셉(미식): 여행지를 선택할 만함" in n and "미식(맛집·파인다이닝, 술)" in n and "tr-istanbul" not in n
    assert "핵심 경험" not in n and "기준 순서" not in n and len(n) < len(t) / 3
    pt = user_text("P", req, v)
    assert "등급" not in pt and "기준 순서" not in pt and "tr-istanbul" not in pt and "us-honolulu 호놀룰루" in pt and "이스탄불 ★★★★" in pt


def read_log():
    return [json.loads(line) for line in LOG.read_text().splitlines()] if LOG.exists() else []


def answers(requests):
    rows = {r["key"]: r for r in read_log() if "error" not in r}
    return {key: fx.parse(rows[key]["final_text"]) for key, *_ in calls(requests) if key in rows}, rows


def checks(arm, req, v, data):
    """코드가 세는 참고 숫자. 통과·실패는 B와 T에 같은 기준으로 붙인다."""
    ids = [c.get("id") for c in ranked(data)]
    reasons = [f"{c.get('reason')} {c.get('caveat') or ''}" for c in ranked(data)]
    out = []
    visited = [i for i in ids if i in {m["city"] for m in v["memos"]}]
    unknown = [i for i in ids if i not in fx.CITIES]
    low = [i for i in ids if i in fx.CITIES and not fx.fits(i, req)]
    if visited or unknown or low:
        out.append(f"다녀온 도시 {visited}, 목록 밖 {unknown}, 주 컨셉 2등급 미만 {low}")
    if "prefer" in v:
        n = len(set(ids[:3]) & set(v["prefer"]["ids"]))
        out.append(f"상위 3곳에 기대 도시 {n}곳(기준 {v['prefer']['min']}): {'통과' if n >= v['prefer']['min'] else '실패'}")
    if v.get("expect_unused") and arm in "TPN":
        out.append(f"메모를 쓰지 않아야 함: {'통과' if not data.get('used_memories') else '실패'}")
    if "count_words" in v:
        out.append(f"상위 3곳 이유에 '{v['count_words']}'가 나온 도시 {sum(bool(re.search(v['count_words'], t)) for t in reasons[:3])}곳")
    if "forbid_words" in v:
        hit = re.findall(v["forbid_words"], " ".join(reasons) + json.dumps(data.get("used_memories") or [], ensure_ascii=False))
        out.append(f"나오면 안 되는 낱말 '{v['forbid_words']}': {'없음' if not hit else hit}")
    return out


def report(requests):
    ans, rows = answers(requests)
    for req in requests:
        print(f"\n## {req['id']}  {fx.request_text(req).replace(chr(10), ' / ')}")
        for key, arm, _, v in (c for c in calls(requests) if c[2] is req):
            data = ans.get(key)
            print(f"\n[{key}] {'메모 전달 안 함' if arm == 'A' else memo_text(v).replace(chr(10), ' ')}")
            if data is None:
                print("   형식 오류 또는 기록 없음")
                continue
            g = {c: n for n, cs in baseline(req, v) for c in cs}
            print(f"   순서(괄호는 주 컨셉 등급): {[(c.get('id'), g.get(c.get('id'))) for c in ranked(data)]}")
            for line in checks(arm, req, v, data):
                print(f"   {line}")
            if arm != "A" and "watch" in v:
                print(f"   볼 점: {v['watch']}")
            if arm in "TPN":
                print(f"   쓴 메모: {data.get('used_memories') or []}")
            for c in ranked(data):
                print(f"   {c.get('id')}: {c.get('reason')}" + (f" | 유의: {c['caveat']}" if c.get("caveat") else ""))
            if data.get("note"):
                print(f"   note: {data['note']}")
    for arm in "ABTPN":
        done = [r for r in rows.values() if r["arm"] == arm]
        print(f"[{arm}] 호출 {len(done)}건, 추정 비용 ${rp.cost(done):.2f}, 지연 평균 {sum(r['latency_s'] for r in done) / max(len(done), 1):.1f}s, "
              f"입력 평균 {sum(r['input_tokens'] for r in done) // max(len(done), 1)}토큰, 검색어 {sum(r.get('search_requests', 0) for r in done)}개")
    print("어느 쪽이 그 사람에게 더 맞는지는 사람이 판정한다. --sheet로 방식을 가린 시트를 만든다.")


def sheet(requests):
    """B·T·P를 가린 검수 시트. 1부는 도시 이름만, 2부는 이유 문장. 첫 실행의 sheet-on.md(판정이 적혀 있다)는 건드리지 않는다."""
    ans, _ = answers(requests)
    rnd, key_map, labels = random.Random(2026101202 if RUN == 1 else 20261012 + RUN), {}, "가나다라"[:len(SHEET_ARMS)]
    part1 = ["# 검수 시트 1부: 후보만\n\n사례마다 여러 추천 가운데 이 여행자에게 가장 맞는 쪽과 가장 덜 맞는 쪽을 적는다. 비슷하면 비슷하다고 적는다. 2부는 1부를 끝낸 뒤에 본다.\n"]
    part2 = ["# 검수 시트 2부: 이유 문장\n\n같은 사례의 이유 문장이다. 메모를 넘어서 해석했는지, 이번 요청을 지켰는지, 다른 후보와의 차이를 설명하는지 본다.\n"]
    name = lambda i: fx.CITIES[i]["name"]["ko"] if i in fx.CITIES else str(i)
    for req in requests:
        for v in req["variants"][1:]:
            trio = [f"{req['id']}:{v['id']}:{arm}" for arm in SHEET_ARMS]
            if not all(ans.get(k) for k in trio):
                continue
            rnd.shuffle(trio)
            case = f"{req['id']}-{v['id']}"
            key_map[case] = dict(zip(labels, trio))
            head = f"\n## {case}\n\n이번 요청: {PHRASE[req['main']]} 위주의 여행" + (f". {req['text']}" if req.get("text") else "") + "\n\n" + memo_text(v) + "\n"
            part1.append(head + "".join(f"\n- {lab}: " + " → ".join(name(c.get("id")) for c in ranked(ans[k])) for lab, k in zip(labels, trio))
                         + "\n\n가장 맞는 쪽: \n가장 덜 맞는 쪽: \n이유: \n")
            part2.append(head + "".join(f"\n**{lab}**\n" + "".join(f"\n- {name(c.get('id'))}: {c.get('reason')}" for c in ranked(ans[k])) + "\n"
                                        for lab, k in zip(labels, trio)) + "\n메모: \n")
    mode = LOG.stem.split("-")[1]
    out = DIR / f"sheet{len(SHEET_ARMS)}-{mode}.md"
    if out.exists():
        sys.exit(f"{out.name}이 이미 있다. 판정을 적었을 수 있어 덮어쓰지 않는다. 다시 만들려면 파일을 옮긴 뒤 실행한다.")
    out.write_text("\n".join(part1) + "\n\n---\n\n" + "\n".join(part2))
    (DIR / f"key{len(SHEET_ARMS)}-{mode}.json").write_text(json.dumps(key_map, ensure_ascii=False, indent=1) + "\n")
    print(f"{out.name} ({len(key_map)}개 사례)와 key{len(SHEET_ARMS)}-{mode}.json을 {DIR}에 썼다")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--report", action="store_true")
    p.add_argument("--sheet", action="store_true")
    p.add_argument("--search", choices=("on", "off"), default="on")
    p.add_argument("--run", type=int, default=2)
    args = p.parse_args()
    global LOG, DIR, RUN, SHEET_ARMS
    RUN = args.run
    DIR = DIR if RUN == 1 else DIR / f"run{RUN}"
    SHEET_ARMS = "BTP" if RUN == 1 else "BTPN"
    LOG = DIR / f"responses-{args.search}.jsonl"
    draft = json.loads((DIR / "draft.json").read_text())
    levels = [lv["id"] for lv in draft.get("levels", [])]  # 이름으로 적은 등급은 계산용 0~3으로 바꾼다
    for c in draft["cities"].values():
        c["grades"] = {s: levels.index(g) if levels else g for s, g in c["grades"].items()}
    fx.CITIES.update(draft["cities"])
    requests = json.loads((DIR / "cases.json").read_text())["requests"]
    parts = [s.strip() for s in (DIR / "prompt.md").read_text().split("\n---\n")]
    systems = {"T": parts[1], "A": parts[2], "B": parts[2], "P": parts[3], **({"N": parts[4]} if len(parts) > 4 else {})}
    self_check()
    if args.report:
        return report(requests)
    if args.sheet:
        return sheet(requests)
    rp.MAX_TOKENS = 4096
    done = {r["key"] for r in read_log()}
    for key, arm, req, v in calls(requests):
        user = user_text(arm, req, v)
        if args.dry_run:
            print(f"--- {key}\n{user if arm != 'T' else user.split(chr(10) + chr(10) + '도시 자료:')[0] + f'{chr(10)}(도시 자료 {len(pool(req, v))}곳 생략)'}\n")
            continue
        if key in done:
            continue
        spent = rp.cost(read_log())
        if spent > MAX_USD:
            sys.exit(f"stopped: spent ${spent:.2f}, over ${MAX_USD}")
        row = {"key": key, "arm": arm, "model": rp.FLASH, "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
        start = time.monotonic()
        try:
            res = rp.call_gemini(rp.FLASH, systems[arm], user, "low", search=args.search == "on")
            row.update({k: res[k] for k in ("final_text", "stop_reason", "input_tokens", "output_tokens", "search_requests", "searches")})
        except rp.GeminiError as e:
            row["error"] = str(e)
        row["latency_s"] = round(time.monotonic() - start, 2)
        with LOG.open("a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        if "error" in row:  # 실패는 기록하고 멈춘다. 그 줄을 지우고 다시 돌리면 이어서 한다.
            sys.exit(f"stopped at {key}: {row['error']}")
        print(key, [c.get("id") for c in ranked(fx.parse(row["final_text"]))], f"검색어 {row['search_requests']}", f"{row['latency_s']}s")


if __name__ == "__main__":
    main()
