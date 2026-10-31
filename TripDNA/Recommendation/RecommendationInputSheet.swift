import SwiftUI

/// 추천 입력: 전체 화면 시트. 단계 카드 하나만 펼치고 나머지는 "라벨 · 값 ›" 줄로 접는다.
/// 주 컨셉을 고르기 전에는 "추천 받기"가 연하고, 누르면 컨셉 카드 테두리를 강조한다.
struct RecommendationInputSheet: View {
    let onSubmit: (RecommendationRequest) -> Void
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    private enum Step: Hashable { case concept, when, budget, wants }

    @State private var request: RecommendationRequest
    @State private var expanded: Step
    @State private var customBudget: Bool
    @State private var customBudgetText: String
    @State private var highlightConcept = false
    @State private var shownYear = Calendar.current.component(.year, from: .now)
    @State private var exactDates: Bool

    /// `initial`이 있으면 그 조건을 채워서 연다. 컨셉이 이미 있으면 사는 나라 같은 나머지 설정이 있는 마지막 단계를 먼저 편다.
    init(initial: RecommendationRequest = RecommendationRequest(), onSubmit: @escaping (RecommendationRequest) -> Void) {
        self.onSubmit = onSubmit
        _request = State(initialValue: initial)
        _expanded = State(initialValue: initial.isReady ? .wants : .concept)
        _exactDates = State(initialValue: initial.startDate != nil)
        let custom = initial.budgetMaxKRW.map { !Self.presetBudgets.contains($0) } ?? false
        _customBudget = State(initialValue: custom)
        _customBudgetText = State(initialValue: custom ? initial.budgetMaxKRW.map { String($0 / 10_000) } ?? "" : "")
    }

    private static var presetBudgets: [Int] { RecommendationRequest.budgetPresets }

    private let calendar = Calendar.current
    private var thisYear: Int { calendar.component(.year, from: .now) }
    private var thisMonth: Int { calendar.component(.month, from: .now) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("새 여행 추천")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .dnaFont(.cardTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.dnaRaised, in: Circle())
                }
                .accessibilityLabel("닫기")
            }
            .padding(.horizontal, DNASpacing.md)
            .padding(.vertical, DNASpacing.xs)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: DNASpacing.xs) {
                        stepCard(.concept, label: "여행 컨셉", value: conceptSummary, title: "어떤 여행인가요?", subtitle: "가장 하고 싶은 것 하나") { conceptBody }
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(Color.dnaAction, lineWidth: highlightConcept ? 2 : 0)
                            )
                        stepCard(.when, label: "언제 · 얼마나", value: whenSummary, title: "언제, 얼마나?", subtitle: nil, accessory: AnyView(exactDatesToggle)) { whenBody }
                        stepCard(.budget, label: "예산", value: budgetSummary, title: "예산은 얼마까지?", subtitle: "최대 금액이에요") { budgetBody }
                        stepCard(.wants, label: "이번 여행에서는", value: wantsSummary, title: "이번 여행에서는", subtitle: nil) { wantsBody }
                        // 시안 규칙: 하단에는 버튼만 둔다. 전송 안내는 카드 아래에 둔다.
                        Text(CityRecommendationSection.sendNotice)
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DNASpacing.md)
                            .padding(.top, DNASpacing.sm)
                    }
                    .padding(.horizontal, DNASpacing.sm)
                    .padding(.bottom, DNASpacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: expanded) { _, step in
                    withAnimation { proxy.scrollTo(step, anchor: .top) }
                }
            }

            Button(action: submit) {
                Label("추천 받기", systemImage: "sparkles")
            }
            .buttonStyle(.dnaPrimary(isDisabled: !request.isReady))
            .accessibilityHint(request.isReady ? "" : "먼저 여행 컨셉을 골라 주세요")
            .accessibilityIdentifier("recommendationInput.submit")
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.xs)
            .padding(.bottom, DNASpacing.md)
        }
        .background(Color.dnaSheet.ignoresSafeArea())
    }

    private func submit() {
        guard request.isReady else {
            withAnimation { expanded = .concept; highlightConcept = true }
            return
        }
        onSubmit(request)
        dismiss()
    }

    // MARK: 카드 틀

    private func stepCard<Content: View>(
        _ step: Step, label: String, value: String, title: String, subtitle: String?,
        accessory: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Group {
            if expanded == step {
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).dnaFont(.stepTitle).foregroundStyle(Color.dnaTextPrimary)
                            if let subtitle {
                                Text(subtitle).dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
                            }
                        }
                        Spacer(minLength: DNASpacing.xs)
                        accessory
                    }
                    content()
                }
                .padding(DNASpacing.gutter)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { expanded = step }
                } label: {
                    HStack {
                        Text(label).dnaFont(.body).foregroundStyle(Color.dnaTextSecondary)
                        Spacer(minLength: DNASpacing.xs)
                        Text(value).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary).lineLimit(1)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.dnaTextTertiary)
                    }
                    .padding(.horizontal, DNASpacing.gutter)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label), \(value)")
            }
        }
        .background(Color.dnaRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .id(step)
    }

    // MARK: ① 컨셉

    private var conceptBody: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            TripConceptPicker(
                primary: request.primary,
                secondary: request.secondary,
                secondaryTitle: "함께 하고 싶은 것 · 선택",
                onPrimary: { concept in
                    request.setPrimary(concept)
                    highlightConcept = false
                },
                onSecondary: { request.toggleSecondary($0) }
            )
            DNAStepper(label: "몇 명이서", valueText: "\(request.partySize)명", value: $request.partySize, range: 1...20)
        }
    }

    private var conceptSummary: String {
        guard let primary = request.primary else { return "선택해 주세요" }
        return ([primary] + request.secondary).joinedLabelKo() + " · \(request.partySize)명"
    }

    // MARK: ③ 언제 · 얼마나

    private var whenBody: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            if exactDates {
                DatePicker(
                    "시작일",
                    selection: Binding(
                        get: { request.startDate ?? .now },
                        set: { request.setStartDate($0) }
                    ),
                    in: Date.now...,
                    displayedComponents: .date
                )
                .dnaFont(.body)
            } else {
                monthGrid
            }
            // -1은 미정이다. 미정 → 당일 → 1박 순서로 움직인다.
            DNAStepper(label: "얼마나", valueText: nightsText, value: Binding(
                get: { request.nights ?? -1 },
                set: { request.nights = $0 < 0 ? nil : $0 }
            ), range: -1...60)
        }
    }

    private var exactDatesToggle: some View {
        Button(exactDates ? "월로 고르기" : "날짜 지정") {
            exactDates.toggle()
            if !exactDates { request.startDate = nil }
        }
        .dnaFont(.caption)
        .underline()
        .foregroundStyle(Color.dnaTextPrimary)
        .frame(minHeight: 44)
    }

    private var monthGrid: some View {
        VStack(spacing: DNASpacing.xs) {
            HStack {
                yearButton("chevron.left", enabled: shownYear > thisYear) { shownYear -= 1 }
                    .accessibilityLabel("이전 해")
                Spacer()
                Text("\(String(shownYear))년").dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                yearButton("chevron.right", enabled: shownYear < thisYear + 1) { shownYear += 1 }
                    .accessibilityLabel("다음 해")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DNASpacing.xs), count: 4), spacing: DNASpacing.xs) {
                ForEach(1...12, id: \.self) { month in
                    let past = shownYear == thisYear && month < thisMonth
                    let selected = request.year == shownYear && request.month == month
                    Button { request.toggleMonth(shownYear, month) } label: {
                        Text("\(month)월")
                            .dnaFont(.cardTitle)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(past ? Color.dnaTextTertiary : (selected ? Color.dnaSelectedForeground : Color.dnaTextPrimary))
                            .background(
                                selected ? Color.dnaSelectedBackground : Color.dnaChipFill,
                                in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(past)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private func yearButton(_ systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(enabled ? Color.dnaTextPrimary : Color.dnaTextTertiary)
                .frame(width: 44, height: 44)
                .background(Color.dnaChipFill, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var nightsText: String {
        guard let nights = request.nights else { return "미정" }
        return nights == 0 ? "당일" : "\(nights)박 \(nights + 1)일"
    }

    private var whenSummary: String {
        var parts: [String] = []
        if let date = request.startDate {
            parts.append(date.formatted(.dateTime.month().day()))
        } else if let month = request.month {
            parts.append("\(month)월")
        }
        if request.nights != nil { parts.append(nightsText) }
        return parts.isEmpty ? "미정" : parts.joined(separator: " · ")
    }

    // MARK: ④ 예산

    private var budgetBody: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            DNASegmentedControl(
                items: [("1인", RecommendationRequest.BudgetBasis.perPerson), ("일행 전체", .group)],
                selection: request.budgetBasis
            ) { request.budgetBasis = $0 }
            DNASegmentedControl(items: [("항공 포함", true), ("항공 제외", false)], selection: request.budgetIncludesFlight) {
                request.budgetIncludesFlight = $0
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    DNATagChip(title: "미정", isSelected: request.budgetMaxKRW == nil && !customBudget) {
                        customBudget = false
                        request.budgetMaxKRW = nil
                    }
                    ForEach(RecommendationRequest.budgetPresets, id: \.self) { amount in
                        DNATagChip(
                            title: "\(amount / 10_000)만 원 이하",
                            isSelected: !customBudget && request.budgetMaxKRW == amount
                        ) {
                            customBudget = false
                            request.budgetMaxKRW = amount
                        }
                    }
                    DNATagChip(title: "직접 입력", isSelected: customBudget) {
                        customBudget = true
                        request.budgetMaxKRW = Int(customBudgetText).map { $0 * 10_000 }
                    }
                }
            }
            if customBudget {
                HStack {
                    TextField("금액", text: $customBudgetText)
                        .keyboardType(.numberPad)
                        .onChange(of: customBudgetText) { _, text in
                            request.budgetMaxKRW = Int(text).map { $0 * 10_000 }
                        }
                    Text("만 원 이하").foregroundStyle(Color.dnaTextSecondary)
                }
                .dnaFont(.body)
                .padding(DNASpacing.sm)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            }
            Text("예상 비용이 예산을 넘는 도시는 빼요. 비용은 추정이에요.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private var budgetSummary: String {
        guard let amount = request.budgetMaxKRW else { return "미정" }
        let basis = request.budgetBasis == .perPerson ? "1인" : "일행 전체"
        let flight = request.budgetIncludesFlight ? "항공 포함" : "항공 제외"
        return "\(basis)·\(flight) · \(amount / 10_000)만 원"
    }

    // MARK: ⑤ 원하는 점

    private var wantsBody: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            field("특히 원하는 점", text: $request.wants, placeholder: "예: 비행 5시간 이내")
            field("피하고 싶은 점", text: $request.avoids, placeholder: "예: 너무 붐비는 곳, 우기")
            Toggle(isOn: $request.includeVisited) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("다녀온 도시도 포함").dnaFont(.body)
                    Text("끄면 기록에서 확인되는 방문 도시를 제외해요")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            }
            .tint(Color.dnaAction)
            if dependencies.canIncludeHomeCountry {
                Toggle(isOn: $request.includeHomeCountry) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("사는 나라도 포함").dnaFont(.body)
                        if let code = dependencies.homeCountryCode {
                            Text("끄면 \(CountryCatalog.name(for: code)) 도시는 추천하지 않아요")
                                .dnaFont(.caption)
                                .foregroundStyle(Color.dnaTextSecondary)
                        }
                    }
                }
                .tint(Color.dnaAction)
                .accessibilityIdentifier("recommendationInput.includeHomeCountry")
            }
        }
        .foregroundStyle(Color.dnaTextPrimary)
    }

    private var wantsSummary: String {
        request.wants.isEmpty && request.avoids.isEmpty ? "없음" : "입력함"
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(2...4)
                .dnaFont(.body)
                .padding(DNASpacing.sm)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
        }
    }

}

#Preview("RecommendationInputSheet") {
    RecommendationInputSheet { _ in }
        .previewWithAppEnvironment()
}
