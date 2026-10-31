import Foundation
import SwiftData
import Testing
@testable import TripDNA

struct ConceptAndCityReviewTests {
    private let past = Date().addingTimeInterval(-30 * 24 * 60 * 60)

    private func leg(_ code: String, _ cities: [String] = [], at date: Date? = nil) throws -> TripLeg {
        let start = date ?? past
        return try TripLeg(countryCode: code, cities: cities, startDate: start, endDate: start)
    }

    private func leisure(_ primary: TripConcept, _ secondary: [TripConcept] = [], at date: Date? = nil) throws -> Trip {
        try Trip(legs: [leg("JP", at: date)], companion: .alone, purpose: .leisure,
                 concepts: TripConcepts(primary: primary, secondary: secondary))
    }

    // MARK: 컨셉

    @Test func conceptIDsMatchVocabularyV1PlusEvent() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("data/experience-categories.json")
        struct File: Decodable { struct Category: Decodable { let id: String; let label_ko: String }; let version: Int; let categories: [Category] }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        #expect(file.version == 1)
        #expect(file.categories.map(\.id) + ["event"] == TripConcept.allCases.map(\.rawValue))
        // 화면 이름(label)은 짧은 이름이라 자료 파일의 label_ko와 비교하지 않는다.
        for category in file.categories {
            #expect(TripConcept(rawValue: category.id)?.label.isEmpty == false)
        }
    }

    @Test func conceptsRejectInvalidSecondary() {
        #expect(throws: DomainValidationError.invalidConcepts) {
            try TripConcepts(primary: .food, secondary: [.shopping, .nightlife, .event])
        }
        #expect(throws: DomainValidationError.invalidConcepts) {
            try TripConcepts(primary: .food, secondary: [.food])
        }
        #expect(throws: DomainValidationError.invalidConcepts) {
            try TripConcepts(primary: .food, secondary: [.event, .event])
        }
    }

    @Test func obligationTripCannotHaveConcepts() throws {
        #expect(throws: DomainValidationError.invalidConcepts) {
            try Trip(legs: [leg("JP")], companion: .alone, purpose: .obligation,
                     concepts: TripConcepts(primary: .food))
        }
        var trip = try leisure(.food)
        #expect(throws: DomainValidationError.invalidConcepts) {
            try trip.updateDetails(legs: trip.legs, companion: .alone, purpose: .obligation,
                                   concepts: trip.concepts)
        }
        #expect(trip.concepts?.primary == .food)
        try trip.updateDetails(legs: trip.legs, companion: .alone, purpose: .obligation, concepts: nil)
        #expect(trip.concepts == nil)
    }

    // MARK: 지문

    @Test func fingerprintCountsPrimaryConceptsAndKeepsTies() throws {
        let obligation = try Trip(legs: [leg("JP")], companion: .family, purpose: .obligation)
        let future = try leisure(.shopping, at: Date().addingTimeInterval(30 * 24 * 60 * 60))
        let trips = [
            try leisure(.food, [.shopping]),
            try leisure(.relaxation),
            try leisure(.food),
            try leisure(.relaxation, [.food]),
            try leisure(.event),
            obligation,
            future
        ]
        let fingerprint = try #require(ConceptFingerprint(trips: trips))
        #expect(fingerprint.top == [.food, .relaxation])
        #expect(fingerprint.entries.map(\.concept) == [.food, .relaxation, .event])
        #expect(fingerprint.entries.map(\.count) == [2, 2, 1])
    }

    @Test func fingerprintIsEmptyWithoutCountableTrips() throws {
        #expect(ConceptFingerprint(trips: []) == nil)
        let obligation = try Trip(legs: [leg("JP")], companion: .family, purpose: .obligation)
        let legacy = try Trip(legs: [leg("JP")], companion: .alone, purpose: .leisure)
        #expect(ConceptFingerprint(trips: [obligation, legacy]) == nil)
    }

    // MARK: 도시별 평가

    @Test func reviewTargetsKeepCountryOnlyLegsAndDeduplicate() throws {
        let trip = try Trip(
            legs: [leg("JP", ["도쿄", "오사카"]), leg("KR"), leg("JP", ["도쿄"])],
            companion: .alone, purpose: .leisure
        )
        #expect(trip.reviewTargets.map(\.countryCode) == ["JP", "JP", "KR"])
        #expect(trip.reviewTargets.map(\.city) == ["도쿄", "오사카", nil])
    }

    @Test func cityReviewMustBelongToTripAndHaveValidRating() throws {
        #expect(throws: DomainValidationError.invalidCityReview) {
            try TripEvaluation(satisfaction: 4, wouldRepeat: true,
                               cityReviews: [CityReview(countryCode: "JP", city: "도쿄", rating: 6)],
                               source: .postTrip)
        }
        var trip = try Trip(legs: [leg("JP", ["도쿄"])], companion: .alone, purpose: .leisure)
        try trip.end(at: past)
        let foreign = try TripEvaluation(satisfaction: 4, wouldRepeat: true,
                                         cityReviews: [CityReview(countryCode: "FR", city: "파리", rating: 5)],
                                         source: .postTrip)
        #expect(throws: DomainValidationError.invalidCityReview) { try trip.submit(foreign) }
    }

    @Test func conceptsAndCityReviewsPersistAndLegacyPayloadDecodes() async throws {
        let container = try SwiftDataAppStore.makeContainer(inMemory: true)
        let store = SwiftDataAppStore(container: container, countries: [], tags: [])
        var trip = try Trip(legs: [leg("JP", ["도쿄"])], companion: .alone, purpose: .leisure,
                            concepts: TripConcepts(primary: .food, secondary: [.shopping]))
        try trip.end(at: past)
        try trip.submit(TripEvaluation(
            satisfaction: 5, wouldRepeat: true, positiveTagIDs: ["food"],
            cityReviews: [CityReview(countryCode: "JP", city: "도쿄", rating: 5, liked: "라멘", disliked: nil)],
            source: .postTrip
        ))
        try await store.create(trip)
        let reopened = SwiftDataAppStore(container: container, countries: [], tags: [])
        #expect(try await reopened.trip(id: trip.id) == trip)

        // 컨셉·도시 평가가 생기기 전의 저장 형식(두 키가 없는 JSON)도 그대로 읽힌다.
        var legacy = try Trip(legs: [leg("JP")], companion: .alone, purpose: .leisure)
        try legacy.end(at: past)
        try legacy.submit(TripEvaluation(satisfaction: 3, wouldRepeat: false,
                                         positiveTagIDs: ["food"], source: .postTrip))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any]
        #expect(json?["concepts"] == nil)
        #expect((json?["evaluation"] as? [String: Any])?["cityReviews"] == nil)
        let decoded = try JSONDecoder().decode(Trip.self, from: JSONSerialization.data(withJSONObject: json!))
        #expect(decoded.evaluation?.positiveTagIDs == ["food"])
        #expect(decoded.evaluation?.cityReviews == nil)
    }

    @Test @MainActor func revisingEvaluationKeepsOldTagsAndSavesCityMemos() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        var trip = try Trip(legs: [leg("JP", ["도쿄"])], companion: .alone, purpose: .leisure)
        try trip.end(at: past)
        try trip.submit(TripEvaluation(satisfaction: 4, wouldRepeat: true,
                                       positiveTagIDs: ["food"], negativeTagIDs: ["crowded"],
                                       source: .postTrip), at: past)
        try await dependencies.store.create(trip)

        let viewModel = EvaluationViewModel()
        await viewModel.load(tripID: trip.id, dependencies: dependencies)
        #expect(viewModel.flowSteps.last == .cityReview(0))
        viewModel.cityReviews[0].rating = 5
        viewModel.cityReviews[0].liked = "  골목 산책  "
        viewModel.cityReviews[0].disliked = "   "
        await viewModel.submit(dependencies: dependencies, session: SessionStore())

        let saved = try #require(await dependencies.store.trip(id: trip.id)?.evaluation)
        #expect(saved.positiveTagIDs == ["food"])
        #expect(saved.negativeTagIDs == ["crowded"])
        #expect(saved.cityReviews == [CityReview(countryCode: "JP", city: "도쿄", rating: 5, liked: "골목 산책", disliked: nil)])
    }

    @Test func wantedTiersSurviveStoreReopen() async throws {
        let container = try SwiftDataAppStore.makeContainer(inMemory: true)
        let store = SwiftDataAppStore(container: container, countries: [], tags: [])
        #expect(try await store.loadWantedTiers() == nil)

        var tiers = WantedConceptTiers()
        tiers.place(.food, in: 1)
        tiers.place(.natureScenery, in: 1)
        tiers.place(.shopping, in: 3)
        tiers.place(.shopping, in: 2)
        tiers.avoidNote = "긴 이동"
        try await store.saveWantedTiers(tiers)

        let reopened = SwiftDataAppStore(container: container, countries: [], tags: [])
        let loaded = try await reopened.loadWantedTiers()
        #expect(loaded == tiers)
        #expect(loaded?.tier(of: .shopping) == 2)
        #expect(loaded?.tier(of: .nightlife) == nil)
    }

    @Test @MainActor func photoCandidatesAreSavedAsEndedTrips() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let viewModel = OnboardingViewModel()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(6 * 24 * 60 * 60)
        var candidate = TripCandidate(
            legs: [
                .init(countryCode: "CA", cities: ["Vancouver"], startDate: start, endDate: start),
                .init(countryCode: "US", cities: ["Seattle"], startDate: start, endDate: end)
            ],
            photoAssetIDs: []
        )
        candidate.state = .recorded
        viewModel.candidates = [candidate]
        await viewModel.commitCandidates(dependencies)
        let trips = await dependencies.allTrips()
        #expect(trips.map(\.status) == [.ended])
        #expect(trips.first?.endedAt == end)
        #expect(trips.first?.legs.map(\.countryCode) == ["CA", "US"])
    }

    @Test @MainActor func photoGroupingFollowsDatesAcrossCountriesAndCities() {
        let day: TimeInterval = 24 * 60 * 60
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        func photo(_ code: String?, _ city: String?, _ offset: Double) -> TripCandidate.Photo {
            .init(countryCode: code, city: city, date: base.addingTimeInterval(offset * day), assetID: "\(offset)")
        }
        let candidates = TripCandidate.group([
            photo("CA", "Vancouver", 0), photo("CA", "Banff", 3), photo("CA", "Calgary", 5.9),
            photo("US", "Los Angeles", 6.5), photo("US", "Las Vegas", 8), photo("US", "Page", 9),
            photo("US", "Springdale", 10), photo("US", "Los Angeles", 11),
            photo(nil, "Seoul", 12),
            photo("JP", "Tokyo", 13), photo("JP", "Tokyo", 14),
            photo("JP", "Osaka", 20), photo("JP", "Osaka", 21)
        ])
        // 집 사진과 3일 넘는 공백에서 끊긴다. 최신순.
        // 이틀 이상 사진이 있는 도시만 남는다. 캐나다는 모두 하루라 사진이 가장 많은(동률이면 먼저 간) 도시 하나만 남는다.
        #expect(candidates.map(\.title) == ["Osaka", "Tokyo", "Vancouver·Los Angeles"])
        let road = candidates[2]
        #expect(road.legs.map(\.countryCode) == ["CA", "US"])
        #expect(road.photoAssetIDs.count == 8)

        let viewModel = OnboardingViewModel()
        viewModel.candidates = candidates
        let suggestion = viewModel.mergeSuggestion(for: candidates[0].id)
        #expect(suggestion?.id == candidates[1].id)
        viewModel.merge(candidates[0].id, with: candidates[1].id)
        #expect(viewModel.candidates.first?.legs.count == 1)
        #expect(viewModel.candidates.first?.title == "Tokyo·Osaka")
        #expect(viewModel.candidates.first?.photoAssetIDs.first == "13.0")
    }

    @Test func placeTitlesShowFourAndShortenFromFive() {
        #expect(PlaceTitle.compact(["A", "B", "C", "D"], separator: " · ") == "A · B · C · D")
        #expect(PlaceTitle.compact(["A", "B", "C", "D", "E", "F"], separator: "·") == "A·B·C 외 3곳")
    }

    @Test @MainActor func onboardingDraftRestoresStepAndInputsWithoutDuplicatingTrips() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let trip = try await dependencies.tripService.createTrip(
            legs: [leg("JP", ["교토"])], companion: .unknown, purpose: .leisure, now: past
        )
        let first = OnboardingViewModel()
        await first.restore(dependencies)
        first.homeCountryCode = "KR"
        first.entryMode = .photoScan
        first.recordedTrips = [OnboardingTripSummary(id: trip.id, title: "교토", period: "", concepts: nil)]
        first.conceptQueue = [trip.id]
        first.stage = .concepts
        first.placeConcept(.food, in: 1)
        first.tiers.avoidNote = "긴 이동"
        await first.saveDraft(dependencies)

        let second = OnboardingViewModel()
        await second.restore(dependencies)
        #expect(second.stage == .concepts)
        #expect(second.homeCountryCode == "KR")
        #expect(second.recordedTrips.map(\.id) == [trip.id])
        #expect(second.tiers.tier(of: .food) == 1)
        #expect(second.tiers.avoidNote == "긴 이동")
        #expect(await dependencies.allTrips().count == 1)

        // 후보 검토 중에 꺼졌다면 입력 경로 선택으로 돌아온다.
        second.stage = .candidates
        await second.saveDraft(dependencies)
        let third = OnboardingViewModel()
        await third.restore(dependencies)
        #expect(third.stage == .entryModeSelection)

        try await dependencies.store.deleteAllUserData()
        #expect(try await dependencies.store.loadOnboardingDraft() == nil)
    }
}
