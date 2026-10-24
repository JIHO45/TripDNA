import Foundation

/// 테스트·프리뷰용 저장소. 출시 빌드는 `SwiftDataAppStore`를 쓴다.
nonisolated final class InMemoryAppStore: AppStore {
    private var storedTrips: [String: Trip]
    private var storedRanking: TripRanking?
    private var storedCountries: [String: CountryProfile]
    private var storedTags: [String: TagDefinition]
    private var storedFeedback: [String: CardFeedback]
    private var storedPhotos: [String: DailyPhoto]
    private var storedUTV: UserTasteVector?
    private var storedTastePrior: TasteAxes?
    private var storedQuizAnswers: [QuizAnswer] = []
    private var storedProfile: UserProfile?
    private var storedInterestTagIDs: Set<String> = []
    private var storedWantedTiers: WantedConceptTiers?
    private var storedOnboardingDraft: OnboardingDraft?
    private(set) var storedEvents: [AnalyticsEvent]

    init(
        trips: [Trip] = [],
        ranking: TripRanking? = nil,
        countries: [CountryProfile] = [],
        tags: [TagDefinition] = [],
        feedback: [CardFeedback] = [],
        photos: [DailyPhoto] = [],
        utv: UserTasteVector? = nil,
        profile: UserProfile? = nil,
        events: [AnalyticsEvent] = []
    ) {
        storedTrips = Dictionary(uniqueKeysWithValues: trips.map { ($0.id, $0) })
        storedRanking = ranking
        storedCountries = Dictionary(uniqueKeysWithValues: countries.map { ($0.countryCode, $0) })
        storedTags = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
        storedFeedback = Dictionary(uniqueKeysWithValues: feedback.map { ($0.id, $0) })
        storedPhotos = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        storedUTV = utv
        storedProfile = profile
        storedEvents = events
    }

    /// Dictionary의 순회 순서는 프로세스마다 랜덤 시드로 바뀐다. 조회 결과를 그대로
    /// 내보내면 동점 후보 중 무엇이 먼저 오는지가 실행마다 달라지므로,
    /// 모든 조회는 안정적인 키로 정렬해서 반환한다.
    func trips() async throws -> [Trip] {
        storedTrips.values.sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
        }
    }

    func trip(id: String) async throws -> Trip? {
        storedTrips[id]
    }

    func create(_ trip: Trip) async throws {
        guard storedTrips[trip.id] == nil else {
            throw RepositoryError.duplicateID
        }
        storedTrips[trip.id] = trip
    }

    func update(_ trip: Trip) async throws {
        guard let original = storedTrips[trip.id] else {
            throw RepositoryError.notFound
        }
        // 같은 레코드인지만 확인한다. 구간 수정은 허용된 동작이다.
        guard original.createdAt == trip.createdAt else {
            throw RepositoryError.notFound
        }
        storedTrips[trip.id] = trip
    }

    func deleteTrip(id: String) async throws {
        guard storedTrips.removeValue(forKey: id) != nil else { throw RepositoryError.notFound }
    }

    func currentRanking() async throws -> TripRanking? {
        storedRanking
    }

    func save(_ ranking: TripRanking) async throws {
        storedRanking = ranking
    }

    func profiles() async throws -> [CountryProfile] {
        storedCountries.values.sorted { $0.countryCode < $1.countryCode }
    }

    func profile(countryCode: String) async throws -> CountryProfile? {
        storedCountries[countryCode.uppercased()]
    }

    func definitions() async throws -> [TagDefinition] {
        storedTags.values.sorted { $0.id < $1.id }
    }

    func feedback() async throws -> [CardFeedback] {
        storedFeedback.values.sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
        }
    }

    func create(_ feedback: CardFeedback) async throws {
        guard storedFeedback[feedback.id] == nil else {
            throw RepositoryError.duplicateID
        }
        storedFeedback[feedback.id] = feedback
    }

    func update(_ feedback: CardFeedback) async throws {
        guard storedFeedback[feedback.id] != nil else {
            throw RepositoryError.notFound
        }
        storedFeedback[feedback.id] = feedback
    }

    func deleteFeedback(id: String) async throws {
        guard storedFeedback.removeValue(forKey: id) != nil else { throw RepositoryError.notFound }
    }

    func photos(tripID: String?) async throws -> [DailyPhoto] {
        storedPhotos.values
            .filter { tripID == nil || $0.tripID == tripID }
            .sorted {
                ($0.tripID, $0.tripDayIndex, $0.id) < ($1.tripID, $1.tripDayIndex, $1.id)
            }
    }

    func save(_ photo: DailyPhoto) async throws {
        guard storedPhotos[photo.id] == nil else {
            throw RepositoryError.duplicateID
        }
        storedPhotos[photo.id] = photo
    }

    func upsert(_ photo: DailyPhoto) async throws {
        storedPhotos = storedPhotos.filter { _, existing in
            !(existing.tripID == photo.tripID && existing.tripDayIndex == photo.tripDayIndex)
        }
        storedPhotos[photo.id] = photo
    }

    func deletePhotos(tripID: String) async throws {
        storedPhotos = storedPhotos.filter { $0.value.tripID != tripID }
    }

    func currentUTV() async throws -> UserTasteVector? {
        storedUTV
    }

    func save(_ vector: UserTasteVector) async throws {
        storedUTV = vector
    }

    func loadTastePrior() async throws -> TasteAxes? { storedTastePrior }

    func saveTastePrior(_ axes: TasteAxes) async throws { storedTastePrior = axes }

    func loadQuizAnswers() async throws -> [QuizAnswer] { storedQuizAnswers }

    func saveQuizAnswers(_ answers: [QuizAnswer]) async throws { storedQuizAnswers = answers }

    func loadProfile() async throws -> UserProfile? {
        storedProfile
    }

    func saveProfile(_ profile: UserProfile) async throws {
        storedProfile = profile
    }

    func loadInterestTagIDs() async throws -> Set<String> { storedInterestTagIDs }

    func saveInterestTagIDs(_ ids: Set<String>) async throws { storedInterestTagIDs = ids }

    func loadWantedTiers() async throws -> WantedConceptTiers? { storedWantedTiers }

    func saveWantedTiers(_ tiers: WantedConceptTiers) async throws { storedWantedTiers = tiers }

    func loadOnboardingDraft() async throws -> OnboardingDraft? { storedOnboardingDraft }

    func saveOnboardingDraft(_ draft: OnboardingDraft?) async throws { storedOnboardingDraft = draft }

    func append(_ event: AnalyticsEvent) async throws {
        guard !storedEvents.contains(where: { $0.id == event.id }) else {
            throw RepositoryError.duplicateID
        }
        storedEvents.append(event)
    }

    func events() async throws -> [AnalyticsEvent] {
        storedEvents.sorted {
            $0.createdAt == $1.createdAt ? $0.id < $1.id : $0.createdAt < $1.createdAt
        }
    }

    func deleteAllUserData() async throws {
        storedTrips.removeAll()
        storedRanking = nil
        storedFeedback.removeAll()
        storedPhotos.removeAll()
        storedUTV = nil
        storedTastePrior = nil
        storedQuizAnswers = []
        storedProfile = nil
        storedInterestTagIDs.removeAll()
        storedWantedTiers = nil
        storedOnboardingDraft = nil
        storedEvents.removeAll()
    }
}
