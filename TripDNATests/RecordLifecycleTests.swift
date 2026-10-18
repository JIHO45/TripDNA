import Foundation
import SwiftData
import Testing
@testable import TripDNA

struct RecordLifecycleTests {
    @Test func interestTagsAndUnsavePersistInSwiftData() async throws {
        let container = try SwiftDataAppStore.makeContainer(inMemory: true)
        let first = SwiftDataAppStore(container: container, countries: [], tags: [])
        try await first.saveInterestTagIDs(["food", "culture"])
        let feedback = CardFeedback(
            id: "save-1", countryCode: "JP", slot: .bestMatch,
            action: .save, reason: nil, excludeUntil: nil,
            revokedAt: nil, createdAt: .now
        )
        try await first.create(feedback)
        try await first.deleteFeedback(id: feedback.id)

        let reopened = SwiftDataAppStore(container: container, countries: [], tags: [])
        #expect(try await reopened.loadInterestTagIDs() == ["food", "culture"])
        #expect(try await reopened.feedback().isEmpty)
    }

    @Test @MainActor func dailyPhotoExistsAfterConfirmWithoutReaction() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let service = dependencies.dailyPhotoService
        _ = try await service.saveSelection(
            tripID: "trip", tripDayIndex: 1, storagePath: "a.jpg", selection: .manual, reaction: nil
        )
        let saved = try #require(try await dependencies.store.photos(tripID: "trip").first)
        #expect(saved.selection == .manual)
        #expect(saved.dayReaction == nil)

        try await service.updateReaction(tripID: "trip", tripDayIndex: 1, reaction: .good)
        let updated = try await dependencies.store.photos(tripID: "trip")
        #expect(updated.count == 1)
        #expect(updated.first?.dayReaction == .good)
        #expect(updated.first?.storagePath == "a.jpg")
    }

    @Test @MainActor func deletingTripRemovesItsRecord() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let start = Date().addingTimeInterval(7 * 24 * 60 * 60)
        let end = start.addingTimeInterval(3 * 24 * 60 * 60)
        let leg = try TripLeg(countryCode: "JP", startDate: start, endDate: end)
        let trip = try await dependencies.tripService.createTrip(
            legs: [leg], companion: .alone, purpose: .leisure
        )
        try await dependencies.deleteTrip(tripID: trip.id, userID: "test-user")
        #expect(try await dependencies.store.trip(id: trip.id) == nil)
    }

    @Test @MainActor func deletingEvaluationKeepsTripAndReopensEvaluation() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let start = Date().addingTimeInterval(-10 * 24 * 60 * 60)
        let end = Date().addingTimeInterval(-5 * 24 * 60 * 60)
        let leg = try TripLeg(countryCode: "JP", startDate: start, endDate: end)
        var trip = try Trip(legs: [leg], companion: .alone, purpose: .leisure)
        try trip.end(at: end)
        let evaluation = try TripEvaluation(
            satisfaction: 4, wouldRepeat: true, source: .postTrip
        )
        try trip.submit(evaluation, at: end)
        try await dependencies.store.create(trip)

        try await dependencies.deleteEvaluation(tripID: trip.id, userID: "test-user")
        let restored = try #require(await dependencies.store.trip(id: trip.id))
        #expect(restored.status == .ended)
        #expect(restored.evaluation == nil)
    }
}
