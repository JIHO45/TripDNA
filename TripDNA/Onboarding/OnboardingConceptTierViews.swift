import SwiftUI

extension WantedConceptTiers {
    /// 화면에 보이는 칸 이름. 내부 값은 1~3과 nil("모르겠거나 원하지 않아요").
    static func screenName(of tier: Int?) -> String {
        switch tier {
        case 1: String(localized: "Want Most")
        case 2: String(localized: "Like It")
        case 3: String(localized: "Nice to Have")
        default: String(localized: "Not Sure or Don't Want")
        }
    }

    /// 칸에 놓인 컨셉. nil 칸은 놓지 않은 나머지 전부다.
    func concepts(in tier: Int?) -> [TripConcept] {
        switch tier {
        case 1: tier1
        case 2: tier2
        case 3: tier3
        default: TripConcept.displayOrder.filter { self.tier(of: $0) == nil }
        }
    }
}

/// 컨셉·티어 화면이 함께 쓰는 선택형 칩. 고르는 규칙은 `dnaOption`을 따른다.
/// 티어 칸의 칩은 고른 것이 아니라 칸의 무게를 보여주므로 `tone`으로 겉모습만 바꾼다.
struct OnboardingChip: View {
    enum Tone { case strong, raised }

    let title: String
    var isSelected = false
    var showsChevron = false
    var tone: Tone?

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            if showsChevron {
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
        }
        .dnaFont(.cardTitle)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .modifier(ChipLook(isSelected: isSelected, tone: tone))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private struct ChipLook: ViewModifier {
        let isSelected: Bool
        let tone: Tone?

        func body(content: Content) -> some View {
            if tone == .raised {
                content.foregroundStyle(Color.dnaTextPrimary).background(Color.dnaRaised, in: Capsule())
            } else {
                content.dnaOption(isSelected: isSelected || tone == .strong, in: Capsule())
            }
        }
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
    @State private var isSaving = false

    private var primary: TripConcept? { viewModel.conceptPrimary }
    private var secondary: [TripConcept] { viewModel.conceptSecondary }

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                trailingTitle: String(localized: "Skip This Trip"),
                onTrailing: { advance(save: false) }
            )
            if let trip = viewModel.currentConceptTrip {
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DNASpacing.lg) {
                        Text("Trip \(viewModel.conceptIndex + 1) of \(viewModel.conceptQueue.count) · \(trip.title) · \(trip.period)")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                        OnboardingHeader(title: String(localized: "What kind of trip was it?"), subtitle: String(localized: "Pick the biggest one · You can change it later"))
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DNASpacing.xs) {
                            ForEach(TripConcept.displayOrder, id: \.self) { concept in
                                tile(concept)
                            }
                        }
                        if let primary {
                            // 컨셉을 고르면 "함께 한 것"이 화면 아래에 생기므로, 아래 버튼에 가리지 않게 스크롤해 보여준다.
                            secondarySection(primary: primary).id("secondary")
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
                .onChange(of: primary) { _, new in
                    guard new != nil else { return }
                    withAnimation { proxy.scrollTo("secondary", anchor: .bottom) }
                }
                }
            }
            DNABottomCTA {
                let isLast = viewModel.conceptIndex + 1 >= viewModel.conceptQueue.count
                Button(isLast ? String(localized: "Next") : String(localized: "Next Trip")) { advance(save: true) }
                    .buttonStyle(.dnaPrimary(isDisabled: primary == nil || isSaving))
                    .disabled(primary == nil || isSaving)
                Button("Do the Rest Later") { viewModel.skipRemainingConcepts() }
                    .buttonStyle(.dnaGhost)
            }
        }
        .onChange(of: viewModel.conceptIndex) {
            isSaving = false
        }
    }

    private func tile(_ concept: TripConcept) -> some View {
        let isSelected = primary == concept
        return Button {
            viewModel.selectConceptPrimary(concept)
        } label: {
            Text(concept.label)
                .dnaFont(.cardTitle)
                .frame(maxWidth: .infinity, minHeight: 56)
                .dnaOption(isSelected: isSelected, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func secondarySection(primary: TripConcept) -> some View {
        let options = TripConcept.displayOrder.filter { $0 != primary }
        let half = (options.count + 1) / 2
        let rows = [Array(options.prefix(half)), Array(options.dropFirst(half))]
        return VStack(alignment: .leading, spacing: DNASpacing.xs) {
            HStack {
                Text("Also Included · Optional")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                Text("Up to 2 · \(secondary.count)/2")
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
                                    viewModel.toggleConceptSecondary(concept)
                                } label: {
                                    OnboardingChip(title: concept.label, isSelected: selected)
                                }
                                .buttonStyle(.plain)
                                .disabled(locked)
                                .opacity(locked ? 0.4 : 1)
                            }
                        }
                    }
                }
            }
        }
    }

    private func advance(save: Bool) {
        isSaving = true
        Task {
            if save { await viewModel.saveCurrentConcept(dependencies: dependencies) }
            else { await viewModel.finishConcept(nil, dependencies: dependencies) }
        }
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
                Text("Unplaced ones are here too · This box won't remove them from recommendations. Write anything you really want to avoid below")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            if concepts.isEmpty {
                Text(" ").dnaFont(.body).frame(minHeight: 20)
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
                            OnboardingChip(title: concept.label, showsChevron: true, tone: tier == 1 ? .strong : (tier == nil ? nil : .raised))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DNASpacing.md)
        .padding(.vertical, DNASpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tier == nil ? Color.clear : Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        .overlay {
            if tier == nil {
                RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                    .strokeBorder(Color.dnaDivider, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
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
                trailingTitle: String(localized: "Skip"),
                onBack: { viewModel.goBack() },
                onTrailing: { finish(skipped: true) }
            )
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    OnboardingHeader(title: String(localized: "What kind of trips\ndo you usually want?"), subtitle: String(localized: "Tap a chip to choose a box"))
                    reference
                    ForEach([1, 2, 3], id: \.self) { tier in
                        box(tier: tier)
                    }
                    box(tier: nil)
                    Button {
                        showsAvoidNote = true
                    } label: {
                        let hasNote = !(viewModel.tiers.avoidNote ?? "").isEmpty
                        Text(hasNote ? String(localized: "Avoid: \(viewModel.tiers.avoidNote ?? "") ›") : String(localized: "Add something to avoid ›"))
                            .dnaFont(.button)
                            .underline()
                            .foregroundStyle(Color.dnaTextPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.top, DNASpacing.lg)
                .padding(.bottom, DNASpacing.xl)
            }
            DNABottomCTA {
                Button("Next") { finish(skipped: false) }
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
            Text("Past trips for reference · \(top.map { String(localized: "\($0.concept.label) \($0.count) times") }.joined(separator: " · "))")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaData)
                .padding(DNASpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dnaData.opacity(0.12), in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
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
            Text("Anything you want to avoid?")
                .dnaFont(.heroTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("Write freely. It's fine to leave this blank.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            TextField("e.g., long transfers, crowded places", text: $text, axis: .vertical)
                .lineLimit(3...6)
                .padding(DNASpacing.md)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            Button("Done") { dismiss() }
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
            DNAStepTopBar(progress: viewModel.progress, onBack: { viewModel.goBack() })
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    OnboardingHeader(
                        title: String(localized: "Here's what we'll remember"),
                        subtitle: String(localized: "Edit trips in the Trips tab and wanted trips in Settings.")
                    )
                    if !viewModel.recordedTrips.isEmpty {
                        card(title: String(localized: "\(viewModel.recordedTrips.count) trips taken"), onEdit: { viewModel.editTripConcepts() }) {
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
                        card(title: String(localized: "Trips you want"), onEdit: { viewModel.goBack() }) {
                            ForEach([1, 2, 3], id: \.self) { tier in
                                let concepts = viewModel.tiers.concepts(in: tier)
                                if !concepts.isEmpty {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(WantedConceptTiers.screenName(of: tier))
                                            .dnaFont(.cardTitle)
                                            .foregroundStyle(Color.dnaTextPrimary)
                                        Text(concepts.map(\.label).joined(separator: ", "))
                                            .dnaFont(.body)
                                            .foregroundStyle(Color.dnaTextSecondary)
                                    }
                                }
                            }
                            if let note = viewModel.tiers.avoidNote {
                                Text("Avoid · \(note)")
                                    .dnaFont(.body)
                                    .foregroundStyle(Color.dnaTextSecondary)
                            }
                        }
                    }
                    Text(viewModel.hasTierAnswers
                         ? String(localized: "We remembered your usual tastes. Just pick this trip's concept to get recommendations.")
                         : String(localized: "Just pick this trip's concept to get recommendations."))
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.top, DNASpacing.lg)
                .padding(.bottom, DNASpacing.xl)
            }
            DNABottomCTA {
                Button("Get My First Recommendation") {
                    viewModel.finish(dependencies: dependencies, session: session, router: router, openRecommendation: true)
                }
                .buttonStyle(.dnaPrimary)
                Button("Go Home") {
                    viewModel.finish(dependencies: dependencies, session: session, router: router, openRecommendation: false)
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }

    private func conceptText(_ concepts: TripConcepts?) -> String {
        guard let concepts else { return String(localized: "No concept") }
        return ([concepts.primary] + concepts.secondary).map(\.label).joined(separator: " + ")
    }

    private func card<Content: View>(title: String, onEdit: (() -> Void)? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            HStack {
                Text(title)
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer(minLength: 0)
                if let onEdit {
                    Button("Edit", action: onEdit)
                        .dnaFont(.caption)
                        .underline()
                        .foregroundStyle(Color.dnaTextPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            content()
        }
        .padding(.horizontal, DNASpacing.md)
        .padding(.vertical, DNASpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }
}
