import Foundation
import Testing
@testable import TripDNA

struct AffiliateLinkTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func plannedTripActivityLinkUsesCityDdayAndSubID() throws {
        let store = InMemoryAppStore()
        let service = AffiliateLinkService(events: store, calendar: calendar)
        let leg = try TripLeg(
            countryCode: "JP",
            cities: ["도쿄", "오사카"],
            startDate: date(2026, 7, 15),
            endDate: date(2026, 7, 20)
        )
        let trip = try Trip(
            id: "planned",
            legs: [leg],
            companion: .alone,
            purpose: .leisure,
            createdAt: date(2026, 7, 1)
        )

        let links = service.links(for: trip, now: date(2026, 7, 1))
        let first = try #require(links.first)
        let redirect = try #require(URLComponents(url: first.url, resolvingAgainstBaseURL: false))
        let items = try #require(redirect.queryItems)
        let target = try #require(items.first { $0.name == "k_site" }?.value)
        let targetItems = try #require(URLComponents(string: target)?.queryItems)

        #expect(links.map(\.city) == ["도쿄", "오사카"])
        #expect(first.subID.hasPrefix("trip_d14_JP_"))
        #expect(!first.subID.contains(" "))
        #expect(redirect.host == "affiliate.klook.com")
        #expect(items.first { $0.name == "aid" }?.value == "141494")
        #expect(items.first { $0.name == "aff_adid" }?.value == "1535734")
        // 대시보드 링크처럼 k_site 안의 :/?=는 모두 인코딩돼야 한다.
        #expect(redirect.percentEncodedQuery?.contains("k_site=https%3A%2F%2Fwww.klook.com%2Fko%2Fsearch%2Fresult%2F%3Fquery%3D") == true)
        #expect(targetItems.first { $0.name == "query" }?.value == "도쿄 things to do")
        #expect(first.isAffiliateActive)
    }

    @Test func inactiveConfigurationLinksStraightToSearchWithoutPartnerID() throws {
        let configuration = AffiliateProviderConfiguration(
            providerName: "Klook",
            searchBaseURL: try #require(URL(string: "https://www.klook.com/ko/search/result/")),
            redirectURL: try #require(URL(string: "https://affiliate.klook.com/redirect")),
            partnerID: nil,
            tripAdID: "1",
            recommendationAdID: "2"
        )
        let service = AffiliateLinkService(events: InMemoryAppStore(), configuration: configuration)
        let recommendation = Recommendation(
            countryCode: "JP", slot: .bestMatch, matchScore: 0.8,
            explanationTagIDs: [], rankingAnchorTripID: nil, fitBadges: [], notices: []
        )
        let first = try #require(service.links(for: recommendation).first)
        let items = try #require(URLComponents(url: first.url, resolvingAgainstBaseURL: false)?.queryItems)

        #expect(first.url.host == "www.klook.com")
        #expect(items.map(\.name) == ["query"])
        #expect(!first.isAffiliateActive)
    }

    @Test func recommendationActivityLinksUseExplanationTagsWithoutChangingRecommendation() throws {
        let store = InMemoryAppStore()
        let service = AffiliateLinkService(events: store)
        let recommendation = Recommendation(
            countryCode: "JP",
            slot: .bestMatch,
            matchScore: 0.91,
            explanationTagIDs: ["food", "history"],
            rankingAnchorTripID: nil,
            fitBadges: [],
            notices: []
        )

        let links = service.links(for: recommendation)
        let first = try #require(links.first)
        let queryItems = try #require(URLComponents(url: first.url, resolvingAgainstBaseURL: false)?.queryItems)

        #expect(links.map(\.city) == ["Tokyo", "Osaka", "Kyoto"])
        #expect(links.map(\.category) == [.food, .history, .food])
        #expect(first.subID == "rec_bestmatch_JP_tokyo")
        #expect(queryItems.first { $0.name == "aid" }?.value == "141494")
        #expect(queryItems.first { $0.name == "aff_adid" }?.value == "1535735")
        #expect(first.isAffiliateActive)
        #expect(recommendation.matchScore == 0.91)
    }

    @Test func affiliateClickIsRecordedLocallyWithAttributionContext() async throws {
        let store = InMemoryAppStore()
        let service = AffiliateLinkService(events: store)
        let recommendation = Recommendation(
            countryCode: "TH",
            slot: .freshStretch,
            matchScore: 0.73,
            explanationTagIDs: ["wellness"],
            rankingAnchorTripID: nil,
            fitBadges: [],
            notices: []
        )
        let link = try #require(service.links(for: recommendation).first)

        try await service.recordClick(link, at: date(2026, 7, 1))
        let event = try #require(try await store.events().last)

        #expect(event.type == .slotClick)
        #expect(event.payload["clickType"] == "affiliate")
        #expect(event.payload["entryPoint"] == "recommendation")
        #expect(event.payload["countryCode"] == "TH")
        #expect(event.payload["city"] == "Bangkok")
        #expect(event.payload["category"] == "wellness")
        #expect(event.payload["subID"] == link.subID)
        #expect(event.payload["affiliateActive"] == "true")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func unsupportedCountryHasNoActivityLinks() {
        let service = AffiliateLinkService(events: InMemoryAppStore())
        let recommendation = Recommendation(
            countryCode: "ZZ", slot: .bestMatch, matchScore: 0.8,
            explanationTagIDs: [], rankingAnchorTripID: nil, fitBadges: [], notices: []
        )
        #expect(service.links(for: recommendation).isEmpty)
    }

    @Test @MainActor func registrationAndEditingPreserveCitiesAcrossLegs() async throws {
        let dependencies = AppDependencies(persistence: .inMemory, affiliateActivitiesEnabled: false)
        let registration = TripRegistrationViewModel(prefilledCountryCode: "JP")
        registration.legs[0].cityText = " Tokyo, , Osaka "
        registration.legs.append(TripLegDraft(countryCode: "TH", cities: ["Bangkok"]))
        await registration.submit(dependencies)
        let trip = try #require(await dependencies.allTrips().first)
        #expect(trip.legs.map(\.cities) == [["Tokyo", "Osaka"], ["Bangkok"]])
        let editing = TripRegistrationViewModel(editing: trip)
        #expect(editing.legs[0].cities == ["Tokyo", "Osaka"])
        editing.legs[0].cityText = "Kyoto"
        await editing.submit(dependencies)
        let updated = try #require(await dependencies.allTrips().first)
        #expect(updated.id == trip.id)
        #expect(updated.legs.map(\.cities) == [["Kyoto"], ["Bangkok"]])
    }
}
