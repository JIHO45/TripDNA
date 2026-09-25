import Foundation

protocol TripRepository {
    func trips() async throws -> [Trip]
    func trip(id: String) async throws -> Trip?
    func create(_ trip: Trip) async throws
    func update(_ trip: Trip) async throws
    func deleteTrip(id: String) async throws
}

protocol RankingRepository {
    func currentRanking() async throws -> TripRanking?
    func save(_ ranking: TripRanking) async throws
}

protocol CountryRepository {
    func profiles() async throws -> [CountryProfile]
    func profile(countryCode: String) async throws -> CountryProfile?
}

protocol TagRepository {
    func definitions() async throws -> [TagDefinition]
}

protocol FeedbackRepository {
    func feedback() async throws -> [CardFeedback]
    func create(_ feedback: CardFeedback) async throws
    func update(_ feedback: CardFeedback) async throws
    func deleteFeedback(id: String) async throws
}

protocol DailyPhotoRepository {
    func photos(tripID: String?) async throws -> [DailyPhoto]
    func save(_ photo: DailyPhoto) async throws
    /// 같은 여행·같은 일차 사진이 있으면 교체한다.
    func upsert(_ photo: DailyPhoto) async throws
    func deletePhotos(tripID: String) async throws
}

protocol UTVRepository {
    func currentUTV() async throws -> UserTasteVector?
    func save(_ vector: UserTasteVector) async throws
    func loadTastePrior() async throws -> TasteAxes?
    func saveTastePrior(_ axes: TasteAxes) async throws
}

protocol UserProfileRepository {
    func loadProfile() async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
    func loadInterestTagIDs() async throws -> Set<String>
    func saveInterestTagIDs(_ ids: Set<String>) async throws
}

nonisolated enum AnalyticsEventType: String, Codable, Sendable {
    case tripStarted = "trip_started"
    case tripEvaluated = "trip_evaluated"
    case rankingAdjusted = "ranking_adjusted"
    case utvRecomputed = "utv_recomputed"
    case dailyPhotoSelected = "daily_photo_selected"
    case recommendationFeedback = "recommendation_feedback"
    case slotImpression = "slot_impression"
    case slotClick = "slot_click"
    case slotSave = "slot_save"
    case slotReopen = "slot_reopen"
    case wrappedOpened = "wrapped_opened"
    case wrappedCompleted = "wrapped_completed"
    case wrappedImageSaved = "wrapped_image_saved"
    case wrappedShared = "wrapped_shared"
    case tripCardShared = "trip_card_shared"
    case quizAnswered = "quiz_answered"
    case onboardingStepCompleted = "onboarding_step_completed"
}

nonisolated struct AnalyticsEvent: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let type: AnalyticsEventType
    let payload: [String: String]
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        type: AnalyticsEventType,
        payload: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.payload = payload
        self.createdAt = createdAt
    }
}

protocol EventRepository {
    func append(_ event: AnalyticsEvent) async throws
}

protocol UserDataDeletionRepository {
    func deleteAllUserData() async throws
}

/// 앱이 쓰는 저장소 전체. 화면·뷰모델은 이 하나만 들고 다니고,
/// 실제 구현(SwiftData / 인메모리)은 교체 가능하게 둔다.
protocol AppStore:
    TripRepository,
    RankingRepository,
    CountryRepository,
    TagRepository,
    FeedbackRepository,
    DailyPhotoRepository,
    UTVRepository,
    UserProfileRepository,
    EventRepository,
    UserDataDeletionRepository
{}

nonisolated enum RepositoryError: Error, Equatable {
    case duplicateID
    case notFound
}
