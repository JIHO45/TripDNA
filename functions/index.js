// 앱의 LLM 호출 중계. API 키는 서버에만 두고, 앱이 보낸 요청은 아래 상한 안에서만 전달한다.
// 계약(앱: TripDNA/Recommendation/City/CityLLMClient.swift, CityLLMCredentials.swift)
//   POST {system, user, model, maxTokens, webSearchMaxUses?}
//   헤더: Authorization: Bearer <익명 로그인 ID 토큰>, X-Firebase-AppCheck: <App Check 토큰>
//   → 200 {content, stop_reason}: Messages API 응답 그대로. 잘림·빈 응답 판정은 앱이 한다.
//   → 401: 두 토큰 중 하나라도 없거나 검증에 실패.
// 사용자 내용은 기록하지 않는다(로그에는 상태 코드만).
const { onRequest } = require("firebase-functions/v2/https");
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
  }
  return { params };
}

// ponytail: 호출 횟수 제한이 없다. 정식 앱 사용자라면 무제한으로 부를 수 있다. 무료 한도는 Firestore 계수로 붙인다(구독 단계).
exports.cityLLM = onRequest(
  { secrets: [apiKey], timeoutSeconds: 180, maxInstances: 5 },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "POST only" });
    if (!(await verifyCaller(req))) return res.status(401).json({ error: "unauthorized" });
    const { params, error } = buildParams(req.body);
    if (error) return res.status(400).json({ error });

    try {
      const client = new Anthropic({ apiKey: apiKey.value() });
      const message = await client.messages.create(params);
      res.json({ content: message.content, stop_reason: message.stop_reason });
    } catch (e) {
      const status = e instanceof Anthropic.APIError ? e.status : undefined;
      logger.error("anthropic call failed", { status, type: e?.constructor?.name });
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

exports.metricEventOf = metricEventOf;
exports.buildParams = buildParams;
exports.verifyCaller = verifyCaller;
