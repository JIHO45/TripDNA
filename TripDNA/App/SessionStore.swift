import Foundation

enum OnboardingPhase: Equatable {
    case notStarted
    case inProgress
    case completed
}

@Observable
final class SessionStore {
    private static let authenticatedKey = "session.authenticated"
    private static let appleUserIDKey = "session.previousAppleUserID"
    /// 이전 버전에서 로그아웃하면 남던 값. 지금은 로그아웃이 없으므로 지우기만 한다.
    private static let legacySignedOutKey = "session.signedOut"
    /// Apple `user` 식별자. 로컬 프로필 ID와 별도로 보관한다.
    var appleUserID: String? = UserDefaults.standard.bool(forKey: authenticatedKey)
        ? UserDefaults.standard.string(forKey: appleUserIDKey) : nil
    var userID = UUID().uuidString
    var onboardingPhase: OnboardingPhase = .notStarted
    var isAuthenticated = UserDefaults.standard.bool(forKey: authenticatedKey)

    init() {
        UserDefaults.standard.removeObject(forKey: Self.legacySignedOutKey)
    }

    /// 서버가 없는 동안 로그인은 사용자에게 이득이 없으므로 선택으로 둔다.
    /// 기록이 기기에 남으니 온보딩만 끝나면 홈으로 들어간다.
    /// CloudKit을 붙여 기기 간 이어보기가 생기는 시점에 로그인·로그아웃을 다시 설계한다.
    var isReadyForMainApp: Bool {
        onboardingPhase == .completed
    }

    /// Preview·테스트용. 실제 로그인 플로우는 `applyAppleSignIn`을 쓴다.
    func signInWithApple() {
        isAuthenticated = true
    }

    func applyAppleSignIn(userID: String) {
        appleUserID = userID
        isAuthenticated = true
        UserDefaults.standard.set(userID, forKey: Self.appleUserIDKey)
        UserDefaults.standard.set(true, forKey: Self.authenticatedKey)
    }

    func resetAfterDeletion() {
        appleUserID = nil
        userID = UUID().uuidString
        onboardingPhase = .notStarted
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: Self.appleUserIDKey)
        UserDefaults.standard.removeObject(forKey: Self.authenticatedKey)
    }
}
