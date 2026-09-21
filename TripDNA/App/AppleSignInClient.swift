import AuthenticationServices
import Foundation
import UIKit

struct AppleSignInResult: Sendable {
    let userID: String
    let identityToken: Data?
    let email: String?
    let fullName: PersonNameComponents?
}

enum AppleSignInError: LocalizedError {
    case missingCredential
    case missingPresentationAnchor
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            return "Apple 로그인 정보를 받지 못했어요."
        case .missingPresentationAnchor:
            return "로그인 화면을 표시할 수 없어요."
        case .underlying(let error):
            return error.localizedDescription
        }
    }

    /// 사용자가 시트를 닫은 경우. UI에서는 오류로 보여 주지 않는다.
    var isCancellation: Bool {
        guard case .underlying(let error) = self else { return false }
        let nsError = error as NSError
        return nsError.domain == ASAuthorizationError.errorDomain
            && nsError.code == ASAuthorizationError.canceled.rawValue
    }
}

/// AuthenticationServices 기반 Sign in with Apple. Firebase 연동 전까지는 `userID`만 세션에 반영한다.
final class AppleSignInClient: NSObject {
    static let shared = AppleSignInClient()

    @MainActor
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?

    @MainActor
    func signIn() async throws -> AppleSignInResult {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        return try await withCheckedThrowingContinuation { continuation in
            if let existing = self.continuation {
                existing.resume(throwing: AppleSignInError.missingCredential)
                self.continuation = nil
            }
            self.continuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    @MainActor
    private func finish(_ result: Result<AppleSignInResult, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

extension AppleSignInClient: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                finish(.failure(AppleSignInError.missingCredential))
                return
            }
            finish(.success(AppleSignInResult(
                userID: credential.user,
                identityToken: credential.identityToken,
                email: credential.email,
                fullName: credential.fullName
            )))
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            finish(.failure(AppleSignInError.underlying(error)))
        }
    }
}

extension AppleSignInClient: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let key = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return key
        }
        if let first = scenes.flatMap(\.windows).first {
            return first
        }
        if let scene = scenes.first {
            return UIWindow(windowScene: scene)
        }
        // 연결 씬이 없는 극히 드문 경우. 호출 측에서 권한 요청 실패로 이어질 수 있다.
        preconditionFailure("No UIWindowScene available for Sign in with Apple")
    }
}
