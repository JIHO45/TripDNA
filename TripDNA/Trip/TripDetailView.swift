import SwiftUI

/// UI-6F~6H: 상태별 히어로 카드와 하루 한 장 타임라인을 담은 여행 상세.
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
    @State private var photoPageDay = 1
    @State private var photoDayEdit: PhotoDayEdit?

    private let satisfactionEmojis = ["😞", "😕", "😐", "😊", "🤩"]

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
            if viewModel.trip != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("수정") { showingEdit = true }
                        .tint(Color.dnaData)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let trip = viewModel.trip,
                           trip.status == .evaluated || trip.status == .skippedEvaluation {
                            Button("평가 고치기") {
                                showingEvaluation = true
                            }
                            Button("평가 삭제", role: .destructive) {
                                confirmingEvaluationDeletion = true
                            }
                        }
                        Button("여행 삭제", role: .destructive) {
                            confirmingTripDeletion = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("여행 관리")
                }
            }
        }
        .onAppear {
            // 첫 진입과 DailyPhotoView 등에서 돌아온 경우 모두 여기서 읽는다.
            Task {
                await viewModel.load(tripID: tripID, dependencies: dependencies)
                syncPhotoPageSelection()
            }
        }
        .sheet(isPresented: $showingCoverPicker) {
            coverPickerSheet
        }
        .sheet(isPresented: $showingShare) {
            if let trip = viewModel.trip {
                ShareCardSheet(kind: .trip, title: "여행 공유", disclosure: "기록한 만족도, 내 여행 랭킹과 긍정 태그가 포함돼요.", allowsDestinationNames: true) { showsDestinationNames in
                    TripShareCard(summary: TripShareSummary(trip: trip), showsDestinationNames: showsDestinationNames)
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let trip = viewModel.trip {
                NavigationStack {
                    TripRegistrationView(editing: trip) {
                        Task {
                            await viewModel.load(tripID: tripID, dependencies: dependencies)
                            syncPhotoPageSelection()
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
        .fullScreenCover(isPresented: $showingEvaluation, onDismiss: {
            Task {
                await viewModel.load(tripID: tripID, dependencies: dependencies)
                syncPhotoPageSelection()
            }
        }) {
            EvaluationView(tripID: tripID)
        }
        .navigationDestination(item: $photoDayEdit) { edit in
            if let trip = viewModel.trip {
                DailyPhotoView(trip: trip, dayIndex: edit.dayIndex)
            }
        }
        .confirmationDialog("여행을 종료할까요?", isPresented: $confirmingEnd, titleVisibility: .visible) {
            Button("여행 종료", role: .destructive) {
                Task { await viewModel.end(dependencies: dependencies) }
            }
            Button("계속 여행하기", role: .cancel) {}
        } message: {
            Text("종료하면 30초 평가를 시작할 수 있어요.")
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

    @ViewBuilder
    private func content(for trip: Trip) -> some View {
        let showPhotoPager = trip.status != .planned && viewModel.totalDays > 0
        let hasTripPhotos = photoPageItems.contains { $0.storagePath != nil }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if showPhotoPager {
                    TripPhotoPager(
                        items: photoPageItems,
                        selection: $photoPageDay,
                        prefersCompact: !hasTripPhotos,
                        usesPortraitHero: hasTripPhotos,
                        emptyDayMessage: "이 날은 아직 사진이 없어요",
                        usesScrollHeroEffect: true,
                        onEditDay: { day in
                            photoDayEdit = PhotoDayEdit(dayIndex: day)
                        },
                        canEditDay: { day in
                            canEditPhoto(day: day, trip: trip)
                        }
                    )
                    .padding(.bottom, DNASpacing.sm)
                }

                VStack(alignment: .leading, spacing: DNASpacing.lg) {
                    heroSection(trip)
                    legsSection(trip)
                    if trip.status == .planned && dependencies.affiliateActivitiesEnabled {
                        activitiesSection(trip)
                    }
                    infoSection(trip)
                }
                .padding(DNASpacing.lg)
            }
        }
        .tripPhotoHeroScrollSpace()
        .ignoresSafeArea(edges: showPhotoPager && hasTripPhotos ? .top : [])
        .refreshable {
            await viewModel.load(tripID: tripID, dependencies: dependencies)
            syncPhotoPageSelection()
        }
    }

    private var photoPageItems: [TripPhotoPageItem] {
        (1...max(1, viewModel.totalDays)).map { day in
            TripPhotoPageItem(
                dayIndex: day,
                storagePath: viewModel.photo(forDay: day)?.storagePath
            )
        }
    }

    private func syncPhotoPageSelection() {
        let days = photoPageItems.map(\.dayIndex)
        guard !days.isEmpty else { return }
        if days.contains(viewModel.currentDayIndex) {
            photoPageDay = viewModel.currentDayIndex
        } else if let firstWithPhoto = photoPageItems.first(where: { $0.storagePath != nil })?.dayIndex {
            photoPageDay = firstWithPhoto
        } else {
            photoPageDay = days[0]
        }
    }

    // MARK: - 상태별 히어로

    @ViewBuilder
    private func heroSection(_ trip: Trip) -> some View {
        switch trip.status {
        case .planned: plannedHero(trip)
        case .active: activeHero(trip)
        case .ended: endedHero(trip)
        case .evaluated, .skippedEvaluation: evaluatedHero(trip)
        }
    }

    /// UI-6F: 예정 여행.
    private func plannedHero(_ trip: Trip) -> some View {
        heroCard {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                HStack {
                    StatusPill(status: trip.status)
                    Spacer()
                }
                Text(trip.dateRangeKo)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("여행이 시작되면 매일 한 장의 사진으로 하루를 남길 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaTextSecondary)

                Button {
                    Task { await viewModel.start(dependencies: dependencies) }
                } label: {
                    Text("여행 시작")
                }
                .buttonStyle(.dnaPrimary)
                .padding(.top, DNASpacing.xs)

                Label("여행이 끝나면 30초 평가를 알려드릴게요.", systemImage: "bell")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    /// UI-6G: 현재 여행. N일차와 오늘의 한 장 상태를 크게 보여준다.
    private func activeHero(_ trip: Trip) -> some View {
        heroCard {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                HStack {
                    StatusPill(status: trip.status)
                    Spacer()
                    Text(trip.dateRangeKo)
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(viewModel.currentDayIndex)일차")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(viewModel.totalDays)일")
                        .font(.subheadline)
                        .foregroundStyle(Color.dnaTextSecondary)
                }

                HStack(spacing: DNASpacing.xs) {
                    Image(systemName: viewModel.todayPhoto == nil ? "camera" : "checkmark.circle.fill")
                        .foregroundStyle(viewModel.todayPhoto == nil ? Color.dnaWarning : Color.dnaData)
                    Text(viewModel.todayPhoto == nil ? "오늘의 한 장을 아직 남기지 않았어요" : "오늘의 한 장을 남겼어요")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer(minLength: 0)
                    if viewModel.todayPhoto != nil {
                        Button {
                            photoDayEdit = PhotoDayEdit(dayIndex: viewModel.currentDayIndex)
                        } label: {
                            Text("사진 바꾸기")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.dnaData)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DNASpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )

                if viewModel.todayPhoto == nil {
                    Button {
                        photoDayEdit = PhotoDayEdit(dayIndex: viewModel.currentDayIndex)
                    } label: {
                        Text("오늘의 한 장 고르기")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule(style: .continuous).fill(Color.dnaAction))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, DNASpacing.xs)
                }

                Button("여행 종료") {
                    confirmingEnd = true
                }
                .buttonStyle(.dnaSecondary)
            }
        }
    }

    /// UI-6H(평가 미완료): 30초 평가 강조.
    private func endedHero(_ trip: Trip) -> some View {
        heroCard(borderColor: Color.dnaWarning.opacity(0.45)) {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                HStack {
                    StatusPill(status: trip.status)
                    Spacer()
                    Text(trip.dateRangeKo)
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                Text("여행은 어땠나요?")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text("약 30초면 다음 추천이 더 정확해져요.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaTextSecondary)

                if missingPhotoDayCount > 0 {
                    Text("아직 사진이 없는 날이 \(missingPhotoDayCount)일 있어요. 위 사진을 눌러 보완할 수 있어요.")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }

                Button {
                    showingEvaluation = true
                } label: {
                    Text("30초 평가하기")
                }
                .buttonStyle(.dnaPrimary)
                .padding(.top, DNASpacing.xs)
            }
        }
    }

    private var missingPhotoDayCount: Int {
        guard viewModel.totalDays > 0 else { return 0 }
        return (1...viewModel.totalDays).filter { viewModel.photo(forDay: $0) == nil }.count
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

    /// UI-6H(평가 완료·생략): 결과 요약 + 랭킹 + 대표 사진 + 공유.
    private func evaluatedHero(_ trip: Trip) -> some View {
        heroCard {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                HStack {
                    StatusPill(status: trip.status)
                    Spacer()
                    Text(trip.dateRangeKo)
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }

                if let evaluation = trip.evaluation, !evaluation.skipped {
                    HStack(spacing: DNASpacing.sm) {
                        if let satisfaction = evaluation.satisfaction {
                            Text(satisfactionEmojis[max(0, min(4, satisfaction - 1))])
                                .font(.system(size: 34))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("만족도 \(satisfaction)/5")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                if let wouldRepeat = evaluation.wouldRepeat {
                                    Text(wouldRepeat ? "또 가고 싶은 여행" : "한 번이면 충분한 여행")
                                        .font(.caption)
                                        .foregroundStyle(Color.dnaTextSecondary)
                                }
                            }
                        }
                        Spacer()
                        if let rank = trip.rankPosition {
                            VStack(spacing: 2) {
                                Text("\(rank)위")
                                    .font(.title3.bold())
                                    .foregroundStyle(Color.dnaData)
                                Text("내 랭킹")
                                    .font(.caption2)
                                    .foregroundStyle(Color.dnaTextSecondary)
                            }
                        }
                    }

                    if !evaluation.positiveTagIDs.isEmpty || !evaluation.negativeTagIDs.isEmpty {
                        DNAFlowLayout(spacing: 6) {
                            ForEach(evaluation.positiveTagIDs, id: \.self) { tagID in
                                summaryTagPill(TagCatalog.labelKo(for: tagID), accent: .dnaData)
                            }
                            ForEach(evaluation.negativeTagIDs, id: \.self) { tagID in
                                summaryTagPill(TagCatalog.labelKo(for: tagID), accent: .dnaWarning)
                            }
                        }
                    }
                } else {
                    Text("평가를 생략한 여행이에요. 방문 기록만 남아 있어요.")
                        .font(.subheadline)
                        .foregroundStyle(Color.dnaTextSecondary)
                }

                NavigationLink {
                    RankingBoardView()
                } label: {
                    Label("랭킹 보드", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
                        .overlay(Capsule(style: .continuous).strokeBorder(Color.dnaDivider, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, DNASpacing.xs)

                HStack(spacing: DNASpacing.sm) {
                    Button {
                        showingCoverPicker = true
                    } label: {
                        Label(trip.coverPhotoStoragePath == nil ? "대표 사진 선택" : "대표 사진 변경", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(Color.dnaData)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        showingShare = true
                    } label: {
                        Label("공유하기", systemImage: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(Color.dnaData)
                    }
                    .accessibilityIdentifier("trip.sharePreview")
                }
            }
        }
    }

    private func heroCard<Content: View>(
        borderColor: Color = .dnaDivider,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(DNASpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                    .fill(Color.dnaSurface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.dnaTextTertiary.opacity(0.12), radius: 20, y: 8)
    }

    private func summaryTagPill(_ title: String, accent: Color) -> some View {
        Text(title)
            .font(.caption)
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accent.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(accent.opacity(0.4), lineWidth: 1))
    }

    // MARK: - 구간·정보

    private func legsSection(_ trip: Trip) -> some View {
        SectionCard(title: "여행지") {
            ForEach(Array(trip.legs.enumerated()), id: \.offset) { index, leg in
                HStack(spacing: DNASpacing.sm) {
                    if trip.legs.count > 1 {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.dnaData)
                            .frame(width: 22, height: 22)
                            .background(Color.dnaData.opacity(0.14), in: Circle())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(CountryCatalog.name(for: leg.countryCode))
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        if !leg.cities.isEmpty {
                            Text(leg.cities.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.78))
                        }
                        Text(legDateRange(leg))
                            .font(.caption2)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    Spacer()
                    Text("\(leg.days)일")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            }
        }
    }

    private func infoSection(_ trip: Trip) -> some View {
        SectionCard {
            HStack(spacing: DNASpacing.lg) {
                Label(trip.companion.labelKo, systemImage: "person.2")
                Label(trip.purpose.labelKo, systemImage: trip.purpose == .obligation ? "briefcase" : "sparkles")
                Spacer()
            }
            .font(.subheadline)
            .foregroundStyle(Color.dnaTextSecondary)
            if trip.purpose == .obligation {
                Text("의무 여행이라 취향 반영이 낮아요.")
                    .font(.caption2)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
    }

    @ViewBuilder
    private func activitiesSection(_ trip: Trip) -> some View {
        let links = dependencies.affiliateLinkService.links(for: trip)
        if links.isEmpty {
            SectionCard(title: "출발 전 뭐 할까") {
                VStack(alignment: .leading, spacing: DNASpacing.sm) {
                    Text("여행지에 도시를 추가하면 그 도시의 액티비티를 바로 찾을 수 있어요.")
                        .font(.subheadline)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("도시 추가하기") {
                        showingEdit = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dnaData)
                    .buttonStyle(.plain)
                }
            }
        } else {
            AffiliateActivitySection(title: "출발 전 뭐 할까", links: links)
        }
    }

    private func legDateRange(_ leg: TripLeg) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.dd"
        return "\(formatter.string(from: leg.startDate)) - \(formatter.string(from: leg.endDate))"
    }

    // MARK: - 대표 사진 변경

    private var coverPickerSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                if !viewModel.photos.isEmpty {
                    Text("하루 한 장에서 고르기")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DNASpacing.xs) {
                            ForEach(viewModel.photos.sorted { $0.tripDayIndex < $1.tripDayIndex }) { photo in
                                Button {
                                    Task {
                                        await viewModel.setCoverPhoto(photo.storagePath, dependencies: dependencies)
                                        showingCoverPicker = false
                                    }
                                } label: {
                                    TripPhotoImage(storagePath: photo.storagePath)
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Divider().overlay(Color.dnaDivider)
                }
                Text("사진첩에서 고르기")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                AnyPhotoLibraryPickerButton(title: "사진 선택") { path in
                    Task {
                        await viewModel.setCoverPhoto(path, dependencies: dependencies)
                        showingCoverPicker = false
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(DNASpacing.lg)
            .background(AppCanvas())
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}

#Preview("TripDetailView") {
    NavigationStack {
        TripDetailView(tripID: "preview-trip")
    }
    .previewWithAppEnvironment()
}
