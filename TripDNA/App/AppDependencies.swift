import Foundation

enum AppPersistence {
    /// 기기에 남는 SwiftData 저장소. 출시 빌드가 쓴다.
    case onDisk
    /// 프리뷰·테스트용. 앱을 닫으면 사라진다.
    case inMemory
}

@Observable
final class AppDependencies {
    let store: any AppStore
    let tripService: TripService
    let evaluationService: EvaluationService
    let rankingService: RankingService
    let recommendationService: RecommendationService
    let dailyPhotoService: DailyPhotoService
    let wrappedService = WrappedService()
    let quizService = TasteQuizService()

    var interestTagIDs: Set<String> = []
    /// 자국은 "새로운 여행지 추천" 대상이 될 수 없으므로 항상 후보에서 제외한다.
    /// 온보딩(홈 국가 확인 단계) 또는 설정 화면에서 사용자가 직접 확정한 값만 신뢰하며,
    /// 확정 전까지는 nil로 두어 추측값을 사실로 취급하지 않는다.
    private(set) var homeCountryCode: String?

    func excludedCountryCodes(visited: Set<String>) -> Set<String> {
        guard let homeCountryCode else { return visited }
        return visited.union([homeCountryCode])
    }

    /// 서버가 없으므로 기기에 남는 프로필이 계정 역할을 한다. 이 id로 원장·지문을 묶는다.
    private(set) var localUserID = UUID().uuidString

    /// 앱 진입 시 1회. 기기에 남아 있는 프로필로 홈 국가와 세션을 복원한다.
    /// 온보딩을 마친 기록이 있으면 다시 온보딩을 돌리지 않는다.
    func restore(session: SessionStore) async {
        guard let profile = try? await store.loadProfile() else { return }
        localUserID = profile.id
        homeCountryCode = profile.homeCountryCode
        session.userID = profile.id
        if profile.onboardingStatus == .done {
            session.onboardingPhase = .completed
        }
    }

    /// 온보딩을 끝냈다는 사실을 기기에 남긴다. 로그인 여부와는 무관하다.
    func markOnboardingCompleted() async {
        var profile = await loadOrCreateProfile()
        profile.onboardingStatus = .done
        try? await store.saveProfile(profile)
    }

    /// 온보딩의 "어느 나라에 살고 계세요?" 단계 또는 설정 화면에서 사용자가 국가를
    /// 명시적으로 선택했을 때 호출한다. 기존 프로필의 다른 필드는 보존한다.
    func setHomeCountryCode(_ code: String) async {
        homeCountryCode = code
        var profile = await loadOrCreateProfile()
        profile.homeCountryCode = code
        try? await store.saveProfile(profile)
    }

    private func loadOrCreateProfile() async -> UserProfile {
        if let stored = try? await store.loadProfile() {
            return stored
        }
        return UserProfile(
            id: localUserID,
            locale: Locale.current.identifier,
            onboardingStatus: .pending,
            homeCountryCode: nil,
            departureAirportCode: nil,
            dailyPhotoAutoFallbackConsent: nil,
            createdAt: Date()
        )
    }

    init(persistence: AppPersistence = .onDisk) {
        let countries = Self.loadCountries()
        let tags = Self.loadTags()
        CountryCatalog.profiles = Dictionary(
            uniqueKeysWithValues: countries.map { ($0.countryCode, $0) }
        )
        TagCatalog.definitions = Dictionary(
            uniqueKeysWithValues: tags.map { ($0.id, $0) }
        )

        let store = Self.makeStore(persistence: persistence, countries: countries, tags: tags)
        self.store = store

        let replay = UTVReplayService()
        self.tripService = TripService(trips: store, events: store)
        self.evaluationService = EvaluationService(
            trips: store,
            rankings: store,
            countries: store,
            tags: store,
            feedback: store,
            utv: store,
            events: store,
            replay: replay
        )
        self.rankingService = RankingService(
            trips: store,
            rankings: store,
            evaluationService: evaluationService,
            events: store
        )
        self.recommendationService = RecommendationService(
            countries: store,
            feedbackRepository: store,
            events: store
        )
        self.dailyPhotoService = DailyPhotoService(photos: store, events: store)
    }

    func allTags() async -> [TagDefinition] {
        (try? await store.definitions()) ?? []
    }

    func allTrips() async -> [Trip] {
        (try? await store.trips()) ?? []
    }

    /// 저장소를 만들지 못하면(디스크 손상·마이그레이션 실패) 앱을 죽이는 대신
    /// 인메모리로 계속 쓰게 한다. 이번 실행의 기록은 남지 않지만, 사용자가 앱을
    /// 아예 열지 못하는 상황은 피한다.
    private static func makeStore(
        persistence: AppPersistence,
        countries: [CountryProfile],
        tags: [TagDefinition]
    ) -> any AppStore {
        do {
            let container = try SwiftDataAppStore.makeContainer(
                inMemory: persistence == .inMemory
            )
            return SwiftDataAppStore(container: container, countries: countries, tags: tags)
        } catch {
            assertionFailure("SwiftData 저장소를 열지 못했습니다: \(error)")
            return InMemoryAppStore(countries: countries, tags: tags)
        }
    }

    private static func loadCountries() -> [CountryProfile] {
        guard let url = Bundle.main.url(forResource: "countries", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let profiles = try? SeedDataDecoder().decodeCountries(from: data) else {
            return []
        }
        return profiles
    }

    private static func loadTags() -> [TagDefinition] {
        guard let url = Bundle.main.url(forResource: "tagVocabulary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let tags = try? SeedDataDecoder().decodeTags(from: data) else {
            return []
        }
        return tags
    }
}
