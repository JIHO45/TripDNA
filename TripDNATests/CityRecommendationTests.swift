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
    static func fake(lows: [Int] = []) -> Fake {
        Fake { user in
            let ids = user.components(separatedBy: "[후보 도시")[1]
                .components(separatedBy: "\n\n")[0]
                .components(separatedBy: "\n").dropFirst()
                .map { String($0.split(separator: "|")[0]).trimmingCharacters(in: .whitespaces) }
            let cards = ids.enumerated().map { index, id in
                let low = index < lows.count ? lows[index] : 1_000_000
                return "{\"id\":\"\(id)\",\"reason\":\"이유\",\"caveat\":\"\",\"cost\":{\"low\":\(low),\"high\":\(low * 2)}}"
            }.joined(separator: ",")
            return "{\"understanding\":\"요약\",\"cards\":[\(cards)]}"
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

    @Test func allCutMeansNoneWithinBudgetAndStillLogged() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var request = Self.request()
        request.budgetMaxKRW = 500_000
        let service = try Self.service(client: Self.fake(lows: Array(repeating: 9_000_000, count: 8)), dir: dir)
        await #expect(throws: CityRecommendationError.noneWithinBudget) {
            _ = try await service.recommend(
                request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false
            )
        }
        let logged = try #require(CityRecommendationLog(directory: dir).load().first)
        #expect(logged.budgetCutCityIDs.count == 8)
    }

    @Test func failedResponseIsStillLoggedWithError() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = try Self.service(client: Fake { _ in "not json" }, dir: dir)
        await #expect(throws: CityRecommendationError.self) {
            _ = try await service.recommend(
                request: Self.request(), tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false
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
