import Foundation
import Testing
@testable import TripDNA

struct BudgetCurrencyTests {
    @Test func resolvesFromHomeCountry() {
        #expect(BudgetCurrency.resolve(homeCountryCode: "KR") == "KRW")
        #expect(BudgetCurrency.resolve(homeCountryCode: "US") == "USD")
        #expect(BudgetCurrency.resolve(homeCountryCode: "JP") == "JPY")
        #expect(BudgetCurrency.resolve(homeCountryCode: "DE") == "EUR")
        // 목록에 없는 통화(브라질 BRL)와 알 수 없는 코드는 USD.
        #expect(BudgetCurrency.resolve(homeCountryCode: "BR") == "USD")
        #expect(BudgetCurrency.resolve(homeCountryCode: "ZZ") == "USD")
    }

    @Test func krwPresetsAreUnchangedAndOthersExist() {
        #expect(BudgetCurrency.presets(for: "KRW") == [500_000, 1_000_000, 1_500_000])
        #expect(BudgetCurrency.presets(for: "XXX") == BudgetCurrency.presets(for: "USD"))
        for code in ["USD", "EUR", "GBP", "JPY", "CNY", "TWD", "HKD", "SGD", "AUD", "CAD", "THB"] {
            #expect(BudgetCurrency.presets[code]?.count == 3)
        }
    }

    @Test func oldPayloadDecodesAsKRW() throws {
        let json = #"{"budgetMaxKRW":1500000,"budgetBasis":"group","partySize":2}"#
        let request = try JSONDecoder().decode(RecommendationRequest.self, from: Data(json.utf8))
        #expect(request.budgetMax == 1_500_000)
        #expect(request.budgetCurrency == "KRW")
        #expect(request.budgetBasis == .group)
        var usd = request
        usd.budgetCurrency = "USD"
        let encoded = try JSONEncoder().encode(usd)
        #expect(String(decoding: encoded, as: UTF8.self).contains("\"budgetMaxKRW\":1500000"))
        #expect(try JSONDecoder().decode(RecommendationRequest.self, from: encoded).budgetCurrency == "USD")
    }

    @Test func formatsMoney() {
        #expect(BudgetCurrency.format(1_500_000, currency: "KRW", koreanUnit: "만 원") == shortKRW(1_500_000, koreanUnit: "만 원"))
        if AppLanguage.isKorean { #expect(BudgetCurrency.format(1_500_000, currency: "KRW", koreanUnit: "만 원") == "150만 원") }
        let usd = BudgetCurrency.format(1_000, currency: "USD", koreanUnit: "만 원")
        #expect(usd.contains("1,000") && usd.contains("$"))
    }

    // MARK: 프롬프트

    private func build(_ budget: Int?, currency: String, basis: CityCostBasis?) -> CityLLMRequest {
        let city = City(id: "sample", ko: "샘플", en: "Sample", country: "XX", grades: ["scenery": .choose], season: [:], seasonUnverified: [])
        let catalog = CityCatalog(version: "test", concepts: ["nature": ["scenery"]], cities: [city])
        var request = RecommendationRequest()
        request.primary = .natureScenery
        request.month = 3
        request.nights = 4
        request.budgetMax = budget
        request.budgetCurrency = currency
        let ranked = CityRanker.rank(catalog: catalog, input: .init(primary: .natureScenery, month: 3))
        return CityLLMRequestBuilder.build(
            context: .init(request: request, tiers: .init(), catalog: catalog, model: "test", excludedCountries: [], homeCountryExcluded: false, costBasis: basis),
            ranked: ranked, excludedRanked: [], pool: ranked
        )
    }

    @Test func krwKoreaPromptKeepsLegacyTextAndVersion() {
        for basis in [nil, CityCostBasis(currency: "KRW", airport: "ICN", homeCountry: "KR"), CityCostBasis(currency: "KRW", homeCountry: "KR")] {
            let built = build(1_500_000, currency: "KRW", basis: basis)
            #expect(built.system == CityLLMOutputLanguage.apply(to: CityLLMRequestBuilder.system, textFields: "understanding, reason, caveat, how"))
            #expect(built.user.contains("Budget: max 1500000 KRW (per person, flights included)"))
            #expect(built.user.contains("Daily budget (budget ÷ nights, simple division): about 375000 KRW"))
            #expect(!built.user.contains("Flight origin"))
            #expect(built.version.prompt == CityInputVersion.currentPromptVersion)
            #expect(!built.version.prompt.hasSuffix("-cur"))
        }
    }

    @Test func nonKRWPromptStatesCurrencyAndDeparture() {
        let built = build(1_000, currency: "USD", basis: CityCostBasis(currency: "USD", airport: "JFK", homeCountry: "US"))
        #expect(built.system.contains("integers in USD"))
        #expect(built.system.contains("JFK"))
        #expect(!built.system.contains("integers in KRW") && !built.system.contains("departing from Korea"))
        #expect(built.user.contains("max 1000 USD"))
        #expect(built.user.contains("Flight origin: JFK"))
        #expect(built.version.prompt.hasSuffix("-cur"))
        // KRW여도 출발지가 한국이 아니면 달라진다.
        let jp = build(1_500_000, currency: "KRW", basis: CityCostBasis(currency: "KRW", airport: "NRT", homeCountry: "KR"))
        #expect(jp.version.prompt.hasSuffix("-cur") && jp.user.contains("NRT"))
    }

    @Test func budgetCutUsesRequestCurrencyAmounts() {
        // 예산 비교는 금액만 보므로 요청과 같은 통화로 낸 비용이면 통화와 무관하게 같은 규칙이다. 넘어도 빼지 않는다.
        let a = City(id: "a", ko: "에이", en: "A", country: "XX", grades: ["scenery": .choose], season: [:], seasonUnverified: [])
        let ranked = CityRanker.rank(catalog: CityCatalog(version: "t", concepts: ["nature": ["scenery"]], cities: [a]), input: .init(primary: .natureScenery))
        let response = CityLLMResponse(understanding: "u", cards: [.init(id: "a", reason: "r", caveat: "", cost: .init(low: 1_200, high: 2_000))])
        let over = CityRecommendationService.select(pool: ranked, response: response, budget: 1_000, seed: 1)
        #expect(over.overBudgetIDs == ["a"])
        #expect(over.cards.map(\.cityID) == ["a"])
        #expect(CityRecommendationService.select(pool: ranked, response: response, budget: 1_500, seed: 1).overBudgetIDs.isEmpty)
    }
}
