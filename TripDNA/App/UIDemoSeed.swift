#if DEBUG
import Foundation

/// `-uiDemo <시나리오>` 런치 인자로 실행할 때만 동작하는 UI 확인용 시드.
/// 인메모리 저장소(AppDependencies)에만 쓰므로 기기의 실제 기록은 건드리지 않는다. 온보딩은 건너뛴다.
/// LLM은 부르지 않고, 추천 결과는 번들 카탈로그의 실제 도시 id로 만든 고정 기록을 쓴다.
enum UIDemoSeed {
    enum Scenario: String, CaseIterable {
        /// 온보딩 끝, 여행·원하는 여행 없음 → 홈 첫 사용 카드.
        case empty
        /// 다가오는 여행 1건 + 평가한 지난 여행 1건.
        case upcoming
        /// 오늘 진행 중인 여행.
        case active
        /// 끝났지만 평가하지 않은 여행 → 홈 평가 대기 카드.
        case pendingEval
        /// 컨셉이 다른 평가 완료 여행 6건 → 지문·랭킹.
        case many
        /// 추천 결과: 카드 3장(필수 충족 1, 추가 확인 필요 1), 예산, 이해한 내용.
        case recoResult
        /// 추천 결과 카드가 모두 예산에 걸려 보일 카드가 없음.
        case recoZero
        /// 사는 나라(JP)를 뺀 추천 결과.
        case recoHomeExcluded
        /// 원하는 여행 티어 + 피하고 싶은 것.
        case memory
        /// 저장한 도시와 제외한 도시.
        case saved
        /// 지난 해에 다녀온 평가 완료 여행 6건(랭킹은 기본 순서) → 홈 "지난 Wrapped"와 풀 스토리.
        case wrappedPast
        /// 지난 해에 다녀온 여행이 1건뿐 → 1건 전용 문구.
        case wrappedOne
    }

    /// `-uiDemo` 다음 인자. 없거나 모르는 이름이면 `.upcoming`.
    static var requested: Scenario? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-uiDemo") else { return nil }
        let name = args.indices.contains(index + 1) ? args[index + 1] : ""
        return Scenario(rawValue: name) ?? .upcoming
    }

    static func applyIfRequested(dependencies: AppDependencies, session: SessionStore) async {
        guard let scenario = requested else { return }
        try? await apply(scenario, dependencies: dependencies, session: session)
    }

    static func apply(
        _ scenario: Scenario, dependencies: AppDependencies, session: SessionStore, now: Date = Date()
    ) async throws {
        let store = dependencies.store
        _ = await dependencies.setHomeCountryCode(scenario == .recoHomeExcluded ? "JP" : "KR")
        await dependencies.markOnboardingCompleted()

        switch scenario {
        case .empty:
            break
        case .upcoming:
            try await store.create(trip("PT", String(localized: "Lisbon"), from: 26, to: 30, .food, now: now))
            try await store.create(evaluated("JP", String(localized: "Kyoto"), from: -22, to: -18, .cultureHistory, stars: 5, now: now))
        case .active:
            var active = try trip("PT", String(localized: "Lisbon"), from: -2, to: 3, .cityExploration, now: now)
            try active.start(at: day(-2, now))
            try await store.create(active)
        case .pendingEval:
            var ended = try trip("JP", String(localized: "Osaka"), from: -9, to: -5, .food, now: now)
            try ended.end(at: day(-5, now))
            try await store.create(ended)
        case .many:
            for (index, spec) in manyTrips.enumerated() {
                try await store.create(evaluated(
                    spec.country, spec.city, from: -400 + index * 55, to: -395 + index * 55,
                    spec.concept, secondary: spec.secondary, stars: spec.stars, now: now
                ))
            }
        case .recoResult:
            try await seedTrips(store, now: now)
            try await store.saveWantedTiers(tiers)
            try await store.updateCityState { $0.lastRecord = resultRecord(now: now) }
        case .recoZero:
            try await seedTrips(store, now: now)
            try await store.saveWantedTiers(tiers)
            try await store.updateCityState { $0.lastRecord = zeroRecord(now: now) }
        case .recoHomeExcluded:
            try await seedTrips(store, now: now)
            try await store.saveWantedTiers(tiers)
            try await store.updateCityState { $0.lastRecord = homeExcludedRecord(now: now) }
        case .memory:
            try await seedTrips(store, now: now)
            try await store.saveWantedTiers(tiers)
        case .wrappedPast:
            for (index, spec) in manyTrips.enumerated() {
                let from = lastYearOffset(30 + index * 55, now)
                try await store.create(evaluated(
                    spec.country, spec.city, from: from, to: from + 4,
                    spec.concept, secondary: spec.secondary, stars: spec.stars, now: now
                ))
            }
        case .wrappedOne:
            let from = lastYearOffset(200, now)
            try await store.create(evaluated("JP", String(localized: "Osaka"), from: from, to: from + 4, .food, stars: 5, now: now))
        case .saved:
            try await store.updateCityState {
                $0.save(card(of: "jp-kyoto"), conditionSummary: String(localized: "Culture & History · November"), now: day(-3, now))
                $0.save(card(of: "pt-lisbon"), conditionSummary: String(localized: "Food · March"), now: day(-1, now))
                $0.exclude(card(of: "es-barcelona"), now: day(-5, now))
            }
        }
        session.onboardingPhase = .completed
    }

    /// 지난 해 1월 1일에서 `n`일 뒤가 오늘로부터 며칠 전인지(음수). 올해가 바뀌어도 "지난 해"로 남도록 `now`에서 계산한다.
    private static func lastYearOffset(_ n: Int, _ now: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: calendar.component(.year, from: now) - 1, month: 1, day: 1, hour: 12)) ?? now
        return calendar.dateComponents([.day], from: now, to: calendar.date(byAdding: .day, value: n, to: start) ?? now).day ?? 0
    }

    // MARK: 여행

    private static func day(_ offset: Int, _ now: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: now) ?? now
    }

    private static func trip(
        _ country: String, _ city: String, from: Int, to: Int, _ primary: TripConcept,
        secondary: [TripConcept] = [], now: Date
    ) throws -> Trip {
        try Trip(
            legs: [TripLeg(countryCode: country, cities: [city], startDate: day(from, now), endDate: day(to, now))],
            companion: .alone, purpose: .leisure,
            concepts: TripConcepts(primary: primary, secondary: secondary), createdAt: day(min(from, 0) - 10, now)
        )
    }

    private static func evaluated(
        _ country: String, _ city: String, from: Int, to: Int, _ primary: TripConcept,
        secondary: [TripConcept] = [], stars: Int, now: Date
    ) throws -> Trip {
        var trip = try trip(country, city, from: from, to: to, primary, secondary: secondary, now: now)
        try trip.start(at: day(from, now))
        try trip.end(at: day(to, now))
        try trip.submit(
            TripEvaluation(
                satisfaction: stars, wouldRepeat: stars >= 4,
                cityReviews: [CityReview(
                    countryCode: country, city: city, rating: stars,
                    liked: String(localized: "Great for walking, and lots of places to eat"), disliked: stars <= 3 ? String(localized: "Too crowded") : nil
                )],
                source: .postTrip
            ),
            at: day(to, now)
        )
        return trip
    }

    private static let manyTrips: [(country: String, city: String, concept: TripConcept, secondary: [TripConcept], stars: Int)] = [
        ("JP", String(localized: "Osaka"), .food, [.shopping], 5),
        ("IT", String(localized: "Rome"), .cultureHistory, [.food], 4),
        ("NZ", String(localized: "Queenstown"), .natureScenery, [.activities], 5),
        ("TH", String(localized: "Phuket"), .relaxation, [], 3),
        ("GB", String(localized: "London"), .cityExploration, [.cultureHistory], 4),
        ("JP", String(localized: "Kyoto"), .food, [.cultureHistory], 5)
    ]

    private static func seedTrips(_ store: any AppStore, now: Date) async throws {
        try await store.create(evaluated("JP", String(localized: "Kyoto"), from: -200, to: -196, .cultureHistory, stars: 5, now: now))
        try await store.create(evaluated("TH", String(localized: "Phuket"), from: -120, to: -115, .relaxation, stars: 4, now: now))
    }

    private static let tiers: WantedConceptTiers = {
        var tiers = WantedConceptTiers()
        tiers.tier1 = [.food, .cultureHistory]
        tiers.tier2 = [.cityExploration]
        tiers.tier3 = [.relaxation]
        tiers.avoidNote = String(localized: "I'd like to avoid places that are too crowded")
        return tiers
    }()

    // MARK: 추천 기록

    private static func card(
        of cityID: String, reason: String = String(localized: "A city of long days spent wandering alleys and markets and eating your way through them."),
        caveat: String = String(localized: "It gets crowded in peak season."), cost: CostRange? = nil, conditions: [ConditionResult] = []
    ) -> CityRecommendationRecord.Card {
        let city = CityCatalog.load()?.cities.first { $0.id == cityID }
        return .init(
            cityID: cityID, cityName: city?.displayName ?? cityID, country: city?.country ?? "",
            isExploration: false, seasonCheckNeeded: false, reason: reason, caveat: caveat, cost: cost,
            conditions: conditions, conditionCheckNeeded: conditions.contains { $0.status == .unconfirmed }
        )
    }

    private static let japanOnly = CityCondition(
        id: "c1", text: String(localized: "Japan"), quote: String(localized: "Japan"), level: .required, kind: .country, target: "JP"
    )
    private static let shortFlight = CityCondition(
        id: "c2", text: String(localized: "Within a 5-hour flight"), quote: String(localized: "Within a 5-hour flight"), level: .required, kind: .other
    )

    /// 후보 풀은 서비스의 `replay`와 같은 입력으로 순위를 다시 계산해 만든다. 그래야 저장된 응답을 믿고
    /// 예산 컷·채우기가 풀 일치 검사를 통과한다. 응답은 풀 전체를 덮고, 비용은 정해 둔 값(없으면 풀 순서 기준)을 쓴다.
    private static let demoCosts: [String: CostRange] = [
        "jp-osaka": .init(low: 900_000, high: 1_300_000), "jp-fukuoka": .init(low: 800_000, high: 1_200_000),
        "jp-kyoto": .init(low: 1_000_000, high: 1_400_000), "jp-sapporo": .init(low: 1_800_000, high: 2_300_000),
        "it-rome": .init(low: 1_100_000, high: 1_450_000), "es-barcelona": .init(low: 1_000_000, high: 1_400_000)
    ]

    private static func demoCost(_ cityID: String, index: Int) -> CostRange {
        demoCosts[cityID] ?? .init(low: 900_000 + 100_000 * (index % 8), high: 1_500_000 + 100_000 * (index % 8))
    }

    private static func rankedCities(
        _ request: RecommendationRequest, conditions: [CityCondition], excludedCountries: [String]
    ) -> [RankedCity] {
        guard let catalog = CityCatalog.load(), let primary = request.primary else { return [] }
        return CityRanker.rank(catalog: catalog, input: CityRankingInput(
            primary: primary, secondary: request.secondary, tiers: tiers, month: request.month,
            excludedCountries: Set(excludedCountries), excludedCities: [], seed: 1, conditions: conditions
        ))
    }

    private static func record(
        _ request: RecommendationRequest, cards: [CityRecommendationRecord.Card], conditions: [CityCondition] = [],
        excludedCountries: [String] = [], homeCountry: String? = nil,
        understanding: String?, error: String? = nil, now: Date
    ) -> CityRecommendationRecord {
        let catalog = CityCatalog.load()
        let ranked = rankedCities(request, conditions: conditions, excludedCountries: excludedCountries)
        let pool = Array(ranked.prefix(CityLLMRequestBuilder.poolSize))
        let response = CityLLMResponse(
            understanding: understanding ?? String(localized: "Demo response"),
            cards: pool.enumerated().map { index, item in
                .init(
                    id: item.city.id, reason: String(localized: "This is a demo description."), caveat: String(localized: "This is a demo caveat."),
                    cost: demoCost(item.city.id, index: index)
                )
            }
        )
        let cut = CityRecommendationService.select(
            pool: pool, response: response, budget: request.budgetMax, seed: 1
        ).cutIDs
        return .init(
            id: UUID().uuidString, derivedFrom: nil, createdAt: now,
            version: .init(
                catalog: catalog?.version ?? "demo", prompt: CityInputVersion.promptVersion,
                model: "demo", ranking: CityInputVersion.rankingVersion
            ),
            seed: 1, input: request, tiers: tiers, excludedCountries: excludedCountries, excludedCityIDs: [],
            homeCountryAtRequest: homeCountry,
            rankedCityIDs: ranked.prefix(CityLLMRequestBuilder.tableLimit).map(\.city.id),
            poolCityIDs: pool.map(\.city.id), budgetCutCityIDs: cut,
            conditions: conditions, rejectedConditionIDs: [], extraction: nil, memories: [], memoriesUsed: [],
            system: "", user: "",
            rawResponse: (try? JSONEncoder().encode(response)).flatMap { String(data: $0, encoding: .utf8) },
            understanding: understanding, cards: cards,
            error: error, latencySeconds: 0
        )
    }

    private static func request(primary: TripConcept = .food, budget: Int? = 1_500_000) -> RecommendationRequest {
        var request = RecommendationRequest()
        request.setPrimary(primary)
        request.toggleSecondary(.cultureHistory)
        request.month = 11
        request.year = Calendar.current.component(.year, from: .now)
        request.nights = 3
        request.budgetMax = budget
        request.wants = String(localized: "Japan, within a 5-hour flight")
        return request
    }

    private static func resultRecord(now: Date) -> CityRecommendationRecord {
        let met = ConditionResult(condition: japanOnly, status: .met)
        let unconfirmed = ConditionResult(condition: shortFlight, status: .unconfirmed)
        return record(
            request(),
            cards: [
                card(of: "jp-osaka", cost: .init(low: 900_000, high: 1_300_000), conditions: [met]),
                card(of: "jp-fukuoka", cost: .init(low: 800_000, high: 1_200_000), conditions: [met, unconfirmed]),
                card(of: "jp-kyoto", cost: .init(low: 1_000_000, high: 1_400_000), conditions: [met])
            ],
            conditions: [japanOnly, shortFlight],
            understanding: String(localized: "You're looking for a Japan trip in November, 3 nights, centered on the joy of eating."), now: now
        )
    }

    private static func zeroRecord(now: Date) -> CityRecommendationRecord {
        record(
            request(budget: 500_000), cards: [], conditions: [japanOnly, shortFlight],
            understanding: nil, error: "noneWithinBudget", now: now
        )
    }

    private static func homeExcludedRecord(now: Date) -> CityRecommendationRecord {
        var request = request()
        request.wants = ""
        return record(
            request,
            // 사는 나라(일본)를 뺀 순위에서 카드를 고른다. 도시는 카탈로그가 정한다.
            cards: rankedCities(request, conditions: [], excludedCountries: ["JP"]).prefix(2).enumerated().map { index, item in
                card(of: item.city.id, cost: demoCost(item.city.id, index: index))
            },
            excludedCountries: ["JP"], homeCountry: "JP",
            understanding: String(localized: "You're looking for a trip in November, 3 nights, centered on the joy of eating."), now: now
        )
    }
}
#endif
