import Foundation
import Synchronization

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
    /// 저장한 도시·도시 제외·마지막 추천 결과. 없으면 빈 상태.
    func loadCityState() async throws -> CityRecommendationState
    func saveCityState(_ state: CityRecommendationState) async throws
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
    case onboardingCompleted = "onboarding_completed"
    case cityRecommendationReceived = "city_recommendation_received"
    /// 한도 초과·연결 미설정을 뺀 추천 실패(응답 검증 탈락·네트워크 등).
    case cityRecommendationFailed = "city_recommendation_failed"
    case citySaved = "city_saved"
    case citySkipped = "city_skipped"
    case cityExcluded = "city_excluded"
    case memoryForgotten = "memory_forgotten"
    /// 카드 메뉴의 "틀린 내용 알리기"를 눌렀다. 메일을 실제로 보냈는지는 알 수 없다.
    case errorReportOpened = "error_report_opened"
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

/// 전체 삭제 횟수. 응답을 기다리는 작업은 시작할 때 값을 들고 있다가, 그 사이 전체 삭제가 있었으면
/// 받은 결과를 저장하지 않는다(지운 기록이 늦게 도착한 응답으로 되살아나지 않게).
/// 확인과 저장을 한 잠금 안에서 하므로, 확인한 뒤 저장하기 전에 삭제가 끼어들 수 없다.
nonisolated final class UserDataGeneration: Sendable {
    private let value = Mutex(0)

    var current: Int { value.withLock { $0 } }

    /// 전체 삭제가 지우기 전에 부른다.
    func advance() { value.withLock { $0 += 1 } }

    /// 세대가 그대로일 때만 `write`를 실행하고 true를 돌려준다.
    func ifCurrent(_ generation: Int, _ write: () throws -> Void) throws -> Bool {
        try value.withLock { now in
            guard now == generation else { return false }
            try write()
            return true
        }
    }
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
{
    /// `deleteAllUserData`가 지우기 전에 올린다.
    var dataGeneration: UserDataGeneration { get }
    /// 세대가 그대로일 때만 저장한다. 저장했으면 true.
    func saveCityState(_ state: CityRecommendationState, ifGeneration generation: Int) async throws -> Bool
    /// AI 대화 목록과 마지막 AI 사용량. 없으면 빈 상태. 전체 삭제·iCloud 백업에 들어간다.
    func loadChatState() async throws -> ChatState
    func saveChatState(_ state: ChatState, ifGeneration generation: Int) async throws -> Bool
}

nonisolated enum RepositoryError: Error, Equatable {
    case duplicateID
    case notFound
}
