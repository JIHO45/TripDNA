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
}

nonisolated struct CityLLMConfiguration: Sendable {
    static let model = "claude-haiku-5-5"
    static let maxTokens = 3500

    /// 프록시 주소가 있으면 프록시, 없으면 DEBUG 빌드의 Keychain 키, 둘 다 없으면 nil.
    static func makeClient(bundle: Bundle = .main) -> (any CityLLMClient)? {
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

/// 프록시 계약: POST {system, user, model, maxTokens} → 200 {"text": "..."}.
nonisolated struct CityLLMProxyClient: CityLLMClient {
    let url: URL
    let model: String

    func complete(system: String, user: String) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(
            ["system": system, "user": user, "model": model, "maxTokens": String(CityLLMConfiguration.maxTokens)]
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response)
        struct Body: Decodable { let text: String }
        return try JSONDecoder().decode(Body.self, from: data).text
    }

    private static func check(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CityLLMError.http(http.statusCode)
        }
    }
}

/// 개발용. 키는 Keychain에서만 읽고 어디에도 기록하지 않는다. 출시 빌드에는 들어가지 않는다.
nonisolated struct AnthropicDirectClient: CityLLMClient {
    let apiKey: String
    let model: String

    func complete(system: String, user: String) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!, timeoutInterval: 60)
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
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CityLLMError.http(http.statusCode)
        }
        struct Body: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]
        }
        let text = try JSONDecoder().decode(Body.self, from: data).content
            .compactMap { $0.type == "text" ? $0.text : nil }.joined()
        guard !text.isEmpty else { throw CityLLMError.emptyResponse }
        return text
    }
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
