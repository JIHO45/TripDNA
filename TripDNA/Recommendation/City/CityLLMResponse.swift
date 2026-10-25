import Foundation

nonisolated struct CityLLMResponse: Codable, Equatable, Sendable {
    struct Card: Codable, Equatable, Sendable {
        let id: String
        let reason: String
        let caveat: String
    }

    let understanding: String
    let cards: [Card]
}

nonisolated enum CityResponseError: Error, Equatable {
    case notJSON
    case wrongCards
    case emptyReason(String)
    case internalTermLeaked(String)
}

/// 응답 검사. 코드가 정한 카드 도시와 순서를 그대로 따랐는지, 등급 이름 같은 내부 용어가 문장에 샜는지 본다.
/// 사실의 정확성은 검사하지 못한다(테스터가 읽고 기록한다).
nonisolated enum CityResponseValidator {
    static let forbiddenTerms: [String] =
        [CityGrade.ifThere, .makeTime, .choose].map(\.nameKo) + ["탐색 후보", "make_time", "if_there"]

    static func parse(_ text: String) throws -> CityLLMResponse {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let data = String(text[start...end]).data(using: .utf8),
              let response = try? JSONDecoder().decode(CityLLMResponse.self, from: data) else {
            throw CityResponseError.notJSON
        }
        return response
    }

    static func validate(_ response: CityLLMResponse, cardIDs: [String]) throws {
        guard response.cards.map(\.id) == cardIDs else { throw CityResponseError.wrongCards }
        for card in response.cards {
            guard !card.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CityResponseError.emptyReason(card.id)
            }
            if let term = forbiddenTerms.first(where: { card.reason.contains($0) || card.caveat.contains($0) }) {
                throw CityResponseError.internalTermLeaked(term)
            }
        }
    }
}
