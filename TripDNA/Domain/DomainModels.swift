import Foundation

// 이 프로젝트는 기본 격리가 MainActor다(UI 코드에는 맞지만 도메인에는 맞지 않는다).
// 도메인은 저장소 액터·백그라운드 재생 등 어떤 격리에서도 오가는 순수 값 타입이므로
// 전부 nonisolated로 둔다. 빠뜨리면 Codable 준수가 MainActor에 묶여 액터 안에서 쓸 수 없다.

nonisolated enum TasteAxis: String, CaseIterable, Codable, Sendable {
    case natureUrban
    case energyLevel
    case planningStyle
    case socialMode
    case noveltyAppetite
}

nonisolated struct TasteAxes: Codable, Equatable, Sendable {
    var natureUrban: Double
    var energyLevel: Double
    var planningStyle: Double
    var socialMode: Double
    var noveltyAppetite: Double

    nonisolated static let zero = TasteAxes(
        natureUrban: 0,
        energyLevel: 0,
        planningStyle: 0,
        socialMode: 0,
        noveltyAppetite: 0
    )

    subscript(axis: TasteAxis) -> Double {
        get {
            switch axis {
            case .natureUrban: natureUrban
            case .energyLevel: energyLevel
            case .planningStyle: planningStyle
            case .socialMode: socialMode
            case .noveltyAppetite: noveltyAppetite
            }
        }
        set {
            switch axis {
            case .natureUrban: natureUrban = newValue
            case .energyLevel: energyLevel = newValue
            case .planningStyle: planningStyle = newValue
            case .socialMode: socialMode = newValue
            case .noveltyAppetite: noveltyAppetite = newValue
            }
        }
    }

    func clamped(to range: ClosedRange<Double> = -1...1) -> TasteAxes {
        var result = self
        for axis in TasteAxis.allCases {
            result[axis] = min(max(result[axis], range.lowerBound), range.upperBound)
        }
        return result
    }
}

typealias AxisConfidence = TasteAxes

nonisolated enum OnboardingStatus: String, Codable, Sendable {
    case pending
    case photoScan = "photo_scan"
    case manual
    case quiz
    case done
}

nonisolated struct UserProfile: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var locale: String
    var onboardingStatus: OnboardingStatus
    var homeCountryCode: String?
    var departureAirportCode: String?
    let createdAt: Date
}

nonisolated enum Companion: String, Codable, CaseIterable, Sendable {
    case alone
    case couple
    case family
    case friends
}

nonisolated enum TripPurpose: String, Codable, Sendable {
    case leisure
    case obligation
}

nonisolated enum TripStatus: String, Codable, Sendable {
    case planned
    case active
    case ended
    case evaluated
    case skippedEvaluation = "skipped_eval"
}

nonisolated enum EvaluationSource: String, Codable, Sendable {
    case postTrip = "post_trip"
    case onboardingBackfill = "onboarding_backfill"
    case manualBackfill = "manual_backfill"
}

nonisolated enum ComparisonResult: String, Codable, Sendable {
    case better
    case worse
    case skipped
}

nonisolated struct TripLeg: Codable, Equatable, Sendable {
    let countryCode: String
    let cities: [String]
    let startDate: Date
    let endDate: Date

    var days: Int {
        max(1, Calendar(identifier: .gregorian).dateComponents(
            [.day],
            from: startDate,
            to: endDate
        ).day.map { $0 + 1 } ?? 1)
    }

    init(countryCode: String, cities: [String] = [], startDate: Date, endDate: Date) throws {
        let normalizedCode = countryCode.uppercased()
        guard normalizedCode.count == 2 else {
            throw DomainValidationError.invalidCountryCode
        }
        guard startDate <= endDate else {
            throw DomainValidationError.invalidDateRange
        }
        self.countryCode = normalizedCode
        self.cities = cities
        self.startDate = startDate
        self.endDate = endDate
    }
}

/// 여행별 큰 컨셉. ID는 `data/experience-categories.json` v1의 9개에 `event`를 더한 것이다
/// (docs/recommendation/memory.md "두 단계 컨셉"). 세부 컨셉은 아직 받지 않는다.
nonisolated enum TripConcept: String, CaseIterable, Codable, Sendable {
    case cityExploration = "city_exploration"
    case natureScenery = "nature_scenery"
    case food
    case relaxation
    case cultureHistory = "culture_history"
    case activities
    case shopping
    case nightlife
    case meetingPeople = "meeting_people"
    case event
}

/// 여가 여행의 주 컨셉 1개와 부 컨셉 0~2개.
nonisolated struct TripConcepts: Codable, Equatable, Sendable {
    let primary: TripConcept
    let secondary: [TripConcept]

    init(primary: TripConcept, secondary: [TripConcept] = []) throws {
        guard secondary.count <= 2,
              Set(secondary).count == secondary.count,
              !secondary.contains(primary) else {
            throw DomainValidationError.invalidConcepts
        }
        self.primary = primary
        self.secondary = secondary
    }
}

/// 취향 지문: 다녀온 여가 여행의 주 컨셉 횟수. 성향 추정값이 아니라 발자취다
/// (docs/screens/home-and-fingerprint.md "취향 지문"). 의무 여행과 아직 끝나지 않은 여행은 세지 않는다.
nonisolated struct ConceptFingerprint: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        let concept: TripConcept
        let count: Int
    }

    /// 횟수 내림차순. 같은 횟수는 `TripConcept.allCases` 순서.
    let entries: [Entry]

    /// 1위 컨셉들. 동점이면 함께 담는다.
    var top: [TripConcept] {
        guard let best = entries.first?.count else { return [] }
        return entries.filter { $0.count == best }.map(\.concept)
    }

    /// 셀 여행이 없으면 nil.
    init?(trips: [Trip], now: Date = Date()) {
        let today = Calendar.current.startOfDay(for: now)
        var counts: [TripConcept: Int] = [:]
        for trip in trips where trip.purpose == .leisure {
            let finished = trip.endedAt != nil || (trip.legs.map(\.endDate).max() ?? .distantFuture) < today
            guard finished, let primary = trip.concepts?.primary else { continue }
            counts[primary, default: 0] += 1
        }
        guard !counts.isEmpty else { return nil }
        // sorted는 안정 정렬이 아니므로 동점 순서를 allCases 위치로 고정한다.
        entries = TripConcept.allCases.enumerated()
            .compactMap { index, concept in counts[concept].map { (index, Entry(concept: concept, count: $0)) } }
            .sorted { ($0.1.count, -$0.0) > ($1.1.count, -$1.0) }
            .map(\.1)
    }
}

/// 방문 도시 하나의 평가. 도시 없이 나라만 기록된 구간은 `city`가 nil이다.
nonisolated struct CityReview: Codable, Equatable, Sendable {
    let countryCode: String
    let city: String?
    var rating: Int?
    var liked: String?
    var disliked: String?

    var isEmpty: Bool { rating == nil && liked == nil && disliked == nil }
}

nonisolated struct TripComparison: Codable, Equatable, Sendable {
    let versusTripID: String?
    let result: ComparisonResult
}

nonisolated struct TripEvaluation: Codable, Equatable, Sendable {
    let satisfaction: Int?
    let wouldRepeat: Bool?
    let bestLegCountryCode: String?
    let comparison: TripComparison?
    let positiveTagIDs: [String]
    let negativeTagIDs: [String]
    let tagLegAttribution: [String: String]
    /// 도시별 별점·메모. 이 필드가 생기기 전의 기록에는 없다.
    let cityReviews: [CityReview]?
    let source: EvaluationSource
    let skipped: Bool

    init(
        satisfaction: Int?,
        wouldRepeat: Bool?,
        bestLegCountryCode: String? = nil,
        comparison: TripComparison? = nil,
        positiveTagIDs: [String] = [],
        negativeTagIDs: [String] = [],
        tagLegAttribution: [String: String] = [:],
        cityReviews: [CityReview] = [],
        source: EvaluationSource,
        skipped: Bool = false
    ) throws {
        if skipped {
            guard satisfaction == nil, wouldRepeat == nil else {
                throw DomainValidationError.skippedEvaluationContainsAnswers
            }
        } else {
            guard let satisfaction, (1...5).contains(satisfaction), wouldRepeat != nil else {
                throw DomainValidationError.incompleteEvaluation
            }
        }
        guard positiveTagIDs.count <= 5 else {
            throw DomainValidationError.tooManyPositiveTags
        }
        guard negativeTagIDs.count <= 3 else {
            throw DomainValidationError.tooManyNegativeTags
        }
        guard cityReviews.allSatisfy({ $0.rating.map((1...5).contains) ?? true }) else {
            throw DomainValidationError.invalidCityReview
        }

        self.satisfaction = satisfaction
        self.wouldRepeat = wouldRepeat
        self.bestLegCountryCode = bestLegCountryCode?.uppercased()
        self.comparison = comparison
        self.positiveTagIDs = positiveTagIDs
        self.negativeTagIDs = negativeTagIDs
        self.tagLegAttribution = tagLegAttribution.mapValues { $0.uppercased() }
        self.cityReviews = cityReviews.isEmpty ? nil : cityReviews
        self.source = source
        self.skipped = skipped
    }
}

nonisolated struct Trip: Identifiable, Codable, Equatable, Sendable {
    let id: String
    private(set) var legs: [TripLeg]
    private(set) var companion: Companion
    private(set) var purpose: TripPurpose
    /// 여가 여행의 컨셉. 의무 여행과 이 필드가 생기기 전의 기록에는 없다.
    private(set) var concepts: TripConcepts?
    private(set) var status: TripStatus
    private(set) var evaluation: TripEvaluation?
    private(set) var coverPhotoStoragePath: String?
    private(set) var rankPosition: Int?
    let createdAt: Date
    private(set) var startedAt: Date?
    private(set) var endedAt: Date?
    private(set) var evaluatedAt: Date?

    init(
        id: String = UUID().uuidString,
        legs: [TripLeg],
        companion: Companion,
        purpose: TripPurpose,
        concepts: TripConcepts? = nil,
        createdAt: Date = Date()
    ) throws {
        guard !legs.isEmpty else {
            throw DomainValidationError.tripRequiresLeg
        }
        guard purpose == .leisure || concepts == nil else {
            throw DomainValidationError.invalidConcepts
        }
        self.id = id
        self.legs = legs
        self.companion = companion
        self.purpose = purpose
        self.concepts = concepts
        self.status = .planned
        self.createdAt = createdAt
    }

    mutating func start(at date: Date = Date()) throws {
        guard status == .planned else {
            throw DomainValidationError.invalidTripTransition
        }
        status = .active
        startedAt = date
    }

    mutating func end(at date: Date = Date()) throws {
        guard status == .active || status == .planned else {
            throw DomainValidationError.invalidTripTransition
        }
        status = .ended
        endedAt = date
    }

    mutating func submit(_ evaluation: TripEvaluation, at date: Date = Date()) throws {
        guard status == .ended, self.evaluation == nil else {
            throw DomainValidationError.evaluationAlreadySubmitted
        }
        try validate(evaluation)
        self.evaluation = evaluation
        status = evaluation.skipped ? .skippedEvaluation : .evaluated
        evaluatedAt = date
    }

    /// 제출한 평가를 고친다. 원장 재생 순서가 바뀌지 않도록 평가 시각과 랭킹 자리는 유지한다.
    mutating func revise(_ evaluation: TripEvaluation) throws {
        guard status == .evaluated || status == .skippedEvaluation else {
            throw DomainValidationError.invalidTripTransition
        }
        try validate(evaluation)
        self.evaluation = evaluation
        status = evaluation.skipped ? .skippedEvaluation : .evaluated
    }

    mutating func clearEvaluation() throws {
        guard status == .evaluated || status == .skippedEvaluation else {
            throw DomainValidationError.invalidTripTransition
        }
        evaluation = nil
        evaluatedAt = nil
        rankPosition = nil
        status = .ended
    }

    mutating func setCoverPhoto(storagePath: String?) {
        coverPhotoStoragePath = storagePath
    }

    /// 구간·동행·성격·컨셉만 수정한다. 상태·평가는 유지하되, 평가가 새 구간과 충돌하면 실패한다.
    mutating func updateDetails(
        legs: [TripLeg],
        companion: Companion,
        purpose: TripPurpose,
        concepts: TripConcepts?
    ) throws {
        guard !legs.isEmpty else {
            throw DomainValidationError.tripRequiresLeg
        }
        guard purpose == .leisure || concepts == nil else {
            throw DomainValidationError.invalidConcepts
        }
        let previousLegs = self.legs
        let previousCompanion = self.companion
        let previousPurpose = self.purpose
        self.legs = legs
        self.companion = companion
        self.purpose = purpose
        if let evaluation {
            do {
                try validate(evaluation)
            } catch {
                self.legs = previousLegs
                self.companion = previousCompanion
                self.purpose = previousPurpose
                throw error
            }
        }
        self.concepts = concepts
    }

    mutating func mirrorRankPosition(_ position: Int?) throws {
        if let position, position < 1 {
            throw DomainValidationError.invalidRankPosition
        }
        rankPosition = position
    }

    private func validate(_ evaluation: TripEvaluation) throws {
        let countries = Set(legs.map(\.countryCode))
        if legs.count > 1 {
            guard evaluation.skipped || evaluation.bestLegCountryCode.map(countries.contains) == true else {
                throw DomainValidationError.invalidBestLeg
            }
        } else if evaluation.bestLegCountryCode != nil {
            throw DomainValidationError.invalidBestLeg
        }
        guard evaluation.tagLegAttribution.values.allSatisfy(countries.contains) else {
            throw DomainValidationError.invalidTagAttribution
        }
        guard (evaluation.cityReviews ?? []).allSatisfy({ countries.contains($0.countryCode) }) else {
            throw DomainValidationError.invalidCityReview
        }
    }

    /// 평가할 방문 도시. 도시가 없는 구간은 나라 단위로 남긴다(그 나라의 도시로 배분하지 않는다).
    var reviewTargets: [CityReview] {
        var seen = Set<String>()
        var targets: [CityReview] = []
        for leg in legs {
            let cities: [String?] = leg.cities.isEmpty ? [nil] : leg.cities
            for city in cities where seen.insert("\(leg.countryCode)|\(city ?? "")").inserted {
                targets.append(CityReview(countryCode: leg.countryCode, city: city))
            }
        }
        return targets
    }
}

nonisolated enum PhotoSelection: String, Codable, Sendable {
    case manual
    case autoFallback = "auto_fallback"
}

nonisolated enum DayReaction: String, Codable, Sendable {
    case good
    case neutral
    case bad
}

nonisolated struct DailyPhoto: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let tripID: String
    let tripDayIndex: Int
    let storagePath: String
    let selection: PhotoSelection
    let dayReaction: DayReaction?
    let createdAt: Date
}

nonisolated struct TripRanking: Codable, Equatable, Sendable {
    private(set) var tripIDsOrdered: [String]
    private(set) var ledgerVersion: Int
    private(set) var updatedAt: Date

    init(tripIDsOrdered: [String], ledgerVersion: Int = 0, updatedAt: Date = Date()) throws {
        guard Set(tripIDsOrdered).count == tripIDsOrdered.count else {
            throw DomainValidationError.duplicateRankingTrip
        }
        self.tripIDsOrdered = tripIDsOrdered
        self.ledgerVersion = ledgerVersion
        self.updatedAt = updatedAt
    }

    mutating func move(fromOffsets: IndexSet, toOffset: Int) {
        let moving = fromOffsets.sorted().map { tripIDsOrdered[$0] }
        for index in fromOffsets.sorted(by: >) {
            tripIDsOrdered.remove(at: index)
        }
        let removedBeforeDestination = fromOffsets.filter { $0 < toOffset }.count
        let destination = min(max(0, toOffset - removedBeforeDestination), tripIDsOrdered.count)
        tripIDsOrdered.insert(contentsOf: moving, at: destination)
    }

    mutating func markSaved(at date: Date = Date()) {
        ledgerVersion += 1
        updatedAt = date
    }
}

nonisolated struct UserTasteVector: Codable, Equatable, Sendable {
    let userID: String
    var axes: TasteAxes
    var confidence: AxisConfidence
    var ledgerVersion: Int
    var recomputedAt: Date
    /// Explicitly accepts both poles. Optional so pre-existing JSON remains readable.
    var acceptedAxes: Set<TasteAxis>? = nil

    func isAxisUsable(_ axis: TasteAxis, minimumConfidence: Double = 0.4) -> Bool {
        confidence[axis] >= minimumConfidence
    }
}

nonisolated enum CountryStatus: String, Codable, Sendable {
    case confirmed
    case grey
}

nonisolated struct CountryConstraints: Codable, Equatable, Sendable {
    let cost: Double
    let climate: Double
}

nonisolated struct CountryProfile: Identifiable, Codable, Equatable, Sendable {
    var id: String { countryCode }
    let countryCode: String
    let name: String
    let nameKo: String
    let status: CountryStatus
    let tasteCore: TasteAxes
    let matchingAxes: Set<TasteAxis>
    let interestTags: [String: Double?]
    let constraints: CountryConstraints
    let popularity: Double?
}

nonisolated enum TagGroup: String, Codable, Sendable {
    case interest
    case polarity
    case negative
}

nonisolated enum TagRouting: String, Codable, Sendable {
    case taste
    case interest
    case constraint
    case quality
}

nonisolated struct TagDefinition: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let labelKo: String
    let group: TagGroup
    let routing: Set<TagRouting>
    let axisSignature: [TasteAxis: Double]?
    let polarityPairID: String?
    let constraintTarget: String?
    let qualityTarget: Bool
}

nonisolated enum RecommendationSlot: String, Codable, CaseIterable, Sendable {
    case bestMatch = "best_match"
    case freshStretch = "fresh_stretch"
    case underratedFit = "underrated_fit"
}

nonisolated enum FeedbackAction: String, Codable, Sendable {
    case save
    case skip
    case dislike
}

nonisolated enum FeedbackReason: String, Codable, Sendable {
    case tooExpensive = "too_expensive"
    case tooFar = "too_far"
    case safety
    case notMyTaste = "not_my_taste"
}

nonisolated struct CardFeedback: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let countryCode: String
    let slot: RecommendationSlot
    let action: FeedbackAction
    let reason: FeedbackReason?
    let excludeUntil: Date?
    private(set) var revokedAt: Date?
    let createdAt: Date

    mutating func revoke(at date: Date = Date()) {
        guard action == .dislike else { return }
        revokedAt = date
    }
}

nonisolated struct Recommendation: Identifiable, Codable, Equatable, Sendable {
    var id: String { "\(slot.rawValue):\(countryCode)" }
    let countryCode: String
    let slot: RecommendationSlot
    let matchScore: Double
    let explanationTagIDs: [String]
    let rankingAnchorTripID: String?
    let fitBadges: [String]
    let notices: [String]
}

nonisolated enum DomainValidationError: Error, Equatable {
    case invalidCountryCode
    case invalidDateRange
    case tripRequiresLeg
    case invalidTripTransition
    case incompleteEvaluation
    case skippedEvaluationContainsAnswers
    case evaluationAlreadySubmitted
    case tooManyPositiveTags
    case tooManyNegativeTags
    case invalidBestLeg
    case invalidTagAttribution
    case invalidRankPosition
    case duplicateRankingTrip
    case invalidConcepts
    case invalidCityReview
}
