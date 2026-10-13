"""실제 여행 메모 비교(실행 3). 계획: data/exploration/memo-check/run3/plan.md.

사용자가 my-trips.md에 적은 지난 여행과 이번 요청으로 세 방식을 비교한다. 기대 도시는 미리 정하지 않는다.
  B  요청에 메모를 덧붙인 일반 질문
  P  도시 이름 + 개인화 지침 (기준선)
  S  P에 도시마다 강한 경험의 이름을 더함 (단계 구분과 순서 지시 없음)
  PQ P에 확인 질문 하나와 그 답을 더함 (my-questions.md에 답을 적은 요청만)
실행 4(기본, memo-check/run4/)는 조건 처리만 바꾼다. 입력은 실행 3의 my-trips.md 그대로다.
  P   실행 3의 P와 같다
  PC  P에 조건 처리(확인된 불충족은 제외, 확인된 충족은 유지, 근거가 없으면 미확인)를 더함
  PCQ PC에 확인 질문들과 그 답을 더함. 질문은 뜻이 갈리는 조건(예산의 범위 등)도 묻는다
실행 5(기본, memo-check/run5/)는 조건 처리 문단만 다시 바꾼다.
  PC  실행 4의 PC와 같다
  PD  근거 없이 빼거나 충족이라 하지 않고 미확인으로 둔다. excluded는 말한 조건을 어긴 도시만. 비용·안전을 단정하지 않는다
  PDQ PD에 확인 질문의 답을 더함 (이 실행 폴더에서 --ask로 질문을 받고 답한 경우에만)
실행 6(기본, memo-check/run6/)은 예산을 판정하지 않고 예상 비용의 범위를 보여준다(사용자 결정).
  PE  실행 3의 P에 예상 비용(항공, 1박 숙박, 하루 지출의 낮은 값과 높은 값)을 더함. 합계는 코드가 낸다
  PE2 같은 입력을 한 번 더 돌린 것. 값이 호출마다 얼마나 달라지는지 본다
앞 실행을 다시 보려면 --run 3, 4, 5.
    python3 scripts/run_real_memo.py --dry-run
    python3 scripts/run_real_memo.py --ask     # 확인 질문을 만들어 my-questions.md에 쓴다
    python3 scripts/run_real_memo.py           # 추천 호출. GEMINI_API_KEY 필요. 기록된 호출은 건너뛴다
    python3 scripts/run_real_memo.py --report
    python3 scripts/run_real_memo.py --sheet   # 방식을 가린 my-sheet.md와 key.json
"""
import argparse
import difflib
import json
import random
import re
import sys
import time

import run_fixed_data_check as fx
import run_profile_exploration as rp

DIR = rp.EXP / "memo-check" / "run6"  # main()이 --run에 맞춰 아래 경로와 함께 바꾼다
LOG, TRIPS, QUESTIONS, SHEET = DIR / "responses.jsonl", DIR / "my-trips.md", DIR / "my-questions.md", DIR / "my-sheet.md"
ARMS = {3: (["B", "P", "S"], "PQ"), 4: (["P", "PC"], "PCQ"), 5: (["PC", "PD"], "PDQ"), 6: (["PE", "PE2"], "PEQ")}
BUDGET, NIGHTS = 3_000_000, (7, 14)  # 실행 6의 표시용. 사용자가 적은 예산(항공료 포함)과 기간(1~2주)  # (기본 방식들, 확인 질문에 답한 뒤의 방식)
MAX_USD = 1.0
norm = lambda s: re.sub(r"[\s·,/]", "", s or "")


def parse_md(text):
    """'## 구역' 아래 '### 묶음'마다 '- 항목: 내용'을 읽는다. 항목 이름의 괄호 설명은 버린다."""
    out, section = {}, None
    for line in text.splitlines():
        if line.startswith("## "):
            section = out.setdefault(line[3:].strip(), [])
        elif line.startswith("### ") and section is not None:
            section.append({})
        elif section and (m := re.match(r"-\s*([^:：(]+)(?:\([^)]*\))?\s*[:：]\s*(.*)", line)):
            section[-1][m.group(1).strip()] = m.group(2).strip()
    return out


def load_input():
    d = parse_md(TRIPS.read_text())
    memos = [dict(city=t["도시"], stars=int(t["별점"]) if t.get("별점", "").isdigit() else 0, good=t.get("좋았던 점", ""), bad=t.get("아쉬웠던 점", ""))
             for t in d.get("지난 여행", []) if t.get("도시")]
    concept = {norm(c["label"]): cid for cid, c in fx.CONCEPTS.items()}
    reqs = []
    for i, r in enumerate((r for r in d.get("이번 여행", []) if r.get("주 컨셉")), 1):
        # '주 컨셉: 나이트라이프 / 부 컨셉: 교류, 미식'처럼 한 줄에 적은 것도 읽는다
        head, _, inline = r["주 컨셉"].partition("/")
        main = concept.get(norm(head)) or sys.exit(f"주 컨셉을 알 수 없다: {head}")
        subs = [concept.get(norm(s)) or sys.exit(f"부 컨셉을 알 수 없다: {s}") for s in re.split(r"[,、]", r.get("부 컨셉") or inline.partition(":")[2]) if s.strip()]
        reqs.append(dict(id=f"Q{i}", main=main, detail=None, subs=subs, months=months(r.get("시기", "")), period=r.get("시기") or None, text=r.get("바라는 점") or None))
    return memos, reqs


def months(text):
    """'12~2월 중' -> [12, 1, 2]. 범위가 아니면 적힌 숫자들. 없으면 빈 목록."""
    if m := re.search(r"(\d+)\s*[~\-]\s*(\d+)", text):
        a, b = int(m.group(1)), int(m.group(2))
        return [(a - 1 + i) % 12 + 1 for i in range((b - a) % 12 + 1)]
    return [int(x) for x in re.findall(r"\d+", text) if 1 <= int(x) <= 12]


def level(city, sub, req):
    """적은 달 가운데 하나라도 시즌이면 그 등급으로 본다."""
    return max(fx.grade(city, sub, m) for m in req["months"] or [None])


def fits(cid, req):
    return max(level(fx.CITIES[cid], s, req) for s in fx.CONCEPTS[req["main"]]["sub"]) >= 2


def request_text(req):
    lines = [f"주 컨셉: {fx.LABEL[req['main']]}"]
    if req["subs"]:
        lines.append("부 컨셉: " + ", ".join(fx.LABEL[s] for s in req["subs"]))
    lines.append(f"시기: {req['period']}" if req["period"] else "시기: 정하지 않음")
    if req["text"]:
        lines.append(f"바라는 점: {req['text']}")
    return "\n".join(lines)


def visited_ids(memos):
    """다녀온 도시를 목록의 도시와 잇는다. 표기가 조금 달라도(벤쿠버/밴쿠버) 잇고, 목록에 없으면 잇지 않는다."""
    names = {c["name"]["ko"]: cid for cid, c in fx.CITIES.items()}
    return {m["city"]: names[hit[0]] for m in memos if (hit := difflib.get_close_matches(m["city"].strip(), names, n=1, cutoff=0.66))}


def memo_text(memos):
    if not memos:
        return "지난 여행 평가: 없음"
    return "지난 여행 평가:\n" + "\n".join(
        f"- {m['city']}" + (f" {'★' * m['stars']}" if m["stars"] else "") + f" | 좋았던 점: {m['good'] or '(없음)'} | 아쉬웠던 점: {m['bad'] or '(없음)'}" for m in memos)


def city_lines(memos, req, strong):
    visited = set(visited_ids(memos).values())
    out = []
    for cid, c in fx.CITIES.items():
        if cid in visited:
            continue
        line = f"- {cid} {c['name']['ko']}"
        if strong:  # 위 두 단계의 세부를 단계 구분 없이 한 줄로
            line += " | 강한 경험: " + ", ".join(f"{v['label']}({', '.join(n for s, n in v['sub'].items() if level(c, s, req) >= 2)})"
                                                 for v in fx.CONCEPTS.values() if any(level(c, s, req) >= 2 for s in v["sub"]))
        out.append(line)
    return "\n".join(out)


def user_text(arm, req, memos, qa=None):
    if arm == "B":
        text = f"{fx.LABEL[req['main']]} 위주의 여행을 가고 싶어." + (f" {', '.join(fx.LABEL[s] for s in req['subs'])}도 함께 즐기고 싶어." if req["subs"] else "")
        text += (f" 시기는 {req['period']}." if req["period"] else "") + (f" {req['text'].rstrip('.')}." if req["text"] else "")
        text += " 아래 도시 중에서 나한테 맞을 곳 5곳을 순서대로 추천해줘."
        if memos:
            text += "\n\n참고로 내 지난 여행은 이랬어.\n" + "\n".join(
                f"- {m['city']}:" + (f" 별점 {m['stars']}/5." if m["stars"] else "") + (f" 좋았던 점: {m['good']}" if m["good"] else "")
                + (f" 아쉬웠던 점: {m['bad']}" if m["bad"] else "") for m in memos) + "\n다녀온 곳은 빼고 추천해줘."
        return text + "\n\n도시 목록:\n" + city_lines([], req, False)
    head = f"{request_text(req)}\n\n{memo_text(memos)}"
    if arm == "ask":
        return head
    for q, a in qa or []:
        head += f"\n\n확인 질문: {q}\n여행자의 답: {a}"
    return f"{head}\n\n도시 목록:\n{city_lines(memos, req, arm == 'S')}"


def read_answers():
    """my-questions.md에서 요청별 [(질문, 답)]. 답이 번호(여러 개면 '1,3')면 그 선택지의 글로 바꾼다. 답하지 않은 질문은 뺀다."""
    if not QUESTIONS.exists():
        return {}
    out = {}
    for block in re.split(r"\n## ", "\n" + QUESTIONS.read_text())[1:]:
        pairs = []
        for chunk in re.split(r"\n(?=질문: )", block)[1:]:
            q, a = re.match(r"질문: (.+)", chunk), re.search(r"^답[^:：]*[:：]\s*(.+)$", chunk, re.M)
            if q and a and a.group(1).strip():
                opts, ans = dict(re.findall(r"^(\d)\. (.+)$", chunk, re.M)), a.group(1).strip()
                nums = re.findall(r"\d", ans) if re.fullmatch(r"[\d\s,]+", ans) else []
                pairs.append((q.group(1).strip(), " / ".join(opts[n] for n in nums) if nums and all(n in opts for n in nums) else ans))
        if pairs:
            out[block.split()[0]] = pairs
    return out


def ranked(data):
    """응답이 형식을 조금 벗어나도 읽는다: 목록 안에 목록을 한 번 더 싼 경우."""
    items = (data or {}).get("ranked") or []
    if items and all(isinstance(x, list) for x in items):
        items = [c for x in items for c in x]
    return [c for c in items if isinstance(c, dict)]


def excluded(data):
    """[(도시 ID, 이유)]. 이유를 why 대신 reason에 적은 응답도 읽는다."""
    return [(x.get("id"), x.get("why") or x.get("reason")) for x in (data or {}).get("excluded") or [] if isinstance(x, dict)]


def cost_lines(c):
    """예상 비용을 기간별 합계로. [문장...]. 값이 형식에 안 맞으면 빈 목록. 예산에 맞는지는 말하지 않고 범위의 어디인지만 적는다."""
    k = c.get("cost") or {}
    parts = [k.get(x) for x in ("flight", "lodging_per_night", "daily_spend")]
    if not all(isinstance(v, list) and len(v) == 2 and all(isinstance(n, (int, float)) for n in v) for v in parts):
        return []
    won = lambda v: f"{v / 10000:.0f}만"
    f, h, d = parts
    out = [f"예상 비용(1인): 항공 {won(f[0])}~{won(f[1])}원, 숙박 1박 {won(h[0])}~{won(h[1])}원, 하루 지출 {won(d[0])}~{won(d[1])}원. {k.get('cost_note') or ''}".strip()]
    if k.get("assumptions"):
        out.append(f"가정: {k['assumptions']}")
    for n in NIGHTS:  # 숙박은 박수만큼, 하루 지출은 머무는 날수(박수 + 1)만큼
        low, high = f[0] + n * h[0] + (n + 1) * d[0], f[1] + n * h[1] + (n + 1) * d[1]
        where = "예상 범위보다 낮음" if BUDGET < low else "예상 범위보다 높음" if BUDGET > high else "예상 범위 안"
        out.append(f"{n}박 {n + 1}일 합계 {won(low)}~{won(high)}원. 적은 예산 {won(BUDGET)}원은 {where}")
    return out


def off_format(data):
    """지침의 출력 형식에서 벗어난 점. 내용 평가와 따로 적는다."""
    out = []
    if (r := (data or {}).get("ranked")) and all(isinstance(x, list) for x in r):
        out.append("ranked가 목록 안의 목록")
    if any("why" not in x for x in (data or {}).get("excluded") or [] if isinstance(x, dict)):
        out.append("excluded에 why가 없음")
    return out


def self_check():
    d = parse_md("## 지난 여행\n### 1\n- 도시: 방콕\n- 별점(1~5): 4\n- 좋았던 점: 음식\n## 이번 여행\n### 1\n- 주 컨셉: 문화·역사\n- 시기(월, 선택): 7월\n")
    assert d == {"지난 여행": [{"도시": "방콕", "별점": "4", "좋았던 점": "음식"}], "이번 여행": [{"주 컨셉": "문화·역사", "시기": "7월"}]}
    assert months("12~2월 중") == [12, 1, 2] and months("7월") == [7] and months("") == []
    req, memos = dict(id="Q1", main="food", detail=None, subs=["social"], months=[], period=None, text=None), [dict(city="방콕", stars=4, good="음식", bad="")]
    assert visited_ids([dict(city="벤쿠버"), dict(city="오사카"), dict(city="라스베이가스")]) == {"벤쿠버": "ca-vancouver"}
    winter = dict(req, main="activities", months=[12, 1, 2])
    assert fits("ca-vancouver", winter) and level(fx.CITIES["nz-queenstown"], "winter", winter) == 0 and "부 컨셉: 교류" in request_text(req)
    p, s = user_text("P", req, memos), user_text("S", req, memos)
    assert "th-bangkok" not in p and "강한 경험" not in p and "- jp-tokyo 도쿄 | 강한 경험: " in s and "미식(" in s
    assert not re.search(r"선택할 만함|시간을 낼 만함|등급", s) and "방콕 ★★★★ | 좋았던 점: 음식" in p
    assert [c["id"] for c in ranked({"ranked": [[{"id": "a"}, {"id": "b"}]]})] == ["a", "b"] and excluded({"excluded": [{"id": "x", "reason": "r"}]}) == [("x", "r")]
    assert off_format({"ranked": [[{"id": "a"}]], "excluded": [{"id": "x", "reason": "r"}]}) == ["ranked가 목록 안의 목록", "excluded에 why가 없음"] and not off_format({"ranked": [{"id": "a"}]})
    cl = cost_lines({"cost": {"flight": [300_000, 500_000], "lodging_per_night": [50_000, 250_000], "daily_spend": [40_000, 150_000]}})
    assert "7박 8일 합계 97만~345만원. 적은 예산 300만원은 예상 범위 안" in cl[1] and "예상 범위보다 낮음" not in cl[1] and cost_lines({"cost": {"flight": 1}}) == []
    assert "확인 질문: q\n여행자의 답: a" in user_text("P", req, memos, [("q", "a")]) and "별점 4/5" in user_text("B", req, memos)
    two = user_text("PC", req, memos, [("q1", "a1"), ("q2", "a2")])
    assert two.count("확인 질문: ") == 2 and "여행자의 답: a2" in two and user_text("PC", req, memos) == p


def read_log():
    return [json.loads(line) for line in LOG.read_text().splitlines()] if LOG.exists() else []


def call(key, arm, system, user, search=True):
    row = {"key": key, "arm": arm, "model": rp.FLASH, "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
    start = time.monotonic()
    try:
        res = rp.call_gemini(rp.FLASH, system, user, "low", search=search)
        row.update({k: res[k] for k in ("final_text", "stop_reason", "input_tokens", "output_tokens", "search_requests", "searches")})
    except rp.GeminiError as e:
        row["error"] = str(e)
    row["latency_s"] = round(time.monotonic() - start, 2)
    with LOG.open("a") as f:
        f.write(json.dumps(row, ensure_ascii=False) + "\n")
    if "error" in row:  # 실패는 기록하고 멈춘다. 그 줄을 지우고 다시 돌리면 이어서 한다.
        sys.exit(f"stopped at {key}: {row['error']}")
    return row


def checks(req, ids):
    unknown = [i for i in ids if i not in fx.CITIES]
    low = [i for i in ids if i in fx.CITIES and not fits(i, req)]
    return f"목록 밖 {unknown}, 주 컨셉 후보 미달(시즌 적용) {low}" if unknown or low else "코드 검사: 걸린 것 없음(허용 도시, 큰 컨셉 문턱, 시즌만 본다)"


def main():
    p = argparse.ArgumentParser()
    for flag in ("--dry-run", "--ask", "--report", "--sheet"):
        p.add_argument(flag, action="store_true")
    p.add_argument("--run", type=int, default=6, choices=sorted(ARMS))
    args = p.parse_args()
    global DIR, LOG, TRIPS, QUESTIONS, SHEET
    DIR = rp.EXP / "memo-check" / f"run{args.run}"
    LOG, TRIPS, QUESTIONS, SHEET = DIR / "responses.jsonl", DIR / "my-trips.md", DIR / "my-questions.md", DIR / "my-sheet.md"
    base, after = ARMS[args.run]
    draft = json.loads((DIR / "draft.json").read_text())
    levels = [lv["id"] for lv in draft["levels"]]
    for c in draft["cities"].values():
        c["grades"] = {s: levels.index(g) for s, g in c["grades"].items()}
    fx.CITIES.update(draft["cities"])
    self_check()
    parts = [s.strip() for s in (DIR / "prompt.md").read_text().split("\n---\n")]
    if args.run == 3:
        systems = {"B": parts[1], "P": parts[2].replace("{city_note}", parts[3]), "S": parts[2].replace("{city_note}", parts[4]), "ask": parts[5]}
        systems["PQ"] = systems["P"]
    else:
        systems = {base[0]: parts[1], base[1]: parts[1 if args.run == 6 else 2], after: parts[1 if args.run == 6 else 2], "ask": parts[2 if args.run == 6 else 3]}
    memos, reqs = load_input()
    if not reqs:
        sys.exit(f"{TRIPS.name}의 '이번 여행'에 주 컨셉을 적은 뒤 다시 실행한다.")
    rows = {r["key"]: r for r in read_log() if "error" not in r}
    answers = read_answers()
    plan = [(f"{r['id']}:{arm}", arm, r) for r in reqs for arm in (["ask"] if args.ask else base + ([after] if r["id"] in answers else []))]

    if args.dry_run:
        print(f"지난 여행 {len(memos)}건, 이번 요청 {len(reqs)}건, 답한 확인 질문 {len(answers)}건\n")
        for key, arm, r in [(f"{r['id']}:{a}", a, r) for r in reqs for a in base]:
            print(f"--- {key}\n{user_text(arm, r, memos)}\n")
        return
    if args.report or args.sheet:
        got = {k: fx.parse(v["final_text"]) for k, v in rows.items()}
        name = lambda i: fx.CITIES[i]["name"]["ko"] if i in fx.CITIES else str(i)
        if args.report:
            for r in reqs:
                print(f"\n## {r['id']}  {request_text(r).replace(chr(10), ' / ')}")
                for arm in base + [after]:
                    data = got.get(f"{r['id']}:{arm}")
                    if not data:
                        continue
                    ids = [c.get("id") for c in ranked(data)]
                    print(f"\n[{arm}] {' → '.join(map(name, ids))}\n   {checks(r, ids)}\n   쓴 메모: {data.get('used_memories') or []}")
                    for c in ranked(data):
                        print(f"   {name(c.get('id'))}: {c.get('reason')}" + (f" | 유의: {c['caveat']}" if c.get("caveat") else "") + (f" | 확인 필요: {c['check']}" if c.get("check") else ""))
                        for line in cost_lines(c):
                            print(f"      {line}")
                    for cid, why in excluded(data):
                        print(f"   뺀 도시 {name(cid)}: {why}")
                    if off_format(data):
                        print(f"   형식 이탈: {off_format(data)}")
            for arm in ["ask"] + base + [after]:
                done = [v for v in rows.values() if v["arm"] == arm]
                if done:
                    print(f"[{arm}] 호출 {len(done)}건, 추정 비용 ${rp.cost(done):.2f}, 입력 평균 {sum(v['input_tokens'] for v in done) // len(done)}토큰, 검색어 {sum(v.get('search_requests', 0) for v in done)}개")
            return
        out_sheet = SHEET
        if SHEET.exists():  # 적어 둔 것을 덮어쓰지 않는다. 표시를 고친 시트는 새 이름으로 한 번만 만든다
            out_sheet = SHEET.with_name("my-sheet-v2.md")
            if out_sheet.exists():
                sys.exit(f"{SHEET.name}과 {out_sheet.name}이 이미 있다. 덮어쓰지 않는다.")
        rnd, key_map, p1, p2 = random.Random(20261013), {}, [], []
        for r in reqs:
            arms = [a for a in base + [after] if got.get(f"{r['id']}:{a}")]
            rnd.shuffle(arms)
            key_map[r["id"]] = dict(zip("가나다라", arms))
            head = f"\n## {r['id']}\n\n{request_text(r)}\n" + "".join(f"\n확인 질문: {q}\n내 답: {a}\n" for q, a in answers.get(r["id"], []))
            p1.append(head + "".join(f"\n- {lab}: " + " → ".join(name(c.get("id")) for c in ranked(got[f"{r['id']}:{a}"]))
                                     + (" | 뺀 도시: " + ", ".join(name(cid) for cid, _ in excluded(got[f"{r['id']}:{a}"])) if excluded(got[f"{r['id']}:{a}"]) else "")
                                     for lab, a in zip("가나다라", arms))
                      + "\n\n가장 가고 싶은 쪽: \n가장 덜 가고 싶은 쪽: \n이유: \n")
            p2.append(head + "".join(f"\n**{lab}**\n" + "".join(f"\n- {name(c.get('id'))}: {c.get('reason')}" + (f" (유의: {c['caveat']})" if c.get("caveat") else "") + (f" (확인 필요: {', '.join(map(str, c['check']))})" if c.get("check") else "")
                                                         + "".join(f"\n    - {line}" for line in cost_lines(c))
                                                         for c in ranked(got[f"{r['id']}:{a}"]))
                                     + "".join(f"\n- 뺀 도시 {name(cid)}: {why}" for cid, why in excluded(got[f"{r['id']}:{a}"])) + "\n"
                                     for lab, a in zip("가나다라", arms)) + "\n제안한 경험까지 보고 가장 맞는 쪽: \n사실과 다르거나 내가 말하지 않은 것을 지어낸 곳: \n메모: \n")
        out_sheet.write_text("# 1부: 도시 목록만 보고\n\n아래 2부를 읽기 전에 여기부터 적는다. 이유에는 목록에서 보이는 것만 적는다.\n" + "\n".join(p1) + "\n\n---\n\n# 2부: 제안한 경험까지 보고\n" + "\n".join(p2))
        (DIR / "key.json").write_text(json.dumps(key_map, ensure_ascii=False, indent=1) + "\n")
        return print(f"{out_sheet} 에 시트를 썼다. 대응표는 key.json")

    rp.MAX_TOKENS = 4096
    for key, arm, r in plan:
        if key in rows:
            continue
        if rp.cost(read_log()) > MAX_USD:
            sys.exit(f"stopped: over ${MAX_USD}")
        row = call(key, arm, systems[arm], user_text(arm, r, memos, answers.get(r["id"]) if arm == after else None), search=arm != "ask")
        rows[key] = row
        print(key, json.dumps(fx.parse(row["final_text"]), ensure_ascii=False)[:160] if arm == "ask" else [c.get("id") for c in ranked(fx.parse(row["final_text"]))],
              f"검색어 {row['search_requests']}", f"{row['latency_s']}s")
    if args.ask:
        out = ["# 확인 질문\n\n요청마다 질문이 하나 있거나 없다. `답:` 뒤에 번호나 직접 쓴 글을 적는다. 답하지 않고 넘어가도 된다.\n"]
        for r in reqs:
            q = fx.parse(rows[f"{r['id']}:ask"]["final_text"]) or {}
            qs = q.get("questions") or ([q] if q.get("ask") else [])  # 실행 3은 질문 하나짜리 형식이었다
            out.append(f"## {r['id']} {request_text(r).replace(chr(10), ' / ')}\n")
            if not qs:
                out.append(f"질문 없음. {q.get('why', '')}\n")
            for x in qs:
                out.append(f"질문: {x.get('question')}\n(무엇에 대한 질문인가: {x.get('about') or x.get('note')})\n"
                           + "".join(f"{i}. {o}\n" for i, o in enumerate(x.get("options") or [], 1)) + "답(번호나 직접 적기): \n")
        if QUESTIONS.exists():
            sys.exit(f"{QUESTIONS.name}이 이미 있다. 답을 적었을 수 있어 덮어쓰지 않는다.")
        QUESTIONS.write_text("\n".join(out))
        print(f"{QUESTIONS} 에 질문을 썼다.")


if __name__ == "__main__":
    main()
