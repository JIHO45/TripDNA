//
//  TripDNATests.swift
//  TripDNATests
//
//  Created by 박지호 on 7/24/26.
//

import Foundation
import Testing
@testable import TripDNA

/// 주어진 순서를 그대로 돌려주는 국가 저장소. 추천 결과가 저장소의 조회 순서에
/// 흔들리지 않는지 확인하는 데 쓴다.
private struct OrderedCountryRepository: CountryRepository {
    let ordered: [CountryProfile]

    func profiles() async throws -> [CountryProfile] { ordered }

    func profile(countryCode: String) async throws -> CountryProfile? {
        ordered.first { $0.countryCode == countryCode.uppercased() }
    }
}

struct TripDNATests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test func tripLedgerEnforcesEvaluationInvariants() throws {
        let trip = try makeTrip(id: "multi", countryCodes: ["JP", "TH"])
        var endedTrip = trip
        try endedTrip.end(at: date(2026, 7, 10))

        let invalid = try TripEvaluation(
            satisfaction: 5,
            wouldRepeat: true,
            source: .postTrip
        )
        #expect(throws: DomainValidationError.invalidBestLeg) {
            try endedTrip.submit(invalid)
        }

        let valid = try TripEvaluation(
            satisfaction: 5,
            wouldRepeat: true,
            bestLegCountryCode: "JP",
            positiveTagIDs: ["food"],
            tagLegAttribution: ["food": "JP"],
            source: .postTrip
        )
        try endedTrip.submit(valid, at: date(2026, 7, 11))
        #expect(endedTrip.status == .evaluated)
        #expect(throws: DomainValidationError.evaluationAlreadySubmitted) {
            try endedTrip.submit(valid)
        }
    }

    @Test func calibratedSatisfactionUsesAbsoluteFallbackForTwoTrips() throws {
        let evaluation = try TripEvaluation(
            satisfaction: 5,
            wouldRepeat: true,
            source: .postTrip
        )
        let service = UTVReplayService()

        #expect(service.calibratedSatisfaction(
            evaluation: evaluation,
            rank: 2,
            rankedTripCount: 2
        ) == 1)
        #expect(abs(service.calibratedSatisfaction(
            evaluation: evaluation,
            rank: 2,
            rankedTripCount: 4
        ) - 0.7666666667) < 0.0001)
    }

    @Test func replayIsDeterministicAndDefersGreyCountries() throws {
        var confirmedTrip = try makeTrip(id: "confirmed", countryCodes: ["JP"])
        try confirmedTrip.end(at: date(2026, 1, 2))
        try confirmedTrip.submit(TripEvaluation(
            satisfaction: 5,
            wouldRepeat: true,
            positiveTagIDs: ["outdoor"],
            source: .postTrip
        ), at: date(2026, 1, 3))

        var greyTrip = try makeTrip(id: "grey", countryCodes: ["ZZ"])
        try greyTrip.end(at: date(2026, 2, 2))
        try greyTrip.submit(TripEvaluation(
            satisfaction: 4,
            wouldRepeat: true,
            source: .postTrip
        ), at: date(2026, 2, 3))

        let countries = [
            profile(code: "JP", natureUrban: -0.8),
            profile(code: "ZZ", natureUrban: 0.9, status: .grey)
        ]
        let outdoor = TagDefinition(
            id: "outdoor",
            labelKo: "자연/트레킹",
            group: .interest,
            routing: [.taste, .interest],
            axisSignature: [.natureUrban: -0.6],
            polarityPairID: nil,
            constraintTarget: nil,
            qualityTarget: false
        )
        let service = UTVReplayService()
        let first = service.replay(
            userID: "user",
            trips: [greyTrip, confirmedTrip],
            ranking: nil,
            countries: countries,
            tags: [outdoor],
            now: date(2026, 3, 1)
        )
        let second = service.replay(
            userID: "user",
            trips: [confirmedTrip, greyTrip],
            ranking: nil,
            countries: countries,
            tags: [outdoor],
            now: date(2026, 3, 1)
        )

        #expect(first.vector == second.vector)
        #expect(first.deferredTripIDs == ["grey"])
        #expect(first.vector.axes.natureUrban < 0)
        #expect(first.vector.confidence.natureUrban > 0)
    }

    @Test func midSatisfactionStillMovesAxesTowardTrip() throws {
        var trip = try makeTrip(id: "mid", countryCodes: ["JP"])
        try trip.end(at: date(2026, 1, 2))
        try trip.submit(TripEvaluation(
            satisfaction: 3,
            wouldRepeat: false,
            source: .postTrip
        ), at: date(2026, 1, 3))

        let result = UTVReplayService().replay(
            userID: "user",
            trips: [trip],
            ranking: nil,
            countries: [profile(code: "JP", natureUrban: -0.8)],
            tags: [],
            now: date(2026, 3, 1)
        )

        #expect(result.vector.axes.natureUrban < -0.01)
        #expect(result.vector.confidence.natureUrban > 0)
        #expect(result.vector.confidence.natureUrban <= 0.35)
    }

    @Test func firstHighSatisfactionTripMovesStronglyWithCappedConfidence() throws {
        var trip = try makeTrip(id: "love", countryCodes: ["JP"])
        try trip.end(at: date(2026, 1, 2))
        try trip.submit(TripEvaluation(
            satisfaction: 5,
            wouldRepeat: true,
            positiveTagIDs: ["outdoor"],
            source: .postTrip
        ), at: date(2026, 1, 3))

        let outdoor = TagDefinition(
            id: "outdoor",
            labelKo: "자연/트레킹",
            group: .interest,
            routing: [.taste, .interest],
            axisSignature: [.natureUrban: -0.6],
            polarityPairID: nil,
            constraintTarget: nil,
            qualityTarget: false
        )
        let result = UTVReplayService().replay(
            userID: "user",
            trips: [trip],
            ranking: nil,
            countries: [profile(code: "JP", natureUrban: -0.8)],
            tags: [outdoor],
            now: date(2026, 3, 1)
        )

        // 첫 고평가는 스텝 상한(0.45)까지 세게 당기고, 신뢰도는 콜드스타트 캡 이하.
        #expect(result.vector.axes.natureUrban <= -0.4)
        #expect(result.vector.confidence.natureUrban <= 0.35)
        #expect(result.vector.confidence.natureUrban > 0)
    }

    @Test func rankingPreviewDoesNotPersistButSaveDoes() async throws {
        var first = try makeTrip(id: "first", countryCodes: ["JP"])
        try first.end()
        try first.submit(TripEvaluation(
            satisfaction: 5,
            wouldRepeat: true,
            source: .postTrip
        ))
        var second = try makeTrip(id: "second", countryCodes: ["TH"])
        try second.end()
        try second.submit(TripEvaluation(
            satisfaction: 3,
            wouldRepeat: false,
            source: .postTrip
        ))
        let initial = try TripRanking(tripIDsOrdered: ["first", "second"])
        let store = InMemoryAppStore(
            trips: [first, second],
            ranking: initial,
            countries: [
                profile(code: "JP", natureUrban: 0.8),
                profile(code: "TH", natureUrban: -0.4)
            ]
        )
        let evaluation = EvaluationService(
            trips: store,
            rankings: store,
            countries: store,
            tags: store,
            feedback: store,
            utv: store,
            events: store,
            replay: UTVReplayService()
        )
        let service = RankingService(
            trips: store,
            rankings: store,
            evaluationService: evaluation,
            events: store
        )
        try await store.create(CardFeedback(
            id: "saved-jp",
            countryCode: "JP",
            slot: .bestMatch,
            action: .save,
            reason: nil,
            excludeUntil: nil,
            revokedAt: nil,
            createdAt: date(2026, 7, 1)
        ))
        var draft = initial
        draft.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        let preview = try await service.preview(
            ranking: draft,
            userID: "user",
            now: date(2026, 7, 2)
        )
        #expect(try await store.currentRanking()?.tripIDsOrdered == ["first", "second"])

        let saved = try await service.save(
            draft,
            userID: "user",
            at: date(2026, 7, 2)
        )
        #expect(preview.vector.axes == saved.vector.axes)
        #expect(preview.vector.confidence == saved.vector.confidence)
        #expect(try await store.currentRanking()?.tripIDsOrdered == ["second", "first"])
        #expect(store.storedEvents.map(\.type).contains(.rankingAdjusted))
        #expect(store.storedEvents.map(\.type).contains(.utvRecomputed))
    }

    @Test func skipDoesNotExcludeAndDislikeDoes() async throws {
        let store = InMemoryAppStore(countries: [
            profile(code: "JP", natureUrban: 0.8),
            profile(code: "TH", natureUrban: -0.8),
            profile(code: "FR", natureUrban: 0.2)
        ])
        let service = RecommendationService(
            countries: store,
            feedbackRepository: store,
            events: store
        )
        let vector = UserTasteVector(
            userID: "user",
            axes: TasteAxes(
                natureUrban: 0.8,
                energyLevel: 0,
                planningStyle: 0,
                socialMode: 0,
                noveltyAppetite: 0
            ),
            confidence: TasteAxes(
                natureUrban: 0.8,
                energyLevel: 0,
                planningStyle: 0,
                socialMode: 0,
                noveltyAppetite: 0
            ),
            ledgerVersion: 1,
            recomputedAt: date(2026, 7, 1)
        )
        _ = try await service.applyFeedback(
            countryCode: "JP",
            slot: .bestMatch,
            action: .skip,
            at: date(2026, 7, 1)
        )
        let afterSkip = try await service.generateThreeSlots(
            vector: vector,
            interestTagIDs: [],
            visitedCountryCodes: [],
            now: date(2026, 7, 2)
        )
        #expect(afterSkip.contains { $0.countryCode == "JP" })

        _ = try await service.applyFeedback(
            countryCode: "JP",
            slot: .bestMatch,
            action: .dislike,
            at: date(2026, 7, 2)
        )
        let afterDislike = try await service.generateThreeSlots(
            vector: vector,
            interestTagIDs: [],
            visitedCountryCodes: [],
            now: date(2026, 7, 3)
        )
        #expect(!afterDislike.contains { $0.countryCode == "JP" })
    }

    @Test func nonBestSlotsExcludeNearPerfectMatches() async throws {
        // matchingAxes가 좁아서(자연/도시 1축) 매치 스코어는 높지만, 다른 축에서는
        // 취향과 크게 다른 "가짜 새로운 도전" 후보가 fresh_stretch를 차지하면 안 된다.
        let best = CountryProfile(
            countryCode: "BEST",
            name: "Best",
            nameKo: "베스트",
            status: .confirmed,
            tasteCore: TasteAxes(natureUrban: 0.8, energyLevel: 0, planningStyle: 0, socialMode: 0, noveltyAppetite: 0),
            matchingAxes: [.natureUrban],
            interestTags: ["food": 1.0],
            constraints: CountryConstraints(cost: 0.5, climate: 0.5),
            popularity: 0.5
        )
        let fakeFresh = CountryProfile(
            countryCode: "FAKE",
            name: "Fake",
            nameKo: "가짜",
            status: .confirmed,
            tasteCore: TasteAxes(natureUrban: 0.8, energyLevel: 0.9, planningStyle: 0.9, socialMode: 0.9, noveltyAppetite: 0.9),
            matchingAxes: [.natureUrban],
            interestTags: ["food": 0.8],
            constraints: CountryConstraints(cost: 0.5, climate: 0.5),
            popularity: 0.5
        )
        let genuinelyFresh = CountryProfile(
            countryCode: "REAL",
            name: "Real",
            nameKo: "진짜",
            status: .confirmed,
            tasteCore: TasteAxes(natureUrban: 0.8, energyLevel: 0.7, planningStyle: 0, socialMode: 0, noveltyAppetite: 0),
            matchingAxes: [.natureUrban],
            interestTags: ["shopping": 0.8],
            constraints: CountryConstraints(cost: 0.5, climate: 0.5),
            popularity: 0.5
        )
        let store = InMemoryAppStore(countries: [best, fakeFresh, genuinelyFresh])
        let service = RecommendationService(countries: store, feedbackRepository: store, events: store)
        let vector = UserTasteVector(
            userID: "user",
            axes: TasteAxes(natureUrban: 0.8, energyLevel: 0, planningStyle: 0, socialMode: 0, noveltyAppetite: 0),
            confidence: TasteAxes(natureUrban: 0.8, energyLevel: 0, planningStyle: 0, socialMode: 0, noveltyAppetite: 0),
            ledgerVersion: 1,
            recomputedAt: date(2026, 7, 1)
        )

        let slots = try await service.generateThreeSlots(
            vector: vector,
            interestTagIDs: ["food"],
            visitedCountryCodes: [],
            now: date(2026, 7, 1)
        )

        let fresh = slots.first { $0.slot == .freshStretch }
        #expect(fresh?.countryCode != "FAKE")
        if let fresh {
            #expect(fresh.matchScore < 0.95)
        }
    }

    @Test func wrappedSeasonCrossesYearBoundary() throws {
        var trip = try makeTrip(
            id: "winter",
            countryCodes: ["JP"],
            start: date(2026, 12, 20),
            end: date(2026, 12, 25)
        )
        try trip.start(at: date(2026, 12, 20))
        try trip.end(at: date(2026, 12, 25))
        let service = WrappedService(calendar: calendar)

        #expect(service.isSeasonOpen(at: date(2026, 12, 15), trips: [trip]))
        #expect(service.isSeasonOpen(at: date(2027, 1, 15), trips: [trip]))
        #expect(!service.isSeasonOpen(at: date(2027, 1, 16), trips: [trip]))
    }

    @Test func quizScoresMissingAnswersWithoutInventingSignals() {
        let result = TasteQuizService().score(
            answers: [
                QuizAnswer(questionID: "Q1", signatures: [.natureUrban: 0.7]),
                QuizAnswer(questionID: "Q2", signatures: [.natureUrban: -0.7]),
                QuizAnswer(questionID: "Q3", signatures: [:])
            ],
            interestTagIDs: ["food", "culture", "outdoor", "beach"]
        )

        #expect(result.prior.natureUrban == 0)
        #expect(result.prior.energyLevel == 0)
        #expect(result.confidence.energyLevel == 0)
        #expect(result.interestTagIDs.count == 3)
    }

    @Test @MainActor func miniQuizAsksOneSingleAxisQuestionPerBlurryAxis() {
        let blurry: Set<TasteAxis> = [.planningStyle, .socialMode]
        let questions = QuizQuestionCatalog.miniQuizQuestions(for: blurry)

        let askedAxes = questions.map { question in
            Set(question.options.flatMap { $0.signature.keys })
        }
        #expect(questions.count == blurry.count)
        #expect(askedAxes.allSatisfy { $0.count == 1 })
        #expect(Set(askedAxes.flatMap { $0 }) == blurry)
        #expect(QuizQuestionCatalog.miniQuizQuestions(for: []).isEmpty)
    }

    @Test func coldStartTripsLeaveEveryAxisForTheMiniQuiz() {
        let coldStart = AxisConfidence(
            natureUrban: 0.35, energyLevel: 0.35, planningStyle: 0.2, socialMode: 0.35, noveltyAppetite: 0
        )
        #expect(TasteQuizService().axesRequiringQuestions(confidence: coldStart) == Set(TasteAxis.allCases))
    }

    @Test func comparisonAnchorPrefersSameScoreRecentLeisureTrip() async throws {
        var older = try makeTrip(id: "older", countryCodes: ["JP"])
        try older.end()
        try older.submit(TripEvaluation(
            satisfaction: 4,
            wouldRepeat: true,
            source: .postTrip
        ), at: date(2026, 1, 10))
        var recent = try makeTrip(id: "recent", countryCodes: ["TH"])
        try recent.end()
        try recent.submit(TripEvaluation(
            satisfaction: 4,
            wouldRepeat: true,
            source: .postTrip
        ), at: date(2026, 2, 10))
        let store = InMemoryAppStore()
        let service = EvaluationService(
            trips: store,
            rankings: store,
            countries: store,
            tags: store,
            feedback: store,
            utv: store,
            events: store,
            replay: UTVReplayService()
        )

        let anchor = service.selectComparisonAnchor(
            satisfaction: 4,
            excluding: "new",
            from: [older, recent]
        )
        #expect(anchor?.id == "recent")
    }

    // MARK: 영속성 (개발 2단계 완료 조건)

    @Test func tripEvaluationAndFingerprintSurviveRestart() async throws {
        let storeURL = URL.temporaryDirectory.appending(path: "TripDNA-\(UUID().uuidString).store")
        defer { removeStore(at: storeURL) }
        let profiles = try seedProfiles()

        // 1회차 실행: 여행 등록 → 종료 → 평가.
        do {
            let store = try makeStore(at: storeURL, countries: profiles)
            let trips = TripService(trips: store, events: store)
            let evaluations = EvaluationService(
                trips: store,
                rankings: store,
                countries: store,
                tags: store,
                feedback: store,
                utv: store,
                events: store,
                replay: UTVReplayService()
            )
            let leg = try TripLeg(
                countryCode: "JP",
                startDate: date(2026, 1, 1),
                endDate: date(2026, 1, 5)
            )
            let trip = try await trips.createTrip(
                legs: [leg],
                companion: .alone,
                purpose: .leisure,
                now: date(2026, 1, 1)
            )
            _ = try await trips.endTrip(id: trip.id, at: date(2026, 1, 5))
            _ = try await evaluations.submit(
                tripID: trip.id,
                evaluation: TripEvaluation(
                    satisfaction: 5,
                    wouldRepeat: true,
                    positiveTagIDs: ["outdoor"],
                    source: .postTrip
                ),
                userID: "user",
                at: date(2026, 1, 6)
            )
            try await store.saveProfile(UserProfile(
                id: "user",
                locale: "ko_KR",
                onboardingStatus: .done,
                homeCountryCode: "KR",
                departureAirportCode: nil,
                createdAt: date(2026, 1, 1)
            ))
        }

        // 2회차 실행: 같은 파일을 새 컨테이너로 다시 연다.
        let reopened = try makeStore(at: storeURL, countries: profiles)
        let restoredTrips = try await reopened.trips()
        let restoredTrip = try #require(restoredTrips.first)

        #expect(restoredTrips.count == 1)
        #expect(restoredTrip.status == .evaluated)
        #expect(restoredTrip.evaluation?.satisfaction == 5)
        #expect(restoredTrip.legs.first?.countryCode == "JP")

        let vector = try #require(try await reopened.currentUTV())
        #expect(vector.ledgerVersion > 0)
        #expect(vector.confidence.natureUrban > 0)

        // 재실행 시 온보딩을 다시 돌리지 않기 위한 상태도 남아 있어야 한다.
        let restoredProfile = try #require(try await reopened.loadProfile())
        #expect(restoredProfile.homeCountryCode == "KR")
        #expect(restoredProfile.onboardingStatus == .done)
    }

    private func makeStore(
        at url: URL,
        countries: [CountryProfile]
    ) throws -> SwiftDataAppStore {
        SwiftDataAppStore(
            container: try SwiftDataAppStore.makeContainer(url: url),
            countries: countries,
            tags: []
        )
    }

    /// SwiftData는 저장 파일과 함께 -shm/-wal 사이드카를 만든다.
    private func removeStore(at url: URL) {
        let directory = url.deletingLastPathComponent()
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(
                at: directory.appending(path: url.lastPathComponent + suffix)
            )
        }
    }

    // MARK: 추천 결정성·분화 (개발 1단계 완료 조건)

    @Test func seedCountriesFillEveryMatchingAxisAndInterestTag() throws {
        let profiles = try seedProfiles()

        #expect(profiles.count == 30)
        for profile in profiles {
            // 1축만 쓰면 코사인 유사도가 부호 비교로 붕괴해 매치 점수가 1.0/0.0만 나온다.
            #expect(profile.matchingAxes == [
                .natureUrban, .energyLevel, .planningStyle, .socialMode
            ])
            #expect(Set(profile.interestTags.keys) == Self.interestTagIDs)
            #expect(profile.interestTags.values.allSatisfy { $0 != nil })
            #expect(profile.popularity != nil)
        }
    }

    @Test func bestMatchDoesNotDependOnCountryLoadOrder() async throws {
        let profiles = try seedProfiles()
        let vector = tasteVector(
            axes: TasteAxes(
                natureUrban: 0.7,
                energyLevel: 0.3,
                planningStyle: 0.5,
                socialMode: -0.2,
                noveltyAppetite: 0
            )
        )

        var outcomes = Set<String>()
        for _ in 0..<10 {
            let countries = OrderedCountryRepository(ordered: profiles.shuffled())
            let store = InMemoryAppStore()
            let service = RecommendationService(
                countries: countries,
                feedbackRepository: store,
                events: store
            )
            let slots = try await service.generateThreeSlots(
                vector: vector,
                interestTagIDs: ["food", "culture"],
                visitedCountryCodes: [],
                now: date(2026, 7, 1)
            )
            outcomes.insert(slots.map(\.id).joined(separator: "|"))
        }

        #expect(outcomes.count == 1)
    }

    @Test func differentTastesGetDifferentBestMatches() async throws {
        let profiles = try seedProfiles()
        let personas: [(axes: TasteAxes, tags: Set<String>)] = [
            (TasteAxes(natureUrban: 0.7, energyLevel: -0.2, planningStyle: 0.6,
                       socialMode: -0.4, noveltyAppetite: 0), ["shopping", "food"]),
            (TasteAxes(natureUrban: -0.9, energyLevel: -0.5, planningStyle: 0.3,
                       socialMode: -0.5, noveltyAppetite: 0), ["outdoor"]),
            (TasteAxes(natureUrban: -0.5, energyLevel: -0.6, planningStyle: -0.3,
                       socialMode: 0.1, noveltyAppetite: 0), ["beach", "wellness"]),
            (TasteAxes(natureUrban: 0.2, energyLevel: 0.8, planningStyle: -0.6,
                       socialMode: 0.8, noveltyAppetite: 0), ["nightlife"]),
            (TasteAxes(natureUrban: -0.1, energyLevel: 0.4, planningStyle: 0.6,
                       socialMode: 0.3, noveltyAppetite: 0), ["history", "culture"])
        ]

        var bestMatches: [String] = []
        for persona in personas {
            let countries = OrderedCountryRepository(ordered: profiles)
            let store = InMemoryAppStore()
            let service = RecommendationService(
                countries: countries,
                feedbackRepository: store,
                events: store
            )
            let slots = try await service.generateThreeSlots(
                vector: tasteVector(axes: persona.axes),
                interestTagIDs: persona.tags,
                visitedCountryCodes: [],
                now: date(2026, 7, 1)
            )
            let best = try #require(slots.first { $0.slot == .bestMatch })
            #expect(best.notices.isEmpty)
            bestMatches.append(best.countryCode)
        }

        #expect(Set(bestMatches).count == personas.count)
    }

    @Test func largeTieGroupIsDisclosedInsteadOfFillingSlots() async throws {
        // 매치 스코어가 완전히 같은 후보 3개. 1순위를 단정할 근거가 없는 상태다.
        let store = InMemoryAppStore(countries: [
            profile(code: "AA", natureUrban: 0.5),
            profile(code: "BB", natureUrban: 0.5),
            profile(code: "CC", natureUrban: 0.5)
        ])
        let service = RecommendationService(
            countries: store,
            feedbackRepository: store,
            events: store
        )

        let slots = try await service.generateThreeSlots(
            vector: tasteVector(
                axes: TasteAxes(
                    natureUrban: 0.5,
                    energyLevel: 0,
                    planningStyle: 0,
                    socialMode: 0,
                    noveltyAppetite: 0
                )
            ),
            interestTagIDs: [],
            visitedCountryCodes: [],
            now: date(2026, 7, 1)
        )

        // 슬롯을 억지로 채우지 않고 best_match만 남기며, 동점 사실을 카드에 알린다.
        #expect(slots.map(\.slot) == [.bestMatch])
        #expect(slots.first?.countryCode == "AA")
        #expect(slots.first?.notices.count == 1)
    }

    @Test func lowConfidenceSoftensMatchScoreAndAvoidsAssertingRank() async throws {
        let profiles = try seedProfiles()
        let axes = TasteAxes(
            natureUrban: -1,
            energyLevel: -1,
            planningStyle: -0.5,
            socialMode: 0,
            noveltyAppetite: 0
        )
        func slots(confidence: Double) async throws -> [Recommendation] {
            let store = InMemoryAppStore()
            let service = RecommendationService(
                countries: OrderedCountryRepository(ordered: profiles),
                feedbackRepository: store,
                events: store
            )
            return try await service.generateThreeSlots(
                vector: tasteVector(axes: axes, confidence: confidence),
                interestTagIDs: [],
                visitedCountryCodes: [],
                now: date(2026, 7, 1)
            )
        }

        let confident = try await slots(confidence: 0.7)
        let uncertain = try await slots(confidence: 0.1)
        let confidentBest = try #require(confident.first { $0.slot == .bestMatch })
        let uncertainBest = try #require(uncertain.first { $0.slot == .bestMatch })

        // 축별 신뢰도가 모두 같으면 가중 코사인에서 약분되므로, 확신 수준은
        // 매치 스코어와 동점 판정을 통해서만 드러난다.
        #expect(uncertainBest.matchScore < confidentBest.matchScore)
        #expect(confidentBest.notices.isEmpty)
        #expect(!uncertainBest.notices.isEmpty)
        #expect(uncertain.count < confident.count)
    }

    @Test func seedDecoderMapsCountryNoveltyAndTagRouting() throws {
        let countryJSON = Data("""
        {
          "JP": {
            "name": "Japan",
            "nameKo": "일본",
            "status": "confirmed",
            "tasteCore": {
              "natureUrban": 0.5,
              "energyLevel": 0.1,
              "planningStyle": 0.6,
              "socialMode": -0.2,
              "noveltyDistance": null
            },
            "matchingAxes": ["natureUrban"],
            "interestTags": {"food": 0.9, "culture": null},
            "constraints": {"cost": 0.52, "climate": 0.42}
          }
        }
        """.utf8)
        let tagJSON = Data("""
        {
          "outdoor": {
            "labelKo": "자연/트레킹",
            "group": "interest",
            "routing": ["taste", "interest"],
            "axisSignature": {"natureUrban": -0.6},
            "polarityPairId": null,
            "constraintTarget": null,
            "qualityTarget": false
          }
        }
        """.utf8)
        let decoder = SeedDataDecoder()
        let countries = try decoder.decodeCountries(from: countryJSON)
        let tags = try decoder.decodeTags(from: tagJSON)

        #expect(countries.first?.countryCode == "JP")
        #expect(countries.first?.tasteCore.noveltyAppetite == 0)
        #expect(countries.first?.matchingAxes == [.natureUrban])
        #expect(tags.first?.routing == [.taste, .interest])
        #expect(tags.first?.axisSignature?[.natureUrban] == -0.6)
    }

    private static let interestTagIDs: Set<String> = [
        "food", "culture", "history", "outdoor", "beach",
        "nightlife", "shopping", "wellness", "sportsAndEvents"
    ]

    /// 앱 번들에 실제로 실리는 국가 시드. 단위 테스트는 호스트 앱 안에서 돌기 때문에
    /// Bundle.main이 앱 번들이다.
    private func seedProfiles() throws -> [CountryProfile] {
        let url = try #require(Bundle.main.url(forResource: "countries", withExtension: "json"))
        return try SeedDataDecoder().decodeCountries(from: Data(contentsOf: url))
    }

    private func tasteVector(axes: TasteAxes, confidence: Double = 0.7) -> UserTasteVector {
        UserTasteVector(
            userID: "user",
            axes: axes,
            confidence: TasteAxes(
                natureUrban: confidence,
                energyLevel: confidence,
                planningStyle: confidence,
                socialMode: confidence,
                noveltyAppetite: 0
            ),
            ledgerVersion: 1,
            recomputedAt: date(2026, 7, 1)
        )
    }

    private func makeTrip(
        id: String,
        countryCodes: [String],
        start: Date? = nil,
        end: Date? = nil
    ) throws -> Trip {
        let startDate = start ?? date(2026, 1, 1)
        let endDate = end ?? date(2026, 1, 5)
        let legs = try countryCodes.map {
            try TripLeg(
                countryCode: $0,
                startDate: startDate,
                endDate: endDate
            )
        }
        return try Trip(
            id: id,
            legs: legs,
            companion: .alone,
            purpose: .leisure,
            createdAt: startDate
        )
    }

    private func profile(
        code: String,
        natureUrban: Double,
        status: CountryStatus = .confirmed
    ) -> CountryProfile {
        CountryProfile(
            countryCode: code,
            name: code,
            nameKo: code,
            status: status,
            tasteCore: TasteAxes(
                natureUrban: natureUrban,
                energyLevel: 0,
                planningStyle: 0,
                socialMode: 0,
                noveltyAppetite: 0
            ),
            matchingAxes: [.natureUrban],
            interestTags: ["food": 0.8],
            constraints: CountryConstraints(cost: 0.5, climate: 0.5),
            popularity: 0.5
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
