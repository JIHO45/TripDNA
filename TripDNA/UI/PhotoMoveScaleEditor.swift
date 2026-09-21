import SwiftUI
import UIKit

/// 애플 사진 편집의 Move and Scale: 프레임은 고정, 드래그·핀치로 사진만 맞춘다.
struct PhotoMoveScaleEditor: View {
    let image: UIImage
    @Binding var makeCroppedImage: (() -> UIImage?)?
    var aspectRatio: CGFloat = 3 / 4
    var cornerRadius: CGFloat = DNARadius.card
    var maxHeight: CGFloat = 360

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var pinchAnchorScale: CGFloat = 1
    @State private var dragAnchorOffset: CGSize = .zero

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.dnaSurface)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .frame(maxHeight: maxHeight)
            .overlay {
                GeometryReader { geo in
                    let canvas = geo.size
                    let cover = Self.coverSize(image: image, canvas: canvas)

                    Image(uiImage: image)
                        .resizable()
                        .frame(width: cover.width * scale, height: cover.height * scale)
                        .offset(offset)
                        .position(x: canvas.width / 2, y: canvas.height / 2)
                        .gesture(dragGesture(cover: cover, canvas: canvas))
                        .simultaneousGesture(magnifyGesture(cover: cover, canvas: canvas))
                        .onAppear { publishExporter(cover: cover, canvas: canvas) }
                        .onChange(of: canvas) { _, newCanvas in
                            let newCover = Self.coverSize(image: image, canvas: newCanvas)
                            clamp(cover: newCover, canvas: newCanvas)
                            publishExporter(cover: newCover, canvas: newCanvas)
                        }
                        .onChange(of: scale) { _, _ in
                            publishExporter(cover: cover, canvas: canvas)
                        }
                        .onChange(of: offset) { _, _ in
                            publishExporter(cover: cover, canvas: canvas)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.dnaHairline, lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                Text("손가락으로 옮기고 확대해 맞춰 주세요")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
            }
            .onDisappear { makeCroppedImage = nil }
    }

    // MARK: - Gestures

    private func dragGesture(cover: CGSize, canvas: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: dragAnchorOffset.width + value.translation.width,
                    height: dragAnchorOffset.height + value.translation.height
                )
                clamp(cover: cover, canvas: canvas)
            }
            .onEnded { _ in
                clamp(cover: cover, canvas: canvas)
                dragAnchorOffset = offset
            }
    }

    private func magnifyGesture(cover: CGSize, canvas: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = max(1, pinchAnchorScale * value.magnification)
                clamp(cover: cover, canvas: canvas)
            }
            .onEnded { _ in
                scale = max(1, scale)
                pinchAnchorScale = scale
                clamp(cover: cover, canvas: canvas)
                dragAnchorOffset = offset
            }
    }

    // MARK: - Math

    private static func coverSize(image: UIImage, canvas: CGSize) -> CGSize {
        guard canvas.width > 0, canvas.height > 0 else { return .zero }
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return canvas }
        let imageAspect = imageSize.width / imageSize.height
        let canvasAspect = canvas.width / canvas.height
        if imageAspect > canvasAspect {
            let height = canvas.height
            return CGSize(width: height * imageAspect, height: height)
        } else {
            let width = canvas.width
            return CGSize(width: width, height: width / imageAspect)
        }
    }

    private func clamp(cover: CGSize, canvas: CGSize) {
        let display = CGSize(width: cover.width * scale, height: cover.height * scale)
        let maxX = max(0, (display.width - canvas.width) / 2)
        let maxY = max(0, (display.height - canvas.height) / 2)
        offset = CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func publishExporter(cover: CGSize, canvas: CGSize) {
        let currentScale = scale
        let currentOffset = offset
        let source = image
        makeCroppedImage = {
            Self.renderCropped(
                image: source,
                canvas: canvas,
                cover: cover,
                scale: currentScale,
                offset: currentOffset
            )
        }
    }

    private static func renderCropped(
        image: UIImage,
        canvas: CGSize,
        cover: CGSize,
        scale: CGFloat,
        offset: CGSize
    ) -> UIImage? {
        guard canvas.width > 0, canvas.height > 0,
              cover.width > 0, cover.height > 0 else { return nil }

        let upright = image.normalizedUpRight()
        let display = CGSize(width: cover.width * scale, height: cover.height * scale)
        let imageOriginInCanvas = CGPoint(
            x: (canvas.width - display.width) / 2 + offset.width,
            y: (canvas.height - display.height) / 2 + offset.height
        )
        let unitX = -imageOriginInCanvas.x / display.width
        let unitY = -imageOriginInCanvas.y / display.height
        let unitW = canvas.width / display.width
        let unitH = canvas.height / display.height

        let pixelSize = CGSize(
            width: upright.size.width * upright.scale,
            height: upright.size.height * upright.scale
        )
        let crop = CGRect(
            x: unitX * pixelSize.width,
            y: unitY * pixelSize.height,
            width: unitW * pixelSize.width,
            height: unitH * pixelSize.height
        ).integral.intersection(CGRect(origin: .zero, size: pixelSize))

        guard crop.width > 1, crop.height > 1,
              let croppedCG = upright.cgImage?.cropping(to: crop) else { return nil }
        return UIImage(cgImage: croppedCG, scale: upright.scale, orientation: .up)
    }
}

private extension UIImage {
    func normalizedUpRight() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
