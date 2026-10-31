import Photos
import SwiftUI
import UserNotifications

// MARK: - 권한과 보내는 정보

struct PermissionsSettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var fallbackOn = AppStorageLocation.defaults.bool(forKey: AutoPhotoFallbackService.consentKey)
    @State private var notificationsOn = EvaluationNotificationService.isEnabled
    @State private var message: String?
    @State private var memoriesOn = CityMemoryConsent.state == .granted

    private var photosGranted: Bool { [.authorized, .limited].contains(photoStatus) }
    private var notificationsGranted: Bool {
        [.authorized, .provisional, .ephemeral].contains(notificationStatus)
    }

    var body: some View {
        List {
            Section("Photos") {
                LabeledContent("Photo access", value: photoText)
                    .foregroundStyle(Color.dnaTextPrimary)
                Button("Open iOS Settings") { openSystemSettings() }
                Toggle("Pre-select photos for missed days", isOn: Binding(
                    get: { fallbackOn },
                    set: { setFallback($0) }
                ))
            }
            .listRowBackground(Color.dnaSurface1)

            Section {
                LabeledContent("Notification permission", value: notificationText)
                    .foregroundStyle(Color.dnaTextPrimary)
                Toggle("Trip notifications", isOn: Binding(
                    get: { notificationsOn && notificationsGranted },
                    set: { setNotifications($0) }
                ))
            } header: {
                Text("Notifications")
            } footer: {
                if let message { Text(message).foregroundStyle(Color.dnaError) }
            }
            .listRowBackground(Color.dnaSurface1)

            Section {
                info("What's sent with a recommendation request", CityMemoryConsent.alwaysSent)
                info("What's never sent", CityMemoryConsent.neverSent)
                info("Who receives it", CityMemoryConsent.recipients)
                Toggle("Send past trip ratings and notes", isOn: Binding(
                    get: { memoriesOn },
                    set: { memoriesOn = $0; CityMemoryConsent.state = $0 ? .granted : .declined }
                ))
            } header: {
                Text("Info sent to AI")
            } footer: {
                Text("When on, recommendation requests also send your recent trip ratings, the full text of your notes, and the cities you've visited to an external AI model. When off, nothing is sent from the next recommendation on. Anything already sent can't be recalled from this app. Recommendation history kept on your device can be deleted under Delete data.")
            }
            .listRowBackground(Color.dnaSurface1)
        }
        .settingsListStyle()
        .navigationTitle("Permissions and shared info")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: scenePhase) { await refresh() }
    }

    private func info(_ title: LocalizedStringKey, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
            Text(title).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
            Text(body).dnaFont(.body).foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private var photoText: String {
        switch photoStatus {
        case .authorized: String(localized: "Allowed")
        case .limited: String(localized: "Selected photos only")
        case .denied, .restricted: String(localized: "Not allowed")
        default: String(localized: "Not asked yet")
        }
    }

    private var notificationText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: String(localized: "Allowed")
        case .denied: String(localized: "Not allowed")
        default: String(localized: "Not asked yet")
        }
    }

    private func refresh() async {
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsOn = EvaluationNotificationService.isEnabled
        fallbackOn = AppStorageLocation.defaults.bool(forKey: AutoPhotoFallbackService.consentKey)
        memoriesOn = CityMemoryConsent.state == .granted
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func setFallback(_ on: Bool) {
        guard on else {
            AppStorageLocation.defaults.set(false, forKey: AutoPhotoFallbackService.consentKey)
            fallbackOn = false
            return
        }
        Task {
            if !photosGranted {
                photoStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            }
            let granted = photosGranted
            AppStorageLocation.defaults.set(granted, forKey: AutoPhotoFallbackService.consentKey)
            fallbackOn = granted
            message = granted ? nil : String(localized: "Allow photo access to turn this on. You can change it in iOS Settings.")
        }
    }

    private func setNotifications(_ on: Bool) {
        guard on else {
            EvaluationNotificationService.disable()
            notificationsOn = false
            return
        }
        Task {
            let granted = (try? await EvaluationNotificationService.enable(for: await dependencies.allTrips())) ?? false
            await refresh()
            message = granted ? nil : String(localized: "Allow notifications to turn this on. You can change it in iOS Settings.")
        }
    }
}

// MARK: - 데이터 삭제

/// 지울 대상별 개수. 삭제 확인과, 실패했을 때 무엇이 남았는지 보여주는 데 쓴다.
struct StoredDataCounts: Equatable {
    var trips = 0
    var evaluations = 0
    var photos = 0
    var feedback = 0
    var hasPreferences = false
    var iCloudBackupRemains = false

    var isEmpty: Bool { trips == 0 && photos == 0 && feedback == 0 && !hasPreferences }

    init() {}

    init(store: any AppStore) async {
        let trips = (try? await store.trips()) ?? []
        self.trips = trips.count
        evaluations = trips.filter { $0.evaluation != nil }.count
        photos = ((try? await store.photos(tripID: nil)) ?? []).count
        feedback = ((try? await store.feedback()) ?? []).count
        let tiers = try? await store.loadWantedTiers()
        hasPreferences = !(tiers?.isEmpty ?? true)
    }

    var lines: [String] {
        var result = [String(localized: "\(trips) trips"), String(localized: "\(evaluations) ratings"), String(localized: "\(photos) photos"), String(localized: "\(feedback) saved, excluded, and reaction records")]
        if hasPreferences { result.append(String(localized: "Wanted trips and remembered tastes")) }
        if iCloudBackupRemains { result.append(String(localized: "Backup in iCloud")) }
        return result
    }
}

struct DataDeletionSettingsView: View {
    var onFinished: () -> Void
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @State private var counts = StoredDataCounts()
    @State private var showingConfirm = false
    @State private var isDeleting = false
    @State private var failure: StoredDataCounts?

    var body: some View {
        List {
            Section("Delete One at a Time") {
                NavigationLink("One Memory") { MemorySettingsView() }
                    .foregroundStyle(Color.dnaTextPrimary)
                hint("A single trip or rating", "Open the trip in the Trips tab to delete it.")
            }
            .listRowBackground(Color.dnaSurface1)

            Section {
                Button("Delete all data", role: .destructive) { showingConfirm = true }
                    .disabled(isDeleting)
            } footer: {
                Text("All records on this device and the backup in iCloud will be deleted. Once deleted, they can't be recovered anywhere.")
            }
            .listRowBackground(Color.dnaSurface1)

            if let failure {
                Section("Data Not Deleted") {
                    Text(failure.iCloudBackupRemains
                         ? String(localized: "Couldn't delete the iCloud backup, so your device's records were left as they are. Check your internet connection and iCloud sign-in, then try again.")
                         : String(localized: "Couldn't finish deleting. The data below is still there."))
                        .foregroundStyle(Color.dnaError)
                    ForEach(failure.lines, id: \.self) { Text($0).foregroundStyle(Color.dnaTextPrimary) }
                }
                .listRowBackground(Color.dnaSurface1)
            }
        }
        .settingsListStyle()
        .navigationTitle("Delete data")
        .navigationBarTitleDisplayMode(.inline)
        .task { counts = await StoredDataCounts(store: dependencies.store) }
        .sheet(isPresented: $showingConfirm) { confirmSheet }
    }

    private func hint(_ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
            Text(title).foregroundStyle(Color.dnaTextPrimary)
            Text(body).dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private var confirmSheet: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Text("Delete all data?")
                .dnaFont(.heroTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("This can't be undone.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                ForEach(counts.lines, id: \.self) {
                    Text($0).dnaFont(.body).foregroundStyle(Color.dnaTextPrimary)
                }
            }
            Spacer(minLength: 0)
            Button(isDeleting ? String(localized: "Deleting…") : String(localized: "Delete Everything")) { Task { await deleteAll() } }
                .buttonStyle(.dnaPrimary(isDisabled: isDeleting))
                .disabled(isDeleting)
            Button("Cancel") { showingConfirm = false }
                .buttonStyle(.dnaGhost)
                .disabled(isDeleting)
        }
        .padding(DNASpacing.gutter)
        .background(Color.dnaSheet.ignoresSafeArea())
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isDeleting)
    }

    private func deleteAll() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await dependencies.deleteAccount(session: session)
            showingConfirm = false
            onFinished()
        } catch {
            failure = await StoredDataCounts(store: dependencies.store)
            // iCloud 사본을 못 지우면 기기 기록도 지우지 않고 멈춘다(AppDependencies.deleteAccount).
            failure?.iCloudBackupRemains = (error as? BackupError) == .remoteDeleteFailed
            counts = failure ?? counts
            showingConfirm = false
        }
    }
}
