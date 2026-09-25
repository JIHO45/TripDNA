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
    @State private var reaction: DayReaction?
    @State private var existingReaction: DayReaction?
    @State private var isReplacing = false
    @State private var isSaving = false
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
            AuroraBackground()
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
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .preferredColorScheme(.dark)
        }
        .task(id: resolvedDayIndex) {
            let existing = (try? await dependencies.store.photos(tripID: trip.id))?
                .first { $0.tripDayIndex == resolvedDayIndex }
            isReplacing = existing != nil
            existingReaction = existing?.dayReaction
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
            Spacer(minLength: 0)
        }
    }

    // MARK: - 7D 반응

    private var reactionStage: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            Text(isToday ? "오늘은 어땠나요?" : "그날은 어땠나요?")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("기록용이에요. 취향 지문에는 반영되지 않아요.")
                .font(.subheadline)
                .foregroundStyle(Color.dnaSlate)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DNASpacing.lg)

            HStack(spacing: DNASpacing.sm) {
                reactionButton(title: "좋았어", value: .good, accent: .dnaTeal)
                reactionButton(title: "그럭저럭", value: .neutral, accent: .dnaAmber)
                reactionButton(title: "별로", value: .bad, accent: .dnaCoral)
            }
            .padding(.horizontal, DNASpacing.lg)

            Spacer()
        }
    }

    private func reactionButton(title: String, value: DayReaction, accent: Color) -> some View {
        Button {
            Task { await finish(with: value) }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                        .fill(accent.opacity(0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                        .strokeBorder(accent.opacity(0.45), lineWidth: 1)
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
                Button {
                    Task { await confirmPhoto() }
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("이 사진으로 남기기")
                    }
                }
                .buttonStyle(.dnaPrimary(isDisabled: isSaving))
                .disabled(isSaving)

                Button("다른 사진 고르기") {
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
                .foregroundStyle(Color.dnaTeal)
            Text(isToday ? "오늘을 한 장으로 남긴다면?" : "\(resolvedDayIndex)일차를 한 장으로 남긴다면?")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DNASpacing.md)
        .padding(.horizontal, DNASpacing.lg)
    }

    private var doneOverlay: some View {
        VStack(spacing: DNASpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.dnaTeal.opacity(0.18))
                    .frame(width: 88, height: 88)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.dnaTeal)
            }
            Text(isToday ? "오늘의 한 장을 남겼어요" : "\(resolvedDayIndex)일차 사진을 남겼어요")
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(DNASpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface.opacity(0.96))
        )
        .transition(.scale.combined(with: .opacity))
    }

    /// UI-7C: 첫 확정 직후 1회만 노출하는 자동 후보 동의.
    private var autoFallbackConsentSheet: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer(minLength: 0)
            Text("앱을 열 때 비어 있는 날의 사진을 골라둘까요?")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DNASpacing.lg)
            DNATrustPanel(text: "EXIF 위치는 제거되고 리사이즈본만 저장돼요.")
                .padding(.horizontal, DNASpacing.lg)
            Spacer(minLength: 0)
            DNABottomCTA {
                Button("자동으로 골라두기") {
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
                .padding(.vertical, 14)
            }
        }
        .background(AuroraBackground())
        .interactiveDismissDisabled()
        .onDisappear {
            // 시트를 닫으면 반응 단계로 진행한다.
            if stage == .preview {
                stage = .reaction
            }
        }
    }

    private func confirmPhoto() async {
        guard selectedPath != nil else { return }
        isSaving = true
        defer { isSaving = false }

        // Move and Scale로 맞춘 영역을 크롭해 저장한다.
        if let cropped = makeCroppedImage?(),
           let croppedPath = try? LocalPhotoStore.saveImage(cropped) {
            selectedPath = croppedPath
            previewImage = cropped
        }

        // 이미 남긴 날을 바꾸는 경우: 반응·동의는 건너뛰고 바로 저장한다.
        if isReplacing {
            await finish(with: existingReaction)
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

    private func finish(with reaction: DayReaction?) async {
        guard let selectedPath else { return }
        isSaving = true
        defer { isSaving = false }
        _ = try? await dependencies.dailyPhotoService.saveSelection(
            tripID: trip.id,
            tripDayIndex: resolvedDayIndex,
            storagePath: selectedPath,
            selection: .manual,
            reaction: reaction
        )
        withAnimation(.spring(duration: 0.35)) {
            showDoneCheck = true
            stage = .done
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
