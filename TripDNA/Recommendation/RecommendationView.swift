import SwiftUI

/// UI-4A. 추천 메인: 3슬롯 카드 세로 스택 + 상황 필터 + 저장 목록 진입.
struct RecommendationView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(AppRouter.self) private var router
    @State private var viewModel = RecommendationViewModel()
    @State private var cityModel = CityRecommendationViewModel()
    @State private var lastRequest: RecommendationRequest?
    @State private var dislikeTarget: Recommendation?
    @State private var showingFilterSheet = false
    @State private var showingInput = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.lg) {
                VStack(alignment: .leading, spacing: DNASpacing.sm) {
                    header
                    DNAHeaderDivider()
                }
                if viewModel.hasRequested, cityModel.state != .idle {
                    CityRecommendationSection(model: cityModel) {
                        guard let lastRequest else { return }
                        Task { await cityModel.run(request: lastRequest, dependencies: dependencies) }
                    }
                }
                content
            }
            .padding(DNASpacing.lg)
        }
        .dnaTopScrollBlur()
        .dnaBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if viewModel.allSlotsReacted {
                DNABottomCTA {
                    Button {
                        Task { await viewModel.loadNewSet(dependencies) }
                    } label: {
                        Text("새 추천 보기")
                    }
                    .buttonStyle(.dnaPrimary)
                }
            }
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await viewModel.load(dependencies) }
        .refreshable { await viewModel.load(dependencies) }
        .sheet(isPresented: $showingFilterSheet) {
            RecommendationFilterSheet(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showingInput) {
            RecommendationInputSheet { request in
                lastRequest = request
                Task { await viewModel.submit(request, dependencies) }
                Task { await cityModel.start(request: request, dependencies: dependencies) }
            }
        }
        .onChange(of: router.recommendationInputRequested, initial: true) {
            guard router.recommendationInputRequested else { return }
            router.recommendationInputRequested = false
            showingInput = true
        }
        .alert(
            "지난 여행 평가를 추천에 쓸까요?",
            isPresented: Binding(
                get: { cityModel.pendingConsentRequest != nil },
                set: { _ in }
            )
        ) {
            Button("동의하고 보내기") { Task { await cityModel.answerConsent(true, dependencies: dependencies) } }
            Button("보내지 않기", role: .cancel) { Task { await cityModel.answerConsent(false, dependencies: dependencies) } }
        } message: {
            Text("도시별 별점과 좋았던 점·아쉬웠던 점 메모 원문, 다녀온 도시가 추천을 위해 외부 AI 모델로 전달돼요. 동의하지 않으면 보내지 않고, 기록은 이 기기에만 남아요. 설정은 도시 추천 위쪽 스위치에서 바꿀 수 있어요.")
        }
        .sheet(item: $dislikeTarget) { recommendation in
            RecommendationDislikeSheet(
                countryName: CountryCatalog.name(for: recommendation.countryCode)
            ) { reason in
                Task {
                    await viewModel.dislike(recommendation, reason: reason, dependencies: dependencies)
                }
            }
        }
        .animation(.spring(duration: 0.45), value: viewModel.slots)
        .animation(.easeOut(duration: 0.2), value: viewModel.toastMessage)
        .task(id: viewModel.toastMessage) {
            guard viewModel.toastMessage != nil else { return }
            try? await Task.sleep(for: .seconds(1.8))
            viewModel.toastMessage = nil
        }
    }

    // MARK: 상단

    private var header: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            DNAScreenHeader(title: "추천") {
                HStack(spacing: DNASpacing.sm) {
                    if viewModel.hasRequested {
                        Button { showingInput = true } label: {
                            DNACircleIcon(systemImage: "plus", isEmphasized: false)
                        }
                        .accessibilityLabel("새 여행 추천")
                    }
                    Button {
                        showingFilterSheet = true
                    } label: {
                        DNACircleIcon(
                            systemImage: "line.3.horizontal.decrease",
                            isEmphasized: viewModel.filter.isActive
                        )
                    }
                    .accessibilityLabel("상황 필터")

                    NavigationLink {
                        SavedRecommendationsView(viewModel: viewModel)
                    } label: {
                        DNACircleIcon(systemImage: "bookmark", isEmphasized: false)
                    }
                    .accessibilityLabel("저장 목록")
                }
            }

            if viewModel.filter.isActive {
                DNAFlowLayout(spacing: 6) {
                    ForEach(viewModel.filter.summaryKo, id: \.self) { summary in
                        Text(summary)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.dnaData)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.dnaData.opacity(0.12), in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: 본문

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.slots.isEmpty {
            LoadingView()
                .frame(height: 260)
        } else if !viewModel.hasFingerprint {
            EmptyStateView(
                systemImage: "sparkles",
                title: "추천을 준비 중이에요",
                message: viewModel.errorMessage ?? "아직 취향 지문이 없어요.",
                actionTitle: "여행 등록하러 가기",
                action: { router.selectedTab = .trips }
            )
            .frame(height: 300)
        } else if !viewModel.hasRequested {
            introView
        } else if viewModel.slots.isEmpty {
            emptyResultView
        } else {
            ForEach(viewModel.slots) { recommendation in
                slotCard(recommendation)
                    .onScrollVisibilityChange(threshold: 0.5) { visible in
                        guard visible, let exposure = viewModel.exposure else { return }
                        Task { await exposure.record(recommendation, dependencies: dependencies) }
                    }
                    .id("\(viewModel.exposure?.id ?? ""):\(recommendation.id)")
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
        }
    }

    /// 입력 시트로 추천을 받은 적이 없을 때의 안내. 입력은 시트에서 받는다.
    private var introView: some View {
        VStack(spacing: DNASpacing.md) {
            VStack(spacing: DNASpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Color.dnaActionText)
                    .frame(width: 56, height: 56)
                    .background(Color.dnaSurface2, in: Circle())
                Text("아직 받은 추천이 없어요")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("여행 컨셉을 고르면 추천을 받아요. 지금은 나라 단위로 보여주고, 고른 조건은 아직 일부만 반영돼요.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .multilineTextAlignment(.center)
                Button { showingInput = true } label: { Text("새 여행 추천 받기") }
                    .buttonStyle(.dnaPrimary)
                    .accessibilityIdentifier("recommendation.new")
            }
            .padding(DNASpacing.gutter)
            .frame(maxWidth: .infinity)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))

            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                Text("이렇게 추천해요")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                ForEach(Array([
                    "여행 컨셉과, 정해졌다면 시기·기간·예산을 골라요",
                    "최대 3곳을 맞는 이유, 안 맞을 수 있는 점과 함께 보여줘요",
                    "마음에 드는 곳은 저장하거나 여행으로 등록해요"
                ].enumerated()), id: \.offset) { index, text in
                    HStack(alignment: .top, spacing: DNASpacing.sm) {
                        Text("\(index + 1)")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .frame(width: 24, height: 24)
                            .background(Color.dnaSurface2, in: Circle())
                        Text(text)
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DNASpacing.gutter)
        }
    }

    /// 필터 결과 0개 또는 후보 소진 상태.
    @ViewBuilder
    private var emptyResultView: some View {
        if viewModel.filter.isActive {
            EmptyStateView(
                systemImage: "line.3.horizontal.decrease.circle",
                title: "필터에 맞는 추천이 없어요",
                message: "예산 범위가 후보를 모두 제외했어요.\n예산을 높이거나 초기화하면 다시 볼 수 있어요.",
                actionTitle: "필터 초기화",
                action: {
                    viewModel.resetFilter()
                    Task { await viewModel.refreshSlots(dependencies) }
                }
            )
            .frame(height: 300)
        } else {
            EmptyStateView(
                systemImage: "globe.asia.australia",
                title: "지금 보여드릴 추천이 없어요",
                message: "이번 세션에서 본 후보를 초기화하고\n다시 볼 수 있어요.",
                actionTitle: "처음부터 다시 보기",
                action: { Task { await viewModel.restartSession(dependencies) } }
            )
            .frame(height: 300)
        }
    }

    // MARK: 슬롯 카드

    @ViewBuilder
    private func slotCard(_ recommendation: Recommendation) -> some View {
        let reaction = viewModel.reaction(for: recommendation.slot)

        VStack(spacing: 0) {
            if reaction == .skip {
                exhaustedSlotContent(recommendation)
            } else {
                NavigationLink {
                    RecommendationDetailView(recommendation: recommendation, viewModel: viewModel)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        RecommendationHeroView(
                            countryCode: recommendation.countryCode,
                            slot: recommendation.slot
                        )
                        cardInfo(recommendation)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(reaction == .dislike)

                actionRow(recommendation, reaction: reaction)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface1)
        )
        .overlay { dislikedOverlay(recommendation, visible: reaction == .dislike) }
        .clipShape(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaDivider, lineWidth: 1)
        )
        .shadow(color: recommendation.slot.accentColor.opacity(0.14), radius: 20, y: 8)
        .animation(.easeOut(duration: 0.25), value: reaction)
    }

    private func cardInfo(_ recommendation: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            HStack(spacing: DNASpacing.xs) {
                ScoreBadge(score: recommendation.matchScore)
                FitBadgesRow(badges: recommendation.fitBadges)
            }

            Text(viewModel.reasonText(for: recommendation))
                .font(.subheadline)
                .foregroundStyle(Color.dnaTextPrimary.opacity(0.88))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(recommendation.notices, id: \.self) { notice in
                Label {
                    Text(notice)
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "equal.circle")
                        .foregroundStyle(Color.dnaWarning)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DNASpacing.md)
        .padding(.top, DNASpacing.sm)
    }

    /// 저장이 카드의 주 행동이다. 나머지 두 반응은 숨기지 않되 텍스트 버튼으로 낮춘다.
    private func actionRow(_ recommendation: Recommendation, reaction: FeedbackAction?) -> some View {
        let isSaved = reaction == .save
        return HStack(spacing: DNASpacing.md) {
            Button {
                Task { await viewModel.save(recommendation, dependencies: dependencies) }
            } label: {
                Label(isSaved ? "저장했어요" : "저장", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSaved ? Color.dnaData : Color.dnaTextPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.dnaSurface2.opacity(isSaved ? 0.5 : 1), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(reaction != nil)
            .sensoryFeedback(.success, trigger: isSaved) { _, saved in saved }

            Button("이번엔 아니에요") {
                Task { await viewModel.skip(recommendation, dependencies: dependencies) }
            }
            .accessibilityHint("이번 세션에서만 다른 후보로 바꿔요")
            .disabled(reaction != nil)

            Button("관심 없어요") {
                dislikeTarget = recommendation
            }
            .accessibilityHint("되돌리기 전까지 추천하지 않아요")
            .disabled(reaction != nil)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.dnaTextSecondary)
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .padding(.horizontal, DNASpacing.md)
        .padding(.vertical, DNASpacing.sm)
    }

    /// 스킵 후보가 소진된 슬롯의 자리 표시.
    private func exhaustedSlotContent(_ recommendation: Recommendation) -> some View {
        VStack(spacing: DNASpacing.xs) {
            SlotChip(slot: recommendation.slot)
            Text("이 슬롯의 후보를 모두 봤어요")
                .font(.subheadline)
                .foregroundStyle(Color.dnaTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DNASpacing.lg)
    }

    @ViewBuilder
    private func dislikedOverlay(_ recommendation: Recommendation, visible: Bool) -> some View {
        if visible {
            ZStack {
                Color.dnaCanvas.opacity(0.82)
                VStack(spacing: DNASpacing.xs) {
                    Image(systemName: "hand.raised.fill")
                        .font(.title3)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Text("앞으로 추천하지 않을게요")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text("저장 목록에서 언제든 되돌릴 수 있어요")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Button("되돌리기") {
                        Task { await viewModel.undoDislike(recommendation, dependencies: dependencies) }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dnaTextPrimary)
                    .frame(minHeight: 44)
                    .padding(.horizontal, DNASpacing.md)
                    .background(Color.dnaSurface2, in: Capsule())
                    .padding(.top, DNASpacing.xs)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: 토스트

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = viewModel.toastMessage {
            RecommendationToast(message: message)
                .padding(.bottom, DNASpacing.xl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview("RecommendationView") {
    NavigationStack {
        RecommendationView()
    }
    .previewWithAppEnvironment()
}
