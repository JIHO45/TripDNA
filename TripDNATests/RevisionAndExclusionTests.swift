import Foundation
import Testing
@testable import TripDNA

struct RevisionAndExclusionTests {
    @Test @MainActor func revisingEvaluationKeepsLedgerOrderAndUpdatesAnswers() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let end = Date().addingTimeInterval(-5 * 24 * 60 * 60)
        let leg = try TripLeg(countryCode: "JP", startDate: end.addingTimeInterval(-3 * 24 * 60 * 60), endDate: end)
        var trip = try Trip(legs: [leg], companion: .alone, purpose: .leisure)
        try trip.end(at: end)
        try await dependencies.store.create(trip)
        _ = try await dependencies.evaluationService.submit(
            tripID: trip.id,
            evaluation: try TripEvaluation(satisfaction: 2, wouldRepeat: false, source: .postTrip),
            userID: "user",
            at: end
        )
        let submitted = try #require(await dependencies.store.trip(id: trip.id))

        _ = try await dependencies.evaluationService.revise(
            tripID: trip.id,
            evaluation: try TripEvaluation(
                satisfaction: 5, wouldRepeat: true, positiveTagIDs: ["food"], source: .postTrip
            ),
            userID: "user"
        )

        let revised = try #require(await dependencies.store.trip(id: trip.id))
        #expect(revised.status == .evaluated)
        #expect(revised.evaluation?.satisfaction == 5)
        #expect(revised.evaluation?.positiveTagIDs == ["food"])
        #expect(revised.evaluatedAt == submitted.evaluatedAt)
    }

    @Test func revisingRequiresSubmittedEvaluation() throws {
        let date = Date(timeIntervalSince1970: 1_780_000_000)
        var trip = try Trip(
            legs: [TripLeg(countryCode: "JP", startDate: date, endDate: date)],
            companion: .alone,
            purpose: .leisure
        )
        try trip.end(at: date)
        #expect(throws: DomainValidationError.self) {
            try trip.revise(try TripEvaluation(satisfaction: 4, wouldRepeat: true, source: .postTrip))
        }
    }

    @Test @MainActor func evaluationReplayStartsFromStoredQuizPrior() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let prior = TasteAxes(natureUrban: 0.6, energyLevel: -0.4, planningStyle: 0.3, socialMode: -0.5, noveltyAppetite: 0.2)
        try await dependencies.store.saveTastePrior(prior)
        let end = Date(timeIntervalSince1970: 1_780_000_000)
        let leg = try TripLeg(countryCode: "JP", startDate: end.addingTimeInterval(-86_400), endDate: end)
        var trip = try Trip(legs: [leg], companion: .alone, purpose: .leisure)
        try trip.end(at: end)
        try await dependencies.store.create(trip)

        let submitted = try await dependencies.evaluationService.submit(
            tripID: trip.id,
            evaluation: try TripEvaluation(satisfaction: 4, wouldRepeat: true, source: .postTrip),
            userID: "user",
            at: end
        )
        let fromPrior = try await dependencies.evaluationService.recompute(
            userID: "user", trigger: "test", prior: prior, now: end
        )
        let fromZero = try await dependencies.evaluationService.recompute(
            userID: "user", trigger: "test", prior: .zero, now: end
        )

        #expect(submitted.vector.axes == fromPrior.vector.axes)
        #expect(submitted.vector.axes != fromZero.vector.axes)
    }

    @Test func notInterestedExcludesUntilRevoked() async throws {
        let store = InMemoryAppStore(countries: [
            profile(code: "JP", natureUrban: 0.8),
            profile(code: "TH", natureUrban: -0.8),
            profile(code: "FR", natureUrban: 0.2)
        ])
        let service = RecommendationService(countries: store, feedbackRepository: store, events: store)
        let vector = UserTasteVector(
            userID: "user",
            axes: TasteAxes(natureUrban: 0.8, energyLevel: 0, planningStyle: 0, socialMode: 0, noveltyAppetite: 0),
            confidence: TasteAxes(natureUrban: 0.8, energyLevel: 0, planningStyle: 0, socialMode: 0, noveltyAppetite: 0),
            ledgerVersion: 1,
            recomputedAt: .now
        )
        let dislikedAt = Date(timeIntervalSince1970: 1_780_000_000)
        _ = try await service.applyFeedback(
            countryCode: "JP", slot: .bestMatch, action: .dislike, at: dislikedAt
        )

        let twoYearsLater = dislikedAt.addingTimeInterval(730 * 24 * 60 * 60)
        let whileExcluded = try await service.generateThreeSlots(
            vector: vector, interestTagIDs: [], visitedCountryCodes: [], now: twoYearsLater
        )
        #expect(!whileExcluded.contains { $0.countryCode == "JP" })
        #expect(try await service.activeDislikes(now: twoYearsLater).map(\.countryCode) == ["JP"])

        try await service.revokeDislike(countryCode: "JP", at: twoYearsLater)
        let afterRevoke = try await service.generateThreeSlots(
            vector: vector, interestTagIDs: [], visitedCountryCodes: [], now: twoYearsLater
        )
        #expect(afterRevoke.contains { $0.countryCode == "JP" })
        #expect(try await service.activeDislikes(now: twoYearsLater).isEmpty)
    }

    private func profile(code: String, natureUrban: Double) -> CountryProfile {
        CountryProfile(
            countryCode: code,
            name: code,
            nameKo: code,
            status: .confirmed,
            tasteCore: TasteAxes(natureUrban: natureUrban, energyLevel: 0, planningStyle: 0, socialMode: 0, noveltyAppetite: 0),
            matchingAxes: [.natureUrban],
            interestTags: ["food": 0.5],
            constraints: CountryConstraints(cost: 0.5, climate: 0.5),
            popularity: 0.5
        )
    }
}

struct HomeCountryExclusionTests {
    @Test @MainActor func homeCountryIsExcludedByDefaultAndIncludedOnRequest() async {
        let dependencies = AppDependencies(persistence: .inMemory)
        #expect(dependencies.excludedCountryCodes(visited: ["JP"]) == ["JP"])

        await dependencies.setHomeCountryCode("KR")
        #expect(dependencies.excludedCountryCodes(visited: ["JP"]) == ["JP", "KR"])
        #expect(dependencies.excludedCountryCodes(visited: ["JP"], includingHomeCountry: true) == ["JP"])
    }
}
