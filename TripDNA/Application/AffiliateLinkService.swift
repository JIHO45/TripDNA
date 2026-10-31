import Foundation

nonisolated enum AffiliateEntryPoint: Equatable, Sendable {
    case trip(daysUntilDeparture: Int)
    case recommendation(slot: RecommendationSlot)

    var subIDComponent: String {
        switch self {
        case .trip(let days):
            return "trip_d\(max(0, days))"
        case .recommendation(let slot):
            return "rec_\(slot.rawValue.replacingOccurrences(of: "_", with: ""))"
        }
    }

    var analyticsValue: String {
        switch self {
        case .trip: "trip"
        case .recommendation: "recommendation"
        }
    }
}

nonisolated enum ActivityCategory: String, CaseIterable, Sendable {
    case highlights
    case food
    case culture
    case history
    case outdoor
    case beach
    case nightlife
    case shopping
    case wellness
    case sportsAndEvents

    init?(tagID: String) {
        self.init(rawValue: tagID)
    }

    var label: String {
        switch self {
        case .highlights: String(localized: "Popular Activities")
        case .food: String(localized: "Food Tours")
        case .culture: String(localized: "Arts & Culture")
        case .history: String(localized: "History Tours")
        case .outdoor: String(localized: "Outdoors & Nature")
        case .beach: String(localized: "Beach & Relaxation")
        case .nightlife: String(localized: "Nightlife")
        case .shopping: String(localized: "Shopping")
        case .wellness: String(localized: "Wellness")
        case .sportsAndEvents: String(localized: "Sports & Events")
        }
    }

    var systemImage: String {
        switch self {
        case .highlights: "sparkles"
        case .food: "fork.knife"
        case .culture: "theatermasks"
        case .history: "building.columns"
        case .outdoor: "mountain.2"
        case .beach: "beach.umbrella"
        case .nightlife: "moon.stars"
        case .shopping: "bag"
        case .wellness: "leaf"
        case .sportsAndEvents: "ticket"
        }
    }

    var searchTerm: String {
        switch self {
        case .highlights: "things to do"
        case .food: "food tour"
        case .culture: "culture art"
        case .history: "history tour"
        case .outdoor: "outdoor nature"
        case .beach: "beach"
        case .nightlife: "nightlife"
        case .shopping: "shopping"
        case .wellness: "spa wellness"
        case .sportsAndEvents: "sports events"
        }
    }
}

nonisolated struct AffiliateProviderConfiguration: Equatable, Sendable {
    let providerName: String
    let searchBaseURL: URL
    /// 제휴 링크는 이 주소를 거쳐 `k_site`로 이동한다.
    let redirectURL: URL
    let partnerID: String?
    /// 라벨은 광고 ID에 묶여 저장되고 링크에 실을 수 없다. 그래서 진입 위치마다
    /// 광고를 하나씩 두고 대시보드에서 위치별 실적을 본다. 도시별 실적은 볼 수 없다.
    let tripAdID: String
    let recommendationAdID: String

    var isAffiliateActive: Bool {
        guard let partnerID else { return false }
        return !partnerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func adID(for entryPoint: AffiliateEntryPoint) -> String {
        switch entryPoint {
        case .trip: tripAdID
        case .recommendation: recommendationAdID
        }
    }

    /// Klook 제휴 대시보드(affiliate.klook.com)의 링크 변환기에서 만든 값.
    /// 광고 1535734는 여행 상세, 1535735는 추천 상세 위치다.
    nonisolated static let klook = AffiliateProviderConfiguration(
        providerName: "Klook",
        searchBaseURL: URL(string: "https://www.klook.com/ko/search/result/")!,
        redirectURL: URL(string: "https://affiliate.klook.com/redirect")!,
        partnerID: "141494",
        tripAdID: "1535734",
        recommendationAdID: "1535735"
    )
}

nonisolated struct AffiliateActivityLink: Identifiable, Equatable, Sendable {
    let id: String
    let providerName: String
    let countryCode: String
    let city: String
    let category: ActivityCategory
    let entryPoint: AffiliateEntryPoint
    let subID: String
    let url: URL
    let isAffiliateActive: Bool
}

/// 승인 전에는 검색 링크와 측정 구조만 제공하고, 승인 후에는 설정값만 주입한다.
/// 추천 점수에는 관여하지 않으며 이미 계산된 설명 태그를 검색 카테고리로만 사용한다.
nonisolated struct AffiliateLinkService {
    let events: any EventRepository
    let configuration: AffiliateProviderConfiguration
    let calendar: Calendar

    init(
        events: any EventRepository,
        configuration: AffiliateProviderConfiguration = .klook,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) {
        self.events = events
        self.configuration = configuration
        self.calendar = calendar
    }

    func links(for trip: Trip, now: Date = Date()) -> [AffiliateActivityLink] {
        guard trip.status == .planned else { return [] }
        let departure = trip.legs.map(\.startDate).min() ?? now
        let days = max(0, calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: departure)
        ).day ?? 0)

        return trip.legs.flatMap { leg in
            leg.cities.prefix(3).compactMap { city in
                makeLink(
                    countryCode: leg.countryCode,
                    city: city,
                    category: .highlights,
                    entryPoint: .trip(daysUntilDeparture: days)
                )
            }
        }
    }

    func links(for recommendation: Recommendation) -> [AffiliateActivityLink] {
        let destinations = AffiliateDestinationCatalog.cities(for: recommendation.countryCode)
        let categories = recommendation.explanationTagIDs
            .compactMap(ActivityCategory.init(tagID:))
            .uniqued()
        let selectedCategories = categories.isEmpty ? [.highlights] : Array(categories.prefix(2))

        return destinations.prefix(3).enumerated().compactMap { index, city in
            let category = selectedCategories[index % selectedCategories.count]
            return makeLink(
                countryCode: recommendation.countryCode,
                city: city,
                category: category,
                entryPoint: .recommendation(slot: recommendation.slot)
            )
        }
    }

    func recordClick(_ link: AffiliateActivityLink, at date: Date = Date()) async throws {
        try await events.append(AnalyticsEvent(
            type: .slotClick,
            payload: [
                "clickType": "affiliate",
                "provider": link.providerName,
                "entryPoint": link.entryPoint.analyticsValue,
                "countryCode": link.countryCode,
                "city": link.city,
                "category": link.category.rawValue,
                "subID": link.subID,
                "affiliateActive": String(link.isAffiliateActive)
            ],
            createdAt: date
        ))
    }

    private func makeLink(
        countryCode: String,
        city: String,
        category: ActivityCategory,
        entryPoint: AffiliateEntryPoint
    ) -> AffiliateActivityLink? {
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCity.isEmpty else { return nil }
        let code = countryCode.uppercased()
        let subID = [entryPoint.subIDComponent, code, slug(trimmedCity)]
            .joined(separator: "_")

        guard var components = URLComponents(
            url: configuration.searchBaseURL,
            resolvingAgainstBaseURL: false
        ) else { return nil }
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(
            name: "query",
            value: "\(trimmedCity) \(category.searchTerm)"
        ))
        components.queryItems = queryItems
        guard let searchURL = components.url,
              let url = configuration.isAffiliateActive
                ? redirectURL(to: searchURL, entryPoint: entryPoint)
                : searchURL
        else { return nil }

        return AffiliateActivityLink(
            id: "\(subID)_\(category.rawValue)",
            providerName: configuration.providerName,
            countryCode: code,
            city: trimmedCity,
            category: category,
            entryPoint: entryPoint,
            subID: subID,
            url: url,
            isAffiliateActive: configuration.isAffiliateActive
        )
    }

    /// 대시보드가 만드는 링크와 같이 `k_site` 값을 `:`·`/`·`?`까지 모두 인코딩한다.
    private func redirectURL(to target: URL, entryPoint: AffiliateEntryPoint) -> URL? {
        guard let partnerID = configuration.partnerID,
              var components = URLComponents(url: configuration.redirectURL, resolvingAgainstBaseURL: false)
        else { return nil }
        let unreserved = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        let encode = { (value: String) in value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value }
        components.percentEncodedQuery = [
            "aid=\(encode(partnerID))",
            "aff_adid=\(encode(configuration.adID(for: entryPoint)))",
            "k_site=\(encode(target.absoluteString))"
        ].joined(separator: "&")
        return components.url
    }

    private func slug(_ value: String) -> String {
        (value.applyingTransform(.toLatin, reverse: false) ?? value)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character(String($0)) : "-" }
            .reduce(into: "") { result, character in
                if character != "-" || result.last != "-" {
                    result.append(character)
                }
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}

private nonisolated extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

/// 대표 도시 이름은 링크 자리 검증용이다. 공급자 destination id는 3.5단계에서
/// 시드 데이터로 옮겨 주입하며, 이 목록은 그때 제거한다.
nonisolated enum AffiliateDestinationCatalog {
    private static let values: [String: [String]] = [
        "AE": ["Dubai", "Abu Dhabi"],
        "AR": ["Buenos Aires", "Mendoza"],
        "AU": ["Sydney", "Melbourne", "Cairns"],
        "BR": ["Rio de Janeiro", "São Paulo"],
        "CA": ["Vancouver", "Toronto", "Banff"],
        "CO": ["Bogotá", "Cartagena"],
        "CR": ["San José", "La Fortuna"],
        "EG": ["Cairo", "Luxor"],
        "FJ": ["Nadi", "Suva"],
        "FR": ["Paris", "Nice", "Lyon"],
        "GR": ["Athens", "Santorini"],
        "ID": ["Bali", "Jakarta", "Yogyakarta"],
        "IN": ["Delhi", "Jaipur", "Mumbai"],
        "IS": ["Reykjavík", "Vík"],
        "IT": ["Rome", "Florence", "Venice"],
        "JO": ["Amman", "Petra"],
        "JP": ["Tokyo", "Osaka", "Kyoto"],
        "KE": ["Nairobi", "Mombasa"],
        "KR": ["Seoul", "Busan", "Jeju"],
        "MA": ["Marrakech", "Fes"],
        "MX": ["Mexico City", "Cancún", "Oaxaca"],
        "NO": ["Oslo", "Bergen", "Tromsø"],
        "NZ": ["Auckland", "Queenstown", "Rotorua"],
        "PE": ["Lima", "Cusco"],
        "PT": ["Lisbon", "Porto"],
        "TH": ["Bangkok", "Chiang Mai", "Phuket"],
        "TZ": ["Zanzibar", "Arusha"],
        "US": ["New York", "Los Angeles", "Las Vegas"],
        "VN": ["Hanoi", "Ho Chi Minh City", "Da Nang"],
        "ZA": ["Cape Town", "Johannesburg"]
    ]

    static func cities(for countryCode: String) -> [String] {
        values[countryCode.uppercased()] ?? []
    }
}
