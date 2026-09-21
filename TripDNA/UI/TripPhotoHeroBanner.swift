import SwiftUI

/// 여행 사진을 화면 상단 full-bleed로 두고, 아래로 갈수록 배경에 녹아들게 블러·페이드한다.
struct TripPhotoHeroBanner: View {
    /// `local://photos/...` 또는 placeholder 경로.
    let storagePaths: [String]
    var height: CGFloat = 240
    /// 경로가 비었을 때 기본 심볼 콜라주를 쓸지 여부.
    var showsPlaceholderWhenEmpty: Bool = true

    private var displayPaths: [String] {
        let trimmed = Array(storagePaths.prefix(3))
        if trimmed.isEmpty, showsPlaceholderWhenEmpty {
            return [
                "local://placeholder/sun.max.fill",
                "local://placeholder/water.waves",
                "local://placeholder/building.2.fill"
            ]
        }
        return trimmed
    }

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(Self.scrollSpace)).minY
            let pull = max(0, minY)
            let scrolled = max(0, -minY)
            let blurRadius = min(18, scrolled / 14)
            let fade = min(0.45, scrolled / 280)

            ZStack(alignment: .bottom) {
                collage
                    .scaleEffect(1 + pull / 900, anchor: .top)
                    .frame(width: geo.size.width, height: height + pull)
                    .clipped()
                    .blur(radius: blurRadius)
                    .opacity(1 - fade)

                LinearGradient(
                    colors: [
                        .clear,
                        Color.dnaBackground.opacity(0.35),
                        Color.dnaBackground.opacity(0.85),
                        Color.dnaBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: height * 0.55)
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: height + pull, alignment: .top)
            .offset(y: -pull)
        }
        .frame(height: height)
    }

    static let scrollSpace = "tripPhotoHeroScroll"

    private var collage: some View {
        HStack(spacing: 2) {
            ForEach(Array(displayPaths.enumerated()), id: \.offset) { _, path in
                TripPhotoImage(storagePath: path)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        }
    }
}

extension View {
    /// `TripPhotoHeroBanner` 스크롤 블러용 coordinate space.
    func tripPhotoHeroScrollSpace() -> some View {
        coordinateSpace(name: TripPhotoHeroBanner.scrollSpace)
    }
}

#Preview("TripPhotoHeroBanner") {
    ScrollView {
        VStack(spacing: 0) {
            TripPhotoHeroBanner(storagePaths: [])
            Text("아래로 스크롤하면 사진이 흐려져요")
                .foregroundStyle(.white)
                .padding()
            Color.clear.frame(height: 600)
        }
    }
    .tripPhotoHeroScrollSpace()
    .background(Color.dnaBackground)
}
