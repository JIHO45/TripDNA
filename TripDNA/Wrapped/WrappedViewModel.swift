import Foundation

/// `WrappedCard`(kind/title/detail)만으로는 풀스크린 스토리 카드를 그리기 부족하므로,
/// ViewModel에서 원본 여행·랭킹·지문·사진 데이터를 가공해 화면 전용 모델로 확장한다.
/// (`WrappedCard` 타입은 Application 계층 소유라 수정하지 않는다.)
struct WrappedDisplayModel: Equatable {
    let year: Int
    let tripCount: Int
    let destinationCount: Int
    let cards: [WrappedCard]

    /// W2. 랭킹 1위(연도 내) 여행 제목·기간. 랭킹이 없으면 첫 여행으로 폴백.
    let topTripTitle: String
    let topTripDateRange: String

    /// W3. 절대값이 가장 큰(가장 선명한) 축.
    let strongestAxis: TasteAxis
    /// 신뢰도가 낮아 추천 매칭에 쓰이지 않는 축이면 true — "추천 근거" 표현 금지(UI-5 스펙).
    let isStrongestAxisConditional: Bool

    /// W4. 해당 연도 평가에서 가장 자주 고른 긍정 태그 라벨 최대 3개. 부정 태그는 제외.
    let topTagLabels: [String]

    let axes: TasteAxes
    let confidence: AxisConfidence
    /// 모든 축의 신뢰도가 기준(0.4) 미만이면 "올해의 첫인상"으로 표현한다(UI-5E).
    let isLowConfidence: Bool

    /// W5. 해당 연도 여행에 속한 하루 한 장 사진(모자이크용).
    let annualPhotos: [DailyPhoto]

    /// 여행이 1개면 비교·순위 표현 없이 한 여행 중심으로 서술한다.
    var isSingleTrip: Bool { tripCount == 1 }

    /// 인트로·공유 카드 제목. 저신뢰 지문이면 "올해의 첫인상" 변형.
    var heroTitle: String { isLowConfidence ? "올해의 첫인상" : "여행 지문" }
}

@Observable
final class WrappedViewModel {
    var summary: WrappedSummary?
    var display: WrappedDisplayModel?
    var isLoading = false
    var notAvailableReason: String?

    func load(_ dependencies: AppDependencies, forcePreview: Bool) async {
        isLoading = true
        defer { isLoading = false }

        let trips = await dependencies.allTrips()
        let ranking = try? await dependencies.store.currentRanking()
        let photos = (try? await dependencies.store.photos(tripID: nil)) ?? []
        guard let vector = try? await dependencies.store.currentUTV() else {
            notAvailableReason = "아직 취향 지문이 없어요."
            return
        }

        let date = forcePreview ? Self.previewDate(trips: trips) : Date()
        let rawSummary = dependencies.wrappedService.generateSixCards(
            at: date,
            trips: trips,
            ranking: ranking,
            vector: vector,
            photos: photos
        )
        guard let rawSummary else {
            summary = nil
            display = nil
            notAvailableReason = forcePreview
                ? "미리보기를 위한 올해 여행 데이터가 없어요. 여행을 먼저 등록해보세요."
                : "Wrapped는 12월 15일 ~ 1월 15일에만 열려요."
            return
        }

        let humanized = Self.humanize(rawSummary, trips: trips)
        summary = humanized
        display = Self.makeDisplayModel(
            summary: humanized,
            trips: trips,
            ranking: ranking,
            vector: vector,
            photos: photos
        )
    }

    // MARK: - Display model

    private static func makeDisplayModel(
        summary: WrappedSummary,
        trips: [Trip],
        ranking: TripRanking?,
        vector: UserTasteVector,
        photos: [DailyPhoto]
    ) -> WrappedDisplayModel {
        let calendar = Calendar(identifier: .gregorian)
        let annualTrips = trips.filter { trip in
            let anchor = trip.endedAt ?? trip.startedAt ?? trip.createdAt
            return calendar.component(.year, from: anchor) == summary.year
        }
        let annualIDs = Set(annualTrips.map(\.id))

        let rankedAnnualIDs = ranking?.tripIDsOrdered.filter(annualIDs.contains) ?? []
        let topTrip = rankedAnnualIDs.first
            .flatMap { id in annualTrips.first { $0.id == id } }
            ?? annualTrips.first

        let strongestAxis = TasteAxis.allCases.max {
            abs(vector.axes[$0]) < abs(vector.axes[$1])
        } ?? .natureUrban

        // 긍정 태그만 빈도순으로 집계한다. 부정 태그는 공유·회고 주인공으로 쓰지 않는다.
        var tagCounts: [String: Int] = [:]
        for trip in annualTrips {
            for tagID in trip.evaluation?.positiveTagIDs ?? [] {
                tagCounts[tagID, default: 0] += 1
            }
        }
        let topTagLabels = tagCounts
            .sorted { lhs, rhs in
                lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
            }
            .prefix(3)
            .map { TagCatalog.labelKo(for: $0.key) }

        let annualPhotos = photos
            .filter { annualIDs.contains($0.tripID) }
            .sorted { ($0.tripID, $0.tripDayIndex) < ($1.tripID, $1.tripDayIndex) }

        return WrappedDisplayModel(
            year: summary.year,
            tripCount: summary.tripCount,
            destinationCount: summary.destinationCount,
            cards: summary.cards,
            topTripTitle: topTrip?.titleKo ?? "기록 없음",
            topTripDateRange: topTrip?.dateRangeKo ?? "",
            strongestAxis: strongestAxis,
            isStrongestAxisConditional: !vector.isAxisUsable(strongestAxis),
            topTagLabels: topTagLabels,
            axes: vector.axes,
            confidence: vector.confidence,
            isLowConfidence: TasteAxis.allCases.allSatisfy { !vector.isAxisUsable($0) },
            annualPhotos: annualPhotos
        )
    }

    // MARK: - Existing helpers

    private static func humanize(_ summary: WrappedSummary, trips: [Trip]) -> WrappedSummary {
        let tripsByID = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) })
        let cards = summary.cards.map { card -> WrappedCard in
            switch card.kind {
            case .topTrip:
                let title = tripsByID[card.detail]?.titleKo ?? "기록 없음"
                return WrappedCard(kind: card.kind, title: card.title, detail: title)
            case .strongestTaste:
                let axis = TasteAxis(rawValue: card.detail)?.labelKo ?? card.detail
                return WrappedCard(kind: card.kind, title: card.title, detail: axis)
            case .tags:
                let label = card.detail == "기록 없음" ? card.detail : TagCatalog.labelKo(for: card.detail)
                return WrappedCard(kind: card.kind, title: card.title, detail: label)
            default:
                return card
            }
        }
        return WrappedSummary(
            year: summary.year,
            tripCount: summary.tripCount,
            destinationCount: summary.destinationCount,
            cards: cards
        )
    }

    private static func previewDate(trips: [Trip]) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let years = trips.compactMap {
            calendar.dateComponents([.year], from: $0.endedAt ?? $0.startedAt ?? $0.createdAt).year
        }
        let year = years.max() ?? calendar.component(.year, from: Date())
        return calendar.date(from: DateComponents(year: year, month: 12, day: 20)) ?? Date()
    }
}
