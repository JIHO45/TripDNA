import Foundation

// MARK: - 웹 검색 응답 (Messages API content 블록, 느슨하게 읽는다)

nonisolated protocol CitySearchClient: Sendable {
    func completeWithSearch(system: String, user: String, maxUses: Int) async throws -> CitySearchReply
}

nonisolated struct CitySearchReply: Decodable, Equatable, Sendable {
    let content: [CityContentBlock]
    let stopReason: String?

    enum CodingKeys: String, CodingKey { case content; case stopReason = "stop_reason" }
}

/// `text`(citations 포함) · `server_tool_use` · `web_search_tool_result` 블록 하나.
/// 검색 결과의 content는 성공하면 배열, 실패하면 error_code가 든 객체다(HTTP는 200).
nonisolated struct CityContentBlock: Decodable, Equatable, Sendable {
    struct Result: Decodable, Equatable, Sendable {
        let url: String
        let title: String?
        let pageAge: String?
        enum CodingKeys: String, CodingKey { case url, title; case pageAge = "page_age" }
    }
    struct Citation: Decodable, Equatable, Sendable { let url: String? }
    private struct ErrorObject: Decodable { let errorCode: String?
        enum CodingKeys: String, CodingKey { case errorCode = "error_code" } }

    let type: String
    var text: String?
    var citations: [Citation] = []
    var results: [Result] = []
    var searchError: String?

    enum CodingKeys: String, CodingKey { case type, text, citations, content }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        text = try? c.decodeIfPresent(String.self, forKey: .text)
        citations = (try? c.decodeIfPresent([Citation].self, forKey: .citations)) ?? []
        if type == "web_search_tool_result" {
            if let list = try? c.decode([Result].self, forKey: .content) {
                results = list
            } else if let error = try? c.decode(ErrorObject.self, forKey: .content) {
                searchError = error.errorCode ?? "unknown"
            }
        }
    }

    init(type: String, text: String? = nil) { self.type = type; self.text = text }
}

// MARK: - 답

/// 일반 LLM 채팅처럼 본문 한 덩어리와, 그 아래 붙는 출처.
nonisolated struct CityAnswer: Codable, Equatable, Sendable {
    struct Source: Codable, Equatable, Sendable {
        let title: String
        let url: URL
        /// 검색 결과가 준 page_age. 없으면 nil("게시일 미확인"으로 표시한다).
        let published: String?
        let retrievedAt: Date
    }
    /// 답 본문(가벼운 마크다운).
    let text: String
    let sources: [Source]
    /// 검색을 시도했지만 결과가 오류였던 경우.
    let searchFailed: Bool

    init(text: String, sources: [Source], searchFailed: Bool) {
        self.text = text; self.sources = sources; self.searchFailed = searchFailed
    }

    private enum CodingKeys: String, CodingKey { case text, sources, searchFailed }
    /// 예전에 저장한 답은 세 부분(evidence/advice/unconfirmed)으로 나뉘어 있었다.
    private enum LegacyKeys: String, CodingKey { case evidence, advice, unconfirmed }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sources = try c.decode([Source].self, forKey: .sources)
        searchFailed = try c.decode(Bool.self, forKey: .searchFailed)
        if let text = try c.decodeIfPresent(String.self, forKey: .text) {
            self.text = text
        } else {
            let old = try decoder.container(keyedBy: LegacyKeys.self)
            text = [LegacyKeys.evidence, .advice, .unconfirmed]
                .compactMap { try? old.decodeIfPresent(String.self, forKey: $0) }
                .filter { !$0.isEmpty }.joined(separator: "\n\n")
        }
    }
}

nonisolated enum CityQuestionError: Error, Equatable {
    case notConfigured
    case incomplete   // pause_turn, max_tokens 등
    case refused
    case unreadable
}

nonisolated enum CityQuestionParser {
    static func parse(_ reply: CitySearchReply, now: Date) throws -> CityAnswer {
        switch reply.stopReason {
        case "refusal": throw CityQuestionError.refused
        case "pause_turn", "max_tokens": throw CityQuestionError.incomplete
        default: break
        }
        let results = reply.content.flatMap(\.results)
        let allowed = Dictionary(results.map { ($0.url, $0) }, uniquingKeysWith: { a, _ in a })
        let isTool: (CityContentBlock) -> Bool = { $0.type == "server_tool_use" || $0.type == "web_search_tool_result" }
        let failed = reply.content.contains(where: isTool) && reply.content.contains { $0.searchError != nil }

        // 검색 전에 쓴 "검색할게요" 같은 말은 버리고, 마지막 검색 뒤의 글만 답으로 쓴다.
        let afterSearch = reply.content.lastIndex(where: isTool).map { reply.content.index(after: $0) } ?? reply.content.startIndex
        var text = reply.content[afterSearch...].compactMap { $0.type == "text" ? $0.text : nil }.joined()
        for match in text.matches(of: /https?:\/\/\S+/).reversed() { text.removeSubrange(match.range) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CityQuestionError.unreadable }

        // 출처는 이 응답의 검색 결과에 실제로 있던 URL만, 인용된 순서로. 모델이 쓴 URL은 믿지 않는다.
        var sources: [CityAnswer.Source] = []
        for url in reply.content.flatMap(\.citations).compactMap(\.url) {
            guard let hit = allowed[url], let parsed = URL(string: url), parsed.scheme?.hasPrefix("http") == true,
                  !sources.contains(where: { $0.url == parsed }) else { continue }
            sources.append(.init(title: hit.title ?? parsed.host ?? url, url: parsed, published: hit.pageAge, retrievedAt: now))
        }
        if failed && sources.isEmpty {
            text += "\n\n" + String(localized: "Search failed, so we couldn't check the latest info. That doesn't mean there isn't any.")
        }
        return CityAnswer(text: text, sources: sources, searchFailed: failed)
    }
}

// MARK: - 질문 서비스

nonisolated struct CityQuestionService: Sendable {
    static let maxSearches = 3

    let catalog: CityCatalog
    let client: (any CitySearchClient)?

    // l10n-ignore-begin
    static let system = """
    You answer questions in a travel city recommendation app, about one city the user received.
    - Answer questions about whether this city fits the user's conditions, why it fits, or how it compares with the conditions using only the data and conditions in the input, without searching.
    - Check facts that change, such as prices, opening hours, bookings, and event or season dates, with web_search. Do not say you confirmed something without a search result.
    - If a search failed or the evidence is thin, say plainly that you couldn't confirm it. Do not turn "not found" into "doesn't exist".
    - Do not make up URLs, site names, or dates. Do not write URLs in the body (the search tool attaches sources separately).
    - Do not put internal terms from the input, such as grade names or sub-concept ids, into your answer. Do not invent facts about the user that are not in the input.
    - Answer the question directly, like a regular AI chat.
    - Do not use fixed sections such as "evidence / advice / what I couldn't confirm", headings (#), tables, or JSON.
    - Do not write a source list (the app adds it below the answer).
    """

    func user(question: String, card: CityRecommendationRecord.Card, request: RecommendationRequest?, conditionSummary: String) -> String {
        var lines = ["[City]", "\(card.cityName) (\(card.country))"]
        if let city = catalog.cities.first(where: { $0.id == card.cityID }) {
            let strong = city.grades.filter { $0.value >= .makeTime }.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value.name)" }
            lines += ["Strong sub-concepts in the data (internal ids; do not use in the answer): \(strong.isEmpty ? "none" : strong.joined(separator: ", "))"]
            if !city.seasonUnverified.isEmpty {
                lines.append("Sub-concepts with unverified operating months: \(city.seasonUnverified.joined(separator: ", "))")
            }
        }
        lines += ["", "[Recommendation card]", "Reason: \(card.reason)"]
        if !card.caveat.isEmpty { lines.append("Caveat: \(card.caveat)") }
        if let cost = card.cost {
            let currency = request?.budgetCurrency ?? BudgetCurrency.krw
            lines.append("Estimated cost (estimate, \(currency)): \(cost.low)~\(cost.high)")
        }
        lines += ["", "[Recommendation conditions]", conditionSummary]
        if let request {
            if let primary = request.primary { lines.append("Main concept: \(primary.label)") }
            if !request.secondary.isEmpty { lines.append("Also: \(request.secondary.map(\.label).joined(separator: ", "))") }
            lines.append("Party size: \(request.partySize)")
            if !request.wants.isEmpty { lines.append("Wants: \(request.wants)") }
            if !request.avoids.isEmpty { lines.append("Avoids: \(request.avoids)") }
        }
        lines += ["", "[Question]", question]
        return lines.joined(separator: "\n")
    }
    // l10n-ignore-end

    func ask(
        _ question: String, card: CityRecommendationRecord.Card, request: RecommendationRequest?,
        conditionSummary: String, now: Date = Date()
    ) async throws -> CityAnswer {
        guard let client else { throw CityQuestionError.notConfigured }
        let reply = try await client.completeWithSearch(
            system: CityLLMOutputLanguage.apply(to: Self.system, textFields: "the answer"), user: user(question: question, card: card, request: request, conditionSummary: conditionSummary),
            maxUses: Self.maxSearches
        )
        return try CityQuestionParser.parse(reply, now: now)
    }
}
