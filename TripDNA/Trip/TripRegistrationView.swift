import SwiftUI

struct TripLegDraft: Identifiable {
    let id: UUID
    var countryCode: String
    var cityText: String
    var startDate: Date
    var endDate: Date

    init(
        id: UUID = UUID(),
        countryCode: String = "",
        cities: [String] = [],
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    ) {
        self.id = id
        self.countryCode = countryCode
        self.cityText = cities.joined(separator: ", ")
        self.startDate = startDate
        self.endDate = endDate
    }

    var hasDateError: Bool { endDate < startDate }
    var isComplete: Bool { countryCode.count == 2 && !hasDateError }

    var cities: [String] {
        cityText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// ⓪ 어떤 여행을 남길까요. 등록 뒤 여행의 진행 상태와 기본 날짜를 정한다.
enum Scenario: Equatable {
    case planned, current, past

    var title: String {
        switch self {
        case .planned: String(localized: "Planning to Go")
        case .current: String(localized: "On a Trip Now")
        case .past: String(localized: "Already Went")
        }
    }

    var subtitle: String {
        switch self {
        case .planned: String(localized: "Fill in only what you know")
        case .current: String(localized: "Start recording from today")
        case .past: String(localized: "Add a trip you already took")
        }
    }
}

@Observable
final class TripRegistrationViewModel {
    /// UI-6C-5: 첫 예정·현재 여행 등록 성공 시 1회만 노출하는 알림 프라이밍.
    static let notificationPrimingShownKey = "tripdna.evalNotificationPrimingShown"

    /// `nil`이면 신규 등록, 값이 있으면 해당 여행 수정.
    let editingTripID: String?
    var legs: [TripLegDraft]
    /// 새 등록에서 고르는 여행 시점. 수정할 때는 nil이다.
    var scenario: Scenario?
    var companion: Companion = .unknown
    var purpose: TripPurpose = .leisure
    var primaryConcept: TripConcept?
    var secondaryConcepts: [TripConcept] = []
    var isSubmitting = false
    var errorMessage: String?
    var duplicateWarning = false
    var didSave = false
    var showNotificationPriming = false
    var primingPlaceTitle = ""

    var isEditing: Bool { editingTripID != nil }

    init(prefilledCountryCode: String?, prefilledCity: String? = nil) {
        editingTripID = nil
        var leg = TripLegDraft()
        if let prefilledCountryCode {
            leg.countryCode = prefilledCountryCode.uppercased()
        }
        if let prefilledCity { leg.cityText = prefilledCity }
        legs = [leg]
    }

    init(editing trip: Trip) {
        editingTripID = trip.id
        legs = trip.legs.map {
            TripLegDraft(
                countryCode: $0.countryCode,
                cities: $0.cities,
                startDate: $0.startDate,
                endDate: $0.endDate
            )
        }
        companion = trip.companion
        purpose = trip.purpose
        primaryConcept = trip.concepts?.primary
        secondaryConcepts = trip.concepts?.secondary ?? []
    }

    /// 필수는 여행 시점(새 등록)과 나라 하나다. 컨셉·동행은 비워 둘 수 있다.
    var canSubmit: Bool {
        !legs.isEmpty && legs.allSatisfy(\.isComplete) && (isEditing || scenario != nil)
    }

    /// 시점을 고르면 그에 맞는 기본 날짜로 구간을 다시 놓는다. 날짜는 ④에서 고칠 수 있다.
    func select(_ scenario: Scenario) {
        self.scenario = scenario
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let offset: Int
        switch scenario {
        case .planned: offset = 30
        case .current: offset = 0
        case .past: offset = -10
        }
        var cursor = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        for index in legs.indices {
            let span = max(0, nights(of: legs[index]))
            legs[index].startDate = cursor
            legs[index].endDate = calendar.date(byAdding: .day, value: span, to: cursor) ?? cursor
            cursor = legs[index].endDate
        }
    }

    func nights(of leg: TripLegDraft) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: leg.startDate), to: calendar.startOfDay(for: leg.endDate)
        ).day ?? 0
    }

    /// 시작일을 바꿔도 박 수는 그대로 둔다.
    func setStart(_ date: Date, legIndex: Int) {
        let span = max(0, nights(of: legs[legIndex]))
        legs[legIndex].startDate = date
        legs[legIndex].endDate = Calendar.current.date(byAdding: .day, value: span, to: date) ?? date
    }

    func setNights(_ nights: Int, legIndex: Int) {
        let start = legs[legIndex].startDate
        legs[legIndex].endDate = Calendar.current.date(byAdding: .day, value: max(0, nights), to: start) ?? start
    }

    /// 부 컨셉 제목. 다녀온 여행은 "함께 한 것", 아니면 "함께 하고 싶은 것".
    var secondaryTitle: String {
        (scenario == .past || (scenario == nil && isPastTrip)) ? String(localized: "Also Did") : String(localized: "Also Want to Do")
    }

    var conceptSummary: String? {
        primaryConcept.map { ([$0] + secondaryConcepts).joinedLabel() }
    }

    /// "11월 14일 – 17일 · 3박 4일". 구간이 여럿이면 첫 구간만 보여준다.
    var whenSummary: String? {
        guard let leg = legs.first else { return nil }
        let span = nights(of: leg)
        let range = span == 0 || leg.startDate >= leg.endDate
            ? leg.startDate.formatted(.dateTime.month().day())
            : (leg.startDate..<leg.endDate).formatted(.interval.month().day())
        return span == 0 ? range : "\(range) · " + String(localized: "\(span) nights, \(span + 1) days")
    }

    /// 의무 여행은 컨셉 없이 방문만 남긴다.
    var builtConcepts: TripConcepts? {
        guard purpose == .leisure, let primaryConcept else { return nil }
        return try? TripConcepts(primary: primaryConcept, secondary: secondaryConcepts)
    }

    func selectPrimary(_ concept: TripConcept) {
        primaryConcept = concept
        secondaryConcepts.removeAll { $0 == concept }
    }

    func toggleSecondary(_ concept: TripConcept) {
        guard concept != primaryConcept else { return }
        if let index = secondaryConcepts.firstIndex(of: concept) {
            secondaryConcepts.remove(at: index)
        } else if secondaryConcepts.count < 2 {
            secondaryConcepts.append(concept)
        }
    }

    /// 여행 전체가 오늘 이전에 끝났으면 과거 여행으로 취급한다.
    var isPastTrip: Bool {
        guard let lastEnd = legs.map(\.endDate).max() else { return false }
        return lastEnd < Calendar.current.startOfDay(for: Date())
    }

    var primaryCTATitle: String { isEditing ? String(localized: "Save Changes") : String(localized: "Add Trip") }

    func addLeg() {
        var newLeg = TripLegDraft()
        if let lastLeg = legs.last {
            // 이어지는 구간이 자연스럽도록 이전 구간 종료일부터 시작한다.
            newLeg.startDate = lastLeg.endDate
            newLeg.endDate = Calendar.current.date(byAdding: .day, value: 3, to: lastLeg.endDate) ?? lastLeg.endDate
        }
        legs.append(newLeg)
    }

    func removeLeg(id: TripLegDraft.ID) {
        legs.removeAll { $0.id == id }
        if legs.isEmpty {
            legs = [TripLegDraft()]
        }
    }

    func submit(_ dependencies: AppDependencies, ignoreDuplicate: Bool = false) async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let builtLegs = try legs.map {
                try TripLeg(
                    countryCode: $0.countryCode,
                    cities: $0.cities,
                    startDate: $0.startDate,
                    endDate: $0.endDate
                )
            }

            if let editingTripID {
                let probe = try Trip(id: editingTripID, legs: builtLegs, companion: companion, purpose: purpose)
                if !ignoreDuplicate {
                    let isDuplicate = try await dependencies.tripService.isDuplicate(of: probe)
                    if isDuplicate {
                        duplicateWarning = true
                        return
                    }
                }
                let updated = try await dependencies.tripService.updateTrip(
                    id: editingTripID,
                    legs: builtLegs,
                    companion: companion,
                    purpose: purpose,
                    concepts: builtConcepts
                )
                try? await EvaluationNotificationService.scheduleIfEnabled(for: updated)
                didSave = true
                return
            }

            let candidate = try Trip(legs: builtLegs, companion: companion, purpose: purpose)
            if !ignoreDuplicate {
                let isDuplicate = try await dependencies.tripService.isDuplicate(of: candidate)
                if isDuplicate {
                    duplicateWarning = true
                    return
                }
            }
            let created = try await dependencies.tripService.createTrip(
                legs: builtLegs,
                companion: companion,
                purpose: purpose,
                concepts: builtConcepts
            )
            // 시점에 맞춰 진행 상태를 정한다. 다녀온 여행은 평가를 기다리는 여행이 된다.
            var stored = created
            switch scenario {
            case .current:
                stored = try await dependencies.tripService.startTrip(id: created.id, at: builtLegs[0].startDate)
            case .past:
                stored = try await dependencies.tripService.endTrip(id: created.id, at: builtLegs[builtLegs.count - 1].endDate)
            case .planned, nil:
                break
            }
            primingPlaceTitle = stored.placeTitleKo
            try? await EvaluationNotificationService.scheduleIfEnabled(for: stored)
            if shouldShowNotificationPriming {
                AppStorageLocation.defaults.set(true, forKey: Self.notificationPrimingShownKey)
                showNotificationPriming = true
            } else {
                didSave = true
            }
        } catch let error as DomainValidationError
            where error == .invalidBestLeg || error == .invalidTagAttribution || error == .invalidCityReview {
            errorMessage = String(localized: "A country used in an evaluation is missing. Keep that country in a rated trip.")
        } catch {
            errorMessage = String(localized: "Please check the trip details. Make sure the country and dates are correct.")
        }
    }

    private var shouldShowNotificationPriming: Bool {
        !isEditing && scenario != .past && !isPastTrip && !AppStorageLocation.defaults.bool(forKey: Self.notificationPrimingShownKey)
    }
}

/// 여행 등록·수정: 단계 카드로 하나씩 연다. 필수는 여행 시점(새 등록)과 나라 하나뿐이다.
struct TripRegistrationView: View {
    var onSaved: (() -> Void)?
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TripRegistrationViewModel
    @State private var countryPickerTarget: CountryPickerTarget?
    @State private var openStep: Step?
    @State private var keyboardUp = false

    private enum Step: Hashable {
        case scenario, kind, where_, concept, companion, when
    }

    init(prefilledCountryCode: String?, prefilledCity: String? = nil, onCreated: (() -> Void)? = nil) {
        self.onSaved = onCreated
        _viewModel = State(initialValue: TripRegistrationViewModel(
            prefilledCountryCode: prefilledCountryCode, prefilledCity: prefilledCity
        ))
        _openStep = State(initialValue: .scenario)
    }

    init(editing trip: Trip, onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
        _viewModel = State(initialValue: TripRegistrationViewModel(editing: trip))
        _openStep = State(initialValue: .where_)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                if !viewModel.isEditing {
                    card(.scenario, "⓪", String(localized: "What kind of trip are you adding?"), viewModel.scenario?.title, scenarioBody)
                }
                card(.kind, "①", String(localized: "Trip Type"), kindSummary, kindBody)
                card(.where_, "②", String(localized: "Where To"), whereSummary, whereBody)
                if viewModel.purpose == .leisure {
                    card(.concept, "③", String(localized: "Trip Concepts"), viewModel.conceptSummary, conceptBody)
                } else {
                    Text("Business trips keep only a visit record, with no trip concept. They don’t count toward your travel fingerprint.")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .padding(DNASpacing.md)
                }
                card(.companion, "", String(localized: "Who With · Optional"), viewModel.companion == .unknown ? nil : viewModel.companion.label, companionBody)
                card(.when, "④", String(localized: "When · How Long"), viewModel.whenSummary, whenBody)
                if let message = viewModel.errorMessage {
                    Text(message)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaError)
                }
            }
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.vertical, DNASpacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 키보드가 떠 있는 동안은 CTA를 숨겨, 키보드 위에 떠서 입력 칸과 겹치지 않게 한다. 스크롤로 끝까지 닿는다.
            if !keyboardUp {
                DNABottomCTA(background: .dnaSheet) {
                    Button {
                        Task { await viewModel.submit(dependencies) }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text(viewModel.primaryCTATitle)
                        }
                    }
                    .buttonStyle(.dnaPrimary(isDisabled: !viewModel.canSubmit || viewModel.isSubmitting))
                    .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
                }
            }
        }
        .background(Color.dnaSheet)
        .tint(Color.dnaTextPrimary)
        .disabled(viewModel.isSubmitting)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle(viewModel.isEditing ? String(localized: "Edit Trip") : String(localized: "Add Trip"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .tint(Color.dnaTextSecondary)
            }
        }
        .sheet(item: $countryPickerTarget) { target in
            CountryPickerSheet(
                selectedCode: Binding(
                    get: {
                        viewModel.legs.first { $0.id == target.legID }?.countryCode ?? ""
                    },
                    set: { newCode in
                        if let index = viewModel.legs.firstIndex(where: { $0.id == target.legID }) {
                            viewModel.legs[index].countryCode = newCode.uppercased()
                        }
                    }
                )
            )
        }
        .sheet(isPresented: $viewModel.showNotificationPriming, onDismiss: {
            viewModel.didSave = true
        }) {
            NotificationPrimingSheet(trips: dependencies.store, placeTitle: viewModel.primingPlaceTitle) {
                viewModel.showNotificationPriming = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .alert("Overlapping Trip", isPresented: $viewModel.duplicateWarning) {
            Button(viewModel.isEditing ? String(localized: "Save Anyway") : String(localized: "Add Anyway"), role: .destructive) {
                Task { await viewModel.submit(dependencies, ignoreDuplicate: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                viewModel.isEditing
                    ? String(localized: "Another trip with the same country and dates exists. Save anyway?")
                    : String(localized: "A trip with the same country and dates already exists. Add anyway?")
            )
        }
        .onChange(of: viewModel.didSave) {
            if viewModel.didSave {
                onSaved?()
                dismiss()
            }
        }
    }

    // MARK: - 카드 틀

    private func card<Body: View>(
        _ step: Step, _ number: String, _ title: String, _ summary: String?, _ body: Body
    ) -> some View {
        let isOpen = openStep == step
        return VStack(alignment: .leading, spacing: DNASpacing.md) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) { openStep = isOpen ? nil : step }
            } label: {
                HStack(spacing: DNASpacing.xs) {
                    if !number.isEmpty {
                        Text(number)
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextTertiary)
                    }
                    // 시안: 펼친 단계는 큰 질문 제목, 접힌 단계는 회색 이름 + 오른쪽 굵은 값(추천 입력 시트와 같음).
                    Text(title)
                        .dnaFont(isOpen ? .stepTitle : .body)
                        .foregroundStyle(isOpen ? Color.dnaTextPrimary : Color.dnaTextSecondary)
                    Spacer(minLength: DNASpacing.xs)
                    if !isOpen {
                        Text(summary ?? String(localized: "TBD"))
                            .dnaFont(.cardTitle)
                            .foregroundStyle(summary == nil ? Color.dnaTextTertiary : Color.dnaTextPrimary)
                            .lineLimit(1)
                    }
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextTertiary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)

            if isOpen { body }
        }
        .padding(.horizontal, DNASpacing.md)
        .padding(.vertical, DNASpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaRaised, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }

    private func optionRow(_ title: String, _ subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .dnaFont(.cardTitle)
                    Text(subtitle)
                        .dnaFont(.caption)
                        .opacity(0.75)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.dnaSelectedForeground : Color.dnaTextPrimary)
            .padding(DNASpacing.md)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                isSelected ? Color.dnaSelectedBackground : Color.dnaSurface1,
                in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - ⓪ 어떤 여행을 남길까요

    private var scenarioBody: some View {
        VStack(spacing: DNASpacing.xs) {
            ForEach([Scenario.planned, .current, .past], id: \.self) { scenario in
                optionRow(scenario.title, scenario.subtitle, isSelected: viewModel.scenario == scenario) {
                    viewModel.select(scenario)
                    withAnimation { openStep = .kind }
                }
            }
        }
        .padding(.bottom, DNASpacing.sm)
    }

    // MARK: - ① 어떤 여행

    private var kindSummary: String {
        viewModel.purpose == .leisure ? String(localized: "Leisure Trip") : String(localized: "Business · Family Visit")
    }

    private var kindBody: some View {
        VStack(spacing: DNASpacing.xs) {
            optionRow(String(localized: "Leisure Trip"), String(localized: "Adds a concept and builds your fingerprint"), isSelected: viewModel.purpose == .leisure) {
                viewModel.purpose = .leisure
                withAnimation { openStep = .where_ }
            }
            optionRow(String(localized: "Business · Family Visit"), String(localized: "Only a visit record is kept"), isSelected: viewModel.purpose == .obligation) {
                viewModel.purpose = .obligation
                withAnimation { openStep = .where_ }
            }
        }
        .padding(.bottom, DNASpacing.sm)
    }

    // MARK: - ② 어디로

    private var whereSummary: String? {
        guard let first = viewModel.legs.first, first.countryCode.count == 2 else { return nil }
        let name = first.cities.first ?? countryDisplayName(first.countryCode)
        return viewModel.legs.count > 1 ? String(localized: "\(name) +\(viewModel.legs.count - 1) more") : name
    }

    private var whereBody: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            ForEach(Array(viewModel.legs.enumerated()), id: \.element.id) { index, leg in
                legCard(leg: leg, index: index)
            }
            Button {
                viewModel.addLeg()
            } label: {
                Label("Add Another Destination", systemImage: "plus")
                    .dnaFont(.button)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("You can also enter cities that aren’t on the list.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
                .padding(.bottom, DNASpacing.sm)
        }
    }

    private func legCard(leg: TripLegDraft, index: Int) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            HStack {
                Text("\(index + 1)")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextTertiary)
                Button {
                    countryPickerTarget = CountryPickerTarget(legID: leg.id)
                } label: {
                    HStack {
                        Text(leg.countryCode.isEmpty ? String(localized: "Choose Country · Required") : countryDisplayName(leg.countryCode))
                            .dnaFont(.cardTitle)
                            .foregroundStyle(leg.countryCode.isEmpty ? Color.dnaTextSecondary : Color.dnaTextPrimary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextTertiary)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if viewModel.legs.count > 1 {
                    Button {
                        viewModel.removeLeg(id: leg.id)
                    } label: {
                        Image(systemName: "xmark")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove destination \(index + 1)")
                }
            }
            if let binding = legBinding(id: leg.id) {
                TextField("City (e.g., Kyoto, Osaka)", text: binding.cityText)
                    .dnaFont(.body)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, DNASpacing.sm)
                    .frame(minHeight: 48)
                    .background(Color.dnaSurface2, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            }
            if !leg.countryCode.isEmpty, CountryCatalog.profiles[leg.countryCode.uppercased()] == nil {
                Text("Recommendation analysis for this country is coming soon. You can still add your trip.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
        .padding(DNASpacing.sm)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
    }

    private func legBinding(id: TripLegDraft.ID) -> Binding<TripLegDraft>? {
        guard let leg = viewModel.legs.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { viewModel.legs.first(where: { $0.id == id }) ?? leg },
            set: { updated in
                guard let index = viewModel.legs.firstIndex(where: { $0.id == id }) else { return }
                viewModel.legs[index] = updated
            }
        )
    }

    // MARK: - ③ 여행 컨셉

    private var conceptBody: some View {
        TripConceptPicker(
            primary: viewModel.primaryConcept,
            secondary: viewModel.secondaryConcepts,
            secondaryTitle: viewModel.secondaryTitle,
            onPrimary: { viewModel.selectPrimary($0) },
            onSecondary: { viewModel.toggleSecondary($0) }
        )
        .padding(.bottom, DNASpacing.sm)
    }

    // MARK: - 누구와

    private var companionBody: some View {
        let options: [Companion] = [.alone, .friends, .couple, .family, .colleagues]
        return VStack(alignment: .leading, spacing: DNASpacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DNASpacing.xs) {
                    ForEach(options, id: \.self) { companion in
                        DNATagChip(title: companion.label, isSelected: viewModel.companion == companion) {
                            // 같은 항목을 다시 누르면 입력하지 않은 상태로 돌아간다.
                            viewModel.companion = viewModel.companion == companion ? .unknown : companion
                        }
                    }
                }
            }
            Text("If left blank, no companion is recorded.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
                .padding(.bottom, DNASpacing.sm)
        }
    }

    // MARK: - ④ 언제 · 얼마나

    private var whenBody: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            ForEach(Array(viewModel.legs.enumerated()), id: \.element.id) { index, leg in
                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    if viewModel.legs.count > 1 {
                        Text("Destination \(index + 1)")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    DatePicker(
                        "Start Date",
                        selection: Binding(
                            get: { leg.startDate },
                            set: { viewModel.setStart($0, legIndex: index) }
                        ),
                        displayedComponents: .date
                    )
                    .dnaFont(.body)
                    DNAStepper(
                        label: String(localized: "How Long"),
                        valueText: viewModel.nights(of: leg) == 0 ? String(localized: "Same day") : String(localized: "\(viewModel.nights(of: leg)) nights, \(viewModel.nights(of: leg) + 1) days"),
                        value: Binding(
                            get: { viewModel.nights(of: leg) },
                            set: { viewModel.setNights($0, legIndex: index) }
                        ),
                        range: 0...60,
                        boxed: false
                    )
                }
                .padding(DNASpacing.sm)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            }
            Text("You can change the dates later in Edit Trip Info.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
                .padding(.bottom, DNASpacing.sm)
        }
    }

    private func countryDisplayName(_ code: String) -> String {
        let normalized = code.uppercased()
        if let profile = CountryCatalog.profiles[normalized] {
            return profile.displayName
        }
        return Locale.current.localizedString(forRegionCode: normalized) ?? normalized
    }
}

private struct CountryPickerTarget: Identifiable {
    let legID: TripLegDraft.ID
    var id: TripLegDraft.ID { legID }
}

/// 국가 검색 시트. 선택 즉시 닫힌다.
private struct CountryPickerSheet: View {
    @Binding var selectedCode: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CountrySelectionList(selectedCode: $selectedCode)
                .padding(.top, DNASpacing.sm)
                .background(AppCanvas())
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .tint(Color.dnaTextPrimary)
                    }
                }
        }
        .onChange(of: selectedCode) {
            dismiss()
        }
    }
}

/// 첫 예정·현재 여행 등록 직후, 무엇을 알려주는지 설명하고 고른 경우에만 알림 권한을 요청한다.
private struct NotificationPrimingSheet: View {
    let trips: any AppStore
    let placeTitle: String
    let onClose: () -> Void
    @State private var isRequesting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                Text("\(placeTitle) trip added")
                    .dnaFont(.heroTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("Want reminders during and after your trip?")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                Label("Keep one photo a day during your trip", systemImage: "camera")
                Label("Ask for a rating when the trip ends", systemImage: "star")
            }
            .dnaFont(.body)
            .foregroundStyle(Color.dnaTextPrimary)
            .padding(DNASpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
            Spacer(minLength: 0)
            if let errorMessage {
                Text(errorMessage).dnaFont(.caption).foregroundStyle(Color.dnaError)
            }
            Button("Turn On Notifications") {
                Task {
                    isRequesting = true
                    defer { isRequesting = false }
                    do {
                        let all = try await trips.trips()
                        if try await EvaluationNotificationService.enable(for: all) {
                            onClose()
                        } else {
                            errorMessage = String(localized: "To use notifications, please allow them in Settings.")
                        }
                    } catch {
                        errorMessage = String(localized: "Couldn’t schedule notifications. Please try again.")
                    }
                }
            }
            .buttonStyle(.dnaPrimary)
            .disabled(isRequesting)
            Button("Later") { onClose() }
                .buttonStyle(.dnaGhost)
                .frame(maxWidth: .infinity)
        }
        .padding(DNASpacing.gutter)
        .background(Color.dnaSheet)
        .interactiveDismissDisabled()
    }
}

#Preview("TripRegistrationView") {
    NavigationStack {
        TripRegistrationView(prefilledCountryCode: "JP")
    }
    .previewWithAppEnvironment()
}
