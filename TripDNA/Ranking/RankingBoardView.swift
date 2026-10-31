import SwiftUI

/// 내 랭킹: 여행 1건이 한 줄이다. 끄는 동안은 임시 순서이고, 저장해야 반영된다.
struct RankingBoardView: View {
    /// 여행 탭의 "내 랭킹" 구간 안에 놓일 때 true. 자체 배경과 탭바 숨김을 쓰지 않는다.
    var embedded = false
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @Environment(AppRouter.self) private var router
    @State private var viewModel = RankingViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.order.isEmpty {
                EmptyStateView(
                    systemImage: "list.number",
                    title: String(localized: "No trips to rank yet"),
                    message: String(localized: "Once you finish rating a trip, you can rank it."),
                    actionTitle: embedded ? nil : String(localized: "View My Trips"),
                    action: { router.selectedTab = .trips }
                )
            } else {
                boardContent
            }
        }
        .background { if !embedded { AppCanvas() } }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(embedded ? .automatic : .hidden, for: .tabBar)
        .task { await viewModel.load(dependencies) }
    }

    private var boardContent: some View {
        VStack(spacing: 0) {
            if viewModel.hasUnsavedChanges {
                Text("This is a preview. Save to apply the new order.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaUnverifiedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DNASpacing.sm)
                    .background(Color.dnaUnverifiedBackground, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
                    .padding(.horizontal, DNASpacing.gutter)
                    .padding(.top, DNASpacing.xs)
            }
            rankingList
            if viewModel.hasUnsavedChanges || viewModel.saveMessage != nil {
                DNABottomCTA {
                    if let message = viewModel.saveMessage {
                        Text(message)
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaData)
                            .multilineTextAlignment(.center)
                    }
                    if viewModel.hasUnsavedChanges {
                        HStack(spacing: DNASpacing.xs) {
                            Button("Cancel") { viewModel.revertDraft() }
                                .buttonStyle(.dnaSecondary)
                                .disabled(viewModel.isSaving)
                            Button {
                                Task { await viewModel.save(dependencies, userID: session.userID) }
                            } label: {
                                if viewModel.isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Save This Order")
                                }
                            }
                            .buttonStyle(.dnaPrimary(isDisabled: viewModel.isSaving))
                            .disabled(viewModel.isSaving)
                        }
                    }
                }
            }
        }
    }

    private var rankingList: some View {
        List {
            Section {
                ForEach(Array(viewModel.order.enumerated()), id: \.element) { index, tripID in
                    if let trip = viewModel.trip(for: tripID) {
                        rankingRow(rank: index + 1, trip: trip)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Color.dnaDivider)
                    }
                }
                .onMove { source, destination in
                    viewModel.moveDraft(
                        fromOffsets: source,
                        toOffset: destination,
                        dependencies: dependencies,
                        userID: session.userID
                    )
                }
            } header: {
                Text("Drag to reorder")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        // EditButton 없이 상시 드래그가 가능하도록 편집 모드를 고정한다.
        .environment(\.editMode, .constant(.active))
    }

    private func rankingRow(rank: Int, trip: Trip) -> some View {
        HStack(spacing: DNASpacing.md) {
            Text("\(rank)")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
                .monospacedDigit()
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.placeTitleKo)
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text(trip.yearMonthKo)
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

#Preview("RankingBoardView") {
    NavigationStack {
        RankingBoardView()
    }
    .previewWithAppEnvironment { session in
        session.onboardingPhase = .completed
    }
}
