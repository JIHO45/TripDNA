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
        /// 추천 카드 사진 크롭 확인: 서울, 취리히, 도하, 나트랑.
        case recoPhotos
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
        /// AI 대화 기록: 예전 형식 답(문단·목록), 제목이 있는 긴 답, 넓은 표, 깨진 표.
        case chat
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
            try await store.create(trip("PT", "Lisbon", from: 26, to: 30, .food, now: now))
            try await store.create(evaluated("JP", "Kyoto", from: -22, to: -18, .cultureHistory, stars: 5, now: now))
        case .active:
            var active = try trip("PT", "Lisbon", from: -2, to: 3, .cityExploration, now: now)
            try active.start(at: day(-2, now))
            try await store.create(active)
        case .pendingEval:
            var ended = try trip("JP", "Osaka", from: -9, to: -5, .food, now: now)
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
        case .recoPhotos:
            try await store.updateCityState { $0.lastRecord = photoRecord(now: now) }
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
            try await store.create(evaluated("JP", "Osaka", from: from, to: from + 4, .food, stars: 5, now: now))
        case .chat:
            let generation = store.dataGeneration.current
            _ = try await store.updateChatState(ifGeneration: generation) { $0.upsert(chatConversation(now: now)) }
        case .saved:
            try await store.updateCityState {
                $0.save(card(of: "jp-kyoto"), conditionSummary: "Culture & History · November", now: day(-3, now))
                $0.save(card(of: "pt-lisbon"), conditionSummary: "Food · March", now: day(-1, now))
                $0.exclude(card(of: "es-barcelona"), now: day(-5, now))
            }
        }
        session.onboardingPhase = .completed
    }

    // l10n-ignore-begin
    private static func chatConversation(now: Date) -> ChatConversation {
        let pairs: [(String, String)] = [
            ("발리에서 푹 쉬고 싶어요", "푹 쉬는 게 목적이라면 **누사두아**가 잘 맞아요.\n- 리조트가 모여 있고 해변이 잔잔해요.\n- 우붓은 자연 속 리조트가 많지만 바다는 없어요."),
            ("리스본, 포르투, 세비야를 날씨·물가·음식으로 비교해 주세요", "세 곳 모두 3월에 걷기 좋지만 성격이 달라요.\n\n| 기준 | 리스본 | 포르투 | 세비야 |\n| --- | --- | --- | --- |\n| 3월 날씨 | 온화하고 가끔 비 | 비가 잦고 바람이 강한 편이라 우산과 겉옷을 챙기는 게 좋아요 | 가장 따뜻해요 |\n| 물가 | 확인하지 못했어요 | 확인하지 못했어요 | 확인하지 못했어요 |\n| 음식 | **해산물**, 에그타르트 | 프란세지냐 | 타파스 |\n\n물가는 시기와 환율에 따라 달라서 따로 확인해 보세요."),
            ("교토 4박 일정 전체를 정리해 주세요", "## 1~2일차: 동쪽\n기요미즈데라와 기온을 묶어 걸어서 다녀요. 오후에는 니넨자카 골목을 천천히 봐요.\n\n## 3~4일차: 서쪽\n- 아라시야마 대나무 숲은 이른 아침이 한산해요.\n- 금각사는 버스로 이동해요.\n\n| 일차 | 지역 |\n| 1 | 동쪽 |\n표 구분 줄이 없는 위 두 줄은 원문으로 보여야 해요."),
        ]
        var messages: [ChatMessage] = []
        for (question, answer) in pairs {
            messages.append(ChatMessage(role: .user, text: question, date: now))
            messages.append(ChatMessage(role: .assistant, text: answer, date: now))
        }
        let context = ChatContextSnapshot(text: "묻는 곳: 추천 탭(새 여행지를 고르는 중)", builtAt: now, includesRatings: false)
        return ChatConversation(id: UUID(), tab: .recommendation, title: "답 형식 확인", createdAt: now, updatedAt: now, context: context, messages: messages)
    }
    // l10n-ignore-end

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
                    liked: "Great for walking, and lots of places to eat", disliked: stars <= 3 ? "Too crowded" : nil
                )],
                source: .postTrip
            ),
            at: day(to, now)
        )
        return trip
    }

    private static let manyTrips: [(country: String, city: String, concept: TripConcept, secondary: [TripConcept], stars: Int)] = [
        ("JP", "Osaka", .food, [.shopping], 5),
        ("IT", "Rome", .cultureHistory, [.food], 4),
        ("NZ", "Queenstown", .natureScenery, [.activities], 5),
        ("TH", "Phuket", .relaxation, [], 3),
        ("GB", "London", .cityExploration, [.cultureHistory], 4),
        ("JP", "Kyoto", .food, [.cultureHistory], 5)
    ]

    private static func seedTrips(_ store: any AppStore, now: Date) async throws {
        try await store.create(evaluated("JP", "Kyoto", from: -200, to: -196, .cultureHistory, stars: 5, now: now))
        try await store.create(evaluated("TH", "Phuket", from: -120, to: -115, .relaxation, stars: 4, now: now))
    }

    private static let tiers: WantedConceptTiers = {
        var tiers = WantedConceptTiers()
        tiers.tier1 = [.food, .cultureHistory]
        tiers.tier2 = [.cityExploration]
        tiers.tier3 = [.relaxation]
        tiers.avoidNote = "I'd like to avoid places that are too crowded"
        return tiers
    }()

    // MARK: 추천 기록

    private static func card(
        of cityID: String, reason: String = "A city of long days spent wandering alleys and markets and eating your way through them.",
        caveat: String = "It gets crowded in peak season.", cost: CostRange? = nil, conditions: [ConditionResult] = []
    ) -> CityRecommendationRecord.Card {
        let city = CityCatalog.load()?.cities.first { $0.id == cityID }
        return .init(
            cityID: cityID, cityName: city?.displayName ?? cityID, country: city?.country ?? "",
            isExploration: false, seasonCheckNeeded: false, reason: reason, caveat: caveat, cost: cost,
            conditions: conditions, conditionCheckNeeded: conditions.contains { $0.status == .unconfirmed }
        )
    }

    private static let japanOnly = CityCondition(
        id: "c1", text: "Japan", quote: "Japan", level: .required, kind: .country, target: "JP"
    )
    private static let shortFlight = CityCondition(
        id: "c2", text: "Within a 5-hour flight", quote: "Within a 5-hour flight", level: .required, kind: .other
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
            understanding: understanding ?? "Demo response",
            cards: pool.enumerated().map { index, item in
                .init(
                    id: item.city.id, reason: "This is a demo description.", caveat: "This is a demo caveat.",
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
        request.wants = "Japan, within a 5-hour flight"
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
            understanding: "You're looking for a Japan trip in November, 3 nights, centered on the joy of eating.", now: now
        )
    }

    private static func photoRecord(now: Date) -> CityRecommendationRecord {
        var request = request(budget: nil)
        request.wants = ""
        return record(
            request,
            cards: ["kr-seoul", "ch-zurich", "us-washington", "es-valencia", "pl-krakow", "sa-riyadh", "id-denpasar", "sa-mecca", "gb-london", "in-delhi", "ar-buenos-aires", "it-verona", "us-los-angeles", "qa-doha", "vn-nha-trang"].map {
                card(of: $0, reason: "This is a demo description.", caveat: "This is a demo caveat.")
            },
            understanding: nil, now: now
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
            understanding: "You're looking for a trip in November, 3 nights, centered on the joy of eating.", now: now
        )
    }
}
#endif
