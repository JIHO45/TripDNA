import Foundation
import Testing
@testable import TripDNA

struct RecommendationRequestTests {
    @Test func mainConceptIsRequired() {
        var request = RecommendationRequest()
        #expect(!request.isReady)
        request.toggleSecondary(.food)
        #expect(!request.isReady)
        request.setPrimary(.natureScenery)
        #expect(request.isReady)
    }

    @Test func secondaryRules() {
        var request = RecommendationRequest()
        request.setPrimary(.food)
        request.toggleSecondary(.food)
        request.toggleSecondary(.event)
        request.toggleSecondary(.shopping)
        request.toggleSecondary(.nightlife)
        #expect(request.secondary == [.event, .shopping])
        request.setPrimary(.event)
        #expect(request.secondary == [.shopping])
    }

    @Test func sameMonthAgainMeansUndecided() {
        var request = RecommendationRequest()
        request.toggleMonth(2027, 2)
        #expect(request.month == 2 && request.year == 2027)
        request.toggleMonth(2027, 2)
        #expect(request.month == nil && request.year == nil)
    }

    @Test func roundTripsAndDecodesWithDefaults() throws {
        var request = RecommendationRequest()
        request.setPrimary(.food)
        request.partySize = 2
        request.budgetMax = 1_000_000
        request.budgetBasis = .group
        request.wants = "비행 5시간 이내"
        let decoded = try JSONDecoder().decode(RecommendationRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded == request)
        let empty = try JSONDecoder().decode(RecommendationRequest.self, from: Data("{}".utf8))
        #expect(empty.primary == nil && empty.includeVisited && !empty.includeHomeCountry)
    }
}
