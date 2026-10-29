const test = require("node:test");
const assert = require("node:assert");
const { buildParams } = require("./index.js");

const ok = { system: "s", user: "u", model: "claude-haiku-5-5", maxTokens: "16000" };

test("앱이 보내는 요청(maxTokens 문자열)을 그대로 전달한다", () => {
  const { params, error } = buildParams(ok);
  assert.equal(error, undefined);
  assert.equal(params.max_tokens, 16000);
  assert.deepEqual(params.messages, [{ role: "user", content: "u" }]);
  assert.equal(params.tools, undefined);
});

test("검색 요청에는 web_search 도구를 붙인다", () => {
  const { params } = buildParams({ ...ok, webSearchMaxUses: 3 });
  assert.deepEqual(params.tools, [{ type: "web_search_20250305", name: "web_search", max_uses: 3 }]);
});

test("허용 범위 밖의 요청은 거부한다", () => {
  for (const bad of [
    undefined,
    { ...ok, user: "" },
    { ...ok, system: 1 },
    { ...ok, model: "claude-opus-5-5" },
    { ...ok, maxTokens: "16001" },
    { ...ok, maxTokens: "abc" },
    { ...ok, webSearchMaxUses: 4 },
    { ...ok, webSearchMaxUses: 0 },
    { ...ok, user: "x".repeat(200001) },
  ]) {
    assert.ok(buildParams(bad).error, JSON.stringify(bad)?.slice(0, 80));
  }
});
