import SwiftUI

/// UI-5B. 풀스크린 스토리 스타일 6장 카드 시퀀스.
/// 상단 6칸 세그먼트 진행바 + 오른쪽 탭=다음 / 왼쪽 탭=이전 + 스와이프를 지원한다.
struct WrappedStoryView: View {
    let display: WrappedDisplayModel

    @State private var index = 0

    private var cards: [WrappedCard] { display.cards }
    private var currentCard: WrappedCard { cards[index] }
    private var isShareCard: Bool { currentCard.kind == .share }

    var body: some View {
        ZStack {
            background(for: currentCard.kind)
                .animation(.easeInOut(duration: 0.4), value: index)

            cardContent
                .id(index)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.94)),
                        removal: .opacity
                    )
                )
                // 공유 카드(W6)만 버튼·토글이 있어 히트 테스트를 살려둔다.
                .allowsHitTesting(isShareCard)

            tapZones

            VStack {
                segmentedProgressBar
                Spacer()
            }
        }
        .gesture(swipeGesture)
    }

    // MARK: - Card routing

    @ViewBuilder
    private var cardContent: some View {
        switch currentCard.kind {
        case .movement:
            MovementCardView(display: display)
        case .topTrip:
            TopTripCardView(display: display)
        case .strongestTaste:
            StrongestTasteCardView(display: display)
        case .tags:
            TagsCardView(display: display)
        case .photo:
            PhotoMosaicCardView(display: display)
        case .share:
            WrappedShareStageView(display: display) {
                withAnimation(.easeOut(duration: 0.35)) { index = 0 }
            }
        }
    }

    // MARK: - Background

    private func background(for kind: WrappedCardKind) -> some View {
        ZStack {
            Color.dnaBackground
            LinearGradient(
                colors: gradientColors(for: kind),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.4)
        }
        .ignoresSafeArea()
    }

    private func gradientColors(for kind: WrappedCardKind) -> [Color] {
        switch kind {
        case .movement: [.dnaIndigo, .dnaTeal]
        case .topTrip: [.dnaCoral, .dnaAmber]
        case .strongestTaste: [.dnaTeal, .dnaIndigo]
        case .tags: [.dnaAmber, .dnaIndigo]
        case .photo: [.dnaCoral, .dnaIndigo]
        case .share: [.dnaIndigo, .dnaBackground]
        }
    }

    // MARK: - Progress & navigation

    private var segmentedProgressBar: some View {
        HStack(spacing: 5) {
            ForEach(cards.indices, id: \.self) { segment in
                Capsule()
                    .fill(segment <= index ? Color.white : Color.white.opacity(0.22))
                    .frame(height: 3)
            }
        }
        .animation(.easeOut(duration: 0.25), value: index)
        .padding(.horizontal, DNASpacing.lg)
        .padding(.top, DNASpacing.sm)
    }

    /// 스토리 표준 제스처: 왼쪽 영역 탭=이전, 오른쪽 영역 탭=다음.
    /// 공유 카드에서는 버튼을 가리지 않도록 왼쪽 가장자리 스트립만 남긴다.
    private var tapZones: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: goBack)
                    .frame(width: proxy.size.width * (isShareCard ? 0.12 : 0.35))
                if !isShareCard {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: advance)
                } else {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                if value.translation.width < -40 {
                    advance()
                } else if value.translation.width > 40 {
                    goBack()
                }
            }
    }

    private func advance() {
        guard index < cards.count - 1 else { return }
        withAnimation(.easeOut(duration: 0.3)) { index += 1 }
    }

    private func goBack() {
        guard index > 0 else { return }
        withAnimation(.easeOut(duration: 0.3)) { index -= 1 }
    }
}

// MARK: - 공통 조각

/// 카드 상단의 작은 소제목 텍스트.
private func storyEyebrow(_ text: String) -> some View {
    Text(text)
        .font(.footnote.weight(.semibold))
        .tracking(2)
        .foregroundStyle(Color.dnaSlate)
}

// MARK: - W1. 올해의 이동

private struct MovementCardView: View {
    let display: WrappedDisplayModel

    var body: some View {
        ZStack {
            PinDotPattern()

            VStack(spacing: DNASpacing.md) {
                storyEyebrow("\(display.year)년의 이동")

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "\(display.destinationCount)")
                        .font(.system(size: 104, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.dnaTeal, .dnaIndigo],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .monospacedDigit()
                    Text("개 나라")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }

                Text(display.isSingleTrip
                     ? "한 번의 여행으로 만났어요"
                     : "\(display.tripCount)번의 여행으로 만났어요")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, DNASpacing.lg)
        }
    }
}

/// 세계 지도 대신 쓰는 장식용 핀·점 패턴. 위치는 고정 시드로 결정적이다.
private struct PinDotPattern: View {
    private static let seeds: [(x: CGFloat, y: CGFloat, size: CGFloat, isPin: Bool)] = [
        (0.14, 0.16, 20, true), (0.82, 0.13, 6, false), (0.68, 0.24, 24, true),
        (0.20, 0.38, 6, false), (0.90, 0.42, 18, true), (0.08, 0.66, 10, false),
        (0.78, 0.72, 22, true), (0.46, 0.09, 5, false), (0.30, 0.84, 7, false),
        (0.88, 0.88, 5, false), (0.58, 0.90, 16, true), (0.12, 0.90, 5, false)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(Self.seeds.indices, id: \.self) { seedIndex in
                let seed = Self.seeds[seedIndex]
                Group {
                    if seed.isPin {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: seed.size))
                    } else {
                        Circle()
                            .frame(width: seed.size, height: seed.size)
                    }
                }
                .foregroundStyle(
                    (seedIndex.isMultiple(of: 2) ? Color.dnaTeal : Color.dnaIndigo)
                        .opacity(0.35)
                )
                .position(
                    x: proxy.size.width * seed.x,
                    y: proxy.size.height * seed.y
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - W2. 올해의 1위 여행

private struct TopTripCardView: View {
    let display: WrappedDisplayModel

    var body: some View {
        VStack(spacing: DNASpacing.md) {
            storyEyebrow(display.isSingleTrip ? "올해의 여행" : "올해 가장 좋았던 여행")

            Image(systemName: display.isSingleTrip ? "airplane" : "trophy.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.dnaAmber)
                .shadow(color: Color.dnaAmber.opacity(0.5), radius: 16)

            Text(display.topTripTitle)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)

            if !display.topTripDateRange.isEmpty {
                Text(display.topTripDateRange)
                    .font(.subheadline)
                    .foregroundStyle(Color.dnaSlate)
                    .monospacedDigit()
            }

            if !display.isSingleTrip {
                Text("랭킹 1위")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.dnaAmber)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.dnaAmber.opacity(0.16), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.dnaAmber.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(.horizontal, DNASpacing.lg)
    }
}

// MARK: - W3. 가장 강한 취향 축

private struct StrongestTasteCardView: View {
    let display: WrappedDisplayModel

    var body: some View {
        VStack(spacing: DNASpacing.md) {
            storyEyebrow(display.isLowConfidence ? "올해의 첫인상" : "가장 선명한 취향")

            Text(display.strongestAxis.labelKo)
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)

            FingerprintRadarView(axes: display.axes, confidence: display.confidence)
                .frame(width: 250)
                .scaleEffect(0.92)

            // 조건부(저신뢰) 축은 변화만 보여주고 "추천 근거"라고 말하지 않는다.
            Text(display.isStrongestAxisConditional
                 ? "아직 추천에는 쓰지 않는 축이지만,\n올해 기록에서 가장 뚜렷하게 드러났어요"
                 : "올해 기록에서 가장 선명하게 드러난 축이에요")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, DNASpacing.lg)
    }
}

// MARK: - W4. 올해의 태그

private struct TagsCardView: View {
    let display: WrappedDisplayModel

    private static let accents: [Color] = [.dnaTeal, .dnaIndigo, .dnaAmber]

    var body: some View {
        VStack(spacing: DNASpacing.lg) {
            storyEyebrow("올해의 태그")

            if display.topTagLabels.isEmpty {
                Text("아직 태그 기록이 없어요")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                VStack(spacing: DNASpacing.sm) {
                    ForEach(Array(display.topTagLabels.enumerated()), id: \.offset) { position, label in
                        let accent = Self.accents[position % Self.accents.count]
                        Text("#\(label)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(accent)
                            .padding(.horizontal, DNASpacing.lg)
                            .padding(.vertical, DNASpacing.sm)
                            .background(accent.opacity(0.14), in: Capsule())
                            .overlay(
                                Capsule().strokeBorder(accent.opacity(0.5), lineWidth: 1)
                            )
                    }
                }

                Text("올해 평가에서 가장 자주 고른 순간들이에요")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, DNASpacing.lg)
    }
}

// MARK: - W5. 여행 사진 모자이크

private struct PhotoMosaicCardView: View {
    let display: WrappedDisplayModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: DNASpacing.lg) {
            storyEyebrow("올해의 한 장")

            if display.annualPhotos.isEmpty {
                // 사진이 없으면 지문 그래픽으로 대체(UI-5 스펙 예외 처리).
                FingerprintRadarView(axes: display.axes, confidence: display.confidence)
                    .frame(width: 250)
                Text("사진 대신 올해의 지문을 담았어요")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(display.annualPhotos.prefix(9)) { photo in
                        photoTile(photo)
                    }
                }
                .frame(maxWidth: 320)

                Text("하루 한 장으로 남긴 \(display.annualPhotos.count)개의 순간")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, DNASpacing.lg)
    }

    private func photoTile(_ photo: DailyPhoto) -> some View {
        TripPhotoImage(storagePath: photo.storagePath)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                Text("D+\(photo.tripDayIndex)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(6)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                    .strokeBorder(Color.dnaHairline, lineWidth: 1)
            )
    }
}

#Preview("WrappedStoryView") {
    WrappedStoryView(
        display: WrappedDisplayModel(
            year: 2026,
            tripCount: 4,
            destinationCount: 6,
            cards: WrappedCardKind.allCases.map {
                WrappedCard(kind: $0, title: $0.rawValue, detail: "")
            },
            topTripTitle: "일본 · 대만",
            topTripDateRange: "2026.04.02 - 2026.04.10",
            strongestAxis: .natureUrban,
            isStrongestAxisConditional: false,
            topTagLabels: ["미식 탐험", "자연 풍경", "밤 산책"],
            axes: PreviewSample.axes,
            confidence: PreviewSample.confidence,
            isLowConfidence: false,
            annualPhotos: []
        )
    )
    .preferredColorScheme(.dark)
}
