import Foundation
import SwiftData
import Testing
@testable import TripDNA

/// iCloud 대신 메모리에 백업을 두는 가짜. CloudKit 자체는 기기에서 확인한다.
private actor FakeBackupRemote: BackupRemote {
    var manifest: BackupManifest?
    var snapshot: Data?
    var uploads = 0
    var failDelete = false

    init(manifest: BackupManifest? = nil, snapshot: Data? = nil) {
        self.manifest = manifest
        self.snapshot = snapshot
    }

    func setFailDelete() { failDelete = true }

    func accountAvailable() async throws -> Bool { true }
    func fetchManifest() async throws -> BackupManifest? { manifest }
    func fetchSnapshot() async throws -> Data {
        guard let snapshot else { throw BackupError.notFound }
        return snapshot
    }
    func upload(snapshot: Data, manifest: BackupManifest, newPhotos: [String: URL], removedPhotos: [String]) async throws {
        self.snapshot = snapshot
        self.manifest = manifest
        uploads += 1
    }
    func downloadPhotos(_ names: [String], into folder: URL) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    func deleteAll() async throws {
        if failDelete { throw URLError(.notConnectedToInternet) }
        manifest = nil
        snapshot = nil
    }
}

@MainActor
struct ICloudBackupTests {
    private func makeStore() throws -> SwiftDataAppStore {
        SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(inMemory: true), countries: [], tags: [])
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "backup-test-\(UUID().uuidString)")!
    }

    private func makeBackup(_ store: SwiftDataAppStore, _ remote: FakeBackupRemote) -> ICloudBackup {
        let photos = FileManager.default.temporaryDirectory.appendingPathComponent("backup-photos-\(UUID().uuidString)")
        return ICloudBackup(store: store, remote: remote, defaults: makeDefaults(), photoFolder: photos)
    }

    private func profile(_ id: String) -> UserProfile {
        UserProfile(id: id, locale: "ko_KR", onboardingStatus: .done, homeCountryCode: "KR", departureAirportCode: nil, createdAt: .now)
    }

    @Test func exportAndRestoreKeepEveryRow() async throws {
        let source = try makeStore()
        try await source.saveProfile(profile("me"))
        try await source.saveInterestTagIDs(["food"])
        let snapshot = try await source.exportBackup()

        let target = try makeStore()
        try await target.saveProfile(profile("other"))
        try await target.restoreBackup(snapshot)

        #expect(try await target.loadProfile()?.id == "me")
        #expect(try await target.loadInterestTagIDs() == ["food"])
        #expect(try await target.exportBackup() == snapshot)
    }

    @Test func unchangedRecordsAreNotUploadedAgain() async throws {
        let store = try makeStore()
        try await store.saveProfile(profile("me"))
        let remote = FakeBackupRemote()
        let backup = makeBackup(store, remote)

        await backup.backUpIfNeeded()
        await backup.backUpIfNeeded()
        #expect(await remote.uploads == 1)
        #expect(backup.status == .upToDate)
        #expect(backup.lastBackupAt != nil)

        try await store.saveInterestTagIDs(["food"])
        await backup.backUpIfNeeded()
        #expect(await remote.uploads == 2)
    }

    @Test func emptyDeviceDoesNotUploadNothing() async throws {
        let remote = FakeBackupRemote()
        let backup = makeBackup(try makeStore(), remote)
        await backup.backUpIfNeeded()
        #expect(await remote.uploads == 0)
        #expect(backup.status == .notYet)
    }

    @Test func anotherDevicesBackupIsNotOverwrittenUntilChosen() async throws {
        let other = try makeStore()
        try await other.saveProfile(profile("old"))
        let otherRemote = FakeBackupRemote()
        await makeBackup(other, otherRemote).backUpIfNeeded()
        let remote = FakeBackupRemote(manifest: await otherRemote.manifest, snapshot: await otherRemote.snapshot)

        let store = try makeStore()
        try await store.saveProfile(profile("new"))
        let backup = makeBackup(store, remote)
        await backup.backUpIfNeeded()
        #expect(await remote.uploads == 0)
        guard case .otherDevice = backup.status else {
            Issue.record("다른 기기 백업을 알려야 한다: \(backup.status)")
            return
        }
        #expect(await backup.restorableBackup() != nil)

        await backup.overwriteRemote()
        #expect(await remote.uploads == 1)
        #expect(await backup.restorableBackup() == nil)
    }

    @Test func restoreReplacesLocalRecordsAndTakesOverTheBackup() async throws {
        let other = try makeStore()
        try await other.saveProfile(profile("old"))
        let otherRemote = FakeBackupRemote()
        await makeBackup(other, otherRemote).backUpIfNeeded()
        let remote = FakeBackupRemote(manifest: await otherRemote.manifest, snapshot: await otherRemote.snapshot)

        let store = try makeStore()
        let backup = makeBackup(store, remote)
        try await backup.restore()

        #expect(try await store.loadProfile()?.id == "old")
        // 되살린 기기가 이제 백업의 주인이라 다음 변경부터 이어서 올린다.
        #expect(await backup.restorableBackup() == nil)
        #expect(backup.status == .upToDate)
    }

    @Test func unreadableBackupLeavesLocalRecordsAlone() async throws {
        let store = try makeStore()
        try await store.saveProfile(profile("me"))
        let broken = BackupSnapshot(
            trips: [.init(id: "t", createdAt: .now, updatedAt: nil, payload: Data("{}".utf8))],
            feedback: [], photos: [], singletons: []
        )
        let manifest = BackupManifest(createdAt: .now, deviceID: "other", photoNames: [], tripCount: 1, snapshotHash: "x")
        let backup = makeBackup(store, FakeBackupRemote(manifest: manifest, snapshot: try broken.encoded()))

        await #expect(throws: (any Error).self) { try await backup.restore() }
        #expect(try await store.loadProfile()?.id == "me")
    }

    @Test func failedRemoteDeletionIsReported() async throws {
        let remote = FakeBackupRemote()
        await remote.setFailDelete()
        let backup = makeBackup(try makeStore(), remote)
        await #expect(throws: BackupError.remoteDeleteFailed) { try await backup.deleteRemote() }
    }

    @Test func statusNeverClaimsBackupWithoutOne() {
        #expect(BackupStatusLabel.text(status: .noAccount, lastBackupAt: nil).title.contains("백업하지 않아요"))
        #expect(!BackupStatusLabel.text(status: .failed("x"), lastBackupAt: .now).title.contains("백업됨"))
        #expect(BackupStatusLabel.text(status: nil, lastBackupAt: nil).title == "지금은 이 기기에만 저장돼요")
    }
}
