import Foundation

/// 홈 하단 Wrapped 배너의 상태. 시즌 밖에도 숨기지 않는다 (docs/screens/wrapped-and-sharing.md, 2026-10-23 결정).
enum WrappedBanner: Equatable {
    /// 12/15~1/15 시즌. 그해 여행이 없어도 열리고, 들어가면 빈 화면이 나온다.
    case open(year: Int)
    /// 시즌 밖. 지난 해 기록으로 다시 만들 수 있다.
    case pastAvailable(year: Int)
    /// 시즌 밖이고 다시 볼 해도 없다.
    case notYet

    static func make(now: Date, trips: [Trip], service: WrappedService = WrappedService(), calendar: Calendar = .current) -> WrappedBanner {
        if let year = service.wrappedYear(at: now) { return .open(year: year) }
        let thisYear = calendar.component(.year, from: now)
        let past = trips.compactMap { WrappedYear.isCounted($0) ? WrappedYear.year(of: $0, calendar: calendar) : nil }
            .filter { $0 < thisYear }
        if let latest = past.max() { return .pastAvailable(year: latest) }
        return .notYet
    }
}

/// 그해 기록으로 만드는 Wrapped. 저장하지 않고 열 때마다 여행 기록에서 다시 만든다.
/// 의무 여행(출장 등)과 아직 떠나지 않은 여행은 모든 숫자에서 뺀다.
struct WrappedYear: Equatable {
    enum Card: String, Equatable {
        case movement, topTrip, topConcept, concepts, photos, finish
    }

    struct ConceptRow: Equatable, Identifiable {
        let tripID: String
        let month: Int
        let place: String
        /// 컨셉을 고르지 않은 여행은 nil ("고르지 않음").
        let concept: TripConcept?
        /// 대표 사진, 없으면 그 여행의 하루 한 장 중 하나.
        let coverPath: String?
        var id: String { tripID }
    }

    struct TopTrip: Equatable {
        let place: String
        let detail: String
        /// 공유 카드의 "나라 이름 표시"를 켰을 때만 쓰는 나라 이름. 도시 이름은 공유에 쓰지 않는다.
        let countriesKo: String
        let conceptKo: String?
        let coverPath: String?
    }

    let year: Int
    /// 그해가 아직 끝나지 않은 12월. "올해 지금까지"라고 말한다.
    let isInProgress: Bool
    let tripCount: Int
    let countryNames: [String]
    let cityCount: Int
    /// 여행이 있었던 달(1~12), 오름차순·중복 없음.
    let months: [Int]
    let fingerprint: ConceptFingerprint?
    let rows: [ConceptRow]
    /// 사용자가 랭킹 순서를 직접 저장했고 올해 여행이 둘 이상일 때만 있다.
    let topTrip: TopTrip?
    /// 하루 한 장 사진. 이 기기 안에서만 보이고 공유 이미지에는 넣지 않는다.
    let photos: [DailyPhoto]
    /// 올해 여행이 한 번이면 비교·순위 말투를 쓰지 않는다.
    let singleTripPlace: String?

    var countryCount: Int { countryNames.count }
    var isEmpty: Bool { tripCount == 0 }
    var isSingleTrip: Bool { tripCount == 1 }

    /// 보여줄 카드. ②는 랭킹을 직접 바꾼 사용자에게만, ③은 컨셉을 고른 여행이 있을 때만 나온다.
    var cards: [Card] {
        guard !isEmpty else { return [] }
        var result: [Card] = [.movement]
        if topTrip != nil { result.append(.topTrip) }
        if fingerprint != nil { result.append(.topConcept) }
        if !isSingleTrip { result.append(.concepts) }
        result.append(contentsOf: [.photos, .finish])
        return result
    }

    var periodKo: String { isInProgress ? "올해 지금까지" : "\(year)년" }

    /// 진행 중인 해는 "올해", 지난 해는 "2025년". 지난 해 화면에서 "올해"라고 말하지 않는다.
    var yearWordKo: String { isInProgress ? "올해" : "\(year)년" }

    var topConceptEyebrowKo: String { isSingleTrip ? "\(yearWordKo)의 여행" : "\(yearWordKo) 가장 많이 떠난 여행" }

    /// ③의 큰 글씨. 동점이면 함께 둔다.
    var topConceptBigKo: String {
        guard let fingerprint else { return "" }
        let names = fingerprint.top.map(\.labelKo).joined(separator: " · ")
        // 한 번뿐이면 "미식 여행"처럼 여행 단어까지 큰 제목에 둔다.
        return isSingleTrip ? "\(names)\n여행" : names
    }

    /// ③의 설명. 한 번뿐이면 "가장 많이" 같은 말을 쓰지 않는다.
    var topConceptCaptionKo: String {
        guard let fingerprint else { return "" }
        if isSingleTrip, let place = singleTripPlace {
            return "\(isInProgress ? "올해는" : "\(year)년에는") \(place)\(KoreanParticle.roParticle(after: place)) 한 번 떠났어요"
        }
        if fingerprint.isTie { return "\(fingerprint.total)번 중 \(fingerprint.topCount)번씩" }
        return fingerprint.homeHeadlineKo
    }

    // MARK: 만들기

    static func make(
        year: Int,
        now: Date,
        trips: [Trip],
        ranking: TripRanking?,
        rankingReordered: Bool,
        photos: [DailyPhoto],
        calendar: Calendar = .current
    ) -> WrappedYear {
        let annual = trips
            .filter { isCounted($0) && Self.year(of: $0, calendar: calendar) == year }
            .sorted { ($0.legs.first?.startDate ?? $0.createdAt) < ($1.legs.first?.startDate ?? $1.createdAt) }
        let ids = Set(annual.map(\.id))

        var countries: [String] = []
        for code in annual.flatMap({ $0.legs.map(\.countryCode) }) where !countries.contains(code) {
            countries.append(code)
        }
        let cities = Set(annual.flatMap { $0.legs.flatMap(\.cities) })
        let months = Set(annual.compactMap { $0.legs.first.map { calendar.component(.month, from: $0.startDate) } }).sorted()

        func cover(of trip: Trip) -> String? {
            trip.coverPhotoStoragePath ?? photos.first { $0.tripID == trip.id }?.storagePath
        }

        var topTrip: TopTrip?
        if rankingReordered, annual.count >= 2,
           let id = ranking?.tripIDsOrdered.first(where: ids.contains),
           let trip = annual.first(where: { $0.id == id }) {
            var parts = [trip.legs.first.map { "\(calendar.component(.month, from: $0.startDate))월" } ?? "", trip.durationKo]
            if let concept = trip.concepts?.primary { parts.append("\(concept.labelKo) 여행") }
            topTrip = TopTrip(place: trip.placeTitleKo, detail: parts.filter { !$0.isEmpty }.joined(separator: " · "),
                              countriesKo: ShareText.list(trip.legs.map { CountryCatalog.name(for: $0.countryCode) }), conceptKo: trip.concepts?.primary.labelKo, coverPath: cover(of: trip))
        }

        return WrappedYear(
            year: year,
            isInProgress: calendar.component(.year, from: now) == year,
            tripCount: annual.count,
            countryNames: countries.map(CountryCatalog.name(for:)),
            cityCount: cities.count,
            months: months,
            fingerprint: ConceptFingerprint(trips: annual, now: now),
            rows: annual.map { trip in
                ConceptRow(
                    tripID: trip.id,
                    month: trip.legs.first.map { calendar.component(.month, from: $0.startDate) } ?? 0,
                    place: trip.placeTitleKo,
                    concept: trip.concepts?.primary,
                    coverPath: cover(of: trip)
                )
            },
            topTrip: topTrip,
            photos: photos
                .filter { ids.contains($0.tripID) }
                .sorted { ($0.tripID, $0.tripDayIndex) < ($1.tripID, $1.tripDayIndex) },
            singleTripPlace: annual.count == 1 ? annual[0].placeTitleKo : nil
        )
    }

    /// Wrapped에 세는 여행: 여가이고 이미 떠난 것.
    static func isCounted(_ trip: Trip) -> Bool {
        trip.purpose == .leisure && trip.status != .planned
    }

    /// 여행이 끝나는 해. 나중에 등록한 지난 여행도 실제 다녀온 해에 들어간다.
    static func year(of trip: Trip, calendar: Calendar = .current) -> Int {
        let end = trip.legs.map(\.endDate).max() ?? trip.createdAt
        return calendar.component(.year, from: end)
    }
}

extension KoreanParticle {
    /// "오사카로", "서울로", "부산으로". ㄹ 받침은 받침이 없는 것처럼 "로".
    static func roParticle(after word: String) -> String {
        guard let scalar = word.unicodeScalars.last?.value, (0xAC00...0xD7A3).contains(scalar) else { return "로" }
        let final = (scalar - 0xAC00) % 28
        return final == 0 || final == 8 ? "로" : "으로"
    }
}

extension Trip {
    /// "4박 5일", 하루짜리는 "당일".
    var durationKo: String {
        let days = legs.reduce(0) { $0 + $1.days }
        return days <= 1 ? "당일" : "\(days - 1)박 \(days)일"
    }
}
