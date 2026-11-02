import StoreKit
import SwiftUI

/// LLM 기능 구독(월·연). 상품 ID는 App Store Connect와 TripDNATests/TripDNA.storekit에 같은 값으로 등록한다.
/// 한도 해제는 서버가 구매 정보를 검증해야 적용된다(미구현). 지금은 구매·복원·상태 표시까지다.
enum Subscription {
    static let monthlyID = "tripdna.subscription.monthly"
    static let yearlyID = "tripdna.subscription.yearly"
    static let productIDs = [monthlyID, yearlyID]
    /// 자체 약관이 없어 Apple 표준 EULA를 쓴다.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// 환불·만료되지 않은 구독이 있으면 true. 만료·환불된 거래는 currentEntitlements에 나오지 않는다.
    static func isActive() async -> Bool {
        await transactionJWS() != nil
    }

    /// 지금 유효한 구독 거래의 서명된 원문. LLM 프록시가 이것을 검증해 구독 한도로 센다(functions/index.js).
    static func transactionJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIDs.contains(transaction.productID), transaction.revocationDate == nil {
                return result.jwsRepresentation
            }
        }
        return nil
    }

    /// 앱 밖에서 끝난 거래(갱신, 승인 대기 후 구매, 다른 기기 구매)를 마무리한다. 앱 시작 때 한 번 건다.
    static func finishUpdates() async {
        for await case .verified(let transaction) in Transaction.updates {
            await transaction.finish()
        }
    }
}

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SubscriptionStoreView(productIDs: Subscription.productIDs) {
            VStack(spacing: 8) {
                Text("TripDNA Subscription").dnaFont(.screenTitle)
                Text("30 recommendations and 30 questions a month")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .multilineTextAlignment(.center)
            .padding()
        }
        .storeButton(.visible, for: .restorePurchases)
        .subscriptionStorePolicyDestination(url: SettingsRootView.privacyPolicyURL, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: Subscription.termsURL, for: .termsOfService)
        .onInAppPurchaseCompletion { _, result in
            // 이 처리기를 달면 기본 처리(거래 마무리)가 빠지므로 직접 마무리한다.
            if case .success(.success(.verified(let transaction))) = result {
                await transaction.finish()
                dismiss()
            }
        }
    }
}
