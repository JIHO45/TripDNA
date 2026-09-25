import Foundation

/// 외부 분석 도구를 붙일 자리. 도구를 정하면 이 프로토콜을 구현해 `AppDependencies`에 넘긴다.
/// 서버가 없으므로 다른 사용자의 공유율·첫 추천 도달은 이 경로로만 관측된다.
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
