import Foundation

/// 도시 등급. 네 단계 이름형이며 사용자 티어와 별개다(docs/recommendation/README.md "도시 등급").
nonisolated enum CityGrade: String, Codable, Comparable, Sendable {
    case none
    case ifThere = "if_there"
    case makeTime = "make_time"
    case choose

    /// LLM 입력과 로그에 쓰는 한국어 이름.
    var nameKo: String {
        switch self {
        case .none: "찾지 못함"
        case .ifThere: "간다면 즐길 만함"
        case .makeTime: "일부러 시간을 낼 만함"
        case .choose: "여행지를 선택할 만함"
        }
    }

    var rankValue: Int {
        switch self {
        case .none: 0
        case .ifThere: 1
        case .makeTime: 2
        case .choose: 3
        }
    }

    static func < (lhs: CityGrade, rhs: CityGrade) -> Bool { lhs.rankValue < rhs.rankValue }
}

/// `Resources/cities.json`의 도시 한 곳. `scripts/build_city_bundle.py`가 catalog.json에서 만든다.
/// 핵심 경험 문장(core)은 담지 않는다(2026-10-25 결정).
nonisolated struct City: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let ko: String
    let en: String
    let country: String
    /// 세부 29개 → 등급.
    let grades: [String: CityGrade]
    /// 운영·행사 월이 확인된 세부. 값이 없는 세부는 달 제한이 없다.
    let season: [String: [Int]]
    /// 운영 월을 확인하지 못한 세부. 시기 조건 충족으로 치지 않는다.
    let seasonUnverified: [String]
    /// 등급의 대상 범위. 이전 자료에는 없을 수 있다.
    var scope: String? = nil
}

nonisolated struct CityCatalog: Codable, Equatable, Sendable {
    /// 후보 자료 버전. 입력 버전의 일부다.
    let version: String
    /// 앱 컨셉이 아니라 자료의 큰 컨셉 id → 세부 id 목록.
    let concepts: [String: [String]]
    let cities: [City]

    /// 앱의 `TripConcept`가 가리키는 자료의 큰 컨셉 id.
    static func conceptID(for concept: TripConcept) -> String {
        switch concept {
        case .cityExploration: "city"
        case .natureScenery: "nature"
        case .food: "food"
        case .relaxation: "relaxation"
        case .cultureHistory: "culture"
        case .activities: "activities"
        case .shopping: "shopping"
        case .nightlife: "nightlife"
        case .meetingPeople: "social"
        case .event: "event"
        }
    }

    func subconcepts(of concept: TripConcept) -> [String] {
        concepts[Self.conceptID(for: concept)] ?? []
    }

    /// 여행 구간에 적힌 도시 이름(한국어·영어, 대소문자 무시)과 나라가 맞는 도시 id. 목록에 없는 이름은 버린다.
    func cityIDs(visitedIn trips: [Trip]) -> Set<String> {
        let visited = Set(trips.flatMap(\.legs).flatMap { leg in
            leg.cities.map { "\(leg.countryCode)|\($0.trimmingCharacters(in: .whitespaces).lowercased())" }
        })
        return Set(cities.filter {
            visited.contains("\($0.country)|\($0.ko.lowercased())") || visited.contains("\($0.country)|\($0.en.lowercased())")
        }.map(\.id))
    }

    static func load(bundle: Bundle = .main) -> CityCatalog? {
        guard let url = bundle.url(forResource: "cities", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CityCatalog.self, from: data)
    }
}
