import Foundation

/// 기기 밖으로 보내는 자리. 출시 빌드는 `ServerMetricsSink`(익명 일별 집계)를 넘긴다.
nonisolated protocol AnalyticsSink: Sendable {
    func send(_ event: AnalyticsEvent)
}

/// 모든 서비스가 이벤트를 남기는 단일 지점. 기기 저장소에 쌓고, 외부 도구가 있으면 함께 보낸다.
nonisolated struct AnalyticsRecorder: EventRepository {
    let store: any EventRepository
    let sink: (any AnalyticsSink)?

    func append(_ event: AnalyticsEvent) async throws {
        try await store.append(event)
        sink?.send(event)
    }
}
