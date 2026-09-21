import SwiftUI

enum MainTab: Hashable {
    case home
    case recommendation
    case trips
}

struct MainTabView: View {
    @State private var selection: MainTab = .home

    init() {
        // 탭바는 앱 브랜드가 아니라 OS 레이어로 둔다. 배경은 시스템 글래스, 선택색은 뉴트럴.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.dnaTextTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.dnaTextTertiary)]
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.dnaTextPrimary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.dnaTextPrimary)]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.dnaBackground)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color.dnaTextPrimary)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeRedesignView(selection: $selection)
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
    }
}

#Preview("MainTabView") {
    MainTabView()
        .previewWithAppEnvironment { session in
            session.onboardingPhase = .completed
            session.isAuthenticated = true
        }
}
