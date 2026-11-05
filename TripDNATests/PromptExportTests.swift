import Foundation
import Synchronization
import Testing
@testable import TripDNA

/// 추천·조건 추출 지침의 실제 호출 검증 도구. 평소 테스트 실행에서는 건너뛴다.
/// `TEST_RUNNER_TRIPDNA_PROMPT_DIR=<폴더>`로 실행하면(scripts/check_prompts.py가 한다)
/// - export: 그 폴더의 cases.json으로 앱 서비스가 실제로 만드는 요청을 requests.json에 쓴다.
///   연결 모드(기본): 2단계 추천 요청에 실제 1단계 응답(extractions.json)을 쓴다. 자유문장이 있는데 응답이 없으면
///   그 사례의 추천 요청은 내보내지 않고 missing에 적는다(가짜 조건으로 대신하지 않는다).
///   단계별 모드(`TEST_RUNNER_TRIPDNA_PROMPT_MODE=staged`): 사례의 extraction(가짜 조건)으로 2단계를 만든다.
/// - check: current.json(요청 id → 응답)이 있으면 앱의 검증 코드(CityResponseValidator, CityConditionJudge)로 검사해 checks.json에 쓴다.
struct PromptExportTests {
    static let dir = ProcessInfo.processInfo.environment["TRIPDNA_PROMPT_DIR"].map { URL(fileURLWithPath: $0) }
    static let staged = ProcessInfo.processInfo.environment["TRIPDNA_PROMPT_MODE"] == "staged"
    struct MissingExtraction: Error {}

    struct Case: Decodable {
        struct Memory: Decodable {
            let id: String
            let city: String?
            let country: String
            let rating: Int?
            let liked: String?
            let disliked: String?
        }
        let id: String
        let primary: String
        var secondary: [String]?
        var wants: String?
        var avoids: String?
        var month: Int?
        var nights: Int?
        var partySize: Int?
        var budget: Int?
        var currency: String?
        var origin: String?
        var homeCountry: String?
        var extraction: String?
        var memories: [Memory]?
    }

    struct Request: Codable {
        let id: String
        let caseID: String
        let stage: String
        let system: String
        let user: String
        let userText: String
        let cardIDs: [String]
        let requiresCost: Bool
        let memoryIDs: [String]
    }

    /// 1단계는 주어진 응답(없으면 실패)을, 2단계는 후보 id를 그대로 쓴 형식상 맞는 응답을 돌려주며 두 요청을 기록한다.
    final class Recorder: CityLLMClient, @unchecked Sendable {
        let extraction: String?
        private let calls = Mutex<[(system: String, user: String)]>([])
        init(extraction: String?) { self.extraction = extraction }
        var recorded: [(system: String, user: String)] { calls.withLock { $0 } }

        func complete(system: String, user: String) async throws -> String {
            calls.withLock { $0.append((system, user)) }
            if user.contains("[Chosen concepts]") {
                guard let extraction else { throw MissingExtraction() }
                return extraction
            }
            let cards = PromptExportTests.cardIDs(in: user).map {
                "{\"id\":\"\($0)\",\"reason\":\"-\",\"caveat\":\"\",\"cost\":{\"low\":1,\"high\":2}}"
            }.joined(separator: ",")
            return "{\"understanding\":\"-\",\"cards\":[\(cards)],\"memories_used\":[]}"
        }
    }

    static func cardIDs(in user: String) -> [String] {
        guard let section = user.components(separatedBy: "[Candidate cities").dropFirst().first else { return [] }
        return section.components(separatedBy: "\n\n")[0].components(separatedBy: "\n").dropFirst()
            .map { String($0.split(separator: "|")[0]).trimmingCharacters(in: .whitespaces) }
    }

    static func request(for c: Case) throws -> RecommendationRequest {
        var request = RecommendationRequest()
        request.setPrimary(try #require(TripConcept(rawValue: c.primary)))
        request.secondary = (c.secondary ?? []).compactMap(TripConcept.init(rawValue:))
        request.wants = c.wants ?? ""
        request.avoids = c.avoids ?? ""
        request.year = c.month == nil ? nil : 2027
        request.month = c.month
        request.nights = c.nights
        request.partySize = c.partySize ?? 1
        request.budgetMax = c.budget
        request.budgetCurrency = c.currency ?? BudgetCurrency.krw
        return request
    }

    @Test(.enabled(if: dir != nil)) func exportRequests() async throws {
        let dir = try #require(Self.dir)
        struct File: Decodable { let cases: [Case] }
        let cases = try JSONDecoder().decode(File.self, from: Data(contentsOf: dir.appendingPathComponent("cases.json"))).cases
        let extractionsURL = dir.appendingPathComponent("extractions.json")
        let real = FileManager.default.fileExists(atPath: extractionsURL.path)
            ? try JSONDecoder().decode([String: String].self, from: Data(contentsOf: extractionsURL)) : [:]
        var missing: [String] = []
        let catalog = try #require(CityCatalog.load(bundle: Bundle(for: CityBundleTests.BundleToken.self)) ?? CityCatalog.load())
        let logs = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: logs) }
        var out: [Request] = []
        for c in cases {
            let recorder = Recorder(extraction: Self.staged ? (c.extraction ?? "{\"conditions\":[]}") : real[c.id])
            let service = CityRecommendationService(catalog: catalog, client: recorder, log: .init(directory: logs))
            let request = try Self.request(for: c)
            let memories = (c.memories ?? []).map {
                CityMemory(id: $0.id, tripID: $0.id, countryCode: $0.country, city: $0.city, rating: $0.rating, liked: $0.liked, disliked: $0.disliked)
            }
            // 1단계가 실패하면 앱 서비스는 2단계를 부르지 않고 오류를 던진다(조건 없이 진행하지 않음). 기록된 요청만 쓴다.
            _ = try? await service.recommend(
                request: request, tiers: WantedConceptTiers(), excludedCountries: [], homeCountryExcluded: false,
                homeCountry: c.homeCountry, departureAirport: c.origin, memories: memories, seed: 42
            )
            let hasText = !(request.wants + request.avoids).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let unlinked = !Self.staged && hasText && real[c.id] == nil
            if unlinked { missing.append(c.id) }
            for call in recorder.recorded {
                let stage = call.user.contains("[Chosen concepts]") ? "extract" : "recommend"
                if stage == "recommend" && unlinked { continue }  // 실제 1단계 응답 없이 만든 추천 요청은 내보내지 않는다
                out.append(Request(
                    id: "\(c.id):\(stage)", caseID: c.id, stage: stage, system: call.system, user: call.user,
                    userText: request.wants + "\n" + request.avoids,
                    cardIDs: stage == "recommend" ? Self.cardIDs(in: call.user) : [],
                    requiresCost: request.budgetMax != nil, memoryIDs: memories.map(\.id)
                ))
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(out).write(to: dir.appendingPathComponent("requests.json"))
        try encoder.encode(["mode": Self.staged ? "staged" : "linked", "missingExtraction": missing.joined(separator: ",")])
            .write(to: dir.appendingPathComponent("export-info.json"))
        #expect(!out.isEmpty)
    }

    @Test(.enabled(if: dir.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("current.json").path) } == true))
    func checkResponses() throws {
        let dir = try #require(Self.dir)
        let requests = try JSONDecoder().decode([Request].self, from: Data(contentsOf: dir.appendingPathComponent("requests.json")))
        let responses = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: dir.appendingPathComponent("current.json")))
        let catalog = try #require(CityCatalog.load(bundle: Bundle(for: CityBundleTests.BundleToken.self)) ?? CityCatalog.load())
        var checks: [String: [String: String]] = [:]
        for request in requests {
            guard let raw = responses[request.id] else { continue }
            var result: [String: String] = [:]
            do {
                if request.stage == "extract" {
                    let parsed = try CityResponseValidator.parseConditions(raw)
                    let (accepted, rejected) = CityConditionJudge.accept(parsed, userText: request.userText, catalog: catalog)
                    result["parse"] = "ok"
                    result["accepted"] = accepted.map { "\($0.id) \($0.level.rawValue) \($0.kind.rawValue) \($0.target ?? "-") quote=\($0.quote)" }.joined(separator: " / ")
                    result["rejected"] = rejected.joined(separator: ",")
                } else {
                    let parsed = try CityResponseValidator.parse(raw)
                    let valid = try CityResponseValidator.validate(
                        parsed, cardIDs: request.cardIDs, requiresCost: request.requiresCost, memoryIDs: Set(request.memoryIDs)
                    )
                    result["parse"] = "ok"
                    result["validate"] = "ok"
                    result["cards"] = "\(valid.cards.count)/\(request.cardIDs.count)"
                    result["order"] = valid.cards.map(\.id) == request.cardIDs.filter { id in valid.cards.contains { $0.id == id } } ? "ok" : "bad"
                }
            } catch {
                result["error"] = String(describing: error)
            }
            checks[request.id] = result
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(checks).write(to: dir.appendingPathComponent("checks.json"))
    }
}
