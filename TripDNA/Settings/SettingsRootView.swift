import Photos
import StoreKit
import SwiftUI

/// 홈의 프로필 버튼으로 여는 설정. 구독 / 취향과 추천 / 데이터와 권한 순으로 묶는다.
struct SettingsRootView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var airportSummary: String?
    @State private var wantedSummary: String?
    @State private var memoryCount: String?
    @State private var excludedCount: String?
    @State private var savedCount: String?
    @State private var isSubscribed: Bool?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let backup = dependencies.backup {
                        NavigationLink { BackupSettingsView(backup: backup) } label: {
                            BackupStatusLabel(backup: backup)
                        }
                    } else {
                        BackupStatusLabel(backup: nil)
                    }
                }
                .listRowBackground(Color.dnaSurface1)

                Section("Subscription") {
                    link(
                        "TripDNA Subscription",
                        detail: isSubscribed.map { $0 ? String(localized: "Active") : String(localized: "Not subscribed") }
                    ) {
                        // push 화면은 내비게이션 뒤로 버튼이 있으므로 스토어 뷰의 X를 숨긴다.
                        SubscriptionView().storeButton(.hidden, for: .cancellation)
                    }
                }
                .listRowBackground(Color.dnaSurface1)

                Section("Tastes & Recommendations") {
                    link("Wanted Trips", detail: wantedSummary) { WantedTripsSettingsView() }
                    link("Remembered Tastes", detail: memoryCount) { MemorySettingsView() }
                    link("Excluded from Recommendations", detail: excludedCount) { ExclusionsSettingsView() }
                    link("Saved Cities", detail: savedCount) { SavedRecommendationsView(viewModel: RecommendationViewModel()) }
                    link("Default Departure Airport", detail: airportSummary) { DepartureAirportSettingsView() }
                    link(
                        "Home Country",
                        detail: dependencies.homeCountryCode.map { CountryCatalog.name(for: $0) } ?? String(localized: "Not set")
                    ) { HomeCountrySettingsView() }
                }
                .listRowBackground(Color.dnaSurface1)

                Section("Data & Permissions") {
                    link("Permissions and shared info") { PermissionsSettingsView() }
                    NavigationLink {
                        DataDeletionSettingsView(onFinished: { dismiss() })
                    } label: {
                        Text("Delete data").foregroundStyle(Color.dnaError)
                    }
                }
                .listRowBackground(Color.dnaSurface1)

                #if DEBUG
                Section("Development") {
                    link("LLM API Key") { DevKeyForm() }
                }
                .listRowBackground(Color.dnaSurface1)
                #endif

                Section {
                    // Notion에 게시한 방침(2026-10-31). 원본은 Notion 페이지, 사본은 docs/privacy-policy.md.
                    Link(destination: Self.privacyPolicyURL) {
                        LabeledContent("Privacy Policy") {
                            Image(systemName: "arrow.up.right").foregroundStyle(Color.dnaTextSecondary)
                        }
                        .foregroundStyle(Color.dnaTextPrimary)
                    }
                    // 약관 주소가 정해지기 전까지 이동하지 않는 자리표시자다.
                    Text("Terms of Use").foregroundStyle(Color.dnaTextPrimary)
                    LabeledContent("Version", value: Self.versionText)
                        .foregroundStyle(Color.dnaTextPrimary)
                } footer: {
                    Text("Terms of Use are coming soon.")
                }
                .listRowBackground(Color.dnaSurface1)
            }
            .settingsListStyle()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadAirportSummary()
                await loadSummaries()
            }
            // 구독 화면에서 돌아올 때마다 다시 읽는다.
            .onAppear { Task { isSubscribed = await Subscription.isActive() } }
        }
    }

    static let privacyPolicyURL = URL(string: "https://woolly-devourer-5d2.notion.site/TripDNA-Privacy-Policy-4093ed084bab809a99c9ffcf15daf337")!

    private func link<Destination: View>(
        _ title: LocalizedStringKey,
        detail: String? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            LabeledContent(title) {
                if let detail { Text(detail).foregroundStyle(Color.dnaTextSecondary) }
            }
            .foregroundStyle(Color.dnaTextPrimary)
        }
    }

    private func loadSummaries() async {
        let tiers = try? await dependencies.store.loadWantedTiers()
        if let tiers {
            wantedSummary = tiers.tier1.isEmpty ? nil : String(localized: "\(tiers.tier1.count) most wanted")
            memoryCount = (tiers.avoidNote ?? "").isEmpty ? nil : String(localized: "1 item")
        }
        let cityState = (try? await dependencies.store.cityState()) ?? CityRecommendationState()
        let excluded = ((try? await dependencies.recommendationService.activeDislikes())?.count ?? 0) + cityState.excluded.count
        excludedCount = excluded > 0 ? String(localized: "\(excluded) places") : nil
        savedCount = cityState.saved.isEmpty ? nil : String(localized: "\(cityState.saved.count) places")
    }

    private func loadAirportSummary() async {
        let profile = try? await dependencies.store.loadProfile()
        airportSummary = profile?.departureAirportCode.map { AirportCatalog.label(for: $0) }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }
}

extension View {
    /// 설정 하위 화면 공통 모양. 시스템 외형을 따르는 토큰만 쓴다.
    func settingsListStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.dnaCanvas.ignoresSafeArea())
            .tint(Color.dnaData)
    }
}

/// 설정 하위 화면 아래쪽에 잠깐 뜨는 알림. `undo`가 있으면 되돌리기 버튼을 함께 보여준다.
struct SettingsToast: Equatable {
    let id = UUID()
    let message: String
    var undoTitle: String?
    var undo: (@MainActor () async -> Void)?

    static func == (lhs: SettingsToast, rhs: SettingsToast) -> Bool { lhs.id == rhs.id }
}

private struct SettingsToastModifier: ViewModifier {
    @Binding var toast: SettingsToast?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let current = toast {
                    HStack(spacing: DNASpacing.sm) {
                        Text(current.message)
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaSelectedForeground)
                        if let undo = current.undo {
                            Button(current.undoTitle ?? String(localized: "Undo")) {
                                toast = nil
                                Task { await undo() }
                            }
                            .dnaFont(.button)
                            .foregroundStyle(Color.dnaActionText)
                        }
                    }
                    .padding(.horizontal, DNASpacing.md)
                    .frame(minHeight: 48)
                    .background(Color.dnaSelectedBackground, in: Capsule())
                    .padding(.bottom, DNASpacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: current.id) {
                        try? await Task.sleep(for: .seconds(4))
                        if toast?.id == current.id { toast = nil }
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: toast)
    }
}

extension View {
    func settingsToast(_ toast: Binding<SettingsToast?>) -> some View {
        modifier(SettingsToastModifier(toast: toast))
    }
}

#Preview("SettingsRootView") {
    SettingsRootView()
        .previewWithAppEnvironment()
}
