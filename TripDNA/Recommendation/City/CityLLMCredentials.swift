import DeviceCheck
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

/// 프록시 요청에 붙이는 헤더: 누가 보냈는지(익명 로그인 ID 토큰), 정식 앱인지(App Check 토큰),
/// 어느 기기인지(DeviceCheck 토큰, 출시 빌드만). 서버는 기기 토큰으로 재설치 뒤 새 익명 ID가 그 달 무료 한도를 다시 받지 못하게 한다.
/// 로그인 화면은 없다. 처음 호출할 때 익명 계정을 만들고 이후에는 같은 계정을 쓴다.
nonisolated enum CityLLMCredentials {
    static func headers() async throws -> [String: String] {
        guard FirebaseApp.app() != nil else { return [:] }
        let auth = Auth.auth()
        let user = if let current = auth.currentUser { current } else { try await auth.signInAnonymously().user }
        let idToken = try await user.getIDToken()
        let appCheck = try await AppCheck.appCheck().token(forcingRefresh: false)
        var headers = ["Authorization": "Bearer \(idToken)", "X-Firebase-AppCheck": appCheck.token]
        if let device = await deviceToken() { headers["X-Apple-Device-Token"] = device }
        return headers
    }

    /// 개발 빌드는 보내지 않는다. 서버는 운영 DeviceCheck만 쓰고, 시뮬레이터는 DeviceCheck를 지원하지 않는다.
    /// 만들지 못하면 보내지 않으며 서버는 기기 확인을 건너뛴다.
    private static func deviceToken() async -> String? {
        #if DEBUG
        return nil
        #else
        guard DCDevice.current.isSupported else { return nil }
        return try? await DCDevice.current.generateToken().base64EncodedString()
        #endif
    }

    /// 전체 삭제 때 익명 계정도 지운다. 오프라인 등으로 서버 삭제에 실패하면 기기에서만 로그아웃해
    /// 다음 호출부터 새 익명 ID를 쓰게 한다. 기기 데이터 삭제는 이 결과와 상관없이 끝난 뒤다.
    static func deleteAnonymousAccount() async {
        guard FirebaseApp.app() != nil, let user = Auth.auth().currentUser else { return }
        do { try await user.delete() } catch { try? Auth.auth().signOut() }
    }
}
