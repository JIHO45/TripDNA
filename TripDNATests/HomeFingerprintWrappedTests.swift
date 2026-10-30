import Foundation
import Testing
@testable import TripDNA

@MainActor
struct HomeFingerprintWrappedTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// 끝난 여행. 컨셉이 nil이면 컨셉을 고르지 않은 여가 여행이다.
    private func trip(
        _ id: String,
        _ concept: TripConcept?,
        month: Int,
        year: Int = 2026,
        purpose: TripPurpose = .leisure,
        country: String = "JP",
        city: String? = nil
    ) throws -> Trip {
        let leg = try TripLeg(
            countryCode: country, cities: city.map { [$0] } ?? [],
            startDate: day(year, month, 10), endDate: day(year, month, 14)
        )
        var trip = try Trip(
            id: id, legs: [leg], companion: .alone, purpose: purpose,
            concepts: concept.flatMap { purpose == .leisure ? try? TripConcepts(primary: $0) : nil },
            createdAt: day(year, month, 1)
        )
        try trip.start(at: day(year, month, 10))
        try trip.end(at: day(year, month, 14))
        return trip
    }

    private func fingerprint(_ concepts: [TripConcept]) throws -> ConceptFingerprint {
        let trips = try concepts.enumerated().map { try trip("t\($0.offset)", $0.element, month: 1 + $0.offset) }
        return try #require(ConceptFingerprint(trips: trips, now: day(2026, 12, 20)))
    }

    // MARK: 지문 문장

    @Test func headlineCountsTopConceptOutOfAllTrips() throws {
        let print = try fingerprint([.food, .food, .food, .cityExploration, .cityExploration, .natureScenery])
        #expect(print.total == 6)
        #expect(print.homeHeadlineKo == "6번 중 3번이 미식 여행이었어요")
        #expect(print.detailHeadlineKo == "가장 많이 떠난 건 미식 여행이에요")
    }

    @Test func headlineKeepsTiesTogetherWithParticle() throws {
        let print = try fingerprint([.food, .food, .cityExploration, .cityExploration])
        #expect(print.top == [.cityExploration, .food] || print.top == [.food, .cityExploration])
        // 받침 있는 말 뒤는 "과", 없는 말 뒤는 "와".
        #expect(print.detailHeadlineKo.hasSuffix("여행을 2번씩 떠났어요"))
        #expect(print.detailHeadlineKo.contains("미식과 도시") || print.detailHeadlineKo.contains("도시와 미식"))
        #expect(print.homeHeadlineKo == print.detailHeadlineKo)
    }

    @Test func headlineCountsThreeOrMoreTiesInsteadOfListingNames() throws {
        let print = try fingerprint([.food, .cityExploration, .natureScenery])
        #expect(print.top.count == 3)
        #expect(print.homeHeadlineKo == "3가지 여행을 1번씩 떠났어요")
        #expect(print.detailHeadlineKo == print.homeHeadlineKo)
    }

    @Test func displayCoverSkipsAutoFilledPhotos() throws {
        var t = try trip("a", .food, month: 1)
        func photo(_ day: Int, _ selection: PhotoSelection) -> DailyPhoto {
            DailyPhoto(id: "\(day)", tripID: "a", tripDayIndex: day, storagePath: "p\(day)",
                       selection: selection, dayReaction: nil, createdAt: Date())
        }
        #expect(t.displayCoverPath(photos: [photo(0, .autoFallback)]) == nil)
        #expect(t.displayCoverPath(photos: [photo(0, .autoFallback), photo(2, .manual), photo(1, .manual)]) == "p1")
        t.setCoverPhoto(storagePath: "cover")
        #expect(t.displayCoverPath(photos: [photo(1, .manual)]) == "cover")
    }

    @Test func headlineForOneTripDoesNotClaimMost() throws {
        let print = try fingerprint([.food])
        #expect(print.detailHeadlineKo == "첫 기록은 미식 여행이에요")
        #expect(print.homeHeadlineKo == "첫 기록은 미식 여행이에요")
    }

    @Test func fingerprintKeepsTripIDsPerConceptAndCountsObligationSeparately() throws {
        let trips = [
            try trip("a", .food, month: 1), try trip("b", .food, month: 2), try trip("c", .relaxation, month: 3),
            try trip("biz", nil, month: 4, purpose: .obligation)
        ]
        let print = try #require(ConceptFingerprint(trips: trips, now: day(2026, 12, 20)))
        #expect(print.tripIDs[.food] == ["a", "b"])
        #expect(print.tripIDs[.relaxation] == ["c"])
        #expect(ConceptFingerprint.obligationCount(in: trips, now: day(2026, 12, 20)) == 1)
        #expect(print.total == 3)
    }

    // MARK: 랭킹을 직접 바꿨다는 표시

    @Test func rankingReorderFlagPersistsUntilCleared() throws {
        let suite = "RankingReorderFlagTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(!RankingReorderFlag.isSet(defaults))
        RankingReorderFlag.mark(defaults)
        #expect(RankingReorderFlag.isSet(defaults))
        // 다시 만든 저장소 핸들에서도 남아 있어야 한다.
        #expect(RankingReorderFlag.isSet(try #require(UserDefaults(suiteName: suite))))
        RankingReorderFlag.clear(defaults)
        #expect(!RankingReorderFlag.isSet(defaults))
    }

    // MARK: Wrapped 카드 선택

    private func year(
        _ trips: [Trip], reordered: Bool, ranking: [String] = [], now: Date? = nil
    ) throws -> WrappedYear {
        WrappedYear.make(
            year: 2026, now: now ?? day(2026, 12, 20), trips: trips,
            ranking: try TripRanking(tripIDsOrdered: ranking), rankingReordered: reordered,
            photos: [], calendar: calendar
        )
    }

    private var fourTrips: [Trip] {
        get throws {
            [try trip("a", .food, month: 4, city: "오사카"), try trip("b", .food, month: 5),
             try trip("c", .food, month: 7), try trip("d", .cityExploration, month: 9)]
        }
    }

    @Test func wrappedSkipsTopTripUnlessRankingWasReordered() throws {
        let trips = try fourTrips
        let plain = try year(trips, reordered: false, ranking: ["d", "a", "b", "c"])
        #expect(plain.topTrip == nil)
        #expect(plain.cards == [.movement, .topConcept, .concepts, .photos, .finish])

        let reordered = try year(trips, reordered: true, ranking: ["d", "a", "b", "c"])
        #expect(reordered.topTrip != nil)
        #expect(reordered.cards == [.movement, .topTrip, .topConcept, .concepts, .photos, .finish])
    }

    @Test func wrappedCountsOnlyThisYearsLeisureTripsAndSaysSoFarInDecember() throws {
        let trips = try fourTrips + [
            try trip("biz", nil, month: 6, purpose: .obligation, country: "DE"),
            try trip("old", .food, month: 6, year: 2025)
        ]
        let wrapped = try year(trips, reordered: false)
        #expect(wrapped.tripCount == 4)
        #expect(wrapped.countryCount == 1)
        #expect(wrapped.months == [4, 5, 7, 9])
        #expect(wrapped.periodKo == "올해 지금까지")
        #expect(wrapped.topConceptCaptionKo == "4번 중 3번이 미식 여행이었어요")
        // 1월에 다시 열면 회고 연도를 적는다.
        #expect(try year(trips, reordered: false, now: day(2027, 1, 5)).periodKo == "2026년")
    }

    @Test func wrappedWithOneTripAvoidsMostAndFirstPlaceWording() throws {
        let only = [try trip("a", .food, month: 4, city: "오사카")]
        let wrapped = try year(only, reordered: true, ranking: ["a"])
        #expect(wrapped.isSingleTrip)
        #expect(wrapped.topTrip == nil)
        #expect(!wrapped.cards.contains(.topTrip))
        #expect(wrapped.topConceptEyebrowKo == "올해의 여행")
        #expect(wrapped.topConceptCaptionKo == "올해는 오사카로 한 번 떠났어요")
        for text in [wrapped.topConceptEyebrowKo, wrapped.topConceptCaptionKo, wrapped.topConceptBigKo] {
            #expect(!text.contains("가장 많이"))
            #expect(!text.contains("1위"))
        }
    }

    @Test func wrappedTieShowsBothConceptsAndEmptyYearHasNoCards() throws {
        let tie = try year(
            [try trip("a", .food, month: 1), try trip("b", .cityExploration, month: 2)], reordered: false
        )
        #expect(tie.topConceptBigKo == "도시 · 미식" || tie.topConceptBigKo == "미식 · 도시")
        #expect(tie.topConceptCaptionKo == "2번 중 1번씩")

        let empty = try year([try trip("biz", nil, month: 3, purpose: .obligation)], reordered: false)
        #expect(empty.isEmpty)
        #expect(empty.cards.isEmpty)
    }

    @Test func wrappedBannerFollowsSeasonAndPastYears() throws {
        let trips = [try trip("old", .food, month: 6, year: 2025)]
        let service = WrappedService(calendar: calendar)
        #expect(WrappedBanner.make(now: day(2026, 12, 20), trips: [], service: service, calendar: calendar) == .open(year: 2026))
        #expect(WrappedBanner.make(now: day(2027, 1, 10), trips: [], service: service, calendar: calendar) == .open(year: 2026))
        #expect(WrappedBanner.make(now: day(2026, 10, 24), trips: trips, service: service, calendar: calendar) == .pastAvailable(year: 2025))
        #expect(WrappedBanner.make(now: day(2026, 10, 24), trips: [], service: service, calendar: calendar) == .notYet)
        // 올해 여행만 있으면 아직 다시 볼 지난 해가 없다.
        let thisYear = [try trip("now", .food, month: 3)]
        #expect(WrappedBanner.make(now: day(2026, 10, 24), trips: thisYear, service: service, calendar: calendar) == .notYet)
    }

    // MARK: 홈 상단 카드

    @Test func homeTopCardFollowsSituation() throws {
        let tiers = { () -> WantedConceptTiers in var t = WantedConceptTiers(); t.place(.food, in: 1); return t }()
        let ended = try trip("e", .food, month: 1)
        func saved(_ id: String) -> SavedCity {
            SavedCity(
                card: .init(
                    cityID: id, cityName: id, country: "JP", isExploration: false, seasonCheckNeeded: false,
                    reason: "", caveat: "", cost: nil, conditions: [], conditionCheckNeeded: false
                ),
                savedAt: Date(), conditionSummary: ""
            )
        }
        let four = ["a", "b", "c", "d"].map(saved)
        #expect(HomeViewModel.topCard(trips: [], savedCities: [], tiers: nil) == .firstUse)
        #expect(HomeViewModel.topCard(trips: [], savedCities: [], tiers: tiers) == .invitation)
        #expect(HomeViewModel.topCard(trips: [ended], savedCities: [], tiers: nil) == .invitation)
        #expect(HomeViewModel.topCard(trips: [ended], savedCities: four, tiers: nil)
                == .recommendations(cities: Array(four.prefix(3))))
        var active = try Trip(legs: [TripLeg(countryCode: "JP", startDate: Date(), endDate: Date())], companion: .alone, purpose: .leisure)
        try active.start()
        #expect(HomeViewModel.topCard(trips: [ended, active], savedCities: [four[0]], tiers: nil) == .active(tripID: active.id))
    }
}
