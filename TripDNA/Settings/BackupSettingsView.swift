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
        let lost = String(localized: "If you delete the app or switch devices, you can't get your records back.")
        let last = lastBackupAt.map { String(localized: "Last backup: \($0.formatted(date: .abbreviated, time: .shortened))") }
        switch status {
        case nil:
            return (String(localized: "Saved only on this device for now"), lost)
        case .checking:
            return (String(localized: "Checking backup status…"), last ?? "")
        case .off:
            return (String(localized: "iCloud backup is off"), lost)
        case .working:
            return (String(localized: "Backing up to iCloud…"), last ?? "")
        case .noAccount:
            return (String(localized: "Not signed in to iCloud, so nothing is backed up"), lost)
        case .notYet:
            return (String(localized: "No records backed up yet"), String(localized: "Once you have records, they're backed up to iCloud when you close the app."))
        case .upToDate:
            return (String(localized: "Backed up to iCloud"), last ?? "")
        case .otherDevice:
            return (String(localized: "Backup paused because another device has a backup"), String(localized: "You can restore it or replace it with this device's records."))
        case .failed(let message):
            return (String(localized: "Couldn't back up"), [message, last].compactMap { $0 }.joined(separator: "\n"))
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
                Toggle("Back up to iCloud", isOn: $backup.isEnabled)
                    .foregroundStyle(Color.dnaTextPrimary)
                BackupStatusLabel(backup: backup)
            } footer: {
                Text("Your trips, ratings, photos, and tastes are backed up to your Apple account's iCloud. You can restore them on a new device signed in with the same Apple account. Photos are resized copies with location data removed, and they use your iCloud storage. Nothing is uploaded to TripDNA servers.")
            }
            .listRowBackground(Color.dnaSurface1)

            if backup.isEnabled {
                Section {
                    Button("Back Up Now") { Task { await backup.backUpIfNeeded() } }
                        .disabled(backup.status == .working)
                }
                .listRowBackground(Color.dnaSurface1)
            }

            if case .otherDevice(let manifest) = backup.status {
                Section {
                    Button("Restore from This Backup") { confirming = .restore }
                    Button("Replace with This Device's Records", role: .destructive) { confirming = .overwrite }
                } header: {
                    Text("Backup in iCloud")
                } footer: {
                    Text("\(manifest.createdAt.formatted(date: .abbreviated, time: .shortened)) backup · \(manifest.tripCount) trips")
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
        .navigationTitle("iCloud backup")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(dialogTitle, isPresented: Binding(
            get: { confirming != nil }, set: { if !$0 { confirming = nil } }
        ), titleVisibility: .visible, presenting: confirming) { choice in
            switch choice {
            case .restore:
                Button("Restore", role: .destructive) { Task { await restore() } }
            case .overwrite:
                Button("Replace", role: .destructive) { Task { await backup.overwriteRemote() } }
            }
        } message: { choice in
            switch choice {
            case .restore: Text("This device's records will be replaced with the backup.")
            case .overwrite: Text("The backup in iCloud will be deleted and replaced with this device's records.")
            }
        }
    }

    private var dialogTitle: String {
        confirming == .overwrite ? String(localized: "Replace the iCloud backup?") : String(localized: "Restore from the backup?")
    }

    private func restore() async {
        restoreError = nil
        do {
            try await backup.restore()
            await dependencies.restore(session: session)
            dismiss()
        } catch {
            restoreError = String(localized: "Couldn't restore. Your device's records weren't changed.")
        }
    }
}
