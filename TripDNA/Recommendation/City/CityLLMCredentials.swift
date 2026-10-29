import Foundation
import FirebaseAppCheck
import FirebaseAuth
import FirebaseCore

/// Firebase 시작. `GoogleService-Info.plist`가 없으면(파일은 git에 없다) 켜지 않고, 프록시 호출은 서버에서 401로 거부된다.
nonisolated enum FirebaseSetup {
    static func configure() {
        guard FirebaseApp.app() == nil,
              Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        #if DEBUG
        // 시뮬레이터에는 App Attest가 없다. 개발 빌드는 디버그 토큰을 쓰며, 콘솔 로그의 토큰을 Firebase에 등록해야 통과한다.
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppAttestFactory())
        #endif
        FirebaseApp.configure()
    }
}

nonisolated final class AppAttestFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? { AppAttestProvider(app: app) }
}

/// 프록시 요청에 붙이는 헤더: 누가 보냈는지(익명 로그인 ID 토큰)와 정식 앱인지(App Check 토큰).
/// 로그인 화면은 없다. 처음 호출할 때 익명 계정을 만들고 이후에는 같은 계정을 쓴다.
nonisolated enum CityLLMCredentials {
    static func headers() async throws -> [String: String] {
        guard FirebaseApp.app() != nil else { return [:] }
        let auth = Auth.auth()
        let user = if let current = auth.currentUser { current } else { try await auth.signInAnonymously().user }
        let idToken = try await user.getIDToken()
        let appCheck = try await AppCheck.appCheck().token(forcingRefresh: false)
        return ["Authorization": "Bearer \(idToken)", "X-Firebase-AppCheck": appCheck.token]
    }
}
