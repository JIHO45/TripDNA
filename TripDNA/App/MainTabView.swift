import SwiftUI

enum MainTab: Hashable {
    case home
    case recommendation
    case trips
}

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    // 탭바·내비게이션 바는 OS 레이어로 둔다. UIAppearance로 배경을 칠하면
    // iOS 26 이후의 시스템 글래스가 꺼지므로 모양은 지정하지 않고 tint만 뉴트럴로 맞춘다.
    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                HomeRedesignView(selection: $router.selectedTab)
            }
            .tabItem { Label("홈", systemImage: "house.fill") }
            .tag(MainTab.home)

            NavigationStack {
                RecommendationView()
            }
            .tabItem { Label("추천", systemImage: "sparkles") }
            .tag(MainTab.recommendation)

            NavigationStack {
                TripListView()
            }
            .tabItem { Label("여행", systemImage: "suitcase.fill") }
            .tag(MainTab.trips)
        }
        .tint(Color.dnaTextPrimary)
        .fullScreenCover(item: $router.evaluationRequest) { request in
            EvaluationView(tripID: request.tripID)
        }
    }
}

#Preview("MainTabView") {
    MainTabView()
        .previewWithAppEnvironment { session in
            session.onboardingPhase = .completed
            session.isAuthenticated = true
        }
}
