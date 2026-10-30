import SwiftUI

/// 여행 상세. 지난 여행은 대표 사진·도시별 평가·하루 한 장·일정을, 여행 중은 오늘의 한 장을 앞세운다.
struct TripDetailView: View {
    let tripID: String
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TripDetailViewModel()
    @State private var showingCoverPicker = false
    @State private var showingEvaluation = false
    @State private var showingEdit = false
    @State private var showingShare = false
    @State private var confirmingEnd = false
    @State private var confirmingTripDeletion = false
    @State private var confirmingEvaluationDeletion = false
    @State private var deletionError: String?
    @State private var photoDayEdit: PhotoDayEdit?
    @State private var showingConceptEdit = false
    @State private var editPrimary: TripConcept?
    @State private var editSecondary: [TripConcept] = []

    private struct PhotoDayEdit: Identifiable, Hashable {
        let dayIndex: Int
        var id: Int { dayIndex }
    }

    var body: some View {
        Group {
            if let trip = viewModel.trip {
                content(for: trip)
            } else if viewModel.isLoading {
                LoadingView()
            } else {
                EmptyStateView(
                    systemImage: "questionmark.folder",
                    title: "여행을 찾을 수 없어요",
                    message: "삭제되었거나 존재하지 않는 여행이에요.",
                    actionTitle: "돌아가기",
                    action: { dismiss() }
                )
            }
        }
        .background(AppCanvas())
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if let trip = viewModel.trip {
                ToolbarItem(placement: .topBarTrailing) {
                    if isPast(trip) {
                        Button { showingShare = true } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("공유")
                        .accessibilityIdentifier("trip.sharePreview")
                    }
                }
                // 공유와 더 보기를 한 알약에 묶지 않고 따로 둔다.
                if #available(iOS 26.0, *), isPast(trip) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("여행 정보 수정") { showingEdit = true }
                        if trip.status == .evaluated || trip.status == .skippedEvaluation {
                            Button("평가 고치기") { showingEvaluation = true }
                            Button("평가 삭제", role: .destructive) { confirmingEvaluationDeletion = true }
                        }
                        Button("여행 삭제", role: .destructive) { confirmingTripDeletion = true }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("여행 관리")
                }
            }
        }
        .onAppear {
            // 첫 진입과 DailyPhotoView 등에서 돌아온 경우 모두 여기서 읽는다.
            Task { await viewModel.load(tripID: tripID, dependencies: dependencies) }
        }
        .sheet(isPresented: $showingCoverPicker) {
            CoverPhotoPickerSheet(trip: viewModel.trip, photos: viewModel.photos) { path in
                Task { await viewModel.setCoverPhoto(path, dependencies: dependencies) }
            }
        }
        .sheet(isPresented: $showingShare) {
            if let trip = viewModel.trip {
                ShareCardSheet(kind: .trip, title: "공유 미리보기", disclosure: "포함: 여행 컨셉, 기간, 내 랭킹 · 빠짐: 날짜, 도시, 동행, 사진", allowsDestinationNames: true) { showsDestinationNames in
                    TripShareCard(summary: TripShareSummary(trip: trip), showsDestinationNames: showsDestinationNames)
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let trip = viewModel.trip {
                NavigationStack {
                    TripRegistrationView(editing: trip) {
                        Task { await viewModel.load(tripID: tripID, dependencies: dependencies) }
                    }
                }
            }
        }
        .sheet(isPresented: $showingConceptEdit, onDismiss: saveEditedConcepts) {
            TripConceptEditSheet(
                primary: $editPrimary,
                secondary: $editSecondary,
                secondaryTitle: viewModel.trip.map(isPast) == false ? "함께 하고 싶은 것" : "함께 한 것"
            )
        }
        .fullScreenCover(isPresented: $showingEvaluation, onDismiss: {
            Task { await viewModel.load(tripID: tripID, dependencies: dependencies) }
        }) {
            EvaluationView(tripID: tripID)
        }
        .navigationDestination(item: $photoDayEdit) { edit in
            if let trip = viewModel.trip {
                DailyPhotoView(trip: trip, dayIndex: edit.dayIndex)
            }
        }
        .confirmationDialog("여행을 끝낼까요?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("여행 끝내기", role: .destructive) {
                Task { await viewModel.end(dependencies: dependencies) }
            }
            Button("계속 여행하기", role: .cancel) {}
        } message: {
            Text("끝내면 도시별 평가를 남길 수 있어요.")
        }
        .confirmationDialog("이 여행을 삭제할까요?", isPresented: $confirmingTripDeletion, titleVisibility: .visible) {
            Button("여행과 사진 삭제", role: .destructive) {
                Task {
                    do {
                        try await dependencies.deleteTrip(tripID: tripID, userID: session.userID)
                        dismiss()
                    } catch { deletionError = error.localizedDescription }
                }
            }
        } message: {
            Text("여행, 평가, 이 여행에 저장한 사진과 랭킹 기록이 삭제돼요.")
        }
        .confirmationDialog("평가를 삭제할까요?", isPresented: $confirmingEvaluationDeletion, titleVisibility: .visible) {
            Button("평가 삭제", role: .destructive) {
                Task {
                    do {
                        try await dependencies.deleteEvaluation(tripID: tripID, userID: session.userID)
                        await viewModel.load(tripID: tripID, dependencies: dependencies)
                    } catch { deletionError = error.localizedDescription }
                }
            }
        } message: {
            Text("여행과 사진은 남고, 평가는 지문과 랭킹에서 제외돼요.")
        }
        .alert("삭제하지 못했어요", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("확인", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "다시 시도해 주세요.")
        }
    }

    private func isPast(_ trip: Trip) -> Bool {
        switch trip.status {
        case .ended, .evaluated, .skippedEvaluation: true
        case .planned, .active: false
        }
    }

    // MARK: - 본문

    private func content(for trip: Trip) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if trip.status != .planned {
                    hero(trip)
                }
                VStack(alignment: .leading, spacing: DNASpacing.lg) {
                    header(trip)
                    switch trip.status {
                    case .planned:
                        plannedActions(trip)
                    case .active:
                        activeActions
                    case .ended, .evaluated, .skippedEvaluation:
                        conceptRow(trip)
                        if let rank = trip.rankPosition { rankRow(rank) }
                        cityReviewsSection(trip)
                    }
                    if trip.status != .planned {
                        dailyPhotosSection(trip)
                    }
                    legsSection(trip)
                    if trip.status == .planned && dependencies.affiliateActivitiesEnabled {
                        activitiesSection(trip)
                    }
                    if trip.purpose == .obligation {
                        Text("출장은 여행 컨셉 없이 방문 기록만 남겨요. 내 여행 지문에는 세지 않아요.")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                }
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.vertical, DNASpacing.lg)
            }
        }
        .ignoresSafeArea(edges: trip.status == .planned ? [] : .top)
        .refreshable { await viewModel.load(tripID: tripID, dependencies: dependencies) }
    }

    /// 대표 사진 → 직접 고른 첫 하루 한 장 → 빈 자리 순서로 보여준다. 사진 위 글자는 흰색이다.
    private func hero(_ trip: Trip) -> some View {
        let path = trip.displayCoverPath(photos: viewModel.photos)
        return ZStack(alignment: .bottomLeading) {
            if let path {
                TripPhotoImage(storagePath: path)
            } else {
                Color.dnaSurface2
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(Color.dnaTextTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if trip.status == .active {
                LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                Text("여행 중 · \(viewModel.currentDayIndex)일째 / \(viewModel.totalDays)일")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.white)
                    .padding(DNASpacing.gutter)
            } else {
                Button { showingCoverPicker = true } label: {
                    Text("사진 바꾸기")
                        .dnaFont(.caption)
                        .foregroundStyle(path == nil ? Color.dnaTextPrimary : Color.white)
                        .padding(.horizontal, DNASpacing.sm)
                        .frame(minHeight: 36)
                        .dnaGlass(in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(DNASpacing.md)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func header(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
            Text(trip.placeTitleKo)
                .dnaFont(.screenTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text(metaLine(trip))
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    /// "2026년 9월 3일 – 9일 · 여가 · 친구 3명". 입력하지 않은 동행은 쓰지 않는다.
    private func metaLine(_ trip: Trip) -> String {
        let year = trip.legs.first.map { Calendar.current.component(.year, from: $0.startDate) }
        var parts = [year.map { "\($0)년 " + trip.shortDateRangeKo } ?? trip.shortDateRangeKo]
        if trip.purpose == .obligation {
            parts.append("출장")
        } else if trip.status != .active {
            parts.append("여가")
        }
        if !trip.companion.labelKo.isEmpty { parts.append(trip.companion.labelKo) }
        return parts.joined(separator: " · ")
    }

    // MARK: - 예정 · 여행 중

    private func plannedActions(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            if let days = trip.daysUntilStart {
                Text("D-\(days)")
                    .dnaFont(.heroTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
            }
            if trip.concepts != nil { conceptRow(trip) }
            Text("여행이 시작되면 매일 한 장의 사진으로 하루를 남길 수 있어요.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            Button("여행 시작") {
                Task { await viewModel.start(dependencies: dependencies) }
            }
            .buttonStyle(.dnaPrimary)
            Label("여행이 끝나는 날 평가를 알려드릴게요.", systemImage: "bell")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private var activeActions: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            HStack(spacing: DNASpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("오늘의 한 장")
                        .dnaFont(.sectionTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text(viewModel.todayPhoto == nil ? "아직 안 남겼어요" : "남겼어요")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(DNASpacing.md)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))

            Button(viewModel.todayPhoto == nil ? "오늘의 한 장 고르기" : "오늘의 사진 바꾸기") {
                photoDayEdit = PhotoDayEdit(dayIndex: viewModel.currentDayIndex)
            }
            .buttonStyle(.dnaPrimary)

            Text("여행이 끝나는 날 평가를 알려드릴게요")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
                .frame(maxWidth: .infinity)

            Button("일찍 돌아왔어요 · 여행 끝내기") { confirmingEnd = true }
                .buttonStyle(.dnaGhost)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 지난 여행

    private func conceptRow(_ trip: Trip) -> some View {
        HStack(spacing: DNASpacing.xs) {
            if let concepts = trip.concepts {
                ForEach([concepts.primary] + concepts.secondary, id: \.self) { concept in
                    Text(concept.labelKo)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .padding(.horizontal, DNASpacing.sm)
                        .frame(minHeight: 32)
                        .background(Color.dnaSurface1, in: Capsule())
                }
            }
            if trip.purpose == .leisure {
                Button("컨셉 고치기") {
                    editPrimary = trip.concepts?.primary
                    editSecondary = trip.concepts?.secondary ?? []
                    showingConceptEdit = true
                }
                .dnaFont(.caption)
                .underline()
                .foregroundStyle(Color.dnaTextPrimary)
                .frame(minHeight: 44)
            }
            Spacer(minLength: 0)
        }
    }

    private func saveEditedConcepts() {
        guard let trip = viewModel.trip, trip.purpose == .leisure, let editPrimary,
              let edited = try? TripConcepts(primary: editPrimary, secondary: editSecondary),
              edited != trip.concepts else { return }
        Task {
            _ = try? await dependencies.tripService.updateTrip(
                id: trip.id, legs: trip.legs, companion: trip.companion, purpose: trip.purpose, concepts: edited
            )
            await viewModel.load(tripID: tripID, dependencies: dependencies)
        }
    }

    private func rankRow(_ rank: Int) -> some View {
        NavigationLink {
            RankingBoardView()
        } label: {
            HStack {
                Text("내 랭킹 \(rank)위")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextTertiary)
            }
            .padding(DNASpacing.md)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func cityReviewsSection(_ trip: Trip) -> some View {
        let saved = trip.evaluation?.cityReviews ?? []
        return VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text("도시별 평가")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            ForEach(Array(trip.reviewTargets.enumerated()), id: \.offset) { _, target in
                let review = saved.first { $0.countryCode == target.countryCode && $0.city == target.city }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(target.city ?? CountryCatalog.name(for: target.countryCode))
                            .dnaFont(.cardTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Spacer()
                        if let rating = review?.rating {
                            Text("★ \(rating)")
                                .dnaFont(.cardTitle)
                                .foregroundStyle(Color.dnaTextPrimary)
                        }
                    }
                    if let review {
                        if let liked = review.liked { memoLine("좋았던 점", liked) }
                        if let disliked = review.disliked { memoLine("아쉬웠던 점", disliked) }
                    } else {
                        HStack {
                            Text("아직 평가 전")
                                .dnaFont(.caption)
                                .foregroundStyle(Color.dnaTextSecondary)
                            Spacer()
                            Button("평가하기") { showingEvaluation = true }
                                .buttonStyle(.dnaDark(fullWidth: false))
                        }
                    }
                }
                .padding(DNASpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            }
        }
    }

    private func memoLine(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextTertiary)
            Text(text)
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextPrimary)
        }
    }

    // MARK: - 하루 한 장 · 일정

    private func dailyPhotosSection(_ trip: Trip) -> some View {
        let days = Array(1...max(1, viewModel.totalDays))
        let filled = days.filter { viewModel.photo(forDay: $0) != nil }.count
        return VStack(alignment: .leading, spacing: DNASpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("하루 한 장")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                Text("\(days.count)일 중 \(filled)일")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 8) {
                ForEach(days, id: \.self) { day in
                    dayCell(day, trip: trip)
                }
            }
            if viewModel.photos.contains(where: { $0.selection == .autoFallback }) {
                Text("'자동'은 비어 있던 날을 앱이 골라둔 사진이에요. 눌러서 직접 바꿀 수 있어요.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
    }

    private func dayCell(_ day: Int, trip: Trip) -> some View {
        let photo = viewModel.photo(forDay: day)
        let editable = canEditPhoto(day: day, trip: trip)
        return VStack(spacing: 6) {
            Button {
                if editable { photoDayEdit = PhotoDayEdit(dayIndex: day) }
            } label: {
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        if let photo {
                            TripPhotoImage(storagePath: photo.storagePath)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                                    .strokeBorder(Color.dnaTextTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                if editable {
                                    Image(systemName: "plus").foregroundStyle(Color.dnaTextSecondary)
                                }
                            }
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if photo?.selection == .autoFallback {
                            Text("자동")
                                .dnaFont(.tabLabel)
                                .foregroundStyle(Color.dnaTextPrimary)
                                .padding(.horizontal, 8)
                                .frame(height: 22)
                                .background(Color.dnaRaised.opacity(0.9), in: Capsule())
                                .padding(6)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!editable)
            .accessibilityLabel(photo == nil ? "\(day)일째 사진 고르기" : "\(day)일째 사진 바꾸기")
            Text(trip.status == .active && day == viewModel.currentDayIndex ? "오늘" : "\(day)일째")
                .dnaFont(.tabLabel)
                .foregroundStyle(Color.dnaTextPrimary)
        }
    }

    /// 여행 중에는 오늘까지, 종료·평가 후에는 모든 일차를 편집할 수 있다.
    private func canEditPhoto(day: Int, trip: Trip) -> Bool {
        switch trip.status {
        case .planned:
            return false
        case .active:
            return day <= viewModel.currentDayIndex
        case .ended, .evaluated, .skippedEvaluation:
            return true
        }
    }

    private func legsSection(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text("일정")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            ForEach(Array(trip.legs.enumerated()), id: \.offset) { _, leg in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leg.cities.isEmpty ? CountryCatalog.name(for: leg.countryCode)
                             : "\(leg.cities.joined(separator: " · ")) · \(CountryCatalog.name(for: leg.countryCode))")
                            .dnaFont(.cardTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Text(legDateRange(leg))
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    Spacer()
                    Text("\(leg.days)일")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                .padding(DNASpacing.md)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            }
        }
    }

    private func legDateRange(_ leg: TripLeg) -> String {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.month, .day], from: leg.startDate)
        let end = calendar.dateComponents([.month, .day], from: leg.endDate)
        let from = "\(start.month ?? 0)월 \(start.day ?? 0)일"
        if leg.startDate == leg.endDate { return from }
        return start.month == end.month ? "\(from) – \(end.day ?? 0)일" : "\(from) – \(end.month ?? 0)월 \(end.day ?? 0)일"
    }

    @ViewBuilder
    private func activitiesSection(_ trip: Trip) -> some View {
        let links = dependencies.affiliateLinkService.links(for: trip)
        if links.isEmpty {
            SectionCard(title: "출발 전 뭐 할까") {
                VStack(alignment: .leading, spacing: DNASpacing.sm) {
                    Text("여행지에 도시를 추가하면 그 도시의 액티비티를 바로 찾을 수 있어요.")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("도시 추가하기") {
                        showingEdit = true
                    }
                    .dnaFont(.button)
                    .foregroundStyle(Color.dnaActionText)
                    .buttonStyle(.plain)
                }
            }
        } else {
            AffiliateActivitySection(title: "출발 전 뭐 할까", links: links)
        }
    }
}

#Preview("TripDetailView") {
    NavigationStack {
        TripDetailView(tripID: "preview-trip")
    }
    .previewWithAppEnvironment()
}
