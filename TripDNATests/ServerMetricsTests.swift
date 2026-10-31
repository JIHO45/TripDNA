import Foundation
import Testing
@testable import TripDNA

struct ServerMetricsTests {
    @Test func metricURLSitsNextToProxy() {
        #expect(ServerMetricsSink.metricURL(proxy: "https://us-central1-p.cloudfunctions.net/cityLLM")?.absoluteString
                == "https://us-central1-p.cloudfunctions.net/metric")
        #expect(ServerMetricsSink.metricURL(proxy: "") == nil)
        #expect(ServerMetricsSink.metricURL(proxy: nil) == nil)
    }

    /// 서버가 모르는 이름은 400으로 버려지므로 두 목록이 같아야 한다.
    @Test func forwardedEventsMatchServerList() throws {
        let server = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "functions/index.js")
        let source = try String(contentsOf: server, encoding: .utf8)
        let list = try #require(source.firstRange(of: /METRIC_EVENTS = new Set\(\[([^\]]*)\]/)?.lowerBound)
        let names = Set(source[list...].prefix { $0 != "]" }.matches(of: /"([a-z_]+)"/).map { String($0.1) })
        #expect(names == Set(ServerMetricsSink.forwarded.map(\.rawValue)))
    }

    @Test func errorReportCarriesVersionsButNotRecommendationText() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let record = try await CityStateTests.record(dir: dir)
        let card = try #require(record.cards.first)
        let url = try #require(CityErrorReport.mailURL(card: card, record: record, appVersion: "1.0"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(items.scheme == "mailto" && items.path == CityErrorReport.address)
        let body = try #require(items.queryItems?.first { $0.name == "body" }?.value)
        #expect(body.contains(card.cityID) && body.contains(record.id) && body.contains(record.version.prompt))
        #expect(!body.contains(card.reason))
    }
}
