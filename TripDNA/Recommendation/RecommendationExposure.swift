import Foundation

/// 받은 도시 추천 결과 하나의 노출 기록. 만들기만 해서는 노출이 아니고, 카드가 절반 이상 보일 때 `record`한다.
/// 결과마다 도시당 한 번, 기기에만 남긴다(docs/evaluation/metrics.md). 요청 문장·메모는 넣지 않는다.
final class RecommendationExposure {
    /// 노출을 묶는 결과 id. 예산만 바꿔 다시 계산한 결과는 새 id다.
    let id: String
    private let context: [String: String]
    private var recorded: Set<String> = []

    init(record: CityRecommendationRecord) {
        id = record.id
        context = [
            "schemaVersion": "2",
            "source": "city",
            "resultID": record.id,
            "derivedFrom": record.derivedFrom ?? "none",
            "catalogVersion": record.version.catalog,
            "promptVersion": record.version.prompt,
            "rankingVersion": record.version.ranking,
            "model": record.version.model,
            "primaryConcept": record.input.primary?.rawValue ?? "unspecified",
            "secondaryConcepts": record.input.secondary.map(\.rawValue).joined(separator: ","),
            "budgetMaxKRW": record.input.budgetMaxKRW.map(String.init) ?? "unspecified",
            "includeVisited": String(record.input.includeVisited),
            "excludedCountryCodes": record.excludedCountries.sorted().joined(separator: ","),
            "excludedCityCount": String(record.excludedCityIDs?.count ?? 0),
            "homeCountryCode": record.homeCountryAtRequest ?? "unspecified",
            "visibilityRule": "at_least_half_visible_once_per_result"
        ]
    }

    /// `screen`은 카드가 놓인 곳(cards: 추천 카드, check: 추가 확인 필요), `position`은 그 안의 1부터 시작하는 순서.
    func record(_ card: CityRecommendationRecord.Card, screen: String, position: Int, dependencies: AppDependencies) async {
        guard recorded.insert(card.cityID).inserted else { return }
        var payload = context
        payload["cityID"] = card.cityID
        payload["countryCode"] = card.country
        payload["screen"] = screen
        payload["position"] = String(position)
        payload["isExploration"] = String(card.isExploration)
        do {
            // AnalyticsSink를 거치지 않는다: 이 기록은 기기에만 남는다.
            try await dependencies.store.append(AnalyticsEvent(type: .recommendationImpression, payload: payload))
        } catch {
            recorded.remove(card.cityID)
        }
    }
}
