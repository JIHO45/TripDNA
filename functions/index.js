// 앱의 LLM 호출 중계. API 키는 서버에만 두고, 앱이 보낸 요청은 아래 상한 안에서만 전달한다.
// 계약(앱: TripDNA/Recommendation/City/CityLLMClient.swift)
//   POST {system, user, model, maxTokens, webSearchMaxUses?}
//   → 200 {content, stop_reason}: Messages API 응답 그대로. 잘림·빈 응답 판정은 앱이 한다.
// 사용자 내용은 기록하지 않는다(로그에는 상태 코드만).
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const Anthropic = require("@anthropic-ai/sdk");

const apiKey = defineSecret("ANTHROPIC_API_KEY");

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

// ponytail: 인증 없이 열린 주소다. 출시 전에 App Check·익명 ID·횟수 계수를 붙인다(구독 단계).
exports.cityLLM = onRequest(
  { secrets: [apiKey], timeoutSeconds: 180, maxInstances: 5 },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "POST only" });
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

exports.buildParams = buildParams;
