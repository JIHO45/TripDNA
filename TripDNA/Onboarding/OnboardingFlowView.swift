import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            AuroraBackground()
            Group {
                switch viewModel.stage {
                case .hook:
                    OnboardingHookView(viewModel: viewModel)
                case .hookExpectation:
                    OnboardingExpectationView(viewModel: viewModel)
                case .homeCountry:
                    OnboardingHomeCountryView(viewModel: viewModel, dependencies: dependencies)
                case .entryModeSelection:
                    OnboardingEntryModeView(viewModel: viewModel)
                case .photoPriming:
                    OnboardingPhotoPrimingView(viewModel: viewModel)
                case .photoScanning:
                    OnboardingPhotoScanningView(viewModel: viewModel)
                case .photoScanReview:
                    OnboardingScanCardLoopView(viewModel: viewModel, dependencies: dependencies, session: session)
                case .manualEntry:
                    OnboardingManualEntryView(viewModel: viewModel, dependencies: dependencies, session: session)
                case .quiz:
                    OnboardingQuizView(viewModel: viewModel, dependencies: dependencies, session: session)
                case .analyzing:
                    OnboardingAnalyzingView(viewModel: viewModel)
                case .result:
                    OnboardingResultView(viewModel: viewModel)
                case .appleSignIn:
                    AppleSignInView(viewModel: viewModel, mode: .onboardingSave)
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.stage)
    }
}

// MARK: - 1A-1 훅 (가치 선언)

struct OnboardingHookView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            FingerprintMotifView()
            VStack(spacing: DNASpacing.sm) {
                Text("지금까지의 여행이,\n다음 여행지를 알고 있어요")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("다녀온 여행으로 먼저 읽고, 부족한 축만 짧게 물어볼게요")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.dnaSlate)
            }
            .padding(.horizontal, DNASpacing.lg)
            .padding(.top, DNASpacing.lg)
            Spacer()
            DNABottomCTA {
                Button {
                    viewModel.advanceFromHook()
                } label: {
                    Text("시작하기")
                }
                .buttonStyle(.dnaPrimary)

                Text("약 2분이면 끝나요")
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)

            }
        }
    }
}

/// 여행 경로가 지문처럼 그려지는 훅 비주얼. 링이 순차적으로 그려지는 모션.
private struct FingerprintMotifView: View {
    @State private var isDrawn = false

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { ring in
                Circle()
                    .trim(from: 0, to: isDrawn ? 1 : 0.12)
                    .stroke(
                        AngularGradient(
                            colors: [.dnaIndigo, .dnaTeal, .dnaIndigo.opacity(0.4), .dnaTeal, .dnaIndigo],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: ring == 2 ? [26, 10] : [])
                    )
                    .frame(width: 96 + CGFloat(ring) * 34, height: 96 + CGFloat(ring) * 34)
                    .rotationEffect(.degrees(Double(ring) * -32))
                    .opacity(isDrawn ? 1 - Double(ring) * 0.16 : 0.2)
                    .animation(
                        .easeInOut(duration: 1.4).delay(Double(ring) * 0.22),
                        value: isDrawn
                    )
            }
            Image(systemName: "touchid")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(
                    LinearGradient(colors: [.dnaTeal, .dnaIndigo], startPoint: .top, endPoint: .bottom)
                )
                .opacity(isDrawn ? 1 : 0.3)
                .scaleEffect(isDrawn ? 1 : 0.85)
                .animation(.spring(duration: 1.1).delay(0.4), value: isDrawn)
        }
        .frame(width: 220, height: 220)
        .shadow(color: .dnaTeal.opacity(0.45), radius: 30)
        .onAppear { isDrawn = true }
    }
}

// MARK: - 1A-2 기대 설정

struct OnboardingExpectationView: View {
    let viewModel: OnboardingViewModel

    private static let sampleAxes = TasteAxes(
        natureUrban: -0.55,
        energyLevel: -0.3,
        planningStyle: 0.25,
        socialMode: -0.15,
        noveltyAppetite: 0.45
    )

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                trailingTitle: "건너뛰기",
                onBack: { viewModel.goBack() },
                onTrailing: { viewModel.advanceToHomeCountry() }
            )
            Spacer()
            SectionCard {
                FingerprintRadarView(axes: Self.sampleAxes, confidence: nil)
                Text("예시 지문")
                    .font(.caption2)
                    .foregroundStyle(Color.dnaSlate)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, DNASpacing.lg)

            VStack(spacing: DNASpacing.sm) {
                Text("몇 번의 탭이면\n당신의 지문이 나옵니다")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("과거 여행을 넣으면 취향이 그려지고,\n부족한 부분만 몇 문항 더 물어요")
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaSlate)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DNASpacing.lg)
            Spacer()
            DNABottomCTA {
                Button {
                    viewModel.advanceToHomeCountry()
                } label: {
                    Text("내 지문 만들기")
                }
                .buttonStyle(.dnaPrimary)
            }
        }
    }
}

// MARK: - 거주 국가

struct OnboardingHomeCountryView: View {
    let viewModel: OnboardingViewModel
    let dependencies: AppDependencies
    @Environment(SessionStore.self) private var session
    @State private var selectedCode: String
    @State private var isConfirming = false

    init(viewModel: OnboardingViewModel, dependencies: AppDependencies) {
        self.viewModel = viewModel
        self.dependencies = dependencies
        _selectedCode = State(initialValue: viewModel.homeCountryCode)
    }

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                onBack: { viewModel.goBack() }
            )
            VStack(alignment: .leading, spacing: 8) {
                Text("어느 나라에 살고 계세요?")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("맞춤 추천에서 거주 국가는 자동으로 제외돼요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DNASpacing.lg)

            CountrySelectionList(selectedCode: $selectedCode)

            DNABottomCTA {
                Button {
                    isConfirming = true
                    Task {
                        await viewModel.confirmHomeCountry(
                            selectedCode, dependencies: dependencies, session: session
                        )
                        isConfirming = false
                    }
                } label: {
                    Text("계속하기")
                }
                .buttonStyle(.dnaPrimary(isDisabled: selectedCode.isEmpty || isConfirming))
                .disabled(selectedCode.isEmpty || isConfirming)
            }
        }
    }
}

// MARK: - 1B-1 등록 방식 선택

struct OnboardingEntryModeView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                onBack: { viewModel.goBack() }
            )
            VStack(spacing: DNASpacing.lg) {
                Text("지난 여행을\n어떻게 불러올까요?")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, DNASpacing.xl)

                VStack(spacing: DNASpacing.sm) {
                    EntryModeCard(
                        systemImage: "photo.on.rectangle.angled",
                        title: "사진첩에서 자동으로 찾기",
                        subtitle: "사진 위치를 기기 안에서 분석해 국가와 시기를 채워드려요",
                        badge: "빠르게 등록"
                    ) { viewModel.selectEntryMode(.photoScan) }

                    EntryModeCard(
                        systemImage: "pencil.line",
                        title: "직접 입력하기",
                        subtitle: "사진 권한 없이 국가와 시기를 직접 입력해요",
                        badge: nil
                    ) { viewModel.selectEntryMode(.manual) }
                }
                .padding(.horizontal, DNASpacing.lg)

                Spacer()

                DNABottomCTA {
                    Button("여행 이력이 없어요 · 사진 퀴즈로 시작") {
                        viewModel.selectEntryMode(.quiz)
                    }
                    .buttonStyle(.dnaGhost)
                }
            }
        }
    }
}

/// 방식 선택 전용 카드. 두 방식을 동등한 크기로 배치하고 틸 배지를 지원한다.
private struct EntryModeCard: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.dnaIndigo.opacity(0.35), .dnaTeal.opacity(0.25)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        Image(systemName: systemImage)
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    Spacer(minLength: 0)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.dnaTeal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.dnaTeal.opacity(0.14), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.dnaTeal.opacity(0.4), lineWidth: 1))
                    }
                }
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
                    .fixedSize(horizontal: false, vertical: true)
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
        }
        .buttonStyle(.plain)
    }
}

#Preview("OnboardingFlowView") {
    OnboardingFlowView()
        .previewWithAppEnvironment()
}

#Preview("OnboardingHookView") {
    OnboardingHookView(viewModel: OnboardingViewModel())
        .background(AuroraBackground())
        .preferredColorScheme(.dark)
}

#Preview("OnboardingExpectationView") {
    OnboardingExpectationView(viewModel: OnboardingViewModel())
        .background(AuroraBackground())
        .preferredColorScheme(.dark)
}

#Preview("OnboardingHomeCountryView") {
    let dependencies = AppDependencies()
    return OnboardingHomeCountryView(
        viewModel: OnboardingViewModel(),
        dependencies: dependencies
    )
    .environment(dependencies)
    .background(AuroraBackground())
    .preferredColorScheme(.dark)
}

#Preview("OnboardingEntryModeView") {
    OnboardingEntryModeView(viewModel: OnboardingViewModel())
        .background(AuroraBackground())
        .preferredColorScheme(.dark)
}
