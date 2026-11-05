import SwiftUI

// MARK: - 홈

/// 위에서부터: 헤더 → 상황에 맞는 카드 하나 → 할 일 → 내 여행 지문 → Wrapped 배너.
/// 기록이 없으면 "원하는 여행"과 "Add a Past Trip"로 시작한다. 없는 개인화 문구는 채우지 않는다.
struct HomeRedesignView: View {
    @Binding var selection: MainTab
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @Environment(AppRouter.self) private var router
    /// D-day 원 지름. 안의 숫자(20pt)와 같은 비율로 커진다.
    @ScaledMetric(relativeTo: .title3) private var dDayDiameter: CGFloat = 56
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
                    title: String(localized: "Share Preview"),
                    disclosure: String(localized: "Includes: trip count, count per concept · Excludes: dates, cities, companions, photos")
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
            .accessibilityLabel("Profile and settings")
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

    private func departureDateText(_ trip: Trip) -> String {
        guard let start = trip.legs.first?.startDate else { return "" }
        return start.formatted(.dateTime.month(.abbreviated).day())
    }

    private func photoBadge(_ text: LocalizedStringKey, dot: Bool) -> some View {
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
                HStack { photoBadge("Traveling", dot: true); Spacer() }
                Spacer()
            }
            .padding(12)
            bottomBar {
                VStack(alignment: .leading, spacing: 2) {
                    Text(HomeViewModel.placeName(trip))
                        .dnaFont(.heroTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text("\(trip.shortDateRangeKo) · \(trip.durationKo)")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            } actions: {
                NavigationLink {
                    DailyPhotoView(trip: trip)
                } label: {
                    Text("Today's Photo")
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
                    Text("View Trip")
                }
                .buttonStyle(.dnaDark)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .dnaGlass(in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: DNARadius.hero, style: .continuous))
    }

    /// 여행 카드 아래 막대. 큰 글자에서는 버튼 라벨이 줄바꿈되지 않게 제목과 버튼을 세로로 쌓는다.
    /// 장소·날짜 옆에 버튼을 둔다. 한 줄에 안 들어가면(영어·큰 글자) 버튼을 아래 줄로, 그래도 안 되면 세로로 쌓는다.
    private func bottomBar<Info: View, Actions: View>(
        @ViewBuilder info: () -> Info, @ViewBuilder actions: () -> Actions
    ) -> some View {
        let info = info(), actions = actions()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: DNASpacing.sm) { info; Spacer(minLength: 0); actions }
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                info
                HStack(spacing: DNASpacing.sm) { actions }
            }
            VStack(alignment: .leading, spacing: DNASpacing.sm) { info; actions }
        }
    }

    private func upcomingCard(_ trip: Trip, days: Int) -> some View {
        ZStack(alignment: .bottom) {
            heroPhoto(trip, height: 300)
                .overlay(Color.dnaData.opacity(0.12))
            VStack {
                HStack(alignment: .top) {
                    photoBadge("Upcoming trip", dot: false)
                    Spacer()
                    VStack(spacing: 0) {
                        Text("D-").dnaFont(size: 11, weight: .semibold)
                        Text("\(days)").dnaFont(size: 20, weight: .heavy)
                    }
                    .foregroundStyle(Color.dnaTextPrimary)
                    .frame(width: dDayDiameter, height: dDayDiameter)
                    .dnaGlass(in: Circle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("D-\(days)")
                }
                Spacer()
            }
            .padding(12)
            bottomBar {
                VStack(alignment: .leading, spacing: 2) {
                    Text(HomeViewModel.placeName(trip))
                        .dnaFont(.heroTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text("Departs \(departureDateText(trip)) · \(trip.durationKo)")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            } actions: {
                NavigationLink {
                    TripDetailView(tripID: trip.id)
                } label: {
                    Text("View Trip")
                }
                .buttonStyle(.dnaDark)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.dnaCanvas, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: DNARadius.hero, style: .continuous))
    }

    /// 추천 권유: "원하는 여행" 칩과 추천 탭으로 가는 버튼. 추천 결과는 만들지 않는다.
    private var invitationCard: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            DNAFlowLayout(spacing: 8) {
                ForEach(wantedChips, id: \.self) { concept in
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.dnaAction)
                            .accessibilityHidden(true)
                        Text(concept.label)
                    }
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(Color.dnaRaised, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.dnaDivider, lineWidth: 1))
                }
                Text("+ This time?")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .overlay(Capsule().strokeBorder(Color.dnaDivider, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            }
            Text("Ready to find your next destination?")
                .dnaFont(.heroTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("Pick just one thing you want to do on this trip and we'll find cities that fit.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                router.recommendationInputRequested = true
                selection = .recommendation
            } label: {
                Text("Get Recommendations")
            }
            .buttonStyle(.dnaPrimary)
            .accessibilityIdentifier("home.recommend")
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            // 컨셉 10개를 보여줘 무엇을 고르는지 알리고, 어느 칩을 눌러도 "원하는 여행"에서 칸을 고른다. 미리 고르지 않는다.
            let half = (TripConcept.displayOrder.count + 1) / 2
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach([Array(TripConcept.displayOrder.prefix(half)), Array(TripConcept.displayOrder.dropFirst(half))], id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(row, id: \.self) { concept in
                                NavigationLink {
                                    WantedTripsSettingsView()
                                } label: {
                                    Text(concept.label)
                                        .dnaFont(.caption)
                                        .foregroundStyle(Color.dnaTextPrimary)
                                        .padding(.horizontal, 14)
                                        .frame(minHeight: 36)
                                        .background(Color.dnaRaised, in: Capsule())
                                        .overlay(Capsule().strokeBorder(Color.dnaDivider, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Start by choosing the trips you want")
                    .dnaFont(.heroTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("Sort them into Most wanted · Like · Nice to have. Anything you leave out stays in \"Not sure or don't want.\"")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                NavigationLink {
                    WantedTripsSettingsView()
                } label: {
                    Text("Choose Wanted Trips")
                        .dnaFont(.button)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Color.dnaAction, in: Capsule())
                }
                .accessibilityIdentifier("home.pickWanted")
                Button {
                    dismissedWantedCard = true
                } label: {
                    Text("Later").frame(minHeight: 48)
                }
                .buttonStyle(.dnaSecondary(onSheet: true, fullWidth: false))
            }
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.hero, style: .continuous))
    }

    // MARK: 다녀온 여행 남기기 (기록이 없을 때)

    private var recordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a Past Trip")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            HStack(spacing: 8) {
                Button {
                    showingPhotoScan = true
                } label: {
                    recordTile(icon: "photo.on.rectangle", title: "Find in Photos", subtitle: nil, dark: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.scanPhotos")
                Button {
                    showingRegistration = true
                } label: {
                    recordTile(icon: "plus", title: "Add Manually", subtitle: nil, dark: false)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.registerTrip")
            }
            Text("Photos and locations are analyzed on your device only.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private func recordTile(icon: String, title: LocalizedStringKey, subtitle: String?, dark: Bool) -> some View {
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
                    Text("Your trip to \(trip.placeTitleKo) has ended")
                        .dnaFont(.cardTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text("Share what you liked and didn't, and we'll use it for your next recommendations")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 8) {
                    Button {
                        router.evaluationRequest = EvaluationRequest(tripID: trip.id)
                    } label: {
                        Text("Rate Trip")
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
                        Text("Skip")
                            .padding(.horizontal, DNASpacing.sm)
                    }
                    .buttonStyle(.dnaGhost)
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
                            Text("My Travel Fingerprint")
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
                    .accessibilityLabel("Share fingerprint")
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
                Text("My Travel Fingerprint")
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
                    Text("Each trip you add fills in another box")
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
                    Text("View Fingerprint Details").dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
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
                bannerLabel(kicker: "Wrapped", title: "\(String(year)) Wrapped is open", subtitle: nil, showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.wrapped")
        case .pastAvailable(let year):
            NavigationLink { WrappedView(year: year) } label: {
                bannerLabel(
                    kicker: "Past Wrapped",
                    title: "View \(String(year)) Wrapped Again",
                    subtitle: "This year's Wrapped opens on December 15",
                    showsChevron: true,
                    dark: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.wrapped")
        case .notYet:
            bannerLabel(kicker: "Wrapped", title: "This year's Wrapped opens December 15", subtitle: nil, showsChevron: false)
                .accessibilityIdentifier("home.wrapped")
        }
    }

    private func bannerLabel(kicker: LocalizedStringKey, title: LocalizedStringKey, subtitle: LocalizedStringKey?, showsChevron: Bool, dark: Bool = false) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: -8) {
                ForEach([Color.dnaData, Color.dnaDataMuted, Color.dnaDataFaint], id: \.self) { color in
                    Circle().fill(color).frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(dark ? Color.dnaControlDark : Color.dnaSurface1, lineWidth: 2))
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(kicker).dnaFont(.caption).foregroundStyle(dark ? Color.white.opacity(0.7) : Color.dnaTextSecondary)
                Text(title).dnaFont(.cardTitle).foregroundStyle(dark ? Color.white : Color.dnaTextPrimary)
                if let subtitle {
                    Text(subtitle).dnaFont(.caption).foregroundStyle(dark ? Color.white.opacity(0.7) : Color.dnaTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .dnaFont(size: 13, weight: .semibold)
                    .foregroundStyle(dark ? Color.white.opacity(0.7) : Color.dnaTextTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(DNASpacing.md)
        .background(dark ? Color.dnaControlDark : Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
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
                Text("Saved Recommendation")
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
                    Text("Details")
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
