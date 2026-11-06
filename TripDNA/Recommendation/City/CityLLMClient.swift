import Foundation
import Security

/// LLM 호출 한 번. 앱 번들과 저장소에는 API 키를 두지 않으므로 호출 경로는 둘뿐이다.
/// - 프록시: Info.plist의 `CityLLMProxyURL`이 가리키는 서버(Firebase 함수 등)가 키를 쥔다.
/// - 개발용 직접 호출: DEBUG 빌드에서 사용자가 Keychain에 넣은 키.
nonisolated protocol CityLLMClient: Sendable {
    func complete(system: String, user: String) async throws -> String
}

nonisolated enum CityLLMError: Error, Equatable {
    case notConfigured
    case http(Int)
    case emptyResponse
    /// `max_tokens`에 닿아 응답이 잘렸다. 생각(thinking) 토큰도 이 한도에 들어간다.
    case truncated
    /// 프록시의 이번 추천 한도(무료 또는 구독)를 다 썼다. `resetAt`에 다시 채워진다.
    case quotaExceeded(resetAt: Date)
    /// 질문·대화의 AI 사용량(비용 예산)에 막혔다.
    case usageLimit(AIUsageLimit)
}

/// 이번 기간 AI 사용량. 서버가 질문·대화 응답과 429에 붙인다.
nonisolated struct AIUsage: Codable, Equatable, Sendable {
    /// 쓴 비율(0~1).
    let share: Double
    let resetAt: Date
    let subscribed: Bool
}

nonisolated struct AIUsageLimit: Equatable, Sendable {
    enum Reason: String, Sendable {
        /// 다 썼다.
        case exhausted
        /// 남았지만 이 요청의 예약분보다 적다. 예약분은 검색·출력 상한이 대부분이라 질문을 줄여도 거의 줄지 않으므로,
        /// 사실상 이번 기간 사용량에 닿은 것으로 안내한다.
        case tooLarge
    }
    let reason: Reason
    let resetAt: Date
    let subscribed: Bool
    let share: Double?

    /// 무료면 두 경우 모두 구독 화면을 연다. 구독자에게는 열지 않는다(추가 구매가 없다).
    var offersSubscription: Bool { !subscribed }

    /// 무료는 업그레이드 안내, 구독은 다시 채워지는 날짜만.
    var message: String {
        let time = resetAt.formatted(.dateTime.month().day().hour().minute())
        switch (reason, subscribed) {
        case (.tooLarge, true):
            return String(localized: "There isn't enough AI usage left this period for this request. It refills on \(time).")
        case (.tooLarge, false):
            return String(localized: "There isn't enough free AI usage left this month for this request. It refills on \(time). Subscribe to use more.")
        case (.exhausted, true):
            return String(localized: "You've used up this period's AI usage. It refills on \(time).")
        case (.exhausted, false):
            return String(localized: "You've used up this month's free AI usage. It refills on \(time). Subscribe to use more.")
        }
    }
}

/// 대화 한 차례. 서버는 user로 시작하고 끝나며 번갈아 오는 목록만 받는다.
nonisolated struct ChatTurn: Equatable, Sendable {
    enum Role: String, Codable, Sendable { case user, assistant }
    let role: Role
    let content: String
}

nonisolated enum ChatPurpose: String, Sendable {
    case chat
    /// 오래된 대화의 요약. 검색하지 않는다.
    case summary
}

/// 대화 응답. 프록시면 이번 기간 AI 사용량이 함께 온다.
nonisolated struct ChatReply: Decodable, Equatable, Sendable {
    let reply: CitySearchReply
    let usage: AIUsage?

    private struct Usage: Decodable { let share: Double; let resetAt: TimeInterval; let subscribed: Bool }
    private enum CodingKeys: String, CodingKey { case usage }

    init(reply: CitySearchReply, usage: AIUsage?) { self.reply = reply; self.usage = usage }

    init(from decoder: Decoder) throws {
        reply = try CitySearchReply(from: decoder)
        let raw = try? decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(Usage.self, forKey: .usage)
        usage = raw.map { AIUsage(share: $0.share, resetAt: Date(timeIntervalSince1970: $0.resetAt), subscribed: $0.subscribed) }
    }
}

nonisolated protocol ChatClient: Sendable {
    func chat(system: String, turns: [ChatTurn], purpose: ChatPurpose, searchUses: Int?) async throws -> ChatReply
}

nonisolated struct CityLLMConfiguration: Sendable {
    static let model = "claude-haiku-5-5"
    /// claude-haiku-5-5는 기본으로 생각을 켜고, 그 토큰도 이 한도에 들어간다. 3500에서는 후보 8곳 설명이 잘렸다.
    static let maxTokens = 16000
    /// 응답에 사용자 조건·평가 메모가 담기므로 디스크 캐시를 남기지 않는다(`.shared`는 응답을 앱 캐시 폴더에 저장했다).
    static let session = URLSession(configuration: .ephemeral)
    /// 프록시 요청 대기 시간. 서버 함수 제한(180초, functions/index.js TIMEOUT_SECONDS)보다 길게 둔다.
    /// 앱이 먼저 끊으면 서버는 끝까지 호출하고 사용량을 차감해, 사용자는 답 없이 사용량만 잃는다.
    static let proxyTimeout: TimeInterval = 190

    /// 프록시 주소가 있으면 프록시, 없으면 DEBUG 빌드의 Keychain 키, 둘 다 없으면 nil.
    /// `usageID`는 추천받기 한 번의 ID다. 프록시는 이 ID로 추천 1회를 센다.
    static func makeClient(usageID: String = UUID().uuidString, bundle: Bundle = .main) -> (any CityLLMClient)? {
        guard var proxy = makeSearchClient(bundle: bundle) as? CityLLMProxyClient else { return makeSearchClient(bundle: bundle) }
        proxy.usageID = usageID
        return proxy
    }

    /// 대화 응답 한도. 생각 토큰도 들어간다. 예약 금액에 들어가므로 추천보다 작게 둔다.
    static let chatMaxTokens = 8000

    /// 두 클라이언트 모두 웹 검색 호출과 대화도 지원한다. 질문·대화 기능이 쓴다.
    static func makeSearchClient(bundle: Bundle = .main) -> (any CityLLMClient & CitySearchClient & ChatClient)? {
        if let raw = bundle.object(forInfoDictionaryKey: "CityLLMProxyURL") as? String,
           !raw.isEmpty, let url = URL(string: raw) {
            return CityLLMProxyClient(url: url, model: model)
        }
        #if DEBUG
        if let key = DevAPIKeyStore.read(), !key.isEmpty {
            return AnthropicDirectClient(apiKey: key, model: model)
        }
        #endif
        return nil
    }
}

/// 프록시 계약(서버: functions/index.js): POST {system, user, model, maxTokens, webSearchMaxUses?}
/// → 200 {"content": [...], "stop_reason": "..."}. Messages API 응답을 가공 없이 돌려주므로
/// 잘림·빈 응답 판정은 직접 호출과 같은 `messageText(from:)`로 한다.
/// webSearchMaxUses가 있으면 서버가 `web_search_20250305` 도구를 붙인다.
/// 서버는 검색·대화 호출을 AI 사용량(비용 예산)으로, 검색 없는 추천 호출을 usageId별 추천 1회로 센다. 한도에 막히면
/// 429 {"resetAt": 유닉스 초, "subscribed": 구독 한도였는지, "kind", "reason"?, "share"?}.
/// 구독 중이면 헤더 X-Apple-Transaction(CityLLMCredentials)으로 알린다.
nonisolated struct CityLLMProxyClient: CityLLMClient, CitySearchClient, ChatClient {
    let url: URL
    let model: String
    /// 추천받기 한 번의 ID. 조건 추출과 추천 본문이 같은 ID로 한 번만 세진다(`makeClient(usageID:)`).
    var usageID = UUID().uuidString

    func completeWithSearch(system: String, user: String, maxUses: Int) async throws -> CitySearchReply {
        var request = URLRequest(url: url, timeoutInterval: CityLLMConfiguration.proxyTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "system": system, "user": user, "model": model,
            "maxTokens": String(CityLLMConfiguration.maxTokens), "webSearchMaxUses": maxUses,
            "requestId": UUID().uuidString
        ] as [String: Any])
        for (field, value) in try await CityLLMCredentials.headers() { request.setValue(value, forHTTPHeaderField: field) }
        let (data, response) = try await CityLLMConfiguration.session.data(for: request)
        try Self.check(response, data)
        return try JSONDecoder().decode(CitySearchReply.self, from: data)
    }

    func chat(system: String, turns: [ChatTurn], purpose: ChatPurpose, searchUses: Int?) async throws -> ChatReply {
        var request = URLRequest(url: url, timeoutInterval: CityLLMConfiguration.proxyTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: Self.chatBody(
            model: model, system: system, turns: turns, purpose: purpose, searchUses: searchUses, requestID: UUID().uuidString
        ))
        for (field, value) in try await CityLLMCredentials.headers() { request.setValue(value, forHTTPHeaderField: field) }
        let (data, response) = try await CityLLMConfiguration.session.data(for: request)
        try Self.check(response, data)
        return try JSONDecoder().decode(ChatReply.self, from: data)
    }

    static func chatBody(model: String, system: String, turns: [ChatTurn], purpose: ChatPurpose, searchUses: Int?, requestID: String) -> [String: Any] {
        var body: [String: Any] = [
            "system": system, "model": model, "purpose": purpose.rawValue, "requestId": requestID,
            "maxTokens": String(CityLLMConfiguration.chatMaxTokens),
            "messages": turns.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        if let searchUses { body["webSearchMaxUses"] = searchUses }
        return body
    }

    func complete(system: String, user: String) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: CityLLMConfiguration.proxyTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(
            [
                "system": system, "user": user, "model": model,
                "maxTokens": String(CityLLMConfiguration.maxTokens), "usageId": usageID
            ]
        )
        for (field, value) in try await CityLLMCredentials.headers() { request.setValue(value, forHTTPHeaderField: field) }
        let (data, response) = try await CityLLMConfiguration.session.data(for: request)
        try Self.check(response, data)
        return try messageText(from: data)
    }

    static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return }
        struct Quota: Decodable {
            let resetAt: TimeInterval
            let kind: String?
            let reason: String?
            let subscribed: Bool?
            let share: Double?
        }
        if http.statusCode == 429, let quota = try? JSONDecoder().decode(Quota.self, from: data) {
            let resetAt = Date(timeIntervalSince1970: quota.resetAt)
            if quota.kind == "chat" {
                throw CityLLMError.usageLimit(AIUsageLimit(
                    reason: quota.reason.flatMap(AIUsageLimit.Reason.init) ?? .exhausted,
                    resetAt: resetAt, subscribed: quota.subscribed ?? false, share: quota.share
                ))
            }
            throw CityLLMError.quotaExceeded(resetAt: resetAt)
        }
        throw CityLLMError.http(http.statusCode)
    }

    /// 한도 소진 안내. 다시 채워지는 시각은 기기 시간대로 보여준다(예: 한국이면 12월 1일 오전 9:00).
    static func quotaMessage(_ what: String, resetAt: Date, subscribed: Bool = false) -> String {
        let time = resetAt.formatted(.dateTime.month().day().hour().minute())
        return subscribed
            ? String(localized: "You've used up this month's subscription \(particled(what, .eulReul)). It refills on \(time).")
            : String(localized: "You've used up this month's free \(particled(what, .eulReul)). It refills on \(time).")
    }
}

/// 개발용. 키는 Keychain에서만 읽고 어디에도 기록하지 않는다. 출시 빌드에는 들어가지 않는다.
nonisolated struct AnthropicDirectClient: CityLLMClient, CitySearchClient, ChatClient {
    let apiKey: String
    let model: String

    /// 웹 검색 서버 도구 요청 본문. temperature·top_p·top_k는 보내지 않는다.
    static func searchBody(model: String, system: String, user: String, maxUses: Int) -> [String: Any] {
        [
            "model": model,
            "max_tokens": CityLLMConfiguration.maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "tools": [["type": "web_search_20250305", "name": "web_search", "max_uses": maxUses]]
        ]
    }

    func completeWithSearch(system: String, user: String, maxUses: Int) async throws -> CitySearchReply {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: Self.searchBody(model: model, system: system, user: user, maxUses: maxUses)
        )
        let (data, response) = try await CityLLMConfiguration.session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CityLLMError.http(http.statusCode)
        }
        return try JSONDecoder().decode(CitySearchReply.self, from: data)
    }

    func chat(system: String, turns: [ChatTurn], purpose: ChatPurpose, searchUses: Int?) async throws -> ChatReply {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        var body: [String: Any] = [
            "model": model, "max_tokens": CityLLMConfiguration.chatMaxTokens, "system": system,
            "messages": turns.map { ["role": $0.role.rawValue, "content": $0.content] },
            "cache_control": ["type": "ephemeral"]
        ]
        if let searchUses { body["tools"] = [["type": "web_search_20250305", "name": "web_search", "max_uses": searchUses]] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await CityLLMConfiguration.session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CityLLMError.http(http.statusCode)
        }
        // 직접 호출에는 사용량 계산이 없다.
        return ChatReply(reply: try JSONDecoder().decode(CitySearchReply.self, from: data), usage: nil)
    }

    func complete(system: String, user: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": CityLLMConfiguration.maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await CityLLMConfiguration.session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CityLLMError.http(http.statusCode)
        }
        return try messageText(from: data)
    }
}

/// Messages API 응답({content, stop_reason})에서 글을 꺼낸다. 직접 호출과 프록시가 같이 쓴다.
nonisolated func messageText(from data: Data) throws -> String {
    struct Body: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
        let stop_reason: String?
    }
    let reply = try JSONDecoder().decode(Body.self, from: data)
    if reply.stop_reason == "max_tokens" { throw CityLLMError.truncated }
    let text = reply.content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
    guard !text.isEmpty else { throw CityLLMError.emptyResponse }
    return text
}

nonisolated enum DevAPIKeyStore {
    private static let service = "app.tripdna.dev-llm-key"

    private static func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
    }

    static func read() -> String? {
        var q = query()
        q[kSecReturnData as String] = true
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String) {
        SecItemDelete(query() as CFDictionary)
        guard !key.isEmpty else { return }
        var q = query()
        q[kSecValueData as String] = Data(key.utf8)
        SecItemAdd(q as CFDictionary, nil)
    }
}
