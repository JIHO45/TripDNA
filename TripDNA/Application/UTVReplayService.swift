import Foundation

nonisolated struct UTVReplayConfiguration: Equatable, Sendable {
    var maximumStep = 0.25
    var axisConfidenceK = 4.0
    var minimumLearningRate = 0.1
    /// 초반(여행 2회 이하) 신뢰도 상한 — 한두 여행에 과신하지 않음.
    var coldStartConfidenceCap = 0.35
    var coldStartConfidenceTripLimit = 2
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
        countries _: [CountryProfile],
        tags: [TagDefinition],
        feedback _: [CardFeedback] = [],
        prior: TasteAxes = .zero,
        quiz: QuizResult? = nil,
        previous: UserTasteVector? = nil,
        now: Date = Date()
    ) -> UTVReplayResult {
        let tagByID = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        let eligibleTrips = trips
            .filter { $0.status == .evaluated || $0.status == .skippedEvaluation }
            .sorted { replayDate(for: $0) < replayDate(for: $1) }
        var axes = prior.clamped()
        var signalCounts = TasteAxes.zero
        var lastSignalDates: [TasteAxis: Date] = [:]
        var deferredTripIDs: [String] = []

        var appliedTripCount = 0
        for trip in eligibleTrips {
            guard let evaluation = trip.evaluation else {
                deferredTripIDs.append(trip.id)
                continue
            }
            let targets = explicitAxisTargets(evaluation: evaluation, tags: tagByID)
            guard !targets.isEmpty else {
                deferredTripIDs.append(trip.id)
                continue
            }
            let learningRate = appliedTripCount >= 8
                ? configuration.minimumLearningRate
                : max(configuration.minimumLearningRate, 1.0 / Double(appliedTripCount + 1))
            let eventDate = replayDate(for: trip)

            for (axis, target) in targets {
                let raw = axes[axis] + learningRate * (target - axes[axis])
                axes[axis] = stepClamped(raw, previous: axes[axis], maximumStep: configuration.maximumStep)
            }

            accumulateSignals(
                evaluation: evaluation,
                at: eventDate,
                tags: tagByID,
                counts: &signalCounts,
                lastDates: &lastSignalDates
            )
            appliedTripCount += 1
        }

        var confidence = calculateConfidence(
            counts: signalCounts,
            lastDates: lastSignalDates,
            appliedTripCount: appliedTripCount,
            now: now
        )
        // Do not count correlated quiz/trip evidence twice. This is a conservative
        // floor, not a calibrated probability or a sum of observation counts.
        for axis in TasteAxis.allCases {
            confidence[axis] = max(confidence[axis], quiz?.confidence[axis] ?? 0)
        }
        let ledgerVersion = ranking?.ledgerVersion ?? eligibleTrips.count
        let vector = UserTasteVector(
            userID: userID,
            axes: axes.clamped(),
            confidence: confidence,
            ledgerVersion: ledgerVersion,
            recomputedAt: now,
            acceptedAxes: quiz?.acceptedAxes
        )
        let oldAxes = previous?.axes ?? prior
        return UTVReplayResult(
            vector: vector,
            delta: subtract(vector.axes, oldAxes),
            deferredTripIDs: deferredTripIDs
        )
    }

    private func explicitAxisTargets(
        evaluation: TripEvaluation,
        tags: [String: TagDefinition]
    ) -> [TasteAxis: Double] {
        var sums: [TasteAxis: Double] = [:]
        var counts: [TasteAxis: Int] = [:]
        for tagID in evaluation.positiveTagIDs {
            guard let tag = tags[tagID],
                  tag.routing.contains(.taste),
                  let signature = tag.axisSignature else {
                continue
            }
            for (axis, value) in signature {
                sums[axis, default: 0] += value
                counts[axis, default: 0] += 1
            }
        }
        var targets: [TasteAxis: Double] = [:]
        for (axis, sum) in sums {
            targets[axis] = min(max(sum / Double(counts[axis, default: 1]), -1), 1)
        }
        return targets
    }

    private func accumulateSignals(
        evaluation: TripEvaluation,
        at date: Date,
        tags: [String: TagDefinition],
        counts: inout TasteAxes,
        lastDates: inout [TasteAxis: Date]
    ) {
        for tagID in evaluation.positiveTagIDs {
            guard let tag = tags[tagID], tag.routing.contains(.taste),
                  let signature = tag.axisSignature else { continue }
            for axis in signature.keys {
                counts[axis] += 1
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
