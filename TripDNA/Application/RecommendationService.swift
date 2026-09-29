import Foundation

nonisolated struct RecommendationConfiguration: Equatable, Sendable {
    var tasteWeight = 0.8
    var interestWeight = 0.2
    var freshStretchTasteFloor = 0.55
    /// 이전 버전의 180일 기한 싫어요가 만료된 뒤 남는 감점. 새 싫어요는 기한이 없다.
    var dislikePenalty = 0.45
    /// fresh_stretch/underrated_fit은 "다르지만 넓혀볼 만한" 혹은 "저평가된" 후보를 위한 슬롯이므로,
    /// 매치 스코어가 이 값 이상이면 사실상 베스트 매치이므로 두 슬롯 후보에서 제외한다.
    var nonBestSlotMatchScoreCeiling = 0.95
    /// 두 후보의 정렬 기준 차이가 이 값 이하면 사실상 같은 점수로 본다.
    var tieEpsilon = 0.005
    /// 매칭축 평균 신뢰도가 이 값에 이르면 지문을 그대로 믿는다. 그 아래면 매치 스코어를
    /// 중립(0.5) 쪽으로 당기고 동점 폭을 넓혀, 아직 모르는 것을 단정하지 않는다.
    /// 가중 코사인은 축 사이의 상대 비율만 반영하므로(신뢰도가 모든 축에서 같으면 약분된다)
    /// 전체 확신 수준은 이 값을 거쳐야 추천에 반영된다.
    var confidenceFullTrust = 0.6
    /// 확신이 전혀 없을 때 `tieEpsilon`에 더해지는 폭. 신뢰도가 낮을수록 더 많은 후보를
    /// 사실상 동점으로 묶어, 근거 없는 1순위 단정과 슬롯 강제 충족을 막는다.
    var lowConfidenceTieEpsilon = 0.03
    /// best_match와 사실상 동점인 후보가 이 수 이상이면, 1순위를 단정하지 않고
    /// 동점 사실을 카드에 표시한다. 나머지 두 슬롯은 1순위가 2순위보다 확실히
    /// 나을 때만 채운다(근거 없는 슬롯 강제 충족 금지).
    var tieDisclosureGroupSize = 3
}

nonisolated struct RecommendationService {
    static let modelVersion = "country-cosine-v2-breadth"
    let countries: any CountryRepository
    let feedbackRepository: any FeedbackRepository
    let events: any EventRepository
    let configuration: RecommendationConfiguration

    init(
        countries: any CountryRepository,
        feedbackRepository: any FeedbackRepository,
        events: any EventRepository,
        configuration: RecommendationConfiguration = .init()
    ) {
        self.countries = countries
        self.feedbackRepository = feedbackRepository
        self.events = events
        self.configuration = configuration
    }

    func generateThreeSlots(
        vector: UserTasteVector,
        interestTagIDs: Set<String>,
        visitedCountryCodes: Set<String>,
        rankedTrips: [Trip] = [],
        now: Date = Date()
    ) async throws -> [Recommendation] {
        let allProfiles = try await countries.profiles()
        let allFeedback = try await feedbackRepository.feedback()
        let trust = trustLevel(vector: vector, profiles: allProfiles)
        let tieEpsilon = self.tieEpsilon(trust: trust)
        let candidates = scoredCandidates(
            profiles: allProfiles,
            vector: vector,
            interestTagIDs: interestTagIDs,
            visitedCountryCodes: visitedCountryCodes,
            feedback: allFeedback,
            trust: trust,
            now: now
        )
        guard !candidates.isEmpty else { return [] }

        var used = Set<String>()
        var results: [Recommendation] = []
        let byMatchScore = ranked(candidates) { $0.matchScore }
        if let best = byMatchScore.first {
            results.append(makeRecommendation(
                candidate: best,
                slot: .bestMatch,
                interestTagIDs: interestTagIDs,
                rankedTrips: rankedTrips,
                profiles: allProfiles,
                notices: tieNotices(for: byMatchScore, tieEpsilon: tieEpsilon) { $0.matchScore }
            ))
            used.insert(best.profile.countryCode)
        }

        let fresh = pickDistinct(
            from: byMatchScore.filter {
                !used.contains($0.profile.countryCode)
                    && $0.tasteFit >= configuration.freshStretchTasteFloor
                    && $0.matchScore < configuration.nonBestSlotMatchScoreCeiling
            },
            by: { noveltyDistance($0.profile.tasteCore, vector.axes, excluding: vector.acceptedAxes ?? []) },
            tieEpsilon: tieEpsilon
        )
        if let fresh {
            results.append(makeRecommendation(
                candidate: fresh,
                slot: .freshStretch,
                interestTagIDs: interestTagIDs,
                rankedTrips: rankedTrips,
                profiles: allProfiles
            ))
            used.insert(fresh.profile.countryCode)
        }

        let underrated = pickDistinct(
            from: byMatchScore.filter {
                !used.contains($0.profile.countryCode)
                    && $0.matchScore < configuration.nonBestSlotMatchScoreCeiling
            },
            by: underratedScore,
            tieEpsilon: tieEpsilon
        )
        if let underrated {
            results.append(makeRecommendation(
                candidate: underrated,
                slot: .underratedFit,
                interestTagIDs: interestTagIDs,
                rankedTrips: rankedTrips,
                profiles: allProfiles
            ))
        }
        return results
    }

    func applyFeedback(
        countryCode: String,
        slot: RecommendationSlot,
        action: FeedbackAction,
        reason: FeedbackReason? = nil,
        exposureSetID: String? = nil,
        at date: Date = Date()
    ) async throws -> CardFeedback {
        let feedback = CardFeedback(
            id: UUID().uuidString,
            countryCode: countryCode,
            slot: slot,
            action: action,
            reason: reason,
            excludeUntil: nil,
            revokedAt: nil,
            createdAt: date
        )
        try await feedbackRepository.create(feedback)
        try await events.append(AnalyticsEvent(
            type: .recommendationFeedback,
            payload: [
                "countryCode": countryCode,
                "slot": slot.rawValue,
                "action": action.rawValue,
                "reason": reason?.rawValue ?? "unspecified",
                "exposureSetID": exposureSetID ?? "unavailable"
            ],
            createdAt: date
        ))
        return feedback
    }

    /// "앞으로도 관심 없어요"를 취소한다. 같은 나라에 남은 제외 기록을 모두 거둔다.
    func revokeDislike(countryCode: String, at date: Date = Date()) async throws {
        for var item in try await feedbackRepository.feedback()
        where item.countryCode == countryCode && item.action == .dislike && item.revokedAt == nil {
            item.revoke(at: date)
            try await feedbackRepository.update(item)
        }
    }

    /// 지금 추천에서 빠져 있는 나라. 나라마다 가장 최근 기록 하나만 돌려준다.
    func activeDislikes(now: Date = Date()) async throws -> [CardFeedback] {
        var seen = Set<String>()
        return try await feedbackRepository.feedback()
            .filter { isActiveDislike($0, now: now) }
            .sorted { $0.createdAt > $1.createdAt }
            .filter { seen.insert($0.countryCode).inserted }
    }

    private struct Candidate {
        let profile: CountryProfile
        let tasteFit: Double
        let interestFit: Double
        let matchScore: Double
    }

    /// 지문 전체의 확신 수준(0~1). 1이면 감쇠 없이 그대로 믿는다.
    /// 후보마다 다른 `matchingAxes` 대신 전체 합집합으로 계산해, 같은 지문에는 항상 같은
    /// 값이 나오게 한다(후보별로 다르면 감쇠가 순위 자체를 흔든다).
    private func trustLevel(vector: UserTasteVector, profiles: [CountryProfile]) -> Double {
        guard configuration.confidenceFullTrust > 0 else { return 1 }
        let matchingAxes = profiles.reduce(into: Set<TasteAxis>()) { $0.formUnion($1.matchingAxes) }
        let axes = matchingAxes.isEmpty ? Set([TasteAxis.natureUrban]) : matchingAxes
        let mean = axes.reduce(0.0) { $0 + vector.confidence[$1] } / Double(axes.count)
        return min(max(mean / configuration.confidenceFullTrust, 0), 1)
    }

    /// 확신이 낮으면 매치 스코어를 중립값으로 당긴다. 순위는 그대로 두고 격차만 좁히므로,
    /// 카드에 "92% 일치"처럼 근거 없이 단호한 숫자가 뜨는 것을 막는다.
    private func trustAdjusted(_ tasteFit: Double, trust: Double) -> Double {
        0.5 + (tasteFit - 0.5) * trust
    }

    private func tieEpsilon(trust: Double) -> Double {
        configuration.tieEpsilon + (1 - trust) * configuration.lowConfidenceTieEpsilon
    }

    private func scoredCandidates(
        profiles: [CountryProfile],
        vector: UserTasteVector,
        interestTagIDs: Set<String>,
        visitedCountryCodes: Set<String>,
        feedback: [CardFeedback],
        trust: Double,
        now: Date
    ) -> [Candidate] {
        profiles.compactMap { profile in
            guard profile.status == .confirmed,
                  !visitedCountryCodes.contains(profile.countryCode),
                  !isActivelyExcluded(profile.countryCode, feedback: feedback, now: now) else {
                return nil
            }
            let tasteFit = weightedCosineSimilarity(
                vector.axes,
                profile.tasteCore,
                confidence: vector.confidence,
                allowedAxes: profile.matchingAxes.isEmpty ? [.natureUrban] : profile.matchingAxes,
                acceptedAxes: vector.acceptedAxes ?? []
            )
            let interestFit = averageInterestFit(profile, selected: interestTagIDs)
            // tasteFit 원본은 fresh_stretch 문턱 판정에 그대로 쓰고, 확신 감쇠는
            // 노출·정렬에 쓰이는 매치 스코어에만 반영한다.
            var score = configuration.tasteWeight * trustAdjusted(tasteFit, trust: trust)
                + configuration.interestWeight * interestFit
            if hasExpiredDislike(profile.countryCode, feedback: feedback, now: now) {
                score *= configuration.dislikePenalty
            }
            return Candidate(
                profile: profile,
                tasteFit: tasteFit,
                interestFit: interestFit,
                matchScore: min(max(score, 0), 1)
            )
        }
    }

    /// 기준값 내림차순, 값이 같으면 국가 코드 오름차순으로 정렬한다.
    /// 타이브레이커가 없으면 동점 후보 중 무엇이 뽑히는지가 저장소의 순회 순서에
    /// 좌우되어 같은 입력에도 실행마다 결과가 달라진다.
    private func ranked(
        _ candidates: [Candidate],
        by score: (Candidate) -> Double
    ) -> [Candidate] {
        let scored: [(candidate: Candidate, value: Double)] = candidates.map {
            (candidate: $0, value: score($0))
        }
        let ordered = scored.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.candidate.profile.countryCode < rhs.candidate.profile.countryCode
        }
        return ordered.map(\.candidate)
    }

    /// 1순위와 사실상 동점인 후보 수(1순위 포함). 입력은 같은 기준으로 정렬돼 있어야 한다.
    private func tieGroupSize(
        _ ordered: [Candidate],
        tieEpsilon: Double,
        by score: (Candidate) -> Double
    ) -> Int {
        guard let top = ordered.first.map(score) else { return 0 }
        return ordered.prefix { abs(score($0) - top) <= tieEpsilon }.count
    }

    /// 1순위가 2순위보다 확실히 나을 때만 후보를 고른다. 사실상 동점이면 그 슬롯을
    /// 고를 근거가 없다는 뜻이므로, 억지로 채우지 않고 비운다.
    private func pickDistinct(
        from candidates: [Candidate],
        by score: (Candidate) -> Double,
        tieEpsilon: Double
    ) -> Candidate? {
        let ordered = ranked(candidates, by: score)
        guard tieGroupSize(ordered, tieEpsilon: tieEpsilon, by: score) == 1 else { return nil }
        return ordered.first
    }

    /// best_match는 비울 수 없으므로, 동점 그룹이 크면 1순위를 단정하는 대신 그 사실을 알린다.
    private func tieNotices(
        for ordered: [Candidate],
        tieEpsilon: Double,
        by score: (Candidate) -> Double
    ) -> [String] {
        let size = tieGroupSize(ordered, tieEpsilon: tieEpsilon, by: score)
        guard size >= configuration.tieDisclosureGroupSize else { return [] }
        return ["지금 지문으로는 이 나라를 포함해 \(size)곳이 거의 같은 점수예요. "
                + "여행 기록이 쌓이면 순위가 더 뚜렷해져요."]
    }

    private func makeRecommendation(
        candidate: Candidate,
        slot: RecommendationSlot,
        interestTagIDs: Set<String>,
        rankedTrips: [Trip],
        profiles: [CountryProfile],
        notices: [String] = []
    ) -> Recommendation {
        // Set의 순회 순서는 실행마다 다르므로, 값이 같은 태그는 id 순으로 고정한다.
        let explanationTags = interestTagIDs
            .compactMap { id -> (id: String, value: Double)? in
                guard let value = candidate.profile.interestTags[id] ?? nil else { return nil }
                return (id, value)
            }
            .sorted { $0.value == $1.value ? $0.id < $1.id : $0.value > $1.value }
            .map(\.id)
        let anchorID = rankingAnchor(
            for: candidate.profile,
            rankedTrips: rankedTrips,
            profiles: profiles
        )
        let costBadge = costBadge(for: candidate.profile.constraints.cost)
        return Recommendation(
            countryCode: candidate.profile.countryCode,
            slot: slot,
            matchScore: candidate.matchScore,
            explanationTagIDs: Array(explanationTags.prefix(2)),
            rankingAnchorTripID: anchorID,
            fitBadges: [costBadge],
            notices: notices
        )
    }

    private func rankingAnchor(
        for candidate: CountryProfile,
        rankedTrips: [Trip],
        profiles: [CountryProfile]
    ) -> String? {
        let byCode = Dictionary(uniqueKeysWithValues: profiles.map { ($0.countryCode, $0) })
        return rankedTrips.prefix(5).max { lhs, rhs in
            let left = lhs.legs.compactMap { byCode[$0.countryCode] }
                .map { cosine($0.tasteCore, candidate.tasteCore) }
                .max() ?? -1
            let right = rhs.legs.compactMap { byCode[$0.countryCode] }
                .map { cosine($0.tasteCore, candidate.tasteCore) }
                .max() ?? -1
            return left < right
        }?.id
    }

    private func weightedCosineSimilarity(
        _ lhs: TasteAxes,
        _ rhs: TasteAxes,
        confidence: AxisConfidence,
        allowedAxes: Set<TasteAxis>,
        acceptedAxes: Set<TasteAxis>
    ) -> Double {
        // An explicitly broad axis must not penalize either pole via the norm.
        // All-broad preferences leave ranking to other evidence; do not invent fit.
        let axes = allowedAxes.subtracting(acceptedAxes)
        var dot = 0.0
        var lhsLength = 0.0
        var rhsLength = 0.0
        for axis in axes {
            let weight = max(confidence[axis], 0.05)
            dot += weight * lhs[axis] * rhs[axis]
            lhsLength += weight * lhs[axis] * lhs[axis]
            rhsLength += weight * rhs[axis] * rhs[axis]
        }
        guard lhsLength > 0, rhsLength > 0 else { return 0.5 }
        return (dot / (sqrt(lhsLength) * sqrt(rhsLength)) + 1) / 2
    }

    private func cosine(_ lhs: TasteAxes, _ rhs: TasteAxes) -> Double {
        var dot = 0.0
        var lhsLength = 0.0
        var rhsLength = 0.0
        for axis in TasteAxis.allCases {
            dot += lhs[axis] * rhs[axis]
            lhsLength += lhs[axis] * lhs[axis]
            rhsLength += rhs[axis] * rhs[axis]
        }
        guard lhsLength > 0, rhsLength > 0 else { return 0 }
        return dot / (sqrt(lhsLength) * sqrt(rhsLength))
    }

    private func noveltyDistance(_ lhs: TasteAxes, _ rhs: TasteAxes, excluding: Set<TasteAxis>) -> Double {
        sqrt(TasteAxis.allCases.filter { !excluding.contains($0) }.reduce(0) { partial, axis in
            partial + pow(lhs[axis] - rhs[axis], 2)
        })
    }

    private func averageInterestFit(_ profile: CountryProfile, selected: Set<String>) -> Double {
        guard !selected.isEmpty else { return 0.5 }
        let values = selected.compactMap { profile.interestTags[$0] ?? nil }
        guard !values.isEmpty else { return 0.5 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func underratedScore(_ candidate: Candidate) -> Double {
        let lowPopularity = 1 - (candidate.profile.popularity ?? 0.5)
        return 0.55 * candidate.matchScore + 0.25 * candidate.interestFit + 0.20 * lowPopularity
    }

    private func isActivelyExcluded(
        _ countryCode: String,
        feedback: [CardFeedback],
        now: Date
    ) -> Bool {
        feedback.contains { $0.countryCode == countryCode && isActiveDislike($0, now: now) }
    }

    /// 기한이 없는 싫어요는 취소할 때까지 유효하다.
    private func isActiveDislike(_ item: CardFeedback, now: Date) -> Bool {
        item.action == .dislike
            && item.revokedAt == nil
            && (item.excludeUntil ?? .distantFuture) > now
    }

    private func hasExpiredDislike(
        _ countryCode: String,
        feedback: [CardFeedback],
        now: Date
    ) -> Bool {
        feedback.contains {
            guard let until = $0.excludeUntil else { return false }
            return $0.countryCode == countryCode
                && $0.action == .dislike
                && $0.revokedAt == nil
                && until <= now
        }
    }

    private func costBadge(for cost: Double) -> String {
        switch cost {
        case ..<0.34: "물가 낮은 편"
        case ..<0.67: "물가 보통"
        default: "물가 높은 편"
        }
    }
}
