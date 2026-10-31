import Foundation
import SwiftData
import Testing
import UIKit
@testable import TripDNA

struct RecordLifecycleTests {
    @Test func writesStampUpdatedAt() async throws {
        let container = try SwiftDataAppStore.makeContainer(inMemory: true)
        let store = SwiftDataAppStore(container: container, countries: [], tags: [])
        let feedback = CardFeedback(
            id: "save-1", countryCode: "JP", slot: .bestMatch,
            action: .save, reason: nil, excludeUntil: nil,
            revokedAt: nil, createdAt: .distantPast
        )
        try await store.create(feedback)
        try await store.saveInterestTagIDs(["food"])

        let context = ModelContext(container)
        let created = try #require(try context.fetch(FetchDescriptor<StoredCardFeedback>()).first?.updatedAt)
        #expect(created > .distantPast)
        #expect(try context.fetch(FetchDescriptor<StoredSingleton>()).first?.updatedAt != nil)

        try await store.update(feedback)
        let updated = try #require(try ModelContext(container).fetch(FetchDescriptor<StoredCardFeedback>()).first?.updatedAt)
        #expect(updated >= created)
    }

    @Test func v1StoreOpensAsV2() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let v1 = try ModelContainer(
                for: Schema(versionedSchema: TripDNASchemaV1.self),
                configurations: ModelConfiguration(url: url, cloudKitDatabase: .none)
            )
            let context = ModelContext(v1)
            context.insert(TripDNASchemaV1.StoredSingleton(key: "interestTags", payload: try JSONEncoder().encode(["food"])))
            try context.save()
        }
        let store = SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(url: url), countries: [], tags: [])
        #expect(try await store.loadInterestTagIDs() == ["food"])
    }

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

    @Test @MainActor func replacingDailyPhotoDeletesOnlyUnusedFiles() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let leg = try TripLeg(countryCode: "JP", startDate: .now, endDate: .now.addingTimeInterval(86400))
        let trip = try await dependencies.tripService.createTrip(legs: [leg], companion: .alone, purpose: .leisure)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        let cover = try LocalPhotoStore.saveImage(image)
        let old = try LocalPhotoStore.saveImage(image)
        let original = try LocalPhotoStore.saveImage(image)
        let cropped = try LocalPhotoStore.saveImage(image)
        defer { try? LocalPhotoStore.delete(paths: [cover, old, original, cropped]) }
        let service = dependencies.dailyPhotoService
        _ = try await service.saveSelection(tripID: trip.id, tripDayIndex: 1, storagePath: cover, selection: .manual, reaction: nil)
        _ = try await dependencies.tripService.setCoverPhoto(tripID: trip.id, storagePath: cover)
        _ = try await service.saveSelection(tripID: trip.id, tripDayIndex: 2, storagePath: old, selection: .manual, reaction: nil)

        // 1일차(대표 사진)와 2일차를 교체하고, 크롭 전 원본과 이전 파일을 정리한다.
        _ = try await service.saveSelection(tripID: trip.id, tripDayIndex: 1, storagePath: cropped, selection: .manual, reaction: nil)
        _ = try await service.saveSelection(tripID: trip.id, tripDayIndex: 2, storagePath: original, selection: .manual, reaction: nil)
        try await dependencies.deleteUnusedPhotoFiles([cover, old, original, cropped])

        #expect(LocalPhotoStore.image(at: cover) != nil)
        #expect(LocalPhotoStore.image(at: old) == nil)
        #expect(LocalPhotoStore.image(at: original) != nil)
        #expect(LocalPhotoStore.image(at: cropped) != nil)
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
