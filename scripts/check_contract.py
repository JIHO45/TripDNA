"""계약 확인 실험의 입력 조립과 응답 검사기. 계약: docs/llm/README.md 5절.

가짜 응답으로 검사기가 조건 누락·거짓 승인·근거 없는 탈락·제외 예외·예산을 잡는지 먼저 본다(self_check).
도시 자료는 고정 자료 실행 2의 20곳(이전 숫자 등급으로 매긴 미검수 초안)을 그대로 쓴다. 계획: data/exploration/contract-check/plan.md
    python3 scripts/check_contract.py                      # 가짜 응답 검사
    python3 scripts/check_contract.py --show F11           # 그 사례의 사용자 메시지 출력
    .venv/bin/python scripts/check_contract.py --dry-run   # 호출 목록과 호출당 최대 비용
    .venv/bin/python scripts/check_contract.py --run       # 호출. GEMINI_API_KEY, ANTHROPIC_API_KEY 필요. 기록된 호출은 건너뛴다
    python3 scripts/check_contract.py --report             # 기록을 계약대로 검사해 출력
    (실행 2 이후는 --exp 2를 붙인다. 지침·사례·기록이 run2/에 있다. 실행 2 계획: data/exploration/contract-check/run2/plan.md)
"""
import argparse
import json
import re
import sys
import time

import run_fixed_data_check as fd

BASE = fd.rp.EXP / "contract-check"
NAMES = {3: "여행지를 선택할 만함", 2: "일부러 시간을 낼 만함", 1: "간다면 즐길 만함", 0: "찾지 못함"}
NOT_JUDGED = {"duration", "budget"}  # 비교할 도시 자료가 없다. 판정 대상에 넣으면 모든 카드가 "확인 필요"가 된다
fd.CITIES.update(json.loads((fd.BASE / "run2/draft.json").read_text())["cities"])


def level(city, key, month):
    """세부면 그 세부, 큰 컨셉이면 세부의 최댓값. 시즌 밖 세부는 0."""
    return fd.top(city, key, month) if key in fd.CONCEPTS else fd.grade(city, key, month)


def base_order(case):
    """주 컨셉 문턱을 넘는 도시를 주 컨셉 등급, 부 컨셉 등급 합의 순서로. 동점은 자료 순서."""
    # ponytail: 티어 가중치는 뺐다. 사례에 티어가 생기면 추천 구조의 순위 계산 3번을 더한다
    main = case["detail"] or case["main"]
    fit = [cid for cid in fd.CITIES if fd.fits(cid, case)]
    key = lambda cid: (level(fd.CITIES[cid], main, case["month"]),
                       sum(level(fd.CITIES[cid], s, case["month"]) for s in case["subs"]))
    return sorted(fit, key=key, reverse=True)


def visited_off(case):
    """다녀온 곳 포함을 끈 경우(include_visited false)의 지난 여행 도시 ID. 예외 대상이 아니다."""
    return {t["city_id"] for t in case.get("trips", []) if t.get("city_id")} if case.get("include_visited") is False else set()


def exclusion_mark(case, cid, overrides=()):
    """이 도시를 빼는 이유. 없으면 None. 제외는 "country:JP" 또는 "city:<id>"."""
    if cid in visited_off(case):
        return "다녀온 곳"
    country = f"country:{fd.CITIES[cid]['country']}"
    return next((r for r in case.get("exclude", []) if r not in overrides and r in (f"city:{cid}", country)), None)


def excluded(case, overrides=()):
    """계속 제외에서 이번 요청 예외를 뺀 도시와, 다녀온 곳 제외 설정의 도시."""
    return {cid for cid in fd.CITIES if exclusion_mark(case, cid, overrides)}


def user_message(case):
    month, main = case["month"], case["detail"] or case["main"]
    out = [l for l in fd.request_text(case).split("\n") if not l.startswith(("시기", "바라는 점"))]
    screen = [("period", f"{month}월" if month else None), ("duration", case.get("days") and f"{case['days']}일"),
              ("budget", case.get("budget") and f"{case['budget']:,}원")]
    out.append("앱이 받은 조건: " + (", ".join(f"{i}={v}" for i, v in screen if v) or "없음"))
    out.append(f"\n[사용자 데이터: 바라는 점]\n{case.get('text') or '없음'}")
    trips = case.get("trips", [])
    out.append("\n[사용자 데이터: 지난 여행]\n" + ("\n".join(
        f"{t['id']} {t['city']} 별점 {t['stars']} 메모: {t.get('note') or '없음'}" for t in trips) or "없음"))
    out.append(f"\n계속 제외: {', '.join(case.get('exclude', [])) or '없음'}")
    if "include_visited" in case:  # 이 설정이 있는 사례에만 줄을 더한다. 실행 1 사례의 입력은 그대로다
        out.append(f"다녀온 곳 포함: {'예' if case['include_visited'] else '아니요'}")
    off = excluded(case)
    rows = []
    for n, cid in enumerate(base_order(case), 1):
        c = fd.CITIES[cid]
        mark = f" [제외됨: {exclusion_mark(case, cid)}]" if cid in off else ""
        subs = "; ".join(f"{fd.LABEL[s]} {NAMES[level(c, s, month)]}" for s in case["subs"])
        unverified = [fd.LABEL[s] for s in c["season_unverified"] if s in fd.LABEL]
        core = [f"{fd.LABEL[s]}: {t}" for s, t in c["core"].items()
                if s in fd.LABEL and (s == main or s in case["subs"] or s in fd.CONCEPTS.get(main, {}).get("sub", {}))]
        rows.append("\n".join(filter(None, [
            f"기준 순서 {n} | {cid} {c['name']['ko']} | {c['country']}{mark}",
            f"{fd.LABEL[main]}: {NAMES[level(c, main, month)]}" + (f" | 부 컨셉: {subs}" if subs else ""),
            unverified and "시즌 미확인 세부: " + ", ".join(unverified),
            "핵심 경험: " + " / ".join(core)])))
    out.append("\n도시 표:\n\n" + ("\n\n".join(rows) or "조건에 맞는 도시 없음"))
    return "\n".join(out)


SCHEMA = json.loads((BASE / "schema.json").read_text())
TYPES = {"object": dict, "array": list, "string": str, "boolean": bool}


def schema_errors(s, v, path="$"):
    """schema.json이 쓰는 기능(type, properties, required, additionalProperties: false, items, enum)만 검사한다."""
    # ponytail: jsonschema가 두 환경 모두 없어 최소 구현. schema에 다른 키워드를 쓰게 되면 jsonschema로 바꾼다
    if not isinstance(v, TYPES[s["type"]]) or (s["type"] != "boolean" and isinstance(v, bool)):
        return [f"{path}: {s['type']} 아님"]
    if "enum" in s and v not in s["enum"]:
        return [f"{path}: 허용 값 아님 {v!r}"]
    out = []
    if s["type"] == "object":
        out += [f"{path}.{k}: 없음" for k in s.get("required", []) if k not in v]
        out += [f"{path}.{k}: 정의되지 않은 필드" for k in v if k not in s.get("properties", {})]
        out += [e for k, sub in s.get("properties", {}).items() if k in v for e in schema_errors(sub, v[k], f"{path}.{k}")]
    if s["type"] == "array":
        out += [e for i, x in enumerate(v) for e in schema_errors(s["items"], x, f"{path}[{i}]")]
    return out


def inspect(case, text):
    """응답 원문 → JSON 파싱 → schema 검사 → 계약 검사. 앞 단계에서 실패하면 형식 실패로 끝낸다."""
    data = fd.parse(text)
    errors = schema_errors(SCHEMA, data) if data is not None else ["JSON을 읽지 못함"]
    if errors:
        return data, {"cards": [], "problems": [f"형식 실패: {e}" for e in errors], "unverified_drops": []}
    return data, check(case, data)


def season_unverified(cid, case):
    """시기를 넣었는데, 후보가 기대는 세부(세부를 골랐으면 그 세부, 아니면 문턱을 넘긴 세부 전부)의 시즌이 미확인인가."""
    c, m = fd.CITIES[cid], case["month"]
    subs = [case["detail"]] if case["detail"] else [s for s in fd.CONCEPTS[case["main"]]["sub"] if fd.grade(c, s, m) >= 2]
    return bool(m and subs) and all(s in c["season_unverified"] for s in subs)


# 사용자에게 보이는 문장의 명확한 내부 표현. "표"·"데이터" 같은 일반 단어는 넣지 않는다
INTERNAL = re.compile("|".join([
    r"(?<![A-Za-z0-9])f\d+(?![A-Za-z0-9])",                              # 조건 ID
    r"\b(?:unknown|met|not_met|confirmed|unconfirmed|needs_check)\b",     # 상태 값
    r"\b(?:period|duration|budget|candidates|failed|passed_over|memories_used|order_note|exclusion_overrides)\b",
    r"\b[a-z]{2}-[a-z]+(?:-[a-z]+)*\b",                                   # 도시 ID(jp-tokyo)
    r"country:[A-Z]{2}", r"기준 순서", r"등급", *NAMES.values()]))


def internal_terms(text):
    return sorted({m.group(0) for m in INTERNAL.finditer(text or "")})


def visible_texts(data):
    """추천 화면 문서가 보여주는 필드: 이해 요약, 지난 여행에서 참고한 내용, 카드의 이유·유의점, 적을 때의 설명.
    order_note는 표시 여부가 정해지지 않아 넣지 않는다."""
    yield "understanding", (data.get("request") or {}).get("understanding")
    for m in data.get("memories_used") or []:
        yield "memories_used.how", m.get("how")
    for c in data.get("candidates") or []:
        yield f"{c.get('id')}.reason", c.get("reason")
        yield f"{c.get('id')}.caveat", c.get("caveat")
    yield "note", data.get("note")


def check(case, data):
    """응답을 계약대로 검사한다. 반환: cards(표시 후보), problems(위반), unverified_drops(검증 안 된 탈락)."""
    problems, text = [], case.get("text") or ""
    req = data.get("request") or {}
    conds = {c.get("id"): c for c in req.get("conditions") or []}
    order = base_order(case)

    # 제외 예외: 계속 제외에 있고 근거 문장이 원문에 있을 때만 적용한다
    applied = []
    for o in req.get("exclusion_overrides") or []:
        if o.get("target") not in case.get("exclude", []):
            problems.append(f"없는 제외에 대한 예외: {o.get('target')}")
        elif not o.get("quote") or o["quote"] not in text:
            problems.append(f"원문에 없는 예외 근거: {o.get('target')}")
        else:
            applied.append(o["target"])
    off = excluded(case, applied)

    # 조건 완전성: 판정 대상만 본다. 기간·예산은 빠져도, 들어 있어도 카드에 영향이 없다
    if case["month"] and "period" not in conds:
        problems.append("시기 조건이 요청 해석에 없음")
    free = [i for i in conds if i not in NOT_JUDGED | {"period"}]
    required = [i for i in free if conds[i].get("required")]

    cards, seen = [], set()
    for c in data.get("candidates") or []:
        cid = c.get("id")
        if cid not in fd.CITIES:
            problems.append(f"목록에 없는 ID: {cid}")
            continue
        if cid in seen:
            problems.append(f"중복: {cid}")
            continue
        seen.add(cid)
        if cid in off:
            problems.append(f"제외 위반: {cid}")
            continue
        if cid not in order:
            problems.append(f"주 컨셉 문턱 미달(시즌 적용): {cid}")
            continue
        reported = {r.get("id"): r for r in c.get("conditions") or []}
        for i in free:
            if i not in reported:
                problems.append(f"{cid}: 조건 {i} 보고 없음")
            elif reported[i].get("llm_status") == "met":
                problems.append(f"{cid}: 조건 {i}를 LLM이 충족으로 표시(근거 인정 안 됨)")
        # ponytail: 자유문장 조건은 비교할 자료가 없어 전부 unconfirmed다. 비행·기후 자료와 인정 출처가 생기면 유형별 비교를 더한다
        cards.append({"id": cid, "label": "확인 필요" if required or season_unverified(cid, case) else "확인됨"})

    # 조건 탈락 재검증: 코드가 불충족을 확인한 것(지금은 시즌)만 인정한다. 카드로 되살리지는 않는다
    unverified = []
    for f in data.get("failed") or []:
        if f.get("condition_id") == "period" and f.get("id") in fd.CITIES and not fd.fits(f["id"], case):
            continue
        unverified.append(f.get("id"))
        problems.append(f"검증되지 않은 탈락: {f.get('id')} ({f.get('condition_id')})")

    # 누락: 기준 순서에서 고른 마지막 후보보다 위인데 어디에도 없는 도시
    chosen = [cid for cid in order if cid in seen]
    if chosen:
        accounted = seen | {f.get("id") for f in data.get("failed") or []} | {p.get("id") for p in data.get("passed_over") or []}
        for cid in order[:order.index(chosen[-1])]:
            if cid not in accounted and cid not in off:
                problems.append(f"말없이 빠짐: {cid}")
    for cid in case.get("must_include", []):
        if cid not in seen:
            problems.append(f"사례의 필수 후보 없음: {cid}")

    for where, text in visible_texts(data):
        for term in internal_terms(text):
            problems.append(f"내부 표현 {where}: {term}")

    trips = {t["id"] for t in case.get("trips", [])}
    for m in data.get("memories_used") or []:
        if m.get("trip_id") not in trips:
            problems.append(f"입력에 없는 여행: {m.get('trip_id')}")
    return {"cards": cards[:3], "problems": problems, "unverified_drops": unverified}


def self_check():
    """가짜 응답으로 검사 규칙을 하나씩 확인한다."""
    case = {"id": "T", "month": 7, "main": "relaxation", "detail": "beach", "subs": [], "budget": 3000000, "days": 5,
            "text": "이번에는 태국 여행도 괜찮아요. 우기는 꼭 피하고 싶어요.", "exclude": ["country:TH", "city:us-honolulu"],
            "trips": [{"id": "t1", "city": "다낭", "stars": 5, "note": "바다가 좋았다"}]}
    order = base_order(case)
    assert all(fd.fits(c, case) for c in order) and {"th-phuket-island", "us-honolulu"} <= set(order)
    top = [c for c in order if c not in excluded(case)]
    a, b = top[0], top[1]
    ok_req = {"understanding": "x", "exclusion_overrides": [], "depends_on": [],
              "conditions": [{"id": "period", "required": True},
                             {"id": "f1", "text": "우기 회피", "type": "weather", "required": True, "quote": "우기는 꼭 피하고"}]}
    unknown = [{"id": "f1", "value": "", "scope": "", "ref": "", "llm_status": "unknown"}]
    good = {"request": ok_req, "candidates": [{"id": a, "reason": "해변", "caveat": "우기 확인 필요", "order_note": "", "conditions": unknown},
                                              {"id": b, "reason": "해변", "caveat": "", "order_note": "", "conditions": unknown}],
            "failed": [], "passed_over": [], "memories_used": [{"trip_id": "t1", "how": "바다"}], "note": ""}
    r = check(case, good)
    assert r["problems"] == [], r["problems"]
    assert [c["label"] for c in r["cards"]] == ["확인 필요"] * 2  # 필수 자유문장 조건은 근거가 없으면 확인 필요

    def bad(**kw):
        d = json.loads(json.dumps(good))
        for k, v in kw.items():
            d[k] = v
        return check(case, d)["problems"]

    # 조건 누락: 후보가 조건을 보고하지 않거나, 요청 해석에서 시기를 빼면 위반
    assert any("보고 없음" in p for p in bad(candidates=[dict(good["candidates"][0], conditions=[]), good["candidates"][1]]))
    assert any("시기 조건" in p for p in bad(request=dict(ok_req, conditions=ok_req["conditions"][1:])))
    # 거짓 승인: 값과 URL이 있어도 LLM의 met은 인정하지 않는다
    lie = [{"id": "f1", "value": "건기", "scope": "7월", "ref": "https://example.com", "llm_status": "met"}]
    assert any("충족으로 표시" in p for p in bad(candidates=[dict(good["candidates"][0], conditions=lie), good["candidates"][1]]))
    # 근거 없는 탈락과 말없이 빠짐
    r = check(case, dict(good, candidates=[good["candidates"][1]], failed=[{"id": a, "condition_id": "f1", "value": "우기", "ref": ""}]))
    assert r["unverified_drops"] == [a] and a not in [c["id"] for c in r["cards"]]
    assert any("말없이 빠짐" in p for p in bad(candidates=[good["candidates"][1]]))
    assert not any("말없이 빠짐" in p for p in bad(candidates=[good["candidates"][1]], passed_over=[{"id": a, "why": "다녀옴"}]))
    # 제외 예외: 원문 근거가 있으면 적용, 없으면 위반이고 제외 유지
    def with_override(cid, target, quote):
        cands = [dict(good["candidates"][0], id=cid)] + good["candidates"]
        return check(case, dict(good, candidates=cands, request=dict(ok_req, exclusion_overrides=[{"target": target, "quote": quote}])))
    r = with_override("th-phuket-island", "country:TH", "이번에는 태국 여행도 괜찮아요")
    assert r["problems"] == [] and r["cards"][0]["id"] == "th-phuket-island", r["problems"]
    p = with_override("us-honolulu", "city:us-honolulu", "하와이도 좋아요")["problems"]
    assert any("원문에 없는 예외" in x for x in p) and any("제외 위반" in x for x in p)
    assert any("제외 위반" in x for x in check(case, dict(good, candidates=[dict(good["candidates"][0], id="th-phuket-island")]))["problems"])
    # 예산·기간: 빠져도, 필수로 들어 있어도 위반이나 확인 필요를 만들지 않는다
    no_free = dict(ok_req, conditions=[{"id": "period", "required": True}, {"id": "budget", "required": True},
                                       {"id": "duration", "required": True}])
    r = check(case, dict(good, request=no_free))
    assert r["problems"] == [] and [c["label"] for c in r["cards"]] == ["확인됨"] * 2
    # 기억·문장·ID
    assert any("입력에 없는 여행" in p for p in bad(memories_used=[{"trip_id": "t9", "how": "x"}]))
    assert any("내부 표현" in p for p in bad(candidates=[dict(good["candidates"][0], reason="해변이 여행지를 선택할 만함"), good["candidates"][1]]))
    assert internal_terms("f1 조건은 unknown, 기준 순서 2위, jp-tokyo") == ["f1", "jp-tokyo", "unknown", "기준 순서"]
    assert internal_terms("자료 표에 날씨 데이터가 없어 확인하지 못했습니다. 3월, A1 게이트") == []
    assert any("내부 표현 note: f1" in p for p in bad(note="f1은 확인되지 않았습니다"))
    assert any("목록에 없는 ID" in p for p in bad(candidates=[dict(good["candidates"][0], id="xx-none")]))
    msg = user_message(case)
    assert "th-phuket-island 푸껫 | TH [제외됨: country:TH]" in msg and "us-honolulu 호놀룰루 | US [제외됨: city:us-honolulu]" in msg
    # 사후 schema 검사: 맞는 응답은 통과하고, 필드 누락·타입 오류·정의 밖 필드·허용 밖 값은 중단 없이 형식 실패가 된다
    valid = {"request": {"understanding": "x", "depends_on": [], "exclusion_overrides": [],
                         "conditions": [{"id": "period", "text": "7월", "type": "period", "required": True, "quote": ""}]},
             "candidates": [{"id": a, "reason": "해변", "caveat": "", "order_note": "", "conditions": []}],
             "failed": [], "passed_over": [], "memories_used": [], "note": ""}
    fmt = lambda d: [x for x in inspect(case, json.dumps(d, ensure_ascii=False))[1]["problems"] if x.startswith("형식 실패")]
    assert fmt(valid) == [], fmt(valid)
    assert fmt({k: v for k, v in valid.items() if k != "failed"}) == ["형식 실패: $.failed: 없음"]
    assert fmt(dict(valid, request=dict(valid["request"], conditions="x"))) == ["형식 실패: $.request.conditions: array 아님"]
    assert fmt(dict(valid, extra=1)) == ["형식 실패: $.extra: 정의되지 않은 필드"]
    bad_status = dict(valid["candidates"][0], conditions=[{"id": "f1", "value": "", "scope": "", "ref": "", "llm_status": "yes"}])
    assert fmt(dict(valid, candidates=[bad_status])) == ["형식 실패: $.candidates[0].conditions[0].llm_status: 허용 값 아님 'yes'"]
    assert fmt(dict(valid, note=True)) == ["형식 실패: $.note: string 아님"]
    assert inspect(case, "없음")[1]["problems"] == ["형식 실패: JSON을 읽지 못함"]
    # 시즌 미확인: 시기를 넣었고 기대는 세부의 시즌이 미확인이면 확인 필요. 시기가 없으면 확인됨
    sports = {"id": "S", "month": 3, "main": "event", "detail": "sports", "subs": []}
    assert "sports" in fd.CITIES["tr-istanbul"]["season_unverified"] and "tr-istanbul" in base_order(sports)
    cards = check(sports, {"request": {"conditions": [{"id": "period"}]},
                           "candidates": [{"id": "tr-istanbul"}, {"id": "us-new-york"}]})["cards"]
    assert [c["label"] for c in cards] == ["확인 필요", "확인됨"], cards
    assert season_unverified("tr-istanbul", sports) and not season_unverified("tr-istanbul", dict(sports, month=None))
    # 다녀온 곳 제외: include_visited false면 지난 여행 도시를 빼고, 그 제외에는 예외를 받지 않는다. 기본(키 없음·true)은 포함
    v = {"id": "V", "month": None, "main": "food", "detail": "street", "subs": [], "include_visited": False, "text": "",
         "trips": [{"id": "t1", "city": "방콕", "city_id": "th-bangkok", "stars": 3, "note": None}]}
    assert excluded(v) == {"th-bangkok"} and excluded(dict(v, include_visited=True)) == set()
    assert "th-bangkok 방콕 | TH [제외됨: 다녀온 곳]" in user_message(v) and "다녀온 곳 포함: 아니요" in user_message(v)
    assert "다녀온 곳 포함" not in user_message({k: x for k, x in v.items() if k != "include_visited"})
    pv = check(v, {"request": {"exclusion_overrides": [{"target": "다녀온 곳", "quote": ""}]}, "candidates": [{"id": "th-bangkok"}]})["problems"]
    assert any("없는 제외에 대한 예외" in x for x in pv) and any("제외 위반: th-bangkok" in x for x in pv)
    # 날짜 확인 안내: 축제·경기·공연 사례의 카드마다 유의점에 날짜·일정이 있어야 한다
    fest = {"id": "E", "month": 10, "main": "event", "detail": "festival", "subs": []}
    two = [c for c in base_order(fest)][:2]
    d = {"request": {"conditions": [{"id": "period"}]}, "candidates": [{"id": two[0], "caveat": "정확한 날짜를 확인하세요"},
                                                                        {"id": two[1], "caveat": ""}]}
    assert expectations(fest, d, check(fest, d)) == [f"기대 날짜 확인 안내 없음: {two[1]}"]
    print("self_check ok")


HAIKU = "claude-haiku-5-5"
fd.rp.PRICES[HAIKU] = (0.10, 0.50)  # Anthropic 단가표 2026-10-06 기준, 프롬프트 10만 토큰 이하
ARMS = {"flash": dict(model=fd.rp.FLASH, reps=1), "haiku": dict(model=HAIKU, reps=2)}
MAX_TOKENS, MAX_USD = 8192, 1.50
EXP = 1  # 실행 번호. main()이 --exp로 정한다. 실행 1은 폴더 바로 아래, 실행 n은 run{n}/의 지침·사례·기록을 쓴다
EVENTS = {"festival", "sports", "concert"}


def run_dir(exp=None):
    exp = exp or EXP
    return BASE if exp == 1 else BASE / f"run{exp}"


def log_path(exp=None):
    return run_dir(exp) / "responses.jsonl"


def load_cases(exp=None):
    """실행 1의 사례(회귀 13 + 새 계약 8)에 그 실행에서 더한 사례를 붙인다. 더한 사례는 new=True."""
    exp = exp or EXP
    old = [c for p in (fd.BASE / "run2/cases.json", BASE / "cases.json") for c in json.loads(p.read_text())["cases"]]
    new = json.loads((run_dir(exp) / "cases.json").read_text())["cases"] if exp > 1 else []
    return old + [dict(c, new=True) for c in new]


def system_prompt():
    body = (run_dir() / "prompt.md").read_text().split("\n---\n", 1)[1].strip()
    return f"{body}\n\nSchema:\n{(BASE / 'schema.json').read_text().strip()}"


def todo():
    return [(c, arm, r) for c in load_cases() for arm, cfg in ARMS.items() for r in range(1, cfg["reps"] + 1)]


def worst_usd(model, system, user):
    price_in, price_out = fd.rp.PRICES[model]
    return ((len(system) + len(user)) * 2 * price_in + MAX_TOKENS * price_out) / 1e6


def call(client, model, system, user):
    if model == fd.rp.FLASH:
        fd.rp.MAX_TOKENS = MAX_TOKENS
        res = fd.rp.call_gemini(model, system, user, "low", search=False)
        return {k: res[k] for k in ("final_text", "stop_reason", "input_tokens", "output_tokens")}
    resp = client.messages.create(model=model, max_tokens=MAX_TOKENS, system=system, output_config={"effort": "medium"},
                                  messages=[{"role": "user", "content": user}])
    # 추론 블록은 기록하지 않는다. 답은 text 블록뿐이다. 거절(refusal)도 그대로 기록하고 형식 실패로 센다
    return dict(final_text="".join(b.text for b in resp.content if b.type == "text"), stop_reason=resp.stop_reason,
                input_tokens=resp.usage.input_tokens, output_tokens=resp.usage.output_tokens)


def run(dry):
    system, rows = system_prompt(), fd.read_log(log_path())
    done = {r["key"] for r in rows}
    client = None
    if not dry and any(ARMS[a]["model"] == HAIKU for _, a, _ in todo()):
        import anthropic
        client = anthropic.Anthropic(max_retries=0)
    total = 0.0
    for case, arm, rep in todo():
        key, model, user = f"{case['id']}:{arm}:r{rep}", ARMS[arm]["model"], user_message(case)
        worst = worst_usd(model, system, user)
        if dry:
            total += worst
            print(f"{key:14s} 입력 {len(system) + len(user):6d}자  최대 ${worst:.4f}")
            continue
        if key in done:
            continue
        spent = fd.rp.cost(fd.read_log(log_path()))
        if spent + worst > MAX_USD:
            sys.exit(f"stopped: spent ${spent:.4f}, next call could add ${worst:.4f}, over ${MAX_USD}")
        row = {"key": key, "case": case["id"], "arm": arm, "rep": rep, "model": model,
               "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
        start = time.monotonic()
        try:
            row.update(call(client, model, system, user))
        except Exception as e:  # 실패는 기록하고 멈춘다. 그 줄을 지우고 다시 돌리면 이어서 한다
            row["error"] = f"{type(e).__name__}: {e}"
        row["latency_s"] = round(time.monotonic() - start, 2)
        with log_path().open("a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        if "error" in row:
            sys.exit(f"stopped at {key}: {row['error']}")
        _, r = inspect(case, row["final_text"])
        print(key, [(c["id"], c["label"]) for c in r["cards"]], f"문제 {len(r['problems'])}", f"{row['latency_s']}s")
    if dry:
        print(f"호출 {len(todo())}회, 최대 합계 ${total:.2f} (상한 ${MAX_USD})")


KINDS = [("기대 날짜", "날짜 안내 없음"), ("기대 표시", "표시 상태 불일치"), ("기대", "사례 기대 불일치"), ("형식", "형식 실패"), ("목록에 없는", "목록 밖 ID"), ("중복", "중복"), ("제외 위반", "제외 위반"),
         ("예외", "예외 근거"), ("시기 조건", "시기 조건 누락"), ("보고 없음", "조건 보고 누락"),
         ("충족으로 표시", "LLM met"), ("검증되지 않은 탈락", "검증 안 된 탈락"), ("말없이 빠짐", "말없이 빠짐"),
         ("필수 후보", "필수 후보 없음"), ("입력에 없는 여행", "여행 ID"), ("내부 표현", "내부 표현"),
         ("문턱", "문턱 미달")]  # 앞에서부터 맞는 첫 항목. "기대 예외 ..."가 예외 근거로 가지 않게 기대가 먼저다


def expectations(case, data, r):
    """사례 파일의 기대(예외, 금지, 표시 상태, 빈 결과). check()가 보지 않는 사례별 항목이다."""
    out = []
    applied = [o.get("target") for o in (data.get("request") or {}).get("exclusion_overrides") or []]
    if "expect_override" in case and (case["expect_override"] is None) != (not applied):
        out.append(f"기대 예외 {case['expect_override']}, 응답 {applied}")
    for rule in case.get("forbid", []):
        bad = [c["id"] for c in r["cards"] if rule in (f"city:{c['id']}", f"country:{fd.CITIES[c['id']]['country']}")]
        if bad:
            out.append(f"기대 금지 {rule}: {bad}")
    required = case.get("stated") or case.get("free_text") == "required"
    for c in r["cards"]:
        want = "확인 필요" if required or season_unverified(c["id"], case) else "확인됨"
        if c["label"] != want:
            out.append(f"기대 표시 {c['id']} {want}, 응답 {c['label']}")
    if case.get("expect_empty") and r["cards"]:
        out.append("기대 빈 결과")
    # 축제·경기·공연에 기대는 카드는 정확한 날짜 확인을 안내해야 한다. 단어로만 센다(날짜·일정)
    if case.get("date_check") or (case["detail"] in EVENTS and case["month"]):
        caveats = {c.get("id"): c.get("caveat") or "" for c in data.get("candidates") or []}
        for c in r["cards"]:
            if not re.search("날짜|일정", caveats.get(c["id"], "")):
                out.append(f"기대 날짜 확인 안내 없음: {c['id']}")
    return out


def problems_of(case, text):
    data, r = inspect(case, text)
    ok = not any(p.startswith("형식 실패") for p in r["problems"])
    return (data if ok else None), r, r["problems"] + (expectations(case, data, r) if ok else [])


def tally_rows(cases, rows):
    """{arm: {"calls": n, "with": 문제 있는 응답 수, 종류: 건수}}"""
    out = {}
    for row in rows:
        t = out.setdefault(row["arm"], {"calls": 0})
        t["calls"] += 1
        kinds = {next((name for word, name in KINDS if word in p), "기타") for p in problems_of(cases[row["case"]], row["final_text"])[2]}
        for k in kinds:  # 응답 수로 센다. 한 응답의 같은 종류 여러 건은 1로
            t[k] = t.get(k, 0) + 1
    return out


def report():
    cases = {c["id"]: c for c in load_cases()}
    rows = [r for r in fd.read_log(log_path()) if "error" not in r]
    tally = {arm: {} for arm in ARMS}
    for row in rows:
        case = cases[row["case"]]
        data, r, problems = problems_of(case, row["final_text"])
        for p in problems:
            kind = next((name for word, name in KINDS if word in p), "기타")
            tally[row["arm"]][kind] = tally[row["arm"]].get(kind, 0) + 1
        req = (data or {}).get("request") or {}
        print(f"\n## {row['key']}  ({row['latency_s']}s)")
        print(f"이해: {req.get('understanding')}")
        print(f"조건: {[(c.get('id'), c.get('text'), c.get('required')) for c in req.get('conditions') or []]}")
        print(f"카드: {[(c['id'], c['label']) for c in r['cards']]}")
        for c in (data or {}).get("candidates") or []:
            print(f"   {c.get('id')} | {c.get('reason')} | 유의: {c.get('caveat')} | 순서: {c.get('order_note')}")
        for name in ("failed", "passed_over", "memories_used"):
            if (data or {}).get(name):
                print(f"   {name}: {data[name]}")
        if (data or {}).get("note"):
            print(f"   note: {data['note']}")
        for p in problems:
            print(f"   ! {p}")
    print("\n## 합계 (문장 내용은 사람이 읽어야 한다)")
    for arm in ARMS:
        done = [r for r in rows if r["arm"] == arm]
        if done:
            print(f"[{arm}] 호출 {len(done)}건 | 비용 ${fd.rp.cost(done):.4f} | 지연 평균 "
                  f"{sum(r['latency_s'] for r in done) / len(done):.1f}s | 문제 {tally[arm] or '없음'}")
    if EXP > 1:
        # 입력이 같은 기존 사례만 실행 1과 비교한다. 이번 실행에서 더한 사례는 따로 센다. 수치는 문제가 있던 응답 수다
        old = {k for k, c in cases.items() if not c.get("new")}
        prev = [r for r in fd.read_log(log_path(1)) if "error" not in r and r["case"] in old]
        print(f"\n## 기존 사례 {len(old)}개: 실행 1 대 실행 {EXP} (같은 입력, 지침만 다름)")
        for name, rs in ((f"실행 1", prev), (f"실행 {EXP}", [r for r in rows if r["case"] in old])):
            print(f"[{name}] {tally_rows(cases, rs)}")
        print(f"\n## 이번에 더한 사례: {sorted(set(cases) - old)} (실행 1과 비교하지 않는다)")
        print(tally_rows(cases, [r for r in rows if r["case"] not in old]))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--show", help="사례 ID. 사용자 메시지를 출력한다")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--run", action="store_true")
    p.add_argument("--report", action="store_true")
    p.add_argument("--exp", type=int, default=1, help="실행 번호. 1은 폴더 바로 아래, n은 run{n}/")
    args = p.parse_args()
    global EXP
    EXP = args.exp
    self_check()
    if args.show:
        print(user_message({c["id"]: c for c in load_cases()}[args.show]))
    if args.dry_run or args.run:
        run(args.dry_run)
    if args.report:
        report()


if __name__ == "__main__":
    main()
