import SwiftUI

/// 여행 탭: 목록(다가오는 · 평가를 기다리는 · 지난 여행)과 내 랭킹.
struct TripListView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppRouter.self) private var router
    @State private var viewModel = TripListViewModel()
    @State private var showingRegistration = false
    @State private var mode: Mode = .list

    private enum Mode: String, CaseIterable {
        case list = "목록"
        case ranking = "내 랭킹"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            VStack(alignment: .leading, spacing: DNASpacing.md) {
                HStack {
                    Text("여행")
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
            Text("+ 등록")
                .dnaFont(.button)
                .foregroundStyle(Color.dnaTextPrimary)
                .padding(.horizontal, DNASpacing.md)
                .frame(minHeight: 44)
                .background(Color.dnaSurface1, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("여행 등록")
    }

    private var modePicker: some View {
        HStack(spacing: 0) {
            ForEach(Mode.allCases, id: \.self) { item in
                Button { mode = item } label: {
                    Text(item.rawValue)
                        .dnaFont(.cardTitle)
                        .foregroundStyle(mode == item ? Color.dnaTextPrimary : Color.dnaTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if mode == item {
                                Capsule().fill(Color.dnaRaised)
                                    .shadow(color: Color.dnaTextPrimary.opacity(0.12), radius: 2, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == item ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.dnaSurface2, in: Capsule())
    }

    // MARK: - 목록

    @ViewBuilder
    private var listContent: some View {
        if viewModel.isLoading && viewModel.trips.isEmpty {
            LoadingView()
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.lg) {
                    if viewModel.trips.isEmpty {
                        emptyCard
                    }
                    if let current = viewModel.currentTrip {
                        section("여행 중") { row(current, trailing: AnyView(inTripBadge(current))) }
                    }
                    if !viewModel.upcomingTrips.isEmpty {
                        section("다가오는 여행") {
                            ForEach(viewModel.upcomingTrips) { trip in
                                row(trip, trailing: AnyView(dDayLabel(trip)))
                            }
                        }
                    }
                    if !viewModel.awaitingTrips.isEmpty {
                        section("평가를 기다리는 여행") {
                            ForEach(viewModel.awaitingTrips) { trip in awaitingCard(trip) }
                        }
                    }
                    ForEach(viewModel.pastTripsByYear, id: \.year) { group in
                        section("지난 여행 · \(group.year)") {
                            ForEach(group.trips) { trip in
                                row(trip, trailing: AnyView(pastTrailing(trip)))
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
            Text("아직 등록한 여행이 없어요")
                .dnaFont(.cardTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("위의 + 등록으로 갈 예정인 여행이나 다녀온 여행을 남겨보세요.")
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
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: DNASpacing.xs) {
                        Text(trip.placeTitleKo)
                            .dnaFont(.cardTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .lineLimit(1)
                        if trip.purpose == .obligation {
                            Text("출장")
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

    /// "11월 14일 – 17일 · 친구 · 문화·역사". 입력하지 않은 항목은 쓰지 않는다.
    private func subtitle(_ trip: Trip) -> String {
        var parts = [trip.shortDateRangeKo]
        if !trip.companion.labelKo.isEmpty { parts.append(trip.companion.labelKo) }
        if let primary = trip.concepts?.primary { parts.append(primary.labelKo) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func dDayLabel(_ trip: Trip) -> some View {
        if let days = trip.daysUntilStart {
            Text("D-\(days)")
                .dnaFont(.cardTitle)
                .foregroundStyle(Color.dnaTextPrimary)
        }
    }

    private func inTripBadge(_ trip: Trip) -> some View {
        Text("여행 중")
            .dnaFont(.caption)
            .foregroundStyle(Color.dnaActionText)
    }

    @ViewBuilder
    private func pastTrailing(_ trip: Trip) -> some View {
        if trip.status == .skippedEvaluation {
            Text("평가 안 함")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextTertiary)
        } else if let rank = trip.rankPosition {
            Text("\(rank)")
                .dnaFont(.cardTitle)
                .foregroundStyle(Color.dnaTextPrimary)
                .monospacedDigit()
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
                Text("이어서")
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
