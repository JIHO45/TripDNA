import Foundation

nonisolated struct QuizAnswer: Codable, Equatable, Sendable {
    let questionID: String
    let signatures: [TasteAxis: Double]
    /// nil/empty means no explicit breadth answer, not rejection of either pole.
    var acceptedAxes: Set<TasteAxis>? = nil
}

nonisolated struct QuizResult: Equatable, Sendable {
    let prior: TasteAxes
    let confidence: AxisConfidence
    let interestTagIDs: Set<String>
    var acceptedAxes: Set<TasteAxis> = []
}

nonisolated struct TasteQuizService {
    var confidenceCap = 0.4

    func score(
        answers: [QuizAnswer],
        interestTagIDs: Set<String>
    ) -> QuizResult {
        var sums = TasteAxes.zero
        var counts = TasteAxes.zero
        var acceptedAxes: Set<TasteAxis> = []
        for answer in answers {
            for (axis, value) in answer.signatures {
                sums[axis] += value
                counts[axis] += 1
            }
            for axis in answer.acceptedAxes ?? [] {
                acceptedAxes.insert(axis)
                // Breadth is evidence, but does not pull directional preference to zero.
            }
        }

        var prior = TasteAxes.zero
        var confidence = TasteAxes.zero
        let maximumQuestionCount: [TasteAxis: Double] = [
            .natureUrban: 4,
            .energyLevel: 3,
            .planningStyle: 2,
            .socialMode: 3,
            .noveltyAppetite: 2
        ]
        for axis in TasteAxis.allCases where counts[axis] > 0 {
            prior[axis] = sums[axis] / counts[axis]
            confidence[axis] = min(
                confidenceCap,
                confidenceCap * counts[axis] / (maximumQuestionCount[axis] ?? counts[axis])
            )
        }
        for axis in acceptedAxes {
            confidence[axis] = max(confidence[axis], confidenceCap / (maximumQuestionCount[axis] ?? 1))
        }
        return QuizResult(
            prior: prior.clamped(),
            confidence: confidence,
            interestTagIDs: Set(interestTagIDs.sorted().prefix(3)),
            acceptedAxes: acceptedAxes
        )
    }

    func axesRequiringQuestions(
        confidence: AxisConfidence,
        minimum: Double = 0.4
    ) -> Set<TasteAxis> {
        Set(TasteAxis.allCases.filter { confidence[$0] < minimum })
    }
}

nonisolated enum WrappedCardKind: String, CaseIterable, Codable, Sendable {
    case movement
    case topTrip
    case strongestTaste
    case tags
    case photo
    case share
}

nonisolated struct WrappedCard: Identifiable, Codable, Equatable, Sendable {
    var id: String { kind.rawValue }
    let kind: WrappedCardKind
    let title: String
    let detail: String
}

nonisolated struct WrappedSummary: Equatable, Sendable {
    let year: Int
    let tripCount: Int
    let destinationCount: Int
    let cards: [WrappedCard]
}

nonisolated struct WrappedService {
    let calendar: Calendar

    init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    func wrappedYear(at date: Date) -> Int? {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return nil
        }
        if month == 12, day >= 15 {
            return year
        }
        if month == 1, day <= 15 {
            return year - 1
        }
        return nil
    }

    func isSeasonOpen(at date: Date, trips: [Trip]) -> Bool {
        guard let year = wrappedYear(at: date) else { return false }
        return trips.contains { tripYear($0) == year }
    }

    func generateSixCards(
        at date: Date,
        trips: [Trip],
        ranking: TripRanking?,
        vector: UserTasteVector,
        photos: [DailyPhoto]
    ) -> WrappedSummary? {
        guard let year = wrappedYear(at: date) else { return nil }
        let annualTrips = trips.filter { tripYear($0) == year }
        guard !annualTrips.isEmpty else { return nil }

        let countries = Set(annualTrips.flatMap { $0.legs.map(\.countryCode) })
        let rankedAnnualIDs = ranking?.tripIDsOrdered.filter { id in
            annualTrips.contains { $0.id == id }
        } ?? []
        let topTripID = rankedAnnualIDs.first ?? annualTrips.first?.id ?? ""
        let strongestAxis = TasteAxis.allCases.max {
            abs(vector.axes[$0]) < abs(vector.axes[$1])
        } ?? .natureUrban
        let positiveTags = annualTrips
            .flatMap { $0.evaluation?.positiveTagIDs ?? [] }
        let mostFrequentTag = Dictionary(grouping: positiveTags, by: { $0 })
            .max { $0.value.count < $1.value.count }?.key
        let hasPhoto = photos.contains { photo in
            annualTrips.contains { $0.id == photo.tripID }
        }

        let cards = [
            WrappedCard(
                kind: .movement,
                title: String(localized: "Movement in \(year)"),
                detail: String(localized: "\(countries.count) countries, \(annualTrips.count) trips")
            ),
            WrappedCard(kind: .topTrip, title: String(localized: "This Year's Top Trip"), detail: topTripID),
            WrappedCard(
                kind: .strongestTaste,
                title: String(localized: "Your Strongest Taste"),
                detail: strongestAxis.rawValue
            ),
            WrappedCard(
                kind: .tags,
                title: String(localized: "This Year's Top Tag"),
                detail: mostFrequentTag.map { TagCatalog.label(for: $0) } ?? String(localized: "No records")
            ),
            WrappedCard(
                kind: .photo,
                title: String(localized: "Photo of the Year"),
                detail: hasPhoto ? String(localized: "Has photos") : String(localized: "No photos")
            ),
            WrappedCard(
                kind: .share,
                title: String(localized: "\(year) Travel Fingerprint"),
                detail: String(localized: "\(countries.count) destinations")
            )
        ]
        return WrappedSummary(
            year: year,
            tripCount: annualTrips.count,
            destinationCount: countries.count,
            cards: cards
        )
    }

    private func tripYear(_ trip: Trip) -> Int? {
        let date = trip.endedAt ?? trip.startedAt ?? trip.createdAt
        return calendar.dateComponents([.year], from: date).year
    }
}

nonisolated struct DailyPhotoService {
    let photos: any DailyPhotoRepository
    let events: any EventRepository

    func saveSelection(
        tripID: String,
        tripDayIndex: Int,
        storagePath: String,
        selection: PhotoSelection,
        reaction: DayReaction?,
        at date: Date = Date()
    ) async throws -> DailyPhoto {
        let existing = try await photos.photos(tripID: tripID)
            .first { $0.tripDayIndex == tripDayIndex }
        let photo = DailyPhoto(
            id: UUID().uuidString,
            tripID: tripID,
            tripDayIndex: tripDayIndex,
            storagePath: storagePath,
            selection: selection,
            dayReaction: reaction ?? existing?.dayReaction,
            createdAt: existing?.createdAt ?? date
        )
        try await photos.upsert(photo)
        try await events.append(AnalyticsEvent(
            type: .dailyPhotoSelected,
            payload: [
                "tripId": tripID,
                "tripDayIndex": String(tripDayIndex),
                "photoId": photo.id,
                "selection": selection.rawValue,
                "dayReaction": photo.dayReaction?.rawValue ?? "null",
                "replaced": existing == nil ? "false" : "true"
            ],
            createdAt: date
        ))
        return photo
    }

    /// 이미 저장된 그날 사진의 반응만 바꾼다. 기록이 없으면 아무것도 하지 않는다.
    func updateReaction(tripID: String, tripDayIndex: Int, reaction: DayReaction) async throws {
        guard let existing = try await photos.photos(tripID: tripID)
            .first(where: { $0.tripDayIndex == tripDayIndex }) else { return }
        try await photos.upsert(DailyPhoto(
            id: existing.id,
            tripID: existing.tripID,
            tripDayIndex: existing.tripDayIndex,
            storagePath: existing.storagePath,
            selection: existing.selection,
            dayReaction: reaction,
            createdAt: existing.createdAt
        ))
    }
}
