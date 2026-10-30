import Foundation

enum OnboardingPhase: Equatable {
    case notStarted
    case inProgress
    case completed
}

@Observable
final class SessionStore {
    /// 이전 버전이 남긴 로그인 관련 값. 로그인이 없어졌으므로 지우기만 한다.
    private static let legacyKeys = ["session.authenticated", "session.previousAppleUserID", "session.signedOut"]
    var userID = UUID().uuidString
    var onboardingPhase: OnboardingPhase = .notStarted

    init() {
        Self.legacyKeys.forEach { AppStorageLocation.defaults.removeObject(forKey: $0) }
    }

    /// 앱에는 로그인이 없다. 기록이 기기에 남으니 온보딩만 끝나면 홈으로 들어간다.
    var isReadyForMainApp: Bool {
        onboardingPhase == .completed
    }

    func resetAfterDeletion() {
        userID = UUID().uuidString
        onboardingPhase = .notStarted
    }
}
