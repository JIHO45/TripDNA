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
    /// 메모 한 칸(좋았던 점·아쉬웠던 점)에서 보내는 최대 글자 수(2026-10-31 결정 C1).
    static let memoLimit = 500

    /// 최근 평가한 여행의 도시별 별점·메모. 평가 시각 순 10건, 메모는 칸마다 500자까지.
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
                rating: item.1.rating,
                liked: item.1.liked.map { String($0.prefix(memoLimit)) },
                disliked: item.1.disliked.map { String($0.prefix(memoLimit)) }
            )
        }
    }
}

/// 첫 추천 전 전송 동의와, 그중 지난 여행 평가를 보낼지에 대한 선택. 처음에는 정하지 않은 상태다.
/// granted·declined 모두 항상 보내는 정보(`alwaysSent`)에는 동의한 상태다. 결정: docs/data/storage-and-privacy.md A1.
nonisolated enum CityMemoryConsent {
    static let key = "tripdna.cityMemoryConsent"

    // 동의 시트와 설정이 같은 문구를 쓴다. 처리방침 4·7절과 맞춘다.
    static var alwaysSent: String { String(localized: "Selected trip concepts, conditions (timing, length, party size, budget), the text you write, the trip you want, and your questions about cities") }
    static var sentIfGranted: String { String(localized: "Star ratings and notes from up to 10 recent trip reviews (up to 500 characters per note), and the cities you visited") }
    static var neverSent: String { String(localized: "Original photos, location history, your name or contact info") }
    static var recipients: String { String(localized: "Google Firebase (relay server) and Anthropic (AI model). All processing happens in the US.") }

    enum State: String { case undecided, granted, declined }

    static func reset() { AppStorageLocation.defaults.removeObject(forKey: key) }

    static var state: State {
        get { AppStorageLocation.defaults.string(forKey: key).flatMap(State.init) ?? .undecided }
        set { AppStorageLocation.defaults.set(newValue.rawValue, forKey: key) }
    }
}
