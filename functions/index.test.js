const test = require("node:test");
const assert = require("node:assert");
const { buildParams } = require("./index.js");

const ok = { system: "s", user: "u", model: "claude-haiku-5-5", maxTokens: "16000", usageId: "5F0C1A2B-0000-4000-8000-000000000001" };

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
    { ...ok, usageId: undefined },
    { ...ok, usageId: "short" },
    { ...ok, usageId: "a/b/../../c-d-e-f" },
  ]) {
    assert.ok(buildParams(bad).error, JSON.stringify(bad)?.slice(0, 80));
  }
});

const { verifyCaller } = require("./index.js");

function req(headers) {
  return { get: (name) => headers[name] };
}
const pass = { appCheck: async () => ({}), idToken: async () => ({ uid: "u1" }) };
const reject = async () => { throw new Error("invalid"); };

test("두 토큰이 모두 맞으면 uid를 돌려준다", async () => {
  const uid = await verifyCaller(req({ "X-Firebase-AppCheck": "a", Authorization: "Bearer t" }), pass);
  assert.equal(uid, "u1");
});

test("토큰이 없거나 하나라도 틀리면 거부한다", async () => {
  const both = { "X-Firebase-AppCheck": "a", Authorization: "Bearer t" };
  assert.equal(await verifyCaller(req({}), pass), null);
  assert.equal(await verifyCaller(req({ Authorization: "Bearer t" }), pass), null);
  assert.equal(await verifyCaller(req({ "X-Firebase-AppCheck": "a", Authorization: "t" }), pass), null);
  assert.equal(await verifyCaller(req(both), { ...pass, appCheck: reject }), null);
  assert.equal(await verifyCaller(req(both), { ...pass, idToken: reject }), null);
});

const { applyUsage, releaseUsage, resetAtOf } = require("./index.js");
const nov = new Date("2026-11-15T12:00:00Z");
const reco = (id) => ({ kind: "recommend", id });
const question = { kind: "question" };

// 앞에서부터 차례로 적용하고 각 호출의 허용 여부를 돌려준다.
function run(usages, now = nov, data) {
  return usages.map((u) => {
    const r = applyUsage(data, u, now);
    if (r.allowed) data = r.next;
    return r.allowed;
  }).concat([data]);
}

test("추천은 ID별로 1회, 한 추천은 호출 네 번(재시도 포함)까지, 월 3회", () => {
  const result = run([reco("a"), reco("a"), reco("a"), reco("a"), reco("a"), reco("b"), reco("c"), reco("d"), reco("c")]);
  assert.deepEqual(result.slice(0, -1), [true, true, true, true, false, true, true, false, true]);
});

test("질문은 호출마다 1회, 월 3회. 추천과 따로 센다", () => {
  const result = run([question, question, reco("a"), question, question]);
  assert.deepEqual(result.slice(0, -1), [true, true, true, true, false]);
});

test("달이 바뀌면(UTC) 다시 채운다", () => {
  const full = run([reco("a"), reco("b"), reco("c")]).at(-1);
  assert.equal(applyUsage(full, reco("d"), new Date("2026-11-30T23:59:59Z")).allowed, false);
  assert.equal(applyUsage(full, reco("d"), new Date("2026-12-01T00:00:00Z")).allowed, true);
});

test("다시 채우는 시각은 다음 달 1일 00:00 UTC", () => {
  assert.equal(resetAtOf(nov), Date.UTC(2026, 11, 1) / 1000);
  assert.equal(resetAtOf(new Date("2026-12-31T23:00:00Z")), Date.UTC(2027, 0, 1) / 1000);
});

test("상류 실패는 그 호출만 되돌린다", () => {
  const one = run([reco("a"), question]).at(-1);
  assert.deepEqual(releaseUsage(one, reco("a"), "2026-11").recos, {});
  assert.equal(releaseUsage(one, question, "2026-11").questions, 0);
  const two = run([reco("a"), reco("a")]).at(-1);
  assert.deepEqual(releaseUsage(two, reco("a"), "2026-11").recos, { a: 1 });
  assert.equal(releaseUsage(one, reco("a"), "2026-10"), null);
});

const { expireAtOf } = require("./index.js");

test("사용량 문서는 그 달이 끝나고 7일 뒤 지운다", () => {
  assert.equal(expireAtOf("2026-11").toISOString(), "2026-12-08T00:00:00.000Z");
  assert.equal(expireAtOf("2026-12").toISOString(), "2027-01-08T00:00:00.000Z");
});

const { metricEventOf } = require("./index.js");

test("집계 이벤트는 정해진 이름만 받는다", () => {
  assert.equal(metricEventOf({ event: "share_card_exported" }), "share_card_exported");
  for (const bad of [undefined, {}, { event: "toString" }, { event: "x/y" }, { event: ["share_card_exported"] }]) {
    assert.equal(metricEventOf(bad), null, JSON.stringify(bad));
  }
});
