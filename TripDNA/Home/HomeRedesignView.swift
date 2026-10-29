import SwiftUI

// MARK: - 홈

/// 위에서부터: 헤더 → 상황에 맞는 카드 하나 → 할 일 → 내 여행 지문 → Wrapped 배너.
/// 기록이 없으면 "원하는 여행"과 "다녀온 여행 남기기"로 시작한다. 없는 개인화 문구는 채우지 않는다.
struct HomeRedesignView: View {
    @Binding var selection: MainTab
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var viewModel = HomeViewModel()
    @State private var showingProfile = false
    @State private var showingRegistration = false
    @State private var showingPhotoScan = false
    @State private var openedCity: SavedCity?
    @State private var showingFingerprintShare = false
    @State private var dismissedWantedCard = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if viewModel.isLoading, viewModel.trips.isEmpty {
                    ProgressView()
                        .tint(Color.dnaTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                } else {
                    topCard
                    if viewModel.trips.isEmpty { recordSection }
                    todoCard
                    fingerprintSection
                    wrappedBanner
                }
            }
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.xs)
            .padding(.bottom, DNASpacing.xl)
        }
        .dnaTopScrollBlur()
        .background(Color.dnaCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingProfile) { SettingsRootView() }
        .sheet(isPresented: $showingRegistration, onDismiss: reload) {
            NavigationStack { TripRegistrationView(prefilledCountryCode: nil) }
        }
        // 사진첩 훑기는 온보딩의 사진 단계를 새 상태로 재사용한다. 온보딩 진행 상태와 완료 여부는 건드리지 않는다.
        .sheet(isPresented: $showingPhotoScan, onDismiss: reload) { HomePhotoScanSheet() }
        .sheet(item: $openedCity) { city in
            NavigationStack {
                CityDetailView(card: city.card, conditionSummary: city.conditionSummary, savedAt: city.savedAt)
            }
        }
        .sheet(isPresented: $showingFingerprintShare) {
            if let fingerprint = viewModel.fingerprint {
                ShareCardSheet(
                    kind: .fingerprint,
                    title: "공유 미리보기",
                    disclosure: "포함: 여행 수, 컨셉별 횟수 · 빠짐: 날짜, 도시, 동행, 사진"
                ) { _ in
                    FingerprintShareCard(fingerprint: fingerprint)
                }
            }
        }
        .task { await viewModel.load(dependencies) }
        .refreshable { await viewModel.load(dependencies) }
        .onChange(of: router.evaluationRequest) {
            if router.evaluationRequest == nil { reload() }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    private func reload() { Task { await viewModel.load(dependencies) } }

    // MARK: 헤더

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.header.status)
                    .dnaFont(size: 13, weight: .semibold)
                    .foregroundStyle(Color.dnaTextSecondary)
                Text(viewModel.header.title)
                    .dnaFont(.screenTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DNASpacing.sm)
            Button {
                showingProfile = true
            } label: {
                Image(systemName: "person")
                    .dnaFont(size: 18, weight: .semibold)
                    .foregroundStyle(Color.dnaTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.dnaCanvas, in: Circle())
                    .overlay(Circle().strokeBorder(Color.dnaDivider, lineWidth: 1))
            }
            .accessibilityLabel("프로필과 설정")
            .accessibilityIdentifier("home.profile")
        }
    }

    // MARK: 상단 카드

    @ViewBuilder
    private var topCard: some View {
        switch viewModel.topCard {
        case .active(let id):
            if let trip = viewModel.trip(id: id) { activeCard(trip) }
        case .upcoming(let id, let days):
            if let trip = viewModel.trip(id: id) { upcomingCard(trip, days: days) }
        case .recommendations(let cities):
            HomeRecommendationCarousel(cities: cities) { openedCity = $0 }
        case .invitation:
            invitationCard
        case .firstUse:
            if !dismissedWantedCard { wantedChoiceCard }
        }
    }

    private func heroPhoto(_ trip: Trip, height: CGFloat) -> some View {
        ZStack {
            Color.dnaSurface2
            if let path = viewModel.coverPath(for: trip) {
                TripPhotoImage(storagePath: path)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func photoBadge(_ text: String, dot: Bool) -> some View {
        HStack(spacing: 6) {
            if dot { Circle().fill(Color.dnaAction).frame(width: 7, height: 7) }
            Text(text).dnaFont(.caption).foregroundStyle(Color.dnaTextPrimary)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .dnaGlass(in: Capsule())
    }

    private func activeCard(_ trip: Trip) -> some View {
        ZStack(alignment: .bottom) {
            heroPhoto(trip, height: 340)
            VStack {
                HStack { photoBadge("여행 중", dot: true); Spacer() }
                Spacer()
            }
            .padding(12)
            HStack(alignment: .center, spacing: DNASpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(HomeViewModel.placeName(trip))
                        .dnaFont(.heroTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text("\(trip.shortDateRangeKo) · \(trip.durationKo)")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                Spacer(minLength: 0)
                NavigationLink {
                    DailyPhotoView(trip: trip)
                } label: {
                    Text("오늘의 한 장")
                        .dnaFont(.button)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Color.dnaAction, in: Capsule())
                }
                .accessibilityIdentifier("home.dailyPhoto")
                NavigationLink {
                    TripDetailView(tripID: trip.id)
                } label: {
                    Text("여행 보기")
                        .dnaFont(.button)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .dnaGlass(in: Capsule())
                }
            }
            .padding(14)
            .dnaGlass(in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: DNARadius.hero, style: .continuous))
    }

    private func upcomingCard(_ trip: Trip, days: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            heroPhoto(trip, height: 260)
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack {
                HStack { photoBadge("다가오는 여행", dot: false); Spacer() }
                Spacer()
            }
            .padding(12)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("D-\(days)")
                        .dnaFont(size: 44, weight: .heavy)
                    Text(HomeViewModel.placeName(trip))
                        .dnaFont(.heroTitle)
                    Text("\(trip.shortDateRangeKo.components(separatedBy: " – ").first ?? "") 출발 · \(trip.durationKo)")
                        .dnaFont(.caption)
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                NavigationLink {
                    TripDetailView(tripID: trip.id)
                } label: {
                    Text("여행 보기")
                        .dnaFont(.button)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .dnaGlass(in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: DNARadius.hero, style: .continuous))
    }

    /// 추천 권유: "원하는 여행" 칩과 추천 탭으로 가는 버튼. 추천 결과는 만들지 않는다.
    private var invitationCard: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            DNAFlowLayout(spacing: 8) {
                ForEach(wantedChips, id: \.self) { concept in
                    Text(concept.labelKo)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(Color.dnaRaised, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.dnaDivider, lineWidth: 1))
                }
                Text("+ 이번엔?")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .overlay(Capsule().strokeBorder(Color.dnaDivider, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            }
            Spacer(minLength: DNASpacing.sm)
            Text("다음 여행지를 찾아볼까요?")
                .dnaFont(.heroTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("여행 컨셉을 고르면 조건에 맞는 도시를 골라 이유와 함께 보여줘요.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                router.recommendationInputRequested = true
                selection = .recommendation
            } label: {
                Text("추천 받기")
            }
            .buttonStyle(.dnaPrimary)
            .accessibilityIdentifier("home.recommend")
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.hero, style: .continuous))
    }

    /// 칩은 사용자가 "가장 원해요"·"좋아요"로 둔 컨셉이다. 최대 4개.
    private var wantedChips: [TripConcept] {
        guard let tiers = viewModel.tiers else { return [] }
        return Array((tiers.tier1 + tiers.tier2).prefix(4))
    }

    /// 첫 사용: "원하는 여행"을 고르게 한다. 고르지 않아도 다른 것을 쓸 수 있다.
    private var wantedChoiceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                Text("원하는 여행부터 골라주세요")
                    .dnaFont(.heroTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("가장 원해요 · 좋아요 · 있으면 좋아요로 골라요. 안 고른 건 \"모르겠거나 원하지 않아요\"로 둬요.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                NavigationLink {
                    WantedTripsSettingsView()
                } label: {
                    Text("원하는 여행 고르기")
                        .dnaFont(.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.dnaAction, in: Capsule())
                }
                .accessibilityIdentifier("home.pickWanted")
                Button {
                    dismissedWantedCard = true
                } label: {
                    Text("나중에")
                        .dnaFont(.button)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 48)
                        .overlay(Capsule().strokeBorder(Color.dnaDivider, lineWidth: 1))
                }
            }
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.hero, style: .continuous))
    }

    // MARK: 다녀온 여행 남기기 (기록이 없을 때)

    private var recordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("다녀온 여행 남기기")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            HStack(spacing: 8) {
                Button {
                    showingPhotoScan = true
                } label: {
                    recordTile(icon: "photo.on.rectangle", title: "사진첩에서 찾기", subtitle: nil, dark: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.scanPhotos")
                Button {
                    showingRegistration = true
                } label: {
                    recordTile(icon: "plus", title: "직접 등록", subtitle: nil, dark: false)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.registerTrip")
            }
            Text("사진과 위치는 기기 안에서만 분석해요.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private func recordTile(icon: String, title: String, subtitle: String?, dark: Bool) -> some View {
        VStack(alignment: .leading) {
            Image(systemName: icon).dnaFont(size: 20, weight: .semibold)
            Spacer(minLength: 0)
            Text(title).dnaFont(.cardTitle)
            if let subtitle { Text(subtitle).dnaFont(size: 11) }
        }
        .foregroundStyle(dark ? Color.dnaSelectedForeground : Color.dnaTextPrimary)
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(
            dark ? Color.dnaSelectedBackground : Color.dnaSurface1,
            in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
        )
    }

    // MARK: 할 일

    @ViewBuilder
    private var todoCard: some View {
        if let trip = viewModel.todoTrip {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(trip.placeTitleKo) 여행이 끝났어요")
                        .dnaFont(.cardTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text("좋았던 점과 아쉬웠던 점을 남기면 다음 추천에 써요")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    Button {
                        router.evaluationRequest = EvaluationRequest(tripID: trip.id)
                    } label: {
                        Text("평가하기")
                            .dnaFont(.button)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .background(Color.dnaAction, in: Capsule())
                    }
                    .accessibilityIdentifier("home.evaluate")
                    Button {
                        Task { await viewModel.skipEvaluation(trip, dependencies: dependencies, userID: session.userID) }
                    } label: {
                        Text("건너뛰기")
                            .dnaFont(.button)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .padding(.horizontal, 18)
                            .frame(minHeight: 44)
                            .overlay(Capsule().strokeBorder(Color.dnaDivider, lineWidth: 1))
                    }
                }
            }
            .padding(DNASpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        }
    }

    // MARK: 내 여행 지문

    @ViewBuilder
    private var fingerprintSection: some View {
        if let fingerprint = viewModel.fingerprint {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                HStack(alignment: .top, spacing: DNASpacing.xs) {
                    NavigationLink {
                        FingerprintDetailView()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("내 여행 지문")
                                .dnaFont(.caption)
                                .foregroundStyle(Color.dnaTextSecondary)
                            Text(fingerprint.homeHeadlineKo)
                                .dnaFont(.cardTitle)
                                .foregroundStyle(Color.dnaTextPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.fingerprint")
                    Button {
                        showingFingerprintShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .dnaFont(size: 16, weight: .semibold)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("지문 공유")
                    .accessibilityIdentifier("home.fingerprintShare")
                }
                NavigationLink {
                    FingerprintDetailView()
                } label: {
                    ConceptBlockRows(fingerprint: fingerprint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(DNASpacing.md)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("내 여행 지문")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: DNARadius.cell, style: .continuous)
                                .strokeBorder(Color.dnaTextTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                                .frame(width: 22, height: 22)
                        }
                    }
                    .accessibilityHidden(true)
                    Text("여행을 남기면 한 칸씩 채워져요")
                        .dnaFont(size: 13)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: DNARadius.card - 2, style: .continuous)
                        .strokeBorder(Color.dnaDivider, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                )
            }
            if !viewModel.trips.isEmpty {
                NavigationLink {
                    FingerprintDetailView()
                } label: {
                    Text("지문 자세히 보기").dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
                }
            }
        }
    }

    // MARK: Wrapped 배너

    @ViewBuilder
    private var wrappedBanner: some View {
        switch viewModel.banner {
        case .open(let year):
            NavigationLink { WrappedView(year: year) } label: {
                bannerLabel(kicker: "Wrapped", title: "\(year) Wrapped가 열렸어요", subtitle: nil, showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.wrapped")
        case .pastAvailable(let year):
            NavigationLink { WrappedView(year: year) } label: {
                bannerLabel(
                    kicker: "지난 Wrapped",
                    title: "\(year) Wrapped 다시 보기",
                    subtitle: "올해 Wrapped는 12월 15일에 열려요",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.wrapped")
        case .notYet:
            bannerLabel(kicker: "Wrapped", title: "12월 15일에 올해 Wrapped가 열려요", subtitle: nil, showsChevron: false)
                .accessibilityIdentifier("home.wrapped")
        }
    }

    private func bannerLabel(kicker: String, title: String, subtitle: String?, showsChevron: Bool) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: -8) {
                ForEach([Color.dnaData, Color.dnaDataMuted, Color.dnaDataFaint], id: \.self) { color in
                    Circle().fill(color).frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(Color.dnaSurface1, lineWidth: 2))
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(kicker).dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
                Text(title).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
                if let subtitle {
                    Text(subtitle).dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .dnaFont(size: 13, weight: .semibold)
                    .foregroundStyle(Color.dnaTextTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(DNASpacing.md)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        .contentShape(Rectangle())
    }
}

// MARK: - 추천 있음

/// 저장한 추천 최대 3장을 옆으로 넘긴다. "1/3" 같은 숫자 대신 점으로 위치를 알린다.
struct HomeRecommendationCarousel: View {
    let cities: [SavedCity]
    let onOpen: (SavedCity) -> Void
    @State private var page = 0

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $page) {
                ForEach(Array(cities.enumerated()), id: \.element.id) { index, city in
                    card(city).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 260)
            if cities.count > 1 {
                HStack(spacing: 6) {
                    ForEach(cities.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Color.dnaTextPrimary : Color.dnaDivider)
                            .frame(width: index == page ? 18 : 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }

    private func card(_ city: SavedCity) -> some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(hex: 0x0F7B73), Color(hex: 0x0A4F4A)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 4) {
                Text("저장한 추천")
                    .dnaFont(.caption)
                    .opacity(0.9)
                Text(city.card.cityName)
                    .dnaFont(size: 30, weight: .heavy)
                Text("\(CountryFlag.emoji(for: city.card.country)) \(CountryCatalog.name(for: city.card.country))")
            }
            .foregroundStyle(.white)
            .padding(18)
            HStack {
                Spacer()
                Button { onOpen(city) } label: {
                    Text("자세히")
                        .dnaFont(.button)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .dnaGlass(in: Capsule())
                }
            }
            .padding(14)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .clipShape(RoundedRectangle(cornerRadius: DNARadius.hero, style: .continuous))
        .padding(.horizontal, 1)
    }
}

#Preview("HomeRedesignView") {
    @Previewable @State var selection = MainTab.home
    NavigationStack {
        HomeRedesignView(selection: $selection)
    }
    .previewWithAppEnvironment { session in
        session.onboardingPhase = .completed
    }
}
