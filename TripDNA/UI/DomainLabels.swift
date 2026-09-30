import Foundation
import SwiftUI

extension TasteAxis {
    var labelKo: String {
        switch self {
        case .natureUrban: "자연 ↔ 도시"
        case .energyLevel: "휴식 ↔ 활동"
        case .planningStyle: "즉흥 ↔ 계획"
        case .socialMode: "혼자 ↔ 함께"
        case .noveltyAppetite: "익숙함 ↔ 새로움"
        }
    }

    var shortLabelKo: String {
        switch self {
        case .natureUrban: "자연/도시"
        case .energyLevel: "에너지"
        case .planningStyle: "계획성"
        case .socialMode: "사교성"
        case .noveltyAppetite: "새로움"
        }
    }

    /// 음수 쪽, 양수 쪽 극 이름.
    var polesKo: (negative: String, positive: String) {
        let parts = labelKo.components(separatedBy: " ↔ ")
        return (parts.first ?? "", parts.last ?? "")
    }
}

extension TasteAxes {
    /// 지문 시각화를 VoiceOver로 읽을 때 쓰는 축별 요약.
    func spokenSummaryKo(confidence: AxisConfidence? = nil) -> String {
        TasteAxis.allCases.map { axis in
            let value = self[axis]
            let poles = axis.polesKo
            let pole = value < 0 ? poles.negative : poles.positive
            var phrase: String
            switch abs(value) {
            case ..<0.15: phrase = "균형"
            case ..<0.5: phrase = "약간 \(pole) 쪽"
            default: phrase = "\(pole) 쪽"
            }
            if let confidence, confidence[axis] < 0.4 {
                phrase += ", 아직 흐림"
            }
            return "\(axis.labelKo): \(phrase)"
        }
        .joined(separator: ". ")
    }
}

extension RecommendationSlot {
    var labelKo: String {
        switch self {
        case .bestMatch: "베스트 매치"
        case .freshStretch: "새로운 도전"
        case .underratedFit: "숨은 인생지"
        }
    }

    var subtitleKo: String {
        switch self {
        case .bestMatch: "가장 잘 맞아요"
        case .freshStretch: "지금까지와 다르지만 넓혀볼 만해요"
        case .underratedFit: "아직 덜 떠올렸을 수 있지만, 취향엔 잘 맞아요"
        }
    }

    /// 현행 국가 추천의 슬롯 칩 색상: bestMatch=teal, freshStretch=indigo, underratedFit=amber.
    var accentColor: Color {
        switch self {
        case .bestMatch: .dnaData
        case .freshStretch: .dnaTextTertiary
        case .underratedFit: .dnaWarning
        }
    }
}

extension FeedbackReason {
    var labelKo: String {
        switch self {
        case .tooExpensive: "예산이 부담돼요"
        case .tooFar: "너무 멀어요"
        case .safety: "안전이 걱정돼요"
        case .notMyTaste: "제 취향이 아니에요"
        }
    }
}

extension TripStatus {
    var labelKo: String {
        switch self {
        case .planned: "예정"
        case .active: "여행 중"
        case .ended: "평가 대기"
        case .evaluated: "완료"
        case .skippedEvaluation: "평가 생략"
        }
    }
}

extension Companion {
    var labelKo: String {
        switch self {
        case .alone: "혼자"
        case .couple: "커플"
        case .family: "가족"
        case .friends: "친구"
        }
    }
}

extension TripPurpose {
    var labelKo: String {
        switch self {
        case .leisure: "여가"
        case .obligation: "의무(출장 등)"
        }
    }
}

extension DayReaction {
    var labelKo: String {
        switch self {
        case .good: "좋았어요"
        case .neutral: "그저 그랬어요"
        case .bad: "아쉬웠어요"
        }
    }
}

extension ComparisonResult {
    var labelKo: String {
        switch self {
        case .better: "더 좋았어요"
        case .worse: "더 아쉬웠어요"
        case .skipped: "비교 생략"
        }
    }
}

extension OnboardingStatus {
    var labelKo: String {
        switch self {
        case .pending: "대기"
        case .photoScan: "사진첩 스캔"
        case .manual: "직접 입력"
        case .quiz: "취향 퀴즈"
        case .done: "완료"
        }
    }
}
