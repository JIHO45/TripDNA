import SwiftUI
import UIKit

/// UI-7: 여행 하루 한 장. 기록용이며 UTV에는 반영하지 않는다.
/// `dayIndex`를 주면 해당 일차를, 생략하면 오늘 일차를 대상으로 한다.
struct DailyPhotoView: View {
    let trip: Trip
    /// 1부터 시작하는 여행 일차. `nil`이면 오늘 기준.
    var dayIndex: Int? = nil
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss

    @State private var stage: Stage = .pick
    @State private var selectedPath: String?
    @State private var previewImage: UIImage?
    @State private var makeCroppedImage: (() -> UIImage?)?
    @State private var isReplacing = false
    @State private var isSaving = false
    @State private var saveFailed = false
    @State private var showConsentSheet = false
    @State private var showDoneCheck = false

    private static let consentAskedKey = "tripdna.dailyPhotoAutoFallbackAsked"

    private enum Stage {
        case pick
        case preview
        case reaction
        case done
    }

    private var resolvedDayIndex: Int {
        if let dayIndex { return max(1, dayIndex) }
        return Self.todayDayIndex(for: trip)
    }

    private var dayDate: Date {
        let start = trip.startedAt ?? trip.legs.first?.startDate ?? Date()
        let startDay = Calendar.current.startOfDay(for: start)
        return Calendar.current.date(byAdding: .day, value: resolvedDayIndex - 1, to: startDay) ?? startDay
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(dayDate)
    }

    var body: some View {
        ZStack {
            AppCanvas()
            stageContent
            if showDoneCheck {
                doneOverlay
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomCTA
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if stage == .pick || stage == .preview {
                ToolbarItem(placement: .topBarTrailing) {
                    DNASkipButton(isToday ? "오늘은 건너뛰기" : "나중에 하기") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showConsentSheet) {
            autoFallbackConsentSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .task(id: resolvedDayIndex) {
            let existing = (try? await dependencies.store.photos(tripID: trip.id))?
                .first { $0.tripDayIndex == resolvedDayIndex }
            isReplacing = existing != nil
        }
        .onDisappear {
            // 확정하지 않고 떠나면 고르기만 한 원본 파일을 정리한다.
            if stage == .pick || stage == .preview { discardSelectedFile() }
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .pick:
            pickStage
        case .preview:
            previewStage
        case .reaction:
            reactionStage
        case .done:
            Color.clear
        }
    }

    // MARK: - 사진 선택

    private var pickStage: some View {
        VStack(spacing: DNASpacing.lg) {
            header
            DailyPhotoLibraryPicker(day: dayDate, onSelect: { path in
                selectedPath = path
                previewImage = LocalPhotoStore.image(at: path)
                makeCroppedImage = nil
                withAnimation(.easeOut(duration: 0.2)) {
                    stage = .preview
                }
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 미리보기 · 확정

    private var previewStage: some View {
        VStack(spacing: DNASpacing.lg) {
            header
            Spacer(minLength: 0)
            if let previewImage {
                PhotoMoveScaleEditor(
                    image: previewImage,
                    makeCroppedImage: $makeCroppedImage
                )
                .padding(.horizontal, DNASpacing.lg)
            } else if let selectedPath {
                TripPhotoImage(storagePath: selectedPath)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
                    .padding(.horizontal, DNASpacing.lg)
            }
            Text("3:4 · 이 비율로 여행 상세와 회고에 보여요")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            Spacer(minLength: 0)
        }
    }

    // MARK: - 7D 반응

    private var reactionStage: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            Text(isToday ? "오늘은 어땠나요?" : "그날은 어땠나요?")
                .font(.title2.bold())
                .foregroundStyle(Color.dnaTextPrimary)
            Text("사진은 저장됐어요. 반응은 기록용이고 취향 지문에는 반영되지 않아요.")
                .font(.subheadline)
                .foregroundStyle(Color.dnaTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DNASpacing.lg)

            HStack(spacing: DNASpacing.sm) {
                reactionButton(title: "좋았어", value: .good)
                reactionButton(title: "그럭저럭", value: .neutral)
                reactionButton(title: "별로", value: .bad)
            }
            .padding(.horizontal, DNASpacing.lg)

            Spacer()
        }
    }

    private func reactionButton(title: String, value: DayReaction) -> some View {
        Button {
            Task { await finish(with: value) }
        } label: {
            Text(title)
                .dnaFont(.button)
                .foregroundStyle(Color.dnaTextPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                        .fill(Color.dnaSurface1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 하단 CTA

    @ViewBuilder
    private var bottomCTA: some View {
        switch stage {
        case .pick, .done:
            EmptyView()
        case .preview:
            DNABottomCTA {
                if saveFailed {
                    Text("사진을 남기지 못했어요. 다시 시도해 주세요.")
                        .font(.footnote)
                        .foregroundStyle(Color.dnaAction)
                        .frame(maxWidth: .infinity)
                }
                Button {
                    Task { await confirmPhoto() }
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text(saveFailed ? "다시 시도" : "이 사진으로 남기기")
                    }
                }
                .buttonStyle(.dnaPrimary(isDisabled: isSaving))
                .disabled(isSaving)

                Button("다른 사진 고르기") {
                    discardSelectedFile()
                    saveFailed = false
                    makeCroppedImage = nil
                    previewImage = nil
                    withAnimation { stage = .pick }
                }
                .buttonStyle(.dnaGhost)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        case .reaction:
            DNABottomCTA {
                Button("건너뛰기") {
                    Task { await finish(with: nil) }
                }
                .buttonStyle(.dnaGhost)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: - 공통

    private var header: some View {
        VStack(spacing: 6) {
            Text("\(trip.titleKo) · \(resolvedDayIndex)일차")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.dnaData)
            Text(isToday ? "오늘을 한 장으로 남긴다면?" : "\(resolvedDayIndex)일차를 한 장으로 남긴다면?")
                .font(.title3.bold())
                .foregroundStyle(Color.dnaTextPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DNASpacing.md)
        .padding(.horizontal, DNASpacing.lg)
    }

    private var doneOverlay: some View {
        VStack(spacing: DNASpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.dnaData.opacity(0.18))
                    .frame(width: 88, height: 88)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.dnaData)
            }
            Text(isToday ? "오늘의 한 장을 남겼어요" : "\(resolvedDayIndex)일차 사진을 남겼어요")
                .font(.headline)
                .foregroundStyle(Color.dnaTextPrimary)
        }
        .padding(DNASpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface1.opacity(0.96))
        )
        .transition(.scale.combined(with: .opacity))
    }

    /// UI-7C: 첫 확정 직후 1회만 노출하는 자동 후보 동의.
    private var autoFallbackConsentSheet: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Text("놓친 날은 그날 사진으로\n골라둘까요?")
                .dnaFont(.heroTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("여행 중에 앱을 열면, 한 장이 비어 있는 날을 그날 찍은 사진 한 장으로 채워둬요. 나중에 직접 바꿀 수 있어요.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            DNATrustPanel(text: "원본 사진은 사진첩에 그대로 있어요. 앱은 위치 정보를 지운 줄인 사본만 보관하고, iCloud 백업이 켜져 있으면 이 사본도 내 iCloud에 백업돼요.")
            Spacer(minLength: 0)
            Button("골라두기") {
                UserDefaults.standard.set(true, forKey: AutoPhotoFallbackService.consentKey)
                showConsentSheet = false
                withAnimation { stage = .reaction }
            }
            .buttonStyle(.dnaPrimary)

            Button("직접 고른 사진만") {
                UserDefaults.standard.set(false, forKey: AutoPhotoFallbackService.consentKey)
                showConsentSheet = false
                withAnimation { stage = .reaction }
            }
            .buttonStyle(.dnaGhost)
            .frame(maxWidth: .infinity)
        }
        .padding(DNASpacing.gutter)
        .background(Color.dnaSheet)
        .interactiveDismissDisabled()
        .onDisappear {
            // 시트를 닫으면 반응 단계로 진행한다.
            if stage == .preview {
                stage = .reaction
            }
        }
    }

    /// 확정 즉시 기록을 저장한다. 이후 반응 단계는 저장된 기록에 반응만 더한다.
    private func confirmPhoto() async {
        guard let selectedPath else { return }
        isSaving = true
        defer { isSaving = false }
        saveFailed = false

        // Move and Scale로 맞춘 영역을 크롭해 저장한다.
        let croppedPath = makeCroppedImage?().flatMap { try? LocalPhotoStore.saveImage($0) }
        let previousPath = try? await dependencies.store.photos(tripID: trip.id)
            .first { $0.tripDayIndex == resolvedDayIndex }?.storagePath
        do {
            // 교체일 때 반응 nil이면 기존 반응이 유지된다.
            _ = try await dependencies.dailyPhotoService.saveSelection(
                tripID: trip.id,
                tripDayIndex: resolvedDayIndex,
                storagePath: croppedPath ?? selectedPath,
                selection: .manual,
                reaction: nil
            )
        } catch {
            // 선택한 사진과 편집 상태는 그대로 두고 재시도하게 한다.
            if let croppedPath { try? LocalPhotoStore.delete(paths: [croppedPath]) }
            saveFailed = true
            return
        }
        // 교체된 이전 사진과 크롭 전 원본은 대표 사진·다른 기록에서 쓰지 않을 때만 지운다.
        try? await dependencies.deleteUnusedPhotoFiles([previousPath, selectedPath].compactMap { $0 })

        // 이미 남긴 날을 바꾸는 경우: 반응·동의는 건너뛰고 바로 끝낸다.
        if isReplacing {
            await finish(with: nil)
            return
        }

        let asked = UserDefaults.standard.bool(forKey: Self.consentAskedKey)
        if !asked {
            UserDefaults.standard.set(true, forKey: Self.consentAskedKey)
            showConsentSheet = true
        } else {
            withAnimation { stage = .reaction }
        }
    }

    private func discardSelectedFile() {
        guard let path = selectedPath else { return }
        selectedPath = nil
        Task { try? await dependencies.deleteUnusedPhotoFiles([path]) }
    }

    private func finish(with reaction: DayReaction?) async {
        guard stage != .done else { return }
        withAnimation(.spring(duration: 0.35)) {
            showDoneCheck = true
            stage = .done
        }
        // 사진은 이미 저장됐다. 반응 저장이 실패해도 기록은 남으므로 그대로 마친다.
        if let reaction {
            try? await dependencies.dailyPhotoService.updateReaction(
                tripID: trip.id,
                tripDayIndex: resolvedDayIndex,
                reaction: reaction
            )
        }
        try? await Task.sleep(for: .seconds(1.1))
        dismiss()
    }

    static func todayDayIndex(for trip: Trip) -> Int {
        let start = trip.startedAt ?? trip.legs.first?.startDate ?? Date()
        let days = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: start),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        return max(1, days + 1)
    }
}

#Preview("DailyPhotoView") {
    let trip = try! Trip(
        legs: [try! TripLeg(countryCode: "JP", startDate: Date().addingTimeInterval(-86400), endDate: Date().addingTimeInterval(86400 * 2))],
        companion: .alone,
        purpose: .leisure
    )
    return NavigationStack {
        DailyPhotoView(trip: trip, dayIndex: 1)
    }
    .previewWithAppEnvironment()
}
