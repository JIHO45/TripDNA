#!/usr/bin/env python3
"""Offline checks for run_profile_exploration.py. No network: the SDK is replaced by a fake.

  python3 scripts/test_profile_exploration.py
"""
import argparse
import json
import pathlib
import sys
import tempfile
import types

sys.path.insert(0, str(pathlib.Path(__file__).parent))
import run_profile_exploration as r

ok = {"jp-tokyo"}
problems = lambda task, text: r.check_output(task, text, ok)[1]

# Format checker: never raises, flags each violation.
assert problems("recommend", '{"candidates":[{"id":"jp-tokyo","facts":["걷기 좋다."],"caveat":"확인 필요."}]}') == []
assert problems("recommend", "[]") == ["not_object"]
assert problems("recommend", '{"candidates":[null]}') == ["candidate_not_object"]
assert problems("recommend", '```json\n{"candidates":[]}\n```') == ["markdown_fence"]
assert "id_not_allowed:jp-osaka" in problems("recommend", '{"candidates":[{"id":"jp-osaka","facts":["a"],"caveat":"c"}]}')
assert problems("recommend", '{"candidates":[{"id":"jp-tokyo","facts":["a","b","c"],"caveat":"c"}]}') == ["facts_count"]
assert problems("detail", '{"answer":[1],"limits":""}') == ["answer_not_text", "limits_not_text"]
assert problems("detail", '{"answer":["See https://x.y"],"limits":"첫 문장. 둘째 문장."}') == [
    "answer_link", "limits_maybe_multi_sentence"]
assert problems("detail", "sorry") == ["not_json"]

# Call order: 24 base calls, A/B then B/A per case; repeats only for the named cases.
cases = [{"id": f"S{i}"} for i in range(1, 7)]
assert len(r.plan(cases, None, 0)) == 24
assert [x[1] for x in r.plan(cases, None, 0)[:8]] == list("AABBBBAA")
assert len(r.plan(cases, {"S1", "S4"}, 2)) == 8

# Run 2 swaps in the constraints-only arm and never includes the experience list.
c = r.build_user("C", "recommend", {"id": "S1", "user": "u"}, [{"id": "x", "name": "n", "country": "ZZ"}], {"x": {"scope": "s", "constraints": []}})
assert r.C_HEADER in c and "experiences" not in c
assert set(r.RUNS[2][0]) == {"A", "C"} and r.RUNS[1] == ("AB", "profiles.json", "runs")

# Full run path with a fake SDK.
replies = iter(["[]", '{"candidates":[null]}'])


class Resp:
    def __init__(self, text):
        self.content = [types.SimpleNamespace(type="text", text=text)]
        self.stop_reason = "end_turn"
        self.usage = types.SimpleNamespace(input_tokens=10, output_tokens=5)


fake = types.ModuleType("anthropic")
fake.APIError = type("APIError", (Exception,), {})
fake.Anthropic = lambda **kw: types.SimpleNamespace(
    messages=types.SimpleNamespace(create=lambda **kw: Resp(next(replies))))
sys.modules["anthropic"] = fake
r.LOG = pathlib.Path(tempfile.mkdtemp()) / "runs" / "responses.jsonl"
args = argparse.Namespace(dry_run=False, limit=2, cases="", rep=0, max_usd=2.0)

r.run(args)  # malformed replies are still logged with raw text and usage
rows = r.read_log()
assert [x["text"] for x in rows] == ["[]", '{"candidates":[null]}']
assert all(x["input_tokens"] == 10 and x["format_problems"] for x in rows)

rows[0]["inputs_hash"] = "different"  # a log made with other inputs must stop the run
r.LOG.write_text("\n".join(json.dumps(x) for x in rows) + "\n")
try:
    r.run(args)
    raise AssertionError("mixed inputs not detected")
except SystemExit as e:
    assert "different inputs" in str(e)

r.LOG.unlink()  # the budget is checked before the call, not after
args.max_usd = 0.001
try:
    r.run(args)
    raise AssertionError("budget not enforced")
except SystemExit as e:
    assert "over --max-usd" in str(e)
assert not r.LOG.exists()

# An API error is logged once, stops the run, and is not retried on resume.
def boom(**kw):
    raise fake.APIError("overloaded")
fake.Anthropic = lambda **kw: types.SimpleNamespace(messages=types.SimpleNamespace(create=boom))
args.max_usd = 3.0
try:
    r.run(args)
    raise AssertionError("run continued after an API error")
except SystemExit as e:
    assert "lower --max-usd" in str(e)
assert [x["key"] for x in r.read_log()] == ["S1-A-recommend-r0"] and "error" in r.read_log()[0]

# The review sheet is written once and never overwritten.
r.EXP = r.LOG.parent.parent
(r.EXP / "cases.json").write_text(json.dumps({"cases": [{"id": "S1", "user": "u", "detail": "d"}]}))
try:
    r.sheet(0)
    raise AssertionError("sheet made before the base run finished")
except SystemExit as e:
    assert "Finish the base run" in str(e)
row = r.read_log()[0]
r.LOG.write_text("\n".join(json.dumps(row) for _ in range(24)) + "\n")
r.sheet(0)
try:
    r.sheet(0)
    raise AssertionError("review sheet overwritten")
except SystemExit as e:
    assert "already exists" in str(e)

print("PASS")
