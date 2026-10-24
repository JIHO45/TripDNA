import Foundation

/// 사용자가 여행 랭킹의 순서를 직접 바꿔 저장한 적이 있는지. 저장하지 않은 기본 순서는 "올해의 1위"로 말하지 않는다
/// (Wrapped ②). 랭킹 저장에 성공할 때만 켜고, 데이터 삭제 때 지운다.
enum RankingReorderFlag {
    static let key = "tripdna.rankingReordered"

    static func isSet(_ defaults: UserDefaults = .standard) -> Bool { defaults.bool(forKey: key) }
    static func mark(_ defaults: UserDefaults = .standard) { defaults.set(true, forKey: key) }
    static func clear(_ defaults: UserDefaults = .standard) { defaults.removeObject(forKey: key) }
}
