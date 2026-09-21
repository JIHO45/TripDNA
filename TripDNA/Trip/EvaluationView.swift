import SwiftUI

/// UI-8: 여행 종료 평가 — 판정 → 비교 → 취향의 30초 스텝 플로우.
struct EvaluationView: View {
    let tripID: String
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
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
                    Text("\(viewModel.trip?.titleKo ?? "여행"), 어땠나요?")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("약 30초면 충분해요")
                        .font(.subheadline)
                        .foregroundStyle(Color.dnaSlate)
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
                Button("평가 시작") { viewModel.start() }
                    .buttonStyle(.dnaPrimary)

                HStack(spacing: DNASpacing.md) {
                    Button("나중에") { dismiss() }
                    Text("·")
                        .foregroundStyle(Color.dnaSlate.opacity(0.5))
                    Button("평가 건너뛰기") {
                        Task { await viewModel.skip(dependencies: dependencies, session: session) }
                    }
                    .disabled(viewModel.isSubmitting)
                }
                .font(.subheadline)
                .foregroundStyle(Color.dnaSlate)
                .frame(maxWidth: .infinity)
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
                .foregroundStyle(.white)
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
            Spacer()
        }
    }

    private var revisitStep: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            Text("다시 가고 싶나요?")
                .font(.title3.bold())
                .foregroundStyle(.white)
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
                .foregroundStyle(.white)
            DNAFlowLayout(spacing: 10) {
                ForEach(viewModel.uniqueCountryCodes, id: \.self) { code in
                    DNATagChip(
                        title: CountryCatalog.name(for: code),
                        isSelected: viewModel.bestLegCountryCode == code,
                        accent: .dnaTeal
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
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if let trip = viewModel.trip, let anchor = viewModel.comparisonAnchor {
                HStack(spacing: DNASpacing.sm) {
                    comparisonCard(title: trip.titleKo, subtitle: trip.dateRangeKo)
                    Text("VS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.dnaSlate)
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(
                    LinearGradient(
                        colors: [.dnaIndigo.opacity(0.4), .dnaTeal.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                )
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Color.dnaSlate)
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
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("최대 5개 · 없어도 괜찮아요")
                        .font(.caption)
                        .foregroundStyle(Color.dnaSlate)

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
                        .foregroundStyle(.white)
                    Text("전체 여행에서 느낀 것이면 '전체 여행에서'를 골라주세요.")
                        .font(.caption)
                        .foregroundStyle(Color.dnaSlate)

                    ForEach(viewModel.tasteTagsNeedingAttribution) { tag in
                        VStack(alignment: .leading, spacing: DNASpacing.sm) {
                            Text(tag.labelKo)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            DNAFlowLayout(spacing: 8) {
                                DNATagChip(
                                    title: "전체 여행에서",
                                    isSelected: viewModel.tagLegAttribution[tag.id] == nil,
                                    accent: .dnaIndigo
                                ) {
                                    viewModel.setAttribution(tagID: tag.id, countryCode: nil)
                                }
                                ForEach(viewModel.uniqueCountryCodes, id: \.self) { code in
                                    DNATagChip(
                                        title: CountryCatalog.name(for: code),
                                        isSelected: viewModel.tagLegAttribution[tag.id] == code,
                                        accent: .dnaTeal
                                    ) {
                                        viewModel.setAttribution(tagID: tag.id, countryCode: code)
                                    }
                                }
                            }
                        }
                        .padding(DNASpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                                .fill(Color.dnaSurface)
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
                        .foregroundStyle(.white)
                    Text("최대 3개 · 선택 사항이에요")
                        .font(.caption)
                        .foregroundStyle(Color.dnaSlate)

                    tagSection(title: "아쉬웠던 것", tags: viewModel.negativeTagOptions, isPositive: false)

                    Text("제출 후에는 평가를 수정할 수 없어요. 서열은 랭킹 보드에서 고칠 수 있어요.")
                        .font(.caption)
                        .foregroundStyle(Color.dnaSlate)
                        .padding(.top, DNASpacing.sm)

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Color.dnaCoral)
                    }
                }
                .padding(DNASpacing.lg)
            }
            DNABottomCTA {
                Button {
                    Task { await viewModel.submit(dependencies: dependencies, session: session) }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("평가 완료")
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
                .foregroundStyle(Color.dnaSlate)
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
                        isSelected: selected,
                        accent: isPositive ? .dnaTeal : .dnaAmber
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
                .tint(Color.dnaTeal)
                .scaleEffect(1.2)
            Text("지문에 반영하는 중")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private var resultStep: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(Color.dnaTeal.opacity(0.16)).frame(width: 88, height: 88)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.dnaTeal)
            }
            Text("평가가 반영됐어요")
                .font(.title3.bold())
                .foregroundStyle(.white)

            if let delta = viewModel.deltaAxes {
                let moved = TasteAxis.allCases.filter { abs(delta[$0]) >= 0.02 }
                SectionCard(title: "지문 변화") {
                    if moved.isEmpty {
                        Text("지문은 거의 그대로예요")
                            .font(.subheadline)
                            .foregroundStyle(Color.dnaSlate)
                    } else {
                        ForEach(TasteAxis.allCases, id: \.self) { axis in
                            let value = delta[axis]
                            HStack {
                                Text(axis.shortLabelKo).foregroundStyle(.white)
                                Spacer()
                                Text(String(format: "%+.2f", value))
                                    .foregroundStyle(abs(value) >= 0.02
                                        ? (value >= 0 ? Color.dnaTeal : Color.dnaCoral)
                                        : Color.dnaSlate)
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
                Button("홈으로") { dismiss() }
                    .buttonStyle(.dnaPrimary)
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
