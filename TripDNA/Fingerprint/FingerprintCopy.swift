import Foundation

/// 한국어 조사 선택. 받침 유무만 본다.
enum KoreanParticle {
    static func hasFinalConsonant(_ word: String) -> Bool {
        guard let scalar = word.unicodeScalars.last?.value, (0xAC00...0xD7A3).contains(scalar) else {
            return true
        }
        return (scalar - 0xAC00) % 28 != 0
    }

    /// "미식과", "도시와"
    static func andJoined(_ first: String, _ second: String) -> String {
        first + (hasFinalConsonant(first) ? "과 " : "와 ") + second
    }
}

/// 지문 문장. 컨셉 횟수를 세어 말할 뿐 성향을 추정하지 않는다
/// (docs/screens/home-and-fingerprint.md "취향 지문").
extension ConceptFingerprint {
    /// 셋 이상 동점이면 이름 대신 "N가지". 이름은 함께 보이는 막대 목록에 이미 나온다.
    var topCountedKo: String? { top.count >= 3 ? "\(top.count)가지" : nil }

    /// 1위 컨셉 이름. 동점이면 둘은 "X와 Y", 셋 이상은 "N가지".
    var topNamesKo: String {
        if let topCountedKo { return topCountedKo }
        let names = top.map(\.labelKo)
        if names.count == 2 { return KoreanParticle.andJoined(names[0], names[1]) }
        return names.joined(separator: "·")
    }

    var isTie: Bool { top.count > 1 }
    var isSingleTrip: Bool { total == 1 }

    /// 홈 지문 카드: "6번 중 3번이 미식 여행이었어요".
    var homeHeadlineKo: String {
        if isSingleTrip { return "첫 기록은 \(topNamesKo) 여행이에요" }
        if isTie { return "\(topNamesKo) 여행을 \(topCount)번씩 떠났어요" }
        return "\(total)번 중 \(topCount)번이 \(topNamesKo) 여행이었어요"
    }

    /// 지문 상세: "가장 많이 떠난 건 미식 여행이에요".
    var detailHeadlineKo: String {
        if isSingleTrip { return "첫 기록은 \(topNamesKo) 여행이에요" }
        if isTie { return "\(topNamesKo) 여행을 \(topCount)번씩 떠났어요" }
        return "가장 많이 떠난 건 \(topNamesKo) 여행이에요"
    }
}
