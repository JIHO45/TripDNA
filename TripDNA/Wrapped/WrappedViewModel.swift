import Foundation

@Observable
final class WrappedViewModel {
    var wrapped: WrappedYear?
    var isLoading = true

    /// 열 때마다 그해 기록으로 다시 만든다. 지난 해도 같다.
    func load(year: Int, dependencies: AppDependencies) async {
        isLoading = true
        defer { isLoading = false }
        let trips = await dependencies.allTrips()
        let ranking = try? await dependencies.store.currentRanking()
        let photos = (try? await dependencies.store.photos(tripID: nil)) ?? []
        wrapped = WrappedYear.make(
            year: year,
            now: Date(),
            trips: trips,
            ranking: ranking,
            rankingReordered: RankingReorderFlag.isSet(),
            photos: photos
        )
    }
}
