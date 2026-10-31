import Foundation

/// 평가 화면의 단위. 방문 도시마다 한 페이지이고, 저장하면 기록 요약이 나온다.
enum EvaluationStep: Equatable {
    /// 값은 `cityReviews`의 위치다.
    case cityReview(Int)
    case processing
    case result
}

@Observable
final class EvaluationViewModel {
    var trip: Trip?
    var photos: [DailyPhoto] = []

    var step: EvaluationStep = .cityReview(0)
    /// 도시별 별점·메모. 메모는 입력 그대로 두고 제출할 때 공백만 정리한다.
    var cityReviews: [CityReview] = []
    /// 평가 화면에서 고칠 수 있는 여행 컨셉. 의무 여행에는 없다.
    var primaryConcept: TripConcept?
    var secondaryConcepts: [TripConcept] = []

    // 이전에 낸 평가의 값은 고쳐 제출할 때 그대로 넘겨 보존한다. 새 평가는 모두 비어 있다.
    private var keptSatisfaction: Int?
    private var keptWouldRepeat: Bool?
    private var keptBestLegCountryCode: String?
    private var keptComparison: TripComparison?
    private var positiveTagIDs: [String] = []
    private var negativeTagIDs: [String] = []
    private var tagLegAttribution: [String: String] = [:]

    var isSubmitting = false
    /// 이미 제출한 평가를 고치는 중. 이전 답이 채워진 채로 시작한다.
    private(set) var isRevising = false
    var errorMessage: String?
    var didSubmit = false
    /// 제출 결과로 도시 평가를 비워 방문 기록만 남겼는지.
    private(set) var savedAsVisitOnly = false

    var isLeisure: Bool { trip?.purpose == .leisure }

    /// 시트와 요약에 쓰는 컨셉 한 줄. 주 컨셉이 앞이다.
    var conceptsLabelKo: String? {
        guard let primaryConcept else { return nil }
        return ([primaryConcept] + secondaryConcepts).joinedLabel()
    }

    var flowSteps: [EvaluationStep] {
        cityReviews.indices.map(EvaluationStep.cityReview)
    }

    var currentIndex: Int {
        if case .cityReview(let index) = step { return index }
        return 0
    }

    /// 헤더 제목. 도시 이름을 이어 붙이고, 도시가 없으면 나라 이름을 쓴다.
    var headerTitle: String {
        let names = cityReviews.map { $0.city ?? CountryCatalog.name(for: $0.countryCode) }
        return names.joined(separator: " · ")
    }

    func load(tripID: String, dependencies: AppDependencies) async {
        trip = try? await dependencies.store.trip(id: tripID)
        photos = (try? await dependencies.store.photos(tripID: tripID)) ?? []
        cityReviews = trip?.reviewTargets ?? []
        primaryConcept = trip?.concepts?.primary
        secondaryConcepts = trip?.concepts?.secondary ?? []
        step = .cityReview(0)
        if let trip, trip.status == .evaluated || trip.status == .skippedEvaluation {
            isRevising = true
            if let evaluation = trip.evaluation, !evaluation.skipped {
                prefill(from: evaluation)
            }
        }
    }

    private func prefill(from evaluation: TripEvaluation) {
        keptSatisfaction = evaluation.satisfaction
        keptWouldRepeat = evaluation.wouldRepeat
        keptBestLegCountryCode = evaluation.bestLegCountryCode
        keptComparison = evaluation.comparison
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

    /// 마지막 도시 페이지에서 제출한다.
    var isLastStep: Bool {
        flowSteps.last == step
    }

    func goBack() {
        if case .cityReview(let index) = step, index > 0 { step = .cityReview(index - 1) }
    }

    func advance() {
        if case .cityReview(let index) = step, index + 1 < cityReviews.count {
            step = .cityReview(index + 1)
        }
    }

    /// 이 도시는 적지 않고 넘어간다. 입력해 둔 별점·메모도 비운다.
    func clearCurrentCity() {
        guard case .cityReview(let index) = step, cityReviews.indices.contains(index) else { return }
        cityReviews[index].rating = nil
        cityReviews[index].liked = nil
        cityReviews[index].disliked = nil
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
        guard let trip else { return }
        isSubmitting = true
        errorMessage = nil
        step = .processing
        defer { isSubmitting = false }
        do {
            let reviews = submittedCityReviews
            // 적은 것이 하나도 없으면 방문 사실만 남긴다.
            let visitOnly = reviews.isEmpty && keptSatisfaction == nil
            let countries = Set(trip.legs.map(\.countryCode))
            let evaluation = try TripEvaluation(
                satisfaction: visitOnly ? nil : keptSatisfaction,
                wouldRepeat: visitOnly ? nil : keptWouldRepeat,
                bestLegCountryCode: keptBestLegCountryCode.flatMap { countries.contains($0) && trip.legs.count > 1 ? $0 : nil },
                comparison: visitOnly ? nil : keptComparison,
                positiveTagIDs: positiveTagIDs,
                negativeTagIDs: negativeTagIDs,
                tagLegAttribution: tagLegAttribution,
                cityReviews: reviews,
                source: .postTrip,
                skipped: visitOnly
            )
            if isRevising {
                _ = try await dependencies.evaluationService.revise(
                    tripID: trip.id, evaluation: evaluation, userID: session.userID
                )
            } else {
                _ = try await dependencies.evaluationService.submit(
                    tripID: trip.id, evaluation: evaluation, userID: session.userID
                )
            }
            try await saveConceptsIfChanged(trip: trip, dependencies: dependencies)
            savedAsVisitOnly = visitOnly
            self.trip = try? await dependencies.store.trip(id: trip.id)
            didSubmit = true
            EvaluationNotificationService.cancel(for: trip.id)
            step = .result
        } catch {
            errorMessage = String(localized: "Couldn’t save your evaluation. Please check what you entered.")
            step = flowSteps.last ?? .cityReview(0)
        }
    }

    private func saveConceptsIfChanged(trip: Trip, dependencies: AppDependencies) async throws {
        guard trip.purpose == .leisure, let primaryConcept else { return }
        let edited = try TripConcepts(primary: primaryConcept, secondary: secondaryConcepts)
        guard edited != trip.concepts else { return }
        _ = try await dependencies.tripService.updateTrip(
            id: trip.id, legs: trip.legs, companion: trip.companion, purpose: trip.purpose, concepts: edited
        )
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
