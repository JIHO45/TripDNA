import SwiftUI

struct TripLegDraft: Identifiable {
    let id: UUID
    var countryCode: String
    var startDate: Date
    var endDate: Date

    init(
        id: UUID = UUID(),
        countryCode: String = "",
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    ) {
        self.id = id
        self.countryCode = countryCode
        self.startDate = startDate
        self.endDate = endDate
    }

    var hasDateError: Bool { endDate < startDate }
    var isComplete: Bool { countryCode.count == 2 && !hasDateError }
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
                startDate: $0.startDate,
                endDate: $0.endDate
            )
        }
        companion = trip.companion
        purpose = trip.purpose
    }

    var canSubmit: Bool {
        !legs.isEmpty && legs.allSatisfy(\.isComplete)
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
                try TripLeg(countryCode: $0.countryCode, startDate: $0.startDate, endDate: $0.endDate)
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
                _ = try await dependencies.tripService.updateTrip(
                    id: editingTripID,
                    legs: builtLegs,
                    companion: companion,
                    purpose: purpose
                )
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
            _ = try await dependencies.tripService.createTrip(
                legs: builtLegs,
                companion: companion,
                purpose: purpose
            )
            if shouldShowNotificationPriming {
                UserDefaults.standard.set(true, forKey: Self.notificationPrimingShownKey)
                showNotificationPriming = true
            } else {
                didSave = true
            }
        } catch let error as DomainValidationError
            where error == .invalidBestLeg || error == .invalidTagAttribution {
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
            VStack(alignment: .leading, spacing: DNASpacing.lg) {
                legsSection
                companionSection
                purposeSection
                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.dnaCoral)
                }
            }
            .padding(.horizontal, DNASpacing.lg)
            .padding(.vertical, DNASpacing.md)
        }
        .safeAreaInset(edge: .bottom) {
            DNABottomCTA {
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
        .dnaBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle(viewModel.isEditing ? "여행 수정" : "여행 등록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") { dismiss() }
                    .tint(Color.dnaSlate)
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
            NotificationPrimingSheet {
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

    // MARK: - 구간 (UI-6C-1)

    private var legsSection: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text("어디로 떠나나요?")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(Array(viewModel.legs.enumerated()), id: \.element.id) { index, leg in
                legCard(leg: leg, index: index)
            }

            Button {
                viewModel.addLeg()
            } label: {
                Label("나라 추가", systemImage: "plus.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dnaTeal)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                            .strokeBorder(Color.dnaTeal.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func legCard(leg: TripLegDraft, index: Int) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            HStack {
                Text(viewModel.legs.count > 1 ? "구간 \(index + 1)" : "여행지")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dnaTeal)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.dnaTeal.opacity(0.12), in: Capsule())
                Spacer()
                if viewModel.legs.count > 1 {
                    Button {
                        viewModel.removeLeg(id: leg.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.dnaSlate)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                countryPickerTarget = CountryPickerTarget(legID: leg.id)
            } label: {
                HStack {
                    Image(systemName: "globe.asia.australia")
                        .foregroundStyle(Color.dnaTeal)
                    Text(leg.countryCode.isEmpty ? "국가 선택 (필수)" : countryDisplayName(leg.countryCode))
                        .foregroundStyle(leg.countryCode.isEmpty ? Color.dnaSlate : .white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dnaSlate)
                }
                .padding(DNASpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }
            .buttonStyle(.plain)

            if !leg.countryCode.isEmpty, CountryCatalog.profiles[leg.countryCode.uppercased()] == nil {
                Text("이 나라의 추천 분석은 준비 중이에요. 등록은 그대로 할 수 있어요.")
                    .font(.caption2)
                    .foregroundStyle(Color.dnaSlate)
            }

            if let binding = legBinding(id: leg.id) {
                DatePicker("시작일", selection: binding.startDate, displayedComponents: .date)
                    .foregroundStyle(.white)
                DatePicker("종료일", selection: binding.endDate, displayedComponents: .date)
                    .foregroundStyle(.white)
            }

            if leg.hasDateError {
                Label("종료일은 시작일 이후여야 해요.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.dnaCoral)
            }
        }
        .padding(DNASpacing.md)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(leg.hasDateError ? Color.dnaCoral.opacity(0.5) : Color.dnaHairline, lineWidth: 1)
        )
    }

    private func legBinding(id: TripLegDraft.ID) -> Binding<TripLegDraft>? {
        guard let index = viewModel.legs.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { viewModel.legs[index] },
            set: { viewModel.legs[index] = $0 }
        )
    }

    // MARK: - 동행 (UI-6C-2)

    private var companionSection: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text("누구와 함께하나요?")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(spacing: DNASpacing.xs) {
                ForEach(Companion.allCases, id: \.self) { companion in
                    let isSelected = viewModel.companion == companion
                    Button {
                        viewModel.companion = companion
                    } label: {
                        Text(companion.labelKo)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Color.dnaTeal : .white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                                    .fill(isSelected ? Color.dnaTeal.opacity(0.14) : Color.dnaSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                                    .strokeBorder(isSelected ? Color.dnaTeal.opacity(0.7) : Color.dnaHairline, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 성격 (UI-6C-3)

    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text("이번 이동은 어떤 여행인가요?")
                .font(.headline)
                .foregroundStyle(.white)
            HStack(spacing: DNASpacing.xs) {
                DNAChoiceCard(text: "여행", isSelected: viewModel.purpose == .leisure) {
                    viewModel.purpose = .leisure
                }
                DNAChoiceCard(text: "출장·행사 등 의무", isSelected: viewModel.purpose == .obligation) {
                    viewModel.purpose = .obligation
                }
            }
            if viewModel.purpose == .obligation {
                Text("의무 여행은 취향 반영이 낮아져요.")
                    .font(.caption)
                    .foregroundStyle(Color.dnaSlate)
            }
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
                .background(AuroraBackground())
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") { dismiss() }
                            .tint(Color.dnaTeal)
                    }
                }
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedCode) {
            dismiss()
        }
    }
}

/// UI-6C-5: 첫 예정·현재 여행 등록 직후 알림 프라이밍. 알림 권한 요청은 스텁이다.
private struct NotificationPrimingSheet: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ZStack {
                Circle()
                    .fill(Color.dnaIndigo.opacity(0.2))
                    .frame(width: 88, height: 88)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.dnaTeal)
            }
            VStack(spacing: DNASpacing.xs) {
                Text("여행이 끝나면\n30초 평가를 알려드릴게요")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("평가할수록 다음 추천이 더 정확해져요.")
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaSlate)
            }
            .padding(.horizontal, DNASpacing.lg)
            Spacer(minLength: 0)
            DNABottomCTA {
                Button("알림 받기") { onClose() }
                    .buttonStyle(.dnaPrimary)
                Button("나중에") { onClose() }
                    .buttonStyle(.dnaGhost)
            }
        }
        .background(AuroraBackground())
        .interactiveDismissDisabled()
    }
}

#Preview("TripRegistrationView") {
    NavigationStack {
        TripRegistrationView(prefilledCountryCode: "JP")
    }
    .previewWithAppEnvironment()
}
