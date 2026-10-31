import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dependencies = AppDependencies(analyticsSink: ServerMetricsSink.make())
    @State private var session = SessionStore()
    @State private var restoreOffer: BackupManifest?
    @State private var isRestoring = false
    @State private var restoreFailed = false

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
        .overlay {
            if isRestoring {
                ProgressView("iCloud에서 되살리는 중")
                    .padding(DNASpacing.lg)
                    .background(Color.dnaSheet, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            }
        }
        .alert("iCloud에 백업이 있어요", isPresented: Binding(
            get: { restoreOffer != nil }, set: { if !$0 { restoreOffer = nil } }
        ), presenting: restoreOffer) { _ in
            Button("되살리기") { Task { await restoreFromBackup() } }
            Button("새로 시작", role: .cancel) {}
        } message: { manifest in
            Text("\(manifest.createdAt.formatted(date: .abbreviated, time: .shortened)) 백업 · 여행 \(manifest.tripCount)개. 이 기기로 되살릴까요? 새로 시작해도 설정의 iCloud 백업에서 나중에 되살릴 수 있어요.")
        }
        .alert("되살리지 못했어요", isPresented: $restoreFailed) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("설정의 iCloud 백업에서 다시 시도할 수 있어요.")
        }
        .task {
            await dependencies.restore(session: session)
            if let backup = dependencies.backup {
                // 온보딩 전(새로 설치한 기기)에만 되살리기를 먼저 묻는다. 묻는 동안에는 올리지 않는다.
                if !session.isReadyForMainApp, let manifest = await backup.restorableBackup() {
                    restoreOffer = manifest
                } else {
                    await backup.backUpIfNeeded()
                }
            }
            await AutoPhotoFallbackService.fillMissingDays(dependencies: dependencies)
            #if DEBUG
            await UIDemoSeed.applyIfRequested(dependencies: dependencies, session: session)
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await AutoPhotoFallbackService.fillMissingDays(dependencies: dependencies) }
            } else if phase == .background {
                dependencies.backup?.backUpInBackground()
            }
        }
    }

    private func restoreFromBackup() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await dependencies.backup?.restore()
            await dependencies.restore(session: session)
        } catch {
            restoreFailed = true
        }
    }
}

#Preview("RootView") {
    RootView()
        .environment(AppRouter())
}
