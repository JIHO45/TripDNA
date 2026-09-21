import SwiftUI

// MARK: - 1B-2 사진첩 프라이밍

struct OnboardingPhotoPrimingView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                onBack: { viewModel.goBack() }
            )
            Spacer()
            MapPinsMotifView()
            VStack(spacing: DNASpacing.sm) {
                Text("다녀온 곳을\n지도에서 찾아드릴까요?")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("사진 위치로 국가와 시기를 자동으로 채워드려요")
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaSlate)
            }
            .padding(.top, DNASpacing.lg)

            DNATrustPanel(text: "사진 위치는 기기 안에서만 분석돼요. 서버로 전송되지 않아요.")
                .padding(.horizontal, DNASpacing.lg)
                .padding(.top, DNASpacing.lg)
            Spacer()
            DNABottomCTA {
                Button {
                    viewModel.startPhotoScan()
                } label: {
                    Text("사진 접근 허용하고 찾기")
                }
                .buttonStyle(.dnaPrimary)

                Button("직접 입력으로 바꾸기") {
                    viewModel.selectEntryMode(.manual)
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }
}

/// 도트 지도 위로 틸 핀이 내려앉는 프라이밍 비주얼.
private struct MapPinsMotifView: View {
    @State private var isDropped = false

    private let pins: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (0.24, 0.32, 0.1), (0.48, 0.55, 0.3), (0.68, 0.28, 0.5), (0.82, 0.62, 0.7)
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface)
            DotGridView()
                .clipShape(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            GeometryReader { proxy in
                ForEach(Array(pins.enumerated()), id: \.offset) { _, pin in
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.dnaTeal)
                        .shadow(color: .dnaTeal.opacity(0.7), radius: 6)
                        .position(x: proxy.size.width * pin.x, y: proxy.size.height * pin.y)
                        .offset(y: isDropped ? 0 : -14)
                        .opacity(isDropped ? 1 : 0)
                        .animation(.spring(duration: 0.6).delay(pin.delay), value: isDropped)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaHairline, lineWidth: 1)
        )
        .frame(height: 190)
        .padding(.horizontal, DNASpacing.lg)
        .onAppear { isDropped = true }
    }
}

private struct DotGridView: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 14
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: 2.4, height: 2.4)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.1)))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

// MARK: - 1B-4 스캔 연출 (0건 결과 포함)

struct OnboardingPhotoScanningView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        if viewModel.scanFoundNothing {
            noResultView
        } else {
            scanningView
        }
    }

    private var scanningView: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            ScanPulseView()
            Text(viewModel.scanStatusText)
                .font(.headline)
                .foregroundStyle(.white)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.scanStatusText)
            ProgressView()
                .tint(Color.dnaTeal)
            Spacer()
            DNABottomCTA {
                Button("취소") {
                    viewModel.cancelPhotoScan()
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }

    private var noResultView: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                onBack: { viewModel.goBack() }
            )
            Spacer()
            EmptyStateView(
                systemImage: "photo.badge.exclamationmark",
                title: "여행 기록을 찾지 못했어요",
                message: "위치 정보가 있는 여행 사진이 없어도 괜찮아요.\n다른 방법으로 지문을 만들 수 있어요."
            )
            .frame(maxHeight: 320)
            Spacer()
            DNABottomCTA {
                Button {
                    viewModel.selectEntryMode(.manual)
                } label: {
                    Text("직접 등록")
                }
                .buttonStyle(.dnaPrimary)

                Button("사진 퀴즈로 시작") {
                    viewModel.selectEntryMode(.quiz)
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }
}

/// 스캔 중 맥동하는 지문 링 모션.
private struct ScanPulseView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .strokeBorder(Color.dnaTeal.opacity(0.5 - Double(ring) * 0.14), lineWidth: 1.4)
                    .frame(width: 88 + CGFloat(ring) * 36, height: 88 + CGFloat(ring) * 36)
                    .scaleEffect(isPulsing ? 1.06 : 0.94)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(ring) * 0.18),
                        value: isPulsing
                    )
            }
            Image(systemName: "photo.stack")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.dnaTeal)
        }
        .frame(width: 190, height: 190)
        .shadow(color: .dnaTeal.opacity(0.35), radius: 24)
        .onAppear { isPulsing = true }
    }
}

// MARK: - 1B-5 여행 확인 카드 루프

struct OnboardingScanCardLoopView: View {
    let viewModel: OnboardingViewModel
    let dependencies: AppDependencies
    let session: SessionStore

    @State private var satisfaction: Int?
    @State private var showComparison = false
    @State private var isAdvancing = false

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                counterText: counterText,
                onBack: { handleBack() }
            )

            if let draft = viewModel.currentScanDraft {
                Spacer(minLength: DNASpacing.md)
                Group {
                    if showComparison, let anchor = viewModel.scanAnchorDraft {
                        comparisonSection(current: draft, anchor: anchor)
                    } else {
                        satisfactionSection(draft: draft)
                    }
                }
                .id("\(draft.id)-\(showComparison)")
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                Spacer(minLength: DNASpacing.md)

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.dnaCoral)
                        .padding(.bottom, DNASpacing.xs)
                }

                DNABottomCTA {
                    Button("이 여행 아니에요") {
                        removeCurrentTrip()
                    }
                    .buttonStyle(.dnaGhost)

                    Button("나머지는 나중에") {
                        finishEarly()
                    }
                    .buttonStyle(.dnaGhost)
                    .disabled(!viewModel.canFinishScanEarly)
                    .opacity(viewModel.canFinishScanEarly ? 1 : 0.35)
                }
            } else {
                LoadingView()
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showComparison)
        .animation(.easeInOut(duration: 0.28), value: viewModel.scanCardIndex)
        .onChange(of: viewModel.scanCardIndex) {
            satisfaction = nil
            showComparison = false
            isAdvancing = false
        }
    }

    private var counterText: String {
        "\(min(viewModel.scanCardIndex + 1, viewModel.photoScanDrafts.count)) / \(viewModel.photoScanDrafts.count)"
    }

    // MARK: 만족도 원탭

    private func satisfactionSection(draft: ManualTripDraft) -> some View {
        VStack(spacing: DNASpacing.lg) {
            ScanTripCard(draft: draft)
                .padding(.horizontal, DNASpacing.lg)

            VStack(spacing: DNASpacing.md) {
                Text("이 여행, 얼마나 좋았나요?")
                    .font(.headline)
                    .foregroundStyle(.white)
                DNASatisfactionEmojiRow(
                    satisfaction: $satisfaction,
                    onSelect: { value in
                        handleSatisfaction(value)
                    }
                )
                .padding(.horizontal, DNASpacing.lg)
            }
        }
    }

    private func handleSatisfaction(_ value: Int) {
        guard !isAdvancing else { return }
        viewModel.setScanSatisfaction(value)
        if viewModel.scanAnchorDraft != nil {
            // 두 번째 카드부터: 원탭 직후 같은 흐름에서 서열 비교 1회.
            isAdvancing = true
            Task {
                try? await Task.sleep(for: .seconds(0.35))
                showComparison = true
                isAdvancing = false
            }
        } else {
            advance(after: 0.4)
        }
    }

    // MARK: 서열 비교

    private func comparisonSection(current: ManualTripDraft, anchor: ManualTripDraft) -> some View {
        VStack(spacing: DNASpacing.lg) {
            Text("예전 \(CountryCatalog.name(for: anchor.countryCode))보다 좋았나요?")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DNASpacing.lg)

            ZStack {
                HStack(spacing: DNASpacing.sm) {
                    ComparisonTripCard(draft: current, caption: "이번에 확인한 여행") {
                        answerComparison(.better)
                    }
                    ComparisonTripCard(draft: anchor, caption: "예전 여행") {
                        answerComparison(.worse)
                    }
                }
                .padding(.horizontal, DNASpacing.lg)

                Text("VS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dnaSlate)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.dnaSurfaceElevated))
                    .overlay(Circle().strokeBorder(Color.dnaHairline, lineWidth: 1))
            }

            Button("비슷했어요 / 기억 안 나요") {
                answerComparison(.skipped)
            }
            .buttonStyle(.dnaGhost)
        }
    }

    private func answerComparison(_ result: ComparisonResult) {
        guard !isAdvancing else { return }
        viewModel.setScanComparison(result)
        advance(after: 0.25)
    }

    // MARK: 진행

    private func advance(after delay: Double) {
        isAdvancing = true
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await viewModel.advanceScanCard(dependencies, session: session)
            isAdvancing = false
        }
    }

    private func removeCurrentTrip() {
        guard !isAdvancing else { return }
        isAdvancing = true
        Task {
            await viewModel.removeCurrentScanDraft(dependencies, session: session)
            isAdvancing = false
            satisfaction = nil
            showComparison = false
        }
    }

    private func finishEarly() {
        guard !isAdvancing else { return }
        isAdvancing = true
        Task {
            await viewModel.finishScanEarly(dependencies, session: session)
            isAdvancing = false
        }
    }

    private func handleBack() {
        if showComparison {
            showComparison = false
        } else if viewModel.scanCardIndex > 0 {
            viewModel.scanCardIndex -= 1
        } else {
            viewModel.goBack()
        }
    }
}

/// 스캔으로 찾은 여행 1건을 보여주는 큰 카드 (사진 자리는 그라데이션 플레이스홀더).
private struct ScanTripCard: View {
    let draft: ManualTripDraft

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            HStack(spacing: DNASpacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.dnaIndigo.opacity(0.42 - Double(index) * 0.08),
                                    Color.dnaTeal.opacity(0.3 - Double(index) * 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 84)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: DNASpacing.xs) {
                    Text(OnboardingFormat.flagEmoji(for: draft.countryCode))
                        .font(.title2)
                    Text(CountryCatalog.name(for: draft.countryCode))
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                Text(OnboardingFormat.periodText(start: draft.startDate, end: draft.endDate))
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaSlate)
            }
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaHairline, lineWidth: 1)
        )
        .shadow(color: Color.dnaIndigo.opacity(0.14), radius: 20, y: 8)
    }
}

/// 서열 비교용 세로형 여행 카드.
private struct ComparisonTripCard: View {
    let draft: ManualTripDraft
    let caption: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DNASpacing.sm) {
                RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.dnaIndigo.opacity(0.4), Color.dnaTeal.opacity(0.28)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 110)
                    .overlay(
                        Text(OnboardingFormat.flagEmoji(for: draft.countryCode))
                            .font(.system(size: 40))
                    )
                VStack(spacing: 2) {
                    Text(CountryCatalog.name(for: draft.countryCode))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(OnboardingFormat.periodText(start: draft.startDate, end: draft.endDate))
                        .font(.caption2)
                        .foregroundStyle(Color.dnaSlate)
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(Color.dnaSlate.opacity(0.8))
                }
            }
            .padding(DNASpacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(Color.dnaSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .strokeBorder(Color.dnaHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("OnboardingPhotoPrimingView") {
    OnboardingPhotoPrimingView(viewModel: OnboardingViewModel())
        .background(AuroraBackground())
        .preferredColorScheme(.dark)
}

#Preview("OnboardingPhotoScanningView") {
    let viewModel = OnboardingViewModel()
    viewModel.scanStatusText = "사진 위치 확인 중"
    return OnboardingPhotoScanningView(viewModel: viewModel)
        .background(AuroraBackground())
        .preferredColorScheme(.dark)
}

#Preview("OnboardingScanCardLoopView") {
    let viewModel = OnboardingViewModel()
    var first = ManualTripDraft()
    first.countryCode = "PT"
    var second = ManualTripDraft()
    second.countryCode = "JP"
    viewModel.photoScanDrafts = [first, second]
    return OnboardingScanCardLoopView(
        viewModel: viewModel,
        dependencies: AppDependencies(),
        session: SessionStore()
    )
    .previewWithAppEnvironment()
}
