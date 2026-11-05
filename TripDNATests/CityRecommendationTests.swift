import Foundation
import Testing
@testable import TripDNA

struct CityRankerTests {
    /// 세부 2개짜리 합성 자료: event = {festival, sports}, food = {dining}, nature = {scenery}.
    static let catalog = CityCatalog(
        version: "test",
        concepts: ["event": ["festival", "sports"], "food": ["dining"], "nature": ["scenery"]],
        cities: []
    )

    static func city(
        _ id: String, country: String = "XX",
        grades: [String: CityGrade] = [:], season: [String: [Int]] = [:], unverified: [String] = []
    ) -> City {
        City(id: id, ko: id, en: id, country: country, grades: grades, season: season, seasonUnverified: unverified)
    }

    static func catalog(_ cities: [City]) -> CityCatalog {
        CityCatalog(version: "test", concepts: catalog.concepts, cities: cities)
    }

    @Test func dropsCitiesBelowMakeTimeForPrimary() {
        let cat = Self.catalog([
            Self.city("a", grades: ["dining": .makeTime]),
            Self.city("b", grades: ["dining": .ifThere]),
            Self.city("c", grades: ["dining": .none])
        ])
        let ranked = CityRanker.rank(catalog: cat, input: CityRankingInput(primary: .food))
        #expect(ranked.map(\.city.id) == ["a"])
    }

    @Test func ordersByPrimaryThenSecondarySumThenTier() {
        let cat = Self.catalog([
            Self.city("low", grades: ["dining": .makeTime, "scenery": .choose]),
            Self.city("top", grades: ["dining": .choose]),
            Self.city("mid", grades: ["dining": .makeTime, "scenery": .makeTime]),
            Self.city("tied", grades: ["dining": .makeTime, "scenery": .makeTime, "festival": .choose])
        ])
        var input = CityRankingInput(primary: .food, secondary: [.natureScenery])
        input.tiers.place(.event, in: 1)
        let ranked = CityRanker.rank(catalog: cat, input: input)
        // choose 먼저. makeTime 묶음에서는 부 컨셉(자연) choose > makeTime(동점 둘은 티어 점수인 이벤트로 가름).
        #expect(ranked.map(\.city.id) == ["top", "low", "tied", "mid"])
    }

    @Test func seasonRemovesOutOfSeasonSubconceptAndKeepsOthers() {
        let cat = Self.catalog([
            Self.city("fest", grades: ["festival": .choose, "sports": .makeTime], season: ["festival": [5, 7, 10]])
        ])
        var june = CityRankingInput(primary: .event)
        june.month = 6
        let result = CityRanker.rank(catalog: cat, input: june)
        #expect(result.first?.primaryGrade == .makeTime)
        june.month = 7
        #expect(CityRanker.rank(catalog: cat, input: june).first?.primaryGrade == .choose)
        june.month = nil
        #expect(CityRanker.rank(catalog: cat, input: june).first?.primaryGrade == .choose)
    }

    @Test func outOfSeasonOnlyCityIsDroppedNotRelabelled() {
        let cat = Self.catalog([Self.city("fest", grades: ["festival": .choose], season: ["festival": [10]])])
        var input = CityRankingInput(primary: .event)
        input.month = 3
        #expect(CityRanker.rank(catalog: cat, input: input).isEmpty)
    }

    @Test func unverifiedSeasonNeedsCheckAndNeverOutranksConfirmed() {
        let cat = Self.catalog([
            Self.city("unverified", grades: ["sports": .choose], unverified: ["sports"]),
            Self.city("confirmed", grades: ["festival": .makeTime])
        ])
        var input = CityRankingInput(primary: .event)
        input.month = 4
        let ranked = CityRanker.rank(catalog: cat, input: input)
        #expect(ranked.map(\.city.id) == ["confirmed", "unverified"])
        #expect(ranked[0].status == .confirmed)
        #expect(ranked[1].status == .needsSeasonCheck)
        #expect(ranked[1].primaryGrade == .choose)
        #expect(ranked[1].unverifiedSubconcepts == ["sports"])
        // 시기를 넣지 않으면 시즌을 적용하지 않는다.
        input.month = nil
        #expect(CityRanker.rank(catalog: cat, input: input).map(\.status) == [.confirmed, .confirmed])
    }

    @Test func excludedCountriesAreRemoved() {
        let cat = Self.catalog([
            Self.city("jp", country: "JP", grades: ["dining": .choose]),
            Self.city("kr", country: "KR", grades: ["dining": .choose])
        ])
        var input = CityRankingInput(primary: .food)
        input.excludedCountries = ["JP"]
        #expect(CityRanker.rank(catalog: cat, input: input).map(\.city.id) == ["kr"])
    }

    @Test func sameSeedGivesSameResultAndSeedChangesTies() {
        let cities = (0..<8).map { Self.city("c\($0)", grades: ["dining": .makeTime]) }
        let cat = Self.catalog(cities)
        var input = CityRankingInput(primary: .food)
        input.seed = 7
        let first = CityRanker.rank(catalog: cat, input: input).map(\.city.id)
        #expect(first == CityRanker.rank(catalog: cat, input: input).map(\.city.id))
        input.seed = 8
        #expect(first != CityRanker.rank(catalog: cat, input: input).map(\.city.id))
    }

    @Test func pickCardsTakesTwoThenExplorationFromFirstBundle() {
        let top = (0..<4).map { Self.city("t\($0)", grades: ["dining": .choose]) }
        let lower = [Self.city("l", grades: ["dining": .makeTime])]
        let cat = Self.catalog(top + lower)
        let ranked = CityRanker.rank(catalog: cat, input: CityRankingInput(primary: .food, seed: 3))
        let picks = CityRanker.pickCards(from: ranked, seed: 3)
        #expect(picks.count == 3)
        #expect(Array(picks.map(\.ranked.city.id).prefix(2)) == ranked.prefix(2).map(\.city.id))
        #expect(picks[2].isExploration)
        #expect(picks[2].ranked.primaryGrade == .choose)
        #expect(picks == CityRanker.pickCards(from: ranked, seed: 3))
    }

    @Test func pickCardsFillsInOrderWhenNoExplorationCandidate() {
        let cat = Self.catalog([
            Self.city("a", grades: ["dining": .choose]),
            Self.city("b", grades: ["dining": .choose]),
            Self.city("c", grades: ["dining": .makeTime])
        ])
        let ranked = CityRanker.rank(catalog: cat, input: CityRankingInput(primary: .food))
        let picks = CityRanker.pickCards(from: ranked, seed: 1)
        #expect(picks.map(\.ranked.city.id) == ranked.map(\.city.id))
        #expect(picks.allSatisfy { !$0.isExploration })
    }
}

struct CityBundleTests {
    @Test func bundledCatalogLoadsWithoutCoreSentences() throws {
        let catalog = try #require(CityCatalog.load(bundle: Bundle(for: BundleToken.self)) ?? CityCatalog.load())
        #expect(catalog.cities.count == 103)
        #expect(catalog.concepts.values.flatMap { $0 }.count == 29)
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "cities", withExtension: "json")
            ?? Bundle.main.url(forResource: "cities", withExtension: "json"))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(!text.contains("\"core\""))
        for city in catalog.cities {
            #expect(city.grades.count == 29, "\(city.id)")
        }
    }

    @Test func realCatalogAppliesFestivalSeason() throws {
        let catalog = try #require(CityCatalog.load(bundle: Bundle(for: BundleToken.self)) ?? CityCatalog.load())
        let kyoto = try #require(catalog.cities.first { $0.id == "jp-kyoto" })
        #expect(CityRanker.grade(kyoto, .event, catalog: catalog, month: 10).confirmed == .choose)
        #expect(CityRanker.grade(kyoto, .event, catalog: catalog, month: 6).confirmed < .choose)
    }

    final class BundleToken {}
}

struct CityLLMRequestTests {
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("data/destinations/catalog.json")

    static func makeRequest(note: String = "") throws -> (CityLLMRequest, CityCatalog) {
        let catalog = try #require(CityCatalog.load(bundle: Bundle(for: CityBundleTests.BundleToken.self)) ?? CityCatalog.load())
        var request = RecommendationRequest()
        request.setPrimary(.event)
        request.toggleSecondary(.food)
        request.toggleMonth(2027, 6)
        request.wants = note
        var tiers = WantedConceptTiers()
        tiers.place(.food, in: 1)
        var input = CityRankingInput(primary: .event, secondary: [.food], tiers: tiers, month: 6)
        input.excludedCountries = ["JP"]
        let ranked = CityRanker.rank(catalog: catalog, input: input)
        input.excludedCountries = []
        let excluded = CityRanker.rank(catalog: catalog, input: input).filter { $0.city.country == "JP" }
        let pool = Array(ranked.prefix(CityLLMRequestBuilder.poolSize))
        let built = CityLLMRequestBuilder.build(
            context: .init(
                request: request, tiers: tiers, catalog: catalog, model: "m",
                excludedCountries: ["JP"], homeCountryExcluded: true
            ),
            ranked: ranked, excludedRanked: excluded, pool: pool
        )
        return (built, catalog)
    }

    @Test func requestHasSeasonUnverifiedAndExcludedMarksButNoGrades() throws {
        let (request, catalog) = try Self.makeRequest(note: "축제 위주로")
        #expect(request.version.catalog == catalog.version)
        #expect(request.version.prompt == CityInputVersion.promptVersion)
        #expect(request.version.model == "m")
        #expect(request.cardIDs.count == CityLLMRequestBuilder.poolSize)
        #expect(!request.requiresCost)
        #expect(request.user.contains("<<<축제 위주로>>>"))
        #expect(request.user.contains("excluded"))
        #expect(request.user.contains("season check needed("))
        // 등급은 순위에만 쓰고 설명 입력에는 넣지 않는다.
        #expect(!CityGrade.allNames.contains { request.user.contains($0) })
        #expect(!request.user.contains("grade"))
        #expect(request.system.contains("as certain"))
        #expect(request.system.contains("need checking"))
    }

    @Test func requestNeverContainsCoreSentences() throws {
        let (request, _) = try Self.makeRequest()
        // 원문 catalog.json은 저장소 루트에 있다. 시뮬레이터 테스트는 호스트 파일 시스템을 읽을 수 있다.
        let data = try #require(try? Data(contentsOf: Self.catalogURL), "catalog.json을 찾지 못했다")
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cities = try #require(json["cities"] as? [String: [String: Any]])
        var checked = 0
        for city in cities.values {
            for sentence in (city["core"] as? [String: String] ?? [:]).values {
                checked += 1
                #expect(!request.user.contains(sentence))
                #expect(!request.system.contains(sentence))
            }
        }
        #expect(checked > 500)
    }
}

struct CityResponseTests {
    static let ids = ["a", "b", "c"]

    static func json(ids: [String] = ids, reason: String = "좋아요", caveat: String = "", cost: String = "null") -> String {
        let cards = ids.map { "{\"id\":\"\($0)\",\"reason\":\"\(reason)\",\"caveat\":\"\(caveat)\",\"cost\":\(cost)}" }
        return "```json\n{\"understanding\":\"u\",\"cards\":[\(cards.joined(separator: ","))]}\n```"
    }

    @Test func acceptsFencedJsonWithRequestedIDsInOrder() throws {
        let response = try CityResponseValidator.parse(Self.json())
        try CityResponseValidator.validate(response, cardIDs: Self.ids, requiresCost: false)
    }

    @Test func cardWithoutCaveatOrCostKeyStillParses() throws {
        let response = try CityResponseValidator.parse("{\"understanding\":\"u\",\"cards\":[{\"id\":\"a\",\"reason\":\"r\"}]}")
        #expect(response.cards.first?.caveat == "")
        #expect(response.cards.first?.cost == nil)
    }

    @Test func costIsRequiredAndOrderedWhenBudgetGiven() throws {
        let none = try CityResponseValidator.parse(Self.json())
        #expect(throws: CityResponseError.invalidCost("a")) {
            try CityResponseValidator.validate(none, cardIDs: Self.ids, requiresCost: true)
        }
        let reversed = try CityResponseValidator.parse(Self.json(cost: "{\"low\":3000000,\"high\":1000000}"))
        #expect(throws: CityResponseError.invalidCost("a")) {
            try CityResponseValidator.validate(reversed, cardIDs: Self.ids, requiresCost: true)
        }
        let ok = try CityResponseValidator.parse(Self.json(cost: "{\"low\":1000000,\"high\":3000000}"))
        try CityResponseValidator.validate(ok, cardIDs: Self.ids, requiresCost: true)
    }

    @Test func rejectsWrongOrMissingIDs() throws {
        let response = try CityResponseValidator.parse(Self.json(ids: ["b", "a", "c"]))
        #expect(throws: CityResponseError.wrongCards) {
            try CityResponseValidator.validate(response, cardIDs: Self.ids, requiresCost: false)
        }
        // 후보 밖 도시를 덧붙여도 후보가 빠지면 여전히 실패한다.
        let missing = try CityResponseValidator.parse(Self.json(ids: ["a", "c", "x"]))
        #expect(throws: CityResponseError.wrongCards) {
            try CityResponseValidator.validate(missing, cardIDs: Self.ids, requiresCost: false)
        }
    }

    /// 2026-10-27 실호출에서 모델이 후보 8곳 뒤에 후보 표의 다른 도시 4곳을 덧붙였다.
    @Test func dropsCitiesOutsideCandidatesWhenCandidateOrderHolds() throws {
        let response = try CityResponseValidator.parse(Self.json(ids: ["x", "a", "b", "y", "c", "z"]))
        let kept = try CityResponseValidator.validate(response, cardIDs: Self.ids, requiresCost: false)
        #expect(kept.cards.map(\.id) == Self.ids)
        #expect(kept.understanding == "u")
    }

    @Test func droppedCardsAreNotChecked() throws {
        let good = Self.ids.map { "{\"id\":\"\($0)\",\"reason\":\"좋아요\",\"cost\":{\"low\":1,\"high\":2}}" }
        let bad = "{\"id\":\"x\",\"reason\":\"일부러 시간을 낼 만함\",\"cost\":null}"
        let response = try CityResponseValidator.parse(
            "{\"understanding\":\"u\",\"cards\":[\((good + [bad]).joined(separator: ","))]}"
        )
        let kept = try CityResponseValidator.validate(response, cardIDs: Self.ids, requiresCost: true)
        #expect(kept.cards.map(\.id) == Self.ids)
    }

    @Test func rejectsLeakedGradeNamesAndNonJSON() throws {
        let leaked = try CityResponseValidator.parse(Self.json(reason: "일부러 시간을 낼 만함 수준이에요"))
        #expect(throws: CityResponseError.internalTermLeaked("일부러 시간을 낼 만함")) {
            try CityResponseValidator.validate(leaked, cardIDs: Self.ids, requiresCost: false)
        }
        #expect(throws: CityResponseError.notJSON) { try CityResponseValidator.parse("죄송합니다") }
    }
}

struct CityRecommendationServiceTests {
    struct Fake: CityLLMClient {
        var reply: @Sendable (String) throws -> String
        func complete(system: String, user: String) async throws -> String { try reply(user) }
    }

    static func service(client: (any CityLLMClient)?, dir: URL) throws -> CityRecommendationService {
        let catalog = try #require(CityCatalog.load(bundle: Bundle(for: CityBundleTests.BundleToken.self)) ?? CityCatalog.load())
        return CityRecommendationService(catalog: catalog, client: client, log: .init(directory: dir))
    }

    /// 요청의 "후보 도시" 구역에서 id를 읽어 응답한다. `lows`의 앞에서부터 비용 하한을 준다(없으면 100만원).
    /// `extra`는 후보 뒤에 덧붙이는 후보 밖 도시 id다(모델이 지시를 어긴 경우).
    static func fake(
        lows: [Int] = [], withCost: Bool = true, extraction: String = "{\"conditions\":[]}", memoriesUsed: String = "[]",
        extra: [String] = []
    ) -> Fake {
        Fake { user in
            if user.contains("[Chosen concepts]") { return extraction }
            let ids = user.components(separatedBy: "[Candidate cities")[1]
                .components(separatedBy: "\n\n")[0]
                .components(separatedBy: "\n").dropFirst()
                .map { String($0.split(separator: "|")[0]).trimmingCharacters(in: .whitespaces) }
            let cards = (ids + extra).enumerated().map { index, id in
                let low = index < lows.count ? lows[index] : 1_000_000
                let cost = withCost ? "{\"low\":\(low),\"high\":\(low * 2)}" : "null"
                return "{\"id\":\"\(id)\",\"reason\":\"이유\",\"caveat\":\"\",\"cost\":\(cost)}"
            }.joined(separator: ",")
            return "{\"understanding\":\"요약\",\"cards\":[\(cards)],\"memories_used\":\(memoriesUsed)}"
        }
    }

    static func request() -> RecommendationRequest {
        var request = RecommendationRequest()
        request.setPrimary(.food)
        request.wants = "가볍게 먹으러 가고 싶어요"
        return request
    }

    @Test func storesInputVersionAndResultForReplay() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let client = Self.fake()
        let service = try Self.service(client: client, dir: dir)
        let record = try await service.recommend(
            request: Self.request(), tiers: WantedConceptTiers(), excludedCountries: ["JP"],
            homeCountryExcluded: false, seed: 42
        )
        #expect(record.cards.count == 3)
        #expect(record.cards.allSatisfy { $0.country != "JP" })
        let loaded = CityRecommendationLog(directory: dir).load()
        #expect(loaded.count == 1)
        let stored = try #require(loaded.first)
        #expect(stored.id == record.id)
        #expect(stored.seed == 42)
        #expect(stored.version.prompt == CityInputVersion.promptVersion)
        #expect(stored.version.ranking == CityInputVersion.rankingVersion)
        #expect(!stored.version.catalog.isEmpty)
        #expect(stored.input.wants == "가볍게 먹으러 가고 싶어요")
        #expect(stored.user.contains("가볍게 먹으러 가고 싶어요"))
        #expect(stored.rawResponse != nil)

        // 같은 입력과 시드로 다시 계산하면 같은 카드·같은 요청 문장이 나온다.
        let replay = try await Self.service(client: client, dir: dir.appendingPathComponent("replay")).recommend(
            request: stored.input, tiers: stored.tiers, excludedCountries: Set(stored.excludedCountries),
            homeCountryExcluded: false, seed: stored.seed
        )
        #expect(replay.cards.map(\.cityID) == record.cards.map(\.cityID))
        #expect(replay.user == record.user)
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("replay"))
    }

    /// 프록시의 한도 초과(429)는 조건 추출 단계에서 나도 "추출 실패"가 아니라 한도 초과로 알린다.
    @Test func quotaExceededIsReportedFromEitherStep() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let resetAt = Date(timeIntervalSince1970: 1_796_083_200)
        let quota = Fake { _ in throw CityLLMError.quotaExceeded(resetAt: resetAt) }
        var plain = Self.request()
        plain.wants = ""
        for request in [Self.request(), plain] {
            await #expect(throws: CityRecommendationError.quotaExceeded(resetAt: resetAt)) {
                try await Self.service(client: quota, dir: dir).recommend(
                    request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false
                )
            }
        }
    }

    @Test func proxyReadsQuotaResponse() throws {
        let url = URL(string: "https://example.test")!
        let response = { (code: Int) in HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)! }
        let body = Data(#"{"error":"quota","kind":"recommend","resetAt":1796083200}"#.utf8)
        #expect(throws: CityLLMError.quotaExceeded(resetAt: Date(timeIntervalSince1970: 1_796_083_200))) {
            try CityLLMProxyClient.check(response(429), body)
        }
        #expect(throws: CityLLMError.http(429)) { try CityLLMProxyClient.check(response(429), Data()) }
        #expect(throws: CityLLMError.http(503)) { try CityLLMProxyClient.check(response(503), body) }
        try CityLLMProxyClient.check(response(200), Data())
    }

    @Test func failedRecommendationReusesItsIDOnce() {
        let id = "A-RECO-ID"
        #expect(CityRecommendationViewModel.retryID(after: CityRecommendationError.invalidResponse("x"), usageID: id, isRetry: false) == id)
        #expect(CityRecommendationViewModel.retryID(after: CityRecommendationError.network("x"), usageID: id, isRetry: true) == nil)
        #expect(CityRecommendationViewModel.retryID(
            after: CityRecommendationError.quotaExceeded(resetAt: .now), usageID: id, isRetry: false
        ) == nil)
    }

    @Test func proxyClientsGetFreshUsageIDs() {
        let url = URL(string: "https://example.test")!
        #expect(CityLLMProxyClient(url: url, model: "m").usageID != CityLLMProxyClient(url: url, model: "m").usageID)
    }

    @Test func overBudgetCitiesGoLastInsteadOfBeingRemoved() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = Self.request()
        request.budgetMax = 2_000_000
        // 순위 1·2번째 도시는 하한이 예산을 넘는다.
        let service = try Self.service(client: Self.fake(lows: [3_000_000, 2_500_000]), dir: dir)
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false, seed: 5
        )
        #expect(record.budgetCutCityIDs == Array(record.poolCityIDs.prefix(2)))
        #expect(record.cards.count == 3)
        #expect(record.cards.allSatisfy { !record.budgetCutCityIDs.contains($0.cityID) })
        #expect(record.cards.allSatisfy { ($0.cost?.low ?? .max) <= 2_000_000 })
    }

    @Test func fewWithinBudgetFillWithOverBudgetCitiesInRankOrder() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = Self.request()
        request.budgetMax = 2_000_000
        // 순위 4번째 한 곳만 예산 안이다.
        let lows = [3_000_000, 2_500_000, 2_200_000, 1_000_000] + Array(repeating: 9_000_000, count: 4)
        let service = try Self.service(client: Self.fake(lows: lows), dir: dir)
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false, seed: 5
        )
        let pool = record.poolCityIDs
        #expect(record.cards.map(\.cityID) == [pool[3], pool[0], pool[1]])
        #expect(record.budgetCutCityIDs == pool.filter { $0 != pool[3] })
        #expect(record.error == nil)
    }

    @Test func allOverBudgetStillShowsCardsAndIsLogged() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = Self.request()
        request.budgetMax = 500_000
        let service = try Self.service(client: Self.fake(lows: Array(repeating: 9_000_000, count: 8)), dir: dir)
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false
        )
        #expect(record.cards.map(\.cityID) == Array(record.poolCityIDs.prefix(3)))
        #expect(record.cards.allSatisfy { !$0.isExploration })
        #expect(record.error == nil)
        #expect(CityRecommendationLog(directory: dir).load().first?.budgetCutCityIDs.count == 8)
    }

    @Test func reselectedFillsResultsSavedUnderTheOldCutRule() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = Self.request()
        request.budgetMax = 500_000
        let service = try Self.service(client: Self.fake(lows: Array(repeating: 9_000_000, count: 8)), dir: dir)
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false
        )
        // 예전 규칙이었다면 모두 빠져 카드가 없었다.
        var old = record
        old.cards = []
        old.error = "noneWithinBudget"
        let offline = try Self.service(client: nil, dir: dir)
        let restored = offline.reselected(old)
        #expect(restored.cards == record.cards)
        #expect(restored.error == nil)
        #expect(restored.id == record.id)
        // 지금 규칙으로 만든 결과는 그대로다.
        #expect(offline.reselected(record) == record)
    }

    @Test func recutChangesBudgetWithoutCallingLLM() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = Self.request()
        request.budgetMax = 2_000_000
        // 순위 1·2번째 하한 3,000,000·2,500,000, 나머지 1,000,000.
        let service = try Self.service(client: Self.fake(lows: [3_000_000, 2_500_000]), dir: dir)
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false, seed: 5
        )
        #expect(record.budgetCutCityIDs.count == 2)
        // 클라이언트가 없는 서비스로도 다시 계산된다 = LLM을 부르지 않는다.
        let offline = try Self.service(client: nil, dir: dir)
        let loosened = try #require(offline.recut(record, budgetMax: 4_000_000))
        #expect(loosened.budgetCutCityIDs.isEmpty)
        #expect(loosened.derivedFrom == record.id)
        #expect(loosened.input.budgetMax == 4_000_000)
        #expect(loosened.cards.map(\.cityID).prefix(2) == record.poolCityIDs.prefix(2))
        let tightened = try #require(offline.recut(loosened, budgetMax: 100_000))
        #expect(tightened.cards.map(\.cityID) == Array(record.poolCityIDs.prefix(3)))
        #expect(tightened.error == nil)
        #expect(tightened.budgetCutCityIDs.count == 8)
        #expect(CityRecommendationLog(directory: dir).load().count == 3)
    }

    @Test func recutIsUnavailableWithoutBudgetEstimates() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = try Self.service(client: Self.fake(withCost: false), dir: dir)
        let record = try await service.recommend(
            request: Self.request(), tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false, seed: 5
        )
        #expect(service.recut(record, budgetMax: 1_000_000) == nil)
    }

    @Test func failedResponseIsStillLoggedWithError() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var noWants = Self.request()
        noWants.wants = ""
        let service = try Self.service(client: Fake { _ in "not json" }, dir: dir)
        await #expect(throws: CityRecommendationError.self) {
            _ = try await service.recommend(
                request: noWants, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false
            )
        }
        let logged = try #require(CityRecommendationLog(directory: dir).load().first)
        #expect(logged.error != nil)
        #expect(logged.rawResponse == "not json")
        #expect(logged.cards.isEmpty)
    }

    @Test func missingClientReportsNotConfigured() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = try Self.service(client: nil, dir: dir)
        await #expect(throws: CityRecommendationError.notConfigured) {
            _ = try await service.recommend(
                request: Self.request(), tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false
            )
        }
    }
}

extension CityGrade {
    static var allNames: [String] { [CityGrade.ifThere, .makeTime, .choose].map(\.name) }
}

struct CityConditionTests {
    static let concepts = ["food": ["dining"], "nature": ["hiking", "scenery"], "event": ["festival"]]

    static func city(
        _ id: String, country: String = "XX", grades: [String: CityGrade] = [:],
        season: [String: [Int]] = [:], unverified: [String] = []
    ) -> City {
        City(id: id, ko: id, en: id, country: country, grades: grades, season: season, seasonUnverified: unverified)
    }

    static func catalog(_ cities: [City]) -> CityCatalog {
        CityCatalog(version: "t", concepts: concepts, cities: cities)
    }

    @Test func acceptsOnlyConditionsGroundedInUserText() {
        let cat = Self.catalog([])
        let good = CityCondition(id: "a", text: "하이킹", quote: "하이킹 위주", level: .core, kind: .subconcept, target: "hiking")
        let noQuote = CityCondition(id: "b", text: "x", quote: "없는 말", level: .required, kind: .other)
        let badTarget = CityCondition(id: "c", text: "x", quote: "하이킹 위주", level: .core, kind: .subconcept, target: "nope")
        let dup = CityCondition(id: "a", text: "중복", quote: "하이킹 위주", level: .core, kind: .other)
        let result = CityConditionJudge.accept([good, noQuote, badTarget, dup], userText: "하이킹 위주로 가고 싶어요", catalog: cat)
        #expect(result.accepted.map(\.id) == ["a"])
        #expect(result.rejected == ["b", "c", "a"])
    }

    @Test func judgesSubconceptCountrySeasonAndOther() {
        let cat = Self.catalog([])
        let kr = Self.city("kr", country: "KR", grades: ["hiking": .choose, "festival": .choose],
                           season: ["festival": [10]], unverified: [])
        let hike = CityCondition(id: "h", text: "", quote: "q", level: .core, kind: .subconcept, target: "hiking")
        #expect(CityConditionJudge.status(of: hike, city: kr, catalog: cat, month: nil) == .met)
        let fest = CityCondition(id: "f", text: "", quote: "q", level: .core, kind: .subconcept, target: "festival")
        #expect(CityConditionJudge.status(of: fest, city: kr, catalog: cat, month: 10) == .met)
        #expect(CityConditionJudge.status(of: fest, city: kr, catalog: cat, month: 3) == .notMet)
        let unverified = Self.city("u", grades: ["festival": .choose], unverified: ["festival"])
        #expect(CityConditionJudge.status(of: fest, city: unverified, catalog: cat, month: 3) == .unconfirmed)
        let only = CityCondition(id: "c", text: "", quote: "q", level: .required, kind: .country, target: "kr")
        #expect(CityConditionJudge.status(of: only, city: kr, catalog: cat, month: nil) == .met)
        let avoid = CityCondition(id: "d", text: "", quote: "q", level: .required, kind: .country, target: "KR", polarity: .avoid)
        #expect(CityConditionJudge.status(of: avoid, city: kr, catalog: cat, month: nil) == .notMet)
        let other = CityCondition(id: "o", text: "", quote: "q", level: .required, kind: .other)
        #expect(CityConditionJudge.status(of: other, city: kr, catalog: cat, month: nil) == .unconfirmed)
    }

    /// 2026-11-05 정책: 경험 조건은 중요도와 상관없이 make_time 이상이면 충족. 예전 기록의 min_grade는 무시한다.
    @Test func subconceptConditionsUseMakeTimeForEveryLevel() throws {
        let cat = Self.catalog([
            Self.city("paris", grades: ["dining": .choose, "museums": .choose, "nightview": .choose]),
            Self.city("tokyo", grades: ["dining": .choose, "museums": .makeTime, "nightview": .choose]),
            Self.city("bangkok", grades: ["dining": .choose, "museums": .ifThere, "nightview": .makeTime])
        ])
        let old = try JSONDecoder().decode(CityCondition.self, from: Data(
            #"{"id":"m","text":"","quote":"q","level":"supporting","kind":"subconcept","target":"museums","min_grade":"choose"}"#.utf8))
        let city = { (id: String) in cat.cities.first { $0.id == id }! }
        #expect(CityConditionJudge.status(of: old, city: city("tokyo"), catalog: cat, month: nil) == .met)
        #expect(CityConditionJudge.status(of: old, city: city("bangkok"), catalog: cat, month: nil) == .notMet)
        for level in [CityCondition.Level.required, .core] {
            let c = CityCondition(id: "m", text: "", quote: "q", level: level, kind: .subconcept, target: "museums")
            #expect(CityConditionJudge.status(of: c, city: city("tokyo"), catalog: cat, month: nil) == .met)
        }
        // 필수 경험 조건을 채우지 못한 도시(if_there)는 여전히 후보에서 빠진다.
        var input = CityRankingInput(primary: .food)
        input.conditions = [CityCondition(id: "m", text: "", quote: "q", level: .required, kind: .subconcept, target: "museums")]
        #expect(Set(CityRanker.rank(catalog: cat, input: input).map(\.city.id)) == ["paris", "tokyo"])
    }

    @Test func requiredNotMetDropsRequiredUnconfirmedGoesLastCoreOrders() {
        let cat = Self.catalog([
            Self.city("jp", country: "JP", grades: ["dining": .choose, "hiking": .choose]),
            Self.city("kr", country: "KR", grades: ["dining": .choose, "hiking": .ifThere]),
            Self.city("kr2", country: "KR", grades: ["dining": .makeTime, "hiking": .choose])
        ])
        var input = CityRankingInput(primary: .food)
        // 필수 나라 KR → jp 제외.
        input.conditions = [CityCondition(id: "c", text: "", quote: "q", level: .required, kind: .country, target: "KR")]
        #expect(Set(CityRanker.rank(catalog: cat, input: input).map(\.city.id)) == ["kr", "kr2"])
        // 핵심 선호 하이킹 → 주 컨셉 등급이 낮아도 충족한 도시가 앞선다.
        input.conditions = [CityCondition(id: "h", text: "", quote: "q", level: .core, kind: .subconcept, target: "hiking")]
        #expect(CityRanker.rank(catalog: cat, input: input).first?.city.id == "jp")
        let ranked = CityRanker.rank(catalog: cat, input: input).map(\.city.id)
        #expect(ranked.firstIndex(of: "jp")! < ranked.firstIndex(of: "kr")!)
        // 확인 못 한 필수 조건은 모든 도시를 같은 "확인 필요" 묶음으로 보낸다. 충족 도시가 따로 없으면 순서는 그대로.
        input.conditions = [CityCondition(id: "o", text: "", quote: "q", level: .required, kind: .other)]
        let checked = CityRanker.rank(catalog: cat, input: input)
        #expect(checked.allSatisfy { $0.needsConditionCheck })
    }
}

struct CityMemoryAndTwoStageTests {
    static func trip(city: String, rating: Int, liked: String, evaluatedAt: Date) throws -> Trip {
        var trip = try Trip(
            legs: [TripLeg(countryCode: "JP", cities: [city], startDate: evaluatedAt, endDate: evaluatedAt)],
            companion: .alone, purpose: .leisure
        )
        try trip.end(at: evaluatedAt)
        try trip.submit(
            TripEvaluation(
                satisfaction: 4, wouldRepeat: true,
                cityReviews: [CityReview(countryCode: "JP", city: city, rating: rating, liked: liked, disliked: nil)],
                source: .postTrip
            ),
            at: evaluatedAt
        )
        return trip
    }

    @Test func longMemoIsCutToLimitBeforeSending() throws {
        let long = String(repeating: "가", count: CityMemory.memoLimit + 50)
        let trip = try Self.trip(city: "교토", rating: 4, liked: long, evaluatedAt: Date(timeIntervalSince1970: 1_000))
        let memory = try #require(CityMemory.recent(from: [trip]).first)
        #expect(memory.liked?.count == CityMemory.memoLimit)
    }

    @Test func memoriesAreRecentFirstAndCapped() throws {
        let old = try Self.trip(city: "교토", rating: 4, liked: "조용했다", evaluatedAt: Date(timeIntervalSince1970: 1_000))
        let new = try Self.trip(city: "오사카", rating: 5, liked: "먹을 게 많았다", evaluatedAt: Date(timeIntervalSince1970: 2_000))
        let memories = CityMemory.recent(from: [old, new], limit: 1)
        #expect(memories.count == 1)
        #expect(memories[0].id == "m1")
        #expect(memories[0].city == "오사카")
        #expect(memories[0].liked == "먹을 게 많았다")
    }

    @Test func twoStageFlowUsesConditionsAndMemories() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = CityRecommendationServiceTests.request()
        request.wants = "맛집 위주로 가고 싶어요"
        let extraction = "{\"conditions\":[{\"id\":\"f1\",\"text\":\"미식 중심\",\"quote\":\"맛집 위주\",\"level\":\"core\",\"kind\":\"subconcept\",\"target\":\"dining\"},{\"id\":\"x\",\"text\":\"지어낸\",\"quote\":\"본 적 없는 문장\",\"level\":\"required\",\"kind\":\"other\"}]}"
        let client = CityRecommendationServiceTests.fake(extraction: extraction, memoriesUsed: "[{\"id\":\"m1\",\"how\":\"오사카에서 먹거리를 좋아했어요\"}]")
        let service = try CityRecommendationServiceTests.service(client: client, dir: dir)
        let memory = CityMemory(id: "m1", tripID: "t", countryCode: "JP", city: "오사카", rating: 5, liked: "먹을 게 많았다", disliked: nil)
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false,
            memories: [memory], seed: 1
        )
        #expect(record.conditions.map(\.id) == ["f1"])
        #expect(record.rejectedConditionIDs == ["x"])
        #expect(record.extraction?.raw == extraction)
        #expect(record.memoriesUsed.map(\.id) == ["m1"])
        #expect(record.user.contains("<<<먹을 게 많았다>>>"))
        #expect(record.user.contains("[Conditions from this request"))
        #expect(record.cards.allSatisfy { $0.conditions.map(\.condition.id) == ["f1"] })
    }

    @Test func memoryIDNotInInputIsRejected() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let client = CityRecommendationServiceTests.fake(memoriesUsed: "[{\"id\":\"m9\",\"how\":\"x\"}]")
        let service = try CityRecommendationServiceTests.service(client: client, dir: dir)
        await #expect(throws: CityRecommendationError.self) {
            _ = try await service.recommend(
                request: CityRecommendationServiceTests.request(), tiers: WantedConceptTiers(),
                excludedCountries: [], homeCountryExcluded: false
            )
        }
    }

    @Test func noMemoriesMeansNoMemorySectionInRequest() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = try CityRecommendationServiceTests.service(client: CityRecommendationServiceTests.fake(), dir: dir)
        let record = try await service.recommend(
            request: CityRecommendationServiceTests.request(), tiers: WantedConceptTiers(),
            excludedCountries: [], homeCountryExcluded: false
        )
        #expect(!record.user.contains("Past trip reviews —"))
    }

    @Test func extractionFailureStopsBeforeSecondCallAndIsLogged() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = CityRecommendationServiceTests.request()
        request.wants = "일본만 가고 싶어요"
        let service = try CityRecommendationServiceTests.service(
            client: CityRecommendationServiceTests.fake(extraction: "not json"), dir: dir
        )
        await #expect(throws: CityRecommendationError.self) {
            _ = try await service.recommend(
                request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false
            )
        }
        let logged = try #require(CityRecommendationLog(directory: dir).load().first)
        #expect(logged.cards.isEmpty)
        #expect(logged.rawResponse == nil)
        #expect(logged.extraction?.error != nil)
        #expect(logged.error?.contains("extractionFailed") == true)
    }

    @Test func recutDropsStaleUnderstandingAndMarksDerived() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = CityRecommendationServiceTests.request()
        request.budgetMax = 2_000_000
        let service = try CityRecommendationServiceTests.service(client: CityRecommendationServiceTests.fake(), dir: dir)
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false, seed: 2
        )
        #expect(record.understanding != nil)
        let derived = try #require(service.recut(record, budgetMax: 1_500_000))
        #expect(derived.understanding == nil)
        #expect(derived.derivedFrom == record.id)
    }

    @Test func logDeleteAllRemovesRecords() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = try CityRecommendationServiceTests.service(client: CityRecommendationServiceTests.fake(), dir: dir)
        _ = try await service.recommend(
            request: CityRecommendationServiceTests.request(), tiers: WantedConceptTiers(),
            excludedCountries: [], homeCountryExcluded: false
        )
        let log = CityRecommendationLog(directory: dir)
        #expect(log.load().count == 1)
        try log.deleteAll()
        #expect(log.load().isEmpty)
        try log.deleteAll()
    }

    @Test func consentResetReturnsToUndecided() {
        CityMemoryConsent.state = .granted
        CityMemoryConsent.reset()
        #expect(CityMemoryConsent.state == .undecided)
    }
}

// MARK: - 도시 저장·제외·결과 복원

struct CityStateTests {
    static func card(_ id: String, country: String = "JP", conditions: [ConditionResult] = []) -> CityRecommendationRecord.Card {
        .init(
            cityID: id, cityName: id, country: country, isExploration: false, seasonCheckNeeded: false,
            reason: "이유", caveat: "", cost: nil, conditions: conditions, conditionCheckNeeded: false
        )
    }

    static func condition(_ level: CityCondition.Level, _ status: ConditionStatus, text: String = "조건") -> ConditionResult {
        .init(condition: CityCondition(id: text, text: text, quote: text, level: level, kind: .other), status: status)
    }

    static func record(dir: URL, excludedCities: Set<String> = []) async throws -> CityRecommendationRecord {
        let service = try CityRecommendationServiceTests.service(client: CityRecommendationServiceTests.fake(), dir: dir)
        return try await service.recommend(
            request: CityRecommendationServiceTests.request(), tiers: WantedConceptTiers(),
            excludedCountries: [], excludedCities: excludedCities, homeCountryExcluded: false, seed: 7
        )
    }

    @Test func excludedCityIsRemovedFromRankingPoolAndRecut() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let base = try await Self.record(dir: dir)
        let first = try #require(base.rankedCityIDs.first)
        let record = try await Self.record(dir: dir, excludedCities: [first])
        #expect(!record.rankedCityIDs.contains(first))
        #expect(!record.poolCityIDs.contains(first))
        #expect(!record.cards.contains { $0.cityID == first })
        #expect(record.excludedCityIDs == [first])

        // 예산만 바꿔 다시 계산해도 제외한 도시는 돌아오지 않는다.
        let service = try CityRecommendationServiceTests.service(client: nil, dir: dir)
        let derived = try #require(service.recut(record, budgetMax: nil))
        #expect(!derived.poolCityIDs.contains(first))
    }

    @Test func visitedCitiesMatchByNameAndCountryOnly() throws {
        let cat = CityRankerTests.catalog([
            City(id: "jp-osaka", ko: "오사카", en: "Osaka", country: "JP", grades: [:], season: [:], seasonUnverified: []),
            City(id: "jp-kyoto", ko: "교토", en: "Kyoto", country: "JP", grades: [:], season: [:], seasonUnverified: []),
            City(id: "jp-tokyo", ko: "도쿄", en: "Tokyo", country: "JP", grades: [:], season: [:], seasonUnverified: [])
        ])
        let day = Date(timeIntervalSince1970: 0)
        let trip = try Trip(legs: [
            TripLeg(countryCode: "JP", cities: ["오사카", " kyoto "], startDate: day, endDate: day),
            TripLeg(countryCode: "KR", cities: ["Tokyo"], startDate: day, endDate: day)
        ], companion: .alone, purpose: .leisure)
        // 같은 나라의 다른 도시(도쿄)는 빼지 않고, 나라가 다른 같은 이름도 맞추지 않는다.
        #expect(cat.cityIDs(visitedIn: [trip]) == ["jp-osaka", "jp-kyoto"])
    }

    @Test @MainActor func cityImpressionsAreLocalOncePerResultAndKeepPosition() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let record = try await Self.record(dir: dir)
        let card = try #require(record.cards.last)
        let dependencies = AppDependencies(persistence: .inMemory)
        let store = try #require(dependencies.store as? SwiftDataAppStore)
        let exposure = RecommendationExposure(record: record)
        #expect(try await store.events().filter { $0.type == .recommendationImpression }.isEmpty)
        await exposure.record(card, screen: "cards", position: 2, dependencies: dependencies)
        await exposure.record(card, screen: "cards", position: 2, dependencies: dependencies)
        let events = try await store.events().filter { $0.type == .recommendationImpression }
        #expect(events.count == 1)
        #expect(events.first?.payload["resultID"] == record.id)
        #expect(events.first?.payload["cityID"] == card.cityID)
        #expect(events.first?.payload["position"] == "2")
        #expect(events.first?.payload["catalogVersion"] == record.version.catalog)
        try await store.deleteAllUserData()
        #expect(try await store.events().isEmpty)
    }

    @Test func rankerSkipsExcludedCities() throws {
        let cat = CityRankerTests.catalog([
            CityRankerTests.city("a", grades: ["dining": .choose]),
            CityRankerTests.city("b", grades: ["dining": .makeTime])
        ])
        var input = CityRankingInput(primary: .food)
        input.excludedCities = ["a"]
        #expect(CityRanker.rank(catalog: cat, input: input).map(\.city.id) == ["b"])
    }

    @Test func restoredResultHidesCitiesAndCountriesExcludedLater() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let record = try await Self.record(dir: dir)
        let store = InMemoryAppStore(countries: [], tags: [])
        try await store.updateCityState { $0.lastRecord = record }

        let restored = try #require(try await store.cityState().lastRecord)
        #expect(restored.cards == record.cards)
        let firstCity = restored.cards[0].cityID
        let secondCountry = restored.cards[1].country
        let visible = restored.visibleCards(excludedCities: [firstCity], excludedCountries: [secondCountry])
        #expect(!visible.contains { $0.cityID == firstCity })
        #expect(!visible.contains { $0.country == secondCountry })
        // 저장된 결과 자체는 그대로다.
        #expect(restored.cards.count == record.cards.count)
    }

    @Test func skippedIDsRoundTripAndOldDataDecodesEmpty() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let store = SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(url: url), countries: [], tags: [])
            try await store.updateCityState { $0.skippedCityIDs = ["a", "b"]; $0.retryUsageID = "RETRY-ID" }
        }
        let reopened = SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(url: url), countries: [], tags: [])
        #expect(try await reopened.cityState().skippedCityIDs == ["a", "b"])
        // 실패한 추천의 ID는 앱을 다시 켜도 남아 다음 추천받기가 이어 쓴다.
        #expect(try await reopened.cityState().retryUsageID == "RETRY-ID")
        let old = try JSONDecoder().decode(CityRecommendationState.self, from: Data("{\"saved\":[]}".utf8))
        #expect(old.skippedCityIDs == [])
        #expect(old.retryUsageID == nil)
    }

    private static func seed(_ dependencies: AppDependencies, budget: Int? = nil) async throws -> CityRecommendationRecord {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = try CityRecommendationServiceTests.service(client: CityRecommendationServiceTests.fake(), dir: dir)
        var request = CityRecommendationServiceTests.request()
        request.budgetMax = budget
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], excludedCities: [],
            homeCountryExcluded: false, seed: 7
        )
        try await dependencies.store.updateCityState { $0.lastRecord = record }
        return record
    }

    @Test @MainActor func skipsSurviveRestartAndRefillsMatch() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let record = try await Self.seed(dependencies)
        let before = CityRecommendationViewModel()
        await before.restore(dependencies: dependencies)
        // 원래 카드와, 넘기기로 들어온 보충 카드까지 넘긴다.
        await before.skip(record.cards[0].cityID, dependencies: dependencies)
        let refilled = try #require(before.refills.first)
        await before.skip(refilled.cityID, dependencies: dependencies)
        await before.skip(record.cards[1].cityID, dependencies: dependencies)
        #expect(before.actionError == nil)
        #expect(!before.visibleCards(record).contains { $0.cityID == record.cards[0].cityID })

        let after = CityRecommendationViewModel()
        await after.restore(dependencies: dependencies)
        #expect(after.skippedCityIDs == before.skippedCityIDs)
        #expect(after.visibleCards(record).map(\.cityID) == before.visibleCards(record).map(\.cityID))
        #expect(after.visibleCards(record).count == record.cards.count)
        // 영구 제외로 번지지 않는다.
        #expect(try await dependencies.store.cityState().excluded.isEmpty)
    }

    // MARK: 순위 정책이 바뀐 기록(city-rank-v4, 경험 조건 충족 기준 make_time 통일)

    /// 저장된 기록의 순위 버전과 조건만 바꾼 사본. 예전에 저장된 기록을 흉내 낸다.
    static func variant(_ record: CityRecommendationRecord, ranking: String, conditions: [CityCondition]) throws -> CityRecommendationRecord {
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        var version = try #require(object["version"] as? [String: Any])
        version["ranking"] = ranking
        object["version"] = version
        object["conditions"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(conditions))
        return try JSONDecoder().decode(CityRecommendationRecord.self, from: JSONSerialization.data(withJSONObject: object))
    }

    static let museum = CityCondition(id: "m", text: "박물관", quote: "q", level: .supporting, kind: .subconcept, target: "museums")

    @Test func rankingPolicyChangeIsOnlyOldRecordsWithExperienceConditions() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let record = try await Self.seed(dependencies, budget: 5_000_000)
        #expect(!CityRecommendationService.rankingPolicyChanged(record))
        #expect(!CityRecommendationService.rankingPolicyChanged(try Self.variant(record, ranking: CityInputVersion.rankingVersion, conditions: [Self.museum])))
        #expect(CityRecommendationService.rankingPolicyChanged(try Self.variant(record, ranking: "city-rank-v3", conditions: [Self.museum])))
        // 버전 기록이 더 오래된 것도 이전 정책이다.
        #expect(CityRecommendationService.rankingPolicyChanged(try Self.variant(record, ranking: "city-rank-v1", conditions: [Self.museum])))
        // 경험 조건이 없거나, 판정 기준이 없는 회피 조건만 있으면 바뀐 기준의 영향이 없다.
        let other = CityCondition(id: "o", text: "직항", quote: "q", level: .required, kind: .other)
        var avoid = Self.museum
        avoid.polarity = .avoid
        #expect(!CityRecommendationService.rankingPolicyChanged(try Self.variant(record, ranking: "city-rank-v3", conditions: [other, avoid])))
    }

    @Test @MainActor func oldPolicyWithExperienceConditionKeepsResultButExplainsBlockedActions() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let seeded = try await Self.seed(dependencies, budget: 5_000_000)
        let old = try Self.variant(seeded, ranking: "city-rank-v3", conditions: [Self.museum])
        try await dependencies.store.updateCityState { $0.lastRecord = old }
        let service = try CityRecommendationServiceTests.service(client: nil, dir: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        #expect(service.recut(old, budgetMax: 4_000_000) == nil)
        #expect(service.refill(old, count: 1, shown: Set(old.cards.map(\.cityID)), removedCities: [], removedCountries: []).isEmpty)

        let model = CityRecommendationViewModel()
        await model.restore(dependencies: dependencies)
        // 저장된 결과는 그대로 보이고, 열기만 해서는 안내가 뜨지 않는다.
        #expect(model.state == .done(old))
        #expect(model.actionError == nil)
        // 넘기기는 되지만 빈 자리는 채우지 않고 이유를 알린다.
        await model.skip(old.cards[0].cityID, dependencies: dependencies)
        #expect(model.skippedCityIDs == [old.cards[0].cityID])
        #expect(model.refills.isEmpty)
        #expect(model.actionError == CityRecommendationViewModel.policyChanged)
        // 예산 변경도 다시 계산하지 않고 이유를 알린다. 결과는 바뀌지 않는다.
        await model.applyBudget(4_000_000, dependencies: dependencies)
        #expect(model.lastRecord == old)
        #expect(model.actionError == CityRecommendationViewModel.policyChanged)
    }

    @Test @MainActor func oldPolicyWithoutExperienceConditionWorksAsBefore() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let seeded = try await Self.seed(dependencies, budget: 5_000_000)
        let old = try Self.variant(seeded, ranking: "city-rank-v3", conditions: [])
        try await dependencies.store.updateCityState { $0.lastRecord = old }
        let model = CityRecommendationViewModel()
        await model.restore(dependencies: dependencies)
        await model.skip(old.cards[0].cityID, dependencies: dependencies)
        #expect(!model.refills.isEmpty)
        await model.applyBudget(4_000_000, dependencies: dependencies)
        #expect(model.lastRecord?.derivedFrom == old.id)
        #expect(model.actionError == nil)
    }

    @Test @MainActor func newResultClearsSkipsButBudgetRecutKeepsThem() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let record = try await Self.seed(dependencies, budget: 5_000_000)
        let model = CityRecommendationViewModel()
        await model.restore(dependencies: dependencies)
        let skipped = record.cards[0].cityID
        await model.skip(skipped, dependencies: dependencies)

        await model.applyBudget(4_000_000, dependencies: dependencies)
        #expect(model.skippedCityIDs == [skipped])
        #expect(try await dependencies.store.cityState().skippedCityIDs == [skipped])
        let recut = try #require(model.lastRecord)
        #expect(!model.visibleCards(recut).contains { $0.cityID == skipped })

        // 새 결과를 받으면 같은 저장에서 비운다.
        try await dependencies.store.updateCityState { $0.lastRecord = record; $0.skippedCityIDs = [] }
        #expect(try await dependencies.store.cityState().skippedCityIDs.isEmpty)
    }

    @Test @MainActor func budgetChangeNoticeAndRevertRestoreCondition() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dependencies = AppDependencies(persistence: .inMemory)
        let service = try CityRecommendationServiceTests.service(
            client: CityRecommendationServiceTests.fake(lows: [3_000_000, 2_500_000]), dir: dir
        )
        var request = CityRecommendationServiceTests.request()
        request.budgetMax = 4_000_000
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], excludedCities: [],
            homeCountryExcluded: false, seed: 7
        )
        try await dependencies.store.updateCityState { $0.lastRecord = record }
        let model = CityRecommendationViewModel()
        await model.restore(dependencies: dependencies)
        #expect(model.budgetChange == nil)
        let skipped = record.cards[2].cityID
        await model.skip(skipped, dependencies: dependencies)
        let original = model.visibleCards(record).map(\.cityID)

        // 줄어드는 경우
        await model.applyBudget(2_000_000, dependencies: dependencies)
        #expect(model.budgetChange?.message == "예산을 1인 200만 원 이하로 바꿔 추천 순서를 조정했어요")
        #expect(model.skippedCityIDs == [skipped])
        // 되돌리면 이전 예산과 처음 보이던 카드로 돌아오고, 안내는 사라진다. 넘긴 도시는 그대로다.
        await model.revertBudget(dependencies: dependencies)
        #expect(model.lastRecord?.input.budgetMax == 4_000_000)
        #expect(model.visibleCards(try #require(model.lastRecord)).map(\.cityID) == original)
        #expect(model.budgetChange == nil)
        #expect(model.skippedCityIDs == [skipped])
        #expect(try await dependencies.store.cityState().lastRecord?.input.budgetMax == 4_000_000)

        // 영향이 없는 경우
        await model.applyBudget(5_000_000, dependencies: dependencies)
        #expect(model.budgetChange?.message == "예산을 1인 500만 원 이하로 바꿨어요")
        // 모두 예산을 넘는다고 추정돼도 빼지 않고 순위대로 보여준다(2026-11-06).
        await model.applyBudget(100_000, dependencies: dependencies)
        let tight = try #require(model.lastRecord)
        #expect(tight.budgetCutCityIDs.count == tight.poolCityIDs.count)
        #expect(!model.visibleCards(tight).isEmpty)
    }

    @Test @MainActor func returningToOriginalBudgetRestoresOriginalRecordAndSurvivesRestore() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dependencies = AppDependencies(persistence: .inMemory)
        let service = try CityRecommendationServiceTests.service(
            client: CityRecommendationServiceTests.fake(lows: [3_000_000, 2_500_000]), dir: dir
        )
        var request = CityRecommendationServiceTests.request()
        request.budgetMax = 4_000_000
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], excludedCities: [],
            homeCountryExcluded: false, seed: 7
        )
        #expect(record.understanding != nil)
        try await dependencies.store.updateCityState { $0.lastRecord = record }
        let model = CityRecommendationViewModel()
        await model.restore(dependencies: dependencies)
        let skipped = record.cards[2].cityID
        await model.skip(skipped, dependencies: dependencies)

        // 바꾸면 파생 결과, 복원해도 원본이 남아 있다.
        await model.applyBudget(2_000_000, dependencies: dependencies)
        #expect(model.lastRecord?.derivedFrom == record.id)
        let reopened = CityRecommendationViewModel()
        await reopened.restore(dependencies: dependencies)
        #expect(reopened.originalRecord?.id == record.id)

        // 직접 처음 예산을 입력해도, 되돌려도 원본으로 돌아온다.
        await reopened.applyBudget(4_000_000, dependencies: dependencies)
        #expect(reopened.lastRecord?.id == record.id)
        #expect(reopened.lastRecord?.understanding != nil)
        #expect(reopened.lastRecord?.derivedFrom == nil)
        #expect(reopened.budgetChange == nil)
        #expect(reopened.originalRecord == nil)
        #expect(reopened.skippedCityIDs == [skipped])

        await model.revertBudget(dependencies: dependencies)
        #expect(model.lastRecord?.id == record.id)
        #expect(model.lastRecord?.understanding != nil)
        #expect(model.budgetChange == nil)
        let stored = try await dependencies.store.cityState()
        #expect(stored.lastRecord?.id == record.id)
        #expect(stored.originalRecord == nil)
        let again = CityRecommendationViewModel()
        await again.restore(dependencies: dependencies)
        #expect(again.lastRecord?.derivedFrom == nil)
        #expect(again.lastRecord?.understanding != nil)
    }

    @Test @MainActor func choosingUndecidedBudgetRecutsWithoutBudget() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let dependencies = AppDependencies(persistence: .inMemory)
        let service = try CityRecommendationServiceTests.service(
            client: CityRecommendationServiceTests.fake(lows: [3_000_000, 2_500_000]), dir: dir
        )
        var request = CityRecommendationServiceTests.request()
        request.budgetMax = 2_000_000
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], excludedCities: [],
            homeCountryExcluded: false, seed: 7
        )
        try await dependencies.store.updateCityState { $0.lastRecord = record }
        let model = CityRecommendationViewModel()
        await model.restore(dependencies: dependencies)
        await model.applyBudget(nil, dependencies: dependencies)
        #expect(model.lastRecord?.input.budgetMax == nil)
        #expect(model.lastRecord?.budgetCutCityIDs.isEmpty == true)
        #expect(model.budgetChange?.message.hasPrefix("예산을 미정으로 바꿔") == true)
        #expect(model.canEditBudget)
        await model.revertBudget(dependencies: dependencies)
        #expect(model.lastRecord?.id == record.id)
    }

    @Test func oldCityStateWithoutNewKeysDecodes() throws {
        let state = try JSONDecoder().decode(CityRecommendationState.self, from: Data("{\"saved\":[],\"excluded\":[]}".utf8))
        #expect(state.skippedCityIDs.isEmpty)
        #expect(state.lastRecord == nil)
    }

    @Test func savedAndExcludedCitiesSurviveReopeningTheStore() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let store = SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(url: url), countries: [], tags: [])
            try await store.updateCityState {
                $0.save(Self.card("kyoto"), conditionSummary: "미식 · 11월 · 3박")
                $0.exclude(Self.card("osaka"))
            }
        }
        let reopened = SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(url: url), countries: [], tags: [])
        let state = try await reopened.cityState()
        #expect(state.saved.map(\.id) == ["kyoto"])
        #expect(state.saved.first?.conditionSummary == "미식 · 11월 · 3박")
        #expect(state.saved.first?.card == Self.card("kyoto"))
        #expect(state.excludedCityIDs == ["osaka"])
    }

    @Test func readsOldAndPartialFormats() throws {
        let empty = try JSONDecoder().decode(CityRecommendationState.self, from: Data("{}".utf8))
        #expect(empty == CityRecommendationState())

        var withSaved = CityRecommendationState()
        withSaved.save(Self.card("kyoto"), conditionSummary: "")
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(withSaved)) as? [String: Any])
        object["lastRecord"] = ["unreadable": true]
        object.removeValue(forKey: "excluded")
        let decoded = try JSONDecoder().decode(CityRecommendationState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.saved.map(\.id) == ["kyoto"])
        #expect(decoded.lastRecord == nil)
        #expect(decoded.excluded.isEmpty)
    }

    @Test func recordWithoutExcludedCityKeyStillDecodes() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let record = try await Self.record(dir: dir)
        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(record)) as? [String: Any])
        object.removeValue(forKey: "excludedCityIDs")
        let old = try JSONDecoder().decode(CityRecommendationRecord.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.excludedCityIDs == nil)
        #expect(old.cards == record.cards)
    }

    @Test func deleteAllUserDataRemovesSavedCitiesExclusionsAndLastResult() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let record = try await Self.record(dir: dir)
        let stores: [any AppStore] = [
            SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(inMemory: true), countries: [], tags: []),
            InMemoryAppStore(countries: [], tags: [])
        ]
        for store in stores {
            try await store.updateCityState {
                $0.save(Self.card("kyoto"), conditionSummary: "x")
                $0.exclude(Self.card("osaka"))
                $0.lastRecord = record
            }
            #expect(try await store.cityState().saved.count == 1)
            try await store.deleteAllUserData()
            #expect(try await store.cityState() == CityRecommendationState())
        }
    }

    @Test func saveReplacesSameCityAndUnsaveRemoves() {
        var state = CityRecommendationState()
        state.save(Self.card("kyoto"), conditionSummary: "a")
        state.save(Self.card("kyoto"), conditionSummary: "b")
        #expect(state.saved.count == 1)
        #expect(state.saved[0].conditionSummary == "b")
        state.exclude(Self.card("kyoto"))
        state.release(cityID: "kyoto")
        #expect(state.excluded.isEmpty)
        state.unsave(cityID: "kyoto")
        #expect(state.saved.isEmpty)
    }

    @Test func badgeFollowsRequiredConditionTable() {
        #expect(Self.card("a").badge == nil)
        #expect(Self.card("a", conditions: [Self.condition(.core, .unconfirmed, text: "축제")]).badge == nil)
        #expect(Self.card("a", conditions: [Self.condition(.core, .unconfirmed, text: "축제")]).unconfirmedPreferences == ["축제"])
        let met = Self.card("a", conditions: [Self.condition(.required, .met, text: "직항")])
        #expect(met.badge == .requiredMet(scope: ["직항"]))
        let unconfirmed = Self.card("a", conditions: [Self.condition(.required, .met, text: "직항"), Self.condition(.required, .unconfirmed, text: "5시간")])
        #expect(unconfirmed.badge == .needsCheck(names: ["5시간"]))
        #expect(unconfirmed.needsCheck)
        let violated = Self.card("a", conditions: [Self.condition(.required, .notMet)])
        #expect(violated.violatesRequiredCondition)
    }

    @Test func requestSummaryIsOneLine() {
        var request = RecommendationRequest()
        request.setPrimary(.food)
        request.year = 2026
        request.month = 11
        request.nights = 3
        request.budgetMax = 1_000_000
        #expect(request.summaryText == "미식 · 11월 · 3박 · 1인 100만원 이하")
    }

    /// 기간을 고르지 않으면 미정이다. 예전에는 기본값 3박이 화면에 안 보인 채 요청과 요약에 들어갔다.
    @Test func unsetNightsStayUnknownInSummaryAndLLMRequest() throws {
        var request = RecommendationRequest()
        request.setPrimary(.food)
        request.budgetMax = 1_000_000
        #expect(request.nights == nil)
        #expect(request.summaryText == "미식 · 1인 100만원 이하")

        let (built, _) = try CityLLMRequestTests.makeRequest()
        #expect(built.user.contains("Trip length: undecided"))
        #expect(!built.user.contains("Daily budget"))

        // 저장된 예전 요청: 박 수가 있으면 그대로, 없으면 미정으로 읽는다.
        let decoder = JSONDecoder()
        #expect(try decoder.decode(RecommendationRequest.self, from: Data(#"{"nights":5}"#.utf8)).nights == 5)
        #expect(try decoder.decode(RecommendationRequest.self, from: Data("{}".utf8)).nights == nil)
    }

    // MARK: 저장 실패 처리

    /// 읽기·저장을 골라 실패시키는 저장소. 저장 호출 횟수를 센다.
    final class FlakyRepository: UserProfileRepository, @unchecked Sendable {
        struct Failure: Error {}
        var state = CityRecommendationState()
        var failLoad = false
        var failSave = false
        var saveCalls = 0
        func loadCityState() async throws -> CityRecommendationState {
            if failLoad { throw Failure() }
            return state
        }
        func saveCityState(_ state: CityRecommendationState) async throws {
            saveCalls += 1
            if failSave { throw Failure() }
            self.state = state
        }
        func loadProfile() async throws -> UserProfile? { nil }
        func saveProfile(_ profile: UserProfile) async throws {}
        func loadInterestTagIDs() async throws -> Set<String> { [] }
        func saveInterestTagIDs(_ ids: Set<String>) async throws {}
        func loadWantedTiers() async throws -> WantedConceptTiers? { nil }
        func saveWantedTiers(_ tiers: WantedConceptTiers) async throws {}
        func loadOnboardingDraft() async throws -> OnboardingDraft? { nil }
        func saveOnboardingDraft(_ draft: OnboardingDraft?) async throws {}
    }

    @Test func failedLoadDoesNotWriteAndPropagates() async throws {
        let repo = FlakyRepository()
        repo.state.save(Self.card("kyoto"), conditionSummary: "")
        repo.failLoad = true
        await #expect(throws: FlakyRepository.Failure.self) {
            try await repo.updateCityState { $0.save(Self.card("osaka"), conditionSummary: "") }
        }
        #expect(repo.saveCalls == 0)
        // 읽기가 돌아오면 기존 저장이 그대로 있다.
        repo.failLoad = false
        #expect(repo.state.saved.map(\.id) == ["kyoto"])
    }

    @Test func failedSavePropagatesAndLeavesStoredStateUnchanged() async throws {
        let repo = FlakyRepository()
        repo.state.save(Self.card("kyoto"), conditionSummary: "")
        repo.failSave = true
        var shown = repo.state
        await #expect(throws: FlakyRepository.Failure.self) {
            // 호출자는 성공했을 때만 화면 상태를 바꾼다.
            shown = try await repo.updateCityState { $0.exclude(Self.card("osaka")) }
        }
        #expect(shown.excluded.isEmpty)
        #expect(repo.state.excluded.isEmpty)
        #expect(repo.state.saved.map(\.id) == ["kyoto"])
    }

    // MARK: 저장한 도시의 원래 요청

    @Test func savedCityKeepsItsRequestAndOldRecordsStillDecode() throws {
        var request = CityRecommendationServiceTests.request()
        request.month = 11
        var state = CityRecommendationState()
        state.save(Self.card("kyoto"), conditionSummary: request.summaryText, request: request)
        let decoded = try JSONDecoder().decode(CityRecommendationState.self, from: JSONEncoder().encode(state))
        #expect(decoded.saved.first?.request == request)
        #expect(decoded.saved.first?.summary == request.summaryText)

        var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var saved = try #require(object["saved"] as? [[String: Any]])
        saved[0].removeValue(forKey: "request")
        saved[0]["conditionSummary"] = "예전 요약"
        object["saved"] = saved
        let old = try JSONDecoder().decode(CityRecommendationState.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.saved.first?.request == nil)
        #expect(old.saved.first?.summary == "예전 요약")
    }

    // MARK: 넘기기·제외 뒤 채우기

    @Test func refillTakesNextPoolCityAndNeverReshowsOrExcluded() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = try CityRecommendationServiceTests.service(client: CityRecommendationServiceTests.fake(), dir: dir)
        let record = try await Self.record(dir: dir)
        #expect(record.cards.count == 3)
        let shown = Set(record.cards.map(\.cityID))
        let skipped = record.cards[0].cityID

        // 하나를 넘기면 이미 보여준 도시를 뺀 풀의 코드 순서 다음 도시 하나가 온다.
        let next = try #require(record.poolCityIDs.first { !shown.contains($0) })
        let filled = service.refill(record, count: 1, shown: shown, removedCities: [skipped], removedCountries: [])
        #expect(filled.map(\.cityID) == [next])

        // 다음 후보까지 제외하면 그 도시는 건너뛴다.
        let after = try #require(record.poolCityIDs.first { !shown.contains($0) && $0 != next })
        let skipNext = service.refill(record, count: 1, shown: shown, removedCities: [skipped, next], removedCountries: [])
        #expect(skipNext.map(\.cityID) == [after])

        // 풀이 소진되면 채우지 않는다.
        let exhausted = service.refill(
            record, count: 1, shown: Set(record.poolCityIDs), removedCities: [skipped], removedCountries: []
        )
        #expect(exhausted.isEmpty)
        // 남은 후보가 요청한 수보다 적으면 있는 만큼만 채운다.
        let all = service.refill(record, count: 100, shown: shown, removedCities: [], removedCountries: [])
        #expect(all.count <= record.poolCityIDs.count - shown.count)
        #expect(all.allSatisfy { !shown.contains($0.cityID) })
    }

    /// 저장된 원문에는 후보 밖 카드가 남는다. 같은 id가 두 번 나와도 채우기·예산 재계산이 멈추지 않고 그 도시를 쓰지 않는다.
    @Test func citiesOutsideCandidatesAreDroppedInResultRefillAndRecut() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let client = CityRecommendationServiceTests.fake(extra: ["zz-extra", "zz-extra"])
        let service = try CityRecommendationServiceTests.service(client: client, dir: dir)
        let record = try await service.recommend(
            request: CityRecommendationServiceTests.request(), tiers: WantedConceptTiers(),
            excludedCountries: [], homeCountryExcluded: false, seed: 7
        )
        #expect(record.error == nil)
        #expect(record.cards.count == 3)
        #expect(record.rawResponse?.contains("zz-extra") == true)

        let pool = Set(record.poolCityIDs)
        let filled = service.refill(
            record, count: 100, shown: Set(record.cards.map(\.cityID)), removedCities: [], removedCountries: []
        )
        #expect(!filled.isEmpty)
        let recut = try #require(service.recut(record, budgetMax: 5_000_000))
        #expect((record.cards + filled + recut.cards).allSatisfy { pool.contains($0.cityID) })
    }
}

struct CityConditionTextTests {
    @Test func chipsShowKnownPeriodLengthAndBudget() {
        var request = RecommendationRequest()
        request.month = 11
        request.nights = 3
        request.budgetMax = 1_000_000
        #expect(request.conditionChips == ["11월", "3박 4일", "1인 100만 원 이하"])
    }

    @Test func unknownLengthAndBudgetAreOmittedAndPeriodSaysUndecided() {
        #expect(RecommendationRequest().conditionChips == ["시기 미정"])
    }

    @Test func dateWinsAndGroupBudgetWithoutFlightIsSpelledOut() {
        var request = RecommendationRequest()
        request.startDate = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 5))
        request.nights = 0
        request.budgetBasis = .group
        request.budgetIncludesFlight = false
        request.budgetMax = 2_000_000
        #expect(request.conditionChips == ["12월 5일", "당일", "전체 200만 원 이하 (항공 제외)"])
    }

    @Test func collapsedLineKeepsRequiredConditions() {
        var request = RecommendationRequest()
        request.primary = .food
        request.month = 11
        request.nights = 3
        #expect(request.collapsedLine(required: ["비행 5시간 이내"]) == "미식 · 11월 3박 4일 · 필수: 비행 5시간 이내")
        #expect(request.collapsedLine(required: []) == "미식 · 11월 3박 4일")
        #expect(RecommendationRequest().collapsedLine(required: ["비행 5시간 이내"]) == "필수: 비행 5시간 이내")
    }

    @Test func understandingSeenDefaultsToFalseForOldState() throws {
        let state = try JSONDecoder().decode(CityRecommendationState.self, from: Data("{}".utf8))
        #expect(!state.understandingSeen)
    }
}
