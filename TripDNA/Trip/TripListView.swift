import SwiftUI

/// 여행 탭: 목록(다가오는 · 평가를 기다리는 · 지난 여행)과 내 랭킹.
struct TripListView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppRouter.self) private var router
    @State private var viewModel = TripListViewModel()
    @State private var showingRegistration = false
    @State private var mode: Mode = .list

    private enum Mode: CaseIterable {
        case list, ranking

        var title: String {
            switch self {
            case .list: String(localized: "List")
            case .ranking: String(localized: "My Ranking")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            VStack(alignment: .leading, spacing: DNASpacing.md) {
                HStack {
                    Text("Trips")
                        .dnaFont(.screenTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                    Spacer()
                    registerButton
                }
                modePicker
            }
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.xs)

            switch mode {
            case .list:
                listContent
            case .ranking:
                RankingBoardView(embedded: true)
            }
        }
        .background(AppCanvas())
        .toolbar(.hidden, for: .navigationBar)
        .aiChatButton(tab: .trips)
        .sheet(isPresented: $showingRegistration) {
            NavigationStack {
                TripRegistrationView(prefilledCountryCode: nil)
            }
        }
        .onAppear { Task { await viewModel.load(dependencies) } }
        .onChange(of: showingRegistration) {
            if !showingRegistration {
                Task { await viewModel.load(dependencies) }
            }
        }
        .onChange(of: router.evaluationRequest) {
            if router.evaluationRequest == nil {
                Task { await viewModel.load(dependencies) }
            }
        }
    }

    private var registerButton: some View {
        Button {
            showingRegistration = true
        } label: {
            Text("+ Add")
                .dnaFont(.button)
                .foregroundStyle(Color.dnaTextPrimary)
                .padding(.horizontal, DNASpacing.md)
                .frame(minHeight: 44)
                .background(Color.dnaSurface1, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Trip")
    }

    private var modePicker: some View {
        DNASegmentedControl(items: Mode.allCases.map { ($0.title, $0) }, selection: mode) { mode = $0 }
    }

    // MARK: - 목록

    @ViewBuilder
    private var listContent: some View {
        if viewModel.isLoading && viewModel.trips.isEmpty {
            LoadingView()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.section) {
                    if viewModel.trips.isEmpty {
                        emptyCard
                    }
                    if let current = viewModel.currentTrip {
                        section(String(localized: "On a Trip")) { row(current, trailing: AnyView(inTripBadge(current))) }
                    }
                    if !viewModel.upcomingTrips.isEmpty {
                        section(String(localized: "Upcoming Trips")) {
                            ForEach(viewModel.upcomingTrips) { trip in
                                row(trip, trailing: AnyView(dDayLabel(trip)))
                            }
                        }
                    }
                    if !viewModel.awaitingTrips.isEmpty {
                        section(String(localized: "Waiting for Your Rating")) {
                            ForEach(viewModel.awaitingTrips) { trip in awaitingCard(trip) }
                        }
                    }
                    if !viewModel.pastTripsByYear.isEmpty {
                        section(String(localized: "Past Trips")) {
                            ForEach(viewModel.pastTripsByYear, id: \.year) { group in
                                Text(String(group.year))
                                    .dnaFont(.caption)
                                    .foregroundStyle(Color.dnaTextSecondary)
                                    .padding(.top, DNASpacing.xxs)
                                ForEach(group.trips) { trip in
                                    row(trip, trailing: AnyView(pastTrailing(trip)))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.bottom, DNASpacing.xl)
            }
            .dnaTopScrollBlur()
            .refreshable { await viewModel.load(dependencies) }
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text("No trips yet")
                .dnaFont(.cardTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("Tap + Add above to save a trip you’re planning or one you’ve taken.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DNASpacing.md)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text(title)
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            content()
        }
    }

    private func row(_ trip: Trip, trailing: AnyView) -> some View {
        NavigationLink {
            TripDetailView(tripID: trip.id)
        } label: {
            HStack(spacing: DNASpacing.sm) {
                thumbnail(trip)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: DNASpacing.xs) {
                        Text(trip.placeTitleKo)
                            .dnaFont(.cardTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .lineLimit(1)
                        if trip.purpose == .obligation {
                            Text("Business")
                                .dnaFont(.tabLabel)
                                .foregroundStyle(Color.dnaTextSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.dnaSurface2, in: Capsule())
                        }
                    }
                    Text(subtitle(trip))
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                trailing
            }
            .padding(DNASpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// 대표 사진이 있으면 그것을, 없으면 색 면을 쓴다. 가짜 사진은 넣지 않는다.
    private func thumbnail(_ trip: Trip) -> some View {
        ZStack {
            Color.dnaData.opacity(0.12).background(Color.dnaSurface2)
            if let path = trip.coverPhotoStoragePath { TripPhotoImage(storagePath: path) }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
        .accessibilityHidden(true)
    }

    /// "11월 14일 – 17일 · 친구 · 문화·역사". 입력하지 않은 항목은 쓰지 않는다.
    private func subtitle(_ trip: Trip) -> String {
        var parts = [trip.shortDateRangeKo]
        if !trip.companion.label.isEmpty { parts.append(trip.companion.label) }
        if let primary = trip.concepts?.primary { parts.append(primary.label) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func dDayLabel(_ trip: Trip) -> some View {
        if let days = trip.daysUntilStart {
            VStack(spacing: 0) {
                Text("D-").dnaFont(size: 11, weight: .semibold)
                Text("\(days)").dnaFont(.cardTitle)
            }
            .foregroundStyle(Color.dnaTextPrimary)
            .frame(width: 48, height: 48)
            .background(Color.dnaRaised, in: Circle())
            .overlay(Circle().strokeBorder(Color.dnaDivider, lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("D-\(days)")
        }
    }

    private func inTripBadge(_ trip: Trip) -> some View {
        Text("On a Trip")
            .dnaFont(.caption)
            .foregroundStyle(Color.dnaActionText)
    }

    @ViewBuilder
    private func pastTrailing(_ trip: Trip) -> some View {
        if trip.status == .skippedEvaluation {
            Text("Not Rated")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextTertiary)
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                if let stars = trip.evaluation?.satisfaction {
                    Text("★ \(stars)")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                if let rank = trip.rankPosition {
                    Text("#\(rank)")
                        .dnaFont(.cardTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .monospacedDigit()
                }
            }
        }
    }

    /// 어두운 카드. 눌러서 바로 평가를 이어간다.
    private func awaitingCard(_ trip: Trip) -> some View {
        Button {
            router.evaluationRequest = EvaluationRequest(tripID: trip.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.placeTitleKo)
                        .dnaFont(.cardTitle)
                        .foregroundStyle(Color.white)
                    Text(trip.shortDateRangeKo)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                Spacer(minLength: 0)
                Text("Resume")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaInk)
                    .padding(.horizontal, DNASpacing.sm)
                    .frame(minHeight: 32)
                    .background(Color.white, in: Capsule())
            }
            .padding(DNASpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dnaControlDark, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview("TripListView") {
    NavigationStack {
        TripListView()
    }
    .previewWithAppEnvironment()
}
