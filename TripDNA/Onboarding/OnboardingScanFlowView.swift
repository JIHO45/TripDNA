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
                Text("We'll find the places\nyou've been in your photos")
                    .dnaFont(.screenTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    checkLine(String(localized: "Location and date are read only on this device"))
                    checkLine(String(localized: "Original photos are never sent anywhere"))
                    checkLine(String(localized: "Trips we find are shown only as suggestions, and only the ones you confirm are recorded"))
                }
                Text(viewModel.isFromHome ? String(localized: "You can still add trips manually without allowing access.") : String(localized: "You can still add trips manually or start with your tastes without allowing access."))
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.lg)
            Spacer(minLength: 0)
            DNABottomCTA {
                Button("Allow Photo Access") { viewModel.startPhotoScan() }
                    .buttonStyle(.dnaPrimary)
                Button("Switch to Manual Entry") { viewModel.selectEntryMode(.manual) }
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
                Button("Cancel") { viewModel.cancelPhotoScan() }
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
                Text(viewModel.scanWasDenied ? String(localized: "Photo access\nwasn't allowed") : String(localized: "No trip suggestions\nto confirm"))
                    .dnaFont(.screenTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text(viewModel.scanWasDenied
                     ? String(localized: "That's okay. You can continue another way.")
                     : viewModel.isFromHome
                     ? String(localized: "We couldn't find any trip photos with location info. You can add a trip manually.")
                     : String(localized: "We couldn't find any trip photos with location info. You can add a trip manually or set your tastes first."))
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.top, DNASpacing.lg)

            if viewModel.isPhotoAccessLimited {
                LimitedPhotoAccessBanner(
                    message: String(localized: "For now, we can only see the photos you picked. Allow all photos and we'll find trips across your whole library."),
                    onSelectMore: { viewModel.presentLimitedPhotoPicker() }
                )
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.top, DNASpacing.md)
            }
            Spacer(minLength: 0)
            DNABottomCTA {
                Button("Add Manually") { viewModel.selectEntryMode(.manual) }
                    .buttonStyle(.dnaPrimary)
                if !viewModel.isFromHome {
                    Button("Start with Tastes, No Trip History") { viewModel.selectEntryMode(.preferencesOnly) }
                        .buttonStyle(.dnaSecondary)
                }
                if viewModel.scanWasDenied, let url = URL(string: UIApplication.openSettingsURLString) {
                    Link("Change Selected Photos (iOS Settings)", destination: url)
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
                        Text("Pick trips to record")
                            .dnaFont(.screenTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Text("\(viewModel.recordedCandidateCount) of \(viewModel.candidates.count) candidates recorded · Only your picks are recorded")
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    if viewModel.isPhotoAccessLimited {
                        LimitedPhotoAccessBanner(
                            message: String(localized: "We only found trips in the photos you selected. Allow all photos to find more trips."),
                            onSelectMore: { viewModel.presentLimitedPhotoPicker() }
                        )
                    }
                    ForEach(viewModel.candidates) { candidate in
                        switch candidate.state {
                        case .pending: pendingCard(candidate)
                        case .recorded:
                            collapsedRow(candidate.title, status: String(localized: "Recorded"), recorded: true, action: String(localized: "Cancel")) {
                                viewModel.setState(.pending, for: candidate.id)
                            }
                        case .removed:
                            collapsedRow(candidate.title, status: String(localized: "Removed"), recorded: false, action: String(localized: "Undo")) {
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
                Button(count > 0 ? String(localized: "Record \(count) and Continue") : String(localized: "Record and Continue")) {
                    Task { await viewModel.commitCandidates(dependencies) }
                }
                .buttonStyle(.dnaPrimary(isDisabled: count == 0 || viewModel.isWorking))
                .disabled(count == 0 || viewModel.isWorking)
                Button("Do the Rest Later") {
                    Task { await viewModel.commitCandidates(dependencies) }
                }
                .buttonStyle(.dnaGhost)
                .disabled(viewModel.isWorking)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refreshPhotoAccessAfterReturning() }
        }
        .alert("Choose City", isPresented: Binding(get: { cityTarget != nil }, set: { if !$0 { cityTarget = nil } })) {
            TextField("City name", text: $cityText)
            Button("OK") {
                if let cityTarget { viewModel.setCity(cityText, for: cityTarget) }
                cityTarget = nil
            }
            Button("Cancel", role: .cancel) { cityTarget = nil }
        } message: {
            Text("We can't tell the city from the photo location. Enter a city you know.")
        }
    }

    private func collapsedRow(_ title: String, status: String, recorded: Bool, action: String, onTap: @escaping () -> Void) -> some View {
        HStack(spacing: DNASpacing.xs) {
            if recorded {
                Image(systemName: "checkmark").foregroundStyle(Color.dnaData).accessibilityHidden(true)
            }
            Text(title).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
            Text(status).dnaFont(.body).foregroundStyle(Color.dnaTextSecondary)
            Spacer()
            Button(action, action: onTap)
                .dnaFont(.button)
                .foregroundStyle(Color.dnaTextPrimary)
                .frame(minHeight: 44)
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
                            .frame(height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
                    }
                }
            }
            HStack(spacing: DNASpacing.xs) {
                Text(candidate.legs.map { OnboardingFormat.flagEmoji(for: $0.countryCode) }.joined())
                Text(candidate.isCityUnknown ? String(localized: "\(candidate.title) · City unknown") : candidate.title)
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
            }
            Text("\(OnboardingFormat.dateRangeText(start: candidate.startDate, end: candidate.endDate)) · \(candidate.photoAssetIDs.count) photos")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)

            if candidate.isCityUnknown {
                suggestionRow(text: String(localized: "We can't tell the city because the photo location is unclear."), action: String(localized: "Choose City")) {
                    cityText = ""
                    cityTarget = candidate.id
                }
            } else if let other = viewModel.mergeSuggestion(for: candidate.id) {
                suggestionRow(text: String(localized: "\(particled(other.title, .waGwa)) is close in date. Was it one trip?"), action: String(localized: "Merge with \(particled(other.title, .waGwa))")) {
                    viewModel.merge(candidate.id, with: other.id)
                }
            }

            HStack(spacing: DNASpacing.sm) {
                Button("Remove") { viewModel.setState(.removed, for: candidate.id) }
                    .buttonStyle(.dnaSecondary(onSheet: true))
                Button(candidate.isCityUnknown ? String(localized: "Record Country Only") : String(localized: "Record")) {
                    viewModel.setState(.recorded, for: candidate.id)
                }
                .buttonStyle(.dnaDark(fullWidth: true))
            }
        }
        .padding(DNASpacing.md)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
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
                    Link("Allow All Photos", destination: url)
                }
                Button("Select More Photos", action: onSelectMore)
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
