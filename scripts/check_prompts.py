"""추천·조건 추출 지침의 실제 호출 검증. 사례: data/exploration/prompt-check/cases.json

앱이 실제로 만드는 요청을 쓰기 위해 요청 조립과 응답 검사는 Swift 테스트(TripDNATests/PromptExportTests)가 한다.
이 스크립트는 그 테스트를 부르고, 사이에서 모델을 호출하고, 결과를 모아 보여 준다. 앱 언어는 xcodebuild -testLanguage로 바꾼다.

연결 검증(기본, mode linked): 1단계 실제 추출 응답을 2단계 추천 입력으로 쓴다. 추출 응답이 없으면 그 사례의 추천은 만들지 않는다.
단계별 검증(--mode staged): 사례에 적은 가짜 조건으로 2단계를 만든다. 결과 폴더가 따로다(runs/<lang>-<mode>).
응답은 responses.jsonl에 요청 해시·모델과 함께 계속 쌓는다(덮어쓰지 않음). 같은 해시·모델은 다시 부르지 않는다.

    .venv/bin/python scripts/check_prompts.py cycle --lang ko --cases E03,R01,R02,E05   # 내보내기→추출 호출→다시 내보내기→추천 호출→검사
    .venv/bin/python scripts/check_prompts.py run --lang en --cases R01,E06,R02 --reps 3   # 같은 요청의 추천 응답을 3개까지(재현 확인)
    python3 scripts/check_prompts.py check --lang en --nth 2                               # 2번째 응답을 앱 검증 코드로 검사
    python3 scripts/check_prompts.py report --lang ko --cases E03,R01,R02,E05
    (export / run / check 를 따로 부를 수도 있다. --model 로 모델을 바꾼다. 기본은 앱 모델.)
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / "data" / "exploration" / "prompt-check"
SWIFT_CLIENT = ROOT / "TripDNA/Recommendation/City/CityLLMClient.swift"
DERIVED = Path(os.environ.get("TRIPDNA_DERIVED", "/tmp/tripdna-prompt-check-dd"))
PRICES = {"claude-haiku-5-5": (0.10, 0.50), "claude-sonnet-5-5": (2.00, 10.00)}  # 2026-11-05 공식 가격표
MAX_USD = 1.0  # 실행 폴더 하나의 누적 상한


def app_model():
    return re.search(r'static let model = "([^"]+)"', SWIFT_CLIENT.read_text()).group(1)


def max_tokens():
    return int(re.search(r"static let maxTokens = (\d+)", SWIFT_CLIENT.read_text()).group(1))


def run_dir(a):
    d = BASE / "runs" / f"{a.lang}-{a.mode}"
    d.mkdir(parents=True, exist_ok=True)
    return d


def req_hash(r):
    return hashlib.sha256((r["system"] + "\n\0\n" + r["user"]).encode()).hexdigest()[:16]


def log(d):
    p = d / "responses.jsonl"
    return [json.loads(l) for l in p.read_text().splitlines() if l.strip()] if p.exists() else []


def latest(d, model, nth=None):
    """(요청 해시) → 그 모델의 응답 기록. 기본은 가장 최근, nth(1부터)를 주면 그 해시의 n번째 응답."""
    out, seen = {}, {}
    for row in log(d):
        if row["model"] == model:
            seen[row["hash"]] = seen.get(row["hash"], 0) + 1
            if nth is None or seen[row["hash"]] == nth:
                out[row["hash"]] = row
    return out


def counts(d, model):
    out = {}
    for row in log(d):
        if row["model"] == model:
            out[row["hash"]] = out.get(row["hash"], 0) + 1
    return out


def requests(d):
    p = d / "requests.json"
    return json.loads(p.read_text()) if p.exists() else []


def selected_cases(a):
    data = json.loads((BASE / "cases.json").read_text())
    if a.cases:
        keep = set(a.cases.split(","))
        missing = keep - {c["id"] for c in data["cases"]}
        if missing:
            sys.exit(f"없는 사례: {sorted(missing)}")
        data["cases"] = [c for c in data["cases"] if c["id"] in keep]
    return data


def xcode(a, test):
    d = run_dir(a)
    region = {"ko": "KR", "en": "US"}[a.lang]
    cmd = ["xcodebuild", "-quiet", "-project", str(ROOT / "TripDNA.xcodeproj"), "-scheme", "TripDNA",
           "-destination", "platform=iOS Simulator,name=iPhone 17", "-derivedDataPath", str(DERIVED),
           "-testLanguage", a.lang, "-testRegion", region, "test", f"-only-testing:TripDNATests/PromptExportTests/{test}"]
    env = dict(os.environ, TEST_RUNNER_TRIPDNA_PROMPT_DIR=str(d), TEST_RUNNER_TRIPDNA_PROMPT_MODE=a.mode)
    print(f"xcodebuild {test} ({a.lang}, {a.mode}) ...", flush=True)
    r = subprocess.run(cmd, env=env, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("xcodebuild 실패:\n" + (r.stdout + r.stderr)[-3000:])


def export(a):
    d = run_dir(a)
    (d / "cases.json").write_text(json.dumps(selected_cases(a), ensure_ascii=False, indent=1))
    if a.mode == "linked":  # 이전에 내보낸 추출 요청과 해시가 같은 실제 응답만 넘긴다
        done = latest(d, a.model)
        ext = {r["caseID"]: done[req_hash(r)]["text"] for r in requests(d)
               if r["stage"] == "extract" and req_hash(r) in done}
        (d / "extractions.json").write_text(json.dumps(ext, ensure_ascii=False, indent=1))
    xcode(a, "exportRequests()")
    reqs = requests(d)
    info = json.loads((d / "export-info.json").read_text())
    print(f"요청 {len(reqs)}개: " + ", ".join(r["id"] for r in reqs))
    if info.get("missingExtraction"):
        print("추출 응답이 없어 추천 요청을 만들지 않은 사례:", info["missingExtraction"])


def worst(r, model):
    pin, pout = PRICES[model]
    return ((len(r["system"]) + len(r["user"])) * 2 * pin + max_tokens() * pout) / 1e6


def run(a):
    if not os.environ.get("ANTHROPIC_API_KEY"):
        sys.exit("ANTHROPIC_API_KEY가 없다. 같은 터미널에서 export ANTHROPIC_API_KEY=... 뒤에 다시 실행한다")
    import anthropic
    client = anthropic.Anthropic(max_retries=0)
    d = run_dir(a)
    have = counts(d, a.model)
    spent = sum(row.get("usd", 0) for row in log(d))
    keep = set(a.cases.split(",")) if a.cases else None
    calls = [r for r in requests(d) if keep is None or r["caseID"] in keep for _ in range(max(0, (a.reps if r["stage"] == "recommend" else 1) - have.get(req_hash(r), 0)))]
    for r in calls:
        h = req_hash(r)
        if spent + worst(r, a.model) > MAX_USD:
            sys.exit(f"stopped: spent ${spent:.4f}, over ${MAX_USD}")
        start = time.monotonic()
        resp = client.messages.create(model=a.model, max_tokens=max_tokens(), system=r["system"],
                                      messages=[{"role": "user", "content": r["user"]}])
        pin, pout = PRICES[a.model]
        usd = (resp.usage.input_tokens * pin + resp.usage.output_tokens * pout) / 1e6
        spent += usd
        row = {"id": r["id"], "case": r["caseID"], "stage": r["stage"], "hash": h, "model": a.model,
               "text": "".join(b.text for b in resp.content if b.type == "text"), "stop": resp.stop_reason,
               "usd": usd, "in": resp.usage.input_tokens, "out": resp.usage.output_tokens,
               "s": round(time.monotonic() - start, 1), "at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}
        with (d / "responses.jsonl").open("a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        print(r["id"], resp.stop_reason, f"${usd:.4f}")
    print(f"이 폴더 누적 ${spent:.4f}")


def check(a):
    d = run_dir(a)
    done = latest(d, a.model, a.nth)
    current = {r["id"]: done[req_hash(r)]["text"] for r in requests(d) if req_hash(r) in done}
    (d / "current.json").write_text(json.dumps(current, ensure_ascii=False, indent=1))
    xcode(a, "checkResponses()")
    checks = json.loads((d / "checks.json").read_text())
    with (d / "checks.jsonl").open("a") as f:  # 검사 결과도 덮어쓰지 않고 해시와 함께 남긴다
        for r in requests(d):
            if r["id"] in checks:
                f.write(json.dumps({"id": r["id"], "hash": req_hash(r), "model": a.model, "nth": a.nth, "check": checks[r["id"]],
                                    "at": time.strftime("%Y-%m-%dT%H:%M:%S%z")}, ensure_ascii=False) + "\n")
    print(json.dumps(checks, ensure_ascii=False, indent=1))


def report(a):
    d = run_dir(a)
    cases = {c["id"]: c for c in selected_cases(a)["cases"]}
    checks = json.loads((d / "checks.json").read_text()) if (d / "checks.json").exists() else {}
    done = latest(d, a.model, a.nth)
    info = json.loads((d / "export-info.json").read_text()) if (d / "export-info.json").exists() else {}
    print(f"모드 {info.get('mode')}, 모델 {a.model}, 추출 응답 없음: {info.get('missingExtraction') or '-'}")
    for r in requests(d):
        if r["caseID"] not in cases or req_hash(r) not in done:
            continue
        c = cases[r["caseID"]]
        print(f"\n=== {r['id']} ({a.lang}, 해시 {req_hash(r)})")
        if r["stage"] == "extract":
            print("입력:", (c.get("wants") or "") + " / " + (c.get("avoids") or ""), "| 기대 level:", c.get("expect_levels"))
        else:
            conds = r["user"].split("[Conditions from this request")[1].split("\n\n")[0] if "[Conditions from this request" in r["user"] else "(조건 없음)"
            print("추천 입력의 조건:", conds.strip().replace("\n", " / "))
            print("후보:", ", ".join(r["cardIDs"]))
        print(done[req_hash(r)]["text"].strip()[:3000])
        print("  앱 검사:", json.dumps(checks.get(r["id"], {"검사": "check 미실행"}), ensure_ascii=False))
        print("  watch:", c["watch"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["export", "run", "check", "report", "cycle"])
    ap.add_argument("--lang", choices=["ko", "en"], default="ko")
    ap.add_argument("--mode", choices=["linked", "staged"], default="linked")
    ap.add_argument("--cases", help="쉼표로 나눈 사례 id. 예: E03,R01")
    ap.add_argument("--model")
    ap.add_argument("--reps", type=int, default=1, help="run: 추천 요청마다 응답을 이 개수까지 모은다(추출은 1회, 같은 추출 결과로 추천만 반복)")
    ap.add_argument("--nth", type=int, help="check/report: 각 요청의 n번째 응답(1부터)을 본다. 기본은 가장 최근")
    a = ap.parse_args()
    a.model = a.model or app_model()
    if a.command == "cycle":
        export(a); run(a)
        if a.mode == "linked":
            export(a); run(a)
        check(a)
    else:
        {"export": export, "run": run, "check": check, "report": report}[a.command](a)


if __name__ == "__main__":
    main()
