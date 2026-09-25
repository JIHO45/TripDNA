import SwiftUI

/// UI-6A: 현재·예정을 상태 카드로, 지난 여행을 목록으로 보여주는 화면.
struct TripListView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel = TripListViewModel()
    @State private var showingRegistration = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.trips.isEmpty {
                VStack(alignment: .leading, spacing: DNASpacing.lg) {
                    VStack(alignment: .leading, spacing: DNASpacing.sm) {
                        DNAScreenHeader(title: "내 여행", subtitle: "등록한 여행을 한눈에 보세요")
                        DNAHeaderDivider()
                    }
                    LoadingView()
                }
                .padding(DNASpacing.lg)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DNASpacing.lg) {
                        VStack(alignment: .leading, spacing: DNASpacing.sm) {
                            DNAScreenHeader(title: "내 여행", subtitle: "등록한 여행을 한눈에 보세요")
                            DNAHeaderDivider()
                        }
                        focusSection
                        pastSection
                    }
                    .padding(DNASpacing.lg)
                }
                .dnaTopScrollBlur()
                .refreshable { await viewModel.load(dependencies) }
            }
        }
        .background(AppCanvas())
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            DNABottomCTA {
                Button {
                    showingRegistration = true
                } label: {
                    Label("여행 등록", systemImage: "plus")
                }
                .buttonStyle(.dnaPrimary)
            }
        }
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
    }

    // MARK: - 현재 · 예정

    @ViewBuilder
    private var focusSection: some View {
        if let current = viewModel.currentTrip {
            tripSection(title: "여행 중") {
                tripLink(current)
            }

            if !viewModel.upcomingTrips.isEmpty {
                tripSection(title: "예정") {
                    ForEach(viewModel.upcomingTrips) { trip in
                        CompactTripRow(trip: trip)
                    }
                }
            }
        } else if !viewModel.upcomingTrips.isEmpty {
            tripSection(title: "다가오는 여행") {
                ForEach(viewModel.upcomingTrips) { trip in
                    tripLink(trip)
                }
            }
        } else {
            emptyFocusCard
        }
    }

    private var emptyFocusCard: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text("다음 여행이 없어요")
                .font(.headline)
                .foregroundStyle(.white)
            Text("아래 버튼으로 예정 여행을 등록해보세요.")
                .font(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DNASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaDivider, lineWidth: 1)
        )
    }

    // MARK: - 지난 여행

    private var pastSection: some View {
        tripSection(title: pastSectionTitle) {
            if viewModel.pastTrips.isEmpty {
                Text("다녀온 여행을 등록하면 지문이 더 정확해져요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .padding(.vertical, DNASpacing.xs)
            } else {
                ForEach(viewModel.pastTrips) { trip in
                    tripLink(trip)
                }
            }
        }
    }

    private var pastSectionTitle: String {
        if viewModel.pendingEvaluationCount > 0 {
            "지난 여행 · 평가 \(viewModel.pendingEvaluationCount)"
        } else {
            "지난 여행"
        }
    }

    // MARK: - Helpers

    private func tripSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dnaTextSecondary)
            content()
        }
    }

    private func tripLink(_ trip: Trip) -> some View {
        NavigationLink {
            TripDetailView(tripID: trip.id)
        } label: {
            TripCard(trip: trip)
        }
        .buttonStyle(.plain)
    }
}

/// 현재 여행이 있을 때 예정 여행을 가볍게 보여주는 한 줄 행.
private struct CompactTripRow: View {
    let trip: Trip

    var body: some View {
        NavigationLink {
            TripDetailView(tripID: trip.id)
        } label: {
            HStack(spacing: DNASpacing.sm) {
                StatusPill(status: trip.status)
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.titleKo)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(trip.dateRangeKo)
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .padding(.horizontal, DNASpacing.md)
            .padding(.vertical, DNASpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(Color.dnaSurface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .strokeBorder(Color.dnaDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 국가(다국가 "A · B")·기간·상태 배지·평가 대기 강조를 담은 여행 카드.
private struct TripCard: View {
    let trip: Trip

    private var awaitingEvaluation: Bool { trip.status == .ended }

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            HStack(alignment: .top, spacing: DNASpacing.sm) {
                coverThumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.titleKo)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(trip.dateRangeKo)
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    HStack(spacing: 8) {
                        Label(trip.companion.labelKo, systemImage: "person.2")
                        if trip.purpose == .obligation {
                            Label(trip.purpose.labelKo, systemImage: "briefcase")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.dnaTextSecondary)
                }
                Spacer(minLength: 0)
                StatusPill(status: trip.status)
            }

            if awaitingEvaluation {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.caption)
                    Text("30초 평가가 기다리고 있어요")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Color.dnaWarning)
                .padding(.horizontal, DNASpacing.sm)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                        .fill(Color.dnaWarning.opacity(0.1))
                )
            }
        }
        .padding(DNASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(
                    awaitingEvaluation ? Color.dnaWarning.opacity(0.4) : Color.dnaDivider,
                    lineWidth: 1
                )
        )
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        if let path = trip.coverPhotoStoragePath {
            TripPhotoImage(storagePath: path)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous))
        }
    }
}

#Preview("TripListView") {
    NavigationStack {
        TripListView()
    }
    .previewWithAppEnvironment()
}
