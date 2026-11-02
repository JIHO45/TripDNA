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
    const r = applyUsage(data, u, now.toISOString().slice(0, 7));
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
  assert.equal(applyUsage(full, reco("d"), "2026-11").allowed, false);
  assert.equal(applyUsage(full, reco("d"), "2026-12").allowed, true);
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

const { applyDailyCall, DAILY_CALL_CAP } = require("./index.js");

test("하루 전체 호출 상한까지 받고, 넘으면 막는다", () => {
  assert.deepEqual(applyDailyCall(undefined), { allowed: true, next: { calls: 1 } });
  assert.equal(applyDailyCall({ calls: DAILY_CALL_CAP - 1 }).allowed, true);
  assert.equal(applyDailyCall({ calls: DAILY_CALL_CAP }).allowed, false);
});

const { bitsFor, checkDevice, deviceJWT } = require("./index.js");
const crypto = require("node:crypto");

test("기기 비트는 이어지는 달마다 다르다", () => {
  const months = ["2026-11", "2026-12", "2027-01", "2027-02"].map((m) => JSON.stringify(bitsFor(m)));
  assert.equal(new Set(months).size, 4);
  assert.deepEqual(bitsFor("2026-11"), bitsFor("2027-03"));
});

function fakeApple(state) {
  const calls = [];
  const call = async (path, body) => {
    calls.push([path, body]);
    return path === "query_two_bits" ? state : {};
  };
  return { call, calls };
}

test("이번 달에 기록된 기기는 claimed, 아니면 이번 달로 기록한다", async () => {
  const thisMonth = fakeApple({ bit0: true, bit1: false, last_update_time: "2026-11" });
  assert.equal(await checkDevice("t", "2026-11", thisMonth.call), "claimed");
  assert.equal(thisMonth.calls.length, 1);

  for (const state of [null, { bit0: true, bit1: true, last_update_time: "2026-10" }]) {
    const apple = fakeApple(state);
    assert.equal(await checkDevice("t", "2026-11", apple.call), "ok");
    assert.deepEqual(apple.calls[1], ["update_two_bits", { device_token: "t", ...bitsFor("2026-11") }]);
  }
});

test("DeviceCheck JWT는 ES256으로 서명된다", () => {
  const { privateKey, publicKey } = crypto.generateKeyPairSync("ec", { namedCurve: "P-256" });
  const pem = privateKey.export({ type: "pkcs8", format: "pem" });
  const [header, payload, signature] = deviceJWT(pem, "KEY123", 1_800_000_000_000).split(".");
  assert.deepEqual(JSON.parse(Buffer.from(header, "base64url")), { alg: "ES256", kid: "KEY123" });
  assert.deepEqual(JSON.parse(Buffer.from(payload, "base64url")), { iss: "CH7CDR7288", iat: 1_800_000_000 });
  const ok = crypto.verify("sha256", Buffer.from(`${header}.${payload}`), { key: publicKey, dsaEncoding: "ieee-p1363" },
    Buffer.from(signature, "base64url"));
  assert.ok(ok);
});

const { verifySubscription, subscriptionPeriod, quotaFor } = require("./index.js");

test("구독 거래: 우리 상품이고 만료·환불 전이어야 한다", async () => {
  const base = { productId: "tripdna.subscription.monthly", originalTransactionId: "100", purchaseDate: Date.parse("2026-11-01T00:00:00Z"), expiresDate: Date.parse("2026-12-01T00:00:00Z") };
  const check = (t) => verifySubscription("jws", nov, async () => t);
  assert.equal((await check(base))?.originalTransactionId, "100");
  assert.equal(await check({ ...base, productId: "other" }), null);
  assert.equal(await check({ ...base, expiresDate: Date.parse("2026-11-10T00:00:00Z") }), null);
  assert.equal(await check({ ...base, revocationDate: Date.parse("2026-11-10T00:00:00Z") }), null);
  assert.equal(await check(null), null);
  assert.equal(await verifySubscription("jws", nov, async () => { throw new Error("bad signature"); }), null);
});

test("구독 기간은 결제일부터 한 달씩, 없는 날은 말일", () => {
  const jan31 = Date.parse("2026-01-31T10:00:00Z");
  assert.deepEqual(subscriptionPeriod(jan31, new Date("2026-01-31T10:00:00Z")), { start: jan31, end: Date.parse("2026-02-28T10:00:00Z") });
  assert.deepEqual(subscriptionPeriod(jan31, new Date("2026-03-15T00:00:00Z")), { start: Date.parse("2026-02-28T10:00:00Z"), end: Date.parse("2026-03-31T10:00:00Z") });
  // 연 구독도 매달 다시 채운다.
  const p = subscriptionPeriod(Date.parse("2026-03-05T00:00:00Z"), nov);
  assert.equal(p.start, Date.parse("2026-11-05T00:00:00Z"));
});

test("구독자는 원 거래 ID 문서에 30회, 무료는 uid 문서에 3회", () => {
  const sub = { originalTransactionId: "100", purchaseDate: Date.parse("2026-11-05T00:00:00Z") };
  const q = quotaFor("uid1", sub, nov);
  assert.equal(q.docId, "sub-100");
  assert.equal(q.subscribed, true);
  assert.equal(q.resetAt, Date.parse("2026-12-05T00:00:00Z") / 1000);
  let data;
  const allowed = Array.from({ length: 31 }, () => {
    const r = applyUsage(data, question, q.period, q.limits);
    if (r.allowed) data = r.next;
    return r.allowed;
  });
  assert.equal(allowed.filter(Boolean).length, 30);
  const free = quotaFor("uid1", null, nov);
  assert.equal(free.docId, "uid1");
  assert.equal(free.subscribed, false);
  assert.equal(free.period, "2026-11");
});
