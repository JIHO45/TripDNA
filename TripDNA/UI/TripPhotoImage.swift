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
                        colors: [.dnaTextTertiary.opacity(0.45), .dnaData.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))
                }
            } else {
                ZStack {
                    Color.dnaSurface1
                    Image(systemName: "photo")
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            }
        }
    }
}

extension String {
    /// 데모·시드 데이터의 `local://placeholder/<SF Symbol>` 경로에서 심볼 이름을 꺼낸다.
    var placeholderPhotoSymbol: String? {
        guard hasPrefix("local://placeholder/") else { return nil }
        return String(dropFirst("local://placeholder/".count))
    }
}
