import Foundation
import SwiftData

// MARK: - 저장 모델
//
// 도메인 모델은 초기화 시점에 불변 조건을 검증하는 struct다(평가 없는 evaluated 여행,
// 중복 랭킹 등을 막는다). 이를 컬럼으로 분해했다가 되돌리려면 검증을 건너뛰는
// 초기화 경로를 새로 열어야 하므로, 조회에 필요한 키만 컬럼으로 두고 값 자체는
// Codable JSON으로 보관한다.

/// 출시 후 저장 모델을 바꿀 때는 이 스키마를 고치지 말고 V2를 새로 만들어
/// `TripDNAMigrationPlan`에 단계를 추가한다. 이미 설치된 기기의 저장소가 V1이기 때문이다.
nonisolated enum TripDNASchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [StoredTrip.self, StoredCardFeedback.self, StoredDailyPhoto.self,
         StoredAnalyticsEvent.self, StoredSingleton.self]
    }

    @Model
    final class StoredTrip {
        @Attribute(.unique) var tripID: String
        var createdAt: Date
        var payload: Data

        init(tripID: String, createdAt: Date, payload: Data) {
            self.tripID = tripID
            self.createdAt = createdAt
            self.payload = payload
        }
    }

    @Model
    final class StoredCardFeedback {
        @Attribute(.unique) var feedbackID: String
        var createdAt: Date
        var payload: Data

        init(feedbackID: String, createdAt: Date, payload: Data) {
            self.feedbackID = feedbackID
            self.createdAt = createdAt
            self.payload = payload
        }
    }

    @Model
    final class StoredDailyPhoto {
        @Attribute(.unique) var photoID: String
        var tripID: String
        var tripDayIndex: Int
        var payload: Data

        init(photoID: String, tripID: String, tripDayIndex: Int, payload: Data) {
            self.photoID = photoID
            self.tripID = tripID
            self.tripDayIndex = tripDayIndex
            self.payload = payload
        }
    }

    @Model
    final class StoredAnalyticsEvent {
        @Attribute(.unique) var eventID: String
        var createdAt: Date
        var payload: Data

        init(eventID: String, createdAt: Date, payload: Data) {
            self.eventID = eventID
            self.createdAt = createdAt
            self.payload = payload
        }
    }

    /// 항상 한 벌만 존재하는 값(랭킹·취향 지문·사용자 프로필)을 키로 구분해 보관한다.
    @Model
    final class StoredSingleton {
        @Attribute(.unique) var key: String
        var payload: Data

        init(key: String, payload: Data) {
            self.key = key
            self.payload = payload
        }
    }
}

/// V1에 마지막 수정 시각(`updatedAt`)을 더했다. 나중에 여러 기기나 서버와 기록을 맞출 때
/// 어느 쪽이 최신인지 가리는 데 쓴다. V1에서 옮겨 온 행은 시각을 모르므로 nil이다.
/// 추가만 하는 바뀜이라 가벼운 이전(lightweight)으로 충분하다.
nonisolated enum TripDNASchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [StoredTrip.self, StoredCardFeedback.self, StoredDailyPhoto.self,
         StoredAnalyticsEvent.self, StoredSingleton.self]
    }

    @Model
    final class StoredTrip {
        @Attribute(.unique) var tripID: String
        var createdAt: Date
        var updatedAt: Date?
        var payload: Data

        init(tripID: String, createdAt: Date, updatedAt: Date? = nil, payload: Data) {
            self.tripID = tripID
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.payload = payload
        }
    }

    @Model
    final class StoredCardFeedback {
        @Attribute(.unique) var feedbackID: String
        var createdAt: Date
        var updatedAt: Date?
        var payload: Data

        init(feedbackID: String, createdAt: Date, updatedAt: Date? = nil, payload: Data) {
            self.feedbackID = feedbackID
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.payload = payload
        }
    }

    @Model
    final class StoredDailyPhoto {
        @Attribute(.unique) var photoID: String
        var tripID: String
        var tripDayIndex: Int
        var updatedAt: Date?
        var payload: Data

        init(photoID: String, tripID: String, tripDayIndex: Int, updatedAt: Date? = nil, payload: Data) {
            self.photoID = photoID
            self.tripID = tripID
            self.tripDayIndex = tripDayIndex
            self.updatedAt = updatedAt
            self.payload = payload
        }
    }

    /// 추가만 하고 고치지 않는 기록이라 수정 시각을 두지 않는다.
    @Model
    final class StoredAnalyticsEvent {
        @Attribute(.unique) var eventID: String
        var createdAt: Date
        var payload: Data

        init(eventID: String, createdAt: Date, payload: Data) {
            self.eventID = eventID
            self.createdAt = createdAt
            self.payload = payload
        }
    }

    @Model
    final class StoredSingleton {
        @Attribute(.unique) var key: String
        var updatedAt: Date?
        var payload: Data

        init(key: String, updatedAt: Date? = nil, payload: Data) {
            self.key = key
            self.updatedAt = updatedAt
            self.payload = payload
        }
    }
}

nonisolated enum TripDNAMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [TripDNASchemaV1.self, TripDNASchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: TripDNASchemaV1.self, toVersion: TripDNASchemaV2.self)]
    }
}

typealias StoredTrip = TripDNASchemaV2.StoredTrip
typealias StoredCardFeedback = TripDNASchemaV2.StoredCardFeedback
typealias StoredDailyPhoto = TripDNASchemaV2.StoredDailyPhoto
typealias StoredAnalyticsEvent = TripDNASchemaV2.StoredAnalyticsEvent
typealias StoredSingleton = TripDNASchemaV2.StoredSingleton

// MARK: - 저장소

/// 기기 로컬 SwiftData 저장소. 서버가 없으므로 이 저장소가 유일한 진실의 원천이다.
///
/// 국가 프로필·태그 어휘는 번들 JSON에서 읽는 읽기 전용 시드라 데이터베이스에
/// 넣지 않고 메모리에서 그대로 돌려준다. 사진 파일은 `LocalPhotoStore`가 맡고,
/// 여기에는 메타데이터만 저장한다.
actor SwiftDataAppStore: nonisolated AppStore {
    private enum SingletonKey {
        static let ranking = "ranking"
        static let utv = "utv"
        static let userProfile = "userProfile"
        static let interestTags = "interestTags"
        static let tastePrior = "tastePrior"
    }

    private let container: ModelContainer
    private let countryProfiles: [CountryProfile]
    private let tagDefinitions: [TagDefinition]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var context: ModelContext?

    /// `ModelContext`는 스레드 안전하지 않다. 액터 안에서 처음 쓸 때 만들어,
    /// 이후 모든 접근이 이 액터의 실행기에서 직렬화되도록 한다.
    private var modelContext: ModelContext {
        if let context { return context }
        let created = ModelContext(container)
        context = created
        return created
    }

    init(
        container: ModelContainer,
        countries: [CountryProfile],
        tags: [TagDefinition]
    ) {
        self.container = container
        self.countryProfiles = countries.sorted { $0.countryCode < $1.countryCode }
        self.tagDefinitions = tags.sorted { $0.id < $1.id }
    }

    /// - Parameter url: 저장 파일 위치. 기본 위치를 쓰려면 nil. 테스트가 앱 재실행을
    ///   흉내 내려고 같은 파일을 다시 열 때 지정한다.
    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let configuration = if let url {
            ModelConfiguration(url: url)
        } else {
            ModelConfiguration(isStoredInMemoryOnly: inMemory)
        }
        return try ModelContainer(
            for: Schema(versionedSchema: TripDNASchemaV2.self),
            migrationPlan: TripDNAMigrationPlan.self,
            configurations: configuration
        )
    }

    // MARK: 여행

    func trips() async throws -> [Trip] {
        let rows = try modelContext.fetch(
            FetchDescriptor<StoredTrip>(
                sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.tripID)]
            )
        )
        return try rows.map { try decoder.decode(Trip.self, from: $0.payload) }
    }

    func trip(id: String) async throws -> Trip? {
        guard let row = try tripRow(id: id) else { return nil }
        return try decoder.decode(Trip.self, from: row.payload)
    }

    func create(_ trip: Trip) async throws {
        guard try tripRow(id: trip.id) == nil else {
            throw RepositoryError.duplicateID
        }
        modelContext.insert(StoredTrip(
            tripID: trip.id,
            createdAt: trip.createdAt,
            updatedAt: .now,
            payload: try encoder.encode(trip)
        ))
        try modelContext.save()
    }

    func update(_ trip: Trip) async throws {
        guard let row = try tripRow(id: trip.id) else {
            throw RepositoryError.notFound
        }
        // 같은 레코드인지만 확인한다. 구간 수정은 허용된 동작이다.
        guard try decoder.decode(Trip.self, from: row.payload).createdAt == trip.createdAt else {
            throw RepositoryError.notFound
        }
        row.payload = try encoder.encode(trip)
        row.updatedAt = .now
        try modelContext.save()
    }

    func deleteTrip(id: String) async throws {
        guard let row = try tripRow(id: id) else { throw RepositoryError.notFound }
        modelContext.delete(row)
        try modelContext.save()
    }

    // MARK: 랭킹

    func currentRanking() async throws -> TripRanking? {
        try singleton(TripRanking.self, key: SingletonKey.ranking)
    }

    func save(_ ranking: TripRanking) async throws {
        try saveSingleton(ranking, key: SingletonKey.ranking)
    }

    // MARK: 국가·태그 (번들 시드)

    func profiles() async throws -> [CountryProfile] {
        countryProfiles
    }

    func profile(countryCode: String) async throws -> CountryProfile? {
        let normalized = countryCode.uppercased()
        return countryProfiles.first { $0.countryCode == normalized }
    }

    func definitions() async throws -> [TagDefinition] {
        tagDefinitions
    }

    // MARK: 추천 카드 반응

    func feedback() async throws -> [CardFeedback] {
        let rows = try modelContext.fetch(
            FetchDescriptor<StoredCardFeedback>(
                sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.feedbackID)]
            )
        )
        return try rows.map { try decoder.decode(CardFeedback.self, from: $0.payload) }
    }

    func create(_ feedback: CardFeedback) async throws {
        guard try feedbackRow(id: feedback.id) == nil else {
            throw RepositoryError.duplicateID
        }
        modelContext.insert(StoredCardFeedback(
            feedbackID: feedback.id,
            createdAt: feedback.createdAt,
            updatedAt: .now,
            payload: try encoder.encode(feedback)
        ))
        try modelContext.save()
    }

    func update(_ feedback: CardFeedback) async throws {
        guard let row = try feedbackRow(id: feedback.id) else {
            throw RepositoryError.notFound
        }
        row.payload = try encoder.encode(feedback)
        row.updatedAt = .now
        try modelContext.save()
    }

    func deleteFeedback(id: String) async throws {
        guard let row = try feedbackRow(id: id) else { throw RepositoryError.notFound }
        modelContext.delete(row)
        try modelContext.save()
    }

    // MARK: 하루 한 장 (메타데이터만. 파일은 LocalPhotoStore)

    func photos(tripID: String?) async throws -> [DailyPhoto] {
        var descriptor = FetchDescriptor<StoredDailyPhoto>(
            sortBy: [
                SortDescriptor(\.tripID),
                SortDescriptor(\.tripDayIndex),
                SortDescriptor(\.photoID)
            ]
        )
        if let tripID {
            descriptor.predicate = #Predicate { $0.tripID == tripID }
        }
        let rows = try modelContext.fetch(descriptor)
        return try rows.map { try decoder.decode(DailyPhoto.self, from: $0.payload) }
    }

    func save(_ photo: DailyPhoto) async throws {
        guard try photoRow(id: photo.id) == nil else {
            throw RepositoryError.duplicateID
        }
        modelContext.insert(storedPhoto(photo))
        try modelContext.save()
    }

    func upsert(_ photo: DailyPhoto) async throws {
        let tripID = photo.tripID
        let dayIndex = photo.tripDayIndex
        let existing = try modelContext.fetch(
            FetchDescriptor<StoredDailyPhoto>(
                predicate: #Predicate { $0.tripID == tripID && $0.tripDayIndex == dayIndex }
            )
        )
        for row in existing {
            modelContext.delete(row)
        }
        modelContext.insert(storedPhoto(photo))
        try modelContext.save()
    }

    func deletePhotos(tripID: String) async throws {
        let rows = try modelContext.fetch(FetchDescriptor<StoredDailyPhoto>(
            predicate: #Predicate { $0.tripID == tripID }
        ))
        for row in rows { modelContext.delete(row) }
        try modelContext.save()
    }

    // MARK: 취향 지문·사용자 프로필

    func currentUTV() async throws -> UserTasteVector? {
        try singleton(UserTasteVector.self, key: SingletonKey.utv)
    }

    func save(_ vector: UserTasteVector) async throws {
        try saveSingleton(vector, key: SingletonKey.utv)
    }

    func loadTastePrior() async throws -> TasteAxes? {
        try singleton(TasteAxes.self, key: SingletonKey.tastePrior)
    }

    func saveTastePrior(_ axes: TasteAxes) async throws {
        try saveSingleton(axes, key: SingletonKey.tastePrior)
    }

    func loadQuizAnswers() async throws -> [QuizAnswer] {
        try singleton([QuizAnswer].self, key: "quizAnswers.v1") ?? []
    }

    func saveQuizAnswers(_ answers: [QuizAnswer]) async throws {
        try saveSingleton(answers, key: "quizAnswers.v1")
    }

    func loadProfile() async throws -> UserProfile? {
        try singleton(UserProfile.self, key: SingletonKey.userProfile)
    }

    func saveProfile(_ profile: UserProfile) async throws {
        try saveSingleton(profile, key: SingletonKey.userProfile)
    }

    func loadInterestTagIDs() async throws -> Set<String> {
        try singleton(Set<String>.self, key: SingletonKey.interestTags) ?? []
    }

    func saveInterestTagIDs(_ ids: Set<String>) async throws {
        try saveSingleton(ids, key: SingletonKey.interestTags)
    }

    // MARK: 이벤트

    func append(_ event: AnalyticsEvent) async throws {
        let eventID = event.id
        let existing = try modelContext.fetchCount(
            FetchDescriptor<StoredAnalyticsEvent>(predicate: #Predicate { $0.eventID == eventID })
        )
        guard existing == 0 else {
            throw RepositoryError.duplicateID
        }
        modelContext.insert(StoredAnalyticsEvent(
            eventID: event.id,
            createdAt: event.createdAt,
            payload: try encoder.encode(event)
        ))
        try modelContext.save()
    }

    func events() async throws -> [AnalyticsEvent] {
        let rows = try modelContext.fetch(
            FetchDescriptor<StoredAnalyticsEvent>(
                sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.eventID)]
            )
        )
        return try rows.map { try decoder.decode(AnalyticsEvent.self, from: $0.payload) }
    }

    func deleteAllUserData() async throws {
        try modelContext.delete(model: StoredTrip.self)
        try modelContext.delete(model: StoredCardFeedback.self)
        try modelContext.delete(model: StoredDailyPhoto.self)
        try modelContext.delete(model: StoredAnalyticsEvent.self)
        try modelContext.delete(model: StoredSingleton.self)
        try modelContext.save()
    }

    // MARK: 내부

    private func storedPhoto(_ photo: DailyPhoto) -> StoredDailyPhoto {
        StoredDailyPhoto(
            photoID: photo.id,
            tripID: photo.tripID,
            tripDayIndex: photo.tripDayIndex,
            updatedAt: .now,
            payload: (try? encoder.encode(photo)) ?? Data()
        )
    }

    private func tripRow(id: String) throws -> StoredTrip? {
        try modelContext.fetch(
            FetchDescriptor<StoredTrip>(predicate: #Predicate { $0.tripID == id })
        ).first
    }

    private func feedbackRow(id: String) throws -> StoredCardFeedback? {
        try modelContext.fetch(
            FetchDescriptor<StoredCardFeedback>(predicate: #Predicate { $0.feedbackID == id })
        ).first
    }

    private func photoRow(id: String) throws -> StoredDailyPhoto? {
        try modelContext.fetch(
            FetchDescriptor<StoredDailyPhoto>(predicate: #Predicate { $0.photoID == id })
        ).first
    }

    private func singletonRow(key: String) throws -> StoredSingleton? {
        try modelContext.fetch(
            FetchDescriptor<StoredSingleton>(predicate: #Predicate { $0.key == key })
        ).first
    }

    private func singleton<T: Decodable>(_ type: T.Type, key: String) throws -> T? {
        guard let row = try singletonRow(key: key) else { return nil }
        return try decoder.decode(T.self, from: row.payload)
    }

    private func saveSingleton<T: Encodable>(_ value: T, key: String) throws {
        let payload = try encoder.encode(value)
        if let row = try singletonRow(key: key) {
            row.payload = payload
            row.updatedAt = .now
        } else {
            modelContext.insert(StoredSingleton(key: key, updatedAt: .now, payload: payload))
        }
        try modelContext.save()
    }
}
