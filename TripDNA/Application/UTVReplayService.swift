import Foundation

nonisolated struct UTVReplayConfiguration: Equatable, Sendable {
    var rankWeight = 0.7
    var positiveTagAlpha = 0.3
    var maximumStep = 0.25
    /// 첫 여가 여행이 고평가(만족도 높음)일 때 허용하는 1회 스텝 상한.
    var firstTripHighSatisfactionStep = 0.45
    var axisConfidenceK = 4.0
    var minimumLearningRate = 0.1
    var positiveGainMultiplier = 1.5
    var negativeGain = -0.5
    var skippedEvaluationCap = 0.5
    /// 만족도 중간·태그 없음처럼 게인이 0이 되는 경우에도, 방문 사실만큼은 아주 약하게 반영.
    var visitPriorGainFloor = 0.08
    /// 첫 여가 여행 고평가 시 게인 배율. 축은 세게, 신뢰도는 별도 캡으로 낮게 유지.
    var firstTripHighSatisfactionGainBoost = 1.8
    /// 평가된 여가 여행 1회당 축 신호 가산(태그·비교가 없어도 신뢰도 0에 고정되지 않게).
    var visitSignalWeight = 0.3
    /// 초반(여행 2회 이하) 신뢰도 상한 — 한두 여행에 과신하지 않음.
    var coldStartConfidenceCap = 0.35
    var coldStartConfidenceTripLimit = 2
    var feedbackWeight = 0.4
    var staleHalfLifeMonths = 24.0
    var minimumStaleFactor = 0.4
}

nonisolated struct UTVReplayResult: Equatable, Sendable {
    let vector: UserTasteVector
    let delta: TasteAxes
    let deferredTripIDs: [String]
}

nonisolated struct UTVReplayService {
    let configuration: UTVReplayConfiguration
    let calendar: Calendar

    init(
        configuration: UTVReplayConfiguration = .init(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.configuration = configuration
        self.calendar = calendar
    }

    func replay(
        userID: String,
        trips: [Trip],
        ranking: TripRanking?,
        countries: [CountryProfile],
        tags: [TagDefinition],
        feedback: [CardFeedback] = [],
        prior: TasteAxes = .zero,
        previous: UserTasteVector? = nil,
        now: Date = Date()
    ) -> UTVReplayResult {
        let countryByCode = Dictionary(uniqueKeysWithValues: countries.map { ($0.countryCode, $0) })
        let tagByID = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        let eligibleTrips = trips
            .filter { $0.status == .evaluated || $0.status == .skippedEvaluation }
            .sorted { replayDate(for: $0) < replayDate(for: $1) }
        let rankByID = ranking.map {
            Dictionary(uniqueKeysWithValues: $0.tripIDsOrdered.enumerated().map { ($0.element, $0.offset + 1) })
        } ?? [:]

        var axes = prior.clamped()
        var signalCounts = TasteAxes.zero
        var lastSignalDates: [TasteAxis: Date] = [:]
        var deferredTripIDs: [String] = []

        var appliedTripCount = 0
        for trip in eligibleTrips {
            guard let evaluation = trip.evaluation,
                  let tripVector = calculateTripVector(
                    trip: trip,
                    evaluation: evaluation,
                    countries: countryByCode,
                    tags: tagByID
                  ) else {
                deferredTripIDs.append(trip.id)
                continue
            }

            let calibratedSatisfaction = calibratedSatisfaction(
                evaluation: evaluation,
                rank: rankByID[trip.id],
                rankedTripCount: rankByID.count
            )
            let learningRate = appliedTripCount >= 8
                ? configuration.minimumLearningRate
                : max(configuration.minimumLearningRate, 1.0 / Double(appliedTripCount + 1))
            let isFirstHighSatisfactionLeisure = appliedTripCount == 0
                && trip.purpose == .leisure
                && !evaluation.skipped
                && calibratedSatisfaction >= 0.75
            let stepLimit = isFirstHighSatisfactionLeisure
                ? configuration.firstTripHighSatisfactionStep
                : configuration.maximumStep
            let eventDate = replayDate(for: trip)

            for axis in TasteAxis.allCases {
                var gain = axisGain(
                    axis: axis,
                    evaluation: evaluation,
                    purpose: trip.purpose,
                    calibratedSatisfaction: calibratedSatisfaction,
                    tags: tagByID
                )
                if isFirstHighSatisfactionLeisure, gain > 0 {
                    gain = min(gain * configuration.firstTripHighSatisfactionGainBoost, 1)
                }
                let skippedMultiplier = evaluation.skipped ? configuration.skippedEvaluationCap : 1
                let raw = axes[axis] + learningRate * gain * skippedMultiplier * (tripVector[axis] - axes[axis])
                axes[axis] = stepClamped(raw, previous: axes[axis], maximumStep: stepLimit)
            }

            accumulateSignals(
                evaluation: evaluation,
                purpose: trip.purpose,
                at: eventDate,
                tags: tagByID,
                counts: &signalCounts,
                lastDates: &lastSignalDates
            )
            appliedTripCount += 1
        }

        applyFeedback(
            feedback.sorted { $0.createdAt < $1.createdAt },
            countries: countryByCode,
            axes: &axes
        )

        let confidence = calculateConfidence(
            counts: signalCounts,
            lastDates: lastSignalDates,
            appliedTripCount: appliedTripCount,
            now: now
        )
        let ledgerVersion = ranking?.ledgerVersion ?? eligibleTrips.count
        let vector = UserTasteVector(
            userID: userID,
            axes: axes.clamped(),
            confidence: confidence,
            ledgerVersion: ledgerVersion,
            recomputedAt: now
        )
        let oldAxes = previous?.axes ?? prior
        return UTVReplayResult(
            vector: vector,
            delta: subtract(vector.axes, oldAxes),
            deferredTripIDs: deferredTripIDs
        )
    }

    func calibratedSatisfaction(
        evaluation: TripEvaluation,
        rank: Int?,
        rankedTripCount: Int
    ) -> Double {
        guard !evaluation.skipped, let satisfaction = evaluation.satisfaction else {
            return 0.5
        }
        let absolute = Double(satisfaction - 1) / 4
        guard rankedTripCount > 2, let rank else {
            return absolute
        }
        let rankPercentile = 1 - Double(rank - 1) / Double(max(1, rankedTripCount - 1))
        return configuration.rankWeight * rankPercentile
            + (1 - configuration.rankWeight) * absolute
    }

    private func calculateTripVector(
        trip: Trip,
        evaluation: TripEvaluation,
        countries: [String: CountryProfile],
        tags: [String: TagDefinition]
    ) -> TasteAxes? {
        let confirmedLegs = trip.legs.compactMap { leg -> (TripLeg, CountryProfile)? in
            guard let profile = countries[leg.countryCode], profile.status == .confirmed else {
                return nil
            }
            return (leg, profile)
        }
        guard !confirmedLegs.isEmpty else { return nil }

        var rawWeights = confirmedLegs.map { leg, _ in
            Double(leg.days) * (leg.countryCode == evaluation.bestLegCountryCode ? 1.5 : 1)
        }
        let totalWeight = rawWeights.reduce(0, +)
        rawWeights = rawWeights.map { $0 / totalWeight }

        var legVectors = confirmedLegs.map { $0.1.tasteCore }
        for tagID in evaluation.positiveTagIDs {
            guard let tag = tags[tagID],
                  tag.routing.contains(.taste),
                  let signature = tag.axisSignature else {
                continue
            }
            let targetCountry = evaluation.tagLegAttribution[tagID] ?? evaluation.bestLegCountryCode
            let targetIndex = targetCountry.flatMap { country in
                confirmedLegs.firstIndex { $0.0.countryCode == country }
            }

            if let targetIndex {
                add(signature, multipliedBy: configuration.positiveTagAlpha, to: &legVectors[targetIndex])
            } else {
                for index in legVectors.indices {
                    add(signature, multipliedBy: configuration.positiveTagAlpha, to: &legVectors[index])
                }
            }
        }

        var result = TasteAxes.zero
        for index in legVectors.indices {
            for axis in TasteAxis.allCases {
                result[axis] += rawWeights[index] * legVectors[index][axis]
            }
        }
        return result.clamped()
    }

    private func axisGain(
        axis: TasteAxis,
        evaluation: TripEvaluation,
        purpose: TripPurpose,
        calibratedSatisfaction: Double,
        tags: [String: TagDefinition]
    ) -> Double {
        let base = min(max(2.6 * calibratedSatisfaction - 1.3, -0.3), 1)
        let hasPositive = evaluation.positiveTagIDs.contains {
            tags[$0]?.axisSignature?[axis] != nil && tags[$0]?.routing.contains(.taste) == true
        }
        let hasNegative = evaluation.negativeTagIDs.contains {
            tags[$0]?.axisSignature?[axis] != nil && tags[$0]?.routing.contains(.taste) == true
        }

        var gain: Double
        if hasNegative {
            gain = configuration.negativeGain
        } else if hasPositive {
            gain = min(max(base, 0) * configuration.positiveGainMultiplier, 1)
        } else {
            gain = base * 0.5
        }

        // 만족도 중간·스킵·태그 없음처럼 게인이 0이면, 방문 사실만으로 아주 약하게 여행지 축을 당긴다.
        // 저만족(base < 0)·부정 태그는 바닥값을 올리지 않는다.
        if !hasNegative, base >= 0, gain < configuration.visitPriorGainFloor {
            gain = configuration.visitPriorGainFloor
        }

        if purpose == .obligation {
            gain *= 0.2
        }
        return gain
    }

    private func accumulateSignals(
        evaluation: TripEvaluation,
        purpose: TripPurpose,
        at date: Date,
        tags: [String: TagDefinition],
        counts: inout TasteAxes,
        lastDates: inout [TasteAxis: Date]
    ) {
        for tagID in evaluation.positiveTagIDs + evaluation.negativeTagIDs {
            guard let signature = tags[tagID]?.axisSignature else { continue }
            for axis in signature.keys {
                counts[axis] += 1
                lastDates[axis] = max(lastDates[axis] ?? .distantPast, date)
            }
        }
        if evaluation.comparison?.result != nil,
           evaluation.comparison?.result != .skipped {
            for axis in TasteAxis.allCases {
                counts[axis] += 1
                lastDates[axis] = max(lastDates[axis] ?? .distantPast, date)
            }
        }

        // 여가 여행 방문 자체도 약한 신호로 센다. UI에서 "신뢰도 낮음"을 보여줄 수 있게 0은 피한다.
        if purpose == .leisure {
            let visitWeight = evaluation.skipped
                ? configuration.visitSignalWeight * configuration.skippedEvaluationCap
                : configuration.visitSignalWeight
            for axis in TasteAxis.allCases {
                counts[axis] += visitWeight
                lastDates[axis] = max(lastDates[axis] ?? .distantPast, date)
            }
        }
    }

    private func calculateConfidence(
        counts: TasteAxes,
        lastDates: [TasteAxis: Date],
        appliedTripCount: Int,
        now: Date
    ) -> AxisConfidence {
        var result = TasteAxes.zero
        let coldStart = appliedTripCount <= configuration.coldStartConfidenceTripLimit
        for axis in TasteAxis.allCases {
            let count = counts[axis]
            guard count > 0, let lastDate = lastDates[axis] else { continue }
            let months = max(
                0,
                Double(calendar.dateComponents([.month], from: lastDate, to: now).month ?? 0)
            )
            let decay = max(
                configuration.minimumStaleFactor,
                pow(0.5, months / configuration.staleHalfLifeMonths)
            )
            var value = count / (count + configuration.axisConfidenceK) * decay
            if coldStart {
                value = min(value, configuration.coldStartConfidenceCap)
            }
            result[axis] = value
        }
        return result
    }

    private func applyFeedback(
        _ feedback: [CardFeedback],
        countries: [String: CountryProfile],
        axes: inout TasteAxes
    ) {
        for item in feedback where item.action != .skip && item.revokedAt == nil {
            guard let profile = countries[item.countryCode] else { continue }
            let direction = item.action == .save ? 1.0 : -1.0
            for axis in TasteAxis.allCases {
                let target = direction > 0 ? profile.tasteCore[axis] : -profile.tasteCore[axis]
                axes[axis] += configuration.feedbackWeight * (target - axes[axis])
                axes[axis] = min(max(axes[axis], -1), 1)
            }
        }
    }

    private func stepClamped(
        _ proposed: Double,
        previous: Double,
        maximumStep: Double
    ) -> Double {
        min(
            max(proposed, previous - maximumStep),
            previous + maximumStep
        )
    }

    private func add(
        _ signature: [TasteAxis: Double],
        multipliedBy multiplier: Double,
        to vector: inout TasteAxes
    ) {
        for (axis, value) in signature {
            vector[axis] += value * multiplier
        }
        vector = vector.clamped()
    }

    private func subtract(_ lhs: TasteAxes, _ rhs: TasteAxes) -> TasteAxes {
        var result = TasteAxes.zero
        for axis in TasteAxis.allCases {
            result[axis] = lhs[axis] - rhs[axis]
        }
        return result
    }

    private func replayDate(for trip: Trip) -> Date {
        trip.endedAt ?? trip.startedAt ?? trip.createdAt
    }
}
