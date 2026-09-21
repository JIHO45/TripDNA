import Foundation
import SwiftUI

// MARK: - 1B 직접 입력 (국가 검색 → 시기 → 만족도 원탭 → 관심사 태그 ≤3)

struct OnboardingManualEntryView: View {
    let viewModel: OnboardingViewModel
    let dependencies: AppDependencies
    let session: SessionStore

    private enum Step: Equatable {
        case country
        case period
        case satisfaction
        case tags
        case roster
    }

    @State private var step: Step = .country
    @State private var draft = ManualTripDraft()
    @State private var satisfaction: Int?
    @State private var isAdvancing = false

    /// 온보딩에서는 관심사 그룹 태그만 노출한다 (성향 태그 제외).
    private static let interestTagIDs = [
        "food", "culture", "history", "outdoor", "beach",
        "nightlife", "shopping", "wellness", "sportsAndEvents"
    ]

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                counterText: counterText,
                trailingTitle: showsTopFinishButton ? "지문 보러 가기" : nil,
                onBack: { handleBack() },
                onTrailing: { submit() }
            )

            Group {
                switch step {
                case .country: countryStep
                case .period: periodStep
                case .satisfaction: satisfactionStep
                case .tags: tagsStep
                case .roster: rosterStep
                }
            }
            .frame(maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
            .id(step)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    private var counterText: String? {
        viewModel.manualDrafts.isEmpty ? nil : "\(viewModel.manualDrafts.count)개 등록됨"
    }

    /// 3개 이상 등록하면 어느 단계에서든 조기 페이오프를 허용한다 (상단 고정 CTA).
    private var showsTopFinishButton: Bool {
        viewModel.manualDrafts.count >= 3 && step != .roster
    }

    // MARK: 국가

    private var countryStep: some View {
        VStack(spacing: 0) {
            stepHeadline("어디를 다녀오셨나요?", caption: "국가 이름으로 검색해보세요")
            CountrySelectionList(selectedCode: $draft.countryCode)
            DNABottomCTA {
                Button {
                    step = .period
                } label: {
                    Text("다음")
                }
                .buttonStyle(.dnaPrimary(isDisabled: draft.countryCode.isEmpty))
                .disabled(draft.countryCode.isEmpty)
            }
        }
    }

    // MARK: 시기

    private var periodStep: some View {
        VStack(spacing: 0) {
            stepHeadline(
                "\(CountryCatalog.name(for: draft.countryCode)),\n언제 다녀오셨나요?",
                caption: "대략적인 시기면 충분해요"
            )
            SectionCard {
                DatePicker("시작일", selection: $draft.startDate, in: ...Date(), displayedComponents: .date)
                    .foregroundStyle(.white)
                DatePicker("종료일", selection: $draft.endDate, in: draft.startDate...Date(), displayedComponents: .date)
                    .foregroundStyle(.white)
            }
            .tint(Color.dnaTeal)
            .padding(.horizontal, DNASpacing.lg)
            Spacer()
            DNABottomCTA {
                Button {
                    if draft.endDate < draft.startDate {
                        draft.endDate = draft.startDate
                    }
                    step = .satisfaction
                } label: {
                    Text("다음")
                }
                .buttonStyle(.dnaPrimary)
            }
        }
    }

    // MARK: 만족도 원탭

    private var satisfactionStep: some View {
        VStack(spacing: DNASpacing.lg) {
            stepHeadline(
                "\(OnboardingFormat.flagEmoji(for: draft.countryCode)) \(CountryCatalog.name(for: draft.countryCode)) 여행,\n얼마나 좋았나요?",
                caption: OnboardingFormat.periodText(start: draft.startDate, end: draft.endDate)
            )
            Spacer()
            DNASatisfactionEmojiRow(satisfaction: $satisfaction) { value in
                guard !isAdvancing else { return }
                isAdvancing = true
                draft.satisfaction = value
                Task {
                    try? await Task.sleep(for: .seconds(0.35))
                    step = .tags
                    isAdvancing = false
                }
            }
            .padding(.horizontal, DNASpacing.lg)
            Spacer()
            Spacer()
        }
    }

    // MARK: 관심사 태그 (선택)

    private var tagsStep: some View {
        VStack(spacing: DNASpacing.lg) {
            stepHeadline("이 여행에서 좋았던 걸\n골라주세요", caption: "선택 사항 · 최대 3개")
            DNAFlowLayout(spacing: 10) {
                ForEach(Self.interestTagIDs, id: \.self) { tagID in
                    let isSelected = draft.positiveTagIDs.contains(tagID)
                    let isLocked = !isSelected && draft.positiveTagIDs.count >= 3
                    DNATagChip(title: TagCatalog.labelKo(for: tagID), isSelected: isSelected) {
                        if isSelected {
                            draft.positiveTagIDs.remove(tagID)
                        } else if !isLocked {
                            draft.positiveTagIDs.insert(tagID)
                        }
                    }
                    .disabled(isLocked)
                    .opacity(isLocked ? 0.35 : 1)
                }
            }
            .padding(.horizontal, DNASpacing.lg)
            Spacer()
            DNABottomCTA {
                Button {
                    registerCurrentDraft()
                } label: {
                    Text("이 여행 등록하기")
                }
                .buttonStyle(.dnaPrimary)
            }
        }
    }

    // MARK: 등록 목록

    private var rosterStep: some View {
        VStack(spacing: 0) {
            stepHeadline(
                "여행 \(viewModel.manualDrafts.count)개를 등록했어요",
                caption: viewModel.manualDrafts.count >= 3
                    ? "이제 지문을 그릴 수 있어요"
                    : "여행이 많을수록 지문이 선명해져요"
            )
            ScrollView {
                VStack(spacing: DNASpacing.sm) {
                    ForEach(viewModel.manualDrafts) { registered in
                        RegisteredTripRow(draft: registered) {
                            viewModel.removeManualDraft(id: registered.id)
                            if viewModel.manualDrafts.isEmpty {
                                startNewDraft()
                            }
                        }
                    }
                }
                .padding(.horizontal, DNASpacing.lg)
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.dnaCoral)
                    .padding(.bottom, DNASpacing.xs)
            }

            DNABottomCTA {
                Button {
                    submit()
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("지문 보러 가기")
                    }
                }
                .buttonStyle(.dnaPrimary(isDisabled: viewModel.isSubmitting))
                .disabled(viewModel.isSubmitting)

                Button("여행 하나 더 등록하기") {
                    startNewDraft()
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }

    // MARK: 공통

    private func stepHeadline(_ title: String, caption: String?) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DNASpacing.lg)
    }

    private func registerCurrentDraft() {
        viewModel.registerManualDraft(draft)
        step = .roster
    }

    private func startNewDraft() {
        draft = ManualTripDraft()
        satisfaction = nil
        step = .country
    }

    private func submit() {
        guard !viewModel.isSubmitting else { return }
        Task { await viewModel.submitBackfill(dependencies, session: session) }
    }

    private func handleBack() {
        switch step {
        case .country:
            if viewModel.manualDrafts.isEmpty {
                viewModel.goBack()
            } else {
                step = .roster
            }
        case .period:
            step = .country
        case .satisfaction:
            step = .period
        case .tags:
            satisfaction = nil
            step = .satisfaction
        case .roster:
            viewModel.goBack()
        }
    }
}

/// 등록 완료된 여행 1건의 요약 행.
private struct RegisteredTripRow: View {
    let draft: ManualTripDraft
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DNASpacing.sm) {
            Text(OnboardingFormat.flagEmoji(for: draft.countryCode))
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(CountryCatalog.name(for: draft.countryCode))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(OnboardingFormat.periodText(start: draft.startDate, end: draft.endDate))
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
            }
            Spacer()
            Text(OnboardingFormat.satisfactionEmojis[max(0, min(4, draft.satisfaction - 1))])
                .font(.title3)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Color.dnaSlate.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(DNASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                .fill(Color.dnaSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                .strokeBorder(Color.dnaHairline, lineWidth: 1)
        )
    }
}

// MARK: - 공용 유틸 (다른 화면에서도 사용 — 시그니처 유지)

struct FlowChips: View {
    let ids: [String]
    @Binding var selected: Set<String>

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(ids, id: \.self) { tagID in
                let isSelected = selected.contains(tagID)
                Text(TagCatalog.labelKo(for: tagID))
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        isSelected ? Color.dnaCoral.opacity(0.2) : Color.white.opacity(0.06),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule().strokeBorder(isSelected ? Color.dnaCoral.opacity(0.6) : Color.dnaHairline, lineWidth: 1)
                    )
                    .foregroundStyle(isSelected ? Color.dnaCoral : .white)
                    .onTapGesture {
                        if isSelected {
                            selected.remove(tagID)
                        } else {
                            selected.insert(tagID)
                        }
                    }
            }
        }
    }
}

enum TagCatalog {
    nonisolated(unsafe) static var definitions: [String: TagDefinition] = [:]

    nonisolated static func labelKo(for id: String) -> String {
        definitions[id]?.labelKo ?? id
    }
}

#Preview("OnboardingManualEntryView") {
    OnboardingManualEntryView(
        viewModel: OnboardingViewModel(),
        dependencies: AppDependencies(),
        session: SessionStore()
    )
    .previewWithAppEnvironment()
}

#Preview("FlowChips") {
    @Previewable @State var selected: Set<String> = ["food"]
    FlowChips(
        ids: ["food", "culture", "history", "outdoor", "beach"],
        selected: $selected
    )
    .padding()
    .background(AuroraBackground())
    .previewWithAppEnvironment()
}
