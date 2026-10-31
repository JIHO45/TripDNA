import Photos
import SwiftUI
import UIKit

/// 미리보기와 내보내기에 같은 고정 크기 이미지를 사용한다. 카드는 자체 배경색을 가지므로 밝은 외형으로 고정해 렌더링한다.
/// 비율은 9:16(저장 1080×1920)이다. 피드가 4:5로 잘라도 읽히도록 핵심 내용은 가운데 4:5 안전 구역(높이 `safeHeight`)에 둔다.
enum ShareCardRenderer {
    static let size = CGSize(width: 360, height: 640)
    static let safeHeight: CGFloat = 450

    @MainActor static func render<Content: View>(_ content: Content) -> UIImage? {
        let renderer = ImageRenderer(content: content
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, .medium))
        renderer.scale = 3
        return renderer.uiImage
    }
}

enum ShareCardKind: String {
    case fingerprint
    case trip
    case wrapped
}

struct ShareCardSheet<Card: View>: View {
    let kind: ShareCardKind
    let title: String
    /// "포함: … · 빠짐: …" 한 줄.
    let disclosure: String
    var allowsDestinationNames = false
    @ViewBuilder let card: (Bool) -> Card

    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    @State private var showsDestinationNames = false
    @State private var confirmed = false
    @State private var renderedImage: UIImage?
    @State private var isSaving = false
    @State private var message: String?
    @State private var showsPermissionToast = false
    @State private var sharePayload: ShareCardPayload?
    @State private var exportCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    if let renderedImage {
                        Image(uiImage: renderedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 270)
                            .clipShape(RoundedRectangle(cornerRadius: DNARadius.hero, style: .continuous))
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("\(title) image")
                            .accessibilityIdentifier("shareCard.preview")
                    } else {
                        Text("Couldn't create the image. Please try again.")
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Button("Create Again", action: render)
                    }
                    destinationRow
                    Text(disclosure)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .padding(.horizontal, DNASpacing.xxs)
                    if let message {
                        Text(message)
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .accessibilityIdentifier("shareCard.message")
                    }
                }
                .padding(.horizontal, DNASpacing.gutter)
                .padding(.vertical, DNASpacing.md)
            }
            .dnaBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        // 시스템 툴바가 원형 배경을 그려 주므로 아이콘만 둔다.
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.dnaTextPrimary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .overlay(alignment: .bottom) { permissionToast }
            .onAppear(perform: render)
            .onChange(of: showsDestinationNames) {
                // 공개 범위가 바뀌면 이전 확인은 무효다. 다시 확인해야 저장·공유할 수 있다.
                confirmed = false
                message = nil
                showsPermissionToast = false
                render()
            }
            .interactiveDismissDisabled(isSaving)
            .sheet(item: $sharePayload) { payload in
                ShareCardActivityView(image: payload.image) { activityType in
                    Task { await recordExport(action: "share", activityType: activityType) }
                }
            }
        }
        .sensoryFeedback(.success, trigger: exportCount)
    }

    // MARK: 구성

    private var destinationRow: some View {
        HStack(spacing: DNASpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Show Country Names")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text(destinationNote)
                    .dnaFont(.caption)
                    .foregroundStyle(showsDestinationNames ? Color.dnaUnverifiedText : Color.dnaTextSecondary)
            }
            Spacer(minLength: 0)
            Toggle("Show Country Names", isOn: $showsDestinationNames)
                .labelsHidden()
                .disabled(!allowsDestinationNames)
                .accessibilityIdentifier("shareCard.destinations")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, DNASpacing.sm)
        .background(
            showsDestinationNames ? Color.dnaUnverifiedBackground : Color.dnaSurface1,
            in: RoundedRectangle(cornerRadius: DNARadius.card - 2, style: .continuous)
        )
    }

    private var destinationNote: String {
        if !allowsDestinationNames { return String(localized: "This card has no country names") }
        return showsDestinationNames ? String(localized: "Country names appear in the image") : String(localized: "Country names are hidden")
    }

    private var bottomBar: some View {
        DNABottomCTA {
            Toggle(isOn: $confirmed) {
                Text("I've checked what will be shared")
                    .dnaFont(size: 14, weight: .bold)
                    .foregroundStyle(Color.dnaTextPrimary)
            }
            .toggleStyle(ShareConfirmCheckStyle())
            .accessibilityIdentifier("shareCard.confirm")
            if let renderedImage {
                HStack(spacing: DNASpacing.xs) {
                    Button {
                        Task { await save(renderedImage) }
                    } label: {
                        Text(isSaving ? String(localized: "Saving") : String(localized: "Save Image"))
                    }
                    .buttonStyle(.dnaSecondary)
                    .accessibilityIdentifier("shareCard.save")
                    .disabled(!confirmed || isSaving)
                    .opacity(confirmed ? 1 : 0.45)

                    Button {
                        guard confirmed, !isSaving else { return }
                        sharePayload = ShareCardPayload(image: renderedImage)
                    } label: {
                        Text("Share").frame(minHeight: 48)
                    }
                    .buttonStyle(.dnaDark(fullWidth: true))
                    .accessibilityIdentifier("shareCard.share")
                    .disabled(!confirmed || isSaving)
                    .opacity(confirmed ? 1 : 0.35)
                }
            }
        }
    }

    @ViewBuilder
    private var permissionToast: some View {
        if showsPermissionToast {
            HStack(spacing: DNASpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Can't save to your photo library")
                        .dnaFont(.cardTitle)
                    Text("Permission to save is turned off")
                        .dnaFont(.caption)
                        .opacity(0.8)
                }
                Spacer(minLength: 0)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .dnaFont(.button)
                .foregroundStyle(Color.dnaActionText)
                .accessibilityIdentifier("shareCard.openSettings")
            }
            .foregroundStyle(Color.dnaSelectedForeground)
            .padding(.horizontal, DNASpacing.md)
            .frame(minHeight: 56)
            .background(Color.dnaSelectedBackground, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            .padding(.horizontal, DNASpacing.gutter)
            .padding(.bottom, 170)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: 동작

    private func render() {
        renderedImage = ShareCardRenderer.render(card(showsDestinationNames))
    }

    @MainActor private func save(_ image: UIImage) async {
        guard confirmed, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        message = nil
        withAnimation { showsPermissionToast = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            withAnimation { showsPermissionToast = true }
            return
        }
        guard let data = image.pngData() else {
            message = String(localized: "Couldn't create the image. Please try again.")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            message = String(localized: "Saved to Photos.")
            await recordExport(action: "save", activityType: nil)
        } catch {
            message = String(localized: "Couldn't save. Try again or use Share.")
        }
    }

    private func recordExport(action: String, activityType: String?) async {
        exportCount += 1
        var payload = [
            "kind": kind.rawValue,
            "action": action,
            "destinationNamesShown": String(showsDestinationNames)
        ]
        payload["activityType"] = activityType
        await dependencies.track(.shareCardExported, payload)
    }
}

/// 공개 확인은 켜고 끄는 설정이 아니라 동의라서 체크 상자로 보인다. 접근성에는 토글로 읽힌다.
private struct ShareConfirmCheckStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: DNASpacing.xs) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .dnaFont(size: 22, weight: .regular)
                    .foregroundStyle(configuration.isOn ? Color.dnaSelectedBackground : Color.dnaTextSecondary)
                configuration.label
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? String(localized: "On") : String(localized: "Off"))
    }
}

private struct ShareCardPayload: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 미리보기에서 확인한 이미지만 전달하며 원본 여행 데이터는 공유하지 않는다.
/// 시트를 취소하면 `completed`가 false라서 아무것도 기록하지 않는다.
private struct ShareCardActivityView: UIViewControllerRepresentable {
    let image: UIImage
    /// 사용자가 실제로 보냈을 때만 호출된다. 인자는 받은 앱의 activity type이다.
    let onCompleted: (String) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            guard completed else { return }
            onCompleted(activityType?.rawValue ?? "unknown")
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
