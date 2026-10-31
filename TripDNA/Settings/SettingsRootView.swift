import Photos
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                        Text("지금은 이 기기에만 저장돼요")
                            .dnaFont(.cardTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Text("앱을 지우거나 기기를 바꾸면 기록을 되찾을 수 없어요.")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    .padding(.vertical, DNASpacing.xxs)
                }
                .listRowBackground(Color.dnaSurface1)

                Section("구독") {
                    LabeledContent("TripDNA 구독") {
                        Text("준비 중").foregroundStyle(Color.dnaTextSecondary)
                    }
                    .foregroundStyle(Color.dnaTextPrimary)
                }
                .listRowBackground(Color.dnaSurface1)

                Section("취향과 추천") {
                    link("원하는 여행", detail: wantedSummary) { WantedTripsSettingsView() }
                    link("기억하는 취향", detail: memoryCount) { MemorySettingsView() }
                    link("추천에서 제외한 곳", detail: excludedCount) { ExclusionsSettingsView() }
                    link("저장한 도시", detail: savedCount) { SavedRecommendationsView(viewModel: RecommendationViewModel()) }
                    link("출발 공항 기본값", detail: airportSummary) { DepartureAirportSettingsView() }
                    link(
                        "사는 나라",
                        detail: dependencies.homeCountryCode.map { CountryCatalog.name(for: $0) } ?? "정하지 않음"
                    ) { HomeCountrySettingsView() }
                }
                .listRowBackground(Color.dnaSurface1)

                Section("데이터와 권한") {
                    link("권한과 보내는 정보") { PermissionsSettingsView() }
                    NavigationLink {
                        DataDeletionSettingsView(onFinished: { dismiss() })
                    } label: {
                        Text("데이터 삭제").foregroundStyle(Color.dnaError)
                    }
                }
                .listRowBackground(Color.dnaSurface1)

                #if DEBUG
                Section("개발용") {
                    link("LLM API 키") { DevKeyForm() }
                }
                .listRowBackground(Color.dnaSurface1)
                #endif

                Section {
                    // Notion에 게시한 방침(2026-10-31). 원본은 Notion 페이지, 사본은 docs/privacy-policy.md.
                    Link(destination: Self.privacyPolicyURL) {
                        LabeledContent("개인정보 처리방침") {
                            Image(systemName: "arrow.up.right").foregroundStyle(Color.dnaTextSecondary)
                        }
                        .foregroundStyle(Color.dnaTextPrimary)
                    }
                    // 약관 주소가 정해지기 전까지 이동하지 않는 자리표시자다.
                    Text("이용약관").foregroundStyle(Color.dnaTextPrimary)
                    LabeledContent("버전", value: Self.versionText)
                        .foregroundStyle(Color.dnaTextPrimary)
                } footer: {
                    Text("이용약관은 준비 중이에요.")
                }
                .listRowBackground(Color.dnaSurface1)
            }
            .settingsListStyle()
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task {
                await loadAirportSummary()
                await loadSummaries()
            }
        }
    }

    static let privacyPolicyURL = URL(string: "https://woolly-devourer-5d2.notion.site/TripDNA-Privacy-Policy-4093ed084bab809a99c9ffcf15daf337")!

    private func link<Destination: View>(
        _ title: String,
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
            wantedSummary = tiers.tier1.isEmpty ? nil : "가장 원해요 \(tiers.tier1.count)개"
            memoryCount = (tiers.avoidNote ?? "").isEmpty ? nil : "1개"
        }
        let cityState = (try? await dependencies.store.cityState()) ?? CityRecommendationState()
        let excluded = ((try? await dependencies.recommendationService.activeDislikes())?.count ?? 0) + cityState.excluded.count
        excludedCount = excluded > 0 ? "\(excluded)곳" : nil
        savedCount = cityState.saved.isEmpty ? nil : "\(cityState.saved.count)곳"
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
    var undo: (@Sendable () async -> Void)?

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
                            Button(current.undoTitle ?? "되돌리기") {
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
