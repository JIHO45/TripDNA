import Foundation
import SwiftUI

/// 데이터 이름과 LLM 출력 언어를 한국어/영어 중 무엇으로 할지 정하는 유일한 기준.
nonisolated enum AppLanguage {
    static var isKorean: Bool { Bundle.main.preferredLocalizations.first?.hasPrefix("ko") == true }
}

extension TasteAxis {
    var label: String {
        switch self {
        case .natureUrban: String(localized: "Nature ↔ City")
        case .energyLevel: String(localized: "Rest ↔ Activity")
        case .planningStyle: String(localized: "Spontaneous ↔ Planned")
        case .socialMode: String(localized: "Solo ↔ Together")
        case .noveltyAppetite: String(localized: "Familiar ↔ Novel")
        }
    }

    var shortLabel: String {
        switch self {
        case .natureUrban: String(localized: "Nature/City")
        case .energyLevel: String(localized: "Energy")
        case .planningStyle: String(localized: "Planning")
        case .socialMode: String(localized: "Social")
        case .noveltyAppetite: String(localized: "Novelty")
        }
    }

    /// 음수 쪽, 양수 쪽 극 이름.
    var poles: (negative: String, positive: String) {
        let parts = label.components(separatedBy: " ↔ ")
        return (parts.first ?? "", parts.last ?? "")
    }
}

extension TasteAxes {
    /// 지문 시각화를 VoiceOver로 읽을 때 쓰는 축별 요약.
    func spokenSummary(confidence: AxisConfidence? = nil) -> String {
        TasteAxis.allCases.map { axis in
            let value = self[axis]
            let poles = axis.poles
            let pole = value < 0 ? poles.negative : poles.positive
            var phrase: String
            switch abs(value) {
            case ..<0.15: phrase = String(localized: "Balanced")
            case ..<0.5: phrase = String(localized: "Slightly toward \(pole)")
            default: phrase = String(localized: "Toward \(pole)")
            }
            if let confidence, confidence[axis] < 0.4 {
                phrase += String(localized: ", still faint")
            }
            return "\(axis.label): \(phrase)"
        }
        .joined(separator: ". ")
    }
}

extension RecommendationSlot {
    var label: String {
        switch self {
        case .bestMatch: String(localized: "Best Match")
        case .freshStretch: String(localized: "Fresh Stretch")
        case .underratedFit: String(localized: "Hidden Gem")
        }
    }

    var subtitle: String {
        switch self {
        case .bestMatch: String(localized: "Fits you best")
        case .freshStretch: String(localized: "Different from before, but worth stretching to")
        case .underratedFit: String(localized: "You may not have thought of it yet, but it suits your taste")
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
    var label: String {
        switch self {
        case .tooExpensive: String(localized: "The budget is a stretch")
        case .tooFar: String(localized: "Too far")
        case .safety: String(localized: "I'm worried about safety")
        case .notMyTaste: String(localized: "Not my taste")
        }
    }
}

extension TripStatus {
    var label: String {
        switch self {
        case .planned: String(localized: "Planned")
        case .active: String(localized: "Traveling")
        case .ended: String(localized: "Awaiting Review")
        case .evaluated: String(localized: "Completed")
        case .skippedEvaluation: String(localized: "Review Skipped")
        }
    }
}

extension Companion {
    /// 입력하지 않은 동행은 UI에 아무것도 보이지 않는다.
    var label: String {
        switch self {
        case .alone: String(localized: "Solo")
        case .couple: String(localized: "Partner")
        case .family: String(localized: "Family")
        case .friends: String(localized: "Friends")
        case .colleagues: String(localized: "Colleagues")
        case .unknown: ""
        }
    }
}

extension TripPurpose {
    var label: String {
        switch self {
        case .leisure: String(localized: "Leisure")
        case .obligation: String(localized: "Obligation (e.g. business)")
        }
    }
}

extension TripConcept {
    /// 화면에 보이는 짧은 이름(2026-10-24 디자인 결정). `data/experience-categories.json`의 `label_ko`는
    /// 자료용 이름이라 다를 수 있다. `event`만 그 파일에 없다.
    nonisolated var label: String {
        switch self {
        case .cityExploration: String(localized: "City")
        case .natureScenery: String(localized: "Nature")
        case .food: String(localized: "Food")
        case .relaxation: String(localized: "Relaxation")
        case .cultureHistory: String(localized: "Culture & History")
        case .activities: String(localized: "Activities")
        case .shopping: String(localized: "Shopping")
        case .nightlife: String(localized: "Nightlife")
        case .meetingPeople: String(localized: "Socializing")
        case .event: String(localized: "Events")
        }
    }
}

extension DayReaction {
    var label: String {
        switch self {
        case .good: String(localized: "Loved it")
        case .neutral: String(localized: "It was okay")
        case .bad: String(localized: "Could've been better")
        }
    }
}

extension ComparisonResult {
    var label: String {
        switch self {
        case .better: String(localized: "Better")
        case .worse: String(localized: "Worse")
        case .skipped: String(localized: "Skip comparison")
        }
    }
}

extension OnboardingStatus {
    var label: String {
        switch self {
        case .pending: String(localized: "Pending")
        case .photoScan: String(localized: "Photo Scan")
        case .manual: String(localized: "Manual Entry")
        case .quiz: String(localized: "Taste Quiz")
        case .done: String(localized: "Done")
        }
    }
}
