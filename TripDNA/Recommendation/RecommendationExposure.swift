import CryptoKit
import Foundation

/// A displayed set's frozen inputs. Constructing it does not record an exposure.
final class RecommendationExposure {
    let id = UUID().uuidString
    private let source: String
    private let cards: [Recommendation]
    private let context: [String: String]
    private var recorded: Set<String> = []

    init(source: String, cards: [Recommendation], vector: UserTasteVector,
         interests: Set<String>, excludedCountries: Set<String>,
         homeCountry: String?, budget: String? = nil) {
        self.source = source
        self.cards = cards
        context = [
            "schemaVersion": "1",
            "modelVersion": RecommendationService.modelVersion,
            "countryDataVersion": Self.countryDataVersion,
            "source": source,
            "orderedCards": Self.json(cards),
            "tasteAxes": Self.json(vector.axes),
            "axisConfidence": Self.json(vector.confidence),
            "acceptedAxes": Self.json((vector.acceptedAxes ?? []).map(\.rawValue).sorted()),
            "ledgerVersion": String(vector.ledgerVersion),
            "interestTagIDs": Self.json(interests.sorted()),
            "excludedCountryCodes": Self.json(excludedCountries.sorted()),
            "homeCountryCode": homeCountry ?? "unspecified",
            "budget": budget ?? "unspecified",
            "travelDates": "not_collected",
            "duration": "not_collected",
            "companion": "not_collected",
            "visibilityRule": "at_least_half_visible_once_per_set"
        ]
    }

    func record(_ card: Recommendation, dependencies: AppDependencies) async {
        guard let index = cards.firstIndex(where: { $0.id == card.id }),
              recorded.insert(card.id).inserted else { return }
        var payload = context
        payload["exposureSetID"] = id
        payload["countryCode"] = card.countryCode
        payload["slot"] = card.slot.rawValue
        payload["position"] = String(index + 1)
        do {
            // Bypass AnalyticsSink: this history stays on this device.
            try await dependencies.store.append(AnalyticsEvent(type: .recommendationImpression, payload: payload))
            await dependencies.recordFirstRecommendationIfNeeded(source: source)
        } catch {
            recorded.remove(card.id)
        }
    }

    private static func json<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else { return "null" }
        return text
    }

    private static let countryDataVersion: String = {
        guard let url = Bundle.main.url(forResource: "countries", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return "unavailable" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }()
}
