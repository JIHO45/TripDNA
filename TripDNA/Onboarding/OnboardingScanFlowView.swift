import Photos
import SwiftUI
import UIKit

// MARK: - 1B-2 사진첩 프라이밍

struct OnboardingPhotoPrimingView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                onBack: { viewModel.goBack() }
            )
            Spacer()
            MapPinsMotifView()
            VStack(spacing: DNASpacing.sm) {
                Text("다녀온 곳을\n지도에서 찾아드릴까요?")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("사진 위치로 국가와 시기를 자동으로 채워드려요")
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .padding(.top, DNASpacing.lg)

            DNATrustPanel(text: "사진 원본은 업로드하지 않아요. 위치 좌표는 국가 확인에 사용돼요.")
                .padding(.horizontal, DNASpacing.lg)
                .padding(.top, DNASpacing.lg)
            Spacer()
            DNABottomCTA {
                Button {
                    viewModel.startPhotoScan()
                } label: {
                    Text("사진 접근 허용하고 찾기")
                }
                .buttonStyle(.dnaPrimary)

                Button("직접 입력으로 바꾸기") {
                    viewModel.selectEntryMode(.manual)
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }
}

/// 도트 지도 위로 틸 핀이 내려앉는 프라이밍 비주얼.
private struct MapPinsMotifView: View {
    @State private var isDropped = false

    private let pins: [(x: CGFloat, y: CGFloat, delay: Double)] = [
        (0.24, 0.32, 0.1), (0.48, 0.55, 0.3), (0.68, 0.28, 0.5), (0.82, 0.62, 0.7)
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface1)
            DotGridView()
                .clipShape(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            GeometryReader { proxy in
                ForEach(Array(pins.enumerated()), id: \.offset) { _, pin in
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.dnaData)
                        .shadow(color: .dnaData.opacity(0.7), radius: 6)
                        .position(x: proxy.size.width * pin.x, y: proxy.size.height * pin.y)
                        .offset(y: isDropped ? 0 : -14)
                        .opacity(isDropped ? 1 : 0)
                        .animation(.spring(duration: 0.6).delay(pin.delay), value: isDropped)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaDivider, lineWidth: 1)
        )
        .frame(height: 190)
        .padding(.horizontal, DNASpacing.lg)
        .onAppear { isDropped = true }
    }
}

private struct DotGridView: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 14
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: 2.4, height: 2.4)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.1)))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

// MARK: - 1B-4 스캔 연출 (0건 결과 포함)

struct OnboardingPhotoScanningView: View {
    let viewModel: OnboardingViewModel

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if viewModel.scanFoundNothing {
                noResultView
            } else {
                scanningView
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshPhotoAccessAfterReturning() }
        }
    }

    private var scanningView: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            ScanPulseView()
            Text(viewModel.scanStatusText)
                .font(.headline)
                .foregroundStyle(.white)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.scanStatusText)
            ProgressView()
                .tint(Color.dnaData)
            Spacer()
            DNABottomCTA {
                Button("취소") {
                    viewModel.cancelPhotoScan()
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }

    private var noResultView: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                onBack: { viewModel.goBack() }
            )
            Spacer()
            EmptyStateView(
                systemImage: "photo.badge.exclamationmark",
                title: viewModel.isPhotoAccessLimited ? "선택한 사진에서는 여행을 찾지 못했어요" : "여행 기록을 찾지 못했어요",
                message: "위치 정보가 있는 여행 사진이 없어도 괜찮아요.\n다른 방법으로 지문을 만들 수 있어요."
            )
            .frame(maxHeight: 320)
            if viewModel.isPhotoAccessLimited {
                LimitedPhotoAccessBanner(
                    message: "지금은 직접 고른 사진만 볼 수 있어요. 모든 사진을 허용하면 사진첩 전체에서 여행을 찾아드려요.",
                    onSelectMore: { viewModel.presentLimitedPhotoPicker() }
                )
                .padding(.horizontal, DNASpacing.lg)
            }
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.dnaAction)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DNASpacing.lg)
            }
            Spacer()
            DNABottomCTA {
                Button {
                    viewModel.selectEntryMode(.manual)
                } label: {
                    Text("직접 등록")
                }
                .buttonStyle(.dnaPrimary)

                Button("사진 퀴즈로 시작") {
                    viewModel.selectEntryMode(.quiz)
                }
                .buttonStyle(.dnaGhost)
            }
        }
    }
}

/// 스캔 중 맥동하는 지문 링 모션.
private struct ScanPulseView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .strokeBorder(Color.dnaData.opacity(0.5 - Double(ring) * 0.14), lineWidth: 1.4)
                    .frame(width: 88 + CGFloat(ring) * 36, height: 88 + CGFloat(ring) * 36)
                    .scaleEffect(isPulsing ? 1.06 : 0.94)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(ring) * 0.18),
                        value: isPulsing
                    )
            }
            Image(systemName: "photo.stack")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.dnaData)
        }
        .frame(width: 190, height: 190)
        .shadow(color: .dnaData.opacity(0.35), radius: 24)
        .onAppear { isPulsing = true }
    }
}

// MARK: - 1B-5 여행 확인 카드 루프

struct OnboardingScanCardLoopView: View {
    let viewModel: OnboardingViewModel
    let dependencies: AppDependencies
    let session: SessionStore

    @State private var satisfaction: Int?
    @State private var showComparison = false
    @State private var isAdvancing = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(
                progress: viewModel.progress,
                counterText: counterText,
                onBack: { handleBack() }
            )

            if viewModel.isPhotoAccessLimited {
                LimitedPhotoAccessBanner(
                    message: "선택한 사진에서만 여행을 찾았어요. 모든 사진을 허용하면 더 많은 여행을 찾을 수 있어요.",
                    onSelectMore: { viewModel.presentLimitedPhotoPicker() }
                )
                .padding(.horizontal, DNASpacing.lg)
                .padding(.top, DNASpacing.xs)
            }

            if let draft = viewModel.currentScanDraft {
                Spacer(minLength: DNASpacing.md)
                Group {
                    if showComparison, let anchor = viewModel.scanAnchorDraft {
                        comparisonSection(current: draft, anchor: anchor)
                    } else {
                        satisfactionSection(draft: draft)
                    }
                }
                .id("\(draft.id)-\(showComparison)")
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                Spacer(minLength: DNASpacing.md)

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color.dnaAction)
                        .padding(.bottom, DNASpacing.xs)
                }

                DNABottomCTA {
                    Button("이 여행 아니에요") {
                        removeCurrentTrip()
                    }
                    .buttonStyle(.dnaGhost)

                    Button("나머지는 나중에") {
                        finishEarly()
                    }
                    .buttonStyle(.dnaGhost)
                    .disabled(!viewModel.canFinishScanEarly)
                    .opacity(viewModel.canFinishScanEarly ? 1 : 0.35)
                }
            } else {
                LoadingView()
            }
        }
        .animation(.easeInOut(duration: 0.28), value: showComparison)
        .animation(.easeInOut(duration: 0.28), value: viewModel.scanCardIndex)
        .onChange(of: viewModel.scanCardIndex) {
            satisfaction = nil
            showComparison = false
            isAdvancing = false
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshPhotoAccessAfterReturning() }
        }
    }

    private var counterText: String {
        "\(min(viewModel.scanCardIndex + 1, viewModel.photoScanDrafts.count)) / \(viewModel.photoScanDrafts.count)"
    }

    // MARK: 만족도 원탭

    private func satisfactionSection(draft: ManualTripDraft) -> some View {
        VStack(spacing: DNASpacing.lg) {
            ScanTripCard(draft: draft)
                .padding(.horizontal, DNASpacing.lg)

            VStack(spacing: DNASpacing.md) {
                Text("이 여행, 얼마나 좋았나요?")
                    .font(.headline)
                    .foregroundStyle(.white)
                DNASatisfactionEmojiRow(
                    satisfaction: $satisfaction,
                    onSelect: { value in
                        handleSatisfaction(value)
                    }
                )
                .padding(.horizontal, DNASpacing.lg)
            }
        }
    }

    private func handleSatisfaction(_ value: Int) {
        guard !isAdvancing else { return }
        viewModel.setScanSatisfaction(value)
        if viewModel.scanAnchorDraft != nil {
            // 두 번째 카드부터: 원탭 직후 같은 흐름에서 서열 비교 1회.
            isAdvancing = true
            Task {
                try? await Task.sleep(for: .seconds(0.35))
                showComparison = true
                isAdvancing = false
            }
        } else {
            advance(after: 0.4)
        }
    }

    // MARK: 서열 비교

    private func comparisonSection(current: ManualTripDraft, anchor: ManualTripDraft) -> some View {
        VStack(spacing: DNASpacing.lg) {
            Text("예전 \(CountryCatalog.name(for: anchor.countryCode))보다 좋았나요?")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DNASpacing.lg)

            ZStack {
                HStack(spacing: DNASpacing.sm) {
                    ComparisonTripCard(draft: current, caption: "이번에 확인한 여행") {
                        answerComparison(.better)
                    }
                    ComparisonTripCard(draft: anchor, caption: "예전 여행") {
                        answerComparison(.worse)
                    }
                }
                .padding(.horizontal, DNASpacing.lg)

                Text("VS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dnaTextSecondary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.dnaSurface2))
                    .overlay(Circle().strokeBorder(Color.dnaDivider, lineWidth: 1))
            }

            Button("비슷했어요 / 기억 안 나요") {
                answerComparison(.skipped)
            }
            .buttonStyle(.dnaGhost)
        }
    }

    private func answerComparison(_ result: ComparisonResult) {
        guard !isAdvancing else { return }
        viewModel.setScanComparison(result)
        advance(after: 0.25)
    }

    // MARK: 진행

    private func advance(after delay: Double) {
        isAdvancing = true
        Task {
            try? await Task.sleep(for: .seconds(delay))
            await viewModel.advanceScanCard(dependencies, session: session)
            isAdvancing = false
        }
    }

    private func removeCurrentTrip() {
        guard !isAdvancing else { return }
        isAdvancing = true
        Task {
            await viewModel.removeCurrentScanDraft(dependencies, session: session)
            isAdvancing = false
            satisfaction = nil
            showComparison = false
        }
    }

    private func finishEarly() {
        guard !isAdvancing else { return }
        isAdvancing = true
        Task {
            await viewModel.finishScanEarly(dependencies, session: session)
            isAdvancing = false
        }
    }

    private func handleBack() {
        if showComparison {
            showComparison = false
        } else if viewModel.scanCardIndex > 0 {
            viewModel.scanCardIndex -= 1
        } else {
            viewModel.goBack()
        }
    }
}

/// 스캔으로 찾은 여행 1건을 보여주는 사진 중심 카드. 묶인 사진 전체를 좌우로 넘겨본다.
private struct ScanTripCard: View {
    let draft: ManualTripDraft

    @State private var page = 0

    private var photoIDs: [String] { draft.photoAssetIDs }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            photoPager

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.25), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)

            tripInfo
                .padding(DNASpacing.md)
                .allowsHitTesting(false)
        }
        .frame(minHeight: 240, maxHeight: 320)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if photoIDs.count > 1 {
                Text("\(page + 1) / \(photoIDs.count)")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(DNASpacing.sm)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.15), value: page)
            }
        }
        .shadow(color: Color.dnaTextTertiary.opacity(0.22), radius: 24, y: 10)
    }

    @ViewBuilder
    private var photoPager: some View {
        if photoIDs.isEmpty {
            ScanTripPhotoFallback(countryCode: draft.countryCode, flagSize: 72)
        } else {
            TabView(selection: $page) {
                ForEach(Array(photoIDs.enumerated()), id: \.offset) { index, assetID in
                    PhotoAssetImage(localIdentifier: assetID, targetSize: CGSize(width: 900, height: 900))
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private var tripInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: DNASpacing.xs) {
                Text(OnboardingFormat.flagEmoji(for: draft.countryCode))
                    .font(.title)
                Text(CountryCatalog.name(for: draft.countryCode))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            HStack(spacing: 6) {
                Text(OnboardingFormat.periodText(start: draft.startDate, end: draft.endDate))
                if !photoIDs.isEmpty {
                    Text("·")
                    Label("사진 \(photoIDs.count)장", systemImage: "photo.on.rectangle")
                        .labelStyle(.titleAndIcon)
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.85))
        }
        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
    }
}

/// 제한된 사진 접근일 때 전체 허용(설정) 또는 사진 추가 선택을 안내하는 배너.
private struct LimitedPhotoAccessBanner: View {
    let message: String
    let onSelectMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            HStack(alignment: .top, spacing: DNASpacing.sm) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.body)
                    .foregroundStyle(Color.dnaWarning)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DNASpacing.md) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("모든 사진 허용하기", destination: url)
                        .foregroundStyle(Color.dnaData)
                }
                Button("사진 더 고르기", action: onSelectMore)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .font(.footnote.weight(.semibold))
            .padding(.leading, 28)
        }
        .padding(DNASpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                .fill(Color.dnaWarning.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                .strokeBorder(Color.dnaWarning.opacity(0.25), lineWidth: 1)
        )
    }
}

/// 사진이 없거나 불러오지 못했을 때의 대체 비주얼 (국기 + 그라데이션).
private struct ScanTripPhotoFallback: View {
    let countryCode: String
    var flagSize: CGFloat = 40

    var body: some View {
        LinearGradient(
            colors: [Color.dnaTextTertiary.opacity(0.45), Color.dnaData.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(OnboardingFormat.flagEmoji(for: countryCode))
                .font(.system(size: flagSize))
        )
    }
}

/// `PHAsset.localIdentifier`로 사진첩 이미지를 직접 불러와 채워 그린다 (파일로 복사하지 않음).
private struct PhotoAssetImage: View {
    let localIdentifier: String
    let targetSize: CGSize

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Color.dnaSurface1
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                } else if didFail {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(Color.dnaTextSecondary.opacity(0.7))
                } else {
                    ProgressView().tint(.white.opacity(0.7))
                }
            }
            .clipped()
            .task(id: localIdentifier) {
                await load()
            }
    }

    @MainActor
    private func load() async {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            didFail = true
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        for await delivered in Self.imageStream(for: asset, targetSize: targetSize, options: options) {
            withAnimation(.easeOut(duration: 0.2)) { image = delivered }
        }
        if image == nil && !Task.isCancelled { didFail = true }
    }

    /// opportunistic 요청은 저화질 → 고화질 순으로 여러 번 콜백되므로 스트림으로 흘려보낸다.
    /// 화면을 벗어나 task가 취소되면 스트림 종료와 함께 사진 요청도 취소한다.
    private static func imageStream(
        for asset: PHAsset,
        targetSize: CGSize,
        options: PHImageRequestOptions
    ) -> AsyncStream<UIImage> {
        let (stream, continuation) = AsyncStream<UIImage>.makeStream()
        let requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            if let image { continuation.yield(image) }
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !isDegraded || image == nil { continuation.finish() }
        }
        continuation.onTermination = { termination in
            if case .cancelled = termination {
                PHImageManager.default().cancelImageRequest(requestID)
            }
        }
        return stream
    }
}

/// 서열 비교용 세로형 여행 카드.
private struct ComparisonTripCard: View {
    let draft: ManualTripDraft
    let caption: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DNASpacing.sm) {
                coverPhoto
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if !draft.photoAssetIDs.isEmpty {
                            Text(OnboardingFormat.flagEmoji(for: draft.countryCode))
                                .font(.title3)
                                .padding(6)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(6)
                        }
                    }
                VStack(spacing: 2) {
                    Text(CountryCatalog.name(for: draft.countryCode))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(OnboardingFormat.periodText(start: draft.startDate, end: draft.endDate))
                        .font(.caption2)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(Color.dnaTextSecondary.opacity(0.8))
                }
            }
            .padding(DNASpacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(Color.dnaSurface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .strokeBorder(Color.dnaDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// 여행 중간 무렵 사진을 대표로 쓴다 (첫 장은 공항·이동 사진인 경우가 많음).
    @ViewBuilder
    private var coverPhoto: some View {
        let ids = draft.photoAssetIDs
        if ids.isEmpty {
            ScanTripPhotoFallback(countryCode: draft.countryCode)
        } else {
            PhotoAssetImage(localIdentifier: ids[ids.count / 2], targetSize: CGSize(width: 500, height: 500))
        }
    }
}

#Preview("OnboardingPhotoPrimingView") {
    OnboardingPhotoPrimingView(viewModel: OnboardingViewModel())
        .background(AppCanvas())
        .preferredColorScheme(.dark)
}

#Preview("OnboardingPhotoScanningView") {
    let viewModel = OnboardingViewModel()
    viewModel.scanStatusText = "사진 위치 확인 중"
    return OnboardingPhotoScanningView(viewModel: viewModel)
        .background(AppCanvas())
        .preferredColorScheme(.dark)
}

#Preview("OnboardingScanCardLoopView") {
    let viewModel = OnboardingViewModel()
    var first = ManualTripDraft()
    first.countryCode = "PT"
    var second = ManualTripDraft()
    second.countryCode = "JP"
    viewModel.photoScanDrafts = [first, second]
    return OnboardingScanCardLoopView(
        viewModel: viewModel,
        dependencies: AppDependencies(),
        session: SessionStore()
    )
    .previewWithAppEnvironment()
}
