import SwiftUI

struct HomeView: View {
    @Binding var selection: MainTab
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @State private var viewModel = HomeViewModel()
    @State private var showingProfile = false

    private var showsEmptyFingerprintCTA: Bool {
        !viewModel.isLoading && viewModel.vector == nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.lg) {
                VStack(alignment: .leading, spacing: DNASpacing.sm) {
                    header
                    DNAHeaderDivider()
                }
                if viewModel.isLoading, viewModel.vector == nil {
                    LoadingView().frame(height: 280)
                } else if let vector = viewModel.vector {
                    fingerprintSection(vector)
                    primaryActionSection
                    recommendationSection
                    if viewModel.isSeasonOpen {
                        wrappedBanner
                    } else {
                        debugWrappedPreviewLink
                    }
                } else {
                    emptyFingerprintState
                }
            }
            .padding(DNASpacing.lg)
        }
        .dnaTopScrollBlur()
        .dnaBackground()
        .safeAreaInset(edge: .bottom) {
            if showsEmptyFingerprintCTA {
                DNABottomCTA {
                    Button {
                        selection = .trips
                    } label: {
                        Text("새 여행 등록")
                    }
                    .buttonStyle(.dnaPrimary)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingProfile) {
            ProfileSheet()
        }
        .task {
            await viewModel.load(dependencies)
        }
        .refreshable {
            await viewModel.load(dependencies)
        }
    }

    // MARK: - 상단 바 (3A-1)

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: "좋은 아침이에요"
        case 12..<18: "좋은 오후예요"
        case 18..<23: "좋은 저녁이에요"
        default: "늦은 밤이에요"
        }
    }

    private var header: some View {
        DNAScreenHeader(title: greeting, subtitle: "오늘의 여행 취향을 확인해보세요") {
            Button {
                showingProfile = true
            } label: {
                DNACircleIcon(systemImage: "person.fill")
            }
            .accessibilityLabel("프로필")
        }
    }

    // MARK: - 5축 미니 지문 카드 (3A-2)

    private func fingerprintSection(_ vector: UserTasteVector) -> some View {
        NavigationLink {
            FingerprintDetailView()
        } label: {
            SectionCard {
                VStack(spacing: DNASpacing.sm) {
                    HStack {
                        Text("내 취향 지문")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("자세히 보기 ›")
                            .font(.caption)
                            .foregroundStyle(Color.dnaTeal)
                    }
                    FingerprintRadarView(axes: vector.axes, confidence: vector.confidence)
                    Text(AxisNarrative.representativeSentenceKo(axes: vector.axes, confidence: vector.confidence))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 상태 주행동 카드 (3A-3)

    private var primaryActionSection: some View {
        Group {
            switch viewModel.primaryAction {
            case .evaluate(let tripID, let title):
                NavigationLink {
                    TripDetailView(tripID: tripID)
                } label: {
                    primaryActionCard(
                        icon: "checkmark.seal.fill",
                        title: "\(title) 여행을 평가해 주세요",
                        subtitle: "평가하면 지문이 더 선명해져요"
                    )
                }
                .buttonStyle(.plain)
            case .dailyPhoto(let tripID, let title):
                NavigationLink {
                    TripDetailView(tripID: tripID)
                } label: {
                    primaryActionCard(
                        icon: "camera.fill",
                        title: "오늘의 한 장 고르기",
                        subtitle: "\(title) 여행 중이에요"
                    )
                }
                .buttonStyle(.plain)
            case .activeTrip(let tripID, let title):
                NavigationLink {
                    TripDetailView(tripID: tripID)
                } label: {
                    primaryActionCard(
                        icon: "checkmark.circle.fill",
                        title: "오늘의 한 장을 남겼어요",
                        subtitle: "\(title) · 사진을 바꾸려면 탭하세요"
                    )
                }
                .buttonStyle(.plain)
            case .upcoming(let title):
                Button {
                    selection = .trips
                } label: {
                    primaryActionCard(
                        icon: "calendar",
                        title: "여행 일정 확인",
                        subtitle: "\(title) 여행이 다가오고 있어요"
                    )
                }
                .buttonStyle(.plain)
            case .registerFirstTrip:
                Button {
                    selection = .trips
                } label: {
                    primaryActionCard(
                        icon: "plus.circle.fill",
                        title: "새 여행 등록",
                        subtitle: "여행이 쌓일수록 지문이 정교해져요"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 크고 명확한 단일 CTA 카드. 한 화면 주 행동 하나(코랄) 원칙의 주인공.
    private func primaryActionCard(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: DNASpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.dnaCoral, Color.dnaCoral.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.dnaCoral)
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaCoral.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.dnaCoral.opacity(0.16), radius: 18, y: 8)
    }

    // MARK: - 추천 1장 (3A-4)

    private var recommendationSection: some View {
        Group {
            if let best = viewModel.bestMatch {
                Button {
                    selection = .recommendation
                } label: {
                    SectionCard(title: "오늘의 추천") {
                        VStack(alignment: .leading, spacing: DNASpacing.sm) {
                            HStack {
                                SlotChip(slot: best.slot)
                                Spacer()
                                ScoreBadge(score: best.matchScore)
                            }
                            HStack {
                                Text(CountryCatalog.name(for: best.countryCode))
                                    .font(.title3.bold())
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.dnaSlate)
                            }
                            FitBadgesRow(badges: best.fitBadges)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Wrapped 배너 (3A-5, 시즌 한정)

    private var wrappedBanner: some View {
        NavigationLink {
            WrappedView(forcePreview: false)
        } label: {
            HStack(spacing: DNASpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("올해의 여행 지문")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("올해의 여행을 한 편의 이야기로 정리했어요")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer(minLength: 0)
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            .padding(DNASpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.dnaIndigo, Color.dnaCoral.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.dnaIndigo.opacity(0.3), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var debugWrappedPreviewLink: some View {
        #if DEBUG
        NavigationLink {
            WrappedView(forcePreview: true)
        } label: {
            HStack {
                Image(systemName: "sparkles.rectangle.stack")
                Text("Wrapped 미리보기 (디버그용)")
                    .font(.caption)
                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(Color.dnaSlate)
            .padding(DNASpacing.sm)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: DNARadius.control - 4))
        }
        .buttonStyle(.plain)
        #endif
    }

    // MARK: - 지문 없음 상태 (3A-6)

    private var emptyFingerprintState: some View {
        EmptyStateView(
            systemImage: "touchid",
            title: "아직 지문이 없어요",
            message: "여행을 등록하면 첫 지문이 만들어져요."
        )
        .frame(height: 240)
    }
}

// MARK: - 프로필 시트 (3A-7)

struct ProfileSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var showingHomeCountryPicker = false
    @State private var showingSignOutDialog = false
    @State private var showingDeleteDialog = false
    @State private var isDeletingAccount = false
    @State private var deletionError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("계정") {
                    LabeledContent("사용자 ID", value: String(session.userID.prefix(8)))
                        .foregroundStyle(.white)
                }
                .listRowBackground(Color.dnaSurface)

                Section {
                    Button {
                        showingHomeCountryPicker = true
                    } label: {
                        LabeledContent(
                            "거주 국가",
                            value: dependencies.homeCountryCode.map { CountryCatalog.name(for: $0) } ?? "설정 안 됨"
                        )
                    }
                    .foregroundStyle(.white)
                } footer: {
                    Text("거주 국가는 여행지 추천에서 자동으로 제외돼요.")
                        .foregroundStyle(Color.dnaSlate)
                }
                .listRowBackground(Color.dnaSurface)

                Section {
                    if session.isAuthenticated {
                        Button(role: .destructive) {
                            showingSignOutDialog = true
                        } label: {
                            Text("로그아웃")
                        }
                    }
                    Button(role: .destructive) {
                        showingDeleteDialog = true
                    } label: {
                        Text("계정 및 데이터 삭제")
                    }
                    .disabled(isDeletingAccount)
                } footer: {
                    Text("기기에 저장된 여행·지문·추천 기록과 사진을 삭제해요. 다른 기기에서 복구할 수 없어요.")
                        .foregroundStyle(Color.dnaSlate)
                }
                .listRowBackground(Color.dnaSurface)
            }
            .scrollContentBackground(.hidden)
            .background(AuroraBackground())
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showingHomeCountryPicker) {
                HomeCountryPickerSheet()
            }
            .confirmationDialog(
                "로그아웃할까요?",
                isPresented: $showingSignOutDialog,
                titleVisibility: .visible
            ) {
                Button("로그아웃", role: .destructive) {
                    session.signOut()
                    dismiss()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 기기의 기록은 유지돼요. 같은 Apple 계정으로 다시 로그인할 수 있어요.")
            }
            .confirmationDialog(
                "계정과 모든 데이터를 삭제할까요?",
                isPresented: $showingDeleteDialog,
                titleVisibility: .visible
            ) {
                Button("모두 삭제", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        defer { isDeletingAccount = false }
                        do {
                            try await dependencies.deleteAccount(session: session)
                            dismiss()
                        } catch {
                            deletionError = error.localizedDescription
                        }
                    }
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("기기에 저장된 여행·평가·지문·추천 반응·사진이 영구 삭제돼요.")
            }
            .alert("삭제를 완료하지 못했어요", isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )) {
                Button("확인", role: .cancel) { deletionError = nil }
            } message: {
                Text(deletionError ?? "다시 시도해 주세요.")
            }
        }
    }
}

private struct HomeCountryPickerSheet: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCode: String

    init() {
        _selectedCode = State(initialValue: "KR")
    }

    var body: some View {
        NavigationStack {
            CountrySelectionList(selectedCode: $selectedCode)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            Task {
                                await dependencies.setHomeCountryCode(selectedCode)
                                dismiss()
                            }
                        }
                    }
                }
        }
        .task {
            selectedCode = dependencies.homeCountryCode ?? Locale.current.region?.identifier.uppercased() ?? "KR"
        }
    }
}

#Preview("HomeView") {
    @Previewable @State var selection = MainTab.home
    NavigationStack {
        HomeView(selection: $selection)
    }
    .previewWithAppEnvironment { session in
        session.onboardingPhase = .completed
        session.isAuthenticated = true
    }
}
