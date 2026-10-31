import Foundation

@Observable
final class HomeViewModel {
    /// 홈 맨 위 카드는 상황에 맞는 하나만 보인다.
    enum TopCard: Equatable {
        case active(tripID: String)
        case upcoming(tripID: String, days: Int)
        /// 앱이 이미 가진 추천(저장한 도시) 최대 3개.
        case recommendations(cities: [SavedCity])
        /// 기록은 있고 추천도 예정 여행도 없을 때 추천을 권한다.
        case invitation
        /// 기록도 "원하는 여행"도 없는 처음.
        case firstUse
    }

    var trips: [Trip] = []
    var photos: [DailyPhoto] = []
    var savedCities: [SavedCity] = []
    var tiers: WantedConceptTiers?
    var banner: WrappedBanner = .notYet
    var isLoading = true

    var topCard: TopCard {
        Self.topCard(trips: trips, savedCities: savedCities, tiers: tiers)
    }

    var fingerprint: ConceptFingerprint? { ConceptFingerprint(trips: trips) }
    var obligationCount: Int { ConceptFingerprint.obligationCount(in: trips) }

    /// 평가를 기다리는 가장 최근 끝난 여행.
    var todoTrip: Trip? {
        trips.filter { $0.status == .ended }
            .max { ($0.legs.last?.endDate ?? $0.createdAt) < ($1.legs.last?.endDate ?? $1.createdAt) }
    }

    func trip(id: String) -> Trip? { trips.first { $0.id == id } }

    func load(_ dependencies: AppDependencies) async {
        defer { isLoading = false }
        trips = await dependencies.allTrips()
        photos = (try? await dependencies.store.photos(tripID: nil)) ?? []
        tiers = try? await dependencies.store.loadWantedTiers()
        savedCities = ((try? await dependencies.store.cityState().saved) ?? []).sorted { $0.savedAt > $1.savedAt }
        banner = WrappedBanner.make(now: Date(), trips: trips, service: dependencies.wrappedService)
    }

    /// 평가를 건너뛴다. 방문 사실만 남고, 나중에 여행 상세에서 고칠 수 있다.
    func skipEvaluation(_ trip: Trip, dependencies: AppDependencies, userID: String) async {
        guard let evaluation = try? TripEvaluation(satisfaction: nil, wouldRepeat: nil, source: .postTrip, skipped: true) else { return }
        _ = try? await dependencies.evaluationService.submit(tripID: trip.id, evaluation: evaluation, userID: userID)
        EvaluationNotificationService.cancel(for: trip.id)
        await load(dependencies)
    }

    // MARK: 상황 판단

    static func topCard(
        trips: [Trip],
        savedCities: [SavedCity],
        tiers: WantedConceptTiers?,
        now: Date = Date()
    ) -> TopCard {
        if let active = trips.first(where: { $0.status == .active }) {
            return .active(tripID: active.id)
        }
        let upcoming = trips
            .filter { $0.status == .planned }
            .compactMap { trip in trip.daysUntilStart.map { (trip, $0) } }
            .min { $0.1 < $1.1 }
        if let upcoming {
            return .upcoming(tripID: upcoming.0.id, days: upcoming.1)
        }
        if !savedCities.isEmpty {
            return .recommendations(cities: Array(savedCities.prefix(3)))
        }
        if trips.isEmpty, tiers?.isEmpty ?? true {
            return .firstUse
        }
        return .invitation
    }

    /// 헤더의 작은 줄과 제목.
    var header: (status: String, title: String) {
        switch topCard {
        case .active(let id):
            guard let trip = trip(id: id) else { return (String(localized: "Traveling"), "") }
            return (String(localized: "Traveling"), String(localized: "Day \(dayIndex(of: trip)) in \(Self.placeName(trip))"))
        case .upcoming(let id, let days):
            let place = trip(id: id).map(Self.placeName) ?? ""
            return (String(localized: "Upcoming trip"), String(localized: "\(days) days until \(place)"))
        case .recommendations, .invitation:
            return (String(localized: "Planning your next trip"), String(localized: "Where to next?"))
        case .firstUse:
            return (String(localized: "Welcome to TripDNA"), String(localized: "What kind of trip do you want?"))
        }
    }

    func hasTodayPhoto(for trip: Trip) -> Bool {
        let index = dayIndex(of: trip)
        return photos.contains { $0.tripID == trip.id && $0.tripDayIndex == index }
    }

    func dayIndex(of trip: Trip, now: Date = Date()) -> Int {
        let start = trip.startedAt ?? trip.legs.first?.startDate ?? now
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: now)
        ).day ?? 0
        return max(1, days + 1)
    }

    /// 도시가 있으면 첫 도시, 없으면 첫 나라.
    static func placeName(_ trip: Trip) -> String {
        guard let leg = trip.legs.first else { return "" }
        return leg.cities.first ?? CountryCatalog.name(for: leg.countryCode)
    }

    func coverPath(for trip: Trip) -> String? {
        trip.displayCoverPath(photos: photos)
    }
}
