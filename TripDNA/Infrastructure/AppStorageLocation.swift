import Foundation

/// 기기 상태(UserDefaults·파일)가 놓이는 곳을 한 군데에서 정한다.
/// `-uiDemo`·`-uiTesting`으로 띄우면 기기에 남은 실제 값을 건드리지 않도록 별도 위치를 쓰고, 실행할 때마다 비운다.
nonisolated enum AppStorageLocation {
    static let demoSuite = "tripdna.demo"
    private static let demoFolder = "TripDNADemo"

    #if DEBUG
    static let isIsolated: Bool = {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-uiDemo") || args.contains("-uiTesting")
    }()
    #else
    static let isIsolated = false
    #endif

    /// 앱 전체가 쓰는 UserDefaults. 격리 모드에서는 데모 전용 suite다.
    static let defaults = makeDefaults(isolated: isIsolated)

    /// `Documents`·`Application Support` 같은 기본 폴더. 격리 모드에서는 임시 폴더 아래로 옮긴다.
    static func directory(_ search: FileManager.SearchPathDirectory) -> URL {
        directory(search, isolated: isIsolated)
    }

    static func makeDefaults(isolated: Bool) -> UserDefaults {
        guard isolated, let suite = UserDefaults(suiteName: demoSuite) else { return .standard }
        suite.removePersistentDomain(forName: demoSuite)
        return suite
    }

    static func directory(_ search: FileManager.SearchPathDirectory, isolated: Bool) -> URL {
        let real = FileManager.default.urls(for: search, in: .userDomainMask)[0]
        guard isolated else { return real }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(demoFolder, isDirectory: true)
            .appendingPathComponent("\(search.rawValue)", isDirectory: true)
    }
}
