import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dependencies = AppDependencies()
    @State private var session = SessionStore()

    var body: some View {
        Group {
            if session.isReadyForMainApp {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .environment(dependencies)
        .environment(session)
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

#Preview("RootView") {
    RootView()
        .environment(AppRouter())
}
