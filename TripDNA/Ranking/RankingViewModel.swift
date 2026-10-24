import Foundation
import SwiftUI

@Observable
final class RankingViewModel {
    private(set) var trips: [String: Trip] = [:]
    var order: [String] = []
    private var savedOrder: [String] = []
    var previewVector: UserTasteVector?
    var isLoading = true
    var isSaving = false
    var saveMessage: String?

    /// 저장 델타 문구 계산용 — 마지막 저장(또는 로드) 시점의 축 값.
    private var baselineAxes: TasteAxes?
    /// 빠른 연속 드래그를 디바운스해 마지막 순서만 미리보기 계산한다.
    @ObservationIgnored private var previewTask: Task<Void, Never>?

    var hasUnsavedChanges: Bool {
        order != savedOrder
    }

    func trip(for id: String) -> Trip? {
        trips[id]
    }

    func load(_ dependencies: AppDependencies) async {
        isLoading = true
        defer { isLoading = false }

        let allTrips = await dependencies.allTrips()
        trips = Dictionary(uniqueKeysWithValues: allTrips.map { ($0.id, $0) })

        let ranking = try? await dependencies.rankingService.loadRanking()
        order = ranking?.tripIDsOrdered ?? []
        savedOrder = order
        previewVector = try? await dependencies.store.currentUTV()
        baselineAxes = previewVector?.axes
    }

    /// 저장하지 않은 임시 순서를 버리고 저장된 순서로 돌아간다.
    func revertDraft() {
        previewTask?.cancel()
        order = savedOrder
        saveMessage = nil
    }

    func moveDraft(fromOffsets: IndexSet, toOffset: Int, dependencies: AppDependencies, userID: String) {
        order.move(fromOffsets: fromOffsets, toOffset: toOffset)
        previewTask?.cancel()
        previewTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.refreshPreview(dependencies, userID: userID)
        }
    }

    func refreshPreview(_ dependencies: AppDependencies, userID: String) async {
        guard let draft = try? TripRanking(tripIDsOrdered: order) else { return }
        let result = try? await dependencies.rankingService.preview(
            ranking: draft,
            userID: userID
        )
        guard !Task.isCancelled else { return }
        previewVector = result?.vector
    }

    func save(_ dependencies: AppDependencies, userID: String) async {
        previewTask?.cancel()
        previewTask = nil
        guard let draft = try? TripRanking(tripIDsOrdered: order) else { return }
        isSaving = true
        defer { isSaving = false }
        if let result = try? await dependencies.rankingService.save(draft, userID: userID) {
            previewVector = result.vector
            baselineAxes = result.vector.axes
            savedOrder = order
            RankingReorderFlag.mark()
            saveMessage = "이 순서로 저장했어요."
        } else {
            saveMessage = "저장하지 못했어요. 다시 시도해주세요."
        }
    }
}
