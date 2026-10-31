import Foundation

/// 추천 입력 시트에서 모은 이번 여행 조건. 추천 생성은 아직 이 값을 쓰지 않고, 사는 나라 포함만 필터로 옮긴다.
/// 비운 값은 "모름"이다.
nonisolated struct RecommendationRequest: Codable, Equatable, Sendable {
    enum BudgetBasis: String, Codable, Sendable { case perPerson, group }

    var primary: TripConcept?
    var secondary: [TripConcept] = []
    var partySize = 1
    /// 월로 고른 시기. nil이면 미정. 날짜를 지정하면 `startDate`가 우선한다.
    var year: Int?
    var month: Int?
    var startDate: Date?
    /// 박 수. nil이면 미정, 0이면 당일.
    var nights: Int?
    var budgetBasis: BudgetBasis = .perPerson
    var budgetIncludesFlight = true
    /// 최대 금액(`budgetCurrency` 단위). nil이면 미정. 저장 키는 예전 이름 `budgetMaxKRW`를 그대로 쓴다.
    var budgetMax: Int?
    /// `budgetMax`의 통화(ISO 코드). 이 필드가 없던 예전 저장 값은 원화다.
    var budgetCurrency = BudgetCurrency.krw
    var wants = ""
    var avoids = ""
    var includeVisited = true
    var includeHomeCountry = false

    private enum CodingKeys: String, CodingKey {
        case primary, secondary, partySize, year, month, startDate, nights, budgetBasis, budgetIncludesFlight
        case budgetMax = "budgetMaxKRW"
        case budgetCurrency, wants, avoids, includeVisited, includeHomeCountry
    }

    init() {}

    /// 필드가 늘어도 예전 값을 읽도록, 없는 키는 기본값으로 둔다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        primary = try c.decodeIfPresent(TripConcept.self, forKey: .primary)
        secondary = try c.decodeIfPresent([TripConcept].self, forKey: .secondary) ?? []
        partySize = try c.decodeIfPresent(Int.self, forKey: .partySize) ?? 1
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        month = try c.decodeIfPresent(Int.self, forKey: .month)
        startDate = try c.decodeIfPresent(Date.self, forKey: .startDate)
        nights = try c.decodeIfPresent(Int.self, forKey: .nights)
        budgetBasis = try c.decodeIfPresent(BudgetBasis.self, forKey: .budgetBasis) ?? .perPerson
        budgetIncludesFlight = try c.decodeIfPresent(Bool.self, forKey: .budgetIncludesFlight) ?? true
        budgetMax = try c.decodeIfPresent(Int.self, forKey: .budgetMax)
        budgetCurrency = try c.decodeIfPresent(String.self, forKey: .budgetCurrency) ?? BudgetCurrency.krw
        wants = try c.decodeIfPresent(String.self, forKey: .wants) ?? ""
        avoids = try c.decodeIfPresent(String.self, forKey: .avoids) ?? ""
        includeVisited = try c.decodeIfPresent(Bool.self, forKey: .includeVisited) ?? true
        includeHomeCountry = try c.decodeIfPresent(Bool.self, forKey: .includeHomeCountry) ?? false
    }

    /// 저장한 도시와 결과 화면에 쓰는 한 줄 조건 요약. 예: "미식 · 11월 · 3박 · 1인 100만원 이하".
    var summaryText: String {
        var parts: [String] = []
        if let primary { parts.append(primary.label) }
        if let month = month ?? startDate.map({ Calendar.current.component(.month, from: $0) }) {
            parts.append(Calendar.current.shortMonthSymbols[month - 1])
        }
        if let nights { parts.append(String(localized: "\(nights) nights")) }
        if let budgetMax {
            parts.append(budgetBasis == .perPerson
                ? String(localized: "Per person under \(BudgetCurrency.format(budgetMax, currency: budgetCurrency, koreanUnit: "만원"))") // l10n-ignore Korean amount unit
                : String(localized: "Total under \(BudgetCurrency.format(budgetMax, currency: budgetCurrency, koreanUnit: "만원"))")) // l10n-ignore Korean amount unit
        }
        return parts.joined(separator: " · ")
    }

    /// 추천을 받으려면 주 컨셉이 필수다.
    var isReady: Bool { primary != nil }

    mutating func setPrimary(_ concept: TripConcept) {
        primary = concept
        secondary.removeAll { $0 == concept }
    }

    /// 함께 하고 싶은 것: 주 컨셉 제외, 최대 2개.
    mutating func toggleSecondary(_ concept: TripConcept) {
        if let index = secondary.firstIndex(of: concept) {
            secondary.remove(at: index)
        } else if concept != primary, secondary.count < 2 {
            secondary.append(concept)
        }
    }

    /// 같은 달을 다시 고르면 미정으로 돌아간다. 월을 고르면 지정 날짜는 지운다.
    mutating func toggleMonth(_ year: Int, _ month: Int) {
        startDate = nil
        if self.year == year, self.month == month {
            self.year = nil
            self.month = nil
        } else {
            self.year = year
            self.month = month
        }
    }

    mutating func setStartDate(_ date: Date) {
        startDate = date
        year = nil
        month = nil
    }
}
