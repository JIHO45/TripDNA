import Foundation

/// 예산·비용의 통화. 사는 나라 설정으로 한 번 정하고 요청에 코드로 저장한다.
/// 지원하지 않는 통화는 USD로 통일해 LLM 프롬프트·컷·표시가 같은 통화를 쓰게 한다.
nonisolated enum BudgetCurrency {
    static let krw = "KRW"

    /// 통화별 예산 칩. KRW는 기존 값 그대로다.
    static let presets: [String: [Int]] = [
        "KRW": [500_000, 1_000_000, 1_500_000],
        "USD": [500, 1_000, 2_000],
        "EUR": [500, 1_000, 2_000],
        "GBP": [500, 1_000, 1_500],
        "JPY": [100_000, 200_000, 300_000],
        "CNY": [3_000, 6_000, 10_000],
        "TWD": [15_000, 30_000, 50_000],
        "HKD": [4_000, 8_000, 12_000],
        "SGD": [700, 1_400, 2_000],
        "AUD": [800, 1_500, 2_500],
        "CAD": [700, 1_400, 2_000],
        "THB": [15_000, 30_000, 50_000]
    ]

    /// 사는 나라 → 통화 → (없으면) 기기 지역 통화 → USD. 목록에 없는 통화는 USD.
    static func resolve(homeCountryCode: String?) -> String {
        let code = homeCountryCode.flatMap { Locale(identifier: "und_\($0.uppercased())").currency?.identifier }
            ?? Locale.current.currency?.identifier
        return code.flatMap { presets[$0] != nil ? $0 : nil } ?? "USD"
    }

    static func presets(for currency: String) -> [Int] { presets[currency] ?? presets["USD"]! }

    /// 직접 입력 칸의 단위. KRW는 만 원 단위, 그 밖은 금액 그대로.
    static func customUnit(for currency: String) -> Int { currency == krw ? 10_000 : 1 }

    /// KRW는 기존 짧은 표기(`shortKRW`), 그 밖은 소수 없는 통화 표기.
    static func format(_ amount: Int, currency: String, koreanUnit: String) -> String {
        currency == krw
            ? shortKRW(amount, koreanUnit: koreanUnit)
            : amount.formatted(.currency(code: currency).precision(.fractionLength(0)))
    }
}
