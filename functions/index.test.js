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

test("검색 요청에는 web_search 도구를 붙이고 AI 사용량으로 센다", () => {
  const { params, usage } = buildParams({ ...ok, webSearchMaxUses: 3 });
  assert.deepEqual(params.tools, [{ type: "web_search_20250305", name: "web_search", max_uses: 3 }]);
  assert.equal(usage.kind, "chat");
  assert.equal(usage.searchUses, 3);
  assert.ok(usage.id.length >= 8); // 예전 앱: requestId가 없으면 서버가 만든다
});

const chat = { system: "s", model: "claude-haiku-5-5", maxTokens: 4000, purpose: "chat", requestId: "req-00000001",
  messages: [{ role: "user", content: "a" }, { role: "assistant", content: "b" }, { role: "user", content: "c" }] };

test("대화는 messages를 그대로 보내고 캐시를 켠다", () => {
  const { params, usage, error } = buildParams(chat);
  assert.equal(error, undefined);
  assert.equal(params.messages.length, 3);
  assert.deepEqual(params.cache_control, { type: "ephemeral" });
  assert.deepEqual(usage, { kind: "chat", id: "req-00000001", searchUses: 0, inputChars: 4 });
});

test("대화·요약 요청의 형식 검사", () => {
  const m = (...roles) => roles.map((role) => ({ role, content: "x" }));
  for (const bad of [
    { ...chat, purpose: "other" },
    { ...chat, purpose: undefined },
    { ...chat, user: "u" },
    { ...chat, messages: [] },
    { ...chat, messages: m("assistant") },
    { ...chat, messages: m("user", "assistant") },
    { ...chat, messages: m("user", "user", "user") },
    { ...chat, messages: [{ role: "user", content: "" }] },
    { ...chat, messages: [{ role: "user", content: "x".repeat(200001) }] },
    { ...chat, requestId: "bad/id" },
    { ...chat, purpose: "summary", webSearchMaxUses: 1 },
  ]) {
    assert.ok(buildParams(bad).error, JSON.stringify(bad).slice(0, 120));
  }
  assert.equal(buildParams({ ...chat, purpose: "summary" }).error, undefined);
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
  const one = run([reco("a")]).at(-1);
  assert.deepEqual(releaseUsage(one, reco("a"), "2026-11").recos, {});
  const two = run([reco("a"), reco("a")]).at(-1);
  assert.deepEqual(releaseUsage(two, reco("a"), "2026-11").recos, { a: 1 });
  assert.equal(releaseUsage(one, reco("a"), "2026-10"), null);
});

const { costOf, reserveOf, inputTokensOf, applyChatReserve, applyChatSettle, applyChatRelease, HOLD_TTL_MS, TIMEOUT_SECONDS } = require("./index.js");
const t0 = nov.getTime();
const P = "2026-11";

test("실제 비용: 단가 × 토큰(마이크로달러) + 검색 1회 1만, 10만 토큰 넘는 프롬프트는 비싼 단가", () => {
  assert.equal(costOf({ input_tokens: 1000, output_tokens: 1000 }), 100 + 500);
  assert.equal(costOf({ input_tokens: 0, cache_creation_input_tokens: 1000, cache_read_input_tokens: 10000, output_tokens: 0 }), 125 + 100);
  assert.equal(costOf({ input_tokens: 100, output_tokens: 0, server_tool_use: { web_search_requests: 2 } }), 10 + 20000);
  assert.equal(costOf({ input_tokens: 100001, output_tokens: 0 }), Math.ceil(100001 * 0.5));
  assert.equal(costOf(undefined), 0);
});

test("예약은 실제로 나올 수 있는 비용보다 크다", () => {
  const r = reserveOf({ inputTokens: 1000, maxTokens: 4000, searchUses: 0 });
  assert.ok(r >= costOf({ input_tokens: 1000, output_tokens: 4000 }));
  assert.ok(r >= costOf({ cache_creation_input_tokens: 1000, output_tokens: 4000 }));
  const s = reserveOf({ inputTokens: 1000, maxTokens: 4000, searchUses: 3 });
  assert.ok(s > 3 * 10000 + r);
});

test("토큰 계산이 실패하면 글자 수 × 상한으로 본다", async () => {
  const params = { model: "m", system: "s", messages: [] };
  assert.equal(await inputTokensOf(params, 10, async () => ({ input_tokens: 7 })), 7);
  assert.equal(await inputTokensOf(params, 10, async () => { throw new Error("x"); }), 20);
  assert.equal(await inputTokensOf(params, 10, async () => ({})), 20);
});

test("다 쓴 경우와, 남았지만 이 요청에 모자란 경우를 구분한다", () => {
  const spent = { month: P, recos: {}, chat: { used: 1000, holds: {}, settled: [] } };
  assert.equal(applyChatReserve(spent, P, 1000, "r1", 1, t0).reason, "exhausted");
  const some = { month: P, recos: {}, chat: { used: 400, holds: {}, settled: [] } };
  const r = applyChatReserve(some, P, 1000, "r1", 700, t0);
  assert.equal(r.reason, "tooLarge");
  assert.equal(r.share, 0.4);
  assert.equal(applyChatReserve(some, P, 1000, "r1", 600, t0).allowed, true);
});

test("동시 예약은 함께 예산을 넘지 못한다", () => {
  let data;
  const a = applyChatReserve(data, P, 1000, "a", 600, t0);
  data = a.next;
  const b = applyChatReserve(data, P, 1000, "b", 600, t0);
  assert.equal(b.reason, "tooLarge");
  assert.equal(applyChatReserve(data, P, 1000, "c", 400, t0).allowed, true);
});

test("정산: 예약을 풀고 실제 비용을 차감한다. 예약보다 많아도 실제 비용", () => {
  const held = applyChatReserve(undefined, P, 1000, "a", 100, t0).next;
  const s = applyChatSettle(held, P, 1000, "a", 150, t0 + 1000);
  assert.equal(s.charged, true);
  assert.equal(s.next.chat.used, 150);
  assert.deepEqual(s.next.chat.holds, {});
  assert.equal(s.share, 0.15);
});

test("같은 요청은 두 번 정산되지 않고, 같은 ID로 다시 예약할 수 없다", () => {
  const held = applyChatReserve(undefined, P, 1000, "a", 100, t0).next;
  const once = applyChatSettle(held, P, 1000, "a", 50, t0).next;
  assert.equal(applyChatSettle(once, P, 1000, "a", 50, t0).charged, false);
  assert.equal(applyChatReserve(held, P, 1000, "a", 1, t0).reason, "duplicate");
  assert.equal(applyChatReserve(once, P, 1000, "a", 1, t0).reason, "duplicate");
});

test("만료된 예약은 예산에서 빠지고, 만료 뒤 정산은 아무것도 바꾸지 않는다", () => {
  const held = applyChatReserve(undefined, P, 1000, "a", 900, t0).next;
  assert.equal(applyChatReserve(held, P, 1000, "b", 900, t0 + HOLD_TTL_MS - 1).reason, "tooLarge");
  assert.equal(applyChatReserve(held, P, 1000, "b", 900, t0 + HOLD_TTL_MS).allowed, true);
  assert.equal(applyChatSettle(held, P, 1000, "a", 50, t0 + HOLD_TTL_MS).charged, false);
});

test("예약 만료는 함수 제한 시간보다 길다", () => {
  assert.ok(HOLD_TTL_MS > TIMEOUT_SECONDS * 1000);
});

test("실패하면 예약만 풀고 차감하지 않는다. 기간이 바뀌면 그대로 둔다", () => {
  const held = applyChatReserve(undefined, P, 1000, "a", 100, t0).next;
  const r = applyChatRelease(held, P, "a");
  assert.deepEqual(r.next.chat, { used: 0, holds: {}, settled: [] });
  assert.equal(applyChatRelease(held, "2026-12", "a").next, undefined);
  assert.equal(applyChatSettle(held, "2026-12", 1000, "a", 10, t0).charged, false);
});

test("기간이 바뀌면 AI 사용량을 새로 센다", () => {
  const spent = { month: "2026-10", recos: {}, chat: { used: 5000, holds: {}, settled: ["x"] } };
  const r = applyChatReserve(spent, P, 1000, "x", 10, t0);
  assert.equal(r.allowed, true);
  assert.equal(r.next.chat.used, 0);
});

const { expireAtOf } = require("./index.js");

test("사용량 문서는 그 달이 끝나고 7일 뒤 지운다", () => {
  assert.equal(expireAtOf("2026-11").toISOString(), "2026-12-08T00:00:00.000Z");
  assert.equal(expireAtOf("2026-12").toISOString(), "2027-01-08T00:00:00.000Z");
});

const { opsExpireAtOf } = require("./index.js");

test("운영비 문서는 그 날짜(UTC)부터 90일 뒤 지운다", () => {
  assert.equal(opsExpireAtOf(new Date("2026-11-06T23:59:00Z")).toISOString(), "2027-02-04T00:00:00.000Z");
  assert.equal(opsExpireAtOf(new Date("2026-11-06T00:00:00Z")).toISOString(), "2027-02-04T00:00:00.000Z");
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

test("구독자는 원 거래 ID 문서와 구독 예산, 무료는 uid 문서와 무료 예산", () => {
  const { CHAT_BUDGETS } = require("./index.js");
  const sub = { originalTransactionId: "100", purchaseDate: Date.parse("2026-11-05T00:00:00Z") };
  const q = quotaFor("uid1", sub, nov);
  assert.equal(q.docId, "sub-100");
  assert.equal(q.subscribed, true);
  assert.equal(q.chatBudget, CHAT_BUDGETS.sub);
  assert.equal(q.resetAt, Date.parse("2026-12-05T00:00:00Z") / 1000);
  let data;
  const allowed = Array.from({ length: 31 }, (_, i) => {
    const r = applyUsage(data, reco(`r${i}`), q.period, q.limits);
    if (r.allowed) data = r.next;
    return r.allowed;
  });
  assert.equal(allowed.filter(Boolean).length, 30);
  const free = quotaFor("uid1", null, nov);
  assert.equal(free.docId, "uid1");
  assert.equal(free.subscribed, false);
  assert.equal(free.chatBudget, CHAT_BUDGETS.free);
  assert.equal(free.period, "2026-11");
});
