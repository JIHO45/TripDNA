import StoreKit
import StoreKitTest
import Testing
@testable import TripDNA

/// TripDNA.storekit로 상품 설정과 구매 후 구독 상태 판정을 확인한다.
@MainActor
@Suite(.serialized)
struct SubscriptionTests {
    static let config = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("TripDNA.storekit")

    @Test func configHasBothProducts() async throws {
        let session = try SKTestSession(contentsOf: Self.config)
        session.clearTransactions()
        let products = try await Product.products(for: Subscription.productIDs)
        #expect(Set(products.map(\.id)) == Set(Subscription.productIDs))
    }

    /// 만료는 자동 검사하지 않는다. SKTestSession.expireSubscription이 세션 거래만 바꾸고
    /// 앱의 Transaction.currentEntitlements에는 반영되지 않았다(2026-11-02, Xcode 27). Xcode 거래 관리자로 직접 확인한다.
    @Test func activeAfterPurchase() async throws {
        let session = try SKTestSession(contentsOf: Self.config)
        session.disableDialogs = true
        session.clearTransactions()
        #expect(await Subscription.isActive() == false)

        try await session.buyProduct(identifier: Subscription.monthlyID)
        #expect(await Subscription.isActive())
        session.clearTransactions()
    }
}
