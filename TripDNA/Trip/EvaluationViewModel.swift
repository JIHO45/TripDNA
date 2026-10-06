import Foundation

/// UI-8 스텝형 평가의 화면 단위.
enum EvaluationStep: Equatable {
    case intro
    case satisfaction
    case revisit
    case bestCountry
    case comparison
    case positiveTags
    case tagAttribution
    case negativeTags
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
    var positiveTagOptions: [TagDefinition] = []
    var negativeTagOptions: [TagDefinition] = []

    var step: EvaluationStep = .intro
    var satisfaction: Int?
    var revisitAnswer: RevisitAnswer?
    var bestLegCountryCode: String?
    var comparisonResult: ComparisonResult?
    var positiveTagIDs: [String] = []
    var negativeTagIDs: [String] = []
    /// taste 라우팅 태그 → 귀속 국가 코드. "전체 여행"이면 키를 넣지 않는다.
    var tagLegAttribution: [String: String] = [:]

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

    var polarityTags: [TagDefinition] {
        positiveTagOptions.filter { $0.group == .polarity }
    }

    var interestTags: [TagDefinition] {
        positiveTagOptions.filter { $0.group == .interest }
    }

    /// 선택된 긍정 태그 중 taste 라우팅이 있는 것만 — 기존 평가 입력의 귀속 대상.
    var tasteTagsNeedingAttribution: [TagDefinition] {
        positiveTagOptions.filter { tag in
            positiveTagIDs.contains(tag.id) && tag.routing.contains(.taste)
        }
    }

    /// intro~negativeTags 사이 실제 진행 스텝(동적).
    var flowSteps: [EvaluationStep] {
        var steps: [EvaluationStep] = [.intro, .satisfaction, .revisit]
        if isMultiLeg { steps.append(.bestCountry) }
        // 비교는 만족도 확정 후 앵커가 있을 때만 의미 있다. 없으면 advance()에서 자동 생략.
        steps.append(.comparison)
        steps.append(.positiveTags)
        if isMultiLeg && !tasteTagsNeedingAttribution.isEmpty {
            steps.append(.tagAttribution)
        }
        steps.append(.negativeTags)
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
        case .positiveTags, .tagAttribution, .negativeTags:
            return "3/3 취향"
        case .processing, .result:
            return "완료"
        }
    }

    func load(tripID: String, dependencies: AppDependencies) async {
        trip = try? await dependencies.store.trip(id: tripID)
        allTrips = await dependencies.allTrips()
        evaluationService = dependencies.evaluationService
        photos = (try? await dependencies.store.photos(tripID: tripID)) ?? []
        let tags = await dependencies.allTags()
        positiveTagOptions = tags.filter { $0.group != .negative }
        negativeTagOptions = tags.filter { $0.group == .negative }
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

    func togglePositive(_ tagID: String) {
        if let index = positiveTagIDs.firstIndex(of: tagID) {
            positiveTagIDs.remove(at: index)
            tagLegAttribution[tagID] = nil
        } else if positiveTagIDs.count < 5 {
            positiveTagIDs.append(tagID)
        }
    }

    func toggleNegative(_ tagID: String) {
        if let index = negativeTagIDs.firstIndex(of: tagID) {
            negativeTagIDs.remove(at: index)
        } else if negativeTagIDs.count < 3 {
            negativeTagIDs.append(tagID)
        }
    }

    func setAttribution(tagID: String, countryCode: String?) {
        if let countryCode {
            tagLegAttribution[tagID] = countryCode
        } else {
            tagLegAttribution[tagID] = nil
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

            // 선택된 taste 태그에 대해서만 귀속을 남긴다.
            let attribution = tagLegAttribution.filter { positiveTagIDs.contains($0.key) }

            let evaluation = try TripEvaluation(
                satisfaction: satisfaction,
                wouldRepeat: wouldRepeat,
                bestLegCountryCode: isMultiLeg ? bestLegCountryCode : nil,
                comparison: comparison,
                positiveTagIDs: positiveTagIDs,
                negativeTagIDs: negativeTagIDs,
                tagLegAttribution: attribution,
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
            step = .negativeTags
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
