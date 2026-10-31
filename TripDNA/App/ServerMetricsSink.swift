import FirebaseAppCheck
import FirebaseCore
import Foundation

/// 출시 후 관측(R5)용 익명 집계. 아래 이벤트가 생기면 이름만 서버(functions/index.js `metric`)에 보내고,
/// 서버는 그날 그 이벤트 수만 1 올린다. 익명 ID·내용·기기 정보는 보내지 않는다(App Check 토큰만).
/// 사람별 퍼널·재사용은 볼 수 없다. 실패해도 다시 보내지 않는다.
nonisolated struct ServerMetricsSink: AnalyticsSink {
    static let forwarded: Set<AnalyticsEventType> = [
        .onboardingCompleted, .firstRecommendationShown, .cityRecommendationReceived, .cityRecommendationFailed,
        .citySaved, .citySkipped, .cityExcluded, .memoryForgotten, .shareCardExported, .errorReportOpened,
    ]

    let url: URL

    /// 집계 주소는 LLM 중계(`CityLLMProxyURL`)와 같은 곳의 `metric` 함수다.
    /// 개발 빌드는 보내지 않는다(테스트 수치가 섞이지 않게).
    static func make(bundle: Bundle = .main) -> ServerMetricsSink? {
        #if DEBUG
        return nil
        #else
        return metricURL(proxy: bundle.object(forInfoDictionaryKey: "CityLLMProxyURL") as? String).map(ServerMetricsSink.init)
        #endif
    }

    static func metricURL(proxy raw: String?) -> URL? {
        guard let raw, !raw.isEmpty, let proxy = URL(string: raw) else { return nil }
        return proxy.deletingLastPathComponent().appendingPathComponent("metric")
    }

    func send(_ event: AnalyticsEvent) {
        guard Self.forwarded.contains(event.type), FirebaseApp.app() != nil else { return }
        let url = url
        Task {
            guard let token = try? await AppCheck.appCheck().token(forcingRefresh: false).token else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(token, forHTTPHeaderField: "X-Firebase-AppCheck")
            request.httpBody = try? JSONEncoder().encode(["event": event.type.rawValue])
            _ = try? await CityLLMConfiguration.session.data(for: request)
        }
    }
}
