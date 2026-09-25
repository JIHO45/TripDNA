import Foundation

/// 축 값·신뢰도·변화를 한국어 문구로 바꿔주는 헬퍼.
/// 홈 미니 지문 카드, 지문 상세 히어로·축 바텀시트, 랭킹 저장 델타 문구에서 함께 쓴다.
enum AxisNarrative {
    /// 음(-1) 방향 극 라벨. 예: 자연 ↔ 도시에서 "자연".
    static func negativePoleKo(_ axis: TasteAxis) -> String {
        switch axis {
        case .natureUrban: "자연"
        case .energyLevel: "휴식"
        case .planningStyle: "즉흥"
        case .socialMode: "혼자·소수"
        case .noveltyAppetite: "익숙함"
        }
    }

    /// 양(+1) 방향 극 라벨. 예: 자연 ↔ 도시에서 "도시".
    static func positivePoleKo(_ axis: TasteAxis) -> String {
        switch axis {
        case .natureUrban: "도시"
        case .energyLevel: "활동"
        case .planningStyle: "계획"
        case .socialMode: "함께·북적임"
        case .noveltyAppetite: "새로움"
        }
    }

    /// 양극이 각각 무엇을 뜻하는지 설명. 축 바텀시트에서 사용한다.
    static func poleMeaningKo(_ axis: TasteAxis) -> String {
        switch axis {
        case .natureUrban:
            "자연 쪽일수록 산·바다·고요한 풍경에서 힘을 얻고, 도시 쪽일수록 거리·건축·도시의 리듬을 즐겨요."
        case .energyLevel:
            "휴식 쪽일수록 느긋하게 쉬어가는 여행을, 활동 쪽일수록 몸을 움직이는 액티비티 중심 여행을 좋아해요."
        case .planningStyle:
            "즉흥 쪽일수록 그날의 기분을 따라가고, 계획 쪽일수록 미리 짜인 일정에서 안정감을 느껴요."
        case .socialMode:
            "혼자·소수 쪽일수록 조용한 나만의 시간을, 함께 쪽일수록 사람들과 어울리는 경험을 즐겨요."
        case .noveltyAppetite:
            "익숙함 쪽일수록 검증된 장소를 다시 찾고, 새로움 쪽일수록 처음 가보는 곳에 끌려요."
        }
    }

    /// 값의 방향을 표현하는 짧은 구절. 예: "고요한 자연".
    static func leaningPhraseKo(axis: TasteAxis, value: Double) -> String {
        switch (axis, value < 0) {
        case (.natureUrban, true): "고요한 자연"
        case (.natureUrban, false): "생동감 있는 도시"
        case (.energyLevel, true): "느긋한 휴식"
        case (.energyLevel, false): "활기찬 활동"
        case (.planningStyle, true): "즉흥적인 여정"
        case (.planningStyle, false): "촘촘한 계획"
        case (.socialMode, true): "혼자만의 시간"
        case (.socialMode, false): "함께하는 여행"
        case (.noveltyAppetite, true): "익숙한 편안함"
        case (.noveltyAppetite, false): "새로운 경험"
        }
    }

    /// 가장 강한 축 기반의 대표 문장 1줄. 신뢰도가 충분한 축을 우선한다.
    static func representativeSentenceKo(axes: TasteAxes, confidence: AxisConfidence?) -> String {
        let sorted = TasteAxis.allCases.sorted { abs(axes[$0]) > abs(axes[$1]) }
        let candidate = sorted.first { abs(axes[$0]) >= 0.15 && (confidence?[$0] ?? 1) >= 0.4 }
            ?? sorted.first { abs(axes[$0]) >= 0.15 }
        guard let axis = candidate else {
            return "아직 취향이 만들어지는 중이에요"
        }
        return "\(leaningPhraseKo(axis: axis, value: axes[axis])) 쪽에 가까운 여행자예요"
    }

    /// 랭킹 저장 후 가장 크게 움직인 축을 알려주는 델타 문구.
    /// 변화가 미미하면 과장하지 않는다(UI-3F).
    static func deltaMessageKo(from old: TasteAxes, to new: TasteAxes) -> String {
        let top = TasteAxis.allCases
            .map { (axis: $0, delta: abs(new[$0] - old[$0])) }
            .max { $0.delta < $1.delta }
        guard let top, top.delta >= 0.02 else {
            return "지문은 거의 그대로예요"
        }
        let amount = top.delta >= 0.15 ? "제법" : "조금"
        return "'\(top.axis.labelKo)' 축이 \(amount) 움직였어요"
    }
}
