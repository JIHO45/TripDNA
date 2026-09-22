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

    var labelKo: String {
        switch self {
        case .highlights: "인기 액티비티"
        case .food: "푸드 투어"
        case .culture: "문화·예술 체험"
        case .history: "역사 투어"
        case .outdoor: "자연·아웃도어"
        case .beach: "해변·휴양"
        case .nightlife: "나이트라이프"
        case .shopping: "쇼핑"
        case .wellness: "웰니스"
        case .sportsAndEvents: "스포츠·이벤트"
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
    let partnerID: String?
    let partnerIDQueryName: String
    let subIDQueryName: String

    var isAffiliateActive: Bool {
        guard let partnerID else { return false }
        return !partnerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 3.5단계에서 승인받은 공급자의 ID와 실제 파라미터명으로 교체한다.
    nonisolated static let launchPlaceholder = AffiliateProviderConfiguration(
        providerName: "Klook",
        searchBaseURL: URL(string: "https://www.klook.com/ko/search/result/")!,
        partnerID: nil,
        partnerIDQueryName: "aid",
        subIDQueryName: "subid"
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
        configuration: AffiliateProviderConfiguration = .launchPlaceholder,
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
        queryItems.append(URLQueryItem(name: configuration.subIDQueryName, value: subID))
        if let partnerID = configuration.partnerID, configuration.isAffiliateActive {
            queryItems.append(URLQueryItem(name: configuration.partnerIDQueryName, value: partnerID))
        }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

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
