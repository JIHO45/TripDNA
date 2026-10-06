import Foundation
import SwiftData
import Testing
@testable import TripDNA

struct TasteEvidenceTests {
    @Test func visitsComparisonsAndSavesDoNotInventTasteOrConfidence() throws {
        let prior = TasteAxes(natureUrban: 0.2, energyLevel: 0, planningStyle: -0.7,
                              socialMode: 0, noveltyAppetite: 0)
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        var trips: [Trip] = []
        for (index, code) in ["JP", "US", "CA"].enumerated() {
            let day = start.addingTimeInterval(Double(index) * 86_400)
            let leg = try TripLeg(countryCode: code, startDate: day, endDate: day)
            var trip = try Trip(id: code, legs: [leg], companion: .alone,
                                purpose: .leisure, createdAt: day)
            try trip.end(at: day)
            try trip.submit(TripEvaluation(satisfaction: 5, wouldRepeat: true,
                comparison: TripComparison(versusTripID: trips.first?.id, result: .better),
                source: .postTrip), at: day)
            trips.append(trip)
        }
        let countries = ["JP", "US", "CA"].map {
            CountryProfile(countryCode: $0, name: $0, nameKo: $0, status: .confirmed,
                tasteCore: TasteAxes(natureUrban: -0.8, energyLevel: 0.8, planningStyle: 0.9,
                                    socialMode: 0.8, noveltyAppetite: 0),
                matchingAxes: [.natureUrban, .energyLevel, .planningStyle, .socialMode],
                interestTags: [:], constraints: .init(cost: 0.5, climate: 0.5), popularity: 0.5)
        }
        let saves = countries.map { country in
            CardFeedback(id: country.countryCode, countryCode: country.countryCode,
                slot: .bestMatch, action: .save, reason: nil, excludeUntil: nil,
                revokedAt: nil, createdAt: start)
        }
        let result = UTVReplayService().replay(userID: "u", trips: trips, ranking: nil,
            countries: countries, tags: [], feedback: saves, prior: prior, now: start)
        #expect(result.vector.axes == prior)
        #expect(result.vector.confidence == .zero)
    }

    @Test func everyCountryRejectionLeavesTasteUnchanged() {
        let prior = TasteAxes(natureUrban: 0.3, energyLevel: -0.2, planningStyle: 0.4,
                              socialMode: -0.1, noveltyAppetite: 0.2)
        let country = profile("JP", nature: 0.9)
        for reason: FeedbackReason? in [nil, .tooExpensive, .tooFar, .safety, .notMyTaste] {
            let feedback = CardFeedback(id: "f", countryCode: "JP", slot: .bestMatch,
                                        action: .dislike, reason: reason, excludeUntil: nil,
                                        revokedAt: nil, createdAt: .now)
            let result = UTVReplayService().replay(userID: "u", trips: [], ranking: nil,
                countries: [country], tags: [], feedback: [feedback], prior: prior)
            #expect(result.vector.axes == prior)
        }
    }

    @Test func broadAnswerIsEvidenceAndUnknownIsNot() {
        let broad = TasteQuizService().score(answers: [
            QuizAnswer(questionID: "Q1", signatures: [:], acceptedAxes: [.natureUrban])
        ], interestTagIDs: [])
        let unknown = TasteQuizService().score(answers: [
            QuizAnswer(questionID: "Q1", signatures: [:])
        ], interestTagIDs: [])
        #expect(broad.prior == unknown.prior)
        #expect(broad.acceptedAxes == [.natureUrban])
        #expect(broad.confidence.natureUrban > 0)
        #expect(unknown.confidence.natureUrban == 0)
        #expect(unknown.acceptedAxes.isEmpty)
    }

    @Test @MainActor func quizBackNavigationReplacesBreadthAnswer() {
        let vm = OnboardingViewModel()
        vm.answerQuizAcceptingBoth()
        #expect(vm.quizAnswers.first?.acceptedAxes == [.natureUrban])
        #expect(vm.goBackInQuiz())
        vm.answerQuiz(option: nil)
        #expect(vm.quizAnswers.count == 1)
        #expect(vm.quizAnswers.first?.acceptedAxes == nil)
    }

    @Test @MainActor func quizEvidenceSurvivesStoreReopenReplayAndDeletion() async throws {
        let container = try SwiftDataAppStore.makeContainer(inMemory: true)
        let store = SwiftDataAppStore(container: container, countries: [], tags: [])
        let answers = [QuizAnswer(questionID: "Q1", signatures: [:], acceptedAxes: [.natureUrban]),
                       QuizAnswer(questionID: "Q3", signatures: [.energyLevel: 0.7])]
        let quiz = TasteQuizService().score(answers: answers, interestTagIDs: [])
        try await store.saveQuizAnswers(answers)
        try await store.saveTastePrior(quiz.prior)
        let reopened = SwiftDataAppStore(container: container, countries: [], tags: [])
        #expect(try await reopened.loadQuizAnswers() == answers)
        let service = EvaluationService(trips: reopened, rankings: reopened, countries: reopened,
            tags: reopened, feedback: reopened, utv: reopened, events: reopened, replay: UTVReplayService())
        let replayed = try await service.recompute(userID: "u", trigger: "test")
        #expect(replayed.vector.acceptedAxes == [.natureUrban])
        #expect(replayed.vector.confidence == quiz.confidence)
        #expect(replayed.vector.axes == quiz.prior)
        try await reopened.deleteAllUserData()
        #expect(try await reopened.loadQuizAnswers().isEmpty)
    }

    @Test func legacyVectorDecodesWithoutInventingBreadth() throws {
        let original = vector()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        json.removeValue(forKey: "acceptedAxes")
        let decoded = try JSONDecoder().decode(UserTasteVector.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.acceptedAxes == nil)
        #expect(decoded.axes == original.axes)
    }

    @Test func acceptingBothDoesNotFavorEitherPole() async throws {
        var taste = vector()
        taste.axes.natureUrban = 0.7
        taste.acceptedAxes = [.natureUrban]
        // Only this axis differs. No denominator penalty for either pole.
        let store = InMemoryAppStore(countries: [profile("JP", nature: 0.9)])
        let other = InMemoryAppStore(countries: [profile("JP", nature: -0.9)])
        let positive = try await RecommendationService(countries: store, feedbackRepository: store, events: store)
            .generateThreeSlots(vector: taste, interestTagIDs: [], visitedCountryCodes: [])
        let negative = try await RecommendationService(countries: other, feedbackRepository: other, events: other)
            .generateThreeSlots(vector: taste, interestTagIDs: [], visitedCountryCodes: [])
        #expect(positive.first?.matchScore == negative.first?.matchScore)
    }

    @Test func rejectionReasonAndExposureLinkAreRecorded() async throws {
        let store = InMemoryAppStore(countries: [profile("JP", nature: 0.9)])
        let service = RecommendationService(countries: store, feedbackRepository: store, events: store)
        _ = try await service.applyFeedback(countryCode: "JP", slot: .bestMatch,
            action: .dislike, reason: .tooExpensive, exposureSetID: "set-1")
        #expect(store.storedEvents.last?.payload["reason"] == "too_expensive")
        #expect(store.storedEvents.last?.payload["exposureSetID"] == "set-1")
        #expect(try await service.generateThreeSlots(vector: vector(), interestTagIDs: [], visitedCountryCodes: []).isEmpty)
    }

    @Test @MainActor func impressionsAreLocalDeduplicatedAndKeepDisplayOrder() async throws {
        let sink = CapturingSink()
        let dependencies = AppDependencies(persistence: .inMemory, analyticsSink: sink)
        let first = card("JP", slot: .bestMatch)
        let second = card("PT", slot: .freshStretch)
        let exposure = RecommendationExposure(source: "test", cards: [first, second], vector: vector(),
            interests: ["food"], excludedCountries: ["KR"], homeCountry: "KR", budget: "low")
        let store = try #require(dependencies.store as? SwiftDataAppStore)
        #expect(try await store.events().filter { $0.type == .recommendationImpression }.isEmpty)
        // The second card can become visible first; position is still its display order.
        await exposure.record(second, dependencies: dependencies)
        await exposure.record(second, dependencies: dependencies)
        let events = try await store.events().filter { $0.type == .recommendationImpression }
        #expect(events.count == 1)
        #expect(events.first?.payload["position"] == "2")
        #expect(events.first?.payload["budget"] == "low")
        #expect(events.first?.payload["modelVersion"] == RecommendationService.modelVersion)
        #expect(events.first?.payload["countryDataVersion"]?.count == 64)
        #expect(!sink.events.contains { $0.type == .recommendationImpression })
        try await store.deleteAllUserData()
        #expect(try await store.events().isEmpty)
    }

    private func vector() -> UserTasteVector {
        UserTasteVector(userID: "u", axes: .zero,
            confidence: TasteAxes(natureUrban: 0.7, energyLevel: 0.7, planningStyle: 0.7,
                                  socialMode: 0.7, noveltyAppetite: 0.7), ledgerVersion: 0, recomputedAt: .now)
    }

    private func profile(_ code: String, nature: Double) -> CountryProfile {
        CountryProfile(countryCode: code, name: code, nameKo: code, status: .confirmed,
            tasteCore: TasteAxes(natureUrban: nature, energyLevel: 0, planningStyle: 0, socialMode: 0, noveltyAppetite: 0),
            matchingAxes: [.natureUrban], interestTags: [:], constraints: .init(cost: 0.5, climate: 0.5), popularity: 0.5)
    }

    private func card(_ code: String, slot: RecommendationSlot) -> Recommendation {
        Recommendation(countryCode: code, slot: slot, matchScore: 0.6, explanationTagIDs: [],
            rankingAnchorTripID: nil, fitBadges: [], notices: [])
    }
}

private final class CapturingSink: AnalyticsSink, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AnalyticsEvent] = []
    var events: [AnalyticsEvent] { lock.withLock { storage } }
    func send(_ event: AnalyticsEvent) { lock.withLock { storage.append(event) } }
}
