import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dependencies = AppDependencies()
    @State private var session = SessionStore()

    var body: some View {
        Group {
            if session.isReadyForMainApp {
                MainTabView()
            } else if session.onboardingPhase == .completed && session.requiresSignIn {
                AppleSignInView(mode: .sessionRestore)
            } else {
                OnboardingFlowView()
            }
        }
        .environment(dependencies)
        .environment(session)
        .preferredColorScheme(.dark)
        // 전역 tint는 뉴트럴로 둔다. 틸은 지문 데이터 표시에만 쓴다.
        .tint(Color.dnaTextPrimary)
        .task {
            await dependencies.restore(session: session)
            await AutoPhotoFallbackService.fillMissingDays(dependencies: dependencies)
            #if DEBUG
            await UIDemoSeed.applyIfRequested(dependencies: dependencies, session: session)
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await AutoPhotoFallbackService.fillMissingDays(dependencies: dependencies) }
            }
        }
    }
}

#if DEBUG
/// `-uiDemo` 런치 인자로 실행할 때만 동작하는 UI 확인용 시드.
/// 온보딩·로그인을 건너뛰고 지문·여행·평가가 채워진 상태의 화면을 바로 볼 수 있게 한다.
enum UIDemoSeed {
    static func applyIfRequested(dependencies: AppDependencies, session: SessionStore) async {
        guard ProcessInfo.processInfo.arguments.contains("-uiDemo") else { return }
        guard (try? await dependencies.store.currentUTV()) == nil else { return }

        let now = Date()
        let calendar = Calendar.current

        let vector = UserTasteVector(
            userID: session.userID,
            axes: TasteAxes(
                natureUrban: -0.38,
                energyLevel: -0.21,
                planningStyle: -0.34,
                socialMode: -0.62,
                noveltyAppetite: 0.29
            ),
            confidence: TasteAxes(
                natureUrban: 0.74,
                energyLevel: 0.46,
                planningStyle: 0.58,
                socialMode: 0.83,
                noveltyAppetite: 0.31
            ),
            ledgerVersion: 3,
            recomputedAt: now
        )
        try? await dependencies.store.save(vector)

        await seedFinishedTrip(dependencies: dependencies, now: now, calendar: calendar)
        await seedUpcomingTrip(dependencies: dependencies, now: now, calendar: calendar)

        dependencies.interestTagIDs = ["food", "culture", "outdoor"]
        await dependencies.setHomeCountryCode("KR")

        session.onboardingPhase = .completed
        session.isAuthenticated = true
    }

    /// 18일 전에 돌아온 평가 완료 여행. 대표 사진은 고정 경로를 쓰므로
    /// 파일을 넣지 않으면 사진 없는 홈으로 보인다.
    private static func seedFinishedTrip(
        dependencies: AppDependencies,
        now: Date,
        calendar: Calendar
    ) async {
        guard let start = calendar.date(byAdding: .day, value: -22, to: now),
              let end = calendar.date(byAdding: .day, value: -18, to: now),
              let leg = try? TripLeg(countryCode: "JP", cities: ["교토"], startDate: start, endDate: end),
              var trip = try? Trip(legs: [leg], companion: .alone, purpose: .leisure, createdAt: start),
              let evaluation = try? TripEvaluation(
                  satisfaction: 5,
                  wouldRepeat: true,
                  positiveTagIDs: ["culture"],
                  source: .postTrip
              )
        else { return }

        try? trip.start(at: start)
        try? trip.end(at: end)
        try? trip.submit(evaluation, at: end)
        trip.setCoverPhoto(storagePath: LocalPhotoStore.pathPrefix + "demo-kyoto.jpg")
        try? await dependencies.store.create(trip)
    }

    private static func seedUpcomingTrip(
        dependencies: AppDependencies,
        now: Date,
        calendar: Calendar
    ) async {
        guard let start = calendar.date(byAdding: .day, value: 26, to: now),
              let end = calendar.date(byAdding: .day, value: 30, to: now),
              let leg = try? TripLeg(countryCode: "PT", cities: ["리스본"], startDate: start, endDate: end),
              let trip = try? Trip(legs: [leg], companion: .alone, purpose: .leisure, createdAt: now)
        else { return }

        try? await dependencies.store.create(trip)
    }
}
#endif

#Preview("RootView") {
    RootView()
}
