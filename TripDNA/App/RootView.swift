import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var dependencies = AppDependencies(analyticsSink: ServerMetricsSink.make())
    @State private var session = SessionStore()
    @State private var restoreOffer: BackupManifest?
    @State private var isRestoring = false
    @State private var restoreFailed = false
    @State private var showsStorageWarning = false

    var body: some View {
        Group {
            if session.isReadyForMainApp {
                // 복원 뒤 각 탭이 처음부터 다시 불러오도록 새로 만든다.
                MainTabView().id(dependencies.restoredBackupCount)
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
                ProgressView("Restoring from iCloud")
                    .padding(DNASpacing.lg)
                    .background(Color.dnaSheet, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            }
        }
        .alert("There's a backup in iCloud", isPresented: Binding(
            get: { restoreOffer != nil }, set: { if !$0 { restoreOffer = nil } }
        ), presenting: restoreOffer) { _ in
            Button("Restore") { Task { await restoreFromBackup() } }
            Button("Start Fresh", role: .cancel) {}
        } message: { manifest in
            Text("Backup from \(manifest.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(manifest.tripCount) trips. Restore it on this device? Even if you start fresh, you can restore it later from iCloud backup in Settings.")
        }
        .alert("Couldn't open your saved data", isPresented: $showsStorageWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your existing records haven't been deleted, but anything you add now won't be saved. Fully close TripDNA and open it again. If this keeps happening, free up storage on your iPhone or update the app.")
        }
        .alert("Couldn't restore", isPresented: $restoreFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can try again from iCloud backup in Settings.")
        }
        .task {
            showsStorageWarning = dependencies.storageUnavailable
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
            try await dependencies.restoreFromBackup(session: session)
        } catch {
            restoreFailed = true
        }
    }
}

#Preview("RootView") {
    RootView()
        .environment(AppRouter())
}
