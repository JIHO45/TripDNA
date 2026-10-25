import Foundation

/// 이번 추천에서 코드가 순위를 계산하는 데 쓰는 입력.
nonisolated struct CityRankingInput: Equatable, Sendable {
    var primary: TripConcept
    var secondary: [TripConcept] = []
    /// 사용자가 놓은 티어(1~3). 놓지 않은 컨셉은 점수에 넣지 않는다.
    var tiers = WantedConceptTiers()
    /// 여행 월. nil이면 시즌을 적용하지 않는다.
    var month: Int?
    /// 후보에서 뺄 나라(사는 나라 기본 제외, 다녀온 곳 제외, 계속 제외 등). 호출자가 이번 요청의 예외까지 반영해 넘긴다.
    var excludedCountries: Set<String> = []
    /// "다시 추천하지 않기"로 뺀 도시 id.
    var excludedCities: Set<String> = []
    /// 탐색 후보를 고르는 시드. 같은 입력과 시드는 같은 결과를 낸다.
    var seed: UInt64 = 0
    /// 자유문장에서 뽑아 코드가 받아들인 조건. 필수 불충족은 후보에서 빼고, 확인 못 한 필수는 뒤쪽 묶음, 핵심 선호는 묶음 순서에 쓴다.
    var conditions: [CityCondition] = []
}

nonisolated struct RankedCity: Equatable, Sendable {
    enum Status: String, Codable, Sendable {
        /// 주 컨셉 등급이 시즌 확인된 세부로 뒷받침된다(시기를 넣지 않은 경우 포함).
        case confirmed
        /// 주 컨셉 등급이 운영 월을 확인하지 못한 세부에 기대고 있다. 기본 추천 위로 오르지 않는다.
        case needsSeasonCheck
    }

    let city: City
    let status: Status
    /// 시즌 적용 후 주 컨셉 등급. `needsSeasonCheck`면 미확인 세부를 포함한 값이다.
    let primaryGrade: CityGrade
    let secondaryGrades: [CityGrade]
    /// 주 컨셉 등급에 쓰인 세부 중 시즌을 확인하지 못한 것.
    let unverifiedSubconcepts: [String]
    let tierScore: Int
    let conditionResults: [ConditionResult]

    var needsConditionCheck: Bool {
        conditionResults.contains { $0.condition.level == .required && $0.status == .unconfirmed }
    }
    /// 기본 추천과 섞지 않는 "추가 확인 필요" 묶음에 속하는지(시즌 또는 필수 조건을 확인하지 못함).
    var needsCheck: Bool { status == .needsSeasonCheck || needsConditionCheck }
    func met(_ level: CityCondition.Level) -> Int {
        conditionResults.filter { $0.condition.level == level && $0.status == .met }.count
    }
}

nonisolated struct CityPick: Equatable, Sendable {
    let ranked: RankedCity
    /// 첫 묶음 안에서 시드로 고른 탐색 후보.
    let isExploration: Bool
}

/// 2026-10-17 결정의 순위 규칙(핵심 선호·자유문장 조건은 LLM 추출이 필요해 아직 쓰지 않는다).
/// 1) 주 컨셉이 "일부러 시간을 낼 만함" 이상인 도시만 남긴다. 시즌 미확인 세부에만 기댄 도시는 뒤쪽 묶음.
/// 2) 묶음(확인 여부, 주 컨셉 등급) 안에서 부 컨셉 등급 합, 티어 점수 순.
/// 3) 앞 2장은 순서대로, 나머지 1장은 첫 묶음 안에서 시드로 고른 탐색 후보.
nonisolated enum CityRanker {
    static let threshold = CityGrade.makeTime
    static let tierWeights = [1: 3, 2: 2, 3: 1]

    static func rank(catalog: CityCatalog, input: CityRankingInput) -> [RankedCity] {
        catalog.cities
            .filter { !input.excludedCountries.contains($0.country) && !input.excludedCities.contains($0.id) }
            .compactMap { rankedCity($0, catalog: catalog, input: input) }
            .sorted { lhs, rhs in
                if lhs.needsCheck != rhs.needsCheck { return !lhs.needsCheck }
                if lhs.met(.core) != rhs.met(.core) { return lhs.met(.core) > rhs.met(.core) }
                if lhs.primaryGrade != rhs.primaryGrade { return lhs.primaryGrade > rhs.primaryGrade }
                let ls = lhs.secondaryGrades.reduce(0) { $0 + $1.rankValue }
                let rs = rhs.secondaryGrades.reduce(0) { $0 + $1.rankValue }
                if ls != rs { return ls > rs }
                if lhs.met(.supporting) != rhs.met(.supporting) { return lhs.met(.supporting) > rhs.met(.supporting) }
                if lhs.tierScore != rhs.tierScore { return lhs.tierScore > rhs.tierScore }
                return tiebreak(lhs.city.id, input.seed) < tiebreak(rhs.city.id, input.seed)
            }
    }

    /// 카드 3장(앞 2장 + 탐색 1장). 탐색 후보가 없으면 기준을 낮추지 않고 순서대로 채운다.
    static func pickCards(from ranked: [RankedCity], seed: UInt64) -> [CityPick] {
        var picks = ranked.prefix(2).map { CityPick(ranked: $0, isExploration: false) }
        let rest = Array(ranked.dropFirst(2))
        guard let first = ranked.first else { return [] }
        let explore = rest
            .filter {
                $0.needsCheck == first.needsCheck && $0.met(.core) == first.met(.core) && $0.primaryGrade == first.primaryGrade
            }
            .min { tiebreak($0.city.id, seed &+ 1) < tiebreak($1.city.id, seed &+ 1) }
        if let explore {
            picks.append(CityPick(ranked: explore, isExploration: true))
        } else if let next = rest.first {
            picks.append(CityPick(ranked: next, isExploration: false))
        }
        return picks
    }

    private static func rankedCity(_ city: City, catalog: CityCatalog, input: CityRankingInput) -> RankedCity? {
        let primary = grade(city, input.primary, catalog: catalog, month: input.month)
        guard primary.possible >= threshold else { return nil }
        let confirmed = primary.confirmed >= threshold
        let secondaryGrades = input.secondary.map {
            grade(city, $0, catalog: catalog, month: input.month).confirmed
        }
        let tierScore = TripConcept.allCases
            .filter { $0 != input.primary }
            .reduce(0) { sum, concept in
                guard let tier = input.tiers.tier(of: concept), let weight = tierWeights[tier] else { return sum }
                return sum + weight * grade(city, concept, catalog: catalog, month: input.month).confirmed.rankValue
            }
        let results = input.conditions.map {
            ConditionResult(condition: $0, status: CityConditionJudge.status(of: $0, city: city, catalog: catalog, month: input.month))
        }
        // 필수 조건의 불충족이 확인된 도시는 후보에서 뺀다. 확인하지 못한 것은 빼지 않는다.
        if results.contains(where: { $0.condition.level == .required && $0.status == .notMet }) { return nil }
        return RankedCity(
            city: city,
            status: confirmed ? .confirmed : .needsSeasonCheck,
            primaryGrade: confirmed ? primary.confirmed : primary.possible,
            secondaryGrades: secondaryGrades,
            unverifiedSubconcepts: confirmed ? [] : primary.unverified,
            tierScore: tierScore,
            conditionResults: results
        )
    }

    /// 큰 컨셉의 등급 = 세부 등급의 최댓값. 시기가 주어지면 시즌 밖 세부는 뺀다.
    /// `confirmed`는 미확인 세부를 뺀 값, `possible`은 미확인 세부를 포함한 값이다.
    static func grade(
        _ city: City, _ concept: TripConcept, catalog: CityCatalog, month: Int?
    ) -> (confirmed: CityGrade, possible: CityGrade, unverified: [String]) {
        var confirmed = CityGrade.none
        var possible = CityGrade.none
        var unverified: [(sub: String, grade: CityGrade)] = []
        for sub in catalog.subconcepts(of: concept) {
            let grade = city.grades[sub] ?? .none
            guard let month else {
                confirmed = max(confirmed, grade)
                possible = max(possible, grade)
                continue
            }
            if city.seasonUnverified.contains(sub) {
                unverified.append((sub, grade))
                possible = max(possible, grade)
            } else if let months = city.season[sub], !months.isEmpty, !months.contains(month) {
                continue
            } else {
                confirmed = max(confirmed, grade)
                possible = max(possible, grade)
            }
        }
        return (confirmed, possible, unverified.filter { $0.grade > confirmed }.map(\.sub))
    }

    /// 시드로 도시 id를 섞는 결정적 값. 기기·실행과 무관하게 같아야 하므로 FNV-1a를 쓴다.
    static func tiebreak(_ id: String, _ seed: UInt64) -> UInt64 {
        var hash: UInt64 = 14695981039346656037 ^ seed
        for byte in id.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1099511628211
        }
        return hash
    }
}
