import CloudKit
import CryptoKit
import Foundation
import UIKit

// MARK: - 백업본

/// iCloud에 올리는 기록 한 벌. 저장소의 행을 그대로 담는다(도메인 값은 이미 JSON이다).
/// 기기 안 측정 기록(이벤트)과 추천 기록 파일은 넣지 않는다.
nonisolated struct BackupSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1

    struct Row: Codable, Equatable, Sendable {
        let id: String
        let createdAt: Date
        let updatedAt: Date?
        let payload: Data
    }

    struct PhotoRow: Codable, Equatable, Sendable {
        let id: String
        let tripID: String
        let tripDayIndex: Int
        let updatedAt: Date?
        let payload: Data
    }

    struct SingletonRow: Codable, Equatable, Sendable {
        let key: String
        let updatedAt: Date?
        let payload: Data
    }

    var version = currentVersion
    let trips: [Row]
    let feedback: [Row]
    let photos: [PhotoRow]
    let singletons: [SingletonRow]

    var isEmpty: Bool { trips.isEmpty && feedback.isEmpty && photos.isEmpty && singletons.isEmpty }

    /// 키 순서를 고정해 같은 내용이면 같은 바이트가 되게 한다.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> BackupSnapshot {
        let snapshot = try JSONDecoder().decode(BackupSnapshot.self, from: data)
        guard snapshot.version <= currentVersion else { throw BackupError.newerVersion }
        return snapshot
    }

    /// 기기 기록을 지우기 전에 백업의 여행·반응·사진 기록을 모두 읽을 수 있는지 본다.
    func validate() throws {
        let decoder = JSONDecoder()
        for row in trips { _ = try decoder.decode(Trip.self, from: row.payload) }
        for row in feedback { _ = try decoder.decode(CardFeedback.self, from: row.payload) }
        for row in photos { _ = try decoder.decode(DailyPhoto.self, from: row.payload) }
    }
}

/// 백업의 겉정보. 백업본을 내려받지 않고도 언제·어느 기기가 올렸는지 안다.
nonisolated struct BackupManifest: Equatable, Sendable {
    let createdAt: Date
    /// 올린 기기의 설치 ID. 앱을 지우면 바뀌므로 재설치한 기기도 "다른 기기"로 본다.
    let deviceID: String
    let photoNames: [String]
    let tripCount: Int
    let snapshotHash: String
}

nonisolated enum BackupError: Error, Equatable {
    case notFound
    case newerVersion
    case remoteDeleteFailed
}

// MARK: - iCloud 저장소

nonisolated protocol BackupRemote: Sendable {
    func accountAvailable() async throws -> Bool
    func fetchManifest() async throws -> BackupManifest?
    func fetchSnapshot() async throws -> Data
    /// 새 사진을 먼저 올리고 겉정보·백업본을 저장한 뒤, 빠진 사진을 지운다.
    func upload(snapshot: Data, manifest: BackupManifest, newPhotos: [String: URL], removedPhotos: [String]) async throws
    func downloadPhotos(_ names: [String], into folder: URL) async throws
    func deleteAll() async throws
}

/// 사용자 iCloud의 비공개 CloudKit 저장소. 전용 영역(zone) 하나에 백업 기록 1개와 사진마다 기록 1개를 둔다.
/// 영역째 지우면 백업이 모두 사라진다. 출시 전에 CloudKit 콘솔에서 스키마를 Production으로 배포해야 한다.
nonisolated struct CloudKitBackupRemote: BackupRemote {
    static let containerID = "iCloud.com.Joe.TripDNA"
    private static let zoneID = CKRecordZone.ID(zoneName: "TripDNABackup", ownerName: CKCurrentUserDefaultName)
    private static let manifestID = CKRecord.ID(recordName: "backup", zoneID: zoneID)
    private static let manifestKeys = ["createdAt", "deviceID", "photoNames", "tripCount", "snapshotHash"]

    // 만들기만 해서는 iCloud에 접근하지 않도록 쓸 때 연다.
    private var container: CKContainer { CKContainer(identifier: Self.containerID) }
    private var database: CKDatabase { container.privateCloudDatabase }

    private static func photoID(_ name: String) -> CKRecord.ID {
        CKRecord.ID(recordName: "photo-\(name)", zoneID: zoneID)
    }

    func accountAvailable() async throws -> Bool {
        try await container.accountStatus() == .available
    }

    func fetchManifest() async throws -> BackupManifest? {
        let record: CKRecord
        do {
            let results = try await database.records(for: [Self.manifestID], desiredKeys: Self.manifestKeys)
            guard let result = results[Self.manifestID] else { return nil }
            record = try result.get()
        } catch let error as CKError where Self.isMissing(error) {
            // ponytail: 사용자가 iOS 설정에서 지운 영역(userDeletedZone)도 "백업 없음"으로 보고 다음 백업이 영역을 다시 만든다.
            // 이렇게 하지 않으면 백업이 영영 막힌다. Apple은 다시 올리기 전에 묻기를 권하므로, 불만이 나오면 확인 단계를 둔다.
            return nil
        }
        guard let createdAt = record["createdAt"] as? Date,
              let deviceID = record["deviceID"] as? String,
              let hash = record["snapshotHash"] as? String else { return nil }
        return BackupManifest(
            createdAt: createdAt,
            deviceID: deviceID,
            photoNames: record["photoNames"] as? [String] ?? [],
            tripCount: record["tripCount"] as? Int ?? 0,
            snapshotHash: hash
        )
    }

    func fetchSnapshot() async throws -> Data {
        let record: CKRecord
        do {
            record = try await database.record(for: Self.manifestID)
        } catch let error as CKError where Self.isMissing(error) {
            throw BackupError.notFound
        }
        guard let url = (record["snapshot"] as? CKAsset)?.fileURL else { throw BackupError.notFound }
        return try Data(contentsOf: url)
    }

    func upload(snapshot: Data, manifest: BackupManifest, newPhotos: [String: URL], removedPhotos: [String]) async throws {
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: Self.zoneID)], deleting: [])

        // 한 요청의 기록 수 한도(400)보다 작게 나눠 올린다.
        let names = newPhotos.keys.sorted()
        for start in stride(from: 0, to: names.count, by: 50) {
            let records = names[start..<min(start + 50, names.count)].map { name in
                let record = CKRecord(recordType: "BackupPhoto", recordID: Self.photoID(name))
                record["file"] = CKAsset(fileURL: newPhotos[name]!)
                return record
            }
            let (saved, _) = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
            for result in saved.values { _ = try result.get() }
        }

        let file = FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(UUID().uuidString).json")
        try snapshot.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let record = CKRecord(recordType: "Backup", recordID: Self.manifestID)
        record["createdAt"] = manifest.createdAt
        record["deviceID"] = manifest.deviceID
        record["photoNames"] = manifest.photoNames
        record["tripCount"] = manifest.tripCount
        record["snapshotHash"] = manifest.snapshotHash
        record["snapshot"] = CKAsset(fileURL: file)
        let (saved, _) = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        _ = try saved[Self.manifestID]?.get()

        // 빠진 사진 지우기는 실패해도 백업은 맞다(남은 사진은 다음 복구에 쓰이지 않는다).
        if !removedPhotos.isEmpty {
            _ = try? await database.modifyRecords(saving: [], deleting: removedPhotos.map(Self.photoID))
        }
    }

    func downloadPhotos(_ names: [String], into folder: URL) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for start in stride(from: 0, to: names.count, by: 50) {
            let chunk = Array(names[start..<min(start + 50, names.count)])
            let results = try await database.records(for: chunk.map(Self.photoID))
            for name in chunk {
                guard let result = results[Self.photoID(name)] else { continue }
                let record: CKRecord
                do {
                    record = try result.get()
                } catch let error as CKError where error.code == .unknownItem {
                    continue // 사진 하나가 빠졌어도 나머지 기록은 되살린다.
                }
                guard let url = (record["file"] as? CKAsset)?.fileURL else { continue }
                try FileManager.default.copyItem(at: url, to: folder.appendingPathComponent(name))
            }
        }
    }

    func deleteAll() async throws {
        do {
            let (_, deleted) = try await database.modifyRecordZones(saving: [], deleting: [Self.zoneID])
            _ = try deleted[Self.zoneID]?.get()
        } catch let error as CKError where Self.isMissing(error) {
            return // 이미 없다(사용자가 iOS 설정에서 지운 경우 포함).
        }
    }

    /// 백업이 없다는 뜻의 오류. 사용자가 iOS 설정 › iCloud에서 앱 데이터를 지우면 userDeletedZone이 온다.
    private static func isMissing(_ error: CKError) -> Bool {
        [.unknownItem, .zoneNotFound, .userDeletedZone].contains(error.code)
    }
}

// MARK: - 백업 상태와 동작

/// 자동 백업(앱을 닫을 때·켤 때), 새 기기 복구, 전체 삭제 때 iCloud 사본 지우기를 맡는다.
/// 다른 기기(또는 재설치 전)의 백업은 사용자가 고르기 전까지 덮어쓰지 않는다.
@Observable
final class ICloudBackup {
    enum Status: Equatable {
        case checking
        case off
        case working
        case noAccount
        case notYet
        case upToDate
        case otherDevice(BackupManifest)
        case failed(String)
    }

    private(set) var status = Status.checking
    private(set) var lastBackupAt: Date?
    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            if isEnabled {
                Task { await backUpIfNeeded() }
            } else {
                status = .off
            }
        }
    }

    private let store: SwiftDataAppStore
    private let remote: any BackupRemote
    private let defaults: UserDefaults
    private let deviceID: String
    /// 사진 파일 폴더. 테스트는 기기의 실제 사진을 건드리지 않도록 임시 폴더를 넘긴다.
    private let photoFolder: URL
    private var running: Task<Void, Never>?
    @ObservationIgnored private var backgroundTask = UIBackgroundTaskIdentifier.invalid

    private enum Keys {
        static let enabled = "backup.enabled"
        static let deviceID = "backup.deviceID"
        static let lastBackupAt = "backup.lastBackupAt"
    }

    init(
        store: SwiftDataAppStore,
        remote: any BackupRemote = CloudKitBackupRemote(),
        defaults: UserDefaults = AppStorageLocation.defaults,
        photoFolder: URL = LocalPhotoStore.directory
    ) {
        self.store = store
        self.photoFolder = photoFolder
        self.remote = remote
        self.defaults = defaults
        // 기본으로 켠다(2026-10-31 사용자 결정).
        isEnabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        lastBackupAt = defaults.object(forKey: Keys.lastBackupAt) as? Date
        if let id = defaults.string(forKey: Keys.deviceID) {
            deviceID = id
        } else {
            deviceID = UUID().uuidString
            defaults.set(deviceID, forKey: Keys.deviceID)
        }
        if !isEnabled { status = .off }
    }

    /// 바뀐 게 있으면 올린다. 이미 돌고 있으면 그 작업이 끝나기만 기다린다.
    func backUpIfNeeded() async {
        guard isEnabled else { return }
        await run { await self.performBackup(overwrite: false) }
    }

    /// 앱이 뒤로 갈 때. 시스템이 잠깐 시간을 더 주는 동안 올린다.
    func backUpInBackground() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "iCloud backup") { [weak self] in
            // 시간이 다 되면 멈추고 바로 끝낸다. 끝내지 않으면 시스템이 앱을 강제로 종료한다. 남은 사진은 다음 백업이 올린다.
            self?.running?.cancel()
            self?.endBackgroundTask()
        }
        Task {
            await backUpIfNeeded()
            endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    /// 다른 기기의 백업을 이 기기 기록으로 바꾼다(사용자가 고른 경우만).
    func overwriteRemote() async {
        await run { await self.performBackup(overwrite: true) }
    }

    /// 새로 설치한 기기에서 되살릴 백업이 있는지 본다. 이 기기가 올린 백업이면 nil이다.
    func restorableBackup() async -> BackupManifest? {
        guard isEnabled, (try? await remote.accountAvailable()) == true,
              let manifest = try? await remote.fetchManifest(), manifest.deviceID != deviceID else { return nil }
        status = .otherDevice(manifest)
        return manifest
    }

    /// iCloud의 백업으로 이 기기의 기록과 사진을 바꾸고, 이 기기를 백업의 주인으로 삼는다.
    func restore() async throws {
        await running?.value
        status = .working
        do {
            let snapshot = try BackupSnapshot.decode(try await remote.fetchSnapshot())
            try snapshot.validate()
            guard let manifest = try await remote.fetchManifest() else { throw BackupError.notFound }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
            try await remote.downloadPhotos(manifest.photoNames, into: folder)
            // 내려받은 사진들로 사진 폴더를 통째로 바꾼다. 기존 사진은 옆으로 옮겨 두었다가
            // 기록까지 다 되살린 뒤에만 지운다. 중간에 실패하면 기존 사진을 제자리로 돌린다.
            let files = FileManager.default
            let previous = photoFolder.deletingLastPathComponent()
                .appendingPathComponent("\(photoFolder.lastPathComponent)-before-restore-\(UUID().uuidString)", isDirectory: true)
            let hadPhotos = files.fileExists(atPath: photoFolder.path)
            if hadPhotos { try files.moveItem(at: photoFolder, to: previous) }
            do {
                try files.createDirectory(at: photoFolder.deletingLastPathComponent(), withIntermediateDirectories: true)
                try files.moveItem(at: folder, to: photoFolder)
                try await store.restoreBackup(snapshot)
            } catch {
                // 기존 사진은 옆에 있으므로 지금 자리의 폴더는 내려받은 사진뿐이다.
                try? files.removeItem(at: photoFolder)
                if hadPhotos { try? files.moveItem(at: previous, to: photoFolder) }
                throw error
            }
            if hadPhotos { try? files.removeItem(at: previous) }
        } catch {
            status = Self.status(for: error)
            throw error
        }
        await run { await self.performBackup(overwrite: true) }
    }

    /// 전체 삭제의 첫 단계. 지우지 못하면 기기 기록도 지우지 않도록 호출자가 멈춘다.
    func deleteRemote() async throws {
        running?.cancel()
        await running?.value
        do {
            // iCloud에 로그인돼 있지 않으면 이 기기에서 닿을 백업이 없다.
            if try await remote.accountAvailable() {
                try await remote.deleteAll()
            }
        } catch {
            throw BackupError.remoteDeleteFailed
        }
        lastBackupAt = nil
        defaults.removeObject(forKey: Keys.lastBackupAt)
        status = isEnabled ? .notYet : .off
    }

    private func run(_ work: @escaping () async -> Void) async {
        if let running {
            await running.value
            return
        }
        let task = Task { await work() }
        running = task
        await task.value
        running = nil
    }

    private func performBackup(overwrite: Bool) async {
        do {
            guard try await remote.accountAvailable() else {
                status = .noAccount
                return
            }
            let snapshot = try await store.exportBackup()
            let data = try snapshot.encoded()
            let photoNames = ((try? FileManager.default.contentsOfDirectory(atPath: photoFolder.path)) ?? [])
                .filter { $0.hasSuffix(".jpg") }.sorted()
            let hash = Self.hash(data, photoNames)

            let existing = try await remote.fetchManifest()
            if let existing, existing.deviceID != deviceID, !overwrite {
                status = .otherDevice(existing)
                return
            }
            if let existing, existing.snapshotHash == hash, existing.deviceID == deviceID {
                markBackedUp(existing.createdAt)
                return
            }
            if existing == nil, snapshot.isEmpty {
                status = .notYet
                return
            }
            try Task.checkCancellation()

            status = .working
            let previous = Set(existing?.photoNames ?? [])
            var newPhotos: [String: URL] = [:]
            for name in photoNames where !previous.contains(name) {
                newPhotos[name] = photoFolder.appendingPathComponent(name)
            }
            let manifest = BackupManifest(
                createdAt: .now, deviceID: deviceID, photoNames: photoNames,
                tripCount: snapshot.trips.count, snapshotHash: hash
            )
            try await remote.upload(
                snapshot: data, manifest: manifest, newPhotos: newPhotos,
                removedPhotos: Array(previous.subtracting(photoNames))
            )
            markBackedUp(manifest.createdAt)
        } catch {
            status = Self.status(for: error)
        }
    }

    private func markBackedUp(_ date: Date) {
        lastBackupAt = date
        defaults.set(date, forKey: Keys.lastBackupAt)
        status = .upToDate
    }

    private static func hash(_ data: Data, _ photoNames: [String]) -> String {
        var hasher = SHA256()
        hasher.update(data: data)
        hasher.update(data: Data(photoNames.joined(separator: "\n").utf8))
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func status(for error: Error) -> Status {
        if error is CancellationError { return .failed(String(localized: "Backup stopped.")) }
        if case BackupError.newerVersion = error { return .failed(String(localized: "This backup was made by a newer version of the app. Please update the app.")) }
        if case BackupError.notFound = error { return .failed(String(localized: "Couldn't find the backup in iCloud.")) }
        guard let error = error as? CKError else { return .failed(String(localized: "Couldn't back up. Please try again in a moment.")) }
        switch error.code {
        case .notAuthenticated:
            return .noAccount
        case .quotaExceeded:
            return .failed(String(localized: "Couldn't back up because iCloud storage is full."))
        case .networkUnavailable, .networkFailure:
            return .failed(String(localized: "Couldn't back up because you're not connected to the internet."))
        default:
            return .failed(String(localized: "Couldn't back up. Please try again in a moment."))
        }
    }
}
