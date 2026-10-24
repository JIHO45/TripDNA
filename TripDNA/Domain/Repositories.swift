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
    func loadQuizAnswers() async throws -> [QuizAnswer]
    func saveQuizAnswers(_ answers: [QuizAnswer]) async throws
}

protocol UserProfileRepository {
    func loadProfile() async throws -> UserProfile?
    func saveProfile(_ profile: UserProfile) async throws
    func loadInterestTagIDs() async throws -> Set<String>
    func saveInterestTagIDs(_ ids: Set<String>) async throws
    func loadWantedTiers() async throws -> WantedConceptTiers?
    func saveWantedTiers(_ tiers: WantedConceptTiers) async throws
    /// 온보딩 도중 앱이 꺼져도 이어가기 위한 임시 진행 상태. nil을 저장하면 지운다.
    func loadOnboardingDraft() async throws -> OnboardingDraft?
    func saveOnboardingDraft(_ draft: OnboardingDraft?) async throws
}

nonisolated enum AnalyticsEventType: String, Codable, Sendable {
    case tripStarted = "trip_started"
    case tripEvaluated = "trip_evaluated"
    case rankingAdjusted = "ranking_adjusted"
    case utvRecomputed = "utv_recomputed"
    case dailyPhotoSelected = "daily_photo_selected"
    case recommendationFeedback = "recommendation_feedback"
    case recommendationImpression = "recommendation_impression"
    case slotClick = "slot_click"
    /// 설치 후 처음으로 추천 카드를 본 시점. README §6 "첫 추천 도달"
    case firstRecommendationShown = "first_recommendation_shown"
    /// 지문·여행·Wrapped 카드를 저장했거나 공유 시트에서 실제로 보냈을 때.
    case shareCardExported = "share_card_exported"
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
