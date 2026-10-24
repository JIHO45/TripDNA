import Photos
import SwiftUI
import UIKit

/// 미리보기와 내보내기에 같은 고정 크기 이미지를 사용한다.
enum ShareCardRenderer {
    @MainActor static func render<Content: View>(_ content: Content) -> UIImage? {
        let renderer = ImageRenderer(content: content
            .frame(width: 360, height: 640)
            .environment(\.colorScheme, .dark)
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
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("\(title) 이미지 미리보기")
                            .accessibilityIdentifier("shareCard.preview")
                    } else {
                        Text("이미지를 만들지 못했어요. 다시 시도해주세요.")
                        Button("다시 만들기", action: render)
                    }
                    Text(disclosure)
                        .font(.subheadline)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Text("정확한 날짜·도시·동행인·사진은 포함하지 않아요.")
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    if allowsDestinationNames {
                        Toggle("여행지 이름 표시", isOn: $showsDestinationNames)
                            .accessibilityIdentifier("shareCard.destinations")
                        Text(showsDestinationNames ? "국가 이름이 이미지에 포함돼요." : "국가 이름은 숨겨져 있어요.")
                            .font(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    Toggle("공개할 내용을 확인했어요", isOn: $confirmed)
                        .accessibilityIdentifier("shareCard.confirm")
                    if let message {
                        Text(message)
                            .font(.subheadline)
                            .accessibilityIdentifier("shareCard.message")
                    }
                }
                .padding(DNASpacing.lg)
            }
            .dnaBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                DNABottomCTA {
                    if let renderedImage {
                        Button {
                            guard confirmed, !isSaving else { return }
                            sharePayload = ShareCardPayload(image: renderedImage)
                        } label: {
                            Label("공유하기", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.dnaPrimary)
                        .accessibilityIdentifier("shareCard.share")
                        .disabled(!confirmed || isSaving)
                        Button {
                            Task { await save(renderedImage) }
                        } label: {
                            Label(isSaving ? "저장 중" : "이미지 저장", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.dnaSecondary)
                        .accessibilityIdentifier("shareCard.save")
                        .disabled(!confirmed || isSaving)
                    }
                }
            }
            .onAppear(perform: render)
            .onChange(of: showsDestinationNames) {
                confirmed = false
                message = nil
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

    private func render() {
        renderedImage = ShareCardRenderer.render(card(showsDestinationNames))
    }

    @MainActor private func save(_ image: UIImage) async {
        guard confirmed, !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        message = nil
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            message = "사진 저장 권한이 없어요. 설정에서 허용하거나 공유하기로 이미지를 내보내세요."
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
            message = "저장하지 못했어요. 다시 시도하거나 공유하기를 이용해주세요."
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
