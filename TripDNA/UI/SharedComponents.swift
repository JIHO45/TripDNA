import SwiftUI

// MARK: - Design tokens
//
// 색을 조합이 아니라 권한으로 배분하는 역할 기반 팔레트.
//   Action(코랄) : 사용자가 누를 수 있는 핵심 행동에만. 한 화면에 하나.
//   Data(틸)     : 지문·매칭·확신도처럼 데이터 의미에만.
//   Neutral      : 배경·표면·구분선·일반 아이콘·텍스트 전부.
// 화면의 분위기는 인터페이스 색이 아니라 여행 사진이 만든다.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex & 0xFF0000) >> 16) / 255
        let green = Double((hex & 0x00FF00) >> 8) / 255
        let blue = Double(hex & 0x0000FF) / 255
        self = Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    // 표면. 딥네이비 대신 약간 따뜻한 잉크 계열을 써서 여행 사진과 충돌하지 않게 한다.
    static let dnaCanvas = Color(hex: 0x11110F)
    static let dnaSurface1 = Color(hex: 0x181816)
    static let dnaSurface2 = Color(hex: 0x20201D)
    static let dnaElevated = Color(hex: 0x282824)

    // 텍스트
    static let dnaTextPrimary = Color(hex: 0xF2F0E9)
    static let dnaTextSecondary = Color(hex: 0xAAA79E)
    static let dnaTextTertiary = Color(hex: 0x747169)

    static let dnaDivider = Color.white.opacity(0.08)

    // 행동
    static let dnaAction = Color(hex: 0xF06A4F)
    static let dnaActionPressed = Color(hex: 0xD9563E)

    // 데이터
    static let dnaData = Color(hex: 0x62B8AA)
    static let dnaDataMuted = Color(hex: 0x355F59)

    // 상태
    static let dnaWarning = Color(hex: 0xD9A441)
    static let dnaError = Color(hex: 0xE36D66)

    // MARK: 이전 이름
    //
    // 모든 화면이 역할 토큰으로 옮겨졌다. 새 코드에서 쓰면 경고가 나도록 남겨 둔다.
    @available(*, deprecated, renamed: "dnaCanvas") static let dnaBackground = Color.dnaCanvas
    @available(*, deprecated, renamed: "dnaSurface1") static let dnaSurface = Color.dnaSurface1
    @available(*, deprecated, renamed: "dnaSurface2") static let dnaSurfaceElevated = Color.dnaSurface2
    @available(*, deprecated, renamed: "dnaTextSecondary") static let dnaSlate = Color.dnaTextSecondary
    @available(*, deprecated, renamed: "dnaDivider") static let dnaHairline = Color.dnaDivider
    @available(*, deprecated, renamed: "dnaAction") static let dnaCoral = Color.dnaAction
    @available(*, deprecated, renamed: "dnaData") static let dnaTeal = Color.dnaData
    @available(*, deprecated, renamed: "dnaWarning") static let dnaAmber = Color.dnaWarning
    @available(*, deprecated, renamed: "dnaTextTertiary") static let dnaIndigo = Color.dnaTextTertiary
}

enum DNASpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum DNARadius {
    static let card: CGFloat = 24
    static let control: CGFloat = 16
    static let chip: CGFloat = 999
}

/// 모든 화면의 기본 표면. 균일한 웜 잉크 캔버스 한 장이다.
/// 화면마다 다른 조명을 주면 내용이 달라도 같은 템플릿으로 읽히므로 글로우를 두지 않는다.
struct AppCanvas: View {
    var body: some View {
        Color.dnaCanvas.ignoresSafeArea()
    }
}

@available(*, deprecated, renamed: "AppCanvas")
typealias AuroraBackground = AppCanvas

/// `ScrollView`/`List`/`Form` 루트에 적용해 캔버스와 다크 스크롤 배경을 통일한다.
struct DNAScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(AppCanvas())
    }
}

extension View {
    func dnaBackground() -> some View {
        modifier(DNAScreenBackground())
    }

    /// iOS 26 시스템 scroll edge blur. 상단에 tint 막대를 올리지 않고, 지나가는 콘텐츠 자체를 흐리게 한다.
    @ViewBuilder
    func dnaTopScrollBlur() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}

// MARK: - Scaled Type

/// 디자인이 정한 pt 크기를 기준으로 두되, 사용자의 글자 크기 설정을 따라 함께 커진다.
/// 이미지로 렌더링되는 공유 카드처럼 크기가 고정돼야 하는 곳에는 쓰지 않는다.
private struct DNAScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: Self.textStyle(for: size))
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<12: .caption2
        case ..<14: .footnote
        case ..<16: .subheadline
        case ..<18: .body
        case ..<23: .title3
        case ..<29: .title2
        default: .title
        }
    }
}

extension View {
    func dnaFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(DNAScaledFont(size: size, weight: weight, design: design))
    }
}

// MARK: - Buttons

/// 단색 코랄 주 행동. 위치와 크기로 먼저 읽히게 하고, 글로우로 강조하지 않는다.
struct DNAPrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dnaFont(size: 16, weight: .semibold)
            .foregroundStyle(isDisabled ? Color.dnaTextTertiary : Color.dnaCanvas)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func fillColor(isPressed: Bool) -> Color {
        if isDisabled { return Color.white.opacity(0.08) }
        return isPressed ? .dnaActionPressed : .dnaAction
    }
}

struct DNASecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule(style: .continuous).fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule(style: .continuous).strokeBorder(Color.dnaDivider, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct DNAGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(Color.dnaTextSecondary)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == DNAPrimaryButtonStyle {
    static var dnaPrimary: DNAPrimaryButtonStyle { DNAPrimaryButtonStyle() }
    static func dnaPrimary(isDisabled: Bool) -> DNAPrimaryButtonStyle { DNAPrimaryButtonStyle(isDisabled: isDisabled) }
}

extension ButtonStyle where Self == DNASecondaryButtonStyle {
    static var dnaSecondary: DNASecondaryButtonStyle { DNASecondaryButtonStyle() }
}

extension ButtonStyle where Self == DNAGhostButtonStyle {
    static var dnaGhost: DNAGhostButtonStyle { DNAGhostButtonStyle() }
}

/// 탭 루트 공통 헤더. 타이틀은 항상 `.title2.bold()`, 자막은 caption.
struct DNAScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, subtitle: String? = nil, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            }
            Spacer(minLength: DNASpacing.sm)
            trailing()
        }
    }
}

/// 헤더와 본문을 가르는 full-bleed 구분선. 가로 패딩 없이 화면 끝까지 이은다.
struct DNAHeaderDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.dnaDivider)
            .frame(height: 1)
            .padding(.horizontal, -DNASpacing.lg)
    }
}

/// 상단 액션 아이콘. 여행 목록의 현재/예정/지난 세그먼트 칩과 동일한 톤.
struct DNACircleIcon: View {
    let systemImage: String
    var isEmphasized: Bool = true
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(isEmphasized ? .white : Color.dnaTextSecondary)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isEmphasized ? Color.dnaSurface2 : Color.white.opacity(0.04))
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        isEmphasized ? Color.dnaData.opacity(0.5) : Color.dnaDivider,
                        lineWidth: 1
                    )
            )
    }
}

/// 화면 하단에 고정하는 코랄 CTA. 한 화면에 주 행동 하나만 두는 원칙을 강제한다.
struct DNABottomCTA<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: DNASpacing.sm) {
            content()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DNASpacing.lg)
        .padding(.top, DNASpacing.sm)
        .padding(.bottom, DNASpacing.md)
        // safeAreaInset에서도 좌우 inset이 빠지지 않도록 배경은 패딩 바깥에 깔고,
        // 버튼 콘텐츠 폭은 명시적으로 화면 가로 - lg*2 를 유지한다.
        .background(alignment: .bottom) {
            LinearGradient(
                colors: [Color.dnaCanvas.opacity(0), Color.dnaCanvas.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
            .padding(.horizontal, -DNASpacing.lg)
        }
    }
}

// MARK: - Progress & skip

/// 상단 세그먼트 진행 바. 온보딩·퀴즈 전반에서 재사용한다.
struct DNASegmentedProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(Color.dnaTextSecondary)
                    .frame(width: proxy.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("진행률")
        .accessibilityValue("\(Int((max(0, min(1, progress)) * 100).rounded()))퍼센트")
    }
}

/// 우상단에 항상 노출하는 "건너뛰기" 텍스트 버튼.
struct DNASkipButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String = "건너뛰기", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }
}

/// 진행 바 + "현재/전체" 카운터 + 우상단 텍스트 버튼을 묶은 스텝 상단 바.
/// 온보딩 퀴즈·스캔 카드 루프·종료 평가처럼 단계형 플로우 상단에 사용한다.
struct DNAStepTopBar: View {
    var progress: Double
    var counterText: String?
    var trailingTitle: String?
    var onBack: (() -> Void)?
    var onTrailing: (() -> Void)?

    var body: some View {
        VStack(spacing: DNASpacing.sm) {
            HStack(spacing: DNASpacing.sm) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.dnaTextSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.06), in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("뒤로")
                }
                Spacer(minLength: 0)
                if let counterText {
                    Text(counterText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.dnaTextSecondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                if let trailingTitle, let onTrailing {
                    Button(trailingTitle, action: onTrailing)
                        .font(.subheadline)
                        .foregroundStyle(Color.dnaTextSecondary)
                } else if onBack != nil {
                    // 좌측 뒤로가기와 시각 균형을 맞추는 자리 채움.
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            DNASegmentedProgressBar(progress: progress)
        }
        .padding(.horizontal, DNASpacing.lg)
        .padding(.top, DNASpacing.sm)
    }
}

// MARK: - Selection cards

/// 사진첩/직접입력/퀴즈처럼 동등하게 배치되는 선택 카드.
struct DNASelectableCard: View {
    var systemImage: String
    var title: String
    var subtitle: String?
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DNASpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: DNARadius.control - 4, style: .continuous)
                        .fill(Color.dnaSurface2)
                        .frame(width: 44, height: 44)
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(Color.dnaTextPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.dnaTextPrimary)
                    if let subtitle {
                        Text(subtitle).font(.caption).foregroundStyle(Color.dnaTextSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .padding(DNASpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(isSelected ? Color.dnaElevated : Color.dnaSurface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .strokeBorder(isSelected ? Color.dnaTextSecondary.opacity(0.5) : Color.dnaDivider, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 퀴즈 A/B 선택지처럼 텍스트 위주의 카드형 버튼.
struct DNAChoiceCard: View {
    var text: String
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DNASpacing.sm) {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.dnaTextPrimary : Color.dnaTextTertiary)
                    .accessibilityHidden(true)
            }
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color.dnaTextPrimary)
                .padding(DNASpacing.md)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(
                    RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                        .fill(isSelected ? Color.dnaElevated : Color.dnaSurface1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                        .strokeBorder(isSelected ? Color.dnaTextSecondary.opacity(0.5) : Color.dnaDivider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - One-tap inputs

/// 만족도 1~5 원탭 이모지 행. 스캔 카드 루프·수동 등록·종료 평가에서 재사용한다.
/// 중립색 테두리와 체크 표시로 선택 상태를 구분한다.
struct DNASatisfactionEmojiRow: View {
    @Binding var satisfaction: Int?
    var onSelect: ((Int) -> Void)?

    private let emojis = ["😞", "😕", "😐", "😊", "🤩"]
    private let spokenLabels = ["별로였어요", "아쉬웠어요", "보통이었어요", "좋았어요", "최고였어요"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    satisfaction = value
                    onSelect?(value)
                } label: {
                    Text(emojis[value - 1])
                        .font(.system(size: 30))
                        .frame(width: 56, height: 56)
                        .background(
                            Circle().fill(
                                satisfaction == value ? Color.dnaElevated : Color.dnaSurface1
                            )
                        )
                        .overlay(
                            Circle().strokeBorder(
                                satisfaction == value ? Color.dnaTextSecondary : Color.dnaDivider,
                                lineWidth: satisfaction == value ? 2 : 1
                            )
                        )
                        .overlay(alignment: .bottomTrailing) {
                            if satisfaction == value {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.dnaTextPrimary, Color.dnaElevated)
                                    .accessibilityHidden(true)
                            }
                        }
                        .scaleEffect(satisfaction == value ? 1.08 : 1)
                        .animation(.spring(duration: 0.25), value: satisfaction)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("만족도 \(value)점, \(spokenLabels[value - 1])")
                .accessibilityAddTraits(satisfaction == value ? .isSelected : [])
                .frame(maxWidth: .infinity)
            }
        }
    }
}

/// 권한 요청·데이터 경계처럼 신뢰가 필요한 지점에 쓰는 방패 아이콘 패널.
struct DNATrustPanel: View {
    var systemImage: String = "lock.shield.fill"
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DNASpacing.sm) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(Color.dnaData)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                .fill(Color.dnaData.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                .strokeBorder(Color.dnaData.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Chips

/// 좌측 정렬 플로우 레이아웃. 태그 칩 나열에 사용한다.
struct DNAFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in computeRows(proposal: proposal, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let addedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if addedWidth > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// 선택 가능한 태그 칩. 온보딩 관심사·평가 태그·필터에서 재사용한다.
struct DNATagChip: View {
    let title: String
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DNASpacing.xs) {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.dnaTextPrimary : Color.dnaTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(isSelected ? Color.dnaElevated : Color.dnaSurface1, in: Capsule())
            .overlay {
                Capsule().strokeBorder(
                    isSelected ? Color.dnaTextSecondary.opacity(0.5) : Color.dnaDivider,
                    lineWidth: 1
                )
            }
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 추천 슬롯 라벨 칩 (bestMatch=틸 / freshStretch=인디고 / underratedFit=앰버).
struct SlotChip: View {
    let slot: RecommendationSlot

    var body: some View {
        Text(slot.subtitleKo)
            .font(.caption.weight(.bold))
            .foregroundStyle(slot.accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(slot.accentColor.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(slot.accentColor.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Cards & badges

/// 24pt 라운드, 소프트 글로우 카드. 전 화면 공통 컨테이너.
struct SectionCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            content()
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .fill(Color.dnaSurface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous)
                .strokeBorder(Color.dnaDivider, lineWidth: 1)
        )
        .shadow(color: Color.dnaTextTertiary.opacity(0.12), radius: 20, y: 8)
    }
}

/// 5축 지문을 발광 지문(펜타곤) 형태로 시각화하는 히어로 컴포넌트.
/// 홈·지문 상세·온보딩 결과처럼 "첫인상"을 심어야 하는 위치에 사용한다.
struct FingerprintRadarView: View {
    let axes: TasteAxes
    var confidence: AxisConfidence?

    private let axisOrder = TasteAxis.allCases

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = size / 2 - 28

            ZStack {
                ForEach(1...3, id: \.self) { ring in
                    polygon(radius: radius * CGFloat(ring) / 3, center: center)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                }

                ForEach(Array(axisOrder.enumerated()), id: \.offset) { index, _ in
                    let point = vertex(index: index, radius: radius, center: center)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point)
                    }
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }

                valuePolygon(center: center, radius: radius)
                    .fill(
                        LinearGradient(colors: [.dnaTextTertiary.opacity(0.5), .dnaData.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                    )
                valuePolygon(center: center, radius: radius)
                    .stroke(Color.dnaData, lineWidth: 2)
                    .shadow(color: Color.dnaData.opacity(0.7), radius: 10)

                ForEach(Array(axisOrder.enumerated()), id: \.offset) { index, axis in
                    let labelPoint = vertex(index: index, radius: radius + 20, center: center)
                    Text(axis.shortLabelKo)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(labelColor(for: axis))
                        .position(labelPoint)
                }
            }
        }
        .frame(height: 220)
        .accessibilityElement()
        .accessibilityLabel("취향 지문")
        .accessibilityValue(axes.spokenSummaryKo(confidence: confidence))
    }

    private func angle(for index: Int) -> CGFloat {
        let count = CGFloat(axisOrder.count)
        return -CGFloat.pi / 2 + (2 * .pi / count) * CGFloat(index)
    }

    private func normalized(_ axis: TasteAxis) -> CGFloat {
        CGFloat((axes[axis] + 1) / 2)
    }

    private func vertex(index: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = angle(for: index)
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }

    private func polygon(radius: CGFloat, center: CGPoint) -> Path {
        var path = Path()
        for index in axisOrder.indices {
            let point = vertex(index: index, radius: radius, center: center)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private func valuePolygon(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for (index, axis) in axisOrder.enumerated() {
            let point = vertex(index: index, radius: radius * normalized(axis), center: center)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private func labelColor(for axis: TasteAxis) -> Color {
        guard let confidence else { return .white }
        return confidence[axis] < 0.4 ? Color.dnaTextSecondary.opacity(0.6) : .white
    }
}

struct ScoreBadge: View {
    let score: Double

    var body: some View {
        Text("취향 매치 \(Int((score * 100).rounded()))%")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.dnaData.opacity(0.16), in: Capsule())
            .foregroundStyle(Color.dnaData)
    }
}

struct FitBadgesRow: View {
    let badges: [String]

    var body: some View {
        if !badges.isEmpty {
            HStack(spacing: 6) {
                ForEach(badges, id: \.self) { badge in
                    Text(badge)
                        .font(.caption2)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
        }
    }
}

struct StatusPill: View {
    let status: TripStatus

    var body: some View {
        Text(status.labelKo)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    /// 상태는 행동도 데이터도 아니므로 뉴트럴로 둔다.
    /// 사용자 조치가 남은 "평가 대기"만 경고색을 갖는다.
    private var color: Color {
        switch status {
        case .ended: .dnaWarning
        case .planned, .active, .evaluated, .skippedEvaluation: .dnaTextSecondary
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ProgressView("불러오는 중…")
            .tint(Color.dnaData)
            .foregroundStyle(Color.dnaTextSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 빈 상태는 막힌 화면이 아니라 다음 행동으로 이어져야 한다. 갈 곳이 있으면 `actionTitle`을 준다.
struct EmptyStateView: View {
    var systemImage: String = "airplane.departure"
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 64, height: 64)
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.dnaData)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.dnaTextSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.dnaSecondary)
                    .frame(maxWidth: 260)
                    .padding(.top, DNASpacing.sm)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension Trip {
    var titleKo: String {
        legs.map { CountryCatalog.name(for: $0.countryCode) }.joined(separator: " · ")
    }

    var dateRangeKo: String {
        guard let first = legs.first, let last = legs.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return "\(formatter.string(from: first.startDate)) - \(formatter.string(from: last.endDate))"
    }
}

enum CountryCatalog {
    static var profiles: [String: CountryProfile] = [:]

    /// 시드 프로필의 한국어 이름을 우선하고, 없으면 Locale 한글 지역명으로 폴백한다.
    /// 거주 국가처럼 30개 목적지 밖 ISO 코드도 풀네임으로 보여주기 위함이다.
    static func name(for code: String) -> String {
        let normalized = code.uppercased()
        if let nameKo = profiles[normalized]?.nameKo {
            return nameKo
        }
        return Locale(identifier: "ko_KR").localizedString(forRegionCode: normalized)
            ?? Locale.current.localizedString(forRegionCode: normalized)
            ?? normalized
    }
}

/// 세계 모든 ISO 국가 코드를 대상으로 검색 가능한 선택 목록.
/// 홈 국가 확인처럼 30개 목적지 카탈로그를 벗어난 범용 국가 선택에 사용한다.
struct CountrySelectionList: View {
    @Binding var selectedCode: String
    @State private var query = ""

    private var allCountries: [(code: String, name: String)] {
        NSLocale.isoCountryCodes.compactMap { code in
            guard let name = Locale.current.localizedString(forRegionCode: code) else { return nil }
            return (code: code, name: name)
        }
        .sorted { $0.name < $1.name }
    }

    private var filteredCountries: [(code: String, name: String)] {
        guard !query.isEmpty else { return allCountries }
        return allCountries.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: DNASpacing.sm) {
            HStack(spacing: DNASpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.dnaTextSecondary)

                TextField("국가 검색", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DNASpacing.md)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(Color.dnaSurface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .stroke(Color.dnaDivider)
            )

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCountries, id: \.code) { country in
                        Button {
                            selectedCode = country.code
                        } label: {
                            HStack {
                                Text(country.name)
                                Spacer()
                                if country.code == selectedCode {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.dnaData)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DNASpacing.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)

                        Divider()
                            .overlay(Color.dnaDivider)
                    }
                }
            }
        }
        .padding(.horizontal, DNASpacing.lg)
    }
}

enum PreviewSample {
    static let axes = TasteAxes(
        natureUrban: 0.35,
        energyLevel: 0.55,
        planningStyle: -0.2,
        socialMode: 0.15,
        noveltyAppetite: 0.4
    )

    static let confidence = AxisConfidence(
        natureUrban: 0.7,
        energyLevel: 0.55,
        planningStyle: 0.4,
        socialMode: 0.35,
        noveltyAppetite: 0.5
    )

    static let vector = UserTasteVector(
        userID: "preview-user",
        axes: axes,
        confidence: confidence,
        ledgerVersion: 1,
        recomputedAt: Date()
    )

    static let recommendation = Recommendation(
        countryCode: "JP",
        slot: .bestMatch,
        matchScore: 0.82,
        explanationTagIDs: ["food", "culture"],
        rankingAnchorTripID: nil,
        fitBadges: ["취향 일치", "관심사 매치"],
        notices: []
    )
}

extension View {
    /// Preview용 `AppDependencies` + `SessionStore` 환경 주입.
    func previewWithAppEnvironment(
        configureSession: ((SessionStore) -> Void)? = nil
    ) -> some View {
        let session = SessionStore()
        configureSession?(session)
        return self
            .environment(AppDependencies(persistence: .inMemory))
            .environment(session)
            .environment(AppRouter())
            .preferredColorScheme(.dark)
    }
}

#Preview("FingerprintRadarView") {
    FingerprintRadarView(axes: PreviewSample.axes, confidence: PreviewSample.confidence)
        .padding()
        .background(AppCanvas())
        .preferredColorScheme(.dark)
}

#Preview("ScoreBadge") {
    ScoreBadge(score: 0.82)
        .padding()
        .background(Color.dnaCanvas)
}

#Preview("FitBadgesRow") {
    FitBadgesRow(badges: ["취향 일치", "관심사 매치"])
        .padding()
        .background(Color.dnaCanvas)
}

#Preview("SectionCard") {
    SectionCard(title: "섹션 카드") {
        Text("내용이 여기에 들어가요.")
            .font(.subheadline)
            .foregroundStyle(Color.dnaTextSecondary)
    }
    .padding()
    .background(AppCanvas())
}

#Preview("StatusPill") {
    HStack {
        StatusPill(status: .planned)
        StatusPill(status: .active)
        StatusPill(status: .ended)
        StatusPill(status: .evaluated)
    }
    .padding()
    .background(Color.dnaCanvas)
}

#Preview("LoadingView") {
    LoadingView()
        .background(AppCanvas())
}

#Preview("EmptyStateView") {
    EmptyStateView(title: "아직 데이터가 없어요", message: "여행을 등록하면 여기에 표시돼요.")
        .background(AppCanvas())
}

#Preview("CountrySelectionList") {
    @Previewable @State var code = "KR"
    CountrySelectionList(selectedCode: $code)
        .background(AppCanvas())
        .preferredColorScheme(.dark)
}
