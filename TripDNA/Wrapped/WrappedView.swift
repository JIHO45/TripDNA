import SwiftUI

/// UI-5 연간 Wrapped 루트.
/// 5A 인트로 → 5B 6장 카드 시퀀스 순서로 전환하며, 시즌 게이트·연도 판정은
/// 기존 `WrappedService`(12/15 ~ 1/15) 로직을 그대로 사용한다.
struct WrappedView: View {
    let forcePreview: Bool
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = WrappedViewModel()
    @State private var isStoryPresented = false

    var body: some View {
        Group {
            if let display = viewModel.display {
                if isStoryPresented {
                    WrappedStoryView(display: display)
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                } else {
                    WrappedIntroView(
                        display: display,
                        onStart: {
                            withAnimation(.easeOut(duration: 0.35)) { isStoryPresented = true }
                        },
                        onLater: { dismiss() }
                    )
                    .transition(.opacity)
                }
            } else if viewModel.isLoading {
                LoadingView()
                    .background(AuroraBackground())
            } else {
                EmptyStateView(
                    systemImage: "sparkles.rectangle.stack",
                    title: "Wrapped를 볼 수 없어요",
                    message: viewModel.notAvailableReason ?? ""
                )
                .background(AuroraBackground())
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.load(dependencies, forcePreview: forcePreview) }
    }
}

// MARK: - UI-5A 시작 화면

private struct WrappedIntroView: View {
    let display: WrappedDisplayModel
    let onStart: () -> Void
    let onLater: () -> Void

    var body: some View {
        ZStack {
            AppCanvas()

            VStack(spacing: DNASpacing.md) {
                Spacer()

                Text("한 해의 기록이 모였어요")
                    .font(.footnote.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Color.dnaSlate)

                Text(verbatim: "\(display.year)")
                    .font(.system(size: 84, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.dnaTeal, .dnaIndigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(display.heroTitle)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                introStats
                    .padding(.top, DNASpacing.lg)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, DNASpacing.lg)

            VStack {
                Spacer()
                DNABottomCTA {
                    Button("내 Wrapped 보기", action: onStart)
                        .buttonStyle(.dnaPrimary)
                    Button("나중에", action: onLater)
                        .buttonStyle(.dnaGhost)
                }
            }
        }
    }

    private var introStats: some View {
        HStack(spacing: 0) {
            statColumn(value: display.destinationCount, label: "여행 국가")
            Rectangle()
                .fill(Color.dnaHairline)
                .frame(width: 1, height: 44)
            statColumn(value: display.tripCount, label: "여행 수")
        }
        .padding(.vertical, DNASpacing.md)
        .frame(maxWidth: 300)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaHairline, lineWidth: 1)
        )
    }

    private func statColumn(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: "\(value)")
                .font(.title.bold())
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.dnaSlate)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("WrappedView") {
    NavigationStack {
        WrappedView(forcePreview: true)
    }
    .previewWithAppEnvironment()
}
