"""같은 검색 자료로 대화 모델을 비교한다. 사례: data/exploration/chat-check/fixed/cases.json, 자료: fixed/evidence.json

모델마다 새로 검색하면 자료 차이와 모델 차이가 섞이므로, 이전 실행에서 문제가 나온 사례의 출처 원문을 고정해
web_search 없이 문서(document, 인용 켬)로 준다. 지침·사례 문맥은 check_chat.py와 같고, 문서 사용 안내 한 줄만 더한다.
평가는 사실 보존(1인/전체, 금액·통화, 날짜·요일, 본문과 출처 일치)을 외국어 혼입보다 먼저 본다.
자동 판정(실제 오류/근거 부족/검토 필요)은 잠정이며, 검토 필요는 오류로 세지 않는다. 모든 답을 사람이 인용 원문과 대조하고 자동 판정의 누락·오탐을 기록한다.
조건: 웹 검색 인용이 아니라 문서 인용이다. 여기서 좋아도 앱 흐름(검색 포함)에서 다시 확인한다.
effort는 앱처럼 지정하지 않아 모델 기본값(Haiku 5.5 medium, Sonnet 5.5 high)이다. 단가: 2026-11-05 공식 가격표 확인
(Haiku 5.5 $0.10/$0.50, 10만 토큰 초과 $0.50/$2.50; Sonnet 5.5 $2/$10).
    python3 scripts/check_chat_fixed.py                        # 가짜 답으로 사실 규칙 확인
    .venv/bin/python scripts/check_chat_fixed.py --dry-run     # 호출 목록과 최대 비용
    .venv/bin/python scripts/check_chat_fixed.py --run         # ANTHROPIC_API_KEY 필요. 기록된 호출은 건너뛴다
    python3 scripts/check_chat_fixed.py --report [--citations] # 모델별 답·사실 문제(!)·검토(?)·인용 대조
    (--cases H11,H08, --models haiku,sonnet 으로 좁힌다)
"""
import argparse
import hashlib
import json
import os
import re
import sys
import time

import check_chat as cc
import run_profile_exploration as rp

FIXED = cc.DIR / "fixed"
LOG = FIXED / "responses.jsonl"
MODELS = {"haiku": cc.MODEL, "sonnet": rp.SONNET}  # rp.PRICES의 Sonnet 단가는 2026-10-07 가격표 기준
REPS = 3  # 사실 오류는 간헐적이라 같은 입력을 세 번
MAX_USD = 3.0
NOTE = ("\n- 이번 질문에는 앱이 미리 찾은 검색 자료가 문서로 함께 주어집니다. web_search 대신 이 문서만 근거로 쓰고, "
        "문서에 없는 바뀌는 사실은 확인하지 못했다고 쓰세요.")
ONLY = None
USE = list(MODELS)


def load():
    fixed = json.loads((FIXED / "cases.json").read_text())["cases"]
    base = {c["id"]: c for c in cc.load_cases()}
    evidence = json.loads((FIXED / "evidence.json").read_text())["cases"]
    return [dict(f, base=base[f["id"]], docs=evidence[f["id"]]) for f in fixed if not ONLY or f["id"] in ONLY]


def system_for(case):
    return cc.system_for(case["base"]).replace(cc.app_system(), cc.app_system() + NOTE, 1)


def messages_for(case):
    msgs = cc.messages_for(case["base"])
    docs = [{"type": "document", "source": {"type": "text", "media_type": "text/plain", "data": d["text"]},
             "title": d["title"], "context": d["url"], "citations": {"enabled": True}} for d in case["docs"]]
    msgs[-1] = {"role": "user", "content": docs + [{"type": "text", "text": msgs[-1]["content"]}]}
    return msgs


def input_hash(case):
    return hashlib.sha256(json.dumps([system_for(case), messages_for(case)], ensure_ascii=False).encode()).hexdigest()[:16]


def text_of(row):
    return "".join(b.get("text", "") for b in row["blocks"] if b["type"] == "text").strip()


def fact_problems(case, text):
    """잠정 판정. kind는 실제 오류 / 근거 부족 / 검토 필요. 검토 필요는 오류 수에 넣지 않는다. 사람이 원문과 대조해 확정한다."""
    out = []
    lines = text.split("\n")
    for r in case["rules"]:
        hit = None
        if "if" in r:
            hit = next((l for l in lines if re.search(r["if"], l) and not re.search(r["then"], l)), None)
        elif "forbid" in r:
            m = re.search(r["forbid"], text)
            hit = m and text[max(0, m.start() - 15): m.end() + 15]
        elif "conflict" in r:
            found = [p for p in r["conflict"] if re.search(p, text)]
            hit = found and not re.search(r["unless"], text) and ("둘 다 단정" if len(found) == len(r["conflict"]) else "한쪽만 단정")
        if hit:
            out.append(f"{r['kind']}: {r['label']} ({str(hit).strip()[:60]})")
    out += [f"실제 오류: '{p}' 없음" for p in case["require"] if not re.search(p, text)]
    return out


def self_check():
    cases = {c["id"]: c for c in load()}
    p = lambda cid, t: fact_problems(cases[cid], t)
    kinds = lambda cid, t: [x.split(":")[0] for x in p(cid, t)]
    assert "실제 오류" in kinds("H11", "VIP 테이블은 4명 기준 €350 전후예요.")
    assert p("H11", "VIP 테이블은 4인 테이블 기준 1인당 €350부터였어요(2026).") == []
    assert "근거 부족" in kinds("H11", "2027년 가격은 €400이에요.")
    both = "야나기바시 시장은 매일 열어요.\n일요일에는 야나기바시가 쉰다는 안내도 있어요."
    assert any("둘 다 단정" in x for x in p("H08", both))
    assert any("한쪽만 단정" in x for x in p("H08", "야나기바시 시장은 매일 열어요."))
    assert not any("야나기바시" in x for x in p("H08", both + "\n자료마다 영업일이 엇갈려요."))
    assert "실제 오류" in kinds("H08", "말이 있는 계란말이와 라멘 조합이 대표예요.")
    assert "검토 필요" in kinds("H08", "명란 계란말이와 라멘이 약 ¥800이에요.")
    assert "근거 부족" in kinds("H05", "야간 입장료는 주간과 같은 500엔이에요. 200엔")
    assert p("H05", "야간은 별도 입장권이 필요해요. 500엔, 200엔. 예약은 필요 없어요.") == []
    assert "실제 오류" in kinds("H05", "500엔 200엔. 예약이 필요합니다.")
    assert "실제 오류" in kinds("H07", "땅콩 팟타이 사테 쏨땀. '마이 사이 took-ka'라고 하세요.")
    assert p("H07", "땅콩 팟타이 사테 쏨땀. \"마이 사이 투아 리송(ไม่ใส่ถั่วลิสง)\"") == []
    # 첫 비교의 사람 판정(judgments.md)에서 나온 누락·오탐
    assert p("H11", "VIP는 4인 테이블에 1인당 약 €350부터, 2027년 가격은 확정되기 전까지 참고용") == []
    assert any("야나기바시" in x for x in p("H08", both + "\n가기 전에 확인하세요."))
    assert "실제 오류" in kinds("H05", "500엔, 소중고생은 200엔입니다.")
    assert "근거 부족" in kinds("H05", "500엔 200엔. 야간 입장 마감 시간은 자료마다 달라서 확인하세요.")
    assert p("H07", "땅콩 팟타이 사테 쏨땀.\n**알레르기 주의사항**") == []
    for c in cases.values():
        assert c["docs"] and messages_for(c)[-1]["content"][-1]["type"] == "text"
        assert NOTE in system_for(c)
    print(f"self_check ok: 사례 {len(cases)}개, 문서 {sum(len(c['docs']) for c in cases.values())}개")


def todo():
    return [(c, m, r) for c in load() for m in USE for r in range(1, REPS + 1)]


def worst_usd(case, model):
    chars = len(system_for(case)) + len(json.dumps(messages_for(case), ensure_ascii=False))
    price_in, price_out = rp.PRICES[model]
    return (chars * 2 * price_in + cc.MAX_TOKENS * price_out) / 1e6


def read_log():
    return [json.loads(l) for l in LOG.read_text().splitlines() if l.strip()] if LOG.exists() else []


def run(dry):
    client = None
    if not dry:
        if not os.environ.get("ANTHROPIC_API_KEY"):
            sys.exit("ANTHROPIC_API_KEY가 없다. 같은 터미널에서 export ANTHROPIC_API_KEY=... 뒤에 다시 실행한다")
        import anthropic
        client = anthropic.Anthropic(max_retries=0)
    done, total = {(r["key"], r["input_hash"]) for r in read_log() if "error" not in r}, 0.0
    for case, short, rep in todo():
        model, key, ih = MODELS[short], f"{case['id']}:{short}:r{rep}", input_hash(case)
        worst = worst_usd(case, model)
        if dry:
            total += worst
            print(f"{key:14s} 최대 ${worst:.4f}")
            continue
        if (key, ih) in done:
            continue
        spent = rp.cost(read_log())
        if spent + worst > MAX_USD:
            sys.exit(f"stopped: spent ${spent:.4f}, next call could add ${worst:.4f}, over ${MAX_USD}")
        row = {"key": key, "case": case["id"], "model": model, "rep": rep, "input_hash": ih,
               "started_at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
        start = time.monotonic()
        try:
            resp = client.messages.create(model=model, max_tokens=cc.MAX_TOKENS, system=system_for(case),
                                          messages=messages_for(case))
            row.update(blocks=[b.model_dump(mode="json") for b in resp.content], stop_reason=resp.stop_reason,
                       input_tokens=resp.usage.input_tokens, output_tokens=resp.usage.output_tokens)
        except Exception as e:  # 실패는 기록하고 멈춘다. 다시 돌리면 이어서 한다
            row["error"] = f"{type(e).__name__}: {e}"
        row["latency_s"] = round(time.monotonic() - start, 2)
        with LOG.open("a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        if "error" in row:
            sys.exit(f"stopped at {key}: {row['error']}")
        print(key, f"사실 문제 {len(fact_problems(case, text_of(row)))}", f"{row['latency_s']}s")
    if dry:
        print(f"호출 {len(todo())}회, 최대 합계 ${total:.2f} (상한 ${MAX_USD})")


def report(citations, every=False):
    """지금 입력(지침·자료)의 기록만 보인다. every면 예전 입력의 기록(진단 자료)도."""
    cases = {c["id"]: c for c in load()}
    rows = [r for r in read_log() if "error" not in r and r["case"] in cases and r["model"] in [MODELS[m] for m in USE]
            and (every or r["input_hash"] == input_hash(cases[r["case"]]))]
    tally = {}
    for r in sorted(rows, key=lambda r: (r["case"], r["model"], r["rep"])):
        case, text = cases[r["case"]], text_of(r)
        facts, cited = fact_problems(case, text), [b for b in r["blocks"] if b["type"] == "text" and b.get("citations")]
        t = tally.setdefault(r["model"], {"기록": 0, "실제 오류": 0, "근거 부족": 0, "검토 필요": 0, "외국어 등 검토 표시": 0})
        t["기록"] += 1
        for kind in ("실제 오류", "근거 부족", "검토 필요"):
            t[kind] += any(f.startswith(kind) for f in facts)
        t["외국어 등 검토 표시"] += bool(cc.review(text))
        print(f"\n=== {r['key']} ({r['model']}, 출력 {r.get('output_tokens')}토큰, {r.get('latency_s')}s)")
        print(text)
        if r.get("stop_reason") != "end_turn":  # 사고 토큰도 출력 한도(앱과 같은 8000)에 들어간다
            print(f"  ! 잘림: stop_reason {r.get('stop_reason')}")
        for p in facts:
            print("  ! " + p)
        for p in cc.review(text):
            print("  ? " + p)
        print(f"  인용 달린 문장 {len(cited)}개")
        if citations:  # 본문이 인용한 원문의 기준·수치를 지켰는지 사람이 대조한다
            for b in cited:
                print("    본문: " + b["text"].strip().replace("\n", " ")[:160])
                for c in b["citations"]:
                    print(f"    원문[{c.get('document_title', '')[:30]}]: " + c.get("cited_text", "").strip().replace("\n", " ")[:240])
        print("  watch: " + case["watch"])
    print()
    print("자동 잠정 집계(답 수, 한 답이 여러 종류에 들 수 있음). 확정은 judgments.md의 사람 판정:")
    for model, t in tally.items():
        cost = rp.cost([r for r in rows if r["model"] == model])
        print(f"{model}: " + ", ".join(f"{k} {v}" for k, v in t.items()) + f", 비용 ${cost:.4f}")


def main():
    global ONLY, USE
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--run", action="store_true")
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--citations", action="store_true")
    ap.add_argument("--all", action="store_true", help="예전 지침·자료로 만든 기록도 보인다")
    ap.add_argument("--cases")
    ap.add_argument("--models", help="쉼표로 나눈 모델 별칭: " + ",".join(MODELS))
    a = ap.parse_args()
    ONLY = set(a.cases.split(",")) if a.cases else None
    if a.models:
        USE = a.models.split(",")
        if set(USE) - set(MODELS):
            sys.exit(f"모르는 모델: {sorted(set(USE) - set(MODELS))}")
    if a.dry_run or a.run:
        run(a.dry_run)
    elif a.report:
        report(a.citations, a.all)
    else:
        self_check()


if __name__ == "__main__":
    main()
