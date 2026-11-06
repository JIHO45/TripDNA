#if DEBUG
import Foundation

// 데모 문장은 앱 언어에 맞춰 직접 고르는 DEBUG 전용 데이터라 번역 목록을 거치지 않는다.
// l10n-ignore-begin

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
        /// 조건에 맞는 도시가 없어 보일 카드가 없음. 예산을 넘는 추정 도시는 빼지 않으므로 예산 없이 만든다.
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
        /// App Store 스크린샷: 지난 해 평가 완료 여행 6건(지문·Wrapped), 확인 필요 없이 요약이 접힌 추천 결과, AI 대화 1개.
        case appStore
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
        case .appStore:
            for (index, spec) in storeTrips.enumerated() {
                let from = lastYearOffset(30 + index * 55, now)
                var trip = try evaluated(
                    spec.country, spec.city, from: from, to: from + 4,
                    spec.concept, secondary: spec.secondary, stars: spec.stars, liked: spec.liked,
                    disliked: spec.city == text("Taipei", "타이베이") ? text("Lines at the popular spots were long", "유명한 가게는 줄이 길었어요") : nil, now: now
                )
                // 대표 사진은 앱에 들어 있는 도시 사진(Unsplash, data/destinations/city-photo-sources.csv)을 쓴다.
                let cover = Bundle.main.url(forResource: spec.photo, withExtension: "jpg")
                let coverPath = cover.flatMap { try? Data(contentsOf: $0) }.flatMap { try? LocalPhotoStore.saveImageData($0) }
                trip.setCoverPhoto(storagePath: coverPath)
                try await store.create(trip)
                // 하루 한 장: 타이베이는 -uiDemoPhotoDir의 taipei-1~5.jpg(design/app-store/screenshots/photos), 나머지는 대표 사진을 첫날에.
                let dayPaths = spec.photo == "tw-taipei" ? demoPhotoPaths(prefix: "taipei", count: 5) : [coverPath].compactMap { $0 }
                for (offset, path) in dayPaths.enumerated() {
                    try await store.upsert(DailyPhoto(
                        id: UUID().uuidString, tripID: trip.id, tripDayIndex: offset + 1, storagePath: path,
                        selection: .manual, dayReaction: nil, createdAt: day(from + offset, now)
                    ))
                }
            }
            try await store.saveWantedTiers(tiers)
            try await store.updateCityState { $0.lastRecord = storeRecord(now: now); $0.understandingSeen = true }
            let generation = store.dataGeneration.current
            _ = try await store.updateChatState(ifGeneration: generation) { $0.upsert(storeConversation(now: now)) }
        case .saved:
            try await store.updateCityState {
                $0.save(card(of: "jp-kyoto"), conditionSummary: "Culture & History · November", now: day(-3, now))
                $0.save(card(of: "pt-lisbon"), conditionSummary: "Food · March", now: day(-1, now))
                $0.exclude(card(of: "es-barcelona"), now: day(-5, now))
            }
        }
        session.onboardingPhase = .completed
    }

    private static func storeConversation(now: Date) -> ChatConversation {
        let question = text("Osaka for 3 nights, mostly to eat. Where should I stay?", "오사카 3박, 먹는 여행이면 어디에 묵으면 좋을까요?")
        let answer = text(
            "For a food trip, staying near **Namba and Dotonbori** is easiest.\n- You can walk to markets and small restaurants in the side streets.\n- Kuromon Market is close by.\n- If you want a quieter hotel, one stop away works well too.",
            "먹는 여행이라면 **난바·도톤보리** 근처가 편해요.\n- 시장과 골목 식당을 걸어서 다닐 수 있어요.\n- 구로몬 시장도 가까워요.\n- 조용한 숙소를 원하면 한 정거장 떨어진 곳도 괜찮아요."
        )
        let question2 = text("Is it easy to do a day trip to Kyoto from there?", "거기서 교토 당일치기도 쉬워요?")
        let answer2 = text(
            "Yes. From Namba, the train to Kyoto takes about an hour.\n- Leave early to see the temples before the crowds.\n- Come back in the evening and eat in Dotonbori.",
            "네, 난바에서 교토까지 전철로 1시간 정도예요.\n- 아침 일찍 나서면 붐비기 전에 사찰을 볼 수 있어요.\n- 저녁에 돌아와 도톤보리에서 식사하면 돼요."
        )
        let messages = [question, answer, question2, answer2].enumerated().map { ChatMessage(role: $0.offset.isMultiple(of: 2) ? .user : .assistant, text: $0.element, date: now) }
        // 평가를 담지 않은 대화여야 평가 전송 동의 없이도 이어서 쓸 수 있는 화면으로 나온다.
        let context = ChatContextSnapshot(text: text("Asked from: Recommendations", "묻는 곳: 추천 탭"), builtAt: now, includesRatings: false)
        return ChatConversation(id: UUID(), tab: .recommendation, title: text("Where to stay in Osaka", "오사카 숙소 위치"), createdAt: now, updatedAt: now, context: context, messages: messages)
    }

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
        secondary: [TripConcept] = [], stars: Int, liked: String? = nil, disliked: String? = nil, now: Date
    ) throws -> Trip {
        var trip = try trip(country, city, from: from, to: to, primary, secondary: secondary, now: now)
        try trip.start(at: day(from, now))
        try trip.end(at: day(to, now))
        try trip.submit(
            TripEvaluation(
                satisfaction: stars, wouldRepeat: stars >= 4,
                cityReviews: [CityReview(
                    countryCode: country, city: city, rating: stars,
                    liked: liked ?? text("Great for walking, and lots of places to eat", "걷기 좋고 먹을 곳이 많았어요"),
                    disliked: disliked ?? (stars <= 3 ? text("Too crowded", "너무 붐볐어요") : nil)
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

    /// 스크린샷용 지난 여행. 추천 카드(오사카·도쿄·후쿠오카)와 겹치지 않게 일본은 교토만 둔다.
    private static var storeTrips: [(country: String, city: String, concept: TripConcept, secondary: [TripConcept], stars: Int, liked: String?, photo: String)] {
        [
            ("TW", text("Taipei", "타이베이"), .food, [.cityExploration], 5, text("Loved the night market street food", "야시장 길거리 음식이 정말 좋았어요"), "tw-taipei"),
            ("IT", text("Rome", "로마"), .cultureHistory, [.food], 4, nil, "it-rome"),
            ("NZ", text("Queenstown", "퀸스타운"), .natureScenery, [.activities], 5, nil, "nz-queenstown"),
            ("TH", text("Phuket", "푸껫"), .relaxation, [], 3, nil, "th-phuket-island"),
            ("GB", text("London", "런던"), .cityExploration, [.cultureHistory], 4, nil, "gb-london"),
            ("JP", text("Kyoto", "교토"), .cultureHistory, [.food], 5, nil, "jp-kyoto")
        ]
    }

    /// 스크린샷용 사진은 앱 번들에 넣지 않고 실행 인자로 받은 Mac 폴더에서 읽는다(시뮬레이터 전용).
    private static func demoPhotoPaths(prefix: String, count: Int) -> [String] {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-uiDemoPhotoDir"), args.indices.contains(index + 1) else { return [] }
        let dir = URL(fileURLWithPath: args[index + 1])
        return (1...count).compactMap { n in
            (try? Data(contentsOf: dir.appendingPathComponent("\(prefix)-\(n).jpg"))).flatMap { try? LocalPhotoStore.saveImageData($0) }
        }
    }

    private static func seedTrips(_ store: any AppStore, now: Date) async throws {
        try await store.create(evaluated("JP", "Kyoto", from: -200, to: -196, .cultureHistory, stars: 5, now: now))
        try await store.create(evaluated("TH", "Phuket", from: -120, to: -115, .relaxation, stars: 4, now: now))
    }

    private static let tiers: WantedConceptTiers = {
        var tiers = WantedConceptTiers()
        tiers.tier1 = [.food, .cultureHistory]
        tiers.tier2 = [.cityExploration]
        tiers.tier3 = [.relaxation]
        tiers.avoidNote = text("I'd like to avoid places that are too crowded", "너무 붐비는 곳은 피하고 싶어요")
        return tiers
    }()

    // MARK: 추천 기록

    /// 실제로는 LLM이 앱 언어로 쓰는 문장. 스크린샷이 한 언어로 나오게 앱 언어에 맞춰 고른다.
    private static func text(_ en: String, _ ko: String) -> String { AppLanguage.isKorean ? ko : en }

    /// 금액은 원화로 적고, 영어면 USD로 1/1000 해서 쓴다(150만 원 → $1,500). 같은 비율이라 예산 컷 결과는 같다.
    private static let currency = AppLanguage.isKorean ? BudgetCurrency.krw : "USD"
    private static func money(_ krw: Int) -> Int { AppLanguage.isKorean ? krw : krw / 1000 }
    private static func cost(_ low: Int, _ high: Int) -> CostRange { .init(low: money(low), high: money(high)) }

    private static func card(
        of cityID: String, reason: String = text("A city of long days spent wandering alleys and markets and eating your way through them.", "골목과 시장을 하루 종일 걸으며 먹는 즐거움을 누리는 도시예요."),
        caveat: String = text("It gets crowded in peak season.", "성수기에는 붐벼요."), cost: CostRange? = nil, conditions: [ConditionResult] = []
    ) -> CityRecommendationRecord.Card {
        let city = CityCatalog.load()?.cities.first { $0.id == cityID }
        return .init(
            cityID: cityID, cityName: city?.displayName ?? cityID, country: city?.country ?? "",
            isExploration: false, seasonCheckNeeded: false, reason: reason, caveat: caveat, cost: cost,
            conditions: conditions, conditionCheckNeeded: conditions.contains { $0.status == .unconfirmed }
        )
    }

    private static let japanOnly = CityCondition(
        id: "c1", text: text("Japan", "일본"), quote: text("Japan", "일본"), level: .required, kind: .country, target: "JP"
    )
    private static let shortFlight = CityCondition(
        id: "c2", text: text("Within a 5-hour flight", "비행 5시간 이내"), quote: text("within a 5-hour flight", "비행 5시간 이내"), level: .required, kind: .other
    )

    /// 후보 풀은 서비스의 `replay`와 같은 입력으로 순위를 다시 계산해 만든다. 그래야 저장된 응답을 믿고
    /// 예산 컷·채우기가 풀 일치 검사를 통과한다. 응답은 풀 전체를 덮고, 비용은 정해 둔 값(없으면 풀 순서 기준)을 쓴다.
    private static let demoCosts: [String: CostRange] = [
        "jp-osaka": cost(900_000, 1_300_000), "jp-fukuoka": cost(800_000, 1_200_000),
        "jp-kyoto": cost(1_000_000, 1_400_000), "jp-sapporo": cost(1_800_000, 2_300_000),
        "it-rome": cost(1_100_000, 1_450_000), "es-barcelona": cost(1_000_000, 1_400_000)
    ]

    private static func demoCost(_ cityID: String, index: Int) -> CostRange {
        demoCosts[cityID] ?? cost(900_000 + 100_000 * (index % 8), 1_500_000 + 100_000 * (index % 8))
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
        ).overBudgetIDs
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
        request.budgetMax = budget.map(money)
        request.budgetCurrency = currency
        request.wants = text("Japan, within a 5-hour flight", "일본, 비행 5시간 이내")
        return request
    }

    private static func resultRecord(now: Date) -> CityRecommendationRecord {
        let met = ConditionResult(condition: japanOnly, status: .met)
        let unconfirmed = ConditionResult(condition: shortFlight, status: .unconfirmed)
        return record(
            request(),
            cards: [
                card(of: "jp-osaka", cost: cost(900_000, 1_300_000), conditions: [met]),
                card(of: "jp-fukuoka", cost: cost(800_000, 1_200_000), conditions: [met, unconfirmed]),
                card(of: "jp-kyoto", cost: cost(1_000_000, 1_400_000), conditions: [met])
            ],
            conditions: [japanOnly, shortFlight],
            understanding: text("You're looking for a Japan trip in November, 3 nights, centered on the joy of eating.", "11월에 3박으로, 먹는 즐거움을 중심에 둔 일본 여행을 찾고 있어요."), now: now
        )
    }

    /// 스크린샷용: 세 카드 모두 꼭 지킬 조건을 충족해 "추가 확인 필요"가 나오지 않는다. 3장보다 적으면 복원할 때 풀에서 채운다.
    private static func storeRecord(now: Date) -> CityRecommendationRecord {
        let met = [ConditionResult(condition: japanOnly, status: .met), ConditionResult(condition: shortFlight, status: .met)]
        return record(
            request(),
            cards: [
                card(of: "jp-osaka", reason: text("Like the night markets you loved in Taipei, it's a city for eating your way through alleys and markets.", "타이베이에서 좋았던 야시장 먹거리처럼, 골목과 시장을 걸으며 먹는 재미가 큰 도시예요."),
                     cost: cost(900_000, 1_300_000), conditions: met),
                card(of: "jp-tokyo", reason: text("Small restaurants on every side street make it easy to fill several days with food.", "골목마다 작은 식당이 많아 먹는 여행으로 며칠을 채우기 좋아요."),
                     cost: cost(1_100_000, 1_500_000), conditions: met),
                card(of: "jp-fukuoka", reason: text("Riverside food stalls and a compact center, easy for a short trip.", "강가 포장마차와 가까운 시내 덕분에 짧은 여행에 편한 도시예요."),
                     cost: cost(800_000, 1_200_000), conditions: met)
            ],
            conditions: [japanOnly, shortFlight],
            understanding: text("You're looking for a Japan trip in November, 3 nights, centered on the joy of eating.", "11월에 3박으로, 먹는 즐거움을 중심에 둔 일본 여행을 찾고 있어요."), now: now
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
            request(budget: nil), cards: [], conditions: [japanOnly, shortFlight],
            understanding: nil, error: "noCards", now: now
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
            understanding: text("You're looking for a trip in November, 3 nights, centered on the joy of eating.", "11월에 3박으로, 먹는 즐거움을 중심에 둔 여행을 찾고 있어요."), now: now
        )
    }
}
// l10n-ignore-end
#endif
