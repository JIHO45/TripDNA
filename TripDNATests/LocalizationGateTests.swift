import Foundation
import Testing

/// 현지화 누락 검사. 앱 코드의 원문은 영어이고 한국어는 Localizable.xcstrings의 번역이다.
/// 번역표를 코드와 맞추려면 먼저 `scripts/l10n_sync.py`를 실행한다.
struct LocalizationGateTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    /// 주석 밖의 한글은 번역을 거치지 않는 문자열이다.
    /// 의도한 예외는 그 줄에 `// l10n-ignore`, 여러 줄이면 `// l10n-ignore-begin` … `// l10n-ignore-end`.
    @Test func appCodeHasNoHangulOutsideComments() throws {
        let appDir = Self.root.appendingPathComponent("TripDNA")
        let files = FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil)!
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        #expect(files.count > 50, Comment(rawValue: "앱 소스를 찾지 못함: \(appDir.path)"))
        var hits: [String] = []
        for file in files {
            let lines = try String(contentsOf: file, encoding: .utf8).components(separatedBy: "\n")
            for (number, code) in Self.codeOnly(lines) where code.unicodeScalars.contains(where: Self.isHangul) {
                hits.append("\(file.lastPathComponent):\(number) \(lines[number - 1].trimmingCharacters(in: .whitespaces))")
            }
        }
        Self.report("hangul", hits)
        #expect(hits.isEmpty, Comment(rawValue: "번역을 거치지 않는 한글 \(hits.count)줄:\n" + hits.sorted().joined(separator: "\n")))
    }

    @Test func everyCatalogKeyHasKoreanWithMatchingPlaceholders() throws {
        let url = Self.root.appendingPathComponent("TripDNA/Localizable.xcstrings")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let strings = catalog["strings"] as! [String: [String: Any]]
        var problems: [String] = []
        for (key, entry) in strings where (entry["shouldTranslate"] as? Bool) != false && !key.trimmingCharacters(in: .whitespaces).isEmpty {
            if entry["extractionState"] as? String == "stale" { problems.append("stale: \(key)") }
            let ko = (entry["localizations"] as? [String: Any])?["ko"] as? [String: Any]
            if ko?["variations"] != nil { continue }
            let unit = ko?["stringUnit"] as? [String: String]
            guard unit?["state"] == "translated", let value = unit?["value"], !value.isEmpty else {
                problems.append("ko 없음: \(key)"); continue
            }
            if Self.placeholders(key) != Self.placeholders(value) { problems.append("자리표시 불일치: \(key) → \(value)") }
        }
        Self.report("catalog", problems)
        #expect(problems.isEmpty, Comment(rawValue: "\(problems.count)건:\n" + problems.sorted().joined(separator: "\n")))
    }

    /// xcodebuild 출력에는 실패 메시지가 안 보여서 전체 목록을 build/l10n-gate-<이름>.txt에 남긴다.
    static func report(_ name: String, _ lines: [String]) {
        let dir = root.appendingPathComponent("build")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? (lines.sorted().joined(separator: "\n") + "\n").write(to: dir.appendingPathComponent("l10n-gate-\(name).txt"), atomically: true, encoding: .utf8)
    }

    static func isHangul(_ s: Unicode.Scalar) -> Bool {
        (0xAC00...0xD7A3).contains(s.value) || (0x3131...0x318E).contains(s.value)
    }

    /// `%@`, `%lld`, `%1$@` 같은 자리표시의 종류 목록(순서 무관, 위치 번호 무시).
    static func placeholders(_ s: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: #"%(?:\d+\$)?([#0\- +']*\d*(?:\.\d+)?(?:hh|h|ll|l|q|L|z|t|j)?[@dDuUxXoOfeEgGcCsSpaAi])"#)
        return regex.matches(in: s, range: NSRange(s.startIndex..., in: s))
            .map { String(s[Range($0.range(at: 1), in: s)!]) }.sorted()
    }

    /// 줄 번호와 주석을 뺀 코드 부분. 문자열 안의 `//`는 주석으로 보지 않는다.
    static func codeOnly(_ lines: [String]) -> [(Int, String)] {
        var result: [(Int, String)] = []
        var inBlockComment = false, inMultilineString = false, ignoring = false
        for (index, line) in lines.enumerated() {
            if line.contains("l10n-ignore-begin") { ignoring = true }
            if line.contains("l10n-ignore-end") { ignoring = false; continue }
            let skip = ignoring || line.contains("// l10n-ignore")
            var code = "", inString = false
            let chars = Array(line)
            var i = 0
            while i < chars.count {
                let c = chars[i], next = i + 1 < chars.count ? chars[i + 1] : " "
                if inBlockComment {
                    if c == "*" && next == "/" { inBlockComment = false; i += 1 }
                } else if inMultilineString {
                    if line[line.index(line.startIndex, offsetBy: i)...].hasPrefix("\"\"\"") { inMultilineString = false; i += 2 }
                    code.append(c)
                } else if inString {
                    code.append(c)
                    if c == "\\" { i += 1; if i < chars.count { code.append(chars[i]) } } else if c == "\"" { inString = false }
                } else if c == "/" && next == "/" {
                    break
                } else if c == "/" && next == "*" {
                    inBlockComment = true; i += 1
                } else if c == "\"" {
                    if line[line.index(line.startIndex, offsetBy: i)...].hasPrefix("\"\"\"") { inMultilineString = true; i += 2 } else { inString = true }
                    code.append(c)
                } else {
                    code.append(c)
                }
                i += 1
            }
            if !skip { result.append((index + 1, code)) }
        }
        return result
    }
}
