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
    let analytics: AnalyticsRecorder
    let tripService: TripService
    let evaluationService: EvaluationService
    let rankingService: RankingService
    let recommendationService: RecommendationService
    let affiliateLinkService: AffiliateLinkService
    let affiliateActivitiesEnabled: Bool
    let dailyPhotoService: DailyPhotoService
    let wrappedService = WrappedService()
    /// 기기에 남는 저장소일 때만 있다. 프리뷰·테스트·데모는 iCloud에 닿지 않는다.
    let backup: ICloudBackup?
    let quizService = TasteQuizService()

    var interestTagIDs: Set<String> = []
    /// 사는 나라는 기본으로 후보에서 제외하고, 추천 조건의 "사는 나라도 포함"으로 매번 넣을 수 있다.
    /// 온보딩(홈 국가 확인 단계) 또는 설정 화면에서 사용자가 직접 확정한 값만 신뢰하며,
    /// 확정 전까지는 nil로 두어 추측값을 사실로 취급하지 않는다.
    private(set) var homeCountryCode: String?

    func excludedCountryCodes(visited: Set<String>, includingHomeCountry: Bool = false) -> Set<String> {
        guard let homeCountryCode, !includingHomeCountry else { return visited }
        return visited.union([homeCountryCode])
    }

    /// 사는 나라가 추천 목록에 있을 때만 "사는 나라도 포함" 토글과 안내를 보여준다.
    var canIncludeHomeCountry: Bool {
        homeCountryCode.map { CountryCatalog.profiles[$0] != nil } ?? false
    }

    /// 서버가 없으므로 기기에 남는 프로필이 계정 역할을 한다. 이 id로 원장·지문을 묶는다.
    private(set) var localUserID = UUID().uuidString

    /// 앱 진입 시 1회. 기기에 남아 있는 프로필로 홈 국가와 세션을 복원한다.
    /// 온보딩을 마친 기록이 있으면 다시 온보딩을 돌리지 않는다.
    func restore(session: SessionStore) async {
        if AppStorageLocation.defaults.object(forKey: Self.firstLaunchKey) == nil {
            AppStorageLocation.defaults.set(Date(), forKey: Self.firstLaunchKey)
        }
        guard let profile = try? await store.loadProfile() else { return }
        localUserID = profile.id
        homeCountryCode = profile.homeCountryCode
        interestTagIDs = (try? await store.loadInterestTagIDs()) ?? []
        session.userID = profile.id
        if profile.onboardingStatus == .done {
            session.onboardingPhase = .completed
        }
    }

    func track(_ type: AnalyticsEventType, _ payload: [String: String] = [:]) async {
        try? await analytics.append(AnalyticsEvent(type: type, payload: payload))
    }

    /// 설치 후 한 번만 기록한다. `source`는 추천을 처음 본 화면이다.
    func recordFirstRecommendationIfNeeded(source: String) async {
        let defaults = AppStorageLocation.defaults
        guard !defaults.bool(forKey: Self.firstRecommendationKey) else { return }
        defaults.set(true, forKey: Self.firstRecommendationKey)
        let firstLaunch = defaults.object(forKey: Self.firstLaunchKey) as? Date ?? Date()
        await track(.firstRecommendationShown, [
            "source": source,
            "secondsSinceFirstLaunch": String(Int(Date().timeIntervalSince(firstLaunch)))
        ])
    }

    /// 온보딩을 끝냈다는 사실을 기기에 남긴다. 로그인 여부와는 무관하다.
    func markOnboardingCompleted() async {
        var profile = await loadOrCreateProfile()
        profile.onboardingStatus = .done
        try? await store.saveProfile(profile)
    }

    /// 온보딩의 "어느 나라에 살고 계세요?" 단계 또는 설정 화면에서 사용자가 국가를
    /// 명시적으로 선택했을 때 호출한다. 기존 프로필의 다른 필드는 보존한다.
    @discardableResult
    func setHomeCountryCode(_ code: String) async -> String {
        homeCountryCode = code
        var profile = await loadOrCreateProfile()
        profile.homeCountryCode = code
        try? await store.saveProfile(profile)
        return profile.id
    }

    /// 설정의 "정하지 않기". 사는 나라를 비우면 기본 제외도 하지 않는다.
    func clearHomeCountryCode() async {
        homeCountryCode = nil
        guard var profile = try? await store.loadProfile() else { return }
        profile.homeCountryCode = nil
        try? await store.saveProfile(profile)
    }

    /// 출발 공항 기본값. 추천 요청 때 읽어 LLM의 항공료 출발지로 보낸다.
    func setDepartureDefaults(airportCode: String?, prefersDirectFlights: Bool?) async throws {
        var profile = await loadOrCreateProfile()
        profile.departureAirportCode = airportCode
        profile.prefersDirectFlights = prefersDirectFlights
        try await store.saveProfile(profile)
    }

    func setInterestTagIDs(_ ids: Set<String>) async throws {
        try await store.saveInterestTagIDs(ids)
        interestTagIDs = ids
    }

    func unsaveRecommendation(countryCode: String) async throws {
        let feedback = try await store.feedback()
        for item in feedback where item.action == .save && item.countryCode == countryCode {
            try await store.deleteFeedback(id: item.id)
        }
    }

    func deleteEvaluation(tripID: String, userID: String) async throws {
        guard var trip = try await store.trip(id: tripID) else { throw RepositoryError.notFound }
        try trip.clearEvaluation()
        try await store.update(trip)
        try await removeFromRanking(tripID: tripID, userID: userID)
    }

    func deleteTrip(tripID: String, userID: String) async throws {
        guard let trip = try await store.trip(id: tripID) else { throw RepositoryError.notFound }
        let photos = try await store.photos(tripID: tripID)
        let paths = photos.map(\.storagePath) + [trip.coverPhotoStoragePath].compactMap { $0 }
        try await store.deleteTrip(id: tripID)
        try await store.deletePhotos(tripID: tripID)
        try await removeFromRanking(tripID: tripID, userID: userID)
        EvaluationNotificationService.cancel(for: tripID)
        try await deleteUnusedPhotoFiles(paths)
    }

    /// 대표 사진이나 하루 한 장 기록이 가리키지 않는 사진 파일만 지운다.
    func deleteUnusedPhotoFiles(_ paths: [String]) async throws {
        let trips = try await store.trips()
        let photos = try await store.photos(tripID: nil)
        let inUse = Set(trips.compactMap(\.coverPhotoStoragePath) + photos.map(\.storagePath))
        try LocalPhotoStore.delete(paths: paths.filter { !inUse.contains($0) })
    }

    private func removeFromRanking(tripID: String, userID: String) async throws {
        if let ranking = try await store.currentRanking() {
            let remaining = ranking.tripIDsOrdered.filter { $0 != tripID }
            if remaining.count != ranking.tripIDsOrdered.count {
                try await store.save(TripRanking(
                    tripIDsOrdered: remaining,
                    ledgerVersion: ranking.ledgerVersion + 1
                ))
                for (index, id) in remaining.enumerated() {
                    guard var trip = try await store.trip(id: id) else { continue }
                    try trip.mirrorRankPosition(index + 1)
                    try await store.update(trip)
                }
            }
        }
        let prior = try await store.loadTastePrior() ?? .zero
        _ = try await evaluationService.recompute(
            userID: userID, trigger: "record_deleted", prior: prior
        )
    }

    func deleteAccount(session: SessionStore) async throws {
        // iCloud 사본을 먼저 지운다. 실패하면 기기 기록도 그대로 두고 알린다(사본만 남는 일을 막는다).
        try await backup?.deleteRemote()
        try await store.deleteAllUserData()
        try LocalPhotoStore.deleteAll()
        // 추천 기록에는 메모 원문과 요청 문장이 있다. 전체 삭제에 포함하고, 실패는 호출자가 사용자에게 알린다.
        try CityRecommendationLog.standard.deleteAll()
        CityMemoryConsent.reset()
        EvaluationNotificationService.clearAll()
        AppStorageLocation.defaults.removeObject(forKey: AutoPhotoFallbackService.consentKey)
        AppStorageLocation.defaults.removeObject(forKey: "tripdna.dailyPhotoAutoFallbackAsked")
        AppStorageLocation.defaults.removeObject(forKey: Self.firstRecommendationKey)
        RankingReorderFlag.clear()
        homeCountryCode = nil
        interestTagIDs.removeAll()
        localUserID = UUID().uuidString
        session.resetAfterDeletion()
        await CityLLMCredentials.deleteAnonymousAccount()
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
            createdAt: Date()
        )
    }

    private static let firstLaunchKey = "analytics.firstLaunchAt"
    private static let firstRecommendationKey = "analytics.firstRecommendationRecorded"

    init(
        persistence: AppPersistence = .onDisk,
        affiliateActivitiesEnabled: Bool = AppDependencies.defaultAffiliateActivitiesEnabled,
        analyticsSink: (any AnalyticsSink)? = nil
    ) {
        self.affiliateActivitiesEnabled = affiliateActivitiesEnabled
        let countries = Self.loadCountries()
        let tags = Self.loadTags()
        CountryCatalog.profiles = Dictionary(
            uniqueKeysWithValues: countries.map { ($0.countryCode, $0) }
        )
        TagCatalog.definitions = Dictionary(
            uniqueKeysWithValues: tags.map { ($0.id, $0) }
        )

        #if DEBUG
        // -uiDemo도 인메모리로 받아, 시드가 기기에 남은 실제 기록을 건드리지 않게 한다.
        let launchArguments = ProcessInfo.processInfo.arguments
        let effectivePersistence: AppPersistence = launchArguments.contains("-uiTesting") || launchArguments.contains("-uiDemo") ? .inMemory : persistence
        #else
        let effectivePersistence = persistence
        #endif
        let store = Self.makeStore(persistence: effectivePersistence, countries: countries, tags: tags)
        self.store = store
        if effectivePersistence == .onDisk, !AppStorageLocation.isIsolated, let local = store as? SwiftDataAppStore {
            backup = ICloudBackup(store: local)
        } else {
            backup = nil
        }
        let analytics = AnalyticsRecorder(store: store, sink: analyticsSink)
        self.analytics = analytics

        let replay = UTVReplayService()
        self.tripService = TripService(trips: store, events: analytics)
        self.evaluationService = EvaluationService(
            trips: store,
            rankings: store,
            countries: store,
            tags: store,
            feedback: store,
            utv: store,
            events: analytics,
            replay: replay
        )
        self.rankingService = RankingService(
            trips: store,
            rankings: store,
            evaluationService: evaluationService,
            events: analytics
        )
        self.recommendationService = RecommendationService(
            countries: store,
            feedbackRepository: store,
            events: analytics
        )
        self.affiliateLinkService = AffiliateLinkService(events: analytics)
        self.dailyPhotoService = DailyPhotoService(photos: store, events: analytics)
    }

    func allTags() async -> [TagDefinition] {
        (try? await store.definitions()) ?? []
    }

    static var defaultAffiliateActivitiesEnabled: Bool {
        #if DEBUG
        !ProcessInfo.processInfo.arguments.contains("-disableAffiliateActivities")
        #else
        false
        #endif
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
            assertionFailure("SwiftData 저장소를 열지 못했습니다: \(error)") // l10n-ignore debug-only assertion
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
