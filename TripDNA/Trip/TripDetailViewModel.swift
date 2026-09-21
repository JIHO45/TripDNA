import Foundation

@Observable
final class TripDetailViewModel {
    var trip: Trip?
    var photos: [DailyPhoto] = []
    var isLoading = false
    var errorMessage: String?

    func load(tripID: String, dependencies: AppDependencies) async {
        isLoading = true
        defer { isLoading = false }
        trip = try? await dependencies.store.trip(id: tripID)
        photos = (try? await dependencies.store.photos(tripID: tripID)) ?? []
    }

    func start(dependencies: AppDependencies) async {
        guard let trip else { return }
        self.trip = try? await dependencies.tripService.startTrip(id: trip.id)
    }

    func end(dependencies: AppDependencies) async {
        guard let trip else { return }
        self.trip = try? await dependencies.tripService.endTrip(id: trip.id)
    }

    func setCoverPhoto(_ path: String, dependencies: AppDependencies) async {
        guard let trip else { return }
        self.trip = try? await dependencies.tripService.setCoverPhoto(tripID: trip.id, storagePath: path)
    }

    // MARK: - 일차·타임라인 계산

    private var tripStartDate: Date? {
        guard let trip else { return nil }
        return trip.startedAt ?? trip.legs.first?.startDate
    }

    /// 현재 여행 기준 오늘이 몇 일차인지. (1일차부터 시작)
    var currentDayIndex: Int {
        guard let tripStartDate else { return 1 }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: tripStartDate),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return max(1, days + 1)
    }

    /// 여행 전체 일수. 타임라인 스트립의 칸 수로 사용한다. (표시 안정성을 위해 상한 60)
    var totalDays: Int {
        guard let trip, let first = trip.legs.first, let last = trip.legs.last else { return 0 }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: first.startDate),
            to: Calendar.current.startOfDay(for: last.endDate)
        ).day ?? 0
        return min(60, max(1, days + 1))
    }

    func photo(forDay dayIndex: Int) -> DailyPhoto? {
        photos.first { $0.tripDayIndex == dayIndex }
    }

    var todayPhoto: DailyPhoto? {
        photo(forDay: currentDayIndex)
    }

    /// 평가 완료 여행의 공유용 텍스트 요약.
    var shareSummary: String {
        guard let trip else { return "" }
        var lines = ["\(trip.titleKo) 여행", trip.dateRangeKo]
        if let satisfaction = trip.evaluation?.satisfaction {
            lines.append("만족도 \(satisfaction)/5")
        }
        if let rank = trip.rankPosition {
            lines.append("내 여행 랭킹 \(rank)위")
        }
        let tags = trip.evaluation?.positiveTagIDs.map(TagCatalog.labelKo(for:)) ?? []
        if !tags.isEmpty {
            lines.append("좋았던 것: " + tags.joined(separator: ", "))
        }
        lines.append("— TripDNA에서 기록했어요")
        return lines.joined(separator: "\n")
    }
}
