import Foundation

// MARK: - 상황 필터 (UI-4B)

/// 예산 범위 필터. 국가 프로필의 상대 물가 지수(constraints.cost)에 대한
/// 상한(ceiling)으로만 쓴다. 예산이 높다고 비싼 곳을 선호하지 않고,
/// 예산이 낮으면 물가 높은 곳을 후보에서 제외한다. 예산 적합을 단정하지 않는다.
enum BudgetLevel: String, CaseIterable, Identifiable, Sendable {
    case low, medium, high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low: String(localized: "Low")
        case .medium: String(localized: "Medium")
        case .high: String(localized: "High")
        }
    }

    /// 예산 상한 안에 들어가는지. 물가 배지 경계(0.34 / 0.67)를 그대로 쓴다.
    /// - 낮음: 물가 낮은 곳만
    /// - 중간: 물가 낮음·보통
    /// - 높음: 제한 없음(비싼 곳도 갈 수 있음 ≠ 비싼 곳만)
    func matches(cost: Double) -> Bool {
        switch self {
        case .low: cost < 0.34
        case .medium: cost < 0.67
        case .high: true
        }
    }
}

struct RecommendationFilter: Equatable {
    var budget: BudgetLevel?
    /// "사는 나라도 포함". 기본 끔이며 기기에 저장하지 않는다.
    var includeHomeCountry = false

    var isActive: Bool { budget != nil || includeHomeCountry }

    /// 메인 화면 상단에 노출할 활성 필터 요약.
    var summary: [String] {
        var parts: [String] = []
        if let budget {
            parts.append(String(localized: "Budget \(budget.label)"))
        }
        if includeHomeCountry {
            parts.append(String(localized: "Home country included"))
        }
        return parts
    }
}

// MARK: - 국기 이모지

/// ISO 3166-1 alpha-2 국가 코드를 유니코드 지역 지시자 국기 이모지로 변환한다.
enum CountryFlag {
    static func emoji(for countryCode: String) -> String {
        let scalars = countryCode.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }
        guard scalars.count == 2 else { return "🌍" }
        return String(String.UnicodeScalarView(scalars))
    }
}

// MARK: - ViewModel

@Observable
final class RecommendationViewModel {
    var slots: [Recommendation] = []
    var savedFeedback: [CardFeedback] = []
    /// "앞으로도 관심 없어요"로 뺀 나라. 저장 목록에서 되돌릴 수 있다.
    var dislikedFeedback: [CardFeedback] = []
    var isLoading = false
    var errorMessage: String?
    var filter = RecommendationFilter()
    /// 입력 시트에서 받은 이번 여행 조건. 생성에는 아직 쓰지 않는다(사는 나라 포함만 filter로 옮김).
    private(set) var request = RecommendationRequest()
    /// 입력 시트로 추천을 받은 적이 있는지. false면 추천 탭은 빈 상태를 보여준다.
    private(set) var hasRequested = false
    /// "저장했어요" 같은 짧은 확인 피드백. nil이 아니면 토스트를 띄운다.
    var toastMessage: String?

    /// 슬롯별 최종 반응. save/dislike가 기록되며, 스킵 후보가 소진된 슬롯은 skip으로 기록된다.
    /// 3장 모두 채워지면 "새 추천 보기" CTA를 노출한다(무한 자동 로딩 금지).
    private(set) var slotReactions: [RecommendationSlot: FeedbackAction] = [:]
    /// 저장 시점의 추천 스냅샷. 저장 목록에서 "저장 시점의 이유"를 유지하기 위해 보관한다.
    private(set) var savedSnapshots: [String: Recommendation] = [:]

    private var vector: UserTasteVector?
    private var visitedCountryCodes: Set<String> = []
    private var sessionExcluded: Set<String> = []
    private var rankedTrips: [Trip] = []

    var hasFingerprint: Bool { vector != nil }

    var allSlotsReacted: Bool {
        !slots.isEmpty && slots.allSatisfy { slotReactions[$0.slot] != nil }
    }

    func reaction(for slot: RecommendationSlot) -> FeedbackAction? {
        slotReactions[slot]
    }

    // MARK: 로드/갱신

    func load(_ dependencies: AppDependencies) async {
        isLoading = true
        defer { isLoading = false }

        let trips = await dependencies.allTrips()
        visitedCountryCodes = Set(trips.flatMap { $0.legs.map(\.countryCode) })
        let ranking = try? await dependencies.store.currentRanking()
        rankedTrips = ranking?.tripIDsOrdered.compactMap { id in trips.first { $0.id == id } } ?? []
        vector = try? await dependencies.store.currentUTV()
        await refreshSlots(dependencies)
        await refreshSavedList(dependencies)
        await refreshDislikedList(dependencies)
    }

    func refreshSlots(_ dependencies: AppDependencies) async {
        guard vector != nil else {
            errorMessage = String(localized: "You don't have a taste fingerprint yet.")
            return
        }
        slots = await generateSlots(dependencies)
        slotReactions = [:]
    }

    /// 3장 모두 반응한 뒤 "새 추천 보기"를 눌렀을 때. 현재 세트는 세션에서 제외하고 새 세트를 만든다.
    func loadNewSet(_ dependencies: AppDependencies) async {
        sessionExcluded.formUnion(slots.map(\.countryCode))
        await refreshSlots(dependencies)
    }

    /// 후보가 소진됐을 때 세션 제외 목록을 비우고 처음부터 다시 본다.
    func restartSession(_ dependencies: AppDependencies) async {
        sessionExcluded = []
        await refreshSlots(dependencies)
    }

    // MARK: 필터 (UI-4B)

    func applyFilter(_ dependencies: AppDependencies) async {
        await refreshSlots(dependencies)
    }

    func submit(_ request: RecommendationRequest, _ dependencies: AppDependencies) async {
        guard request.isReady else { return }
        self.request = request
        filter.includeHomeCountry = request.includeHomeCountry
        hasRequested = true
        await refreshSlots(dependencies)
    }

    func resetFilter() {
        filter = RecommendationFilter()
    }

    // MARK: 반응 (UI-4E)

    func save(_ recommendation: Recommendation, dependencies: AppDependencies) async {
        guard slotReactions[recommendation.slot] == nil else { return }
        _ = try? await dependencies.recommendationService.applyFeedback(
            countryCode: recommendation.countryCode,
            slot: recommendation.slot,
            action: .save
        )
        slotReactions[recommendation.slot] = .save
        savedSnapshots[recommendation.countryCode] = recommendation
        toastMessage = String(localized: "Saved")
        await refreshSavedList(dependencies)
    }

    /// "이번엔 아니에요": 이번 세션에서만 빼고 같은 슬롯을 다음 후보로 바꾼다.
    /// 취향 신호가 아니므로 저장소에 남기지 않는다(README §8).
    func skip(_ recommendation: Recommendation, dependencies: AppDependencies) async {
        sessionExcluded.insert(recommendation.countryCode)
        await replaceSlot(recommendation.slot, dependencies: dependencies)
    }

    /// "앞으로도 관심 없어요": 이유는 선택 사항. 되돌리기 전까지 추천에서 빠진다.
    /// 되돌리기 오버레이를 잠시 보여준 뒤 같은 슬롯을 다음 후보로 교체한다.
    func dislike(
        _ recommendation: Recommendation,
        reason: FeedbackReason?,
        dependencies: AppDependencies
    ) async {
        _ = try? await dependencies.recommendationService.applyFeedback(
            countryCode: recommendation.countryCode,
            slot: recommendation.slot,
            action: .dislike,
            reason: reason
        )
        sessionExcluded.insert(recommendation.countryCode)
        slotReactions[recommendation.slot] = .dislike
        await refreshDislikedList(dependencies)

        try? await Task.sleep(for: .seconds(3))

        // 대기 중 세트가 바뀌었거나 다른 반응으로 덮이면 교체하지 않는다.
        guard slots.contains(where: {
            $0.slot == recommendation.slot && $0.countryCode == recommendation.countryCode
        }),
              slotReactions[recommendation.slot] == .dislike
        else { return }

        await replaceSlot(recommendation.slot, dependencies: dependencies)
    }

    /// 슬롯 카드를 다음 후보로 바꾸고, 없으면 소진 상태로 표시한다.
    /// 다른 슬롯에 이미 보이는 국가는 제외하고 다시 뽑아, 1순위가 화면에 겹쳐
    /// 소진으로 오판되는 경우를 막는다.
    private func replaceSlot(_ slot: RecommendationSlot, dependencies: AppDependencies) async {
        let otherSlotCountries = Set(
            slots.filter { $0.slot != slot }.map(\.countryCode)
        )
        let fresh = await generateSlots(dependencies, alsoExcluding: otherSlotCountries)
        if let replacement = fresh.first(where: { $0.slot == slot }),
           !slots.contains(where: { $0.countryCode == replacement.countryCode }),
           let index = slots.firstIndex(where: { $0.slot == slot }) {
            slots[index] = replacement
            slotReactions[slot] = nil
        } else {
            slotReactions[slot] = .skip
        }
    }

    /// 방금 누른 "관심 없어요"를 카드 위에서 바로 취소한다.
    func undoDislike(_ recommendation: Recommendation, dependencies: AppDependencies) async {
        guard slotReactions[recommendation.slot] == .dislike else { return }
        try? await dependencies.recommendationService.revokeDislike(countryCode: recommendation.countryCode)
        sessionExcluded.remove(recommendation.countryCode)
        slotReactions[recommendation.slot] = nil
        await refreshDislikedList(dependencies)
    }

    func revokeDislike(_ feedback: CardFeedback, dependencies: AppDependencies) async {
        do {
            try await dependencies.recommendationService.revokeDislike(countryCode: feedback.countryCode)
            sessionExcluded.remove(feedback.countryCode)
            await refreshDislikedList(dependencies)
            toastMessage = String(localized: "We'll include it in recommendations again")
        } catch {
            errorMessage = String(localized: "Couldn't undo that. Please try again.")
        }
    }

    func refreshDislikedList(_ dependencies: AppDependencies) async {
        dislikedFeedback = (try? await dependencies.recommendationService.activeDislikes()) ?? []
    }

    // MARK: 저장 목록 (UI-4D)

    func refreshSavedList(_ dependencies: AppDependencies) async {
        let feedback = (try? await dependencies.store.feedback()) ?? []
        var seenCountryCodes = Set<String>()
        savedFeedback = feedback
            .filter { $0.action == .save }
            .sorted { $0.createdAt > $1.createdAt }
            .filter { seenCountryCodes.insert($0.countryCode).inserted }
    }

    func unsave(_ feedback: CardFeedback, dependencies: AppDependencies) async {
        do {
            try await dependencies.unsaveRecommendation(countryCode: feedback.countryCode)
            savedSnapshots[feedback.countryCode] = nil
            await refreshSavedList(dependencies)
        } catch {
            errorMessage = String(localized: "Couldn't remove the save. Please try again.")
        }
    }

    // MARK: 설명 문구 (슬롯 설명 체계: 태그 인용 > 랭킹 앵커 > 축 폴백)

    func reasonText(for recommendation: Recommendation) -> String {
        let quotedTags = recommendation.explanationTagIDs
            .map { "'\(TagCatalog.label(for: $0))'" }
            .joined(separator: "·")

        switch recommendation.slot {
        case .bestMatch:
            if let anchor = anchorTripTitle(recommendation.rankingAnchorTripID), !quotedTags.isEmpty {
                return String(localized: "Similar to the \(quotedTags) you picked on \(anchor)")
            }
            if !quotedTags.isEmpty {
                return String(localized: "The best match for your \(quotedTags) taste")
            }
            if let anchor = anchorTripTitle(recommendation.rankingAnchorTripID) {
                return String(localized: "Similar in feel to your top-ranked \(anchor) trip")
            }
            return String(localized: "The best match for your current fingerprint")
        case .freshStretch:
            if !quotedTags.isEmpty {
                return String(localized: "A half step outside your usual taste. \(quotedTags) stays the same")
            }
            return String(localized: "A half step outside your usual taste")
        case .underratedFit:
            if !quotedTags.isEmpty {
                return String(localized: "If you like \(quotedTags), this could be a surprisingly good fit")
            }
            return String(localized: "You may not have thought of it yet, but it suits your taste")
        }
    }

    /// 저장 목록에서 보여줄, 저장 시점의 추천 이유.
    func savedReasonText(for feedback: CardFeedback) -> String {
        if let snapshot = savedSnapshots[feedback.countryCode] {
            return reasonText(for: snapshot)
        }
        return feedback.slot.subtitle
    }

    // MARK: 내부

    private func generateSlots(
        _ dependencies: AppDependencies,
        alsoExcluding: Set<String> = []
    ) async -> [Recommendation] {
        guard let vector else { return [] }
        let excluded = dependencies.excludedCountryCodes(
            visited: visitedCountryCodes
                .union(sessionExcluded)
                .union(budgetExcludedCountryCodes())
                .union(alsoExcluding),
            includingHomeCountry: filter.includeHomeCountry
        )
        return (try? await dependencies.recommendationService.generateThreeSlots(
            vector: vector,
            interestTagIDs: dependencies.interestTagIDs,
            visitedCountryCodes: excluded,
            rankedTrips: rankedTrips
        )) ?? []
    }

    /// 예산 상한을 넘는 물가의 국가를 후보에서 제외한다.
    private func budgetExcludedCountryCodes() -> Set<String> {
        guard let budget = filter.budget else { return [] }
        return Set(
            CountryCatalog.profiles.values
                .filter { !budget.matches(cost: $0.constraints.cost) }
                .map(\.countryCode)
        )
    }

    private func anchorTripTitle(_ tripID: String?) -> String? {
        guard let tripID else { return nil }
        return rankedTrips.first { $0.id == tripID }?.titleKo
    }
}
