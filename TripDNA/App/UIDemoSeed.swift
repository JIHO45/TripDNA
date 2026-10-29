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
            try await store.create(trip("PT", "리스본", from: 26, to: 30, .food, now: now))
            try await store.create(evaluated("JP", "교토", from: -22, to: -18, .cultureHistory, stars: 5, now: now))
        case .active:
            var active = try trip("PT", "리스본", from: -2, to: 3, .cityExploration, now: now)
            try active.start(at: day(-2, now))
            try await store.create(active)
        case .pendingEval:
            var ended = try trip("JP", "오사카", from: -9, to: -5, .food, now: now)
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
        case .saved:
            try await store.updateCityState {
                $0.save(card(of: "jp-kyoto"), conditionSummary: "문화·역사 · 11월", now: day(-3, now))
                $0.save(card(of: "pt-lisbon"), conditionSummary: "미식 · 3월", now: day(-1, now))
                $0.exclude(card(of: "es-barcelona"), now: day(-5, now))
            }
        }
        session.onboardingPhase = .completed
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
                    liked: "걷기 좋았고 먹을 곳이 많았어요", disliked: stars <= 3 ? "사람이 너무 많았어요" : nil
                )],
                source: .postTrip
            ),
            at: day(to, now)
        )
        return trip
    }

    private static let manyTrips: [(country: String, city: String, concept: TripConcept, secondary: [TripConcept], stars: Int)] = [
        ("JP", "오사카", .food, [.shopping], 5),
        ("IT", "로마", .cultureHistory, [.food], 4),
        ("NZ", "퀸스타운", .natureScenery, [.activities], 5),
        ("TH", "푸껫", .relaxation, [], 3),
        ("GB", "런던", .cityExploration, [.cultureHistory], 4),
        ("JP", "교토", .food, [.cultureHistory], 5)
    ]

    private static func seedTrips(_ store: any AppStore, now: Date) async throws {
        try await store.create(evaluated("JP", "교토", from: -200, to: -196, .cultureHistory, stars: 5, now: now))
        try await store.create(evaluated("TH", "푸껫", from: -120, to: -115, .relaxation, stars: 4, now: now))
    }

    private static let tiers: WantedConceptTiers = {
        var tiers = WantedConceptTiers()
        tiers.tier1 = [.food, .cultureHistory]
        tiers.tier2 = [.cityExploration]
        tiers.tier3 = [.relaxation]
        tiers.avoidNote = "사람이 너무 붐비는 곳은 피하고 싶어요"
        return tiers
    }()

    // MARK: 추천 기록

    private static func card(
        of cityID: String, reason: String = "골목과 시장을 걸으며 먹는 하루가 이어지는 도시예요.",
        caveat: String = "성수기에는 붐벼요.", cost: CostRange? = nil, conditions: [ConditionResult] = []
    ) -> CityRecommendationRecord.Card {
        let city = CityCatalog.load()?.cities.first { $0.id == cityID }
        return .init(
            cityID: cityID, cityName: city?.ko ?? cityID, country: city?.country ?? "",
            isExploration: false, seasonCheckNeeded: false, reason: reason, caveat: caveat, cost: cost,
            conditions: conditions, conditionCheckNeeded: conditions.contains { $0.status == .unconfirmed }
        )
    }

    private static let japanOnly = CityCondition(
        id: "c1", text: "일본", quote: "일본", level: .required, kind: .country, target: "JP"
    )
    private static let shortFlight = CityCondition(
        id: "c2", text: "비행 5시간 이내", quote: "비행 5시간 이내", level: .required, kind: .other
    )

    private static func record(
        _ request: RecommendationRequest, cards: [CityRecommendationRecord.Card], conditions: [CityCondition] = [],
        poolCityIDs: [String], budgetCut: [String] = [], excludedCountries: [String] = [],
        understanding: String?, error: String? = nil, now: Date
    ) -> CityRecommendationRecord {
        .init(
            id: UUID().uuidString, derivedFrom: nil, createdAt: now,
            version: .init(
                catalog: CityCatalog.load()?.version ?? "demo", prompt: CityInputVersion.promptVersion,
                model: "demo", ranking: CityInputVersion.rankingVersion
            ),
            seed: 1, input: request, tiers: tiers, excludedCountries: excludedCountries, excludedCityIDs: [],
            rankedCityIDs: poolCityIDs, poolCityIDs: poolCityIDs, budgetCutCityIDs: budgetCut,
            conditions: conditions, rejectedConditionIDs: [], extraction: nil, memories: [], memoriesUsed: [],
            system: "", user: "", rawResponse: nil, understanding: understanding, cards: cards,
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
        request.budgetMaxKRW = budget
        request.wants = "일본, 비행 5시간 이내"
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
            conditions: [japanOnly, shortFlight], poolCityIDs: ["jp-osaka", "jp-fukuoka", "jp-kyoto", "jp-sapporo"],
            budgetCut: ["jp-sapporo"],
            understanding: "11월에 3박으로, 먹는 즐거움이 중심인 일본 여행을 찾고 있어요.", now: now
        )
    }

    private static func zeroRecord(now: Date) -> CityRecommendationRecord {
        record(
            request(budget: 500_000), cards: [], poolCityIDs: ["jp-osaka", "jp-fukuoka", "jp-kyoto"],
            budgetCut: ["jp-osaka", "jp-fukuoka", "jp-kyoto"],
            understanding: nil, error: "noneWithinBudget", now: now
        )
    }

    private static func homeExcludedRecord(now: Date) -> CityRecommendationRecord {
        var request = request()
        request.wants = ""
        return record(
            request,
            cards: [
                card(of: "it-rome", cost: .init(low: 1_100_000, high: 1_450_000)),
                card(of: "es-barcelona", cost: .init(low: 1_000_000, high: 1_400_000))
            ],
            poolCityIDs: ["it-rome", "es-barcelona", "jp-osaka"], excludedCountries: ["JP"],
            understanding: "11월에 3박으로, 먹는 즐거움이 중심인 여행을 찾고 있어요.", now: now
        )
    }
}
#endif
