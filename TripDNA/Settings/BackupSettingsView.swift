import SwiftUI

/// 설정 맨 위의 백업 상태. 실제로 올라가지 않은 상태를 "백업됨"으로 보이지 않는다.
struct BackupStatusLabel: View {
    let backup: ICloudBackup?

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
            Text(text.title)
                .dnaFont(.cardTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text(text.detail)
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
        .padding(.vertical, DNASpacing.xxs)
    }

    private var text: (title: String, detail: String) {
        Self.text(status: backup?.status, lastBackupAt: backup?.lastBackupAt)
    }

    static func text(status: ICloudBackup.Status?, lastBackupAt: Date?) -> (title: String, detail: String) {
        let lost = "앱을 지우거나 기기를 바꾸면 기록을 되찾을 수 없어요."
        let last = lastBackupAt.map { "마지막 백업: \($0.formatted(date: .abbreviated, time: .shortened))" }
        switch status {
        case nil:
            return ("지금은 이 기기에만 저장돼요", lost)
        case .checking:
            return ("백업 상태를 확인하는 중", last ?? "")
        case .off:
            return ("iCloud 백업 꺼짐", lost)
        case .working:
            return ("iCloud에 백업하는 중", last ?? "")
        case .noAccount:
            return ("iCloud에 로그인되어 있지 않아 백업하지 않아요", lost)
        case .notYet:
            return ("아직 백업한 기록이 없어요", "기록이 생기면 앱을 닫을 때 iCloud에 백업해요.")
        case .upToDate:
            return ("iCloud에 백업됨", last ?? "")
        case .otherDevice:
            return ("다른 기기의 백업이 있어 백업을 멈췄어요", "되살리거나 이 기기 기록으로 바꿀 수 있어요.")
        case .failed(let message):
            return ("백업하지 못했어요", [message, last].compactMap { $0 }.joined(separator: "\n"))
        }
    }
}

struct BackupSettingsView: View {
    @Bindable var backup: ICloudBackup
    @Environment(AppDependencies.self) private var dependencies
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var confirming: Choice?
    @State private var restoreError: String?

    private enum Choice: Identifiable {
        case restore, overwrite
        var id: Self { self }
    }

    var body: some View {
        List {
            Section {
                Toggle("iCloud에 백업", isOn: $backup.isEnabled)
                    .foregroundStyle(Color.dnaTextPrimary)
                BackupStatusLabel(backup: backup)
            } footer: {
                Text("여행·평가·사진·취향 기록을 내 Apple 계정의 iCloud에 백업해요. 같은 Apple 계정으로 로그인한 새 기기에서 되살릴 수 있어요. 사진은 위치 정보를 지운 줄인 사본이고, 내 iCloud 저장 공간을 써요. TripDNA 서버에는 올리지 않아요.")
            }
            .listRowBackground(Color.dnaSurface1)

            if backup.isEnabled {
                Section {
                    Button("지금 백업") { Task { await backup.backUpIfNeeded() } }
                        .disabled(backup.status == .working)
                }
                .listRowBackground(Color.dnaSurface1)
            }

            if case .otherDevice(let manifest) = backup.status {
                Section {
                    Button("이 백업으로 되살리기") { confirming = .restore }
                    Button("이 기기 기록으로 바꾸기", role: .destructive) { confirming = .overwrite }
                } header: {
                    Text("iCloud에 있는 백업")
                } footer: {
                    Text("\(manifest.createdAt.formatted(date: .abbreviated, time: .shortened)) 백업 · 여행 \(manifest.tripCount)개")
                }
                .listRowBackground(Color.dnaSurface1)
            }

            if let restoreError {
                Section {
                    Text(restoreError).foregroundStyle(Color.dnaError)
                }
                .listRowBackground(Color.dnaSurface1)
            }
        }
        .settingsListStyle()
        .navigationTitle("iCloud 백업")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(dialogTitle, isPresented: Binding(
            get: { confirming != nil }, set: { if !$0 { confirming = nil } }
        ), titleVisibility: .visible, presenting: confirming) { choice in
            switch choice {
            case .restore:
                Button("되살리기", role: .destructive) { Task { await restore() } }
            case .overwrite:
                Button("바꾸기", role: .destructive) { Task { await backup.overwriteRemote() } }
            }
        } message: { choice in
            switch choice {
            case .restore: Text("이 기기의 기록이 백업 내용으로 바뀌어요.")
            case .overwrite: Text("iCloud에 있는 백업이 지워지고 이 기기의 기록으로 바뀌어요.")
            }
        }
    }

    private var dialogTitle: String {
        confirming == .overwrite ? "iCloud 백업을 바꿀까요?" : "백업으로 되살릴까요?"
    }

    private func restore() async {
        restoreError = nil
        do {
            try await backup.restore()
            await dependencies.restore(session: session)
            dismiss()
        } catch {
            restoreError = "되살리지 못했어요. 기기 기록은 바뀌지 않았어요."
        }
    }
}
