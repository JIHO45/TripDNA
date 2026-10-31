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

/// 초안: 세 부분의 이름은 시안(RecoStates ⓖ)의 임시 문구이며 최종 문구는 정해지지 않았다.
nonisolated struct CityAnswer: Codable, Equatable, Sendable {
    struct Source: Codable, Equatable, Sendable {
        let title: String
        let url: URL
        /// 검색 결과가 준 page_age. 없으면 nil("게시일 미확인"으로 표시한다).
        let published: String?
        let retrievedAt: Date
    }
    /// 자료 근거. 번호는 `sources`의 1부터 시작하는 순서.
    let evidence: String
    /// 조언(적합성 판단).
    let advice: String
    /// 확인하지 못한 것.
    let unconfirmed: String
    let sources: [Source]
    /// 검색을 시도했지만 결과가 오류였던 경우.
    let searchFailed: Bool
}

nonisolated enum CityQuestionError: Error, Equatable {
    case notConfigured
    case incomplete   // pause_turn, max_tokens 등
    case refused
    case unreadable
}

nonisolated enum CityQuestionParser {
    private struct Parts: Decodable { let evidence: String?; let advice: String?; let unconfirmed: String? }

    static func parse(_ reply: CitySearchReply, now: Date) throws -> CityAnswer {
        switch reply.stopReason {
        case "refusal": throw CityQuestionError.refused
        case "pause_turn", "max_tokens": throw CityQuestionError.incomplete
        default: break
        }
        let results = reply.content.flatMap(\.results)
        let allowed = Dictionary(results.map { ($0.url, $0) }, uniquingKeysWith: { a, _ in a })
        let searched = reply.content.contains { $0.type == "server_tool_use" || $0.type == "web_search_tool_result" }
        let failed = searched && reply.content.contains { $0.searchError != nil }

        let text = reply.content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let data = String(text[start...end]).data(using: .utf8),
              let parts = try? JSONDecoder().decode(Parts.self, from: data) else { throw CityQuestionError.unreadable }

        // 출처는 이 응답의 검색 결과에 실제로 있던 URL만, 인용된 순서로. 모델이 쓴 URL은 믿지 않는다.
        var sources: [CityAnswer.Source] = []
        for url in reply.content.flatMap(\.citations).compactMap(\.url) {
            guard let hit = allowed[url], let parsed = URL(string: url), parsed.scheme?.hasPrefix("http") == true,
                  !sources.contains(where: { $0.url == parsed }) else { continue }
            sources.append(.init(title: hit.title ?? parsed.host ?? url, url: parsed, published: hit.pageAge, retrievedAt: now))
        }
        func clean(_ s: String?) -> String {
            var out = s ?? ""
            for match in out.matches(of: /https?:\/\/\S+/).reversed() { out.removeSubrange(match.range) }
            return out.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var unconfirmed = clean(parts.unconfirmed)
        if failed && sources.isEmpty {
            unconfirmed += (unconfirmed.isEmpty ? "" : "\n") + String(localized: "Search failed, so we couldn't check the latest info. That doesn't mean there isn't any.")
        }
        let evidence = clean(parts.evidence), advice = clean(parts.advice)
        guard !(evidence.isEmpty && advice.isEmpty && unconfirmed.isEmpty) else { throw CityQuestionError.unreadable }
        return CityAnswer(
            evidence: evidence,
            advice: advice, unconfirmed: unconfirmed, sources: sources, searchFailed: failed
        )
    }
}

// MARK: - 질문 서비스

nonisolated struct CityQuestionService: Sendable {
    static let maxSearches = 3

    let catalog: CityCatalog
    let client: (any CitySearchClient)?

    // l10n-ignore-begin
    static let system = """
    당신은 여행 도시 추천 앱의 질문 답변자입니다. 사용자가 받은 도시 한 곳에 대한 질문에 한국어로 답하세요.
    - 이 도시가 사용자 조건에 맞는지, 왜 맞는지, 조건과 비교하는 질문은 입력에 준 자료와 조건만으로 답하고 검색하지 마세요.
    - 가격, 운영시간, 예약, 행사·시즌 일정처럼 바뀌는 사실은 web_search로 확인하세요. 검색 결과 없이 확인했다고 말하지 마세요.
    - 검색이 실패했거나 근거가 부족하면 확인하지 못했다고 그대로 쓰세요. 못 찾은 것을 "없다"로 바꾸지 마세요.
    - URL, 사이트 이름, 날짜를 지어내지 마세요. 본문에 URL을 쓰지 마세요(출처는 검색 도구가 따로 붙입니다).
    - 입력의 등급 이름, 세부 id 같은 내부 용어를 문장에 쓰지 마세요. 입력에 없는 사용자 사실을 만들지 마세요.
    - 마지막에 다음 JSON 객체 하나만 출력하세요. 키는 영어, 값은 한국어 문장입니다. 해당 내용이 없으면 빈 문자열.
      {"evidence": "검색 결과나 입력 자료로 확인한 사실", "advice": "그 사실과 사용자 조건을 이은 판단·조언", "unconfirmed": "확인하지 못한 것"}
    """

    func user(question: String, card: CityRecommendationRecord.Card, request: RecommendationRequest?, conditionSummary: String) -> String {
        var lines = ["[도시]", "\(card.cityName) (\(card.country))"]
        if let city = catalog.cities.first(where: { $0.id == card.cityID }) {
            let strong = city.grades.filter { $0.value >= .makeTime }.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value.name)" }
            lines += ["자료의 강점 세부(내부 id, 문장에 쓰지 말 것): \(strong.isEmpty ? "없음" : strong.joined(separator: ", "))"]
            if !city.seasonUnverified.isEmpty {
                lines.append("운영 월을 확인하지 못한 세부: \(city.seasonUnverified.joined(separator: ", "))")
            }
        }
        lines += ["", "[추천 카드]", "이유: \(card.reason)"]
        if !card.caveat.isEmpty { lines.append("유의점: \(card.caveat)") }
        if let cost = card.cost { lines.append("예상 비용(추정, 원): \(cost.low)~\(cost.high)") }
        lines += ["", "[추천 조건]", conditionSummary]
        if let request {
            if let primary = request.primary { lines.append("주 컨셉: \(primary.label)") }
            if !request.secondary.isEmpty { lines.append("함께: \(request.secondary.map(\.label).joined(separator: ", "))") }
            lines.append("인원 \(request.partySize)명")
            if !request.wants.isEmpty { lines.append("원하는 것: \(request.wants)") }
            if !request.avoids.isEmpty { lines.append("피하고 싶은 것: \(request.avoids)") }
        }
        lines += ["", "[질문]", question]
        return lines.joined(separator: "\n")
    }
    // l10n-ignore-end

    func ask(
        _ question: String, card: CityRecommendationRecord.Card, request: RecommendationRequest?,
        conditionSummary: String, now: Date = Date()
    ) async throws -> CityAnswer {
        guard let client else { throw CityQuestionError.notConfigured }
        let reply = try await client.completeWithSearch(
            system: CityLLMOutputLanguage.apply(to: Self.system, textFields: "evidence, advice, unconfirmed"), user: user(question: question, card: card, request: request, conditionSummary: conditionSummary),
            maxUses: Self.maxSearches
        )
        return try CityQuestionParser.parse(reply, now: now)
    }
}
