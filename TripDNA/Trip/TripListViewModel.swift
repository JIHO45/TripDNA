import Foundation

@Observable
final class TripListViewModel {
    var trips: [Trip] = []
    var isLoading = false

    func load(_ dependencies: AppDependencies) async {
        isLoading = true
        defer { isLoading = false }
        trips = await dependencies.allTrips()
    }

    /// 현재 진행 중 여행. 여러 개면 가장 최근 시작분.
    var currentTrip: Trip? {
        trips
            .filter { $0.status == .active }
            .sorted { startDate(of: $0) > startDate(of: $1) }
            .first
    }

    /// 예정 여행. 시작일 오름차순.
    var upcomingTrips: [Trip] {
        trips
            .filter { $0.status == .planned }
            .sorted { startDate(of: $0) < startDate(of: $1) }
    }

    /// 평가를 기다리는 여행. 종료일 내림차순.
    var awaitingTrips: [Trip] {
        trips.filter { $0.status == .ended }.sorted { endDate(of: $0) > endDate(of: $1) }
    }

    /// 평가를 마쳤거나 건너뛴 지난 여행을 시작 연도별로 묶는다. 최근 연도가 먼저다.
    var pastTripsByYear: [(year: Int, trips: [Trip])] {
        let past = trips
            .filter { $0.status == .evaluated || $0.status == .skippedEvaluation }
            .sorted { endDate(of: $0) > endDate(of: $1) }
        let grouped = Dictionary(grouping: past) { Calendar.current.component(.year, from: startDate(of: $0)) }
        return grouped.keys.sorted(by: >).map { (year: $0, trips: grouped[$0] ?? []) }
    }

    private func startDate(of trip: Trip) -> Date {
        trip.legs.first?.startDate ?? trip.createdAt
    }

    private func endDate(of trip: Trip) -> Date {
        trip.legs.last?.endDate ?? trip.createdAt
    }
}
