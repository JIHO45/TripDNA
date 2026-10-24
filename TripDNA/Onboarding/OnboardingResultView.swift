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
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
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
                        if let breadth = AxisNarrative.breadthSentenceKo(vector) {
                            Text(breadth)
                                .font(.caption)
                                .foregroundStyle(Color.dnaTextSecondary)
                        }
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
                            .onScrollVisibilityChange(threshold: 0.5) { visible in
                                guard visible, let exposure = viewModel.exposure else { return }
                                Task { await exposure.record(recommendation, dependencies: dependencies) }
                            }
                            .id("\(viewModel.exposure?.id ?? ""):\(recommendation.id)")
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
                    session.onboardingPhase = .completed
                    Task { await dependencies.markOnboardingCompleted() }
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
