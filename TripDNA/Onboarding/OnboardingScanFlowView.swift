import Photos
import SwiftUI
import UIKit

// MARK: - ③ 사진 권한 전 설명

struct OnboardingPhotoPrimingView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(progress: viewModel.progress, onBack: { viewModel.goBack() })
            VStack(alignment: .leading, spacing: DNASpacing.lg) {
                Text("다녀온 곳을\n사진으로 찾아볼게요")
                    .dnaFont(.screenTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    checkLine("위치와 날짜는 이 기기 안에서만 읽어요")
                    checkLine("사진 원본은 어디에도 보내지 않아요")
                    checkLine("찾은 여행은 후보로만 보여주고, 확인한 것만 기록해요")
                }
                Text(viewModel.isFromHome ? "허용하지 않아도 직접 등록할 수 있어요." : "허용하지 않아도 직접 등록하거나 취향부터 시작할 수 있어요.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.lg)
            Spacer(minLength: 0)
            DNABottomCTA {
                Button("사진 접근 허용하기") { viewModel.startPhotoScan() }
                    .buttonStyle(.dnaPrimary)
                Button("직접 등록으로 바꾸기") { viewModel.selectEntryMode(.manual) }
                    .buttonStyle(.dnaGhost)
            }
        }
    }

    private func checkLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DNASpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.dnaData)
            Text(text)
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 스캔 중

struct OnboardingPhotoScanningView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: DNASpacing.lg) {
            Spacer()
            ProgressView()
            Text(viewModel.scanStatusText)
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.scanStatusText)
            Spacer()
            DNABottomCTA {
                Button("취소") { viewModel.cancelPhotoScan() }
                    .buttonStyle(.dnaGhost)
            }
        }
    }
}

// MARK: - ⑨ 권한 거부 · 후보 없음

struct OnboardingNoCandidatesView: View {
    let viewModel: OnboardingViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(progress: viewModel.progress, onBack: { viewModel.goBack() })
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                Text(viewModel.scanWasDenied ? "사진 접근을\n허용하지 않았어요" : "확인할 수 있는\n여행 후보가 없어요")
                    .dnaFont(.screenTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text(viewModel.scanWasDenied
                     ? "괜찮아요. 다른 방법으로 계속할 수 있어요."
                     : viewModel.isFromHome
                     ? "위치 정보가 있는 여행 사진을 찾지 못했어요. 직접 여행을 등록할 수 있어요."
                     : "위치 정보가 있는 여행 사진을 찾지 못했어요. 직접 여행을 등록하거나, 취향부터 먼저 정할 수 있어요.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.lg)

            if viewModel.isPhotoAccessLimited {
                LimitedPhotoAccessBanner(
                    message: "지금은 직접 고른 사진만 볼 수 있어요. 모든 사진을 허용하면 사진첩 전체에서 여행을 찾아드려요.",
                    onSelectMore: { viewModel.presentLimitedPhotoPicker() }
                )
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.top, DNASpacing.md)
            }
            Spacer(minLength: 0)
            DNABottomCTA {
                Button("직접 등록") { viewModel.selectEntryMode(.manual) }
                    .buttonStyle(.dnaPrimary)
                if !viewModel.isFromHome {
                    Button("여행 기록 없이 취향부터") { viewModel.selectEntryMode(.preferencesOnly) }
                        .buttonStyle(.dnaSecondary)
                }
                if viewModel.scanWasDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("허용할 사진 바꾸기 (iOS 설정)", destination: url)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshPhotoAccessAfterReturning() }
        }
    }
}

// MARK: - ④ 후보 확인

struct OnboardingCandidatesView: View {
    let viewModel: OnboardingViewModel
    let dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase
    @State private var cityTarget: UUID?
    @State private var cityText = ""

    var body: some View {
        VStack(spacing: 0) {
            DNAStepTopBar(progress: viewModel.progress, onBack: { viewModel.goBack() })
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    VStack(alignment: .leading, spacing: DNASpacing.xs) {
                        Text("기록할 여행을 골라요")
                            .dnaFont(.screenTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Text("후보 \(viewModel.candidates.count)개 중 \(viewModel.recordedCandidateCount)개 기록함 · 고른 것만 기록해요")
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    if viewModel.isPhotoAccessLimited {
                        LimitedPhotoAccessBanner(
                            message: "선택한 사진에서만 여행을 찾았어요. 모든 사진을 허용하면 더 많은 여행을 찾을 수 있어요.",
                            onSelectMore: { viewModel.presentLimitedPhotoPicker() }
                        )
                    }
                    ForEach(viewModel.candidates) { candidate in
                        switch candidate.state {
                        case .pending: pendingCard(candidate)
                        case .recorded:
                            collapsedRow("✓ \(candidate.title) 기록함", action: "취소") {
                                viewModel.setState(.pending, for: candidate.id)
                            }
                        case .removed:
                            collapsedRow("\(candidate.title) 뺐어요", action: "되돌리기") {
                                viewModel.setState(.pending, for: candidate.id)
                            }
                        }
                    }
                    if let message = viewModel.errorMessage {
                        Text(message).dnaFont(.caption).foregroundStyle(Color.dnaError)
                    }
                }
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.top, DNASpacing.lg)
                .padding(.bottom, DNASpacing.xl)
            }
            DNABottomCTA {
                let count = viewModel.recordedCandidateCount
                Button(count > 0 ? "\(count)개 기록하고 계속하기" : "기록하고 계속하기") {
                    Task { await viewModel.commitCandidates(dependencies) }
                }
                .buttonStyle(.dnaPrimary(isDisabled: count == 0 || viewModel.isWorking))
                .disabled(count == 0 || viewModel.isWorking)
                Button("나머지는 나중에") {
                    Task { await viewModel.commitCandidates(dependencies) }
                }
                .buttonStyle(.dnaGhost)
                .disabled(viewModel.isWorking)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshPhotoAccessAfterReturning() }
        }
        .alert("도시 고르기", isPresented: Binding(get: { cityTarget != nil }, set: { if !$0 { cityTarget = nil } })) {
            TextField("도시 이름", text: $cityText)
            Button("확인") {
                if let cityTarget { viewModel.setCity(cityText, for: cityTarget) }
                cityTarget = nil
            }
            Button("취소", role: .cancel) { cityTarget = nil }
        } message: {
            Text("사진 위치가 흐려서 도시를 알 수 없어요. 아는 도시를 적어 주세요.")
        }
    }

    private func collapsedRow(_ text: String, action: String, onTap: @escaping () -> Void) -> some View {
        HStack {
            Text(text)
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            Spacer()
            Button(action, action: onTap)
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextPrimary)
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
    }

    private func pendingCard(_ candidate: TripCandidate) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            if !candidate.photoAssetIDs.isEmpty {
                HStack(spacing: DNASpacing.xs) {
                    ForEach(Array(candidate.photoAssetIDs.prefix(3).enumerated()), id: \.offset) { _, assetID in
                        PhotoAssetImage(localIdentifier: assetID, targetSize: CGSize(width: 300, height: 300))
                            .frame(height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
                    }
                }
            }
            HStack(spacing: DNASpacing.xs) {
                Text(candidate.legs.map { OnboardingFormat.flagEmoji(for: $0.countryCode) }.joined())
                Text(candidate.isCityUnknown ? "\(candidate.title) · 도시 모름" : candidate.title)
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
            }
            Text("\(OnboardingFormat.dateRangeText(start: candidate.startDate, end: candidate.endDate)) · 사진 \(candidate.photoAssetIDs.count)장")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)

            if candidate.isCityUnknown {
                suggestionRow(text: "사진 위치가 흐려서 도시를 모르겠어요.", action: "도시 고르기") {
                    cityText = ""
                    cityTarget = candidate.id
                }
            } else if let other = viewModel.mergeSuggestion(for: candidate.id) {
                suggestionRow(text: "\(other.title)와 날짜가 가까워요. 한 여행이었나요?", action: "\(other.title)와 합치기") {
                    viewModel.merge(candidate.id, with: other.id)
                }
            }

            HStack(spacing: DNASpacing.sm) {
                Button("빼기") { viewModel.setState(.removed, for: candidate.id) }
                    .buttonStyle(.dnaSecondary)
                Button(candidate.isCityUnknown ? "나라만 기록하기" : "기록하기") {
                    viewModel.setState(.recorded, for: candidate.id)
                }
                .buttonStyle(.dnaPrimary)
            }
        }
        .padding(DNASpacing.md)
        .background(Color.dnaRaised, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaDivider, lineWidth: 1)
        }
    }

    private func suggestionRow(text: String, action: String, onTap: @escaping () -> Void) -> some View {
        HStack(spacing: DNASpacing.sm) {
            Text(text)
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaUnverifiedText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action, action: onTap)
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaUnverifiedText)
                .underline()
        }
        .padding(DNASpacing.sm)
        .background(Color.dnaUnverifiedBackground, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
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
                    .foregroundStyle(Color.dnaUnverifiedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: DNASpacing.md) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("모든 사진 허용하기", destination: url)
                }
                Button("사진 더 고르기", action: onSelectMore)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.dnaUnverifiedText)
            .padding(.leading, 28)
        }
        .padding(DNASpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaUnverifiedBackground, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
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
                    ProgressView()
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

#Preview("OnboardingPhotoPrimingView") {
    OnboardingPhotoPrimingView(viewModel: OnboardingViewModel())
        .background(AppCanvas())
}
