import SwiftUI

/// UI-8: 여행 종료 평가 — 판정 → 비교 → 취향의 30초 스텝 플로우.
struct EvaluationView: View {
    let tripID: String
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EvaluationViewModel()
    @State private var photoPageDay = 1

    var body: some View {
        ZStack {
            AppCanvas()
            Group {
                switch viewModel.step {
                case .intro:
                    introStep
                case .processing:
                    processingStep
                case .result:
                    resultStep
                default:
                    steppedContent
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: viewModel.didSubmit) { _, submitted in submitted }
        .task {
            await viewModel.load(tripID: tripID, dependencies: dependencies)
            if let first = introPhotoItems.first?.dayIndex {
                photoPageDay = first
            }
        }
    }

    // MARK: - 8A 시작

    private var introStep: some View {
        let hasRealPhotos = !viewModel.photos.isEmpty

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                TripPhotoPager(
                    items: introPhotoItems,
                    selection: $photoPageDay,
                    prefersCompact: !hasRealPhotos,
                    usesPortraitHero: hasRealPhotos,
                    emptyDayMessage: "이 여행의 사진이 없어요",
                    usesScrollHeroEffect: true
                )

                VStack(spacing: DNASpacing.sm) {
                    Text(viewModel.isRevising
                         ? "\(viewModel.trip?.titleKo ?? "여행") 평가 고치기"
                         : "\(viewModel.trip?.titleKo ?? "여행"), 어땠나요?")
                        .font(.title.bold())
                        .foregroundStyle(Color.dnaTextPrimary)
                        .multilineTextAlignment(.center)
                    Text(viewModel.isRevising ? "이전 답이 채워져 있어요. 바꿀 것만 고치면 돼요" : "약 30초면 충분해요")
                        .font(.subheadline)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                .padding(.horizontal, DNASpacing.lg)
                .padding(.top, DNASpacing.sm)
                .padding(.bottom, DNASpacing.lg)
            }
        }
        .tripPhotoHeroScrollSpace()
        .ignoresSafeArea(edges: hasRealPhotos ? .top : [])
        .safeAreaInset(edge: .bottom) {
            DNABottomCTA {
                Button(viewModel.isRevising ? "고치기 시작" : "평가 시작") { viewModel.start() }
                    .buttonStyle(.dnaPrimary)

                HStack(spacing: DNASpacing.md) {
                    Button(viewModel.isRevising ? "닫기" : "나중에") { dismiss() }
                    if !viewModel.isRevising {
                        Text("·")
                            .foregroundStyle(Color.dnaTextSecondary.opacity(0.5))
                            .accessibilityHidden(true)
                        Button("평가 건너뛰기") {
                            Task { await viewModel.skip(dependencies: dependencies, session: session) }
                        }
                        .disabled(viewModel.isSubmitting)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color.dnaTextSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.top, DNASpacing.xs)
            }
        }
    }

    /// 평가 인트로는 남긴 사진만 넘긴다. 없으면 placeholder 한 장.
    private var introPhotoItems: [TripPhotoPageItem] {
        let photos = viewModel.photos.sorted { $0.tripDayIndex < $1.tripDayIndex }
        if photos.isEmpty {
            return [TripPhotoPageItem(dayIndex: 1, storagePath: "local://placeholder/sun.max.fill")]
        }
        return photos.map {
            TripPhotoPageItem(dayIndex: $0.tripDayIndex, storagePath: $0.storagePath)
        }
    }

    // MARK: - 스텝 공통 셸

    private var steppedContent: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                counterText: viewModel.partLabel,
                trailingTitle: nil,
                onBack: { viewModel.goBack() },
                onTrailing: nil
            )

            Group {
                switch viewModel.step {
                case .satisfaction: satisfactionStep
                case .revisit: revisitStep
                case .bestCountry: bestCountryStep
                case .comparison: comparisonStep
                case .positiveTags: positiveTagsStep
                case .tagAttribution: attributionStep
                case .negativeTags: negativeTagsStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 판정

    private var satisfactionStep: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            Text("이 여행, 얼마나 좋았나요?")
                .font(.title3.bold())
                .foregroundStyle(Color.dnaTextPrimary)
            DNASatisfactionEmojiRow(
                satisfaction: Binding(
                    get: { viewModel.satisfaction },
                    set: { viewModel.satisfaction = $0 }
                ),
                onSelect: { _ in
                    Task {
                        try? await Task.sleep(for: .seconds(0.3))
                        viewModel.advance()
                    }
                }
            )
            .padding(.horizontal, DNASpacing.lg)
            .sensoryFeedback(.selection, trigger: viewModel.satisfaction)
            Spacer()
        }
    }

    private var revisitStep: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            Text("다시 가고 싶나요?")
                .font(.title3.bold())
                .foregroundStyle(Color.dnaTextPrimary)
            VStack(spacing: DNASpacing.sm) {
                DNAChoiceCard(text: "또 가고 싶어요", isSelected: viewModel.revisitAnswer == .yes) {
                    viewModel.revisitAnswer = .yes
                    viewModel.advance()
                }
                DNAChoiceCard(text: "한 번이면 충분해요", isSelected: viewModel.revisitAnswer == .no) {
                    viewModel.revisitAnswer = .no
                    viewModel.advance()
                }
            }
            .padding(.horizontal, DNASpacing.lg)
            Spacer()
            DNABottomCTA {
                Button("잘 모르겠어요") {
                    viewModel.revisitAnswer = .unsure
                    viewModel.advance()
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }

    private var bestCountryStep: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            Text("가장 좋았던 나라는?")
                .font(.title3.bold())
                .foregroundStyle(Color.dnaTextPrimary)
            DNAFlowLayout(spacing: 10) {
                ForEach(viewModel.uniqueCountryCodes, id: \.self) { code in
                    DNATagChip(
                        title: CountryCatalog.name(for: code),
                        isSelected: viewModel.bestLegCountryCode == code
                    ) {
                        viewModel.bestLegCountryCode = code
                        viewModel.advance()
                    }
                }
            }
            .padding(.horizontal, DNASpacing.lg)
            Spacer()
        }
    }

    // MARK: - 비교

    private var comparisonStep: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            Text("둘 중 어느 여행이\n더 좋았나요?")
                .font(.title3.bold())
                .foregroundStyle(Color.dnaTextPrimary)
                .multilineTextAlignment(.center)

            if let trip = viewModel.trip, let anchor = viewModel.comparisonAnchor {
                HStack(spacing: DNASpacing.sm) {
                    comparisonCard(title: trip.titleKo, subtitle: trip.dateRangeKo)
                    Text("VS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dnaTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                    comparisonCard(title: anchor.titleKo, subtitle: anchor.dateRangeKo)
                }
                .padding(.horizontal, DNASpacing.lg)

                VStack(spacing: DNASpacing.sm) {
                    Button("\(trip.titleKo)이(가) 더 좋았어요") {
                        viewModel.comparisonResult = .better
                        viewModel.advance()
                    }
                    .buttonStyle(.dnaSecondary)

                    Button("\(anchor.titleKo)이(가) 더 좋았어요") {
                        viewModel.comparisonResult = .worse
                        viewModel.advance()
                    }
                    .buttonStyle(.dnaSecondary)
                }
                .padding(.horizontal, DNASpacing.lg)
            }

            Spacer()
            DNABottomCTA {
                Button("비슷해요 / 기억 안 나요") {
                    viewModel.comparisonResult = .skipped
                    viewModel.advance()
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }

    private func comparisonCard(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane.departure")
                .font(.title2)
                .foregroundStyle(Color.dnaTextPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(
                    Color.dnaSurface2,
                    in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                )
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dnaTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Color.dnaTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 취향 태그

    private var positiveTagsStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.lg) {
                    Text("좋았던 걸 골라주세요")
                        .font(.title3.bold())
                        .foregroundStyle(Color.dnaTextPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("최대 5개 · 없어도 괜찮아요")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)

                    if !viewModel.polarityTags.isEmpty {
                        tagSection(title: "성향", tags: viewModel.polarityTags, isPositive: true)
                    }
                    if !viewModel.interestTags.isEmpty {
                        tagSection(title: "관심사", tags: viewModel.interestTags, isPositive: true)
                    }
                }
                .padding(DNASpacing.lg)
            }
            DNABottomCTA {
                Button(viewModel.positiveTagIDs.isEmpty ? "건너뛰기" : "다음") {
                    viewModel.advance()
                }
                .buttonStyle(.dnaPrimary)
            }
        }
    }

    private var attributionStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.lg) {
                    Text("그 좋았던 건\n어느 나라에서였나요?")
                        .font(.title3.bold())
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text("전체 여행에서 느낀 것이면 '전체 여행에서'를 골라주세요.")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)

                    ForEach(viewModel.tasteTagsNeedingAttribution) { tag in
                        VStack(alignment: .leading, spacing: DNASpacing.sm) {
                            Text(tag.labelKo)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.dnaTextPrimary)
                            DNAFlowLayout(spacing: 8) {
                                DNATagChip(
                                    title: "전체 여행에서",
                                    isSelected: viewModel.tagLegAttribution[tag.id] == nil
                                ) {
                                    viewModel.setAttribution(tagID: tag.id, countryCode: nil)
                                }
                                ForEach(viewModel.uniqueCountryCodes, id: \.self) { code in
                                    DNATagChip(
                                        title: CountryCatalog.name(for: code),
                                        isSelected: viewModel.tagLegAttribution[tag.id] == code
                                    ) {
                                        viewModel.setAttribution(tagID: tag.id, countryCode: code)
                                    }
                                }
                            }
                        }
                        .padding(DNASpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                                .fill(Color.dnaSurface1)
                        )
                    }
                }
                .padding(DNASpacing.lg)
            }
            DNABottomCTA {
                Button("다음") { viewModel.advance() }
                    .buttonStyle(.dnaPrimary)
            }
        }
    }

    private var negativeTagsStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.lg) {
                    Text("아쉬웠던 점이 있나요?")
                        .font(.title3.bold())
                        .foregroundStyle(Color.dnaTextPrimary)
                    Text("최대 3개 · 선택 사항이에요")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)

                    tagSection(title: "아쉬웠던 것", tags: viewModel.negativeTagOptions, isPositive: false)

                    Text("제출한 뒤에도 여행 상세에서 고칠 수 있어요. 여행끼리의 순서는 랭킹 보드에서 바꿔요.")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .padding(.top, DNASpacing.sm)

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Color.dnaError)
                    }
                }
                .padding(DNASpacing.lg)
            }
            DNABottomCTA {
                Button {
                    Task { await viewModel.submit(dependencies: dependencies, session: session) }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView().tint(Color.dnaCanvas)
                    } else {
                        Text(viewModel.isRevising ? "수정 완료" : "평가 완료")
                    }
                }
                .buttonStyle(.dnaPrimary(isDisabled: viewModel.isSubmitting))
                .disabled(viewModel.isSubmitting)
            }
        }
    }

    private func tagSection(title: String, tags: [TagDefinition], isPositive: Bool) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.dnaTextSecondary)
            DNAFlowLayout(spacing: 8) {
                ForEach(tags) { tag in
                    let selected = isPositive
                        ? viewModel.positiveTagIDs.contains(tag.id)
                        : viewModel.negativeTagIDs.contains(tag.id)
                    let locked = isPositive
                        ? (!selected && viewModel.positiveTagIDs.count >= 5)
                        : (!selected && viewModel.negativeTagIDs.count >= 3)
                    DNATagChip(
                        title: tag.labelKo,
                        isSelected: selected
                    ) {
                        if isPositive {
                            viewModel.togglePositive(tag.id)
                        } else {
                            viewModel.toggleNegative(tag.id)
                        }
                    }
                    .disabled(locked)
                    .opacity(locked ? 0.35 : 1)
                }
            }
        }
    }

    // MARK: - 결과

    private var processingStep: some View {
        VStack(spacing: DNASpacing.md) {
            Spacer()
            ProgressView()
                .tint(Color.dnaTextSecondary)
                .scaleEffect(1.2)
            Text("지문에 반영하는 중")
                .font(.title3.bold())
                .foregroundStyle(Color.dnaTextPrimary)
            Spacer()
        }
    }

    private var resultStep: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(Color.dnaSurface2).frame(width: 88, height: 88)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.dnaTextPrimary)
            }
            Text(viewModel.isRevising ? "수정한 평가가 반영됐어요" : "평가가 반영됐어요")
                .font(.title3.bold())
                .foregroundStyle(Color.dnaTextPrimary)

            if let delta = viewModel.deltaAxes {
                let moved = TasteAxis.allCases.filter { abs(delta[$0]) >= 0.02 }
                SectionCard(title: "지문 변화") {
                    if moved.isEmpty {
                        Text("지문은 거의 그대로예요")
                            .font(.subheadline)
                            .foregroundStyle(Color.dnaTextSecondary)
                    } else {
                        ForEach(TasteAxis.allCases, id: \.self) { axis in
                            let value = delta[axis]
                            HStack {
                                Text(axis.shortLabelKo).foregroundStyle(Color.dnaTextPrimary)
                                Spacer()
                                Text(String(format: "%+.2f", value))
                                    .foregroundStyle(abs(value) >= 0.02
                                        ? (value >= 0 ? Color.dnaData : Color.dnaAction)
                                        : Color.dnaTextSecondary)
                            }
                            .font(.subheadline)
                            .opacity(abs(value) >= 0.02 ? 1 : 0.45)
                        }
                    }
                }
                .padding(.horizontal, DNASpacing.lg)
            }

            Spacer()
            DNABottomCTA {
                Button("바뀐 추천 보기") {
                    router.selectedTab = .recommendation
                    dismiss()
                }
                .buttonStyle(.dnaPrimary)
                Button("닫기") { dismiss() }
                    .buttonStyle(.dnaGhost)
                    .frame(minHeight: 44)
            }
        }
    }
}

#Preview("EvaluationView") {
    EvaluationView(tripID: "preview-trip")
        .previewWithAppEnvironment { session in
            session.onboardingPhase = .completed
            session.isAuthenticated = true
        }
}
