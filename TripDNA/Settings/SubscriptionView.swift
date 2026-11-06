import StoreKit
import SwiftUI

/// LLM 기능 구독(월·연). 상품 ID는 App Store Connect와 TripDNATests/TripDNA.storekit에 같은 값으로 등록한다.
/// 한도는 서버가 구매 정보를 검증해 센다(functions/index.js): 추천 월 30회(무료 3회), AI 대화 예산 US$1.50(무료 US$0.10, 15배).
enum Subscription {
    static let monthlyID = "tripdna.subscription.monthly"
    static let yearlyID = "tripdna.subscription.yearly"
    static let productIDs = [monthlyID, yearlyID]
    /// 자체 약관이 없어 Apple 표준 EULA를 쓴다.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// 환불·만료되지 않은 구독이 있으면 true. 만료·환불된 거래는 currentEntitlements에 나오지 않는다.
    static func isActive() async -> Bool {
        await current() != nil
    }

    /// 지금 유효한 구독 거래의 서명된 원문. LLM 프록시가 이것을 검증해 구독 한도로 센다(functions/index.js).
    static func transactionJWS() async -> String? {
        await current()?.jwsRepresentation
    }

    /// 지금 유효한 구독 거래.
    static func current() async -> VerificationResult<StoreKit.Transaction>? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIDs.contains(transaction.productID), transaction.revocationDate == nil {
                return result
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

/// 구독하지 않았으면 혜택을 앞세운 구매 화면, 구독 중이면 받는 혜택과 구독 관리.
struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    /// 앱 언어의 locale. SubscriptionStoreView는 안쪽 locale을 App Store 지역 것(예: en_US)으로 바꾸므로,
    /// 우리가 넣은 안내 문구에는 이 값을 다시 준다. 상품 이름·가격·구독 버튼은 App Store 지역을 따른다.
    @Environment(\.locale) private var locale
    @State private var plan: SubscribedPlan?
    @State private var loaded = false

    var body: some View {
        Group {
            if !loaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let plan {
                SubscribedView(plan: plan)
            } else {
                store
            }
        }
        .background(AppCanvas())
        .task {
            plan = await SubscribedPlan.load()
            loaded = true
        }
    }

    private var store: some View {
        SubscriptionStoreView(productIDs: Subscription.productIDs) {
            VStack(spacing: DNASpacing.section) {
                SubscriptionHero(
                    image: "WelcomeCity",
                    title: "More trips matched to your taste",
                    subtitle: Text("30 recommendations a month · 15× the AI chat usage of free")
                )
                FreeVsSubscriptionCard()
                SubscriptionBenefits()
            }
            .padding(.bottom, DNASpacing.md)
            .environment(\.locale, locale)
        }
        .subscriptionStoreControlStyle(.prominentPicker)
        .subscriptionStoreButtonLabel(.multiline)
        .tint(Color.dnaAction)
        .containerBackground(Color.dnaCanvas, for: .subscriptionStoreFullHeight)
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

/// 구독 중인 요금제. 이름은 App Store Connect의 표시 이름을 쓴다.
struct SubscribedPlan {
    let name: String
    let periodEnd: Date?
    let willRenew: Bool

    static func load() async -> SubscribedPlan? {
        guard case .verified(let transaction) = await Subscription.current() else { return nil }
        let product = try? await Product.products(for: [transaction.productID]).first
        var willRenew = true
        if case .verified(let renewal) = await transaction.subscriptionStatus?.renewalInfo {
            willRenew = renewal.willAutoRenew
        }
        return SubscribedPlan(name: product?.displayName ?? "TripDNA", periodEnd: transaction.expirationDate, willRenew: willRenew)
    }
}

private struct SubscribedView: View {
    let plan: SubscribedPlan
    @State private var managing = false

    var body: some View {
        ScrollView {
            VStack(spacing: DNASpacing.section) {
                SubscriptionHero(image: "WelcomeBeach", title: "You're subscribed", subtitle: Text(plan.name))
                FreeVsSubscriptionCard()

                if let end = plan.periodEnd {
                    Label {
                        if plan.willRenew {
                            Text("Renews on \(end, format: .dateTime.year().month().day())")
                        } else {
                            Text("Ends on \(end, format: .dateTime.year().month().day()). Benefits stay until then.")
                        }
                    } icon: {
                        Image(systemName: plan.willRenew ? "arrow.clockwise" : "calendar")
                    }
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DNASpacing.gutter)
                }

                SubscriptionBenefits()

                VStack(spacing: DNASpacing.xs) {
                    Button("Manage Subscription") { managing = true }
                        .buttonStyle(.dnaSecondary)
                    Text("Change plans or cancel in your App Store subscriptions.")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, DNASpacing.gutter)
            }
            .padding(.bottom, DNASpacing.xl)
        }
        .dnaBackground()
        .manageSubscriptionsSheet(isPresented: $managing)
    }
}

/// 위쪽 사진. 글자는 사진 아래쪽 어두운 그라데이션 위에 놓는다.
private struct SubscriptionHero: View {
    let image: String
    let title: LocalizedStringKey
    let subtitle: Text

    var body: some View {
        Color.dnaSurface2
            .frame(height: 220)
            .overlay { Image(image).resizable().scaledToFill() }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    Text("TripDNA Subscription")
                        .dnaFont(.caption)
                        .padding(.horizontal, DNASpacing.sm)
                        .padding(.vertical, DNASpacing.xxs + 2)
                        .background(Color.dnaAction, in: Capsule())
                    Text(title).dnaFont(size: 28, weight: .heavy)
                    subtitle.dnaFont(.body).opacity(0.9)
                }
                .foregroundStyle(.white)
                .padding(DNASpacing.gutter)
            }
            .clipped()
            .accessibilityElement(children: .combine)
    }
}

/// 무료와 구독의 차이를 한눈에.
private struct FreeVsSubscriptionCard: View {
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: DNASpacing.md, verticalSpacing: DNASpacing.sm) {
            GridRow {
                Color.clear.frame(height: 1)
                Text("Free").foregroundStyle(Color.dnaTextSecondary)
                Text("Subscription").foregroundStyle(Color.dnaActionText)
            }
            .dnaFont(.caption)
            Divider().gridCellUnsizedAxes(.horizontal)
            GridRow {
                Text("City picks").dnaFont(.cardTitle).fixedSize(horizontal: false, vertical: true)
                Text("3 a month").dnaFont(.body).foregroundStyle(Color.dnaTextSecondary)
                Text("30 a month").dnaFont(.cardTitle)
            }
            GridRow {
                Text("AI chat usage").dnaFont(.cardTitle).fixedSize(horizontal: false, vertical: true)
                Text("Basic").dnaFont(.body).foregroundStyle(Color.dnaTextSecondary)
                Text("15× free").dnaFont(.cardTitle)
            }
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        .padding(.horizontal, DNASpacing.gutter)
    }
}

/// 비교표에 없는 것만 한 줄씩.
private struct SubscriptionBenefits: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            row("sparkles", "Change your conditions and compare cities")
            row("arrow.clockwise", "Refills monthly from your billing date, yearly plan too")
            row("heart", "Trip records, fingerprint, and Wrapped stay free")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DNASpacing.gutter)
    }

    private func row(_ icon: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text).dnaFont(.body).foregroundStyle(Color.dnaTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(Color.dnaActionText)
        }
    }
}
