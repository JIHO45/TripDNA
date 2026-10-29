import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            AppCanvas()
            Group {
                switch viewModel.stage {
                case .hook:
                    OnboardingHookView(viewModel: viewModel)
                case .homeCountry:
                    OnboardingHomeCountryView(viewModel: viewModel, dependencies: dependencies)
                case .entryModeSelection:
                    OnboardingEntryModeView(viewModel: viewModel)
                case .photoPriming:
                    OnboardingPhotoPrimingView(viewModel: viewModel)
                case .photoScanning:
                    OnboardingPhotoScanningView(viewModel: viewModel)
                case .noCandidates:
                    OnboardingNoCandidatesView(viewModel: viewModel)
                case .candidates:
                    OnboardingCandidatesView(viewModel: viewModel, dependencies: dependencies)
                case .concepts:
                    OnboardingConceptsView(viewModel: viewModel, dependencies: dependencies)
                case .tiers:
                    OnboardingTiersView(viewModel: viewModel, dependencies: dependencies)
                case .summary:
                    OnboardingSummaryView(viewModel: viewModel, dependencies: dependencies, session: session)
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.stage)
        .task { await viewModel.restore(dependencies) }
        .onChange(of: viewModel.draft) { Task { await viewModel.saveDraft(dependencies) } }
        // "직접 등록"은 여행 탭의 여행 등록 화면을 그대로 쓴다.
        .sheet(isPresented: $viewModel.showsManualRegistration) {
            NavigationStack {
                TripRegistrationView(prefilledCountryCode: nil) {
                    Task { await viewModel.finishManualRegistration(dependencies: dependencies) }
                }
            }
        }
    }
}

// MARK: - ① 시작

struct OnboardingHookView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            PhotoCollagePlaceholder()
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.top, DNASpacing.xl)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                Text("TripDNA")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                Text("다녀온 여행으로\n다음 여행지를 골라요")
                    .dnaFont(.screenTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("지난 여행과 원하는 여행을 알려주면, 그걸 바탕으로 추천해요. 기록이 없어도 취향부터 시작할 수 있어요.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.lg)
            DNABottomCTA {
                Button("시작하기") { viewModel.stage = .homeCountry }
                    .buttonStyle(.dnaPrimary)
                Text("로그인 없이 시작해요")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
    }
}

/// 실제 여행 사진 4~5장이 들어올 자리. 사진 출처 기록 전까지는 빈 타일만 둔다.
private struct PhotoCollagePlaceholder: View {
    var body: some View {
        Grid(horizontalSpacing: DNASpacing.xs, verticalSpacing: DNASpacing.xs) {
            GridRow {
                tile(symbol: "mountain.2")
                tile(symbol: "fork.knife")
            }
            GridRow {
                tile(symbol: "building.2")
                tile(symbol: "sun.max")
            }
        }
    }

    private func tile(symbol: String) -> some View {
        RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
            .fill(Color.dnaSurface2)
            .overlay {
                Image(systemName: symbol)
                    .font(.title)
                    .foregroundStyle(Color.dnaTextTertiary)
            }
            .frame(maxHeight: .infinity)
    }
}

// MARK: - ①-2 사는 나라

struct OnboardingHomeCountryView: View {
    let viewModel: OnboardingViewModel
    let dependencies: AppDependencies
    @Environment(SessionStore.self) private var session
    @State private var selectedCode: String
    @State private var isSearching = false
    @State private var isConfirming = false
    private let deviceRegion = OnboardingViewModel.deviceRegionCode

    init(viewModel: OnboardingViewModel, dependencies: AppDependencies) {
        self.viewModel = viewModel
        self.dependencies = dependencies
        _selectedCode = State(initialValue: viewModel.homeCountryCode ?? OnboardingViewModel.deviceRegionCode ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                trailingTitle: "나중에",
                onBack: { viewModel.goBack() },
                onTrailing: { confirm(nil) }
            )
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                Text("어느 나라에\n살고 계세요?")
                    .dnaFont(.screenTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("출발 공항 후보를 채우고, 이 나라 도시는 추천에서 기본으로 빼요. 추천할 때 넣을 수도 있어요.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.lg)

            VStack(spacing: DNASpacing.sm) {
                if !selectedCode.isEmpty {
                    HStack(spacing: DNASpacing.sm) {
                        Text(OnboardingFormat.flagEmoji(for: selectedCode)).font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(CountryCatalog.name(for: selectedCode))
                                .dnaFont(.sectionTitle)
                                .foregroundStyle(Color.dnaTextPrimary)
                            if selectedCode == deviceRegion {
                                Text("기기 지역 설정에서 가져왔어요")
                                    .dnaFont(.caption)
                                    .foregroundStyle(Color.dnaTextSecondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.dnaTextPrimary)
                    }
                    .padding(DNASpacing.md)
                    .background(Color.dnaRaised, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                            .strokeBorder(Color.dnaTextPrimary, lineWidth: 1.5)
                    }
                }
                Button {
                    isSearching = true
                } label: {
                    Label("다른 나라 검색", systemImage: "magnifyingglass")
                }
                .buttonStyle(.dnaSecondary)
                Text("설정에서 언제든 바꿀 수 있어요. 정하지 않으면 아무 나라도 빼지 않아요.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.lg)

            Spacer(minLength: 0)

            DNABottomCTA {
                Button("계속하기") { confirm(selectedCode) }
                    .buttonStyle(.dnaPrimary(isDisabled: selectedCode.isEmpty || isConfirming))
                    .disabled(selectedCode.isEmpty || isConfirming)
            }
        }
        .sheet(isPresented: $isSearching) {
            NavigationStack {
                CountrySelectionList(selectedCode: $selectedCode)
                    .padding(.top, DNASpacing.sm)
                    .background(AppCanvas())
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("완료") { isSearching = false }
                        }
                    }
            }
            .onChange(of: selectedCode) { isSearching = false }
        }
    }

    private func confirm(_ code: String?) {
        isConfirming = true
        Task {
            await viewModel.confirmHomeCountry(code, dependencies: dependencies, session: session)
            isConfirming = false
        }
    }
}

// MARK: - ② 지난 여행 불러오기

struct OnboardingEntryModeView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(progress: viewModel.progress, onBack: { viewModel.goBack() })
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                Text("지난 여행을\n어떻게 불러올까요?")
                    .dnaFont(.screenTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("지금 다 넣지 않아도 돼요. 나중에 언제든 추가할 수 있어요.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.lg)

            VStack(spacing: DNASpacing.sm) {
                EntryModeRow(
                    systemImage: "photo.on.rectangle.angled",
                    title: "사진첩에서 찾기",
                    subtitle: "사진의 위치·날짜로 후보를 찾고, 맞는지 직접 확인해요"
                ) { viewModel.selectEntryMode(.photoScan) }
                EntryModeRow(
                    systemImage: "pencil.line",
                    title: "직접 등록",
                    subtitle: "도시와 시기를 골라 넣어요 · 여행 등록과 같은 화면"
                ) { viewModel.selectEntryMode(.manual) }
                EntryModeRow(
                    systemImage: "heart",
                    title: "여행 기록 없이 취향부터",
                    subtitle: "원하는 여행만 골라서 시작해요"
                ) { viewModel.selectEntryMode(.preferencesOnly) }
            }
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.lg)
            Spacer(minLength: 0)
        }
    }
}

/// 세 경로를 같은 크기로 보여주는 행. 누르면 바로 다음 단계로 간다.
private struct EntryModeRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DNASpacing.md) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Color.dnaTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.dnaSurface2, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .dnaFont(.cardTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text(subtitle)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextTertiary)
            }
            .padding(DNASpacing.md)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(Color.dnaRaised, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                    .strokeBorder(Color.dnaDivider, lineWidth: 1)
            }
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
        .background(AppCanvas())
}

#Preview("OnboardingEntryModeView") {
    OnboardingEntryModeView(viewModel: OnboardingViewModel())
        .background(AppCanvas())
}
