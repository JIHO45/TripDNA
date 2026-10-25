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
    @State private var fallbackOn = UserDefaults.standard.bool(forKey: AutoPhotoFallbackService.consentKey)
    @State private var notificationsOn = EvaluationNotificationService.isEnabled
    @State private var message: String?
    @State private var memoriesOn = CityMemoryConsent.state == .granted

    private var photosGranted: Bool { [.authorized, .limited].contains(photoStatus) }
    private var notificationsGranted: Bool {
        [.authorized, .provisional, .ephemeral].contains(notificationStatus)
    }

    var body: some View {
        List {
            Section("사진") {
                LabeledContent("사진 접근", value: photoText)
                    .foregroundStyle(Color.dnaTextPrimary)
                Button("iOS 설정 열기") { openSystemSettings() }
                Toggle("놓친 날 사진 골라두기", isOn: Binding(
                    get: { fallbackOn },
                    set: { setFallback($0) }
                ))
            }
            .listRowBackground(Color.dnaSurface1)

            Section {
                LabeledContent("알림 권한", value: notificationText)
                    .foregroundStyle(Color.dnaTextPrimary)
                Toggle("여행 알림", isOn: Binding(
                    get: { notificationsOn && notificationsGranted },
                    set: { setNotifications($0) }
                ))
            } header: {
                Text("알림")
            } footer: {
                if let message { Text(message).foregroundStyle(Color.dnaError) }
            }
            .listRowBackground(Color.dnaSurface1)

            Section {
                info("추천을 받을 때 보내는 것", "고른 컨셉과 조건, 적은 문장")
                info("보내지 않는 것", "원본 사진, 위치 기록, 이름이나 연락처")
                Toggle("지난 여행 평가·메모 보내기", isOn: Binding(
                    get: { memoriesOn },
                    set: { memoriesOn = $0; CityMemoryConsent.state = $0 ? .granted : .declined }
                ))
            } header: {
                Text("AI로 보내는 정보")
            } footer: {
                Text("켜면 추천을 받을 때 최근 여행 평가의 별점과 메모 원문, 다녀온 도시를 외부 AI 모델로 함께 보내요. 끄면 다음 추천부터 보내지 않아요. 이미 보낸 내용은 이 앱에서 되돌릴 수 없어요. 기기에 남은 추천 기록은 데이터 삭제에서 지울 수 있어요.")
            }
            .listRowBackground(Color.dnaSurface1)
        }
        .settingsListStyle()
        .navigationTitle("권한과 보내는 정보")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: scenePhase) { await refresh() }
    }

    private func info(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
            Text(title).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
            Text(body).dnaFont(.body).foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private var photoText: String {
        switch photoStatus {
        case .authorized: "허용"
        case .limited: "일부 사진만"
        case .denied, .restricted: "허용 안 함"
        default: "아직 묻지 않음"
        }
    }

    private var notificationText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: "허용"
        case .denied: "허용 안 함"
        default: "아직 묻지 않음"
        }
    }

    private func refresh() async {
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsOn = EvaluationNotificationService.isEnabled
        fallbackOn = UserDefaults.standard.bool(forKey: AutoPhotoFallbackService.consentKey)
        memoriesOn = CityMemoryConsent.state == .granted
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func setFallback(_ on: Bool) {
        guard on else {
            UserDefaults.standard.set(false, forKey: AutoPhotoFallbackService.consentKey)
            fallbackOn = false
            return
        }
        Task {
            if !photosGranted {
                photoStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            }
            let granted = photosGranted
            UserDefaults.standard.set(granted, forKey: AutoPhotoFallbackService.consentKey)
            fallbackOn = granted
            message = granted ? nil : "사진 접근을 허용해야 켤 수 있어요. iOS 설정에서 바꿔 주세요."
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
            message = granted ? nil : "알림을 허용해야 켤 수 있어요. iOS 설정에서 바꿔 주세요."
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
        var result = ["여행 \(trips)개", "평가 \(evaluations)개", "사진 \(photos)장", "저장·제외·반응 기록 \(feedback)개"]
        if hasPreferences { result.append("원하는 여행과 기억하는 취향") }
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
            Section("하나씩 지우기") {
                NavigationLink("기억 하나") { MemorySettingsView() }
                    .foregroundStyle(Color.dnaTextPrimary)
                hint("여행이나 평가 하나", "여행 탭에서 해당 여행을 열어 지워요.")
            }
            .listRowBackground(Color.dnaSurface1)

            Section {
                Button("모든 데이터 지우기", role: .destructive) { showingConfirm = true }
                    .disabled(isDeleting)
            } footer: {
                Text("이 기기에 저장된 모든 기록이 지워져요. 계정이 없어서 다른 곳에서 복구할 수 없어요.")
            }
            .listRowBackground(Color.dnaSurface1)

            if let failure {
                Section("지우지 못한 데이터") {
                    Text("삭제를 끝내지 못했어요. 아래는 아직 남아 있는 데이터예요.")
                        .foregroundStyle(Color.dnaError)
                    ForEach(failure.lines, id: \.self) { Text($0).foregroundStyle(Color.dnaTextPrimary) }
                }
                .listRowBackground(Color.dnaSurface1)
            }
        }
        .settingsListStyle()
        .navigationTitle("데이터 삭제")
        .navigationBarTitleDisplayMode(.inline)
        .task { counts = await StoredDataCounts(store: dependencies.store) }
        .sheet(isPresented: $showingConfirm) { confirmSheet }
    }

    private func hint(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
            Text(title).foregroundStyle(Color.dnaTextPrimary)
            Text(body).dnaFont(.caption).foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private var confirmSheet: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Text("모든 데이터를 지울까요?")
                .dnaFont(.heroTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("지우면 되돌릴 수 없어요.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                ForEach(counts.lines, id: \.self) {
                    Text($0).dnaFont(.body).foregroundStyle(Color.dnaTextPrimary)
                }
            }
            Spacer(minLength: 0)
            Button(isDeleting ? "지우는 중…" : "모두 지우기") { Task { await deleteAll() } }
                .buttonStyle(.dnaPrimary(isDisabled: isDeleting))
                .disabled(isDeleting)
            Button("취소") { showingConfirm = false }
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
            counts = failure ?? counts
            showingConfirm = false
        }
    }
}
