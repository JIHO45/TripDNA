import Foundation
import Testing
@testable import TripDNA

struct CityQuestionTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func reply(_ json: String) throws -> CitySearchReply {
        try JSONDecoder().decode(CitySearchReply.self, from: Data(json.utf8))
    }

    static let answerText = #"{\"evidence\":\"입장료는 15유로예요.\",\"advice\":\"미식 취향에 맞아요.\",\"unconfirmed\":\"예약 여부\"}"#

    static func fixture(results: String, citedURL: String, stop: String = "end_turn") -> String {
        """
        {"stop_reason":"\(stop)","content":[
         {"type":"text","text":"검색할게요."},
         {"type":"server_tool_use","id":"s1","name":"web_search","input":{"query":"x"}},
         {"type":"web_search_tool_result","tool_use_id":"s1","content":\(results)},
         {"type":"text","text":"\(answerText)","citations":[{"type":"web_search_result_location","url":"\(citedURL)","title":"모델이 쓴 제목","cited_text":"..."}]}
        ]}
        """
    }

    static let okResults = #"[{"type":"web_search_result","url":"https://a.example/x","title":"공식 안내","page_age":"April 30, 2026","encrypted_content":"zz"}]"#

    @Test func parsesThreePartsAndSources() throws {
        let answer = try CityQuestionParser.parse(Self.reply(Self.fixture(results: Self.okResults, citedURL: "https://a.example/x")), now: Self.now)
        #expect(answer.evidence == "입장료는 15유로예요." && answer.advice == "미식 취향에 맞아요." && answer.unconfirmed == "예약 여부")
        #expect(answer.sources.count == 1)
        #expect(answer.sources[0].url.absoluteString == "https://a.example/x")
        #expect(answer.sources[0].title == "공식 안내")
        #expect(answer.sources[0].published == "April 30, 2026")
    }

    @Test func dropsURLNotInSearchResults() throws {
        let answer = try CityQuestionParser.parse(Self.reply(Self.fixture(results: Self.okResults, citedURL: "https://fake.example/y")), now: Self.now)
        #expect(answer.sources.isEmpty)
    }

    @Test func searchErrorKeepsAnswerAndFlagsUnconfirmed() throws {
        let errorResult = #"{"type":"web_search_tool_result_error","error_code":"unavailable"}"#
        let answer = try CityQuestionParser.parse(Self.reply(Self.fixture(results: errorResult, citedURL: "https://a.example/x")), now: Self.now)
        #expect(answer.sources.isEmpty && answer.searchFailed)
        #expect(answer.evidence == "입장료는 15유로예요.")
        #expect(answer.unconfirmed.contains("확인하지 못했어요"))
    }

    @Test func pauseTurnAndRefusalFail() throws {
        #expect(throws: CityQuestionError.incomplete) {
            try CityQuestionParser.parse(Self.reply(Self.fixture(results: Self.okResults, citedURL: "https://a.example/x", stop: "pause_turn")), now: Self.now)
        }
        #expect(throws: CityQuestionError.refused) {
            try CityQuestionParser.parse(Self.reply(Self.fixture(results: Self.okResults, citedURL: "https://a.example/x", stop: "refusal")), now: Self.now)
        }
    }

    @Test func directBodyHasSearchToolAndNoSampling() {
        let body = AnthropicDirectClient.searchBody(model: "m", system: "s", user: "u", maxUses: 3)
        let tool = (body["tools"] as? [[String: Any]])?.first
        #expect(tool?["type"] as? String == "web_search_20250305")
        #expect(tool?["max_uses"] as? Int == 3)
        #expect(body["temperature"] == nil && body["top_p"] == nil && body["top_k"] == nil)
    }

    struct Fake: CitySearchClient {
        let reply: CitySearchReply
        func completeWithSearch(system: String, user: String, maxUses: Int) async throws -> CitySearchReply { reply }
    }

    @Test func serviceEndToEndWithFake() async throws {
        let card = CityRecommendationRecord.Card(
            cityID: "c", cityName: "리스본", country: "PT", isExploration: false, seasonCheckNeeded: false,
            reason: "미식", caveat: "", cost: nil, conditions: [], conditionCheckNeeded: false
        )
        let catalog = CityCatalog(version: "t", concepts: [:], cities: [])
        let fake = Fake(reply: try Self.reply(Self.fixture(results: Self.okResults, citedURL: "https://a.example/x")))
        let service = CityQuestionService(catalog: catalog, client: fake)
        let answer = try await service.ask("입장료는?", card: card, request: nil, conditionSummary: "음식 · 3박", now: Self.now)
        #expect(answer.sources.count == 1)
        await #expect(throws: CityQuestionError.notConfigured) {
            try await CityQuestionService(catalog: catalog, client: nil).ask("q", card: card, request: nil, conditionSummary: "")
        }
    }
}
