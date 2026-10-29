import Foundation

/// 저장한 도시. 카드 내용과 저장 당시 조건 요약을 함께 남겨, 조건이 바뀐 뒤에도 같은 상세를 다시 열 수 있다.
nonisolated struct SavedCity: Codable, Equatable, Sendable, Identifiable {
    var id: String { card.cityID }
    let card: CityRecommendationRecord.Card
    let savedAt: Date
    /// 저장할 때의 요청 조건 한 줄 요약(`RecommendationRequest.summaryText`).
    let conditionSummary: String
    /// 저장할 때의 요청 조건 전체. 예전 기록에는 없다.
    let request: RecommendationRequest?

    init(card: CityRecommendationRecord.Card, savedAt: Date, conditionSummary: String, request: RecommendationRequest? = nil) {
        self.card = card
        self.savedAt = savedAt
        self.conditionSummary = conditionSummary
        self.request = request
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        card = try c.decode(CityRecommendationRecord.Card.self, forKey: .card)
        savedAt = try c.decode(Date.self, forKey: .savedAt)
        conditionSummary = try c.decode(String.self, forKey: .conditionSummary)
        request = try c.decodeIfPresent(RecommendationRequest.self, forKey: .request)
    }

    /// 보여줄 조건 요약. 요청이 있으면 거기서 만들고, 예전 기록은 저장해 둔 문장을 쓴다.
    var summary: String { request?.summaryText ?? conditionSummary }
}

/// "다시 추천하지 않기"로 뺀 도시. 순위 계산에서 빠지고 설정에서 풀 수 있다.
nonisolated struct ExcludedCity: Codable, Equatable, Sendable, Identifiable {
    var id: String { cityID }
    let cityID: String
    let cityName: String
    let country: String
    let excludedAt: Date
}

/// 도시 추천의 기기 내 상태 한 덩어리(단일 값 표 하나). 전체 삭제가 이 표를 지운다.
nonisolated struct CityRecommendationState: Codable, Equatable, Sendable {
    var saved: [SavedCity] = []
    var excluded: [ExcludedCity] = []
    /// 마지막 추천 결과. 앱을 다시 켜면 추천 탭에 복원한다.
    var lastRecord: CityRecommendationRecord?
    /// `lastRecord`에서 "이번 결과에서 넘기기"한 도시. 새 결과를 받으면 비운다. 영구 제외와 다르다.
    var skippedCityIDs: [String] = []
    /// `lastRecord`의 "이렇게 이해했어요"를 한 번 접었는지. 다시 열면 접힌 채로 시작한다. 새 결과를 받으면 false로 돌린다.
    var understandingSeen = false

    init() {}

    /// 필드가 늘어도 예전 값을 읽도록, 없는 키는 기본값으로 둔다. 큰 마지막 결과는 읽지 못해도 저장·제외를 잃지 않게 따로 다룬다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        saved = try c.decodeIfPresent([SavedCity].self, forKey: .saved) ?? []
        excluded = try c.decodeIfPresent([ExcludedCity].self, forKey: .excluded) ?? []
        lastRecord = try? c.decodeIfPresent(CityRecommendationRecord.self, forKey: .lastRecord)
        skippedCityIDs = try c.decodeIfPresent([String].self, forKey: .skippedCityIDs) ?? []
        understandingSeen = try c.decodeIfPresent(Bool.self, forKey: .understandingSeen) ?? false
    }

    var excludedCityIDs: Set<String> { Set(excluded.map(\.cityID)) }

    mutating func save(
        _ card: CityRecommendationRecord.Card, conditionSummary: String, request: RecommendationRequest? = nil, now: Date = Date()
    ) {
        saved.removeAll { $0.id == card.cityID }
        saved.insert(SavedCity(card: card, savedAt: now, conditionSummary: conditionSummary, request: request), at: 0)
    }

    mutating func unsave(cityID: String) { saved.removeAll { $0.id == cityID } }

    mutating func exclude(_ card: CityRecommendationRecord.Card, now: Date = Date()) {
        excluded.removeAll { $0.cityID == card.cityID }
        excluded.insert(
            ExcludedCity(cityID: card.cityID, cityName: card.cityName, country: card.country, excludedAt: now), at: 0
        )
    }

    mutating func release(cityID: String) { excluded.removeAll { $0.cityID == cityID } }
}

extension UserProfileRepository {
    func cityState() async throws -> CityRecommendationState { try await loadCityState() }

    /// 읽고, 고치고, 저장한다. 읽기나 저장에 실패하면 던지고, 읽지 못했을 때는 저장하지 않아 기존 상태를 덮어쓰지 않는다.
    @discardableResult
    func updateCityState(_ change: (inout CityRecommendationState) -> Void) async throws -> CityRecommendationState {
        var state = try await loadCityState()
        change(&state)
        try await saveCityState(state)
        return state
    }
}

extension CityRecommendationRecord {
    /// 화면에 보일 카드. 받은 뒤에 "다시 추천하지 않기"한 도시·나라와, 필수 조건 위반이 확인된 카드는 보이지 않는다.
    /// 결과 저장은 그대로 두고 보여줄 때 거른다.
    func visibleCards(excludedCities: Set<String>, excludedCountries: Set<String>) -> [Card] {
        cards.visible(excludedCities: excludedCities, excludedCountries: excludedCountries)
    }
}

extension Array where Element == CityRecommendationRecord.Card {
    func visible(excludedCities: Set<String>, excludedCountries: Set<String>) -> [Element] {
        filter {
            !excludedCities.contains($0.cityID) && !excludedCountries.contains($0.country) && !$0.violatesRequiredCondition
        }
    }
}

extension CityRecommendationRecord.Card {
    enum Badge: Equatable {
        /// 필수 조건을 모두 코드가 확인했다. `scope`는 확인한 조건 이름.
        case requiredMet(scope: [String])
        /// 필수 조건 중 확인하지 못한 것이 있다. 기본 추천과 섞지 않는 묶음에 둔다.
        case needsCheck(names: [String])
    }

    private var required: [ConditionResult] { conditions.filter { $0.condition.level == .required } }

    var violatesRequiredCondition: Bool { required.contains { $0.status == .notMet } }

    /// docs/screens/recommendations.md 배지 표. 필수 조건이 없으면 배지 없음.
    var badge: Badge? {
        guard !required.isEmpty else { return nil }
        let unconfirmed = required.filter { $0.status == .unconfirmed }.map(\.condition.text)
        return unconfirmed.isEmpty ? .requiredMet(scope: required.map(\.condition.text)) : .needsCheck(names: unconfirmed)
    }

    /// 선호 조건 중 확인하지 못한 것. 필수 조건의 배지와 따로 안내한다.
    var unconfirmedPreferences: [String] {
        conditions.filter { $0.condition.level != .required && $0.status == .unconfirmed }.map(\.condition.text)
    }

    /// "추가 확인 필요" 묶음에 속하는지.
    var needsCheck: Bool { if case .needsCheck = badge { true } else { false } }
}

extension RecommendationRequest {
    /// "이렇게 이해했어요"의 조건 칩. 시기는 항상 보이고(미정이면 "시기 미정"), 기간·예산은 모르면 뺀다.
    var conditionChips: [String] {
        var chips = [periodText ?? "시기 미정"]
        if let lengthText { chips.append(lengthText) }
        if let budgetText { chips.append(budgetText) }
        return chips
    }

    /// 접힌 한 줄. 예: "미식 · 11월 3박 4일 · 필수: 비행 5시간 이내". 모르는 부분은 뺀다.
    func collapsedLine(required: [String]) -> String {
        var parts: [String] = []
        if let primary { parts.append(primary.labelKo) }
        let when = [periodText, lengthText].compactMap { $0 }.joined(separator: " ")
        if !when.isEmpty { parts.append(when) }
        if !required.isEmpty { parts.append("필수: \(required.joined(separator: ", "))") }
        return parts.joined(separator: " · ")
    }

    private var periodText: String? {
        if let startDate {
            let parts = Calendar.current.dateComponents([.month, .day], from: startDate)
            if let m = parts.month, let d = parts.day { return "\(m)월 \(d)일" }
        }
        return month.map { "\($0)월" }
    }

    private var lengthText: String? {
        guard let nights else { return nil }
        return nights == 0 ? "당일" : "\(nights)박 \(nights + 1)일"
    }

    private var budgetText: String? {
        guard let budgetMaxKRW else { return nil }
        let text = "\(budgetBasis == .perPerson ? "1인" : "전체") \(budgetMaxKRW / 10_000)만 원 이하"
        return budgetIncludesFlight ? text : text + " (항공 제외)"
    }
}
