import SwiftUI

extension WantedConceptTiers {
    /// 화면에 보이는 칸 이름. 내부 값은 1~3과 nil("모르겠거나 원하지 않아요").
    static func screenName(of tier: Int?) -> String {
        switch tier {
        case 1: "가장 원해요"
        case 2: "좋아요"
        case 3: "있으면 좋아요"
        default: "모르겠거나 원하지 않아요"
        }
    }

    /// 칸에 놓인 컨셉. nil 칸은 놓지 않은 나머지 전부다.
    func concepts(in tier: Int?) -> [TripConcept] {
        switch tier {
        case 1: tier1
        case 2: tier2
        case 3: tier3
        default: TripConcept.allCases.filter { self.tier(of: $0) == nil }
        }
    }
}

/// 컨셉·티어 화면이 함께 쓰는 선택형 칩.
struct OnboardingChip: View {
    let title: String
    var isSelected = false
    var showsChevron = false

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            if showsChevron {
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
        }
        .dnaFont(.body)
        .foregroundStyle(isSelected ? Color.dnaSelectedForeground : Color.dnaTextPrimary)
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(isSelected ? Color.dnaSelectedBackground : Color.dnaRaised, in: Capsule())
        .overlay { Capsule().strokeBorder(isSelected ? Color.clear : Color.dnaDivider, lineWidth: 1) }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct OnboardingHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text(title)
                .dnaFont(.screenTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            if let subtitle {
                Text(subtitle)
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - ⑤ 여행별 컨셉

struct OnboardingConceptsView: View {
    let viewModel: OnboardingViewModel
    let dependencies: AppDependencies
    @State private var primary: TripConcept?
    @State private var secondary: [TripConcept] = []
    @State private var isSaving = false

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                trailingTitle: "이 여행 건너뛰기",
                onTrailing: { advance(save: false) }
            )
            if let trip = viewModel.currentConceptTrip {
                ScrollView {
                    VStack(alignment: .leading, spacing: DNASpacing.lg) {
                        Text("여행 \(viewModel.conceptIndex + 1) / \(viewModel.conceptQueue.count) · \(trip.title) · \(trip.period)")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                        OnboardingHeader(title: "어떤 여행이었나요?", subtitle: "가장 큰 것 하나 · 나중에 고칠 수 있어요")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DNASpacing.xs) {
                            ForEach(TripConcept.allCases, id: \.self) { concept in
                                tile(concept)
                            }
                        }
                        if let primary {
                            secondarySection(primary: primary)
                        }
                        if let message = viewModel.errorMessage {
                            Text(message).dnaFont(.caption).foregroundStyle(Color.dnaError)
                        }
                    }
                    .padding(.horizontal, DNASpacing.gutter)
                    .padding(.top, DNASpacing.md)
                    .padding(.bottom, DNASpacing.xl)
                }
                .id(trip.id)
            }
            DNABottomCTA {
                let isLast = viewModel.conceptIndex + 1 >= viewModel.conceptQueue.count
                Button(isLast ? "다음" : "다음 여행") { advance(save: true) }
                    .buttonStyle(.dnaPrimary(isDisabled: primary == nil || isSaving))
                    .disabled(primary == nil || isSaving)
                Button("나머지는 나중에") { viewModel.skipRemainingConcepts() }
                    .buttonStyle(.dnaGhost)
            }
        }
        .onChange(of: viewModel.conceptIndex) {
            primary = nil
            secondary = []
            isSaving = false
        }
    }

    private func tile(_ concept: TripConcept) -> some View {
        let isSelected = primary == concept
        return Button {
            primary = concept
            secondary.removeAll { $0 == concept }
        } label: {
            Text(concept.labelKo)
                .dnaFont(.cardTitle)
                .foregroundStyle(isSelected ? Color.dnaSelectedForeground : Color.dnaTextPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    isSelected ? Color.dnaSelectedBackground : Color.dnaRaised,
                    in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : Color.dnaDivider, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func secondarySection(primary: TripConcept) -> some View {
        let options = TripConcept.allCases.filter { $0 != primary }
        let rows = [options.enumerated().filter { $0.offset % 2 == 0 }.map(\.element),
                    options.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)]
        return VStack(alignment: .leading, spacing: DNASpacing.xs) {
            HStack {
                Text("함께 한 것 · 선택")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                Text("최대 2개 · \(secondary.count)/2")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    ForEach(0..<rows.count, id: \.self) { row in
                        HStack(spacing: DNASpacing.xs) {
                            ForEach(rows[row], id: \.self) { concept in
                                let selected = secondary.contains(concept)
                                let locked = !selected && secondary.count >= 2
                                Button {
                                    toggleSecondary(concept)
                                } label: {
                                    OnboardingChip(title: concept.labelKo, isSelected: selected)
                                }
                                .buttonStyle(.plain)
                                .disabled(locked)
                                .opacity(locked ? 0.35 : 1)
                            }
                        }
                    }
                }
            }
        }
    }

    private func toggleSecondary(_ concept: TripConcept) {
        if let index = secondary.firstIndex(of: concept) {
            secondary.remove(at: index)
        } else if secondary.count < 2 {
            secondary.append(concept)
        }
    }

    private func advance(save: Bool) {
        let concepts = save ? primary.flatMap { try? TripConcepts(primary: $0, secondary: secondary) } : nil
        isSaving = true
        Task { await viewModel.finishConcept(concepts, dependencies: dependencies) }
    }
}

// MARK: - ⑥ 원하는 여행

/// 온보딩과 설정의 "원하는 여행"이 함께 쓰는 칸. 칩을 누르면 네 칸 이름 메뉴가 열린다.
struct ConceptTierBox: View {
    let tier: Int?
    let tiers: WantedConceptTiers
    let onPlace: (TripConcept, Int?) -> Void

    var body: some View {
        let concepts = tiers.concepts(in: tier)
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text(WantedConceptTiers.screenName(of: tier))
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            if tier == nil {
                Text("안 고른 것도 여기 있어요 · 이 칸 때문에 추천에서 빠지지는 않아요. 꼭 피하고 싶은 건 아래에 적어 주세요")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            if concepts.isEmpty {
                Text(" ").dnaFont(.body).frame(minHeight: 40)
            } else {
                DNAFlowLayout(spacing: DNASpacing.xs) {
                    ForEach(concepts, id: \.self) { concept in
                        Menu {
                            ForEach([1, 2, 3, nil] as [Int?], id: \.self) { target in
                                Button(WantedConceptTiers.screenName(of: target)
                                       + (tiers.tier(of: concept) == target ? " ✓" : "")) {
                                    onPlace(concept, target)
                                }
                            }
                        } label: {
                            OnboardingChip(title: concept.labelKo, showsChevron: true)
                        }
                    }
                }
            }
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tier == nil ? Color.dnaSurface1 : Color.dnaRaised, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaDivider, lineWidth: 1)
        }
    }
}

struct OnboardingTiersView: View {
    let viewModel: OnboardingViewModel
    let dependencies: AppDependencies
    @State private var showsAvoidNote = false

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                trailingTitle: "건너뛰기",
                onBack: { viewModel.goBack() },
                onTrailing: { finish(skipped: true) }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    OnboardingHeader(title: "평소에 어떤 여행을\n원하세요?", subtitle: "칩을 눌러 칸을 골라요")
                    reference
                    ForEach([1, 2, 3], id: \.self) { tier in
                        box(tier: tier)
                    }
                    box(tier: nil)
                    Button {
                        showsAvoidNote = true
                    } label: {
                        let hasNote = !(viewModel.tiers.avoidNote ?? "").isEmpty
                        Text(hasNote ? "피하고 싶은 것: \(viewModel.tiers.avoidNote ?? "") ›" : "피하고 싶은 게 있다면 적기 ›")
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.top, DNASpacing.lg)
                .padding(.bottom, DNASpacing.xl)
            }
            DNABottomCTA {
                Button("다음") { finish(skipped: false) }
                    .buttonStyle(.dnaPrimary)
            }
        }
        .sheet(isPresented: $showsAvoidNote) {
            AvoidNoteSheet(text: Binding(
                get: { viewModel.tiers.avoidNote ?? "" },
                set: { viewModel.tiers.avoidNote = $0 }
            ))
            .presentationDetents([.medium])
        }
    }

    /// 지난 여행 참고. 보여주기만 하고 칸을 미리 채우지 않는다.
    @ViewBuilder
    private var reference: some View {
        let top = viewModel.pastConceptReference.prefix(2)
        if !top.isEmpty {
            Text("지난 여행 참고 · " + top.map { "\($0.concept.labelKo) \($0.count)번" }.joined(separator: " · "))
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
                .padding(.horizontal, DNASpacing.sm)
                .padding(.vertical, 6)
                .background(Color.dnaSurface1, in: Capsule())
        }
    }

    private func box(tier: Int?) -> some View {
        ConceptTierBox(tier: tier, tiers: viewModel.tiers) { concept, target in
            viewModel.placeConcept(concept, in: target)
        }
    }

    private func finish(skipped: Bool) {
        Task { await viewModel.finishTiers(skipped: skipped, dependencies: dependencies) }
    }
}

private struct AvoidNoteSheet: View {
    @Binding var text: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Text("피하고 싶은 게 있나요?")
                .dnaFont(.heroTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("자유롭게 적어 주세요. 비워 둬도 괜찮아요.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            TextField("예: 긴 이동, 사람 많은 곳", text: $text, axis: .vertical)
                .lineLimit(3...6)
                .padding(DNASpacing.md)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            Button("완료") { dismiss() }
                .buttonStyle(.dnaPrimary)
            Spacer(minLength: 0)
        }
        .padding(DNASpacing.gutter)
        .background(Color.dnaSheet.ignoresSafeArea())
    }
}

// MARK: - ⑦ 확인하고 시작

struct OnboardingSummaryView: View {
    let viewModel: OnboardingViewModel
    let dependencies: AppDependencies
    let session: SessionStore
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(progress: viewModel.progress)
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    OnboardingHeader(
                        title: "이렇게 기억해 둘게요",
                        subtitle: "여행은 여행 탭에서, 원하는 여행은 설정에서 고칠 수 있어요."
                    )
                    if !viewModel.recordedTrips.isEmpty {
                        card(title: "다녀온 여행 \(viewModel.recordedTrips.count)개") {
                            ForEach(viewModel.recordedTrips) { trip in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(trip.title)
                                        .dnaFont(.cardTitle)
                                        .foregroundStyle(Color.dnaTextPrimary)
                                    Text(conceptText(trip.concepts))
                                        .dnaFont(.body)
                                        .foregroundStyle(Color.dnaTextSecondary)
                                }
                            }
                        }
                    }
                    if viewModel.hasTierAnswers {
                        card(title: "원하는 여행") {
                            ForEach([1, 2, 3], id: \.self) { tier in
                                let concepts = viewModel.tiers.concepts(in: tier)
                                if !concepts.isEmpty {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(WantedConceptTiers.screenName(of: tier))
                                            .dnaFont(.cardTitle)
                                            .foregroundStyle(Color.dnaTextPrimary)
                                        Text(concepts.map(\.labelKo).joined(separator: ", "))
                                            .dnaFont(.body)
                                            .foregroundStyle(Color.dnaTextSecondary)
                                    }
                                }
                            }
                            if let note = viewModel.tiers.avoidNote {
                                Text("피하고 싶은 것 · \(note)")
                                    .dnaFont(.body)
                                    .foregroundStyle(Color.dnaTextSecondary)
                            }
                        }
                    }
                    Text((viewModel.hasTierAnswers ? "평소 취향은 기억했어요. " : "") + "이번 여행의 컨셉만 고르면 추천받을 수 있어요.")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.top, DNASpacing.lg)
                .padding(.bottom, DNASpacing.xl)
            }
            DNABottomCTA {
                Button("첫 추천 받으러 가기") {
                    viewModel.finish(dependencies: dependencies, session: session, router: router, openRecommendation: true)
                }
                .buttonStyle(.dnaPrimary)
                Button("홈으로") {
                    viewModel.finish(dependencies: dependencies, session: session, router: router, openRecommendation: false)
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }

    private func conceptText(_ concepts: TripConcepts?) -> String {
        guard let concepts else { return "컨셉 없음" }
        return ([concepts.primary] + concepts.secondary).map(\.labelKo).joined(separator: " + ")
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text(title)
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            content()
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaRaised, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaDivider, lineWidth: 1)
        }
    }
}
