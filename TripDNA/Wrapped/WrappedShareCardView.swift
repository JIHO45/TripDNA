import SwiftUI
import UIKit

// MARK: - W6. 최종 공유 스테이지 (UI-5B 마지막 카드 + UI-5C 공유 미리보기)

/// 마지막 스토리 카드에서 공통 공유 미리보기·공개 설정·저장 화면으로 연결한다.
struct WrappedShareStageView: View {
    let display: WrappedDisplayModel
    let onRestart: () -> Void

    @State private var showingShare = false

    /// 공유 카드 설계 크기(9:16). 렌더링·미리보기 모두 이 크기를 기준으로 한다.
    private static let cardSize = CGSize(width: 360, height: 640)
    private static let previewScale: CGFloat = 0.48

    var body: some View {
        VStack(spacing: DNASpacing.md) {
            Spacer(minLength: DNASpacing.xl)

            WrappedShareCardView(
                display: display,
                showsDestinationNames: false
            )
            .frame(width: Self.cardSize.width, height: Self.cardSize.height)
            .scaleEffect(Self.previewScale)
            .frame(
                width: Self.cardSize.width * Self.previewScale,
                height: Self.cardSize.height * Self.previewScale
            )
            .shadow(color: Color.dnaIndigo.opacity(0.35), radius: 24, y: 10)

            Spacer(minLength: 0)

            DNABottomCTA {
                ctaButtons
            }
        }
        .sheet(isPresented: $showingShare) {
            ShareCardSheet(
                title: "Wrapped 공유",
                disclosure: "연도, 여행·국가 수, 취향 지문, 베스트 여행과 긍정 태그가 포함돼요.",
                allowsDestinationNames: true
            ) { showsDestinationNames in
                WrappedShareCardView(display: display, showsDestinationNames: showsDestinationNames)
            }
        }
    }

    @ViewBuilder
    private var ctaButtons: some View {
        VStack(spacing: DNASpacing.sm) {
            Button {
                showingShare = true
            } label: {
                Label("공유 미리보기", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.dnaPrimary)
            .accessibilityIdentifier("wrapped.sharePreview")

            Button("처음부터 보기", action: onRestart)
                .buttonStyle(.dnaGhost)
        }
    }

}

// MARK: - UI-5C. 세로 9:16 공유 카드

/// 저장·공유용 카드. 개인 식별 정보와 정확한 날짜는 넣지 않는다(UI-5 스펙).
struct WrappedShareCardView: View {
    let display: WrappedDisplayModel
    var showsDestinationNames: Bool

    var body: some View {
        ZStack {
            cardBackground

            VStack(spacing: DNASpacing.md) {
                VStack(spacing: 2) {
                    Text(verbatim: "\(display.year)")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.dnaTeal, .dnaIndigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(display.heroTitle)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                .padding(.top, DNASpacing.lg)

                FingerprintRadarView(axes: display.axes, confidence: display.confidence)
                    .frame(width: 230)

                Text("\(display.destinationCount)개 나라 · \(display.tripCount)번의 여행")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                VStack(spacing: 4) {
                    Text(display.isSingleTrip ? "올해의 여행" : "올해의 1위 여행")
                        .font(.caption.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(Color.dnaSlate)
                    Text(showsDestinationNames ? display.topTripTitle : "나의 베스트 여행")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.dnaAmber)
                        .minimumScaleFactor(0.7)
                }

                if !display.topTagLabels.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(display.topTagLabels, id: \.self) { label in
                            Text("#\(label)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.dnaTeal)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.dnaTeal.opacity(0.14), in: Capsule())
                        }
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Image(systemName: "touchid")
                        .font(.caption2)
                    Text("TripDNA")
                        .font(.caption2.weight(.medium))
                        .tracking(1)
                }
                .foregroundStyle(Color.dnaSlate.opacity(0.8))
                .padding(.bottom, DNASpacing.md)
            }
            .padding(.horizontal, DNASpacing.lg)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.dnaHairline, lineWidth: 1)
        )
    }

    /// `AuroraBackground`는 `ignoresSafeArea`를 포함해 카드 프레임 밖으로 번질 수 있으므로
    /// 렌더러·미리보기 겸용 배경을 카드 크기에 맞춰 직접 그린다.
    private var cardBackground: some View {
        ZStack {
            Color.dnaBackground
            RadialGradient(
                colors: [Color.dnaIndigo.opacity(0.35), .clear],
                center: UnitPoint(x: 0.2, y: 0.08),
                startRadius: 10,
                endRadius: 300
            )
            RadialGradient(
                colors: [Color.dnaTeal.opacity(0.28), .clear],
                center: UnitPoint(x: 0.88, y: 0.35),
                startRadius: 10,
                endRadius: 280
            )
            RadialGradient(
                colors: [Color.dnaCoral.opacity(0.16), .clear],
                center: UnitPoint(x: 0.25, y: 0.95),
                startRadius: 10,
                endRadius: 260
            )
        }
    }
}

#Preview("WrappedShareCardView") {
    WrappedShareCardView(
        display: WrappedDisplayModel(
            year: 2026,
            tripCount: 4,
            destinationCount: 6,
            cards: [],
            topTripTitle: "일본 · 대만",
            topTripDateRange: "2026.04.02 - 2026.04.10",
            strongestAxis: .natureUrban,
            isStrongestAxisConditional: false,
            topTagLabels: ["미식 탐험", "자연 풍경"],
            axes: PreviewSample.axes,
            confidence: PreviewSample.confidence,
            isLowConfidence: false,
            annualPhotos: []
        ),
        showsDestinationNames: true
    )
    .frame(width: 360, height: 640)
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
