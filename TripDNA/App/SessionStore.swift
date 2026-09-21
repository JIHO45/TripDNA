import Foundation

enum OnboardingPhase: Equatable {
    case notStarted
    case inProgress
    case completed
}

@Observable
final class SessionStore {
    /// Apple `user` 식별자. Firebase Auth 연동 시 `uid` 매핑 전까지 로컬 세션 키로 쓴다.
    var appleUserID: String?
    var userID = UUID().uuidString
    var onboardingPhase: OnboardingPhase = .notStarted
    var isAuthenticated = false

    /// 서버가 없는 동안 로그인은 사용자에게 이득이 없으므로 선택으로 둔다.
    /// 기록이 기기에 남으니 온보딩만 끝나면 홈으로 들어간다.
    /// CloudKit을 붙여 기기 간 이어보기가 생기는 시점에 다시 필수로 되돌린다.
    var isReadyForMainApp: Bool {
        onboardingPhase == .completed
    }

    /// Preview·테스트용. 실제 로그인 플로우는 `applyAppleSignIn`을 쓴다.
    func signInWithApple() {
        isAuthenticated = true
    }

    func applyAppleSignIn(userID: String) {
        appleUserID = userID
        // Firebase 전: Apple user를 앱 내부 userID로도 쓴다.
        self.userID = userID
        isAuthenticated = true
    }

    func signOut() {
        isAuthenticated = false
        appleUserID = nil
    }
}
