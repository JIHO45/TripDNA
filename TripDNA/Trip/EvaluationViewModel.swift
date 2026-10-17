import Foundation

/// UI-8 스텝형 평가의 화면 단위.
enum EvaluationStep: Equatable {
    case intro
    case satisfaction
    case revisit
    case bestCountry
    case comparison
    /// 방문 도시마다 한 페이지. 값은 `cityReviews`의 위치다.
    case cityReview(Int)
    case processing
    case result
}

/// "잘 모르겠어요"를 표현하기 위한 UI 상태.
/// Domain `wouldRepeat`는 스킵이 아니면 non-nil Bool을 요구하므로,
/// unsure는 제출 시 만족도 ≥4 → true, 아니면 false로 매핑한다.
enum RevisitAnswer: Equatable {
    case yes
    case no
    case unsure
}

@Observable
final class EvaluationViewModel {
    var trip: Trip?
    private var allTrips: [Trip] = []
    private var evaluationService: EvaluationService?
    var photos: [DailyPhoto] = []

    var step: EvaluationStep = .intro
    var satisfaction: Int?
    var revisitAnswer: RevisitAnswer?
    var bestLegCountryCode: String?
    var comparisonResult: ComparisonResult?
    /// 도시별 별점·메모. 메모는 입력 그대로 두고 제출할 때 공백만 정리한다.
    var cityReviews: [CityReview] = []
    // 태그 선택 UI는 2026-10-08에 없앴다. 이전 평가의 태그는 수정 제출 때 그대로 넘겨 보존한다.
    private var positiveTagIDs: [String] = []
    private var negativeTagIDs: [String] = []
    private var tagLegAttribution: [String: String] = [:]

    var isSubmitting = false
    /// 이미 제출한 평가를 고치는 중. 이전 답이 채워진 채로 시작한다.
    private(set) var isRevising = false
    var errorMessage: String?
    var didSubmit = false
    var deltaAxes: TasteAxes?

    var comparisonAnchor: Trip? {
        guard let trip, let evaluationService, let satisfaction else { return nil }
        return evaluationService.selectComparisonAnchor(
            satisfaction: satisfaction,
            excluding: trip.id,
            from: allTrips
        )
    }

    var isMultiLeg: Bool {
        (trip?.legs.count ?? 0) > 1
    }

    var uniqueCountryCodes: [String] {
        guard let trip else { return [] }
        var seen = Set<String>()
        var ordered: [String] = []
        for leg in trip.legs {
            let code = leg.countryCode.uppercased()
            if seen.insert(code).inserted {
                ordered.append(code)
            }
        }
        return ordered
    }

    /// intro~마지막 도시 사이 실제 진행 스텝(동적).
    var flowSteps: [EvaluationStep] {
        var steps: [EvaluationStep] = [.intro, .satisfaction, .revisit]
        if isMultiLeg { steps.append(.bestCountry) }
        // 비교는 만족도 확정 후 앵커가 있을 때만 의미 있다. 없으면 advance()에서 자동 생략.
        steps.append(.comparison)
        steps.append(contentsOf: cityReviews.indices.map(EvaluationStep.cityReview))
        return steps
    }

    var progress: Double {
        let steps = flowSteps
        guard let index = steps.firstIndex(of: step), !steps.isEmpty else {
            if step == .processing || step == .result { return 1 }
            return 0
        }
        return Double(index) / Double(max(1, steps.count - 1))
    }

    var partLabel: String {
        switch step {
        case .intro, .satisfaction, .revisit, .bestCountry:
            return "1/3 판정"
        case .comparison:
            return "2/3 비교"
        case .cityReview:
            return "3/3 도시별 기록"
        case .processing, .result:
            return "완료"
        }
    }

    func load(tripID: String, dependencies: AppDependencies) async {
        trip = try? await dependencies.store.trip(id: tripID)
        allTrips = await dependencies.allTrips()
        evaluationService = dependencies.evaluationService
        photos = (try? await dependencies.store.photos(tripID: tripID)) ?? []
        cityReviews = trip?.reviewTargets ?? []
        if let firstLeg = trip?.legs.first, trip?.legs.count == 1 {
            bestLegCountryCode = firstLeg.countryCode
        }
        if let trip, trip.status == .evaluated || trip.status == .skippedEvaluation {
            isRevising = true
            if let evaluation = trip.evaluation, !evaluation.skipped {
                prefill(from: evaluation)
            }
        }
    }

    private func prefill(from evaluation: TripEvaluation) {
        satisfaction = evaluation.satisfaction
        revisitAnswer = evaluation.wouldRepeat.map { $0 ? .yes : .no }
        if let best = evaluation.bestLegCountryCode {
            bestLegCountryCode = best
        }
        comparisonResult = evaluation.comparison?.result
        positiveTagIDs = evaluation.positiveTagIDs
        negativeTagIDs = evaluation.negativeTagIDs
        tagLegAttribution = evaluation.tagLegAttribution
        // 저장된 도시 평가를 같은 도시 자리에 채운다. 구간이 바뀌어 없어진 도시는 남기지 않는다.
        for saved in evaluation.cityReviews ?? [] {
            if let index = cityReviews.firstIndex(where: {
                $0.countryCode == saved.countryCode && $0.city == saved.city
            }) {
                cityReviews[index] = saved
            }
        }
    }

    /// 마지막 페이지(도시가 없으면 비교)에서 제출한다.
    var isLastStep: Bool {
        flowSteps.last == step
    }

    func start() {
        step = .satisfaction
    }

    func goBack() {
        let steps = flowSteps
        guard let index = steps.firstIndex(of: step), index > 0 else {
            step = .intro
            return
        }
        step = steps[index - 1]
    }

    func advance() {
        let steps = flowSteps
        guard let index = steps.firstIndex(of: step) else { return }
        if index + 1 < steps.count {
            let next = steps[index + 1]
            // 비교 스텝인데 앵커가 없으면(첫 여행) 자동 생략.
            if next == .comparison, comparisonAnchor == nil {
                comparisonResult = .skipped
                if index + 2 < steps.count {
                    step = steps[index + 2]
                }
                return
            }
            step = next
        }
    }

    /// 빈 메모는 nil로, 아무것도 적지 않은 도시는 미상으로 빼고 남긴다.
    var submittedCityReviews: [CityReview] {
        cityReviews.compactMap { review in
            var review = review
            review.liked = review.liked?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            review.disliked = review.disliked?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            return review.isEmpty ? nil : review
        }
    }

    func submit(dependencies: AppDependencies, session: SessionStore) async {
        guard let trip, let satisfaction else { return }
        isSubmitting = true
        errorMessage = nil
        step = .processing
        defer { isSubmitting = false }
        do {
            let wouldRepeat: Bool
            switch revisitAnswer {
            case .yes: wouldRepeat = true
            case .no: wouldRepeat = false
            case .unsure, .none:
                // Domain이 non-nil을 요구하므로 만족도 휴리스틱으로 매핑한다.
                wouldRepeat = satisfaction >= 4
            }

            let anchor = comparisonAnchor
            let comparison: TripComparison? = {
                guard let anchor else { return nil }
                return TripComparison(versusTripID: anchor.id, result: comparisonResult ?? .skipped)
            }()

            let evaluation = try TripEvaluation(
                satisfaction: satisfaction,
                wouldRepeat: wouldRepeat,
                bestLegCountryCode: isMultiLeg ? bestLegCountryCode : nil,
                comparison: comparison,
                positiveTagIDs: positiveTagIDs,
                negativeTagIDs: negativeTagIDs,
                tagLegAttribution: tagLegAttribution,
                cityReviews: submittedCityReviews,
                source: .postTrip
            )
            let result = isRevising
                ? try await dependencies.evaluationService.revise(
                    tripID: trip.id,
                    evaluation: evaluation,
                    userID: session.userID
                )
                : try await dependencies.evaluationService.submit(
                    tripID: trip.id,
                    evaluation: evaluation,
                    userID: session.userID
                )
            deltaAxes = result.delta
            didSubmit = true
            EvaluationNotificationService.cancel(for: trip.id)
            try? await Task.sleep(for: .seconds(1.0))
            step = .result
        } catch {
            errorMessage = "평가를 저장하지 못했어요. 입력값을 확인해주세요."
            step = flowSteps.last ?? .intro
        }
    }

    func skip(dependencies: AppDependencies, session: SessionStore) async {
        guard let trip else { return }
        isSubmitting = true
        errorMessage = nil
        step = .processing
        defer { isSubmitting = false }
        do {
            let evaluation = try TripEvaluation(
                satisfaction: nil,
                wouldRepeat: nil,
                source: .postTrip,
                skipped: true
            )
            let result = try await dependencies.evaluationService.submit(
                tripID: trip.id,
                evaluation: evaluation,
                userID: session.userID
            )
            deltaAxes = result.delta
            didSubmit = true
            EvaluationNotificationService.cancel(for: trip.id)
            try? await Task.sleep(for: .seconds(0.8))
            step = .result
        } catch {
            errorMessage = "저장하지 못했어요."
            step = .intro
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
