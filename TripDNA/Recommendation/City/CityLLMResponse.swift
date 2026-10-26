import Foundation

nonisolated struct CostRange: Codable, Equatable, Sendable {
    let low: Int
    let high: Int
}

nonisolated struct CityLLMResponse: Codable, Equatable, Sendable {
    struct Card: Codable, Equatable, Sendable {
        let id: String
        let reason: String
        let caveat: String
        /// 예산이 있을 때만 필수. 원화 총비용 추정 범위.
        let cost: CostRange?

        init(id: String, reason: String, caveat: String, cost: CostRange?) {
            self.id = id; self.reason = reason; self.caveat = caveat; self.cost = cost
        }

        /// 유의점이 없으면 모델이 키를 빼기도 한다. 빈 값으로 읽는다.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            reason = try c.decode(String.self, forKey: .reason)
            caveat = try c.decodeIfPresent(String.self, forKey: .caveat) ?? ""
            cost = try c.decodeIfPresent(CostRange.self, forKey: .cost)
        }
    }

    struct MemoryUse: Codable, Equatable, Sendable {
        let id: String
        let how: String
    }

    let understanding: String
    let cards: [Card]
    var memoriesUsed: [MemoryUse] = []

    enum CodingKeys: String, CodingKey {
        case understanding, cards
        case memoriesUsed = "memories_used"
    }

    init(understanding: String, cards: [Card], memoriesUsed: [MemoryUse] = []) {
        self.understanding = understanding; self.cards = cards; self.memoriesUsed = memoriesUsed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        understanding = try c.decode(String.self, forKey: .understanding)
        cards = try c.decode([Card].self, forKey: .cards)
        memoriesUsed = (try? c.decodeIfPresent([MemoryUse].self, forKey: .memoriesUsed)) ?? []
    }
}

nonisolated enum CityResponseError: Error, Equatable {
    case notJSON
    case wrongCards
    case emptyReason(String)
    case invalidCost(String)
    case unknownMemory(String)
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

    static func validate(
        _ response: CityLLMResponse, cardIDs: [String], requiresCost: Bool, memoryIDs: Set<String> = []
    ) throws {
        if let unknown = response.memoriesUsed.first(where: { !memoryIDs.contains($0.id) }) {
            throw CityResponseError.unknownMemory(unknown.id)
        }
        guard response.cards.map(\.id) == cardIDs else { throw CityResponseError.wrongCards }
        for card in response.cards {
            guard !card.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CityResponseError.emptyReason(card.id)
            }
            if requiresCost {
                guard let cost = card.cost, cost.low > 0, cost.low <= cost.high else {
                    throw CityResponseError.invalidCost(card.id)
                }
            }
            if let term = forbiddenTerms.first(where: { card.reason.contains($0) || card.caveat.contains($0) }) {
                throw CityResponseError.internalTermLeaked(term)
            }
        }
    }
}

nonisolated struct CityConditionResponse: Codable, Equatable, Sendable {
    let conditions: [CityCondition]
}

nonisolated extension CityResponseValidator {
    static func parseConditions(_ text: String) throws -> [CityCondition] {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let data = String(text[start...end]).data(using: .utf8),
              let response = try? JSONDecoder().decode(CityConditionResponse.self, from: data) else {
            throw CityResponseError.notJSON
        }
        return response.conditions
    }
}
