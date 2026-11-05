// 앱의 LLM 호출 중계. API 키는 서버에만 두고, 앱이 보낸 요청은 아래 상한 안에서만 전달한다.
// 계약(앱: TripDNA/Recommendation/City/CityLLMClient.swift, CityLLMCredentials.swift)
//   POST {system, user | messages, model, maxTokens, webSearchMaxUses?, usageId?, purpose?, requestId?}
//     추천: {system, user, usageId}. 질문·대화: purpose("chat"|"summary") 또는 webSearchMaxUses가 있으면 AI 사용량으로 센다.
//     messages는 [{role, content}] 대화(user로 시작·끝, 번갈아). requestId는 정산 중복을 막는 요청별 ID(없으면 서버가 만든다).
//   헤더: Authorization: Bearer <익명 로그인 ID 토큰>, X-Firebase-AppCheck: <App Check 토큰>,
//         X-Apple-Device-Token: <DeviceCheck 토큰>(출시 빌드만. 없으면 기기 확인을 건너뛴다),
//         X-Apple-Transaction: <구독 거래 JWS>(구독 중일 때만. 검증되면 구독 한도로 센다)
//   → 200 {content, stop_reason, usage?}: Messages API 응답. 질문·대화면 usage {share, resetAt, subscribed}(이번 기간 AI 사용량 비율).
//     잘림·빈 응답 판정은 앱이 한다.
//   → 401: 두 토큰 중 하나라도 없거나 검증에 실패.
//   → 429 {error: "quota", kind, resetAt, subscribed, reason?, share?}: 한도에 막혔다. resetAt은 다시 채워지는 시각(유닉스 초).
//     질문·대화(kind "chat")의 reason: "exhausted"(다 씀) | "tooLarge"(남았지만 이 요청의 예약분보다 적다).
//   → 409 {error: "duplicate"}: 같은 requestId를 이미 받았다.
//   → 503 {error: "busy"}: 오늘(UTC) 전체 호출 상한에 닿았다. 사용자 한도는 차감하지 않는다.
// 추천은 usageId(추천받기 1회의 ID)별로 1회로 세고, 질문·대화는 비용 예산(AI 사용량)에서 예약 뒤 실제 비용으로 정산한다.
// 사용자 내용은 기록하지 않는다(로그에는 상태 코드만). Firestore에는 익명 uid별 이번 달 횟수와 추천 ID만 둔다.
const { onRequest } = require("firebase-functions/v2/https");
const functionsV1 = require("firebase-functions/v1");
const { defineSecret, defineString } = require("firebase-functions/params");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { SignedDataVerifier, Environment } = require("@apple/app-store-server-library");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getAppCheck } = require("firebase-admin/app-check");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const Anthropic = require("@anthropic-ai/sdk");

initializeApp();
const apiKey = defineSecret("ANTHROPIC_API_KEY");

const verifiers = {
  appCheck: (token) => getAppCheck().verifyToken(token),
  idToken: (token) => getAuth().verifyIdToken(token),
};

// 정식 앱(App Check)의 이 프로젝트 사용자(익명 로그인)인지 확인하고 uid를 돌려준다. 아니면 null.
async function verifyCaller(req, verify = verifiers) {
  const appCheckToken = req.get("X-Firebase-AppCheck");
  const idToken = /^Bearer (.+)$/.exec(req.get("Authorization") ?? "")?.[1];
  if (!appCheckToken || !idToken) return null;
  try {
    await verify.appCheck(appCheckToken);
    return (await verify.idToken(idToken)).uid;
  } catch {
    return null;
  }
}

const MODEL = "claude-haiku-5-5";
const MAX_TOKENS = 16000;
const MAX_INPUT_CHARS = 200000;
const MAX_SEARCH_USES = 3;

const MAX_MESSAGES = 400;
const ID_PATTERN = /^[A-Za-z0-9-]{8,64}$/;

// 대화는 user로 시작하고 끝나며 번갈아야 한다. 맞으면 글자 수, 아니면 null.
function messagesLength(messages) {
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > MAX_MESSAGES || messages.length % 2 === 0) return null;
  let total = 0;
  for (const [i, m] of messages.entries()) {
    if (m?.role !== (i % 2 === 0 ? "user" : "assistant") || typeof m.content !== "string" || m.content.length === 0) return null;
    total += m.content.length;
  }
  return total;
}

// 요청 본문을 Messages API 인자로 바꾼다. 허용 범위 밖이면 {error}를 돌려준다.
function buildParams(body) {
  const { system, user, messages, model, maxTokens, webSearchMaxUses, purpose } = body ?? {};
  if (typeof system !== "string") return { error: "system must be a string" };
  if (purpose !== undefined && purpose !== "chat" && purpose !== "summary") return { error: "purpose not allowed" };
  if ((user === undefined) === (messages === undefined)) return { error: "send user or messages" };
  if (messages !== undefined && purpose === undefined) return { error: "messages need purpose" };
  const inputLength = messages !== undefined ? messagesLength(messages) : (typeof user === "string" && user.length > 0 ? user.length : null);
  if (inputLength === null) return { error: "user or messages invalid" };
  if (system.length + inputLength > MAX_INPUT_CHARS) return { error: "input too long" };
  if (model !== MODEL) return { error: "model not allowed" };
  const tokens = Number(maxTokens);
  if (!Number.isInteger(tokens) || tokens < 1 || tokens > MAX_TOKENS) return { error: "maxTokens out of range" };

  const params = { model, max_tokens: tokens, system, messages: messages ?? [{ role: "user", content: user }] };
  const isChat = purpose !== undefined || webSearchMaxUses !== undefined;
  if (!isChat) {
    const id = body.usageId;
    if (typeof id !== "string" || !ID_PATTERN.test(id)) return { error: "usageId required" };
    return { params, usage: { kind: "recommend", id } };
  }

  let searchUses = 0;
  if (webSearchMaxUses !== undefined) {
    if (purpose === "summary") return { error: "summary cannot search" };
    searchUses = Number(webSearchMaxUses);
    if (!Number.isInteger(searchUses) || searchUses < 1 || searchUses > MAX_SEARCH_USES) return { error: "webSearchMaxUses out of range" };
    params.tools = [{ type: "web_search_20250305", name: "web_search", max_uses: searchUses }];
  }
  if (body.requestId !== undefined && (typeof body.requestId !== "string" || !ID_PATTERN.test(body.requestId))) {
    return { error: "requestId invalid" };
  }
  // 대화가 길어질수록 앞부분을 다시 읽으므로 캐시를 쓴다(앞부분이 같으면 읽기 값이 10분의 1).
  params.cache_control = { type: "ephemeral" };
  // 예전 앱은 requestId를 보내지 않는다. 그 요청은 한 번만 정산되면 되므로 서버가 만든다.
  return { params, usage: { kind: "chat", id: body.requestId ?? crypto.randomUUID(), searchUses, inputChars: system.length + inputLength } };
}

// 한도(2026-10-17 결정, 월 기준). 추천 1회는 조건 추출과 추천 본문, 두 호출을 쓴다.
// 앱은 실패한 추천을 다시 시도할 때 같은 ID를 한 번 더 쓴다. 그래서 ID 하나에 호출 4번(두 번 시도)까지 1회로 센다.
const FREE_LIMITS = { recommend: 3 };
const SUB_LIMITS = { recommend: 30 };
const CALLS_PER_RECOMMEND = 4;

const monthOf = (now) => now.toISOString().slice(0, 7);
// 다음 달 1일 00:00 UTC(2026-10-23 결정). 유닉스 초.
const resetAtOf = (now) => Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1) / 1000;
// 사용량 문서의 삭제 시각: 그 달이 끝나고 7일 뒤(처리방침, 2026-10-31 결정).
// 실제 삭제는 Firestore TTL 정책(usage 컬렉션의 expireAt 필드)이 한다. 정책은 콘솔·gcloud에서 한 번 켠다.
const expireAtOf = (month) => {
  const [y, m] = month.split("-").map(Number);
  return new Date(Date.UTC(y, m, 8));
};

// 이번 호출을 셀 수 있으면 {allowed: true, next}(저장할 문서), 한도를 넘으면 {allowed: false}.
// 문서: {month: 기간 키, recos: {추천ID: 호출 수}, chat: {used, holds, settled}}. 기간 키가 바뀌면 새로 시작한다.
// 기간 키는 무료면 "YYYY-MM"(UTC 달), 구독이면 이번 한 달 기간의 시작 시각(밀리초 문자열)이다.
function applyUsage(data, usage, month, limits = FREE_LIMITS) {
  const cur = data?.month === month ? data : { month, recos: {} };
  const calls = cur.recos[usage.id];
  if (calls === undefined && Object.keys(cur.recos).length >= limits.recommend) return { allowed: false };
  if (calls >= CALLS_PER_RECOMMEND) return { allowed: false };
  return { allowed: true, next: { ...cur, recos: { ...cur.recos, [usage.id]: (calls ?? 0) + 1 } } };
}

// Anthropic 호출이 실패하면 그 호출을 되돌린다. 그사이 달이 바뀌었으면 그대로 둔다(null).
// 앱이 응답을 검사하다 실패한 경우(잘림·형식 오류)는 여기서 되돌리지 않고, 앱이 같은 ID로 다시 시도해 추가 차감을 피한다.
function releaseUsage(data, usage, month) {
  if (data?.month !== month) return null;
  const recos = { ...data.recos };
  const calls = (recos[usage.id] ?? 0) - 1;
  if (calls > 0) recos[usage.id] = calls; else delete recos[usage.id];
  return { ...data, recos };
}

// AI 사용량(2026-11-03 결정): 질문·대화는 횟수가 아니라 비용 예산으로 센다. 단위는 마이크로달러(US$ 1 = 1,000,000) 정수.
// 호출 전에 이 요청이 쓸 수 있는 최대 비용을 예약하고, 끝나면 실제 비용으로 정산한다. 사용자 차감과 운영비(ops)는 따로 센다.
// 가격: claude-haiku-5-5, 2026-11-03 가격표(US$/MTok). 프롬프트(입력+캐시 쓰기+캐시 읽기)가 10만 토큰을 넘는 요청은 비싼 단가.
// MTok당 달러 × 토큰 수 = 마이크로달러.
const PRICES = {
  low: { input: 0.10, cacheWrite: 0.125, cacheRead: 0.01, output: 0.50 },
  high: { input: 0.50, cacheWrite: 0.625, cacheRead: 0.05, output: 2.50 },
};
const LONG_PROMPT_TOKENS = 100000;
const SEARCH_FEE = 10000; // 검색 1회 US$0.01
// ponytail: 측정 전 값. 검색 한 번이 입력에 더하는 토큰의 상한과, 토큰 계산 API가 실패할 때 쓰는 글자당 토큰 상한.
const SEARCH_RESULT_TOKEN_CAP = 15000;
const FALLBACK_TOKENS_PER_CHAR = 2;
// 2026-11-06 사용자 결정(Haiku 5.5 실측 기준 초기 운영값): 무료 월 US$0.10, 구독 기간당 US$1.50.
// 대화 1회 약 US$0.012~0.024, 추천 30회 약 US$0.04~0.09라 구독자 월 원가 목표 약 US$2 안에 여유가 남는다.
// ponytail: 실사용 데이터 없이 정한 값. ops·chat.used를 보고 조정하고, 모델을 바꾸면 다시 계산한다.
const CHAT_BUDGETS = { free: 100000, sub: 1500000 };
// 예약 만료는 함수 제한 시간보다 길다. 함수가 끝나면 늦은 응답이 올 수 없으므로, 만료로 풀린 예산을 실행 중인 호출이 쓰는 일이 없다.
const TIMEOUT_SECONDS = 180;
const HOLD_TTL_MS = (TIMEOUT_SECONDS + 120) * 1000;
const SETTLED_KEEP = 50;

function tierOf(promptTokens) {
  return promptTokens > LONG_PROMPT_TOKENS ? PRICES.high : PRICES.low;
}

// 받은 usage로 계산한 실제 비용. 캐시 쓰기는 5분 캐시만 쓴다.
function costOf(u) {
  const input = u?.input_tokens ?? 0, write = u?.cache_creation_input_tokens ?? 0, read = u?.cache_read_input_tokens ?? 0;
  const p = tierOf(input + write + read);
  const searches = u?.server_tool_use?.web_search_requests ?? 0;
  return Math.ceil(input * p.input + write * p.cacheWrite + read * p.cacheRead + (u?.output_tokens ?? 0) * p.output) + searches * SEARCH_FEE;
}

// 예약 금액(보수적 상한). 입력은 모두 캐시 쓰기 단가로, 검색이 있으면 검색 결과를 더한 입력을 검색마다 다시 읽는 것으로 본다.
function reserveOf({ inputTokens, maxTokens, searchUses }) {
  const prompt = inputTokens + searchUses * SEARCH_RESULT_TOKEN_CAP;
  const p = tierOf(prompt);
  return Math.ceil(prompt * (searchUses + 1) * p.cacheWrite + maxTokens * p.output) + searchUses * SEARCH_FEE;
}

// 입력 토큰은 토큰 계산 API로 센다. 실패하면 글자 수 × 상한으로 본다.
async function inputTokensOf(params, inputChars, count) {
  try {
    const { input_tokens: n } = await count({ model: params.model, system: params.system, messages: params.messages, tools: params.tools });
    if (Number.isInteger(n) && n > 0) return n;
  } catch {
    logger.warn("token count failed");
  }
  return inputChars * FALLBACK_TOKENS_PER_CHAR;
}

const emptyChat = () => ({ used: 0, holds: {}, settled: [] });
const liveHolds = (holds, nowMs) => Object.fromEntries(Object.entries(holds ?? {}).filter(([, h]) => nowMs - h.at < HOLD_TTL_MS));
const shareOf = (used, budget) => Math.min(1, used / budget);

// 예약. 막히면 reason: "duplicate"(같은 요청 ID) | "exhausted"(다 씀) | "tooLarge"(남았지만 이 예약보다 적다).
// 동시 요청도 각자 트랜잭션 안에서 예약하므로, 함께 예산을 넘지 못한다.
function applyChatReserve(data, period, budget, id, amount, nowMs) {
  const cur = data?.month === period ? data : { month: period, recos: {} };
  const chat = cur.chat ?? emptyChat();
  const holds = liveHolds(chat.holds, nowMs);
  if (id in holds || chat.settled.includes(id)) return { allowed: false, reason: "duplicate" };
  const share = shareOf(chat.used, budget);
  if (chat.used >= budget) return { allowed: false, reason: "exhausted", share };
  const held = Object.values(holds).reduce((sum, h) => sum + h.amount, 0);
  if (chat.used + held + amount > budget) return { allowed: false, reason: "tooLarge", share };
  return { allowed: true, share, next: { ...cur, chat: { ...chat, holds: { ...holds, [id]: { amount, at: nowMs } } } } };
}

// 정산. 예약이 살아 있을 때만 실제 비용을 차감한다(예약보다 많아도 실제 비용). 이미 정산했거나 만료된 요청은 바꾸지 않는다.
function applyChatSettle(data, period, budget, id, cost, nowMs) {
  const chat = data?.month === period ? data.chat : undefined;
  const hold = chat?.holds?.[id];
  if (!hold || nowMs - hold.at >= HOLD_TTL_MS) return { charged: false };
  const { [id]: _, ...rest } = chat.holds;
  const used = chat.used + cost;
  return {
    charged: true, share: shareOf(used, budget),
    next: { ...data, chat: { used, holds: liveHolds(rest, nowMs), settled: [...chat.settled, id].slice(-SETTLED_KEEP) } },
  };
}

// 실패한 호출의 예약을 푼다. 사용자에게는 차감하지 않는다.
function applyChatRelease(data, period, id) {
  const chat = data?.month === period ? data.chat : undefined;
  if (!chat?.holds?.[id]) return {};
  const { [id]: _, ...rest } = chat.holds;
  return { next: { ...data, chat: { ...chat, holds: rest } } };
}

// 운영비(사용자 정보 없음): ops/{YYYY-MM-DD} = {started, confirmed, confirmedCost, unknown, expireAt}.
// 실패한 호출은 제공자가 청구했는지 알 수 없어 unknown으로만 센다. 함수가 도중에 끝난 호출은 started − confirmed − unknown이다.
// 생성일(문서 날짜 00:00 UTC)부터 90일 뒤 삭제(처리방침 5절, 2026-11-06 결정). budget 문서도 같은 값을 쓴다. 삭제는 각 컬렉션의 expireAt TTL 정책이 한다.
const opsExpireAtOf = (now) =>
  new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()) + 90 * DAY_MS);
function recordOps(now, fields) {
  const inc = Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, FieldValue.increment(v)]));
  return getFirestore().collection("ops").doc(now.toISOString().slice(0, 10)).set({ ...inc, expireAt: opsExpireAtOf(now) }, { merge: true })
    .catch(() => logger.error("ops record failed"));
}

// 구독 확인(2026-10-07 결정: 앱이 보낸 거래 JWS를 Apple 공식 라이브러리로 검증).
// 서명이 Apple Root CA G3까지 이어지고 번들 ID·환경이 맞아야 한다. 운영(App Store)을 먼저, 아니면 Sandbox(TestFlight·심사)로 본다.
// Xcode 로컬 StoreKit 거래는 Xcode 인증서로 서명돼 여기서 통과하지 못한다(무료 한도로 센다).
const BUNDLE_ID = "com.Joe.TripDNA";
const SUB_PRODUCTS = new Set(["tripdna.subscription.monthly", "tripdna.subscription.yearly"]);
const appAppleId = defineString("APP_APPLE_ID"); // App Store Connect > 앱 정보 > Apple ID(숫자)
const appleRoots = [fs.readFileSync(path.join(__dirname, "AppleRootCA-G3.cer"))];

async function decodeTransaction(jws) {
  for (const env of [Environment.PRODUCTION, Environment.SANDBOX]) {
    const appId = env === Environment.PRODUCTION ? Number(appAppleId.value()) : undefined;
    try {
      return await new SignedDataVerifier(appleRoots, true, env, BUNDLE_ID, appId).verifyAndDecodeTransaction(jws);
    } catch {
      // 다음 환경으로
    }
  }
  return null;
}

// 지금 유효한 구독 거래면 그 내용을, 아니면 null(무료 사용자로 센다).
async function verifySubscription(jws, now, decode = decodeTransaction) {
  const t = await decode(jws).catch(() => null);
  if (!t || !SUB_PRODUCTS.has(t.productId) || t.revocationDate || !t.originalTransactionId) return null;
  if (!(t.expiresDate > now.getTime()) || !(t.purchaseDate <= now.getTime())) return null;
  return t;
}

// 구독 한도는 결제 주기를 따른다(2026-10-23 결정). 이번 결제일부터 한 달씩 끊어, 연 구독도 매달 30회다.
// 31일 결제처럼 없는 날은 그 달 말일로 맞춘다. {start, end}는 밀리초.
function subscriptionPeriod(purchaseMs, now) {
  const p = new Date(purchaseMs);
  const at = (k) => {
    const y = p.getUTCFullYear();
    const m = p.getUTCMonth() + k;
    const lastDay = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
    return Date.UTC(y, m, Math.min(p.getUTCDate(), lastDay), p.getUTCHours(), p.getUTCMinutes(), p.getUTCSeconds(), p.getUTCMilliseconds());
  };
  let k = 0;
  while (at(k + 1) <= now.getTime()) k++;
  return { start: at(k), end: at(k + 1) };
}

// 누구의 어떤 한도로 셀지. 구독은 원 거래 ID별로 세서, 거래 정보를 여러 기기·사람이 나눠 써도 30회를 함께 쓴다.
// 구독 문서에는 익명 uid를 두지 않는다. 계정 삭제 트리거가 아니라 TTL(기간 끝 7일 뒤)로 지워진다.
const DAY_MS = 24 * 60 * 60 * 1000;
function quotaFor(uid, sub, now) {
  if (!sub) {
    const month = monthOf(now);
    return {
      docId: uid, period: month, limits: FREE_LIMITS, chatBudget: CHAT_BUDGETS.free,
      resetAt: resetAtOf(now), expireAt: expireAtOf(month), subscribed: false,
    };
  }
  const { start, end } = subscriptionPeriod(sub.purchaseDate, now);
  return {
    docId: `sub-${sub.originalTransactionId}`, period: String(start), limits: SUB_LIMITS, chatBudget: CHAT_BUDGETS.sub,
    resetAt: Math.floor(end / 1000), expireAt: new Date(end + 7 * DAY_MS), subscribed: true,
  };
}

// DeviceCheck(2026-11-02 결정): 재설치·전체 삭제로 새 익명 ID를 받아도 같은 기기에서는 그 달 무료 한도를 다시 주지 않는다.
// Apple이 기기마다 2비트와 마지막 기록 달(YYYY-MM)을 보관하며 재설치해도 남는다. 익명 ID가 그 달 처음 부를 때만
// 조회해서, 이번 달에 이미 기록된 기기면 무료 한도 없음(429), 아니면 이번 달로 기록하고 사용량 문서에 deviceMonth를 남긴다.
// 토큰이 없거나(개발 빌드·토큰 생성 실패) Apple 호출이 실패하면 확인을 건너뛴다. 비용은 하루 전체 상한이 막는다.
const deviceKey = defineSecret("DEVICECHECK_KEY"); // Apple Developer > Keys에서 만든 DeviceCheck .p8 파일 내용
const deviceKeyId = defineString("DEVICECHECK_KEY_ID");
const TEAM_ID = "CH7CDR7288";

// 같은 값을 다시 쓰면 기록 달이 갱신되지 않을 수 있어(확인하지 않음) 달마다 다른 비트를 쓴다.
// ponytail: 4달 주기로 같은 값이 돌아온다. 그 경우 기록 달이 안 바뀌면 그 달 한 번 더 무료가 생길 수 있다.
function bitsFor(month) {
  const [y, m] = month.split("-").map(Number);
  const index = y * 12 + m;
  return { bit0: index % 2 === 1, bit1: Math.floor(index / 2) % 2 === 1 };
}

// "claimed": 이번 달에 이미 다른 익명 ID가 쓴 기기. "ok": 이번 달로 기록했다.
async function checkDevice(token, month, call) {
  const state = await call("query_two_bits", { device_token: token });
  if (state?.last_update_time === month) return "claimed";
  await call("update_two_bits", { device_token: token, ...bitsFor(month) });
  return "ok";
}

function deviceJWT(keyPem, keyId, now = Date.now()) {
  const part = (obj) => Buffer.from(JSON.stringify(obj)).toString("base64url");
  const input = `${part({ alg: "ES256", kid: keyId })}.${part({ iss: TEAM_ID, iat: Math.floor(now / 1000) })}`;
  const signature = crypto.sign("sha256", Buffer.from(input), { key: keyPem, dsaEncoding: "ieee-p1363" });
  return `${input}.${signature.toString("base64url")}`;
}

// 출시 빌드(TestFlight·App Store)의 토큰만 받으므로 운영 주소만 쓴다.
async function callDeviceCheck(path, body) {
  const res = await fetch(`https://api.devicecheck.apple.com/v1/${path}`, {
    method: "POST",
    headers: { Authorization: `Bearer ${deviceJWT(deviceKey.value(), deviceKeyId.value())}`, "content-type": "application/json" },
    body: JSON.stringify({ ...body, transaction_id: crypto.randomUUID(), timestamp: Date.now() }),
  });
  if (!res.ok) throw new Error(`devicecheck ${res.status}`);
  const text = await res.text();
  try {
    return JSON.parse(text);
  } catch {
    return null; // 한 번도 기록하지 않은 기기는 JSON 대신 "Failed to find bit state"가 온다.
  }
}

// 전체 비용 상한(2026-11-01 결정). DeviceCheck를 건너뛰는 경우를 포함해 하루(UTC) 전체 호출 수를 막는다. 넘으면 그날은 모두 503.
// ponytail: 고정값. 출시 뒤 실제 비용(metrics·청구서)을 보고 조정한다.
const DAILY_CALL_CAP = 1000;

function applyDailyCall(data) {
  const calls = data?.calls ?? 0;
  return calls >= DAILY_CALL_CAP ? { allowed: false } : { allowed: true, next: { calls: calls + 1 } };
}

// 문서: budget/{YYYY-MM-DD} = {calls, expireAt}. 사용자 정보는 없다. ops와 같이 90일 뒤 TTL로 지운다(2026-11-06 결정).
function takeDailyCall(now) {
  const ref = getFirestore().collection("budget").doc(now.toISOString().slice(0, 10));
  return getFirestore().runTransaction(async (tx) => {
    const result = applyDailyCall((await tx.get(ref)).data());
    if (result.next) tx.set(ref, { ...result.next, expireAt: opsExpireAtOf(now) });
    return result.allowed;
  });
}

function updateUsage(docId, expireAt, change) {
  const ref = getFirestore().collection("usage").doc(docId);
  return getFirestore().runTransaction(async (tx) => {
    const result = change((await tx.get(ref)).data());
    if (result?.next) tx.set(ref, { ...result.next, expireAt });
    return result;
  });
}

exports.cityLLM = onRequest(
  { secrets: [apiKey, deviceKey], timeoutSeconds: TIMEOUT_SECONDS, maxInstances: 5 },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "POST only" });
    const uid = await verifyCaller(req);
    if (!uid) return res.status(401).json({ error: "unauthorized" });
    const { params, usage, error } = buildParams(req.body);
    if (error) return res.status(400).json({ error });

    const now = new Date();
    const month = monthOf(now);
    const transaction = req.get("X-Apple-Transaction");
    const sub = transaction ? await verifySubscription(transaction, now) : null;
    if (transaction && !sub) logger.warn("subscription not verified");
    const quota = quotaFor(uid, sub, now);
    const isChat = usage.kind === "chat";
    const quotaExceeded = (reason = "exhausted", share) => res.status(429).json({
      error: "quota", kind: usage.kind, resetAt: quota.resetAt, subscribed: quota.subscribed,
      ...(isChat ? { reason, share } : {}),
    });

    // 기기 확인은 무료 한도의 재설치 우회를 막는 것이라 구독자는 건너뛴다.
    const deviceToken = sub ? undefined : req.get("X-Apple-Device-Token");
    let deviceChecked = false;
    if (deviceToken) {
      try {
        const doc = (await getFirestore().collection("usage").doc(uid).get()).data();
        if (doc?.month !== month || doc.deviceMonth !== month) {
          if ((await checkDevice(deviceToken, month, callDeviceCheck)) === "claimed") return quotaExceeded();
          deviceChecked = true;
        }
      } catch {
        logger.warn("device check skipped");
      }
    }

    const client = new Anthropic({ apiKey: apiKey.value() });
    const reserve = isChat
      ? reserveOf({
        inputTokens: await inputTokensOf(params, usage.inputChars, (p) => client.messages.countTokens(p)),
        maxTokens: params.max_tokens, searchUses: usage.searchUses,
      })
      : 0;

    let result;
    try {
      result = await updateUsage(quota.docId, quota.expireAt, (data) => {
        const r = isChat
          ? applyChatReserve(data, quota.period, quota.chatBudget, usage.id, reserve, now.getTime())
          : applyUsage(data, usage, quota.period, quota.limits);
        if (deviceChecked && r.next) r.next.deviceMonth = month;
        return r;
      });
    } catch {
      // 셀 수 없으면 부르지 않는다(무제한 호출을 막는다).
      logger.error("usage check failed");
      return res.status(503).json({ error: "usage unavailable" });
    }
    if (result.reason === "duplicate") return res.status(409).json({ error: "duplicate" });
    if (!result.allowed) return quotaExceeded(result.reason, result.share);

    const release = () => updateUsage(quota.docId, quota.expireAt, (data) =>
      isChat ? applyChatRelease(data, quota.period, usage.id) : { next: releaseUsage(data, usage, quota.period) })
      .catch(() => logger.error("usage release failed"));
    // 사용자 한도를 통과한 뒤에 센다. 막히면 사용자 한도는 되돌린다.
    const open = await takeDailyCall(now).catch(() => false);
    if (!open) {
      logger.warn("daily call cap reached or unavailable");
      await release();
      return res.status(503).json({ error: "busy" });
    }

    await recordOps(now, { started: 1 });
    let message;
    try {
      message = await client.messages.create(params);
    } catch (e) {
      const status = e instanceof Anthropic.APIError ? e.status : undefined;
      logger.error("anthropic call failed", { status, type: e?.constructor?.name });
      await Promise.all([release(), recordOps(now, { unknown: 1 })]);
      // 앱에는 원인만 구분해 준다: 상류 과부하·한도는 503, 그 밖은 502.
      return res.status(status === 429 || status >= 500 ? 503 : 502).json({ error: "upstream failed" });
    }

    const cost = costOf(message.usage);
    await recordOps(now, { confirmed: 1, confirmedCost: cost });
    if (!isChat) return res.json({ content: message.content, stop_reason: message.stop_reason });

    let share = result.share;
    try {
      const settled = await updateUsage(quota.docId, quota.expireAt, (data) =>
        applyChatSettle(data, quota.period, quota.chatBudget, usage.id, cost, Date.now()));
      if (settled.charged) share = settled.share;
      else logger.warn("settle skipped: hold expired or already settled");
    } catch {
      // 정산을 못 하면 예약은 만료 때 풀린다. 답은 이미 받았으므로 그대로 준다.
      logger.error("usage settle failed");
    }
    res.json({
      content: message.content, stop_reason: message.stop_reason,
      usage: { share, resetAt: quota.resetAt, subscribed: quota.subscribed },
    });
  }
);

// 출시 후 관측(R5)용 익명 집계. 앱이 POST {event}를 보내면 그날(UTC) 그 이벤트 수만 1 올린다.
// 정식 앱(App Check)만 받고 익명 ID는 받지 않는다: 누가 보냈는지 남기지 않는다. 로그도 남기지 않는다.
// Firestore: metrics/{YYYY-MM-DD} = {이벤트: 수}. 앱: TripDNA/App/ServerMetricsSink.swift(보내는 이벤트 목록).
const METRIC_EVENTS = new Set([
  "onboarding_completed", "first_recommendation_shown", "city_recommendation_received", "city_recommendation_failed",
  "city_saved", "city_skipped", "city_excluded", "memory_forgotten",
  "share_card_exported", "error_report_opened",
]);

const metricEventOf = (body) => (METRIC_EVENTS.has(body?.event) ? body.event : null);

exports.metric = onRequest({ maxInstances: 2 }, async (req, res) => {
  if (req.method !== "POST") return res.status(405).end();
  const token = req.get("X-Firebase-AppCheck");
  try {
    if (!token) throw new Error();
    await verifiers.appCheck(token);
  } catch {
    return res.status(401).end();
  }
  const event = metricEventOf(req.body);
  if (!event) return res.status(400).end();
  const day = new Date().toISOString().slice(0, 10);
  await getFirestore().collection("metrics").doc(day).set({ [event]: FieldValue.increment(1) }, { merge: true });
  res.status(204).end();
});

// 익명 계정이 지워지면(앱의 모든 데이터 지우기) 그 uid의 사용량 문서도 지운다.
// 앱이 오프라인이라 계정 대신 로그아웃만 했으면 이 트리거는 돌지 않고, 문서는 expireAt에 TTL로 지워진다.
exports.deleteUserData = functionsV1.auth.user().onDelete((user) =>
  getFirestore().collection("usage").doc(user.uid).delete()
);

exports.expireAtOf = expireAtOf;
exports.opsExpireAtOf = opsExpireAtOf;
exports.metricEventOf = metricEventOf;
exports.buildParams = buildParams;
exports.bitsFor = bitsFor;
exports.checkDevice = checkDevice;
exports.deviceJWT = deviceJWT;
exports.applyUsage = applyUsage;
exports.applyDailyCall = applyDailyCall;
exports.DAILY_CALL_CAP = DAILY_CALL_CAP;
exports.releaseUsage = releaseUsage;
exports.resetAtOf = resetAtOf;
exports.verifyCaller = verifyCaller;
exports.verifySubscription = verifySubscription;
exports.subscriptionPeriod = subscriptionPeriod;
exports.quotaFor = quotaFor;
exports.costOf = costOf;
exports.reserveOf = reserveOf;
exports.inputTokensOf = inputTokensOf;
exports.applyChatReserve = applyChatReserve;
exports.applyChatSettle = applyChatSettle;
exports.applyChatRelease = applyChatRelease;
exports.HOLD_TTL_MS = HOLD_TTL_MS;
exports.TIMEOUT_SECONDS = TIMEOUT_SECONDS;
exports.CHAT_BUDGETS = CHAT_BUDGETS;
