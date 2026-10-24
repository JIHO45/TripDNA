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

@Observable
final class TripRegistrationViewModel {
    /// UI-6C-5: 첫 예정·현재 여행 등록 성공 시 1회만 노출하는 알림 프라이밍.
    static let notificationPrimingShownKey = "tripdna.evalNotificationPrimingShown"

    /// `nil`이면 신규 등록, 값이 있으면 해당 여행 수정.
    let editingTripID: String?
    var legs: [TripLegDraft]
    var companion: Companion = .alone
    var purpose: TripPurpose = .leisure
    var primaryConcept: TripConcept?
    var secondaryConcepts: [TripConcept] = []
    var isSubmitting = false
    var errorMessage: String?
    var duplicateWarning = false
    var didSave = false
    var showNotificationPriming = false

    var isEditing: Bool { editingTripID != nil }

    init(prefilledCountryCode: String?) {
        editingTripID = nil
        var leg = TripLegDraft()
        if let prefilledCountryCode {
            leg.countryCode = prefilledCountryCode.uppercased()
        }
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

    var canSubmit: Bool {
        !legs.isEmpty && legs.allSatisfy(\.isComplete)
            && (purpose == .obligation || primaryConcept != nil)
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

    var primaryCTATitle: String {
        if isEditing { return "변경 저장" }
        return isPastTrip ? "과거 여행 저장" : "여행 등록"
    }

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
            try? await EvaluationNotificationService.scheduleIfEnabled(for: created)
            if shouldShowNotificationPriming {
                UserDefaults.standard.set(true, forKey: Self.notificationPrimingShownKey)
                showNotificationPriming = true
            } else {
                didSave = true
            }
        } catch let error as DomainValidationError
            where error == .invalidBestLeg || error == .invalidTagAttribution || error == .invalidCityReview {
            errorMessage = "평가에 쓰인 나라가 빠져 있어요. 평가된 여행은 그 나라를 남겨 주세요."
        } catch {
            errorMessage = "여행 정보를 확인해주세요. 국가와 날짜가 올바른지 확인이 필요해요."
        }
    }

    private var shouldShowNotificationPriming: Bool {
        !isEditing && !isPastTrip && !UserDefaults.standard.bool(forKey: Self.notificationPrimingShownKey)
    }
}

/// UI-6C: 구간(다국가)·동행·성격을 입력하는 여행 등록·수정 폼.
struct TripRegistrationView: View {
    var onSaved: (() -> Void)?
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var viewModel: TripRegistrationViewModel
    @State private var countryPickerTarget: CountryPickerTarget?

    init(prefilledCountryCode: String?, onCreated: (() -> Void)? = nil) {
        self.onSaved = onCreated
        _viewModel = State(initialValue: TripRegistrationViewModel(prefilledCountryCode: prefilledCountryCode))
    }

    init(editing trip: Trip, onSaved: (() -> Void)? = nil) {
        self.onSaved = onSaved
        _viewModel = State(initialValue: TripRegistrationViewModel(editing: trip))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.xl) {
                introduction
                legsSection
                companionSection
                purposeSection
                if viewModel.purpose == .leisure {
                    conceptSection
                }
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.dnaError)
                }
            }
            .padding(.horizontal, DNASpacing.lg)
            .padding(.vertical, DNASpacing.md)
        }
        .safeAreaInset(edge: .bottom, spacing: DNASpacing.md) {
            VStack(spacing: DNASpacing.sm) {
                Text(viewModel.canSubmit ? "여행지와 일정을 확인한 뒤 저장해주세요."
                     : viewModel.legs.allSatisfy(\.isComplete) ? "무엇을 하러 가는지 골라주세요."
                     : "여행지를 선택하고 일정을 확인해주세요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await viewModel.submit(dependencies) }
                } label: {
                    if viewModel.isSubmitting {
                        ProgressView().tint(Color.dnaCanvas)
                    } else {
                        Text(viewModel.primaryCTATitle)
                    }
                }
                .buttonStyle(.dnaPrimary(isDisabled: !viewModel.canSubmit || viewModel.isSubmitting))
                .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DNASpacing.lg)
            .padding(.vertical, DNASpacing.md)
            .background {
                ZStack {
                    if reduceTransparency {
                        Color.dnaCanvas
                    } else {
                        Rectangle().fill(.regularMaterial)
                        Color.dnaCanvas.opacity(0.72)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.dnaDivider)
                    .frame(height: 0.5)
                    .allowsHitTesting(false)
            }
        }
        .dnaBackground()
        .tint(Color.dnaTextPrimary)
        .disabled(viewModel.isSubmitting)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle(viewModel.isEditing ? "여행 수정" : "여행 등록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") { dismiss() }
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
            NotificationPrimingSheet(trips: dependencies.store) {
                viewModel.showNotificationPriming = false
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .alert("겹치는 여행이 있어요", isPresented: $viewModel.duplicateWarning) {
            Button(viewModel.isEditing ? "계속 저장" : "계속 등록", role: .destructive) {
                Task { await viewModel.submit(dependencies, ignoreDuplicate: true) }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text(
                viewModel.isEditing
                    ? "같은 국가·기간의 다른 여행이 있어요. 그래도 저장할까요?"
                    : "같은 국가·기간의 여행이 이미 있어요. 그래도 등록할까요?"
            )
        }
        .onChange(of: viewModel.didSave) {
            if viewModel.didSave {
                onSaved?()
                dismiss()
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text(viewModel.isEditing ? "여행의 기록을\n다듬어볼까요?" : "다음 여행도,\n지난 여행도 한곳에.")
                .font(.largeTitle.weight(.regular))
                .foregroundStyle(Color.dnaTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("여행지와 일정, 함께한 사람을 남겨주세요.")
                .font(.subheadline)
                .foregroundStyle(Color.dnaTextSecondary)
        }
        .padding(.top, DNASpacing.sm)
    }

    private var legsSection: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            sectionHeading("여행지와 일정", subtitle: "여러 나라를 방문한다면 순서대로 추가해주세요.")
            ForEach(Array(viewModel.legs.enumerated()), id: \.element.id) { index, leg in
                legCard(leg: leg, index: index)
            }
            Button {
                viewModel.addLeg()
            } label: {
                Label("다음 여행지 추가", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.dnaTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.dnaTextPrimary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private func legCard(leg: TripLegDraft, index: Int) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            HStack {
                Text(String(format: "%02d", index + 1))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.dnaTextSecondary)
                Text("여행지")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                Spacer()
                if viewModel.legs.count > 1 {
                    Button {
                        viewModel.removeLeg(id: leg.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.dnaTextSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("여행지 \(index + 1) 삭제")
                }
            }

            Button {
                countryPickerTarget = CountryPickerTarget(legID: leg.id)
            } label: {
                HStack(spacing: DNASpacing.sm) {
                    Image(systemName: "globe.asia.australia")
                        .font(.title2.weight(.light))
                        .frame(width: 44, height: 44)
                        .background(Color.dnaSurface2, in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(leg.countryCode.isEmpty ? "어디로 떠나나요?" : countryDisplayName(leg.countryCode))
                            .font(.title3.weight(.medium))
                        Text(leg.countryCode.isEmpty ? "국가 선택 · 필수" : "여행지 변경")
                            .font(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                .foregroundStyle(Color.dnaTextPrimary)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle().fill(Color.dnaDivider).frame(height: 1)

            if let binding = legBinding(id: leg.id) {
                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    TextField("도시 (예: 도쿄, 오사카)", text: binding.cityText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding(.horizontal, DNASpacing.sm)
                        .frame(minHeight: 48)
                        .background(Color.dnaSurface2, in: RoundedRectangle(cornerRadius: 14))
                    Text("방문할 도시를 남겨주세요. 여러 도시는 쉼표로 구분하세요.")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }

                VStack(spacing: DNASpacing.sm) {
                    DatePicker("시작일", selection: binding.startDate, displayedComponents: .date)
                    DatePicker("종료일", selection: binding.endDate, displayedComponents: .date)
                }
                .datePickerStyle(.compact)
                .font(.subheadline)
                .foregroundStyle(Color.dnaTextSecondary)
            }

            if leg.hasDateError {
                Label("종료일은 시작일 이후여야 해요.", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(Color.dnaError)
            }
            if !leg.countryCode.isEmpty, CountryCatalog.profiles[leg.countryCode.uppercased()] == nil {
                Text("이 나라의 추천 분석은 준비 중이에요. 등록은 그대로 할 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
        .padding(DNASpacing.md)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: DNARadius.card)
                .strokeBorder(leg.hasDateError ? Color.dnaError.opacity(0.5) : Color.dnaDivider, lineWidth: 1)
        }
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

    private var companionSection: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            sectionHeading("누구와 함께하나요?", subtitle: "함께한 사람에 따라 여행의 모습도 달라지죠.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DNASpacing.sm) {
                ForEach(Companion.allCases, id: \.self) { companion in
                    selectionButton(
                        companion.labelKo,
                        icon: companionIcon(companion),
                        isSelected: viewModel.companion == companion
                    ) {
                        viewModel.companion = companion
                    }
                }
            }
        }
    }

    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            sectionHeading("어떤 여행인가요?", subtitle: "여행의 목적에 맞게 취향을 반영할게요.")
            VStack(spacing: DNASpacing.sm) {
                selectionButton("휴가 · 여행", icon: "sun.max", isSelected: viewModel.purpose == .leisure) {
                    viewModel.purpose = .leisure
                }
                selectionButton("출장 · 가족 방문", icon: "briefcase", isSelected: viewModel.purpose == .obligation) {
                    viewModel.purpose = .obligation
                }
            }
            if viewModel.purpose == .obligation {
                Text("가야 해서 간 여행은 컨셉 없이 방문 기록만 남겨요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
    }

    private var conceptSection: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            sectionHeading("무엇을 하러 가나요?", subtitle: "가장 큰 목적 하나를 골라주세요.")
            DNAFlowLayout(spacing: 8) {
                ForEach(TripConcept.allCases, id: \.self) { concept in
                    DNATagChip(title: concept.labelKo, isSelected: viewModel.primaryConcept == concept) {
                        viewModel.selectPrimary(concept)
                    }
                }
            }
            if let primary = viewModel.primaryConcept {
                Text("함께 즐긴 것 (최대 2개, 선택)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dnaTextSecondary)
                DNAFlowLayout(spacing: 8) {
                    ForEach(TripConcept.allCases.filter { $0 != primary }, id: \.self) { concept in
                        let selected = viewModel.secondaryConcepts.contains(concept)
                        let locked = !selected && viewModel.secondaryConcepts.count >= 2
                        DNATagChip(title: concept.labelKo, isSelected: selected) {
                            viewModel.toggleSecondary(concept)
                        }
                        .disabled(locked)
                        .opacity(locked ? 0.35 : 1)
                    }
                }
            }
        }
    }

    private func selectionButton(_ title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? Color.dnaTextPrimary : Color.dnaTextTertiary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isSelected ? Color.dnaTextPrimary : Color.dnaTextSecondary)
            .padding(DNASpacing.md)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(isSelected ? Color.dnaElevated : Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: DNARadius.control)
                    .strokeBorder(isSelected ? Color.dnaTextSecondary.opacity(0.5) : Color.dnaDivider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func companionIcon(_ companion: Companion) -> String {
        switch companion {
        case .alone: "person"
        case .couple: "person.2"
        case .family: "house"
        case .friends: "person.3"
        }
    }

    private func countryDisplayName(_ code: String) -> String {
        let normalized = code.uppercased()
        if let profile = CountryCatalog.profiles[normalized] {
            return profile.nameKo
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
                        Button("완료") { dismiss() }
                            .tint(Color.dnaTextPrimary)
                    }
                }
        }
        .onChange(of: selectedCode) {
            dismiss()
        }
    }
}

/// 첫 예정·현재 여행 등록 직후 알림 권한을 요청한다.
private struct NotificationPrimingSheet: View {
    let trips: any AppStore
    let onClose: () -> Void
    @State private var isRequesting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(Color.dnaSurface2)
                    .frame(width: 88, height: 88)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.dnaTextPrimary)
            }
            VStack(spacing: DNASpacing.xs) {
                Text("여행이 끝나면\n30초 평가를 알려드릴게요")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("평가할수록 다음 추천이 더 정확해져요.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .padding(.horizontal, DNASpacing.lg)
            Spacer(minLength: 0)
            DNABottomCTA {
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(Color.dnaAction)
                }
                Button("알림 받기") {
                    Task {
                        isRequesting = true
                        defer { isRequesting = false }
                        do {
                            let all = try await trips.trips()
                            if try await EvaluationNotificationService.enable(for: all) {
                                onClose()
                            } else {
                                errorMessage = "알림을 사용하려면 설정에서 허용해 주세요."
                            }
                        } catch {
                            errorMessage = "알림을 예약하지 못했어요. 다시 시도해 주세요."
                        }
                    }
                }
                    .buttonStyle(.dnaPrimary)
                    .disabled(isRequesting)
                Button("나중에") { onClose() }
                    .buttonStyle(.dnaGhost)
            }
        }
        .background(AppCanvas())
        .interactiveDismissDisabled()
    }
}

#Preview("TripRegistrationView") {
    NavigationStack {
        TripRegistrationView(prefilledCountryCode: "JP")
    }
    .previewWithAppEnvironment()
}
