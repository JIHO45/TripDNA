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
        let custom = initial.budgetMax.map { !initial.budgetPresets.contains($0) } ?? false
        _customBudget = State(initialValue: custom)
        _customBudgetText = State(initialValue: custom ? initial.budgetMax.map { String($0 / BudgetCurrency.customUnit(for: initial.budgetCurrency)) } ?? "" : "")
    }

    /// 사는 나라로 정한 통화. 요청에 저장해 LLM·컷·표시가 같은 통화를 쓴다.
    private var currency: String { BudgetCurrency.resolve(homeCountryCode: dependencies.homeCountryCode) }
    private var unit: Int { BudgetCurrency.customUnit(for: currency) }

    private let calendar = Calendar.current
    private var thisYear: Int { calendar.component(.year, from: .now) }
    private var thisMonth: Int { calendar.component(.month, from: .now) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("New Trip Recommendation")
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
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, DNASpacing.md)
            .padding(.vertical, DNASpacing.xs)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: DNASpacing.xs) {
                        stepCard(.concept, label: String(localized: "Trip Concept"), value: conceptSummary, title: String(localized: "What kind of trip?"), subtitle: String(localized: "Pick the one you want most")) { conceptBody }
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(Color.dnaAction, lineWidth: highlightConcept ? 2 : 0)
                            )
                        stepCard(.when, label: String(localized: "When · How Long"), value: whenSummary, title: String(localized: "When and for how long?"), subtitle: nil, accessory: AnyView(exactDatesToggle)) { whenBody }
                        stepCard(.budget, label: String(localized: "Budget"), value: budgetSummary, title: String(localized: "What's your budget?"), subtitle: String(localized: "This is the maximum")) { budgetBody }
                        stepCard(.wants, label: String(localized: "For this trip"), value: wantsSummary, title: String(localized: "For this trip"), subtitle: nil) { wantsBody }
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
                Label("Get Recommendations", systemImage: "sparkles")
            }
            .buttonStyle(.dnaPrimary(isDisabled: !request.isReady))
            .accessibilityHint(request.isReady ? "" : "Choose a trip concept first")
            .accessibilityIdentifier("recommendationInput.submit")
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.xs)
            .padding(.bottom, DNASpacing.md)
        }
        .background(Color.dnaSheet.ignoresSafeArea())
        .onAppear {
            // 예전 통화로 저장한 금액은 사는 나라 통화와 맞지 않으면 미정으로 돌려 통화를 섞지 않는다.
            if request.budgetMax != nil, request.budgetCurrency != currency {
                request.budgetMax = nil
                customBudget = false
                customBudgetText = ""
            }
            request.budgetCurrency = currency
        }
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
                secondaryTitle: String(localized: "Also want to do · Optional"),
                onPrimary: { concept in
                    request.setPrimary(concept)
                    highlightConcept = false
                },
                onSecondary: { request.toggleSecondary($0) }
            )
            DNAStepper(label: String(localized: "Travelers"), valueText: String(localized: "\(request.partySize) people"), value: $request.partySize, range: 1...20)
        }
    }

    private var conceptSummary: String {
        guard let primary = request.primary else { return String(localized: "Choose one") }
        return ([primary] + request.secondary).joinedLabel() + " · " + String(localized: "\(request.partySize) people")
    }

    // MARK: ③ 언제 · 얼마나

    private var whenBody: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            if exactDates {
                DatePicker(
                    "Start Date",
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
            DNAStepper(label: String(localized: "How long"), valueText: nightsText, value: Binding(
                get: { request.nights ?? -1 },
                set: { request.nights = $0 < 0 ? nil : $0 }
            ), range: -1...60)
        }
    }

    private var exactDatesToggle: some View {
        Button(exactDates ? String(localized: "Pick by Month") : String(localized: "Set Exact Dates")) {
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
                    .accessibilityLabel("Previous Year")
                Spacer()
                Text(yearText(shownYear)).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                yearButton("chevron.right", enabled: shownYear < thisYear + 1) { shownYear += 1 }
                    .accessibilityLabel("Next Year")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DNASpacing.xs), count: 4), spacing: DNASpacing.xs) {
                ForEach(1...12, id: \.self) { month in
                    let past = shownYear == thisYear && month < thisMonth
                    let selected = request.year == shownYear && request.month == month
                    Button { request.toggleMonth(shownYear, month) } label: {
                        Text(monthText(month))
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

    private func monthText(_ month: Int) -> String {
        Calendar.current.shortMonthSymbols[month - 1]
    }

    private func yearText(_ year: Int) -> String {
        Calendar.current.date(from: DateComponents(year: year))?.formatted(.dateTime.year()) ?? String(year)
    }

    private var nightsText: String {
        guard let nights = request.nights else { return String(localized: "TBD") }
        return nights == 0 ? String(localized: "Same day") : String(localized: "\(nights)N \(nights + 1)D")
    }

    private var whenSummary: String {
        var parts: [String] = []
        if let date = request.startDate {
            parts.append(date.formatted(.dateTime.month().day()))
        } else if let month = request.month {
            parts.append(monthText(month))
        }
        if request.nights != nil { parts.append(nightsText) }
        return parts.isEmpty ? String(localized: "TBD") : parts.joined(separator: " · ")
    }

    // MARK: ④ 예산

    private var budgetBody: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            DNASegmentedControl(
                items: [(String(localized: "Per person"), RecommendationRequest.BudgetBasis.perPerson), (String(localized: "Whole group"), .group)],
                selection: request.budgetBasis
            ) { request.budgetBasis = $0 }
            DNASegmentedControl(items: [(String(localized: "Flights included"), true), (String(localized: "Flights excluded"), false)], selection: request.budgetIncludesFlight) {
                request.budgetIncludesFlight = $0
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    DNATagChip(title: String(localized: "TBD"), isSelected: request.budgetMax == nil && !customBudget) {
                        customBudget = false
                        request.budgetMax = nil
                    }
                    ForEach(BudgetCurrency.presets(for: currency), id: \.self) { amount in
                        DNATagChip(
                            title: String(localized: "Up to \(BudgetCurrency.format(amount, currency: currency, koreanUnit: "만 원"))"), // l10n-ignore Korean amount unit
                            isSelected: !customBudget && request.budgetMax == amount
                        ) {
                            customBudget = false
                            request.budgetMax = amount
                        }
                    }
                    DNATagChip(title: String(localized: "Custom"), isSelected: customBudget) {
                        customBudget = true
                        request.budgetMax = Int(customBudgetText).map { $0 * unit }
                    }
                }
            }
            if customBudget {
                HStack {
                    TextField("Amount", text: $customBudgetText)
                        .keyboardType(.numberPad)
                        .onChange(of: customBudgetText) { _, text in
                            request.budgetMax = Int(text).map { $0 * unit }
                        }
                    if currency == BudgetCurrency.krw {
                        Text("× ₩10K or less").foregroundStyle(Color.dnaTextSecondary)
                    } else {
                        Text(verbatim: currency).foregroundStyle(Color.dnaTextSecondary)
                    }
                }
                .dnaFont(.body)
                .padding(DNASpacing.sm)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            }
            Text("Cities with estimated costs over your budget are shown after the others. Costs are rough estimates, not live prices.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private var budgetSummary: String {
        guard let amount = request.budgetMax else { return String(localized: "TBD") }
        let basis = request.budgetBasis == .perPerson ? String(localized: "Per person") : String(localized: "Whole group")
        let flight = request.budgetIncludesFlight ? String(localized: "Flights included") : String(localized: "Flights excluded")
        let amountText = BudgetCurrency.format(amount, currency: request.budgetCurrency, koreanUnit: "만 원") // l10n-ignore Korean amount unit
        return String(localized: "\(basis) · \(flight) · \(amountText)")
    }

    // MARK: ⑤ 원하는 점

    private var wantsBody: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            field(String(localized: "Must-haves"), text: $request.wants, placeholder: String(localized: "e.g. Flight under 5 hours"))
            field(String(localized: "Things to avoid"), text: $request.avoids, placeholder: String(localized: "e.g. Crowded places, rainy season"))
            Toggle(isOn: $request.includeVisited) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Include Visited Cities").dnaFont(.body)
                    Text("When off, cities found in your records are excluded")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            }
            .tint(Color.dnaAction)
            if dependencies.canIncludeHomeCountry {
                Toggle(isOn: $request.includeHomeCountry) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include Home Country").dnaFont(.body)
                        if let code = dependencies.homeCountryCode {
                            Text("When off, cities in \(CountryCatalog.name(for: code)) aren't recommended")
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
        request.wants.isEmpty && request.avoids.isEmpty ? String(localized: "None") : String(localized: "Filled In")
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
