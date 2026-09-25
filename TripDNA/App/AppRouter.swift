import SwiftUI
import UserNotifications

/// 화면 밖에서 들어오는 이동 요청(알림 탭, 평가 완료 후 추천 보기)을 받는 앱 전역 내비게이션 상태.
@Observable
final class AppRouter {
    var selectedTab: MainTab = .home
    /// 알림에서 연 평가. 메인 화면이 뜨면 전체 화면으로 띄운다.
    var evaluationRequest: EvaluationRequest?
}

struct EvaluationRequest: Identifiable, Equatable {
    let tripID: String
    var id: String { tripID }
}

/// 앱이 꺼져 있을 때 누른 알림도 받으려면 델리게이트를 실행 직후에 등록해야 한다.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let router = AppRouter()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let tripID = response.notification.request.content.userInfo["tripID"] as? String else { return }
        await MainActor.run {
            router.evaluationRequest = EvaluationRequest(tripID: tripID)
        }
    }
}
