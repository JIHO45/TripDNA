import Foundation

nonisolated enum ApplicationServiceError: Error, Equatable {
    case tripNotFound
    case rankingContainsUnknownTrip
    case rankingDoesNotContainEveryEvaluatedTrip
}

nonisolated struct TripService {
    let trips: any TripRepository
    let events: any EventRepository

    func createTrip(
        legs: [TripLeg],
        companion: Companion,
        purpose: TripPurpose,
        now: Date = Date()
    ) async throws -> Trip {
        let trip = try Trip(
            legs: legs,
            companion: companion,
            purpose: purpose,
            createdAt: now
        )
        try await trips.create(trip)
        try await events.append(AnalyticsEvent(
            type: .tripStarted,
            payload: [
                "tripId": trip.id,
                "countryCodes": legs.map(\.countryCode).joined(separator: ","),
                "companion": companion.rawValue,
                "purpose": purpose.rawValue
            ],
            createdAt: now
        ))
        return trip
    }

    func startTrip(id: String, at date: Date = Date()) async throws -> Trip {
        var trip = try await requiredTrip(id: id)
        try trip.start(at: date)
        try await trips.update(trip)
        return trip
    }

    func endTrip(id: String, at date: Date = Date()) async throws -> Trip {
        var trip = try await requiredTrip(id: id)
        try trip.end(at: date)
        try await trips.update(trip)
        return trip
    }

    func setCoverPhoto(tripID: String, storagePath: String?) async throws -> Trip {
        var trip = try await requiredTrip(id: tripID)
        trip.setCoverPhoto(storagePath: storagePath)
        try await trips.update(trip)
        return trip
    }

    func updateTrip(
        id: String,
        legs: [TripLeg],
        companion: Companion,
        purpose: TripPurpose
    ) async throws -> Trip {
        var trip = try await requiredTrip(id: id)
        try trip.updateDetails(legs: legs, companion: companion, purpose: purpose)
        try await trips.update(trip)
        return trip
    }

    func isDuplicate(of candidate: Trip) async throws -> Bool {
        let existing = try await trips.trips()
        return existing.contains { trip in
            guard trip.id != candidate.id else { return false }
            let existingCountries = Set(trip.legs.map(\.countryCode))
            let candidateCountries = Set(candidate.legs.map(\.countryCode))
            let overlaps = trip.legs.contains { existingLeg in
                candidate.legs.contains { candidateLeg in
                    existingLeg.startDate <= candidateLeg.endDate
                        && candidateLeg.startDate <= existingLeg.endDate
                }
            }
            return existingCountries == candidateCountries && overlaps
        }
    }

    private func requiredTrip(id: String) async throws -> Trip {
        guard let trip = try await trips.trip(id: id) else {
            throw ApplicationServiceError.tripNotFound
        }
        return trip
    }
}

nonisolated struct EvaluationService {
    let trips: any TripRepository
    let rankings: any RankingRepository
    let countries: any CountryRepository
    let tags: any TagRepository
    let feedback: any FeedbackRepository
    let utv: any UTVRepository
    let events: any EventRepository
    let replay: UTVReplayService

    func selectComparisonAnchor(
        satisfaction: Int,
        excluding tripID: String,
        from candidates: [Trip]
    ) -> Trip? {
        let eligible = candidates
            .filter {
                $0.id != tripID
                    && $0.purpose == .leisure
                    && $0.status == .evaluated
                    && $0.evaluation?.satisfaction != nil
            }
            .sorted {
                ($0.evaluatedAt ?? $0.createdAt) > ($1.evaluatedAt ?? $1.createdAt)
            }
        if let sameScore = eligible.first(where: {
            $0.evaluation?.satisfaction == satisfaction
        }) {
            return sameScore
        }
        return eligible.min { lhs, rhs in
            let leftDistance = abs((lhs.evaluation?.satisfaction ?? satisfaction) - satisfaction)
            let rightDistance = abs((rhs.evaluation?.satisfaction ?? satisfaction) - satisfaction)
            if leftDistance == rightDistance {
                return (lhs.evaluatedAt ?? lhs.createdAt) > (rhs.evaluatedAt ?? rhs.createdAt)
            }
            return leftDistance < rightDistance
        }
    }

    func submit(
        tripID: String,
        evaluation: TripEvaluation,
        userID: String,
        prior: TasteAxes = .zero,
        at date: Date = Date()
    ) async throws -> UTVReplayResult {
        guard var trip = try await trips.trip(id: tripID) else {
            throw ApplicationServiceError.tripNotFound
        }
        try trip.submit(evaluation, at: date)
        try await trips.update(trip)
        try await events.append(AnalyticsEvent(
            type: .tripEvaluated,
            payload: [
                "tripId": tripID,
                "source": evaluation.source.rawValue,
                "skipped": String(evaluation.skipped)
            ],
            createdAt: date
        ))
        return try await recompute(
            userID: userID,
            trigger: evaluation.source == .onboardingBackfill ? "onboarding" : "evaluated",
            prior: prior,
            now: date
        )
    }

    func recompute(
        userID: String,
        trigger: String,
        prior: TasteAxes = .zero,
        now: Date = Date()
    ) async throws -> UTVReplayResult {
        let allTrips = try await trips.trips()
        let ranking = try await rankings.currentRanking()
        let profiles = try await countries.profiles()
        let definitions = try await tags.definitions()
        let allFeedback = try await feedback.feedback()
        let previous = try await utv.currentUTV()
        let result = replay.replay(
            userID: userID,
            trips: allTrips,
            ranking: ranking,
            countries: profiles,
            tags: definitions,
            feedback: allFeedback,
            prior: prior,
            previous: previous,
            now: now
        )
        try await utv.save(result.vector)
        try await events.append(AnalyticsEvent(
            type: .utvRecomputed,
            payload: [
                "trigger": trigger,
                "ledgerVersion": String(result.vector.ledgerVersion),
                "natureUrbanDelta": String(result.delta.natureUrban),
                "energyLevelDelta": String(result.delta.energyLevel),
                "planningStyleDelta": String(result.delta.planningStyle),
                "socialModeDelta": String(result.delta.socialMode),
                "noveltyAppetiteDelta": String(result.delta.noveltyAppetite)
            ],
            createdAt: now
        ))
        return result
    }
}

nonisolated struct RankingService {
    let trips: any TripRepository
    let rankings: any RankingRepository
    let evaluationService: EvaluationService
    let events: any EventRepository

    func loadRanking(now: Date = Date()) async throws -> TripRanking {
        if let current = try await rankings.currentRanking() {
            return current
        }
        let rankedTrips = try await trips.trips()
            .filter { $0.status == .evaluated || $0.status == .skippedEvaluation }
            .sorted { lhs, rhs in
                let left = lhs.evaluation?.satisfaction ?? 3
                let right = rhs.evaluation?.satisfaction ?? 3
                if left == right {
                    return (lhs.evaluatedAt ?? lhs.createdAt) > (rhs.evaluatedAt ?? rhs.createdAt)
                }
                return left > right
            }
        return try TripRanking(tripIDsOrdered: rankedTrips.map(\.id), updatedAt: now)
    }

    func preview(
        ranking: TripRanking,
        userID: String,
        prior: TasteAxes = .zero,
        now: Date = Date()
    ) async throws -> UTVReplayResult {
        let allTrips = try await trips.trips()
        let profiles = try await evaluationService.countries.profiles()
        let definitions = try await evaluationService.tags.definitions()
        let allFeedback = try await evaluationService.feedback.feedback()
        return evaluationService.replay.replay(
            userID: userID,
            trips: allTrips,
            ranking: ranking,
            countries: profiles,
            tags: definitions,
            feedback: allFeedback,
            prior: prior,
            previous: try await evaluationService.utv.currentUTV(),
            now: now
        )
    }

    func save(
        _ draft: TripRanking,
        userID: String,
        prior: TasteAxes = .zero,
        at date: Date = Date()
    ) async throws -> UTVReplayResult {
        let allTrips = try await trips.trips()
        let evaluatedIDs = Set(allTrips.filter {
            $0.status == .evaluated || $0.status == .skippedEvaluation
        }.map(\.id))
        let draftIDs = Set(draft.tripIDsOrdered)
        guard draftIDs.isSubset(of: Set(allTrips.map(\.id))) else {
            throw ApplicationServiceError.rankingContainsUnknownTrip
        }
        guard draftIDs == evaluatedIDs else {
            throw ApplicationServiceError.rankingDoesNotContainEveryEvaluatedTrip
        }

        let before = try await rankings.currentRanking()?.tripIDsOrdered ?? []
        var saved = draft
        saved.markSaved(at: date)
        try await rankings.save(saved)

        for (index, tripID) in saved.tripIDsOrdered.enumerated() {
            guard var trip = allTrips.first(where: { $0.id == tripID }) else { continue }
            try trip.mirrorRankPosition(index + 1)
            try await trips.update(trip)
        }

        let moved = saved.tripIDsOrdered.filter { id in
            before.firstIndex(of: id) != saved.tripIDsOrdered.firstIndex(of: id)
        }
        try await events.append(AnalyticsEvent(
            type: .rankingAdjusted,
            payload: [
                "movedTripIds": moved.joined(separator: ","),
                "positionsBefore": before.joined(separator: ","),
                "positionsAfter": saved.tripIDsOrdered.joined(separator: ",")
            ],
            createdAt: date
        ))
        return try await evaluationService.recompute(
            userID: userID,
            trigger: "rank_edit",
            prior: prior,
            now: date
        )
    }
}
