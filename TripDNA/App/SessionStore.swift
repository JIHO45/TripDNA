import Foundation

enum OnboardingPhase: Equatable {
    case notStarted
    case inProgress
    case completed
}

@Observable
final class SessionStore {
    private static let signedOutKey = "session.signedOut"
    private static let authenticatedKey = "session.authenticated"
    private static let previousAppleUserIDKey = "session.previousAppleUserID"
    /// Apple `user` 식별자. 로컬 프로필 ID와 별도로 보관한다.
    var appleUserID: String? = UserDefaults.standard.bool(forKey: authenticatedKey)
        ? UserDefaults.standard.string(forKey: previousAppleUserIDKey) : nil
    var userID = UUID().uuidString
    var onboardingPhase: OnboardingPhase = .notStarted
    var isAuthenticated = UserDefaults.standard.bool(forKey: authenticatedKey)
    var requiresSignIn = UserDefaults.standard.bool(forKey: signedOutKey)

    /// 서버가 없는 동안 로그인은 사용자에게 이득이 없으므로 선택으로 둔다.
    /// 기록이 기기에 남으니 온보딩만 끝나면 홈으로 들어간다.
    /// CloudKit을 붙여 기기 간 이어보기가 생기는 시점에 다시 필수로 되돌린다.
    var isReadyForMainApp: Bool {
        onboardingPhase == .completed && !requiresSignIn
    }

    /// Preview·테스트용. 실제 로그인 플로우는 `applyAppleSignIn`을 쓴다.
    func signInWithApple() {
        isAuthenticated = true
    }

    func applyAppleSignIn(userID: String) {
        appleUserID = userID
        isAuthenticated = true
        requiresSignIn = false
        UserDefaults.standard.set(userID, forKey: Self.previousAppleUserIDKey)
        UserDefaults.standard.set(true, forKey: Self.authenticatedKey)
        UserDefaults.standard.set(false, forKey: Self.signedOutKey)
    }

    func canRestoreAppleUser(_ userID: String) -> Bool {
        guard let previous = UserDefaults.standard.string(forKey: Self.previousAppleUserIDKey) else {
            return true
        }
        return previous == userID
    }

    func signOut() {
        if let appleUserID {
            UserDefaults.standard.set(appleUserID, forKey: Self.previousAppleUserIDKey)
        }
        isAuthenticated = false
        appleUserID = nil
        requiresSignIn = true
        UserDefaults.standard.set(true, forKey: Self.signedOutKey)
        UserDefaults.standard.set(false, forKey: Self.authenticatedKey)
    }

    func resetAfterDeletion() {
        appleUserID = nil
        userID = UUID().uuidString
        onboardingPhase = .notStarted
        isAuthenticated = false
        requiresSignIn = false
        UserDefaults.standard.removeObject(forKey: Self.previousAppleUserIDKey)
        UserDefaults.standard.removeObject(forKey: Self.signedOutKey)
        UserDefaults.standard.removeObject(forKey: Self.authenticatedKey)
    }
}
