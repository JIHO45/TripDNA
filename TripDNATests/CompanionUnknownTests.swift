import Foundation
import Testing
@testable import TripDNA

struct CompanionUnknownTests {
    @Test func unknownCompanionRoundTripsAndOlderValuesDecodeUnchanged() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let leg = try TripLeg(countryCode: "JP", startDate: date, endDate: date)
        let trip = try Trip(legs: [leg], companion: .unknown, purpose: .leisure)
        let decoded = try JSONDecoder().decode(Trip.self, from: JSONEncoder().encode(trip))
        #expect(decoded.companion == .unknown)
        #expect(Companion.unknown.labelKo.isEmpty)
        for raw in ["alone", "couple", "family", "friends"] {
            #expect(Companion(rawValue: raw) != nil)
        }
    }

    @Test func evaluationWithoutOverallAnswersIsAccepted() throws {
        let review = CityReview(countryCode: "JP", city: "교토", rating: 4, liked: nil, disliked: nil)
        let evaluation = try TripEvaluation(satisfaction: nil, wouldRepeat: nil, cityReviews: [review], source: .postTrip)
        #expect(evaluation.cityReviews?.count == 1)
        #expect(throws: DomainValidationError.self) {
            try TripEvaluation(satisfaction: 9, wouldRepeat: nil, source: .postTrip)
        }
    }
}
