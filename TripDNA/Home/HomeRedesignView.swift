import SwiftUI

// MARK: - 홈

/// 대시보드가 아니라 여행 저널의 첫 페이지로 구성한 홈.
/// 카드를 쓰지 않고 캔버스 위에 메타 → 지문 문장 → 능선 → 지난 여행 → 다음 여행지 순으로 흐른다.
struct HomeRedesignView: View {
    @Binding var selection: MainTab
    @Environment(AppDependencies.self) private var dependencies
    @State private var viewModel = HomeViewModel()
    @State private var showingProfile = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                metaHeader

                if viewModel.isLoading, viewModel.vector == nil {
                    ProgressView()
                        .tint(Color.dnaTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                } else if let vector = viewModel.vector {
                    fingerprintOpening(vector)
                    lastTripChapter
                    nextDestinationChapter
                    wrappedLink
                } else {
                    emptyFingerprintOpening
                }
            }
            .padding(.bottom, 28)
        }
        .dnaTopScrollBlur()
        .background(Color.dnaCanvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { bottomAction }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingProfile) { ProfileSheet() }
        .task { await viewModel.load(dependencies) }
        .refreshable { await viewModel.load(dependencies) }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    // MARK: 상단 메타

    @ViewBuilder
    private var wrappedLink: some View {
        if viewModel.isSeasonOpen {
            NavigationLink("올해의 Wrapped") { WrappedView(forcePreview: false) }
                .padding(20)
                .accessibilityIdentifier("home.wrapped")
        } else {
            #if DEBUG
            NavigationLink("Wrapped 미리보기") { WrappedView(forcePreview: true) }
                .padding(20)
                .accessibilityIdentifier("home.wrapped")
            #endif
        }
    }

    /// 인사말 대신 지금 여행자가 어디쯤 있는지를 알려주는 한 줄.
    private var metaHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            // 한글에는 자간·고정폭을 쓰지 않는다. 물성은 영문 메타데이터에서만 낸다.
            Text(HomeNarrative.metaLine(trips: viewModel.trips))
                .dnaFont(size: 13, weight: .regular)
                .foregroundStyle(Color.dnaTextTertiary)

            Spacer(minLength: 12)

            Button {
                showingProfile = true
            } label: {
                Image(systemName: "person")
                    .dnaFont(size: 17, weight: .regular)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("프로필")
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    // MARK: 지문 도입부

    private func fingerprintOpening(_ vector: UserTasteVector) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(HomeNarrative.heroSentence(axes: vector.axes, confidence: vector.confidence))
                .dnaFont(size: 31, weight: .regular)
                .foregroundStyle(Color.dnaTextPrimary)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 26)

            Text(HomeNarrative.evidence(trips: viewModel.trips))
                .dnaFont(size: 14)
                .foregroundStyle(Color.dnaTextSecondary)
                .padding(.top, 14)

            NavigationLink {
                FingerprintDetailView()
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    FingerprintRidge(axes: vector.axes, confidence: vector.confidence)
                        .padding(.top, 30)

                    chapterLinkLabel("취향 자세히 보기")
                        .padding(.top, 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    /// 지문이 없는 상태. touchid 심볼이나 빈 카드 대신, 아직 형태를 잡지 못한 능선을 보여준다.
    private var emptyFingerprintOpening: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("여행 하나가 모이면\n첫 지문이 만들어집니다")
                .dnaFont(size: 31, weight: .regular)
                .foregroundStyle(Color.dnaTextPrimary)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 26)

            Text("여행 탭에서 첫 여행을 등록해보세요")
                .dnaFont(size: 14)
                .foregroundStyle(Color.dnaTextSecondary)
                .padding(.top, 14)

            FingerprintRidge(
                axes: HomeNarrative.dormantAxes,
                confidence: HomeNarrative.dormantConfidence
            )
            .padding(.top, 30)
        }
        .padding(.horizontal, 20)
    }

    // MARK: 지난 여행

    @ViewBuilder
    private var lastTripChapter: some View {
        if let trip = HomeNarrative.mostRecentFinishedTrip(viewModel.trips) {
            VStack(alignment: .leading, spacing: 0) {
                sectionRule

                EditorialLabel("지난 여행")
                    .padding(.horizontal, 20)
                    .padding(.top, 30)

                NavigationLink {
                    TripDetailView(tripID: trip.id)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        // 사진이 표면 자체가 되도록 컨테이너 없이 화면 폭 전체를 쓴다.
                        if let image = realPhoto(for: trip) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 250)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .padding(.top, 16)
                        }

                        Text(HomeNarrative.tripSentence(trip))
                            .dnaFont(size: 21, weight: .regular)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 20)
                            .padding(.top, 18)

                        Text(HomeNarrative.photoMeta(trip))
                            .dnaFont(size: 11, weight: .medium, design: .monospaced)
                            .foregroundStyle(Color.dnaTextTertiary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)

                        chapterLinkLabel("여행 기록 보기")
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func realPhoto(for trip: Trip) -> UIImage? {
        let candidates = [trip.coverPhotoStoragePath].compactMap { $0 }
            + viewModel.photos.filter { $0.tripID == trip.id }.map(\.storagePath)
        return candidates.lazy.compactMap { LocalPhotoStore.image(at: $0) }.first
    }

    // MARK: 다음 여행지

    @ViewBuilder
    private var nextDestinationChapter: some View {
        if let best = viewModel.bestMatch {
            VStack(alignment: .leading, spacing: 0) {
                sectionRule

                EditorialLabel("다음 여행지")
                    .padding(.top, 30)

                Button {
                    selection = .recommendation
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(CountryCatalog.name(for: best.countryCode))
                            .dnaFont(size: 27, weight: .medium)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .padding(.top, 14)

                        Text(HomeNarrative.recommendationReason(best))
                            .dnaFont(size: 15)
                            .foregroundStyle(Color.dnaTextSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)

                        // 매칭 수치만 데이터 색을 갖고, 이유는 뉴트럴로 이어 붙인다.
                        HStack(spacing: 6) {
                            Text("\(Int((best.matchScore * 100).rounded()))% 일치")
                                .dnaFont(size: 13, weight: .medium, design: .monospaced)
                                .foregroundStyle(Color.dnaData)
                            Text("·")
                                .foregroundStyle(Color.dnaTextTertiary)
                            Text(best.slot.subtitleKo)
                                .dnaFont(size: 13)
                                .foregroundStyle(Color.dnaTextTertiary)
                                .lineLimit(1)
                        }
                        .padding(.top, 12)

                        chapterLinkLabel("추천 여행지 보기")
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onScrollVisibilityChange(threshold: 0.5) { visible in
                    guard visible, let exposure = viewModel.exposure else { return }
                    Task { await exposure.record(best, dependencies: dependencies) }
                }
                .id(viewModel.exposure?.id)
            }
            .padding(.horizontal, 20)
        }
    }

    /// 각 장의 끝에 같은 이동 단서를 두어 본문과 함께 누를 수 있음을 알린다.
    private func chapterLinkLabel(_ title: String) -> some View {
        HStack(spacing: 6) {
            Spacer(minLength: 0)
            Text(title)
                .dnaFont(size: 13, weight: .medium)
            Image(systemName: "chevron.right")
                .dnaFont(size: 10, weight: .semibold)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.dnaTextSecondary)
        .frame(minHeight: 44)
    }

    private var sectionRule: some View {
        Rectangle()
            .fill(Color.dnaDivider)
            .frame(height: 1)
            .padding(.top, 36)
    }

    // MARK: 하단 주 행동 (화면에서 코랄을 쓰는 유일한 지점)

    private var bottomAction: some View {
        actionButton
            .padding(.horizontal, 20)
            .padding(.top, 44)
            .padding(.bottom, 8)
            .background(alignment: .bottom) {
                // 지나가는 콘텐츠가 버튼 뒤에서 비치지 않도록 페이드 구간을 길게 잡는다.
                LinearGradient(
                    stops: [
                        .init(color: Color.dnaCanvas.opacity(0), location: 0),
                        .init(color: Color.dnaCanvas.opacity(0.78), location: 0.22),
                        .init(color: Color.dnaCanvas, location: 0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch viewModel.primaryAction {
        case .evaluate(let tripID, _), .dailyPhoto(let tripID, _), .activeTrip(let tripID, _):
            NavigationLink {
                TripDetailView(tripID: tripID)
            } label: {
                Text(actionTitle)
            }
            .buttonStyle(.dnaPrimary)
        case .upcoming:
            Button {
                selection = .trips
            } label: {
                Text(actionTitle)
            }
            .buttonStyle(.dnaPrimary)
        case .registerFirstTrip:
            NavigationLink {
                TripRegistrationView(prefilledCountryCode: nil)
            } label: {
                Text(actionTitle)
            }
            .buttonStyle(.dnaPrimary)
        }
    }

    private var actionTitle: String {
        switch viewModel.primaryAction {
        case .evaluate: "여행 평가하기"
        case .dailyPhoto: "오늘의 한 장 고르기"
        case .activeTrip: "오늘의 한 장 바꾸기"
        case .upcoming: "여행 일정 보기"
        case .registerFirstTrip: "첫 여행 등록하기"
        }
    }

}

// MARK: - 지문 능선

/// 5축 값을 하나의 능선으로 잇는 데이터 전용 시각화.
/// 레이더와 달리 값의 방향(위/아래)과 확신도(선·노드의 농도)를 같은 그림에서 읽게 한다.
struct FingerprintRidge: View {
    let axes: TasteAxes
    var confidence: AxisConfidence?
    var height: CGFloat = 118

    private let order = TasteAxis.allCases

    /// 데이터가 쌓일수록 능선이 진해진다. 확신도가 낮으면 형태만 암시한다.
    private var averageConfidence: Double {
        guard let confidence else { return 1 }
        return order.reduce(0) { $0 + confidence[$1] } / Double(order.count)
    }

    var body: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let plotHeight = proxy.size.height
                let points = points(width: width, height: plotHeight)

                ZStack {
                    // 강도 절반 위치의 참조선.
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: plotHeight * 0.55))
                        path.addLine(to: CGPoint(x: width, y: plotHeight * 0.55))
                    }
                    .stroke(Color.dnaDivider, style: StrokeStyle(lineWidth: 1, dash: [1, 5]))

                    ridge(points: points, width: width, height: plotHeight, filled: true)
                        .fill(
                            LinearGradient(
                                colors: [Color.dnaData.opacity(0.04 + 0.18 * averageConfidence), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    ridge(points: points, width: width, height: plotHeight, filled: false)
                        .stroke(
                            Color.dnaData.opacity(0.4 + 0.6 * averageConfidence),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                        )

                    ForEach(Array(order.enumerated()), id: \.offset) { index, axis in
                        node(for: axis).position(points[index])
                    }
                }
            }
            .frame(height: height)

            axisLabels
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("취향 지문 5축 능선")
        .accessibilityValue(axes.spokenSummaryKo(confidence: confidence))
    }

    /// 축 이름 대신 지금 기울어 있는 극을 보여준다.
    /// 음수는 약함이 아니라 반대 극이므로, 숫자만 두면 "데이터가 적다"로 오해된다.
    private var axisLabels: some View {
        HStack(spacing: 0) {
            ForEach(order, id: \.self) { axis in
                VStack(spacing: 3) {
                    Text(poleLabel(for: axis))
                        .dnaFont(size: 13, weight: .medium)
                        .foregroundStyle(Color.dnaTextSecondary.opacity(opacity(for: axis)))
                    Text(strengthText(for: axis))
                        .dnaFont(size: 11, weight: .medium, design: .monospaced)
                        .foregroundStyle(Color.dnaTextTertiary.opacity(opacity(for: axis)))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func poleLabel(for axis: TasteAxis) -> String {
        let isPositive = axes[axis] > 0
        switch axis {
        case .natureUrban: return isPositive ? "도시" : "자연"
        case .energyLevel: return isPositive ? "활동" : "휴식"
        case .planningStyle: return isPositive ? "계획" : "즉흥"
        case .socialMode: return isPositive ? "함께" : "혼자"
        case .noveltyAppetite: return isPositive ? "새로움" : "익숙함"
        }
    }

    private func node(for axis: TasteAxis) -> some View {
        Circle()
            .fill(Color.dnaCanvas)
            .frame(width: 7, height: 7)
            .overlay(
                Circle().strokeBorder(Color.dnaData.opacity(opacity(for: axis)), lineWidth: 1.6)
            )
    }

    private func opacity(for axis: TasteAxis) -> Double {
        max(0.3, confidence?[axis] ?? 1)
    }

    /// 부호는 극 라벨이 이미 말해주므로 강도만 남긴다.
    private func strengthText(for axis: TasteAxis) -> String {
        String(format: "%.2f", abs(axes[axis]))
    }

    /// 높이는 축의 강도만 나타낸다. 어느 극으로 기울었는지는 아래 라벨이 말한다.
    /// 부호를 높이에 그대로 쓰면 반대 극이 "약한 축"으로 잘못 읽힌다.
    private func points(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let floor = height - 6
        let ceiling: CGFloat = 8
        return order.enumerated().map { index, axis in
            // 실제 축 값은 대부분 0.8 안쪽에 모이므로, 그 범위를 전체 높이로 펴서 차이를 보이게 한다.
            let strength = min(1, abs(CGFloat(axes[axis])) / 0.8)
            return CGPoint(
                x: width * (CGFloat(index) + 0.5) / CGFloat(order.count),
                y: floor - (floor - ceiling) * strength
            )
        }
    }

    /// Catmull-Rom 보간으로 축 사이를 부드럽게 잇고, 좌우 끝은 첫·마지막 값 높이로 연장한다.
    private func ridge(points: [CGPoint], width: CGFloat, height: CGFloat, filled: Bool) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }

        let all = [CGPoint(x: 0, y: first.y)] + points + [CGPoint(x: width, y: last.y)]
        path.move(to: all[0])
        for index in 0..<(all.count - 1) {
            let previous = all[max(0, index - 1)]
            let start = all[index]
            let end = all[index + 1]
            let next = all[min(all.count - 1, index + 2)]
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x + (end.x - previous.x) / 6, y: start.y + (end.y - previous.y) / 6),
                control2: CGPoint(x: end.x - (next.x - start.x) / 6, y: end.y - (next.y - start.y) / 6)
            )
        }

        if filled {
            path.addLine(to: CGPoint(x: width, y: height))
            path.addLine(to: CGPoint(x: 0, y: height))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - 편집용 섹션 라벨

/// 카드 타이틀이 아니라 잡지 목차의 꼬리표 역할. 배경도 테두리도 없다.
struct EditorialLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .dnaFont(size: 13, weight: .semibold)
            .foregroundStyle(Color.dnaTextTertiary)
    }
}

// MARK: - 카피 생성
//
// 여행 원장에는 자유 텍스트가 없으므로, 문장은 축·태그·동행·기간에서 조합해 만든다.

enum HomeNarrative {
    /// 지문이 없을 때 보여주는 잠든 능선. 값이 작아 형태만 암시한다.
    static let dormantAxes = TasteAxes(
        natureUrban: 0.14,
        energyLevel: -0.1,
        planningStyle: 0.06,
        socialMode: -0.16,
        noveltyAppetite: 0.11
    )

    static let dormantConfidence = TasteAxes(
        natureUrban: 0.1,
        energyLevel: 0.1,
        planningStyle: 0.1,
        socialMode: 0.1,
        noveltyAppetite: 0.1
    )

    /// 가장 강하고 신뢰할 수 있는 축 하나로 2줄 히어로 문장을 만든다.
    static func heroSentence(axes: TasteAxes, confidence: AxisConfidence?) -> String {
        let sorted = TasteAxis.allCases.sorted { abs(axes[$0]) > abs(axes[$1]) }
        let candidate = sorted.first { abs(axes[$0]) >= 0.15 && (confidence?[$0] ?? 1) >= 0.35 }
            ?? sorted.first { abs(axes[$0]) >= 0.15 }

        guard let axis = candidate else {
            return "지문이 아직\n형태를 잡는 중입니다"
        }
        return sentence(axis: axis, isPositive: axes[axis] > 0)
    }

    private static func sentence(axis: TasteAxis, isPositive: Bool) -> String {
        switch (axis, isPositive) {
        case (.natureUrban, false): "붐비는 명소보다\n조용한 자연을 먼저 고릅니다"
        case (.natureUrban, true): "풍경보다\n거리의 밀도에 반응합니다"
        case (.energyLevel, false): "일정을 채우기보다\n하루를 비워 두는 편입니다"
        case (.energyLevel, true): "쉬러 가기보다\n움직이러 떠납니다"
        case (.planningStyle, false): "정해진 일정보다\n그날의 기분을 따라갑니다"
        case (.planningStyle, true): "우연에 맡기기보다\n미리 그려둔 길을 걷습니다"
        case (.socialMode, false): "북적임보다\n혼자 걷는 시간을 고릅니다"
        case (.socialMode, true): "조용한 하루보다\n사람들 사이의 온도를 찾습니다"
        case (.noveltyAppetite, false): "새로움보다\n다시 가도 좋은 곳을 택합니다"
        case (.noveltyAppetite, true): "익숙함보다\n처음 보는 골목에 끌립니다"
        }
    }

    /// 문장의 근거를 밝혀 추측이 아니라 기록에서 나왔음을 알린다.
    static func evidence(trips: [Trip]) -> String {
        let evaluated = trips.filter { $0.evaluation?.skipped == false }.count
        guard evaluated > 0 else {
            return "온보딩 응답에서 읽은 첫 인상이에요"
        }
        return "평가한 여행 \(evaluated)번에서 읽었어요"
    }

    /// 인사말 자리를 대체하는 위치·경과 메타. 여행 중이면 몇 일차인지 먼저 알려준다.
    static func metaLine(trips: [Trip], now: Date = Date()) -> String {
        let calendar = Calendar.current

        if let active = trips.first(where: { $0.status == .active }) {
            let start = active.startedAt ?? active.legs.first?.startDate ?? now
            let elapsed = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: start),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            return "\(placeName(active)) · \(max(1, elapsed + 1))일차"
        }

        if let recent = mostRecentFinishedTrip(trips) {
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: returnDate(recent)),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            if days <= 0 {
                return "\(placeName(recent))에서 돌아온 날"
            }
            return "\(placeName(recent))에서 돌아온 지 \(days)일"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter.string(from: now)
    }

    static func mostRecentFinishedTrip(_ trips: [Trip]) -> Trip? {
        trips
            .filter { $0.status == .ended || $0.status == .evaluated || $0.status == .skippedEvaluation }
            .max { returnDate($0) < returnDate($1) }
    }

    /// 평가 태그가 있으면 그 태그를, 없으면 동행과 기간으로 지난 여행을 한 문장으로 요약한다.
    static func tripSentence(_ trip: Trip) -> String {
        let place = placeName(trip)
        let nights = max(1, trip.legs.reduce(0) { $0 + $1.days } - 1)

        if let tagID = trip.evaluation?.positiveTagIDs.first {
            let tag = shortTagLabel(tagID)
            return "\(tag)\(subjectParticle(after: tag)) 좋았던 \(place)에서의 \(nights)박"
        }
        return "\(companionPhrase(trip.companion)) \(place)에서의 \(nights)박"
    }

    /// 받침 유무로 주격 조사를 고른다. 태그 라벨이 문장에 그대로 들어가므로 필요하다.
    private static func subjectParticle(after word: String) -> String {
        hasFinalConsonant(word) ? "이" : "가"
    }

    private static func objectParticle(after word: String) -> String {
        hasFinalConsonant(word) ? "을" : "를"
    }

    private static func hasFinalConsonant(_ word: String) -> Bool {
        guard let scalar = word.unicodeScalars.last?.value,
              (0xAC00...0xD7A3).contains(scalar) else {
            return true
        }
        return (scalar - 0xAC00) % 28 != 0
    }

    private static func companionPhrase(_ companion: Companion) -> String {
        switch companion {
        case .alone: "혼자 걸은"
        case .couple: "둘이서 다녀온"
        case .family: "가족과 보낸"
        case .friends: "친구들과 보낸"
        case .colleagues: "동료들과 보낸"
        case .unknown: "다녀온"
        }
    }

    /// 여행 기록에 물성을 주는 장소·시기 메타데이터 한 줄.
    static func photoMeta(_ trip: Trip) -> String {
        guard let leg = trip.legs.first else { return "" }
        let place = leg.cities.first
            ?? CountryCatalog.profiles[leg.countryCode]?.nameKo
            ?? leg.countryCode

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return "\(place) · \(formatter.string(from: leg.startDate))"
    }

    /// 추천 이유를 별도 설명 카드 대신 제목 아래 한 문장으로 합친다.
    static func recommendationReason(_ recommendation: Recommendation) -> String {
        if let tagID = recommendation.explanationTagIDs.first {
            let tag = shortTagLabel(tagID)
            return "\(tag)\(objectParticle(after: tag)) 좋아하는 기록이 쌓여 있어요"
        }
        return recommendation.slot.subtitleKo
    }

    /// 태그 라벨은 "문화/예술"처럼 슬래시를 포함한다. 문장에 넣을 때는 앞 조각만 쓴다.
    private static func shortTagLabel(_ tagID: String) -> String {
        let label = TagCatalog.labelKo(for: tagID)
        return label.split(separator: "/").first.map(String.init) ?? label
    }

    private static func placeName(_ trip: Trip) -> String {
        guard let leg = trip.legs.first else { return "" }
        return leg.cities.first ?? CountryCatalog.name(for: leg.countryCode)
    }

    private static func returnDate(_ trip: Trip) -> Date {
        trip.endedAt ?? trip.legs.last?.endDate ?? trip.createdAt
    }
}

// MARK: - Previews

#Preview("HomeRedesignView") {
    @Previewable @State var selection = MainTab.home
    NavigationStack {
        HomeRedesignView(selection: $selection)
    }
    .previewWithAppEnvironment { session in
        session.onboardingPhase = .completed
    }
}

#Preview("FingerprintRidge") {
    VStack(spacing: 40) {
        FingerprintRidge(axes: PreviewSample.axes, confidence: PreviewSample.confidence)
        FingerprintRidge(axes: HomeNarrative.dormantAxes, confidence: HomeNarrative.dormantConfidence)
    }
    .padding(20)
    .frame(maxHeight: .infinity)
    .background(Color.dnaCanvas)
    .preferredColorScheme(.dark)
}
