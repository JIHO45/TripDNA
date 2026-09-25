import Foundation

enum PrimaryActionKind {
    case evaluate(tripID: String, titleKo: String)
    case dailyPhoto(tripID: String, titleKo: String)
    /// 오늘은 이미 한 장을 남긴 활성 여행. 상세에서 사진을 바꿀 수 있다.
    case activeTrip(tripID: String, titleKo: String)
    case upcoming(titleKo: String)
    case registerFirstTrip
}

@Observable
final class HomeViewModel {
    var vector: UserTasteVector?
    var trips: [Trip] = []
    var photos: [DailyPhoto] = []
    var bestMatch: Recommendation?
    var isSeasonOpen = false
    var isLoading = false

    var primaryAction: PrimaryActionKind {
        if let ended = trips.first(where: { $0.status == .ended }) {
            return .evaluate(tripID: ended.id, titleKo: ended.titleKo)
        }
        if let active = trips.first(where: { $0.status == .active }) {
            if hasTodayPhoto(for: active) {
                return .activeTrip(tripID: active.id, titleKo: active.titleKo)
            }
            return .dailyPhoto(tripID: active.id, titleKo: active.titleKo)
        }
        if let planned = trips.first(where: { $0.status == .planned }) {
            return .upcoming(titleKo: planned.titleKo)
        }
        return .registerFirstTrip
    }

    func load(_ dependencies: AppDependencies) async {
        isLoading = true
        defer { isLoading = false }

        trips = await dependencies.allTrips()
        photos = (try? await dependencies.store.photos(tripID: nil)) ?? []
        vector = try? await dependencies.store.currentUTV()
        isSeasonOpen = dependencies.wrappedService.isSeasonOpen(at: Date(), trips: trips)

        guard let vector else { return }
        let visited = Set(trips.flatMap { $0.legs.map(\.countryCode) })
        let recommendations = (try? await dependencies.recommendationService.generateThreeSlots(
            vector: vector,
            interestTagIDs: dependencies.interestTagIDs,
            visitedCountryCodes: dependencies.excludedCountryCodes(visited: visited)
        )) ?? []
        bestMatch = recommendations.first { $0.slot == .bestMatch } ?? recommendations.first
    }

    private func hasTodayPhoto(for trip: Trip) -> Bool {
        let dayIndex = currentDayIndex(for: trip)
        return photos.contains { $0.tripID == trip.id && $0.tripDayIndex == dayIndex }
    }

    private func currentDayIndex(for trip: Trip) -> Int {
        let start = trip.startedAt ?? trip.legs.first?.startDate ?? Date()
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return max(1, days + 1)
    }
}
