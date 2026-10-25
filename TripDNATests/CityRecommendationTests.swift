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

    @Test func requestHasGradeNamesSeasonUnverifiedAndExcludedMarksOnly() throws {
        let (request, catalog) = try Self.makeRequest(note: "축제 위주로")
        #expect(request.version.catalog == catalog.version)
        #expect(request.version.prompt == CityInputVersion.promptVersion)
        #expect(request.version.model == "m")
        #expect(request.cardIDs.count == CityLLMRequestBuilder.poolSize)
        #expect(!request.requiresCost)
        #expect(request.user.contains("<<<축제 위주로>>>"))
        #expect(request.user.contains("제외됨"))
        #expect(request.user.contains("시즌 확인 필요("))
        #expect(CityGrade.allNames.contains { request.user.contains($0) })
        #expect(request.system.contains("단정하지"))
        #expect(request.system.contains("확인이 필요"))
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
    static func fake(
        lows: [Int] = [], withCost: Bool = true, extraction: String = "{\"conditions\":[]}", memoriesUsed: String = "[]"
    ) -> Fake {
        Fake { user in
            if user.contains("[고른 컨셉]") { return extraction }
            let ids = user.components(separatedBy: "[후보 도시")[1]
                .components(separatedBy: "\n\n")[0]
                .components(separatedBy: "\n").dropFirst()
                .map { String($0.split(separator: "|")[0]).trimmingCharacters(in: .whitespaces) }
            let cards = ids.enumerated().map { index, id in
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

    @Test func budgetCutsCitiesWhoseLowEstimateExceedsBudget() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = Self.request()
        request.budgetMaxKRW = 2_000_000
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

    @Test func allCutLeavesNoCardsAndIsLogged() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = Self.request()
        request.budgetMaxKRW = 500_000
        let service = try Self.service(client: Self.fake(lows: Array(repeating: 9_000_000, count: 8)), dir: dir)
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false
        )
        #expect(record.cards.isEmpty)
        #expect(record.error == "noneWithinBudget")
        #expect(CityRecommendationLog(directory: dir).load().first?.budgetCutCityIDs.count == 8)
    }

    @Test func recutChangesBudgetWithoutCallingLLM() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = Self.request()
        request.budgetMaxKRW = 2_000_000
        // 순위 1·2번째 하한 3,000,000·2,500,000, 나머지 1,000,000.
        let service = try Self.service(client: Self.fake(lows: [3_000_000, 2_500_000]), dir: dir)
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false, seed: 5
        )
        #expect(record.budgetCutCityIDs.count == 2)
        // 클라이언트가 없는 서비스로도 다시 계산된다 = LLM을 부르지 않는다.
        let offline = try Self.service(client: nil, dir: dir)
        let loosened = try #require(offline.recut(record, budgetMaxKRW: 4_000_000))
        #expect(loosened.budgetCutCityIDs.isEmpty)
        #expect(loosened.derivedFrom == record.id)
        #expect(loosened.input.budgetMaxKRW == 4_000_000)
        #expect(loosened.cards.map(\.cityID).prefix(2) == record.poolCityIDs.prefix(2))
        let tightened = try #require(offline.recut(loosened, budgetMaxKRW: 100_000))
        #expect(tightened.cards.isEmpty)
        #expect(tightened.error == "noneWithinBudget")
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
        #expect(service.recut(record, budgetMaxKRW: 1_000_000) == nil)
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
    static var allNames: [String] { [CityGrade.ifThere, .makeTime, .choose].map(\.nameKo) }
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
        let hike = CityCondition(id: "h", text: "", quote: "q", level: .core, kind: .subconcept, target: "hiking", minGrade: .choose)
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
        // 핵심 선호 하이킹(choose) → 주 컨셉 등급이 낮아도 충족한 도시가 앞선다.
        input.conditions = [CityCondition(id: "h", text: "", quote: "q", level: .core, kind: .subconcept, target: "hiking", minGrade: .choose)]
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
        let extraction = "{\"conditions\":[{\"id\":\"f1\",\"text\":\"미식 중심\",\"quote\":\"맛집 위주\",\"level\":\"core\",\"kind\":\"subconcept\",\"target\":\"dining\",\"min_grade\":\"choose\"},{\"id\":\"x\",\"text\":\"지어낸\",\"quote\":\"본 적 없는 문장\",\"level\":\"required\",\"kind\":\"other\"}]}"
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
        #expect(record.user.contains("[이번 요청에서 뽑은 조건"))
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
        #expect(!record.user.contains("지난 여행 평가 —"))
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
        request.budgetMaxKRW = 2_000_000
        let service = try CityRecommendationServiceTests.service(client: CityRecommendationServiceTests.fake(), dir: dir)
        let record = try await service.recommend(
            request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false, seed: 2
        )
        #expect(record.understanding != nil)
        let derived = try #require(service.recut(record, budgetMaxKRW: 1_500_000))
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
