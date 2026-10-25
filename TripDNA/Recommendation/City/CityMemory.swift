import Foundation

/// LLM에 보내는 지난 여행 평가 한 건. 사용자가 전송에 동의했을 때만 만든다.
nonisolated struct CityMemory: Codable, Equatable, Sendable {
    /// 요청 안에서만 쓰는 짧은 id(m1, m2…). 응답의 `memories_used`가 가리킨다.
    let id: String
    let tripID: String
    let countryCode: String
    let city: String?
    let rating: Int?
    let liked: String?
    let disliked: String?

    static let limit = 10

    /// 최근 평가한 여행의 도시별 별점·메모. 상한과 "최근"의 기준은 문서에서 미정이라 평가 시각 순 10건으로 시작한다.
    static func recent(from trips: [Trip], limit: Int = limit) -> [CityMemory] {
        let reviews = trips
            .filter { $0.evaluation?.skipped == false }
            .sorted { ($0.evaluatedAt ?? .distantPast) > ($1.evaluatedAt ?? .distantPast) }
            .flatMap { trip in
                (trip.evaluation?.cityReviews ?? []).filter { !$0.isEmpty }.map { (trip.id, $0) }
            }
        return reviews.prefix(limit).enumerated().map { index, item in
            CityMemory(
                id: "m\(index + 1)", tripID: item.0, countryCode: item.1.countryCode, city: item.1.city,
                rating: item.1.rating, liked: item.1.liked, disliked: item.1.disliked
            )
        }
    }
}

/// 지난 여행 평가를 외부 모델에 보내는 것에 대한 사용자의 선택. 처음에는 정하지 않은 상태다.
nonisolated enum CityMemoryConsent {
    static let key = "tripdna.cityMemoryConsent"

    enum State: String { case undecided, granted, declined }

    static func reset() { UserDefaults.standard.removeObject(forKey: key) }

    static var state: State {
        get { UserDefaults.standard.string(forKey: key).flatMap(State.init) ?? .undecided }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
