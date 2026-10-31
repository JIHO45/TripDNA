// 앱의 LLM 호출 중계. API 키는 서버에만 두고, 앱이 보낸 요청은 아래 상한 안에서만 전달한다.
// 계약(앱: TripDNA/Recommendation/City/CityLLMClient.swift, CityLLMCredentials.swift)
//   POST {system, user, model, maxTokens, webSearchMaxUses?, usageId?}
//   헤더: Authorization: Bearer <익명 로그인 ID 토큰>, X-Firebase-AppCheck: <App Check 토큰>
//   → 200 {content, stop_reason}: Messages API 응답 그대로. 잘림·빈 응답 판정은 앱이 한다.
//   → 401: 두 토큰 중 하나라도 없거나 검증에 실패.
//   → 429 {error: "quota", kind, resetAt}: 이번 달 무료 한도를 다 썼다. resetAt은 다시 채워지는 UTC 시각(유닉스 초).
// 검색 호출은 상세 질문 1회, 검색 없는 호출은 usageId(추천받기 1회의 ID)별로 추천 1회로 센다.
// 사용자 내용은 기록하지 않는다(로그에는 상태 코드만). Firestore에는 익명 uid별 이번 달 횟수와 추천 ID만 둔다.
const { onRequest } = require("firebase-functions/v2/https");
const functionsV1 = require("firebase-functions/v1");
const { defineSecret } = require("firebase-functions/params");
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

// 요청 본문을 Messages API 인자로 바꾼다. 허용 범위 밖이면 {error}를 돌려준다.
function buildParams(body) {
  const { system, user, model, maxTokens, webSearchMaxUses } = body ?? {};
  if (typeof system !== "string" || typeof user !== "string" || user.length === 0) {
    return { error: "system and user must be strings" };
  }
  if (system.length + user.length > MAX_INPUT_CHARS) return { error: "input too long" };
  if (model !== MODEL) return { error: "model not allowed" };
  const tokens = Number(maxTokens);
  if (!Number.isInteger(tokens) || tokens < 1 || tokens > MAX_TOKENS) return { error: "maxTokens out of range" };

  const params = { model, max_tokens: tokens, system, messages: [{ role: "user", content: user }] };
  if (webSearchMaxUses !== undefined) {
    const uses = Number(webSearchMaxUses);
    if (!Number.isInteger(uses) || uses < 1 || uses > MAX_SEARCH_USES) return { error: "webSearchMaxUses out of range" };
    params.tools = [{ type: "web_search_20250305", name: "web_search", max_uses: uses }];
    return { params, usage: { kind: "question" } };
  }
  const id = body.usageId;
  if (typeof id !== "string" || !/^[A-Za-z0-9-]{8,64}$/.test(id)) return { error: "usageId required" };
  return { params, usage: { kind: "recommend", id } };
}

// 무료 한도(2026-10-17 결정, 월 기준). 추천 1회는 조건 추출과 추천 본문, 두 호출을 쓴다.
// 앱은 실패한 추천을 다시 시도할 때 같은 ID를 한 번 더 쓴다. 그래서 ID 하나에 호출 4번(두 번 시도)까지 1회로 센다.
// ponytail: 구독(StoreKit 검증)이 없어 모두 무료 한도다. 구독 한도 30회는 구독 검증과 함께 붙인다.
const LIMITS = { recommend: 3, question: 3 };
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
// 문서: {month: "YYYY-MM", recos: {추천ID: 호출 수}, questions: 수}. 달이 바뀌면 새로 시작한다.
function applyUsage(data, usage, now) {
  const month = monthOf(now);
  const cur = data?.month === month ? data : { month, recos: {}, questions: 0 };
  if (usage.kind === "question") {
    if (cur.questions >= LIMITS.question) return { allowed: false };
    return { allowed: true, next: { ...cur, questions: cur.questions + 1 } };
  }
  const calls = cur.recos[usage.id];
  if (calls === undefined && Object.keys(cur.recos).length >= LIMITS.recommend) return { allowed: false };
  if (calls >= CALLS_PER_RECOMMEND) return { allowed: false };
  return { allowed: true, next: { ...cur, recos: { ...cur.recos, [usage.id]: (calls ?? 0) + 1 } } };
}

// Anthropic 호출이 실패하면 그 호출을 되돌린다. 그사이 달이 바뀌었으면 그대로 둔다(null).
// 앱이 응답을 검사하다 실패한 경우(잘림·형식 오류)는 여기서 되돌리지 않고, 앱이 같은 ID로 다시 시도해 추가 차감을 피한다.
function releaseUsage(data, usage, month) {
  if (data?.month !== month) return null;
  if (usage.kind === "question") return { ...data, questions: Math.max(0, data.questions - 1) };
  const recos = { ...data.recos };
  const calls = (recos[usage.id] ?? 0) - 1;
  if (calls > 0) recos[usage.id] = calls; else delete recos[usage.id];
  return { ...data, recos };
}

function updateUsage(uid, change) {
  const ref = getFirestore().collection("usage").doc(uid);
  return getFirestore().runTransaction(async (tx) => {
    const result = change((await tx.get(ref)).data());
    if (result?.next) tx.set(ref, { ...result.next, expireAt: expireAtOf(result.next.month) });
    return result;
  });
}

exports.cityLLM = onRequest(
  { secrets: [apiKey], timeoutSeconds: 180, maxInstances: 5 },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "POST only" });
    const uid = await verifyCaller(req);
    if (!uid) return res.status(401).json({ error: "unauthorized" });
    const { params, usage, error } = buildParams(req.body);
    if (error) return res.status(400).json({ error });

    const now = new Date();
    let allowed;
    try {
      ({ allowed } = await updateUsage(uid, (data) => applyUsage(data, usage, now)));
    } catch {
      // 셀 수 없으면 부르지 않는다(무제한 호출을 막는다).
      logger.error("usage check failed");
      return res.status(503).json({ error: "usage unavailable" });
    }
    if (!allowed) return res.status(429).json({ error: "quota", kind: usage.kind, resetAt: resetAtOf(now) });

    try {
      const client = new Anthropic({ apiKey: apiKey.value() });
      const message = await client.messages.create(params);
      res.json({ content: message.content, stop_reason: message.stop_reason });
    } catch (e) {
      const status = e instanceof Anthropic.APIError ? e.status : undefined;
      logger.error("anthropic call failed", { status, type: e?.constructor?.name });
      await updateUsage(uid, (data) => ({ next: releaseUsage(data, usage, monthOf(now)) }))
        .catch(() => logger.error("usage release failed"));
      // 앱에는 원인만 구분해 준다: 상류 과부하·한도는 503, 그 밖은 502.
      res.status(status === 429 || status >= 500 ? 503 : 502).json({ error: "upstream failed" });
    }
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
exports.metricEventOf = metricEventOf;
exports.buildParams = buildParams;
exports.applyUsage = applyUsage;
exports.releaseUsage = releaseUsage;
exports.resetAtOf = resetAtOf;
exports.verifyCaller = verifyCaller;
