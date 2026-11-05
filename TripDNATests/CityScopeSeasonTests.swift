import Foundation
import Testing
@testable import TripDNA

struct CityScopeSeasonTests {
    @Test func confirmedSceneryStillDisclosesUnavailableActivities() throws {
        var city = City(id: "sample", ko: "샘플", en: "Sample", country: "XX",
                        grades: ["scenery": .choose, "winter": .choose, "water": .makeTime],
                        season: ["winter": [6, 7, 8]], seasonUnverified: ["water"])
        city.scope = "도심과 호수. 먼 산 제외"
        let catalog = CityCatalog(version: "test", concepts: ["nature": ["scenery"], "activities": ["winter", "water"]], cities: [city])
        var request = RecommendationRequest()
        request.primary = .natureScenery
        request.month = 1
        let ranked = CityRanker.rank(catalog: catalog, input: .init(primary: .natureScenery, month: 1))
        #expect(ranked.first?.status == .confirmed)
        let built = CityLLMRequestBuilder.build(context: .init(request: request, tiers: .init(), catalog: catalog, model: "test", excludedCountries: [], homeCountryExcluded: false), ranked: ranked, excludedRanked: [], pool: ranked)
        #expect(built.user.contains(city.scope!))
        #expect(built.user.contains("out of season: winter; unverified: water"))
        let legacy = "{\"id\":\"old\",\"ko\":\"옛\",\"en\":\"Old\",\"country\":\"XX\",\"grades\":{},\"season\":{},\"seasonUnverified\":[]}"
        #expect(try JSONDecoder().decode(City.self, from: Data(legacy.utf8)).scope == nil)
    }

    @Test func bundledScopesArePresent() throws {
        let catalog = try #require(CityCatalog.load(bundle: Bundle(for: BundleToken.self)) ?? CityCatalog.load())
        #expect(catalog.cities.count == 103)
        #expect(catalog.cities.allSatisfy { !($0.scope ?? "").isEmpty })
    }
    @Test func everyCatalogCityHasBundledPhoto() throws {
        let catalog = try #require(CityCatalog.load(bundle: Bundle(for: BundleToken.self)) ?? CityCatalog.load())
        let missing = catalog.cities.map(\.id).filter { CityPhoto.image(for: $0) == nil }
        #expect(missing.isEmpty, "사진 없는 도시: \(missing)")
    }
    @Test func cairnsWaterIsAvailableInBothHemisphericSeasons() throws {
        let bundle = try #require(CityCatalog.load())
        let cairns = try #require(bundle.cities.first { $0.id == "au-cairns" })
        let waterOnly = CityCatalog(version: bundle.version, concepts: ["activities": ["water"]], cities: [cairns])
        for month in [1, 7] {
            let ranked = CityRanker.rank(catalog: waterOnly, input: .init(primary: .activities, month: month))
            #expect(ranked.first?.status == .confirmed)
            #expect(ranked.first?.primaryGrade == .choose)
        }
    }
    private final class BundleToken {}
}
