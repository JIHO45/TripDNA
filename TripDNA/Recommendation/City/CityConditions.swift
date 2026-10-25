import Foundation

/// 자유문장에서 LLM이 뽑은 조건. 판정은 번들 자료로 코드가 한다(docs/recommendation/README.md 2026-10-17 결정).
nonisolated struct CityCondition: Codable, Equatable, Sendable {
    enum Level: String, Codable, Sendable { case required, core, supporting }
    /// `subconcept`: 세부 컨셉 등급으로 판정. `country`: 나라로 판정. `other`: 자료가 답하지 못하는 조건(비행시간·분위기 등).
    enum Kind: String, Codable, Sendable { case subconcept, country, other }
    enum Polarity: String, Codable, Sendable { case want, avoid }

    let id: String
    let text: String
    /// 근거가 된 사용자 원문. 원문에 없으면 코드가 조건을 버린다.
    let quote: String
    let level: Level
    let kind: Kind
    let target: String?
    var polarity: Polarity = .want
    var minGrade: CityGrade = .makeTime

    enum CodingKeys: String, CodingKey {
        case id, text, quote, level, kind, target, polarity
        case minGrade = "min_grade"
    }

    init(
        id: String, text: String, quote: String, level: Level, kind: Kind, target: String? = nil,
        polarity: Polarity = .want, minGrade: CityGrade = .makeTime
    ) {
        self.id = id; self.text = text; self.quote = quote; self.level = level
        self.kind = kind; self.target = target; self.polarity = polarity; self.minGrade = minGrade
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        quote = try c.decode(String.self, forKey: .quote)
        level = try c.decode(Level.self, forKey: .level)
        kind = try c.decode(Kind.self, forKey: .kind)
        target = try c.decodeIfPresent(String.self, forKey: .target)
        polarity = (try? c.decodeIfPresent(Polarity.self, forKey: .polarity)) ?? .want
        minGrade = (try? c.decodeIfPresent(CityGrade.self, forKey: .minGrade)) ?? .makeTime
    }
}

nonisolated enum ConditionStatus: String, Codable, Sendable {
    case met, notMet, unconfirmed
}

nonisolated struct ConditionResult: Codable, Equatable, Sendable {
    let condition: CityCondition
    let status: ConditionStatus
}

nonisolated enum CityConditionJudge {
    /// 근거 원문이 실제로 있고 판정에 쓸 수 있는 형태인 조건만 남긴다. 버린 조건의 id를 함께 돌려준다.
    static func accept(
        _ conditions: [CityCondition], userText: String, catalog: CityCatalog
    ) -> (accepted: [CityCondition], rejected: [String]) {
        let subconcepts = Set(catalog.concepts.values.flatMap { $0 })
        var accepted: [CityCondition] = []
        var rejected: [String] = []
        var seen = Set<String>()
        for condition in conditions {
            let quote = condition.quote.trimmingCharacters(in: .whitespacesAndNewlines)
            var valid = !quote.isEmpty && userText.contains(quote) && seen.insert(condition.id).inserted
            switch condition.kind {
            case .subconcept: valid = valid && condition.target.map(subconcepts.contains) == true
            case .country: valid = valid && (condition.target?.count == 2)
            case .other: break
            }
            if valid { accepted.append(condition) } else { rejected.append(condition.id) }
        }
        return (accepted, rejected)
    }

    static func status(
        of condition: CityCondition, city: City, catalog: CityCatalog, month: Int?
    ) -> ConditionStatus {
        switch condition.kind {
        case .other:
            return .unconfirmed
        case .country:
            guard let target = condition.target?.uppercased() else { return .unconfirmed }
            let same = city.country == target
            return (same == (condition.polarity == .want)) ? .met : .notMet
        case .subconcept:
            // 세부를 피하고 싶다는 조건은 자료로 판정할 기준이 없어 확인 필요로 둔다.
            guard condition.polarity == .want, let sub = condition.target else { return .unconfirmed }
            let grade = city.grades[sub] ?? .none
            guard grade >= condition.minGrade else { return .notMet }
            guard let month else { return .met }
            if city.seasonUnverified.contains(sub) { return .unconfirmed }
            if let months = city.season[sub], !months.isEmpty, !months.contains(month) { return .notMet }
            return .met
        }
    }
}
