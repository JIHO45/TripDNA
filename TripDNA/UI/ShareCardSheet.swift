import Photos
import SwiftUI
import UIKit

/// 미리보기와 내보내기에 같은 고정 크기 이미지를 사용한다. 카드는 자체 배경색을 가지므로 밝은 외형으로 고정해 렌더링한다.
enum ShareCardRenderer {
    @MainActor static func render<Content: View>(_ content: Content) -> UIImage? {
        let renderer = ImageRenderer(content: content
            .frame(width: 360, height: 640)
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
                            .frame(maxWidth: 230)
                            .clipShape(RoundedRectangle(cornerRadius: DNARadius.hero, style: .continuous))
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("\(title) 이미지")
                            .accessibilityIdentifier("shareCard.preview")
                    } else {
                        Text("이미지를 만들지 못했어요. 다시 시도해주세요.")
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Button("다시 만들기", action: render)
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
                    Button("닫기") { dismiss() }
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
                Text("나라 이름 표시")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text(destinationNote)
                    .dnaFont(.caption)
                    .foregroundStyle(showsDestinationNames ? Color.dnaUnverifiedText : Color.dnaTextSecondary)
            }
            Spacer(minLength: 0)
            Toggle("나라 이름 표시", isOn: $showsDestinationNames)
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
        if !allowsDestinationNames { return "이 카드에는 나라 이름이 없어요" }
        return showsDestinationNames ? "나라 이름이 이미지에 들어가요" : "나라 이름은 숨겨져 있어요"
    }

    private var bottomBar: some View {
        DNABottomCTA {
            Toggle("공개할 내용을 확인했어요", isOn: $confirmed)
                .dnaFont(size: 14, weight: .bold)
                .foregroundStyle(Color.dnaTextPrimary)
                .accessibilityIdentifier("shareCard.confirm")
            if let renderedImage {
                HStack(spacing: DNASpacing.xs) {
                    Button {
                        Task { await save(renderedImage) }
                    } label: {
                        Text(isSaving ? "저장 중" : "이미지 저장")
                    }
                    .buttonStyle(.dnaSecondary)
                    .accessibilityIdentifier("shareCard.save")
                    .disabled(!confirmed || isSaving)
                    .opacity(confirmed ? 1 : 0.45)

                    Button {
                        guard confirmed, !isSaving else { return }
                        sharePayload = ShareCardPayload(image: renderedImage)
                    } label: {
                        Text("공유")
                            .dnaFont(.button)
                            .foregroundStyle(Color.dnaSelectedForeground)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.dnaSelectedBackground, in: Capsule())
                    }
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
                    Text("사진 보관함에 저장할 수 없어요")
                        .dnaFont(.cardTitle)
                    Text("저장 권한이 꺼져 있어요")
                        .dnaFont(.caption)
                        .opacity(0.8)
                }
                Spacer(minLength: 0)
                Button("설정 열기") {
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
            message = "이미지를 만들지 못했어요. 다시 시도해주세요."
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            message = "사진첩에 저장했어요."
            await recordExport(action: "save", activityType: nil)
        } catch {
            message = "저장하지 못했어요. 다시 시도하거나 공유를 이용해주세요."
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
