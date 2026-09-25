import AuthenticationServices
import SwiftUI

// MARK: - 1D-1 지문 합성 연출

/// 결과 계산과 병행되는 2~4초 고정 연출. 실제 파이프라인 단계와 일치하는 문구만 쓴다.
struct OnboardingAnalyzingView: View {
    let viewModel: OnboardingViewModel
    @State private var phaseIndex = 0
    @State private var motifScale: CGFloat = 0.82

    private let phases = [
        "여행 분석 중",
        "취향 축 계산 중",
        "30개국과 비교 중"
    ]

    var body: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.dnaTextTertiary.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 140
                        )
                    )
                    .frame(width: 280, height: 280)
                FingerprintRadarView(
                    axes: PreviewSample.axes,
                    confidence: PreviewSample.confidence
                )
                .opacity(0.35 + Double(phaseIndex) * 0.2)
                .scaleEffect(motifScale)
                .blur(radius: phaseIndex < 2 ? 2 : 0)
            }
            .frame(height: 240)

            Text(phases[min(phaseIndex, phases.count - 1)])
                .font(.title3.bold())
                .foregroundStyle(.white)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.35), value: phaseIndex)

            Text("지문을 그리는 중이에요")
                .font(.subheadline)
                .foregroundStyle(Color.dnaTextSecondary)
            Spacer()
        }
        .padding(DNASpacing.lg)
        .task {
            withAnimation(.easeOut(duration: 1.2)) {
                motifScale = 1
            }
            for index in phases.indices {
                phaseIndex = index
                try? await Task.sleep(for: .seconds(0.85))
            }
        }
    }
}

// MARK: - 1D-2 · 1D-3 지문 공개 + 첫 추천 3슬롯

struct OnboardingResultView: View {
    let viewModel: OnboardingViewModel

    private var isQuizOnly: Bool {
        viewModel.entryMode == .quiz
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DNASpacing.lg) {
                VStack(spacing: 6) {
                    Text(isQuizOnly ? "첫인상 지문" : "당신의 여행 지문")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dnaTextSecondary)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    if let vector = viewModel.resultVector {
                        Text(AxisNarrative.representativeSentenceKo(
                            axes: vector.axes,
                            confidence: vector.confidence
                        ))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, DNASpacing.md)

                if let vector = viewModel.resultVector {
                    SectionCard {
                        FingerprintRadarView(axes: vector.axes, confidence: vector.confidence)
                        if hasLowConfidence(vector.confidence) {
                            Text("아직 흐려요 · 여행을 평가할수록 지문이 선명해져요")
                                .font(.caption)
                                .foregroundStyle(Color.dnaTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            Text("여행을 평가할수록 지문이 선명해져요")
                                .font(.caption)
                                .foregroundStyle(Color.dnaTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DNASpacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "fingerprint")
                            .foregroundStyle(Color.dnaData)
                        Text("당신의 지문으로 찾은 다음 여행지")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    ForEach(viewModel.recommendations) { recommendation in
                        firstSlotCard(recommendation)
                    }
                }

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.dnaAction)
                }
            }
            .padding(DNASpacing.lg)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            DNABottomCTA {
                Button {
                    viewModel.proceedToSignIn()
                } label: {
                    Text("이 지문 저장하기")
                }
                .buttonStyle(.dnaPrimary)
            }
        }
        .background(AppCanvas())
    }

    private func firstSlotCard(_ recommendation: Recommendation) -> some View {
        HStack(alignment: .top, spacing: DNASpacing.md) {
            Text(flagEmoji(for: recommendation.countryCode))
                .font(.system(size: 36))
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            recommendation.slot.accentColor.opacity(0.35),
                            recommendation.slot.accentColor.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 6) {
                SlotChip(slot: recommendation.slot)
                Text(CountryCatalog.name(for: recommendation.countryCode))
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text(reasonLine(for: recommendation))
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ScoreBadge(score: recommendation.matchScore)
            }
            Spacer(minLength: 0)
        }
        .padding(DNASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(recommendation.slot.accentColor.opacity(0.35), lineWidth: 1)
        )
    }

    private func reasonLine(for recommendation: Recommendation) -> String {
        if let tagID = recommendation.explanationTagIDs.first {
            return "당신이 고른 '\(TagCatalog.labelKo(for: tagID))'와 닮았어요"
        }
        if let badge = recommendation.fitBadges.first {
            return badge
        }
        return recommendation.slot.subtitleKo
    }

    private func hasLowConfidence(_ confidence: AxisConfidence) -> Bool {
        TasteAxis.allCases.contains { confidence[$0] < 0.4 }
    }

    private func flagEmoji(for countryCode: String) -> String {
        OnboardingFormat.flagEmoji(for: countryCode)
    }
}

// MARK: - UI-2 Apple 로그인

/// 온보딩 페이오프 뒤 선택 로그인. 지문을 Apple 계정에 연결한다.
struct AppleSignInView: View {
    var viewModel: OnboardingViewModel?
    var onBack: (() -> Void)?
    @Environment(SessionStore.self) private var session
    @Environment(AppDependencies.self) private var dependencies
    @State private var didSucceed = false
    @State private var isSigningIn = false
    @State private var pendingAppleUserID: String?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if didSucceed {
                successView
            } else {
                promptView
            }
        }
        .background(AppCanvas())
    }

    private var promptView: some View {
        VStack(spacing: DNASpacing.lg) {
            if let onBack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.dnaTextSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, DNASpacing.lg)
                .padding(.top, DNASpacing.sm)
            }

            Spacer()
            if let vector = viewModel?.resultVector {
                SectionCard {
                    FingerprintRadarView(axes: vector.axes, confidence: vector.confidence)
                        .frame(height: 160)
                    Text(AxisNarrative.representativeSentenceKo(
                        axes: vector.axes,
                        confidence: vector.confidence
                    ))
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, DNASpacing.lg)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 96, height: 96)
                    Image(systemName: "applelogo")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }

            Text(headlineText)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(subtitleText)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.dnaTextSecondary)
                .padding(.horizontal, DNASpacing.xl)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.dnaAction)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DNASpacing.lg)
            }

            Spacer()

            VStack(spacing: DNASpacing.sm) {
                Button {
                    Task { await signIn() }
                } label: {
                    HStack(spacing: 8) {
                        if isSigningIn {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Image(systemName: "applelogo")
                        }
                        Text(isSigningIn ? "로그인 중…" : ctaText)
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule(style: .continuous).fill(Color.white))
                }
                .buttonStyle(.plain)
                .disabled(isSigningIn)

                Button("로그인 없이 시작하기") {
                    continueWithoutSignIn()
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dnaTextSecondary)
                .frame(height: 44)
                .disabled(isSigningIn)

                Text("계속하면 이용약관 및 개인정보 처리방침에 동의하게 됩니다.")
                    .font(.caption2)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DNASpacing.lg)
            .padding(.bottom, DNASpacing.lg)
        }
    }

    private var successView: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.dnaData.opacity(0.16))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.dnaData)
            }
            Text(successHeadlineText)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(successSubtitleText)
                .font(.subheadline)
                .foregroundStyle(Color.dnaTextSecondary)
            Spacer()
            DNABottomCTA {
                Button("홈으로 가기") {
                    finalizeSignIn()
                }
                .buttonStyle(.dnaPrimary)
            }
        }
        .task {
            // 체크 모션을 잠깐 보여준 뒤 자동으로 홈으로 이동한다(CTA는 유지).
            try? await Task.sleep(for: .seconds(1.2))
            finalizeSignIn()
        }
    }

    private let headlineText = "Apple 계정으로 로그인할까요?"
    private let subtitleText = "기록은 이 기기에 저장돼요.\n로그인은 계정을 연결하려는 경우에만 하면 돼요."
    private let ctaText = "Apple로 계속하기"
    private let successHeadlineText = "로그인했어요"
    private let successSubtitleText = "홈에서 추천과 여행을 이어갈 수 있어요."

    @MainActor
    private func signIn() async {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil
        defer { isSigningIn = false }

        do {
            let result = try await AppleSignInClient.shared.signIn()
            pendingAppleUserID = result.userID
            // 성공 연출 동안에는 세션을 열지 않는다.
            // (즉시 인증하면 RootView가 MainTab으로 바뀌어 체크 화면이 스킵된다.)
            withAnimation(.easeOut(duration: 0.25)) {
                didSucceed = true
            }
        } catch {
            // 스펙: 인증 취소는 오류로 취급하지 않고 로그인 화면 유지.
            if isAppleSignInCancellation(error) { return }
            errorMessage = "연결을 확인하고 다시 시도해 주세요"
        }
    }

    private func finalizeSignIn() {
        if session.isAuthenticated { return }
        guard let appleUserID = pendingAppleUserID else { return }
        if let viewModel {
            viewModel.completeSignIn(session: session, appleUserID: appleUserID)
        } else {
            session.applyAppleSignIn(userID: appleUserID)
            session.onboardingPhase = .completed
        }
        Task { await dependencies.markOnboardingCompleted() }
    }

    /// 서버가 없는 동안 로그인은 사용자에게 이득이 없다. 기록은 기기에 남으므로
    /// 로그인하지 않아도 그대로 이어서 쓸 수 있다.
    private func continueWithoutSignIn() {
        session.onboardingPhase = .completed
        Task { await dependencies.markOnboardingCompleted() }
    }

    private func isAppleSignInCancellation(_ error: Error) -> Bool {
        if let appleError = error as? AppleSignInError {
            return appleError.isCancellation
        }
        let nsError = error as NSError
        return nsError.domain == ASAuthorizationError.errorDomain
            && nsError.code == ASAuthorizationError.canceled.rawValue
    }
}

#Preview("OnboardingAnalyzingView") {
    OnboardingAnalyzingView(viewModel: OnboardingViewModel())
        .background(AppCanvas())
        .preferredColorScheme(.dark)
}

#Preview("OnboardingResultView") {
    let viewModel = OnboardingViewModel()
    viewModel.entryMode = .quiz
    viewModel.resultVector = PreviewSample.vector
    viewModel.recommendations = [
        PreviewSample.recommendation,
        Recommendation(
            countryCode: "SI",
            slot: .freshStretch,
            matchScore: 0.71,
            explanationTagIDs: ["outdoor"],
            rankingAnchorTripID: nil,
            fitBadges: ["취향에서 반 발짝"],
            notices: []
        ),
        Recommendation(
            countryCode: "LA",
            slot: .underratedFit,
            matchScore: 0.66,
            explanationTagIDs: ["culture"],
            rankingAnchorTripID: nil,
            fitBadges: ["숨은 보석"],
            notices: []
        )
    ]
    return OnboardingResultView(viewModel: viewModel)
        .previewWithAppEnvironment()
}

#Preview("AppleSignInView") {
    AppleSignInView()
        .previewWithAppEnvironment()
}
