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
                    title: String(localized: "Trip not found"),
                    message: String(localized: "It may have been deleted or doesn’t exist."),
                    actionTitle: String(localized: "Go Back"),
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
                        .accessibilityLabel("Share")
                        .accessibilityIdentifier("trip.sharePreview")
                    }
                }
                // 공유와 더 보기를 한 알약에 묶지 않고 따로 둔다.
                if #available(iOS 26.0, *), isPast(trip) {
                    ToolbarSpacer(.fixed, placement: .topBarTrailing)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit Trip Info") { showingEdit = true }
                        if trip.status == .evaluated || trip.status == .skippedEvaluation {
                            Button("Edit Evaluation") { showingEvaluation = true }
                            Button("Delete Evaluation", role: .destructive) { confirmingEvaluationDeletion = true }
                        }
                        Button("Delete Trip", role: .destructive) { confirmingTripDeletion = true }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Manage Trip")
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
                ShareCardSheet(kind: .trip, title: String(localized: "Share Preview"), disclosure: String(localized: "Included: trip concepts, duration, my ranking · Not included: dates, cities, companions, photos"), allowsDestinationNames: true) { showsDestinationNames in
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
                secondaryTitle: viewModel.trip.map(isPast) == false ? String(localized: "Also Want to Do") : String(localized: "Also Did")
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
        .confirmationDialog("End this trip?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("End Trip", role: .destructive) {
                Task { await viewModel.end(dependencies: dependencies) }
            }
            Button("Keep Traveling", role: .cancel) {}
        } message: {
            Text("Once it ends, you can rate each city.")
        }
        .confirmationDialog("Delete this trip?", isPresented: $confirmingTripDeletion, titleVisibility: .visible) {
            Button("Delete Trip and Photos", role: .destructive) {
                Task {
                    do {
                        try await dependencies.deleteTrip(tripID: tripID, userID: session.userID)
                        dismiss()
                    } catch { deletionError = error.localizedDescription }
                }
            }
        } message: {
            Text("This deletes the trip, its evaluation, and the photos and ranking records saved for it.")
        }
        .confirmationDialog("Delete the evaluation?", isPresented: $confirmingEvaluationDeletion, titleVisibility: .visible) {
            Button("Delete Evaluation", role: .destructive) {
                Task {
                    do {
                        try await dependencies.deleteEvaluation(tripID: tripID, userID: session.userID)
                        await viewModel.load(tripID: tripID, dependencies: dependencies)
                    } catch { deletionError = error.localizedDescription }
                }
            }
        } message: {
            Text("Your trip and photos stay. The evaluation is removed from your fingerprint and ranking.")
        }
        .alert("Couldn’t Delete", isPresented: Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )) {
            Button("OK", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? String(localized: "Please try again."))
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
                        Text("Business trips keep only a visit record, with no trip concept. They don’t count toward your travel fingerprint.")
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
                Text("On the trip · Day \(viewModel.currentDayIndex) of \(viewModel.totalDays)")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.white)
                    .padding(DNASpacing.gutter)
            } else {
                Button { showingCoverPicker = true } label: {
                    Text("Change Photo")
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
        // 연도 포함 구간은 시스템 포맷에 맡긴다. 정수 보간은 영어에서 "2,026"이 된다.
        var dateText = trip.shortDateRangeKo
        if let first = trip.legs.first?.startDate, let last = trip.legs.last?.endDate {
            dateText = first < last
                ? (first..<last).formatted(.interval.year().month().day())
                : first.formatted(.dateTime.year().month().day())
        }
        var parts = [dateText]
        if trip.purpose == .obligation {
            parts.append(String(localized: "Business"))
        } else if trip.status != .active {
            parts.append(String(localized: "Leisure"))
        }
        if !trip.companion.label.isEmpty { parts.append(trip.companion.label) }
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
            Text("Once your trip starts, you can keep each day with one photo.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            Button("Start Trip") {
                Task { await viewModel.start(dependencies: dependencies) }
            }
            .buttonStyle(.dnaPrimary)
            Label("We’ll remind you to rate it when your trip ends.", systemImage: "bell")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private var activeActions: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            HStack(spacing: DNASpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today’s Photo")
                        .dnaFont(.sectionTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text(viewModel.todayPhoto == nil ? String(localized: "Not added yet") : String(localized: "Added"))
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(DNASpacing.md)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))

            Button(viewModel.todayPhoto == nil ? String(localized: "Choose Today’s Photo") : String(localized: "Change Today’s Photo")) {
                photoDayEdit = PhotoDayEdit(dayIndex: viewModel.currentDayIndex)
            }
            .buttonStyle(.dnaPrimary)

            Text("We’ll remind you to rate it when your trip ends")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
                .frame(maxWidth: .infinity)

            Button("Back Early · End Trip") { confirmingEnd = true }
                .buttonStyle(.dnaGhost)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 지난 여행

    private func conceptRow(_ trip: Trip) -> some View {
        HStack(spacing: DNASpacing.xs) {
            if let concepts = trip.concepts {
                ForEach([concepts.primary] + concepts.secondary, id: \.self) { concept in
                    Text(concept.label)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .padding(.horizontal, DNASpacing.sm)
                        .frame(minHeight: 32)
                        .background(Color.dnaSurface1, in: Capsule())
                }
            }
            if trip.purpose == .leisure {
                Button("Edit Concepts") {
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
                Text("My Rank: #\(rank)")
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
            Text("City Ratings")
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
                        if let liked = review.liked { memoLine(String(localized: "What you liked"), liked) }
                        if let disliked = review.disliked { memoLine(String(localized: "What fell short"), disliked) }
                    } else {
                        HStack {
                            Text("Not rated yet")
                                .dnaFont(.caption)
                                .foregroundStyle(Color.dnaTextSecondary)
                            Spacer()
                            Button("Rate") { showingEvaluation = true }
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
                Text("One Photo a Day")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                Text("\(filled) of \(days.count) days")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 8) {
                ForEach(days, id: \.self) { day in
                    dayCell(day, trip: trip)
                }
            }
            if viewModel.photos.contains(where: { $0.selection == .autoFallback }) {
                Text("“Auto” marks days the app filled in with a photo for you. Tap to choose your own.")
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
                            Text("Auto")
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
            .accessibilityLabel(photo == nil ? String(localized: "Choose photo for day \(day)") : String(localized: "Change photo for day \(day)"))
            Text(trip.status == .active && day == viewModel.currentDayIndex ? String(localized: "Today") : String(localized: "Trip day \(day)"))
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
            Text("Itinerary")
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
                    Text("\(leg.days) days")
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
        let monthDay = DateFormatter()
        monthDay.setLocalizedDateFormatFromTemplate("MMMd")
        let dayOnly = DateFormatter()
        dayOnly.setLocalizedDateFormatFromTemplate("d")
        let from = monthDay.string(from: leg.startDate)
        if leg.startDate == leg.endDate { return from }
        return start.month == end.month ? "\(from) – \(dayOnly.string(from: leg.endDate))" : "\(from) – \(monthDay.string(from: leg.endDate))"
    }

    @ViewBuilder
    private func activitiesSection(_ trip: Trip) -> some View {
        let links = dependencies.affiliateLinkService.links(for: trip)
        if links.isEmpty {
            SectionCard(title: String(localized: "What to Do Before You Go")) {
                VStack(alignment: .leading, spacing: DNASpacing.sm) {
                    Text("Add a city to your destination to find activities there right away.")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Add a City") {
                        showingEdit = true
                    }
                    .dnaFont(.button)
                    .foregroundStyle(Color.dnaActionText)
                    .buttonStyle(.plain)
                }
            }
        } else {
            AffiliateActivitySection(title: String(localized: "What to Do Before You Go"), links: links)
        }
    }
}

#Preview("TripDetailView") {
    NavigationStack {
        TripDetailView(tripID: "preview-trip")
    }
    .previewWithAppEnvironment()
}
