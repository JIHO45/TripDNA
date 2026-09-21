import SwiftUI

/// `storagePath`가 로컬 파일이면 실사진, placeholder면 심볼 타일로 보여준다.
struct TripPhotoImage: View {
    let storagePath: String
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let image = LocalPhotoStore.image(at: storagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let symbol = storagePath.placeholderPhotoSymbol {
                ZStack {
                    LinearGradient(
                        colors: [.dnaIndigo.opacity(0.45), .dnaTeal.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                ZStack {
                    Color.dnaSurface
                    Image(systemName: "photo")
                        .foregroundStyle(Color.dnaSlate)
                }
            }
        }
    }
}
