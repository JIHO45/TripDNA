import Foundation
import SwiftData
import Testing
@testable import TripDNA

struct AccountDeletionTests {
    @Test func deletionClearsEveryLocalDataModel() async throws {
        let container = try SwiftDataAppStore.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(StoredTrip(tripID: "trip", createdAt: .now, payload: Data()))
        context.insert(StoredCardFeedback(feedbackID: "feedback", createdAt: .now, payload: Data()))
        context.insert(StoredDailyPhoto(photoID: "photo", tripID: "trip", tripDayIndex: 0, payload: Data()))
        context.insert(StoredAnalyticsEvent(eventID: "event", createdAt: .now, payload: Data()))
        context.insert(StoredSingleton(key: "userProfile", payload: Data()))
        try context.save()

        let store = SwiftDataAppStore(container: container, countries: [], tags: [])
        try await store.deleteAllUserData()

        let verificationContext = ModelContext(container)
        #expect(try verificationContext.fetchCount(FetchDescriptor<StoredTrip>()) == 0)
        #expect(try verificationContext.fetchCount(FetchDescriptor<StoredCardFeedback>()) == 0)
        #expect(try verificationContext.fetchCount(FetchDescriptor<StoredDailyPhoto>()) == 0)
        #expect(try verificationContext.fetchCount(FetchDescriptor<StoredAnalyticsEvent>()) == 0)
        #expect(try verificationContext.fetchCount(FetchDescriptor<StoredSingleton>()) == 0)
    }
}
