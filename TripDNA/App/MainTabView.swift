import SwiftUI

enum MainTab: Hashable {
    case home
    case recommendation
    case trips
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    // 탭바·내비게이션 바는 OS 레이어로 둔다(iOS 26 시스템 글래스). UIAppearance로 배경을 칠하면
    // 글래스가 꺼지므로 모양은 지정하지 않고 선택 탭 tint만 맞춘다. 탭은 홈·추천·여행 세 개뿐이다.
    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                HomeRedesignView(selection: $router.selectedTab)
            }
            .readableColumn()
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(MainTab.home)

            NavigationStack {
                RecommendationView()
            }
            .readableColumn()
            .tabItem { Label("Recommendations", systemImage: "sparkles") }
            .tag(MainTab.recommendation)

            NavigationStack {
                TripListView()
            }
            .readableColumn()
            .tabItem { Label("Trips", systemImage: "suitcase.fill") }
            .tag(MainTab.trips)
        }
        .tint(Color.dnaActionText)
        .fullScreenCover(item: $router.evaluationRequest) { request in
            EvaluationView(tripID: request.tripID)
        }
    }
}

private extension View {
    /// iPad에서 화면이 폭 전체로 늘어나지 않게 가운데 한 줄로 모은다. iPhone은 세로 전용이라 이보다 좁아 그대로다.
    /// 700pt는 시작값이다. 사진 비율과 읽기 폭을 보고 조정한다.
    func readableColumn() -> some View {
        frame(maxWidth: 700).frame(maxWidth: .infinity)
    }
}

#Preview("MainTabView") {
    MainTabView()
        .previewWithAppEnvironment { session in
            session.onboardingPhase = .completed
        }
}
