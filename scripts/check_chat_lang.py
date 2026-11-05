"""대화 답변 언어 정책과 요약 지침 검증. 사례: data/exploration/chat-check/lang/cases.json

answer 사례는 지금 지침(ChatService.outputSystem)으로 바로 답한다. summary 사례는 두 번 부른다.
  1) 앱과 같은 요약 지침(ChatService.summarySystem)과 요청 형식(ChatPlanner.summaryRequest)으로 turns 전체를 실제 요약한다.
  2) 그 요약을 [이전 대화 요약]에 넣고 recent와 question으로 다음 답을 만든다(앱처럼 web_search 2회).
요약문과 다음 답을 따로 판정한다. 다음 답이 맞았다고 요약이 정확했다고 보지 않는다. 자동 판정은 잠정이다.
    python3 scripts/check_chat_lang.py                       # 언어 판별과 조립 확인
    .venv/bin/python scripts/check_chat_lang.py --dry-run    # 호출 목록과 최대 비용
    .venv/bin/python scripts/check_chat_lang.py --run        # ANTHROPIC_API_KEY 필요. 기록된 호출은 건너뛴다
    python3 scripts/check_chat_lang.py --report [--cases S01,L05]
"""
import argparse
import hashlib
import json
import os
import re
import sys
import textwrap
import time

import check_chat as cc
import run_profile_exploration as rp

DIR = cc.DIR / "lang"
LOG = DIR / "responses.jsonl"
REPS = 2
MAX_USD = 1.0  # --max-usd로 바꾼다
ONLY = None
USE = ["haiku"]  # main()이 --models로 정한다. 별칭은 cc.MODELS
LANG_NAME = {"ko": "한국어", "en": "영어", "ja": "일본어"}


def summary_system():
    m = re.search(r'static let summarySystem = """\n(.*?)\n\s*"""', cc.SWIFT.read_text(), re.S)
    if not m:
        sys.exit("ChatService.summarySystem을 찾지 못했다")
    return textwrap.dedent(m.group(1))


def summary_request(turns):
    """ChatPlanner.summaryRequest와 같은 형식. 기존 요약은 없다."""
    lines = ["[Existing summary]", "None", "", "[Conversation to add]"]
    lines += [f"{'User' if t['role'] == 'user' else 'AI'}: {t['content']}" for t in turns]
    return "\n".join(lines)


def answer_messages(case):
    turns = case["recent"] if case["kind"] == "summary" else case["turns"]
    return [dict(t) for t in turns] + [{"role": "user", "content": case["question"]}]


def lang_of(text):
    """한글 음절, 가나, 라틴 낱말 수로 주 언어를 고른다. ponytail: 글자 수 어림. 섞인 답은 사람이 본다."""
    counts = {"ko": len(re.findall(r"[가-힣]", text)),
              "ja": len(re.findall(r"[぀-ヿ]", text)) * 2,  # 가나 한 글자는 한글 음절보다 정보가 적다
              "en": len(re.findall(r"\b[A-Za-z]{2,}\b", text)) * 2}
    return max(counts, key=counts.get), counts


def load():
    return [c for c in json.loads((DIR / "cases.json").read_text())["cases"] if not ONLY or c["id"] in ONLY]


def text_of(blocks):
    return cc.shown_text(blocks)


def judge(case, row):
    out = {"요약": [], "답": []}
    if case["kind"] == "summary":
        s = row.get("summary_text", "")
        out["요약"] += [f"'{p}' 없음" for p in case["summary_require"] if not re.search(p, s)]
        out["요약"] += [f"'{p}' 나옴" for p in case["summary_forbid"] if re.search(p, s)]
    a = text_of(row.get("blocks", []))
    got, _ = lang_of(a)
    if case["answer_lang"] and got != case["answer_lang"]:  # null이면 관찰만 한다
        out["답"].append(f"언어 {LANG_NAME[got]}(기대 {LANG_NAME[case['answer_lang']]})")
    out["답"] += [f"'{p}' 없음" for p in case["answer_require"] if not re.search(p, a)]
    out["답"] += [f"'{p}' 나옴" for p in case["answer_forbid"] if re.search(p, a)]
    return out


def input_hash(case):
    return hashlib.sha256(json.dumps([cc.output_system(case["app_lang"]), summary_system(), case],
                                     ensure_ascii=False).encode()).hexdigest()[:16]


def self_check():
    assert lang_of("오사카에서는 타코야키를 드셔 보세요.")[0] == "ko"
    assert lang_of("In Osaka, try takoyaki and okonomiyaki near Dotonbori.")[0] == "en"
    assert lang_of("京都なら嵐山や東福寺がおすすめです。")[0] == "ja"
    assert lang_of("**Shibuya**와 **Ebisu** 근처 라멘집을 추천해요.")[0] == "ko"
    s = summary_system()
    assert "cancelled" in s and "hard requirements" in s and "who said what" in s, "요약 지침에 보존 항목이 없다"
    for c in load():
        system = cc.system_for(c, summary="(요약)" if c["kind"] == "summary" else None)
        assert system.startswith(cc.output_system(c["app_lang"]))
        assert ("[Earlier conversation summary — " in system) == (c["kind"] == "summary")
        assert answer_messages(c)[-1]["content"] == c["question"]
        if c["kind"] == "summary":
            assert summary_request(c["turns"]).count("User: ") == sum(t["role"] == "user" for t in c["turns"])
    print(f"self_check ok: 사례 {len(load())}개, 요약 지침 {len(s)}자")


def read_log():
    return [json.loads(l) for l in LOG.read_text().splitlines() if l.strip()] if LOG.exists() else []


def worst_usd(case, model=cc.MODEL):
    price_in, price_out = rp.PRICES[model]
    calls = 2 if case["kind"] == "summary" else 1
    chars = len(cc.output_system()) + len(json.dumps(case, ensure_ascii=False)) + len(summary_system())
    per = (chars * 2 + cc.SEARCH_USES * rp.SEARCH_TOKENS) * price_in + cc.MAX_TOKENS * price_out
    return calls * per / 1e6 + cc.SEARCH_USES * rp.SEARCH_USD


def run(dry):
    client = None
    if not dry:
        if not os.environ.get("ANTHROPIC_API_KEY"):
            sys.exit("ANTHROPIC_API_KEY가 없다. 같은 터미널에서 export ANTHROPIC_API_KEY=... 뒤에 다시 실행한다")
        import anthropic
        client = anthropic.Anthropic(max_retries=0)
    cc.require_frozen()
    if hashlib.sha256(summary_system().encode()).hexdigest()[:16] != cc.FROZEN["summary"]:
        sys.exit("요약 지침이 고정본과 다르다. 의도한 변경이면 check_chat.FROZEN을 고친다")
    # 완료는 사례·모델·반복·입력 해시로 본다(예전 Haiku 기록의 key에는 모델 이름이 없다)
    done = {(r["case"], r["model"], r["rep"], r["input_hash"]) for r in read_log() if "error" not in r}
    total = 0.0
    todo = [(c, m, r) for c in load() for m in USE for r in range(1, REPS + 1)]
    for case, short, rep in todo:
        model = cc.MODELS[short]
        key, ih, worst = f"{case['id']}:{short}:r{rep}", input_hash(case), worst_usd(case, model)
        if dry:
            total += worst
            print(f"{key:14s} 최대 ${worst:.4f}")
            continue
        if (case["id"], model, rep, ih) in done:
            continue
        spent = rp.cost(read_log())
        if spent + worst > MAX_USD:
            sys.exit(f"stopped: spent ${spent:.4f}, next call could add ${worst:.4f}, over ${MAX_USD}")
        row = {"key": key, "case": case["id"], "rep": rep, "model": model, "input_hash": ih,
               "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "input_tokens": 0, "output_tokens": 0}
        start = time.monotonic()
        try:
            summary = None
            if case["kind"] == "summary":  # 앱의 요약 호출: 검색 없음
                s = client.messages.create(model=model, max_tokens=cc.MAX_TOKENS, system=summary_system(),
                                           messages=[{"role": "user", "content": summary_request(case["turns"])}])
                summary = "".join(b.text for b in s.content if b.type == "text").strip()
                row.update(summary_text=summary, summary_stop=s.stop_reason)
                row["input_tokens"] += s.usage.input_tokens
                row["output_tokens"] += s.usage.output_tokens
            resp = client.messages.create(
                model=model, max_tokens=cc.MAX_TOKENS, system=cc.system_for(case, summary=summary),
                messages=answer_messages(case),
                tools=[{"type": "web_search_20250305", "name": "web_search", "max_uses": cc.SEARCH_USES}])
            tool_usage = getattr(resp.usage, "server_tool_use", None)
            row.update(blocks=[b.model_dump(mode="json") for b in resp.content], stop_reason=resp.stop_reason,
                       search_requests=getattr(tool_usage, "web_search_requests", 0) or 0)
            row["input_tokens"] += resp.usage.input_tokens
            row["output_tokens"] += resp.usage.output_tokens
        except Exception as e:  # 실패는 기록하고 멈춘다. 다시 돌리면 이어서 한다
            row["error"] = f"{type(e).__name__}: {e}"
        row["latency_s"] = round(time.monotonic() - start, 2)
        with LOG.open("a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        if "error" in row:
            sys.exit(f"stopped at {key}: {row['error']}")
        j = judge(case, row)
        print(key, f"요약 {len(j['요약'])}", f"답 {len(j['답'])}", f"{row['latency_s']}s")
    if dry:
        print(f"호출 묶음 {len(todo)}개, 최대 합계 ${total:.2f} (상한 ${MAX_USD})")


def report():
    cases = {c["id"]: c for c in load()}
    rows = [r for r in read_log() if "error" not in r and r["case"] in cases and r["input_hash"] == input_hash(cases[r["case"]])
            and r["model"] in [cc.MODELS[m] for m in USE]]
    flagged = {}
    for r in sorted(rows, key=lambda r: (r["case"], r["model"], r["rep"])):
        case, j = cases[r["case"]], judge(cases[r["case"]], r)
        f = flagged.setdefault(r["model"], {"기록": 0, "요약": 0, "답": 0})
        f["기록"] += 1
        expect = LANG_NAME[case["answer_lang"]] if case["answer_lang"] else "관찰만"
        print(f"\n=== {r['case']} {r['model']} r{r['rep']} (앱 언어 {LANG_NAME[case['app_lang']]}, 기대 답변 언어 {expect}, 실제 {LANG_NAME[lang_of(text_of(r.get('blocks', [])))[0]]})")
        print("질문: " + case["question"])
        if case["kind"] == "summary":
            print("--- 요약")
            print(r.get("summary_text", ""))
            for p in j["요약"]:
                print("  ! 요약: " + p)
            print("  요약 watch: " + case["summary_watch"])
            f["요약"] += bool(j["요약"])
        print("--- 답")
        print(text_of(r.get("blocks", [])))
        for p in j["답"]:
            print("  ! 답: " + p)
        print(f"  언어 판별 {lang_of(text_of(r.get('blocks', [])))[1]}")
        print("  답 watch: " + case["answer_watch"])
        f["답"] += bool(j["답"])
    print("\n자동 표시는 잠정:")
    for model, f in flagged.items():
        print(f"  {model}: 기록 {f['기록']}건, 요약 표시 {f['요약']}건, 답 표시 {f['답']}건, 비용 ${rp.cost([r for r in rows if r['model'] == model]):.4f}")


def main():
    global ONLY
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--run", action="store_true")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--cases")
    ap.add_argument("--models", help="쉼표로 나눈 모델 별칭: " + ",".join(cc.MODELS) + " (기본 haiku)")
    ap.add_argument("--max-usd", type=float)
    a = ap.parse_args()
    global USE, MAX_USD
    ONLY = set(a.cases.split(",")) if a.cases else None
    if a.models:
        USE = a.models.split(",")
        if set(USE) - set(cc.MODELS):
            sys.exit(f"모르는 모델: {sorted(set(USE) - set(cc.MODELS))}")
    if a.max_usd:
        MAX_USD = a.max_usd
    if a.dry_run or a.run:
        run(a.dry_run)
    elif a.report:
        report()
    else:
        self_check()


if __name__ == "__main__":
    main()
