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

    /// 라이트/다크에 따라 바뀌는 색. 시스템 외형을 그대로 따른다.
    init(light: UInt32, dark: UInt32) {
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }

    // 표면 (F · Stay + Glass 토큰 시트)
    static let dnaCanvas = Color(light: 0xFFFFFF, dark: 0x141414)
    static let dnaSurface1 = Color(light: 0xF7F7F7, dark: 0x1F1F1F)
    static let dnaSurface2 = Color(light: 0xEEEEEE, dark: 0x2A2A2A)
    static let dnaInk = Color(light: 0x222222, dark: 0x262626)
    static let dnaRaised = Color(light: 0xFFFFFF, dark: 0x262626)
    static let dnaElevated = dnaRaised
    static let dnaSheet = Color(light: 0xEDEDED, dark: 0x0E0E0E)
    static let dnaControlDark = Color(light: 0x222222, dark: 0x3A3A3A)

    // 텍스트
    static let dnaTextPrimary = Color(light: 0x222222, dark: 0xF5F5F5)
    static let dnaTextSecondary = Color(light: 0x6A6A6A, dark: 0xA3A3A3)
    static let dnaTextTertiary = Color(light: 0x929292, dark: 0x6E6E6E)

    static let dnaDivider = Color(light: 0xEBEBEB, dark: 0x2E2E2E)

    // 행동: 버튼 채움은 양쪽 동일(흰 글자), 글자·아이콘 강조는 dnaActionText
    static let dnaAction = Color(hex: 0xD93A50)
    static let dnaActionPressed = Color(hex: 0xB92F44)
    static let dnaActionText = Color(light: 0xD93A50, dark: 0xFF7A8A)

    // 데이터
    static let dnaData = Color(light: 0x0F7B73, dark: 0x4FB3A9)
    static let dnaDataMuted = Color(light: 0x7DBDB6, dark: 0x2F7C75)
    static let dnaDataFaint = Color(light: 0xBFDDD9, dark: 0x1F4D49)

    // 상태 (다크는 기존 값 유지, 아직 화면에 거의 안 씀)
    static let dnaWarning = Color(hex: 0xD9A441)
    static let dnaError = Color(hex: 0xE36D66)
    static let dnaUnverifiedBackground = Color(light: 0xFFF6E8, dark: 0x2A2418)
    static let dnaUnverifiedText = Color(light: 0x6B4A12, dark: 0xF4E3C1)

    // 선택한 칩·세그먼트 (다크는 반전)
    static let dnaSelectedBackground = Color(light: 0x222222, dark: 0xF5F5F5)
    static let dnaSelectedForeground = Color(light: 0xFFFFFF, dark: 0x141414)
    // 고르지 않은 칩·타일: 카드(흰색/다크 262626) 위에서도 보이는 옅은 회색 채움. 테두리는 두지 않는다.
    static let dnaChipFill = Color(light: 0xF7F7F7, dark: 0x333333)
    // 세그먼트 컨트롤의 선택 조각 (트랙은 dnaSurface2)
    static let dnaSegmentThumb = Color(light: 0xFFFFFF, dark: 0x4A4A4A)

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
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let gutter: CGFloat = 20
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    /// 제목과 그 아래 내용 사이.
    static let titleGap: CGFloat = 12
    /// 같은 화면의 섹션과 섹션 사이.
    static let section: CGFloat = 24
}

enum DNARadius {
    static let cell: CGFloat = 6
    static let chip: CGFloat = 14
    static let control: CGFloat = 14
    static let card: CGFloat = 18
    static let hero: CGFloat = 26
    static let capsule: CGFloat = 999
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
    private let tracking: CGFloat

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, style: Font.TextStyle? = nil, tracking: CGFloat = 0) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style ?? Self.textStyle(for: size))
        self.weight = weight
        self.design = design
        self.tracking = tracking
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design)).tracking(tracking)
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

/// 토큰 시트의 타이포 역할. 시스템 폰트(SF Pro + Apple SD Gothic Neo)만 쓴다.
enum DNAFontRole {
    case screenTitle, heroTitle, stepTitle, sectionTitle, cardTitle, body, button, caption, tabLabel

    fileprivate var spec: (size: CGFloat, weight: Font.Weight, style: Font.TextStyle, tracking: CGFloat) {
        switch self {
        case .screenTitle: (26, .heavy, .title2, -0.52)
        case .heroTitle: (21, .heavy, .title3, -0.21)
        case .stepTitle: (24, .heavy, .title2, -0.3)
        case .sectionTitle: (17, .heavy, .headline, 0)
        case .cardTitle: (15, .heavy, .subheadline, 0)
        case .body: (15, .medium, .subheadline, 0)
        case .button: (15, .heavy, .subheadline, 0)
        case .caption: (12, .semibold, .caption, 0)
        case .tabLabel: (10, .bold, .caption2, 0)
        }
    }
}

extension View {
    func dnaFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(DNAScaledFont(size: size, weight: weight, design: design))
    }

    /// 역할 이름으로 폰트를 부른다. 예: `.dnaFont(.screenTitle)`
    func dnaFont(_ role: DNAFontRole) -> some View {
        let spec = role.spec
        return modifier(DNAScaledFont(size: spec.size, weight: spec.weight, design: .default, style: spec.style, tracking: spec.tracking))
    }

    /// 떠 있는 컨트롤(탭바·사진 위 버튼) 전용 유리. iOS 26은 시스템 글래스, 이전 버전은 ultraThinMaterial.
    @ViewBuilder
    func dnaGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Buttons

/// 단색 코랄 주 행동. 위치와 크기로 먼저 읽히게 하고, 글로우로 강조하지 않는다.
struct DNAPrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dnaFont(size: 16, weight: .semibold)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(fillColor(isPressed: configuration.isPressed))
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func fillColor(isPressed: Bool) -> Color {
        if isDisabled { return Color.dnaAction.opacity(0.35) }
        return isPressed ? .dnaActionPressed : .dnaAction
    }
}

/// 보조 행동: 옅은 회색 채움, 테두리 없음, 짙은 글자. 시안의 나중에·건너뛰기·홈으로.
/// 회색 시트(`dnaSheet`) 위에서는 `onSheet`로 흰 채움을 쓴다.
struct DNASecondaryButtonStyle: ButtonStyle {
    var onSheet = false
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dnaFont(.button)
            .foregroundStyle(Color.dnaTextPrimary)
            .padding(.horizontal, fullWidth ? 0 : DNASpacing.md)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: fullWidth ? 48 : 44)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(onSheet ? Color.dnaRaised : Color.dnaSurface2)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// 검정 채움 행동: 결과 머리글의 "새 여행 추천", 홈 카드의 "여행 보기". 코랄은 화면의 핵심 행동 하나에만 쓴다.
/// 다크에서는 선택 칩과 같이 밝게 뒤집힌다. `fullWidth`가 아니면 글자 폭에 맞는다.
struct DNADarkButtonStyle: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dnaFont(.button)
            .foregroundStyle(Color.dnaSelectedForeground)
            .padding(.horizontal, DNASpacing.md)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous)
                    .fill(Color.dnaSelectedBackground)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct DNAGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dnaFont(.button)
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
    static func dnaSecondary(onSheet: Bool = false, fullWidth: Bool = true) -> DNASecondaryButtonStyle {
        DNASecondaryButtonStyle(onSheet: onSheet, fullWidth: fullWidth)
    }
}

extension ButtonStyle where Self == DNADarkButtonStyle {
    static var dnaDark: DNADarkButtonStyle { DNADarkButtonStyle() }
    static func dnaDark(fullWidth: Bool) -> DNADarkButtonStyle { DNADarkButtonStyle(fullWidth: fullWidth) }
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

    /// 제목과 버튼이 한 줄에 안 들어가면(영어·큰 글자) 단어 중간에서 끊기지 않게 버튼을 제목 아래로 내린다.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                titleBlock
                Spacer(minLength: DNASpacing.sm)
                trailing()
            }
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                titleBlock
                trailing()
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .dnaFont(.screenTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            if let subtitle {
                Text(subtitle)
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
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
            .foregroundStyle(isEmphasized ? Color.dnaTextPrimary : Color.dnaTextSecondary)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(isEmphasized ? Color.dnaSurface2 : Color.dnaTextPrimary.opacity(0.04))
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
    /// 화면 배경색. 버튼 자리는 이 색으로 불투명하게 깔아, 아래로 스크롤되는 내용이 비쳐 버튼과 겹쳐 보이지 않게 한다.
    var background: Color = .dnaCanvas
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
        // 페이드는 상단 여백 안에서만 둔다. 비율로 두면 첫 줄(체크박스·안내문) 뒤가 투명해져 내용이 겹쳐 보인다.
        .background(alignment: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(colors: [background.opacity(0), background], startPoint: .top, endPoint: .bottom)
                    .frame(height: DNASpacing.sm)
                background
            }
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
                Capsule().fill(Color.dnaTextPrimary.opacity(0.08))
                Capsule()
                    .fill(Color.dnaTextSecondary)
                    .frame(width: proxy.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 4)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((max(0, min(1, progress)) * 100).rounded())) percent")
    }
}

/// 우상단에 항상 노출하는 "건너뛰기" 텍스트 버튼.
struct DNASkipButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String = String(localized: "Skip"), action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .dnaFont(.body)
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
                            .background(Color.dnaTextPrimary.opacity(0.06), in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
                Spacer(minLength: 0)
                if let counterText {
                    Text(counterText)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                if let trailingTitle, let onTrailing {
                    Button(trailingTitle, action: onTrailing)
                        .dnaFont(.body)
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
                        .dnaFont(.sectionTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
                    if let subtitle {
                        Text(subtitle).dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .dnaFont(.caption)
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
    private let spokenLabels = [
        String(localized: "Not good"), String(localized: "Disappointing"), String(localized: "It was average"),
        String(localized: "Good"), String(localized: "The best")
    ]

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
                                    .dnaFont(.caption)
                                    .foregroundStyle(Color.dnaTextPrimary, Color.dnaElevated)
                                    .accessibilityHidden(true)
                            }
                        }
                        .scaleEffect(satisfaction == value ? 1.08 : 1)
                        .animation(.spring(duration: 0.25), value: satisfaction)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Satisfaction \(value) of 5, \(spokenLabels[value - 1])")
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
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextPrimary.opacity(0.9))
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

extension View {
    /// 칩·타일·월 칸 공통 선택 규칙. 고르지 않으면 옅은 회색 채움에 짙은 글자, 고르면 검정 채움(다크는 뒤집힘)에 흰 글자.
    /// 테두리와 체크 표시는 쓰지 않고, 접근성에는 `.isSelected`로 알린다.
    func dnaOption<S: Shape>(isSelected: Bool, in shape: S) -> some View {
        self
            .foregroundStyle(isSelected ? Color.dnaSelectedForeground : Color.dnaTextPrimary)
            .background(isSelected ? Color.dnaSelectedBackground : Color.dnaChipFill, in: shape)
    }
}

/// 선택 가능한 태그 칩. 온보딩 관심사·평가 태그·필터에서 재사용한다.
struct DNATagChip: View {
    let title: String
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .dnaFont(.cardTitle)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .dnaOption(isSelected: isSelected, in: Capsule())
                .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// 회색 트랙 위에 선택한 칸이 흰 조각으로 뜨는 세그먼트 컨트롤. 1인/일행 전체, 항공 포함/제외, 목록/내 랭킹.
struct DNASegmentedControl<V: Hashable>: View {
    let items: [(title: String, value: V)]
    let selection: V
    let onSelect: (V) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                let selected = items[index].value == selection
                Button { onSelect(items[index].value) } label: {
                    Text(items[index].title)
                        .dnaFont(.cardTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selected ? Color.dnaTextPrimary : Color.dnaTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if selected {
                                Capsule().fill(Color.dnaSegmentThumb)
                                    .shadow(color: Color.black.opacity(0.14), radius: 2, y: 1)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.dnaSurface2, in: Capsule())
        .animation(.easeOut(duration: 0.15), value: selection)
    }
}

/// 둥근 − / + 버튼 스테퍼. 회색 상자 안에 라벨, 값, 흰 원형 버튼. 인원·박수에 쓴다.
/// 값이 범위 끝이면 해당 버튼이 꺼진다. VoiceOver에서는 위아래 조절로 바꾼다.
struct DNAStepper: View {
    let label: String
    let valueText: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    /// 이미 회색 상자 안에 놓였으면 false로 두어 상자를 겹치지 않는다.
    var boxed = true

    var body: some View {
        HStack(spacing: DNASpacing.xs) {
            Text(label)
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            Spacer(minLength: DNASpacing.xs)
            button("minus", enabled: value > range.lowerBound) { value -= 1 }
            Text(valueText)
                .dnaFont(.cardTitle)
                .foregroundStyle(Color.dnaTextPrimary)
                .multilineTextAlignment(.center)
                .frame(minWidth: 56)
            button("plus", enabled: value < range.upperBound) { value += 1 }
        }
        .padding(.leading, boxed ? DNASpacing.md : 0)
        .padding(.trailing, boxed ? DNASpacing.xs : 0)
        .padding(.vertical, boxed ? DNASpacing.xs : 0)
        .background(boxed ? Color.dnaSurface1 : Color.clear, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment where value < range.upperBound: value += 1
            case .decrement where value > range.lowerBound: value -= 1
            default: break
            }
        }
    }

    private func button(_ systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(enabled ? Color.dnaTextPrimary : Color.dnaTextTertiary)
                .frame(width: 44, height: 44)
                .background(Color.dnaRaised, in: Circle())
                .overlay(Circle().strokeBorder(Color.dnaDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

/// 추천 슬롯 라벨 칩 (bestMatch=틸 / freshStretch=인디고 / underratedFit=앰버).
struct SlotChip: View {
    let slot: RecommendationSlot

    var body: some View {
        Text(slot.subtitle)
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
        VStack(alignment: .leading, spacing: DNASpacing.titleGap) {
            if let title {
                Text(title)
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
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
                        .stroke(Color.dnaTextPrimary.opacity(0.07), lineWidth: 1)
                }

                ForEach(Array(axisOrder.enumerated()), id: \.offset) { index, _ in
                    let point = vertex(index: index, radius: radius, center: center)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point)
                    }
                    .stroke(Color.dnaTextPrimary.opacity(0.06), lineWidth: 1)
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
                    Text(axis.shortLabel)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(labelColor(for: axis))
                        .position(labelPoint)
                }
            }
        }
        .frame(height: 220)
        .accessibilityElement()
        .accessibilityLabel("Taste fingerprint")
        .accessibilityValue(axes.spokenSummary(confidence: confidence))
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
        guard let confidence else { return Color.dnaTextPrimary }
        return confidence[axis] < 0.4 ? Color.dnaTextSecondary.opacity(0.6) : Color.dnaTextPrimary
    }
}

struct ScoreBadge: View {
    let score: Double

    var body: some View {
        Text("Taste match \(score.formatted(.percent.precision(.fractionLength(0))))")
            .dnaFont(.caption)
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
                        .background(Color.dnaTextPrimary.opacity(0.06), in: Capsule())
                }
            }
        }
    }
}

struct StatusPill: View {
    let status: TripStatus

    var body: some View {
        Text(status.label)
            .dnaFont(.caption)
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
        ProgressView("Loading…")
            .tint(Color.dnaData)
            .foregroundStyle(Color.dnaTextSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// AI 답변 대기 표시. 서버가 진행 단계를 주지 않으므로 실제 단계처럼 보이는 문구는 쓰지 않고,
/// 2.5초 뒤 두 번째 문구로 바꾼 다음 답이 올 때까지 그대로 둔다.
/// 깜빡임은 현재 시각에서 불투명도를 계산한다. repeatForever와 달리 백그라운드에서 돌아와도 멈추지 않는다.
struct AnswerLoadingText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var waitedLong = false

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            Text(waitedLong ? "Just a moment…" : "Preparing your answer…")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
                .contentTransition(.opacity)
                .opacity(reduceMotion ? 1 : Self.pulse(at: context.date))
        }
        .animation(.easeInOut, value: waitedLong)
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            waitedLong = true
        }
    }

    /// 1.8초 주기로 1.0과 0.4 사이를 오간다. 0.4 아래로 내려가지 않아 글자가 사라지지 않는다.
    static func pulse(at date: Date) -> Double {
        let phase = date.timeIntervalSinceReferenceDate * 2 * .pi / 1.8
        return 0.7 + 0.3 * cos(phase)
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
                    .fill(Color.dnaTextPrimary.opacity(0.06))
                    .frame(width: 64, height: 64)
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.dnaData)
            }
            Text(title)
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text(message)
                .dnaFont(.body)
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

    /// 도시가 있으면 도시 이름, 없으면 나라 이름. 목록·랭킹의 제목. 다섯 곳부터 줄인다.
    var placeTitleKo: String {
        let cities = legs.flatMap(\.cities)
        return cities.isEmpty ? titleKo : PlaceTitle.compact(cities, separator: " · ")
    }
}

/// 여행 제목의 장소 목록. 네 곳까지는 모두, 다섯 곳부터는 "앞의 3곳 외 n곳"으로 보여준다.
nonisolated enum PlaceTitle {
    static func compact(_ names: [String], separator: String) -> String {
        guard names.count > 4 else { return names.joined(separator: separator) }
        return names.prefix(3).joined(separator: separator) + " " + String(localized: "& \(names.count - 3) more")
    }
}

extension Trip {

    /// "11월 14일 – 17일" 또는 "12월 29일 – 1월 2일". 연도는 묶음 제목이 보여준다.
    var shortDateRangeKo: String {
        guard let first = legs.first?.startDate, let last = legs.last?.endDate else { return "" }
        let calendar = Calendar.current
        let start = calendar.dateComponents([.month, .day], from: first)
        let end = calendar.dateComponents([.month, .day], from: last)
        let from = first.formatted(.dateTime.month().day())
        if start.month == end.month, first != last {
            return String(localized: "\(from) – \(end.day ?? 0)")
        }
        return first == last ? from : "\(from) – \(last.formatted(.dateTime.month().day()))"
    }

    /// "2025년 12월" (시작일 기준).
    var yearMonthKo: String {
        guard let first = legs.first?.startDate else { return "" }
        return first.formatted(.dateTime.year().month(.wide))
    }

    /// 시작일까지 남은 날. 이미 시작했으면 nil.
    var daysUntilStart: Int? {
        guard let first = legs.first?.startDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: first)).day ?? 0
        return days > 0 ? days : nil
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

    /// 시드 프로필의 앱 언어 이름을 우선하고, 없으면 Locale 지역명으로 폴백한다.
    /// 거주 국가처럼 30개 목적지 밖 ISO 코드도 풀네임으로 보여주기 위함이다.
    static func name(for code: String) -> String {
        let normalized = code.uppercased()
        if let displayName = profiles[normalized]?.displayName {
            return displayName
        }
        return Locale.current.localizedString(forRegionCode: normalized) ?? normalized
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

                TextField("Search countries", text: $query)
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
                        .foregroundStyle(Color.dnaTextPrimary)

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
        fitBadges: [String(localized: "Matches your taste"), String(localized: "Matches your interests")],
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
    FitBadgesRow(badges: [String(localized: "Matches your taste"), String(localized: "Matches your interests")])
        .padding()
        .background(Color.dnaCanvas)
}

#Preview("SectionCard") {
    SectionCard(title: "Section Card") {
        Text(verbatim: "Content goes here.")
            .dnaFont(.body)
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
    EmptyStateView(title: "No data yet", message: "Register a trip and it will show up here.")
        .background(AppCanvas())
}

#Preview("CountrySelectionList") {
    @Previewable @State var code = "KR"
    CountrySelectionList(selectedCode: $code)
        .background(AppCanvas())
        .preferredColorScheme(.dark)
}
