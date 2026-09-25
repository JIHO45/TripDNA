import SwiftUI

struct RankingBoardView: View {
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
                    title: "아직 순서를 매길 여행이 없어요",
                    message: "평가를 마친 여행이 생기면 순서를 매길 수 있어요.",
                    actionTitle: "내 여행 보기",
                    action: { router.selectedTab = .trips }
                )
            } else {
                boardContent
            }
        }
        .background(AppCanvas())
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await viewModel.load(dependencies) }
    }

    // MARK: - 보드 본문 (3E)

    private var boardContent: some View {
        VStack(spacing: 0) {
            previewHeader
            rankingList
            DNABottomCTA {
                if let message = viewModel.saveMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.dnaData)
                        .multilineTextAlignment(.center)
                }
                Button {
                    Task { await viewModel.save(dependencies, userID: session.userID) }
                } label: {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("이 순서로 저장")
                    }
                }
                .buttonStyle(.dnaPrimary(isDisabled: !viewModel.hasUnsavedChanges || viewModel.isSaving))
                .disabled(!viewModel.hasUnsavedChanges || viewModel.isSaving)
            }
        }
    }

    // MARK: - 미니 지문 실시간 미리보기 (3E)

    private var previewHeader: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text("여행 단위로 순서를 바꾸면 지문이 다시 계산돼요")
                .font(.caption)
                .foregroundStyle(Color.dnaTextSecondary)

            if let vector = viewModel.previewVector {
                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    MiniFingerprintPreview(vector: vector)
                    if viewModel.hasUnsavedChanges {
                        Text("미리보기예요. 저장해야 반영돼요")
                            .font(.caption2)
                            .foregroundStyle(Color.dnaWarning)
                    }
                }
                .padding(DNASpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                        .fill(Color.dnaSurface1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                        .strokeBorder(Color.dnaDivider, lineWidth: 1)
                )
                .animation(.easeOut(duration: 0.25), value: vector.axes)
            }
        }
        .padding(.horizontal, DNASpacing.lg)
        .padding(.top, DNASpacing.sm)
        .padding(.bottom, DNASpacing.xs)
    }

    // MARK: - 랭킹 리스트 (상시 드래그 가능)

    private var rankingList: some View {
        List {
            Section {
                ForEach(Array(viewModel.order.enumerated()), id: \.element) { index, tripID in
                    if let trip = viewModel.trip(for: tripID) {
                        rankingRow(rank: index + 1, trip: trip)
                            .listRowBackground(Color.dnaSurface1)
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
                Text("드래그해서 순서를 바꿔보세요")
                    .font(.caption2)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        // EditButton 없이 상시 드래그가 가능하도록 편집 모드를 고정한다.
        .environment(\.editMode, .constant(.active))
    }

    private func rankingRow(rank: Int, trip: Trip) -> some View {
        HStack(spacing: DNASpacing.md) {
            Text("\(rank)")
                .font(.title2.bold())
                .foregroundStyle(rank <= 3 ? Color.dnaData : Color.dnaTextSecondary)
                .monospacedDigit()
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.titleKo)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    Text(trip.dateRangeKo)
                        .font(.caption2)
                        .foregroundStyle(Color.dnaTextSecondary)
                    if let satisfaction = trip.evaluation?.satisfaction {
                        Text("만족도 \(satisfaction)/5")
                            .font(.caption2)
                            .foregroundStyle(Color.dnaData)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

/// 드래그 미리보기용 축소판 지문. 짧은 라벨 + 발광 바만으로 구성한 컴팩트 버전.
private struct MiniFingerprintPreview: View {
    let vector: UserTasteVector

    var body: some View {
        VStack(spacing: 6) {
            ForEach(TasteAxis.allCases, id: \.self) { axis in
                HStack(spacing: DNASpacing.sm) {
                    Text(axis.shortLabelKo)
                        .font(.caption2)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .frame(width: 52, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 5)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.dnaTextTertiary, .dnaData],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .opacity(max(0.35, vector.confidence[axis]))
                                .frame(
                                    width: proxy.size.width * CGFloat((vector.axes[axis] + 1) / 2),
                                    height: 5
                                )
                        }
                    }
                    .frame(height: 5)
                    Text(String(format: "%+.2f", vector.axes[axis]))
                        .font(.caption2)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
    }
}

#Preview("RankingBoardView") {
    NavigationStack {
        RankingBoardView()
    }
    .previewWithAppEnvironment { session in
        session.onboardingPhase = .completed
        session.isAuthenticated = true
    }
}
