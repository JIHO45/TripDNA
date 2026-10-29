import SwiftUI
import UIKit

struct TripPhotoPageItem: Identifiable, Equatable {
    var id: Int { dayIndex }
    let dayIndex: Int
    let storagePath: String?
}

/// 하루 한 장: 한 장 크게 보고 좌우로 넘긴다. 하단 일자 스트립으로 점프한다.
struct TripPhotoPager: View {
    let items: [TripPhotoPageItem]
    @Binding var selection: Int
    /// 고정 높이 모드에서 사용. `usesPortraitHero`면 화면 너비 기준 3:4로 대체.
    var height: CGFloat = 300
    /// 사진이 없을 때 낮은 히어로 높이.
    var compactHeight: CGFloat = 168
    /// 사진 미첨부 등 — 낮은 히어로.
    var prefersCompact: Bool = false
    /// 크롭과 동일한 가로:세로 = 3:4 세로형 히어로.
    var usesPortraitHero: Bool = false
    var showsDayStrip: Bool = true
    var emptyDayMessage: String = "이 날은 아직 사진이 없어요"
    /// 상단 full-bleed + 스크롤 시 블러 (여행 상세 히어로용).
    var usesScrollHeroEffect: Bool = false
    /// 노치까지 확장할 때 상단 스크림 높이 계산용. 0이면 키 윈도우 inset을 쓴다.
    var topSafeAreaInset: CGFloat? = nil
    /// 사진·빈 칸·일자 스트립(재탭)으로 해당 일차 추가·수정을 연다.
    var onEditDay: ((Int) -> Void)? = nil
    /// `onEditDay`가 있어도 일차별로 편집 가능 여부를 나눌 때 사용.
    var canEditDay: ((Int) -> Bool)? = nil

    /// SwiftUI `aspectRatio`와 동일하게 width / height.
    private let portraitAspectRatio: CGFloat = 3.0 / 4.0

    private var allowsEditing: Bool { onEditDay != nil }

    private func isEditable(_ dayIndex: Int) -> Bool {
        guard allowsEditing else { return false }
        return canEditDay?(dayIndex) ?? true
    }

    var body: some View {
        VStack(spacing: DNASpacing.sm) {
            if usesScrollHeroEffect {
                heroPagedPhoto
            } else {
                pagedPhoto
                    .frame(height: resolvedFixedHeight)
                    .clipShape(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                            .strokeBorder(Color.dnaDivider, lineWidth: 1)
                    )
            }

            if let item = items.first(where: { $0.dayIndex == selection }) {
                VStack(spacing: 4) {
                    Text("\(item.dayIndex)일차")
                        .dnaFont(.cardTitle)
                        .foregroundStyle(.white)
                    if isEditable(item.dayIndex) {
                        Button {
                            onEditDay?(item.dayIndex)
                        } label: {
                            Text(item.storagePath == nil ? "사진 고르기" : "사진 바꾸기")
                                .dnaFont(.caption)
                                .foregroundStyle(Color.dnaData)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if showsDayStrip, items.count > 1 {
                dayStrip
            }
        }
    }

    // MARK: - Pages

    private var pagedPhoto: some View {
        TabView(selection: $selection) {
            ForEach(items) { item in
                pageContent(item)
                    .tag(item.dayIndex)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    @ViewBuilder
    private var heroPagedPhoto: some View {
        if prefersCompact {
            heroChrome(photoHeight: compactHeight)
                .frame(height: compactHeight)
        } else if usesPortraitHero {
            Color.clear
                .aspectRatio(portraitAspectRatio, contentMode: .fit)
                .overlay {
                    GeometryReader { geo in
                        heroChrome(photoHeight: geo.size.height)
                    }
                }
        } else {
            heroChrome(photoHeight: height)
                .frame(height: height)
        }
    }

    private func heroChrome(photoHeight: CGFloat) -> some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named(TripPhotoScrollSpace.name)).minY
            let pull = max(0, minY)
            let scrolled = max(0, -minY)
            // 정지: 상·하단 스크림 / 스크롤 시작 후 블러·페이드.
            let isScrolling = scrolled > 0.5
            let scrollProgress = min(1, scrolled / 120)
            let blurRadius = isScrolling ? 16 * scrollProgress : 0
            let photoFade = isScrolling ? 0.35 * scrollProgress : 0
            let topInset = resolvedTopSafeAreaInset

            ZStack(alignment: .bottom) {
                pagedPhoto
                    .scaleEffect(1 + pull / 900, anchor: .top)
                    .frame(width: geo.size.width, height: photoHeight + pull)
                    .clipped()
                    .blur(radius: blurRadius)
                    .opacity(1 - photoFade)

                // 상단: 노치·내비 컨트롤 가독성. 정지·스크롤 모두 유지하되 스크롤 시 약화.
                LinearGradient(
                    colors: [
                        Color.dnaCanvas.opacity(isScrolling ? 0.35 : 0.62),
                        Color.dnaCanvas.opacity(isScrolling ? 0.12 : 0.28),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: max(topInset + 40, 88))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

                if !isScrolling {
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.dnaCanvas.opacity(0.2),
                            Color.dnaCanvas.opacity(0.72),
                            Color.dnaCanvas
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: photoHeight * 0.32)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: photoHeight + pull, alignment: .top)
            .offset(y: -pull)
        }
    }

    @ViewBuilder
    private func pageContent(_ item: TripPhotoPageItem) -> some View {
        Group {
            if let path = item.storagePath {
                TripPhotoImage(storagePath: path)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.dnaSurface1, Color.dnaCanvas],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    VStack(spacing: 8) {
                        Image(systemName: isEditable(item.dayIndex) ? "plus.circle" : "photo")
                            .font(prefersCompact ? .title3 : .title)
                            .foregroundStyle(Color.dnaTextSecondary)
                        Text(isEditable(item.dayIndex) ? "탭해서 사진 고르기" : emptyDayMessage)
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DNASpacing.lg)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEditable(item.dayIndex) else { return }
            onEditDay?(item.dayIndex)
        }
    }

    // MARK: - Day strip

    private var dayStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button {
                            if selection == item.dayIndex, isEditable(item.dayIndex), let onEditDay {
                                onEditDay(item.dayIndex)
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selection = item.dayIndex
                                }
                            }
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    if let path = item.storagePath {
                                        TripPhotoImage(storagePath: path)
                                    } else {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                Color.dnaDivider,
                                                style: StrokeStyle(lineWidth: 1, dash: [3])
                                            )
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .font(.caption2)
                                                    .foregroundStyle(Color.dnaTextSecondary.opacity(0.7))
                                            )
                                    }
                                }
                                .frame(width: stripThumbSize.width, height: stripThumbSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(
                                            selection == item.dayIndex ? Color.dnaData : Color.clear,
                                            lineWidth: 2
                                        )
                                )

                                Text("\(item.dayIndex)일")
                                    .font(.caption2.weight(selection == item.dayIndex ? .bold : .regular))
                                    .foregroundStyle(selection == item.dayIndex ? Color.dnaData : Color.dnaTextSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(item.dayIndex)
                    }
                }
                .padding(.horizontal, usesScrollHeroEffect ? DNASpacing.lg : 0)
            }
            .onChange(of: selection) { _, day in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(day, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
        }
    }

    // MARK: - Sizing

    private var resolvedFixedHeight: CGFloat {
        if prefersCompact { return compactHeight }
        return height
    }

    private var stripThumbSize: CGSize {
        if usesPortraitHero, !prefersCompact {
            CGSize(width: 36, height: 48)
        } else {
            CGSize(width: 48, height: 48)
        }
    }

    private var resolvedTopSafeAreaInset: CGFloat {
        if let topSafeAreaInset { return topSafeAreaInset }
        return Self.keyWindowTopSafeAreaInset
    }

    private static var keyWindowTopSafeAreaInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? scenes.first?.windows.first
        return window?.safeAreaInsets.top ?? 59
    }
}


/// 사진 페이저가 스크롤 위치를 읽어 흐림을 계산하는 좌표 공간.
enum TripPhotoScrollSpace {
    static let name = "tripPhotoHeroScroll"
}

extension View {
    /// 사진 페이저를 품은 스크롤 뷰 루트에 붙인다.
    func tripPhotoHeroScrollSpace() -> some View {
        coordinateSpace(name: TripPhotoScrollSpace.name)
    }
}

#Preview("TripPhotoPager") {
    struct PreviewHost: View {
        @State private var day = 2
        var body: some View {
            ScrollView {
                TripPhotoPager(
                    items: [
                        TripPhotoPageItem(dayIndex: 1, storagePath: "local://placeholder/sun.max.fill"),
                        TripPhotoPageItem(dayIndex: 2, storagePath: "local://placeholder/water.waves"),
                        TripPhotoPageItem(dayIndex: 3, storagePath: nil)
                    ],
                    selection: $day,
                    usesPortraitHero: true,
                    usesScrollHeroEffect: true
                )
                Text("아래 콘텐츠")
                    .foregroundStyle(.white)
                    .padding()
                Color.clear.frame(height: 400)
            }
            .tripPhotoHeroScrollSpace()
            .ignoresSafeArea(edges: .top)
            .background(Color.dnaCanvas)
        }
    }
    return PreviewHost()
}
