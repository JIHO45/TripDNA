import Foundation
import SwiftData
import Testing
@testable import TripDNA

struct ConceptAndCityReviewTests {
    private let past = Date().addingTimeInterval(-30 * 24 * 60 * 60)

    private func leg(_ code: String, _ cities: [String] = [], at date: Date? = nil) throws -> TripLeg {
        let start = date ?? past
        return try TripLeg(countryCode: code, cities: cities, startDate: start, endDate: start)
    }

    private func leisure(_ primary: TripConcept, _ secondary: [TripConcept] = [], at date: Date? = nil) throws -> Trip {
        try Trip(legs: [leg("JP", at: date)], companion: .alone, purpose: .leisure,
                 concepts: TripConcepts(primary: primary, secondary: secondary))
    }

    // MARK: 컨셉

    @Test func conceptIDsMatchVocabularyV1PlusEvent() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("data/experience-categories.json")
        struct File: Decodable { struct Category: Decodable { let id: String; let label_ko: String }; let version: Int; let categories: [Category] }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        #expect(file.version == 1)
        #expect(file.categories.map(\.id) + ["event"] == TripConcept.allCases.map(\.rawValue))
        for category in file.categories {
            #expect(TripConcept(rawValue: category.id)?.labelKo == category.label_ko)
        }
    }

    @Test func conceptsRejectInvalidSecondary() {
        #expect(throws: DomainValidationError.invalidConcepts) {
            try TripConcepts(primary: .food, secondary: [.shopping, .nightlife, .event])
        }
        #expect(throws: DomainValidationError.invalidConcepts) {
            try TripConcepts(primary: .food, secondary: [.food])
        }
        #expect(throws: DomainValidationError.invalidConcepts) {
            try TripConcepts(primary: .food, secondary: [.event, .event])
        }
    }

    @Test func obligationTripCannotHaveConcepts() throws {
        #expect(throws: DomainValidationError.invalidConcepts) {
            try Trip(legs: [leg("JP")], companion: .alone, purpose: .obligation,
                     concepts: TripConcepts(primary: .food))
        }
        var trip = try leisure(.food)
        #expect(throws: DomainValidationError.invalidConcepts) {
            try trip.updateDetails(legs: trip.legs, companion: .alone, purpose: .obligation,
                                   concepts: trip.concepts)
        }
        #expect(trip.concepts?.primary == .food)
        try trip.updateDetails(legs: trip.legs, companion: .alone, purpose: .obligation, concepts: nil)
        #expect(trip.concepts == nil)
    }

    // MARK: 지문

    @Test func fingerprintCountsPrimaryConceptsAndKeepsTies() throws {
        let obligation = try Trip(legs: [leg("JP")], companion: .family, purpose: .obligation)
        let future = try leisure(.shopping, at: Date().addingTimeInterval(30 * 24 * 60 * 60))
        let trips = [
            try leisure(.food, [.shopping]),
            try leisure(.relaxation),
            try leisure(.food),
            try leisure(.relaxation, [.food]),
            try leisure(.event),
            obligation,
            future
        ]
        let fingerprint = try #require(ConceptFingerprint(trips: trips))
        #expect(fingerprint.top == [.food, .relaxation])
        #expect(fingerprint.entries.map(\.concept) == [.food, .relaxation, .event])
        #expect(fingerprint.entries.map(\.count) == [2, 2, 1])
    }

    @Test func fingerprintIsEmptyWithoutCountableTrips() throws {
        #expect(ConceptFingerprint(trips: []) == nil)
        let obligation = try Trip(legs: [leg("JP")], companion: .family, purpose: .obligation)
        let legacy = try Trip(legs: [leg("JP")], companion: .alone, purpose: .leisure)
        #expect(ConceptFingerprint(trips: [obligation, legacy]) == nil)
    }

    // MARK: 도시별 평가

    @Test func reviewTargetsKeepCountryOnlyLegsAndDeduplicate() throws {
        let trip = try Trip(
            legs: [leg("JP", ["도쿄", "오사카"]), leg("KR"), leg("JP", ["도쿄"])],
            companion: .alone, purpose: .leisure
        )
        #expect(trip.reviewTargets.map(\.countryCode) == ["JP", "JP", "KR"])
        #expect(trip.reviewTargets.map(\.city) == ["도쿄", "오사카", nil])
    }

    @Test func cityReviewMustBelongToTripAndHaveValidRating() throws {
        #expect(throws: DomainValidationError.invalidCityReview) {
            try TripEvaluation(satisfaction: 4, wouldRepeat: true,
                               cityReviews: [CityReview(countryCode: "JP", city: "도쿄", rating: 6)],
                               source: .postTrip)
        }
        var trip = try Trip(legs: [leg("JP", ["도쿄"])], companion: .alone, purpose: .leisure)
        try trip.end(at: past)
        let foreign = try TripEvaluation(satisfaction: 4, wouldRepeat: true,
                                         cityReviews: [CityReview(countryCode: "FR", city: "파리", rating: 5)],
                                         source: .postTrip)
        #expect(throws: DomainValidationError.invalidCityReview) { try trip.submit(foreign) }
    }

    @Test func conceptsAndCityReviewsPersistAndLegacyPayloadDecodes() async throws {
        let container = try SwiftDataAppStore.makeContainer(inMemory: true)
        let store = SwiftDataAppStore(container: container, countries: [], tags: [])
        var trip = try Trip(legs: [leg("JP", ["도쿄"])], companion: .alone, purpose: .leisure,
                            concepts: TripConcepts(primary: .food, secondary: [.shopping]))
        try trip.end(at: past)
        try trip.submit(TripEvaluation(
            satisfaction: 5, wouldRepeat: true, positiveTagIDs: ["food"],
            cityReviews: [CityReview(countryCode: "JP", city: "도쿄", rating: 5, liked: "라멘", disliked: nil)],
            source: .postTrip
        ))
        try await store.create(trip)
        let reopened = SwiftDataAppStore(container: container, countries: [], tags: [])
        #expect(try await reopened.trip(id: trip.id) == trip)

        // 컨셉·도시 평가가 생기기 전의 저장 형식(두 키가 없는 JSON)도 그대로 읽힌다.
        var legacy = try Trip(legs: [leg("JP")], companion: .alone, purpose: .leisure)
        try legacy.end(at: past)
        try legacy.submit(TripEvaluation(satisfaction: 3, wouldRepeat: false,
                                         positiveTagIDs: ["food"], source: .postTrip))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any]
        #expect(json?["concepts"] == nil)
        #expect((json?["evaluation"] as? [String: Any])?["cityReviews"] == nil)
        let decoded = try JSONDecoder().decode(Trip.self, from: JSONSerialization.data(withJSONObject: json!))
        #expect(decoded.evaluation?.positiveTagIDs == ["food"])
        #expect(decoded.evaluation?.cityReviews == nil)
    }

    @Test @MainActor func revisingEvaluationKeepsOldTagsAndSavesCityMemos() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        var trip = try Trip(legs: [leg("JP", ["도쿄"])], companion: .alone, purpose: .leisure)
        try trip.end(at: past)
        try trip.submit(TripEvaluation(satisfaction: 4, wouldRepeat: true,
                                       positiveTagIDs: ["food"], negativeTagIDs: ["crowded"],
                                       source: .postTrip), at: past)
        try await dependencies.store.create(trip)

        let viewModel = EvaluationViewModel()
        await viewModel.load(tripID: trip.id, dependencies: dependencies)
        #expect(viewModel.flowSteps.last == .cityReview(0))
        viewModel.cityReviews[0].rating = 5
        viewModel.cityReviews[0].liked = "  골목 산책  "
        viewModel.cityReviews[0].disliked = "   "
        await viewModel.submit(dependencies: dependencies, session: SessionStore())

        let saved = try #require(await dependencies.store.trip(id: trip.id)?.evaluation)
        #expect(saved.positiveTagIDs == ["food"])
        #expect(saved.negativeTagIDs == ["crowded"])
        #expect(saved.cityReviews == [CityReview(countryCode: "JP", city: "도쿄", rating: 5, liked: "골목 산책", disliked: nil)])
    }
}
