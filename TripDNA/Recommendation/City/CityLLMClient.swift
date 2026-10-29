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
}

nonisolated struct CityLLMConfiguration: Sendable {
    static let model = "claude-haiku-5-5"
    /// claude-haiku-5-5는 기본으로 생각을 켜고, 그 토큰도 이 한도에 들어간다. 3500에서는 후보 8곳 설명이 잘렸다.
    static let maxTokens = 16000
    /// 응답에 사용자 조건·평가 메모가 담기므로 디스크 캐시를 남기지 않는다(`.shared`는 응답을 앱 캐시 폴더에 저장했다).
    static let session = URLSession(configuration: .ephemeral)

    /// 프록시 주소가 있으면 프록시, 없으면 DEBUG 빌드의 Keychain 키, 둘 다 없으면 nil.
    static func makeClient(bundle: Bundle = .main) -> (any CityLLMClient)? {
        makeSearchClient(bundle: bundle)
    }

    /// 두 클라이언트 모두 웹 검색 호출도 지원한다. 질문 기능이 쓴다.
    static func makeSearchClient(bundle: Bundle = .main) -> (any CityLLMClient & CitySearchClient)? {
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
nonisolated struct CityLLMProxyClient: CityLLMClient, CitySearchClient {
    let url: URL
    let model: String

    func completeWithSearch(system: String, user: String, maxUses: Int) async throws -> CitySearchReply {
        var request = URLRequest(url: url, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "system": system, "user": user, "model": model,
            "maxTokens": String(CityLLMConfiguration.maxTokens), "webSearchMaxUses": maxUses
        ] as [String: Any])
        let (data, response) = try await CityLLMConfiguration.session.data(for: request)
        try Self.check(response)
        return try JSONDecoder().decode(CitySearchReply.self, from: data)
    }

    func complete(system: String, user: String) async throws -> String {
        // 직접 호출과 같은 120초. 생각 토큰을 포함한 16000토큰 응답은 60초를 넘을 수 있다.
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(
            ["system": system, "user": user, "model": model, "maxTokens": String(CityLLMConfiguration.maxTokens)]
        )
        let (data, response) = try await CityLLMConfiguration.session.data(for: request)
        try Self.check(response)
        return try messageText(from: data)
    }

    private static func check(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CityLLMError.http(http.statusCode)
        }
    }
}

/// 개발용. 키는 Keychain에서만 읽고 어디에도 기록하지 않는다. 출시 빌드에는 들어가지 않는다.
nonisolated struct AnthropicDirectClient: CityLLMClient, CitySearchClient {
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
