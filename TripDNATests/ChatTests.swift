import Foundation
import Synchronization
import Testing
@testable import TripDNA

/// 대화 순서대로 답을 돌려주는 가짜 LLM. 받은 요청의 목적을 기록한다.
final class FakeChat: ChatClient, @unchecked Sendable {
    private let calls = Mutex<[ChatPurpose]>([])
    private let sentSystems = Mutex<[String]>([])
    let handler: @Sendable (ChatPurpose, [ChatTurn]) throws -> ChatReply

    init(_ handler: @escaping @Sendable (ChatPurpose, [ChatTurn]) throws -> ChatReply) { self.handler = handler }

    var purposes: [ChatPurpose] { calls.withLock { $0 } }
    var systems: [String] { sentSystems.withLock { $0 } }

    func chat(system: String, turns: [ChatTurn], purpose: ChatPurpose, searchUses: Int?) async throws -> ChatReply {
        calls.withLock { $0.append(purpose) }
        sentSystems.withLock { $0.append(system) }
        return try handler(purpose, turns)
    }

    static func text(_ text: String, usage: AIUsage? = nil) -> ChatReply {
        ChatReply(reply: CitySearchReply(content: [CityContentBlock(type: "text", text: text)], stopReason: "end_turn"), usage: usage)
    }
}

/// persist 호출을 모은다.
final class Saved: @unchecked Sendable {
    private let items = Mutex<[ChatConversation]>([])
    var all: [ChatConversation] { items.withLock { $0 } }
    func add(_ c: ChatConversation) { items.withLock { $0.append(c) } }
}

struct ChatTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let context = ChatContextSnapshot(text: "묻는 곳: 추천 탭", builtAt: now, includesRatings: false)

    static func conversation(pairs: Int, length: Int = 10, summary: ChatSummary? = nil, includesRatings: Bool = false) -> ChatConversation {
        var c = ChatService.newConversation(
            tab: .recommendation,
            context: ChatContextSnapshot(text: "정보", builtAt: now, includesRatings: includesRatings), now: now
        )
        for i in 0..<pairs {
            c.messages.append(ChatMessage(role: .user, text: "q\(i)" + String(repeating: "가", count: length), date: now))
            c.messages.append(ChatMessage(role: .assistant, text: "a\(i)" + String(repeating: "나", count: length), date: now))
        }
        c.summary = summary
        return c
    }

    // MARK: 저장

    @Test func conversationsSurviveReopenAndDeleteAll() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        let usage = AIUsage(share: 0.4, resetAt: Self.now, subscribed: false)
        do {
            let store = SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(url: url), countries: [], tags: [])
            let saved = try await store.updateChatState(ifGeneration: store.dataGeneration.current) {
                $0.upsert(Self.conversation(pairs: 1))
                $0.usage = usage
            }
            #expect(saved)
        }
        let reopened = SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(url: url), countries: [], tags: [])
        let state = try await reopened.loadChatState()
        #expect(state.conversations.first?.messages.count == 2)
        #expect(state.usage == usage)

        let stores: [any AppStore] = [reopened, InMemoryAppStore()]
        for store in stores {
            try await store.updateChatState(ifGeneration: store.dataGeneration.current) { $0.upsert(Self.conversation(pairs: 1)) }
            let generation = store.dataGeneration.current
            try await store.deleteAllUserData()
            #expect(try await store.loadChatState() == ChatState())
            // 기다리던 답은 전체 삭제 뒤에 저장하지 않는다.
            #expect(try await !store.updateChatState(ifGeneration: generation) { $0.upsert(Self.conversation(pairs: 1)) })
        }
    }

    // MARK: 보낼 내용

    @Test func sendsSummaryPlusMessagesAfterIt() {
        let c = Self.conversation(pairs: 3, summary: ChatSummary(text: "요약본", coveredCount: 2))
        guard case .send(let system, let turns) = ChatPlanner.plan(c, question: "새 질문", baseSystem: "기본") else {
            Issue.record("expected send"); return
        }
        #expect(system.contains("요약본") && system.contains("정보"))
        #expect(turns.map(\.content) == [c.messages[2].text, c.messages[3].text, c.messages[4].text, c.messages[5].text, "새 질문"])
        #expect(turns.first?.role == .user && turns.last?.role == .user)
    }

    @Test func longConversationIsSummarizedKeepingRecentTurns() {
        let c = Self.conversation(pairs: 10, length: 1000)
        let limit = 10_000
        guard case .summarize(let upTo) = ChatPlanner.plan(c, question: "q", baseSystem: "b", limit: limit) else {
            Issue.record("expected summarize"); return
        }
        #expect(upTo > 0 && upTo % 2 == 0)
        #expect(upTo <= c.messages.count - ChatPlanner.keepRecentTurns * 2 || upTo == c.messages.count)
        // 요약 뒤에는 보낼 수 있다.
        var summarized = c
        summarized.summary = ChatSummary(text: "요약", coveredCount: upTo)
        if case .summarize = ChatPlanner.plan(summarized, question: "q", baseSystem: "b", limit: limit) {
            // 요약 요청 한도 때문에 나눠 요약하는 경우만 허용
            #expect(upTo < c.messages.count - ChatPlanner.keepRecentTurns * 2)
        }
    }

    @Test func repeatedSummaryCoversExistingSummaryAndNewMessagesOnly() {
        let c = Self.conversation(pairs: 4, summary: ChatSummary(text: "앞의 요약", coveredCount: 4))
        let request = ChatPlanner.summaryRequest(c, upTo: 6)
        #expect(request.contains("앞의 요약"))
        #expect(!request.contains("q0") && !request.contains("q1"))
        #expect(request.contains("q2") && request.contains("a2"))
        #expect(!request.contains("q3"))
    }

    @Test func veryLongRecentReplyIsFoldedIntoSummary() {
        // 최근 답 하나가 한도를 넘으면 최근 N번 안이라도 요약에 넣는다.
        var c = Self.conversation(pairs: 2)
        c.messages[3] = ChatMessage(role: .assistant, text: String(repeating: "x", count: 9_000), date: Self.now)
        // 요약 요청도 한도 안에 들어가야 하므로 앞의 짧은 주고받기부터 나눠 요약하고, 다음에 긴 답을 요약한다.
        guard case .summarize(let first) = ChatPlanner.plan(c, question: "q", baseSystem: "b", limit: 8_000) else {
            Issue.record("expected summarize"); return
        }
        #expect(first == 2)
        c.summary = ChatSummary(text: "요약", coveredCount: first)
        guard case .summarize(let second) = ChatPlanner.plan(c, question: "q", baseSystem: "b", limit: 8_000) else {
            Issue.record("expected second summarize"); return
        }
        #expect(second == 4)
        c.summary = ChatSummary(text: "요약", coveredCount: second)
        guard case .send(_, let turns) = ChatPlanner.plan(c, question: "q", baseSystem: "b", limit: 8_000) else {
            Issue.record("expected send"); return
        }
        #expect(turns.map(\.content) == ["q"])
    }

    @Test func questionAloneTooLongIsRefusedBeforeSending() async {
        let client = FakeChat { _, _ in FakeChat.text("x") }
        let service = ChatService(client: client)
        let question = String(repeating: "q", count: ChatPlanner.inputLimit)
        await #expect(throws: ChatError.questionTooLong) {
            _ = try await service.respond(to: question, in: Self.conversation(pairs: 0), ratingsAllowed: true) { _, _ in }
        }
        #expect(client.purposes.isEmpty)
    }

    // MARK: 요약 실패·잔액 부족

    /// 대화는 앱 언어로 강제하지 않는다. 답변 언어는 지침의 마지막 한 줄(사용자가 쓴 언어)로만 정한다.
    @Test func chatAndSummaryAreNotForcedToAppLanguage() async throws {
        #expect(ChatService.system.hasSuffix("Reply in the language the user writes in."))
        #expect(!ChatService.system.contains("OUTPUT LANGUAGE"))

        let fake = FakeChat { purpose, _ in FakeChat.text(purpose == .summary ? "요약" : "답") }
        let big = String(repeating: "가", count: 20_000)
        var c = Self.conversation(pairs: 0)
        for i in 0..<6 {
            c.messages.append(ChatMessage(role: .user, text: "q\(i)" + big, date: Self.now))
            c.messages.append(ChatMessage(role: .assistant, text: "a\(i)", date: Self.now))
        }
        _ = try await ChatService(client: fake).respond(to: "질문", in: c, ratingsAllowed: true) { _, _ in }
        #expect(fake.purposes.first == .summary && fake.purposes.last == .chat)
        #expect(fake.systems.first == ChatService.summarySystem)
        #expect(fake.systems.last?.hasPrefix(ChatService.system) == true)
        #expect(fake.systems.allSatisfy { !$0.contains("OUTPUT LANGUAGE") })
    }

    @Test func summaryIsKeptWhenReplyIsRefusedAndReusedNextTime() async throws {
        let limited = AIUsageLimit(reason: .tooLarge, resetAt: Self.now, subscribed: false, share: 0.9)
        let refuse = FakeChat { purpose, _ in
            if purpose == .summary { return FakeChat.text("합친 요약") }
            throw CityLLMError.usageLimit(limited)
        }
        let big = String(repeating: "가", count: 20_000)
        var c = Self.conversation(pairs: 0)
        for i in 0..<6 {
            c.messages.append(ChatMessage(role: .user, text: "q\(i)" + big, date: Self.now))
            c.messages.append(ChatMessage(role: .assistant, text: "a\(i)", date: Self.now))
        }
        let saved = Saved()
        await #expect(throws: CityLLMError.usageLimit(limited)) {
            _ = try await ChatService(client: refuse).respond(to: "질문", in: c, ratingsAllowed: true) { conversation, _ in saved.add(conversation) }
        }
        let withSummary = try #require(saved.all.last)
        #expect(withSummary.summary?.text == "합친 요약")
        #expect(withSummary.messages == c.messages)

        let answer = FakeChat { _, _ in FakeChat.text("답") }
        let done = try await ChatService(client: answer).respond(to: "질문", in: withSummary, ratingsAllowed: true) { _, _ in }
        #expect(answer.purposes == [.chat])
        #expect(done.messages.suffix(2).map(\.text) == ["질문", "답"])
    }

    @Test func failedSummaryLeavesConversationUntouched() async {
        let failing = FakeChat { _, _ in throw CityLLMError.http(502) }
        let c = Self.conversation(pairs: 6, length: 20_000)
        let saved = Saved()
        await #expect(throws: CityLLMError.http(502)) {
            _ = try await ChatService(client: failing).respond(to: "질문", in: c, ratingsAllowed: true) { conversation, _ in saved.add(conversation) }
        }
        #expect(failing.purposes == [.summary])
        #expect(saved.all.isEmpty)
    }

    @Test func answerAppendsBothMessagesAndTitle() async throws {
        let usage = AIUsage(share: 0.2, resetAt: Self.now, subscribed: true)
        let client = FakeChat { _, turns in
            #expect(turns.map(\.content) == ["교토 가을 어때?\n둘째 줄"])
            return FakeChat.text("좋아요", usage: usage)
        }
        let received = Mutex<AIUsage?>(nil)
        let done = try await ChatService(client: client).respond(
            to: "교토 가을 어때?\n둘째 줄", in: Self.conversation(pairs: 0), ratingsAllowed: true, now: Self.now
        ) { _, u in received.withLock { $0 = u } }
        #expect(done.title == "교토 가을 어때?")
        #expect(done.messages.map(\.role) == [.user, .assistant])
        #expect(received.withLock { $0 } == usage)
    }

    // MARK: 맥락과 평가 전송

    @Test func contextLeavesOutTripsAndRatingsWhenNotAllowed() throws {
        let trip = try CityMemoryAndTwoStageTests.trip(city: "교토", rating: 5, liked: "골목", evaluatedAt: Self.now)
        var tiers = WantedConceptTiers()
        tiers.place(.food, in: 1)
        let off = ChatContextBuilder.build(tab: .trips, trips: [trip], tiers: tiers, saved: [], ratingsAllowed: false, now: Self.now)
        #expect(!off.text.contains("교토") && !off.text.contains("골목"))
        #expect(off.text.contains("여행 탭") && off.text.contains("1티어"))
        #expect(!off.includesRatings)

        let on = ChatContextBuilder.build(tab: .recommendation, trips: [trip], tiers: nil, saved: [], ratingsAllowed: true, now: Self.now)
        #expect(on.text.contains("교토") && on.text.contains("<<<골목>>>") && on.text.contains("추천 탭"))
        #expect(on.includesRatings)
    }

    @Test func turningRatingsOffBlocksConversationsThatHaveThem() async {
        let c = Self.conversation(pairs: 1, includesRatings: true)
        #expect(!c.canContinue(ratingsAllowed: false))
        #expect(c.canContinue(ratingsAllowed: true))
        #expect(Self.conversation(pairs: 1).canContinue(ratingsAllowed: false))
        let client = FakeChat { _, _ in FakeChat.text("x") }
        await #expect(throws: ChatError.readOnly) {
            _ = try await ChatService(client: client).respond(to: "q", in: c, ratingsAllowed: false) { _, _ in }
        }
        #expect(client.purposes.isEmpty)
    }

    // MARK: 한도 안내와 프록시 계약

    @Test func usageLimitMessagesDifferForFreeAndSubscribers() {
        let free = AIUsageLimit(reason: .exhausted, resetAt: Self.now, subscribed: false, share: 1)
        let sub = AIUsageLimit(reason: .exhausted, resetAt: Self.now, subscribed: true, share: 1)
        let large = AIUsageLimit(reason: .tooLarge, resetAt: Self.now, subscribed: false, share: 0.5)
        #expect(free.message != sub.message)
        #expect(large.message != free.message && large.message != sub.message)
    }

    @Test func proxyDecodesChatLimitAndUsage() throws {
        let response = HTTPURLResponse(url: URL(string: "https://x.example")!, statusCode: 429, httpVersion: nil, headerFields: nil)!
        let body = Data(#"{"error":"quota","kind":"chat","reason":"tooLarge","resetAt":1800000000,"subscribed":true,"share":0.7}"#.utf8)
        #expect(throws: CityLLMError.usageLimit(AIUsageLimit(reason: .tooLarge, resetAt: Self.now, subscribed: true, share: 0.7))) {
            try CityLLMProxyClient.check(response, body)
        }
        let ok = Data(#"{"content":[{"type":"text","text":"hi"}],"stop_reason":"end_turn","usage":{"share":0.25,"resetAt":1800000000,"subscribed":false}}"#.utf8)
        let reply = try JSONDecoder().decode(ChatReply.self, from: ok)
        #expect(reply.usage == AIUsage(share: 0.25, resetAt: Self.now, subscribed: false))
        #expect(reply.reply.content.first?.text == "hi")
    }

    @Test func chatBodyMatchesServerContract() {
        let body = CityLLMProxyClient.chatBody(
            model: "m", system: "s", turns: [ChatTurn(role: .user, content: "u")], purpose: .summary, searchUses: nil, requestID: "req-1234"
        )
        #expect(body["purpose"] as? String == "summary")
        #expect(body["requestId"] as? String == "req-1234")
        #expect(body["webSearchMaxUses"] == nil)
        #expect((body["messages"] as? [[String: String]]) == [["role": "user", "content": "u"]])
    }
}

/// 답 본문을 제목·목록·표·문단으로 나누는 규칙. 표로 볼 수 없는 줄은 원문 그대로 문단에 남아야 한다.
struct AnswerBlockParserTests {
    /// 범위를 쓴 물결표 두 개가 취소선이 되지 않는다(TestFlight에서 본 "25~50달러, 중급 호텔은 60~120달러").
    @Test func tildeRangesStayPlainButBoldStillWorks() {
        let text = "저가 호텔은 25~50달러, 중급 호텔은 60~120달러, **카오산**이 싸요. ~~취소~~"
        let result = AIAnswerView.inline(text)
        #expect(String(result.characters) == "저가 호텔은 25~50달러, 중급 호텔은 60~120달러, 카오산이 싸요. ~~취소~~")
        #expect(!result.runs.contains { $0.inlinePresentationIntent?.contains(.strikethrough) == true })
        #expect(result.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
    }

    /// 문장부호로 끝난 굵은 글씨 뒤에 조사가 붙어도 굵게 보이고 `**`가 남지 않는다(실험 답변 945줄 중 23줄이 이랬다).
    @Test func boldBeforeKoreanParticleAfterPunctuation() {
        let text = "**페낭(말레이시아)**이나 **하노이**를, 기간은 **11월 21일(토)~11월 30일(월)**입니다. 짝 없는 ** 별표"
        let result = AIAnswerView.inline(text)
        #expect(String(result.characters) == "페낭(말레이시아)이나 하노이를, 기간은 11월 21일(토)~11월 30일(월)입니다. 짝 없는 ** 별표")
        let bold = result.runs.filter { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }
            .map { String(result[$0.range].characters) }
        #expect(bold == ["페낭(말레이시아)", "하노이", "11월 21일(토)~11월 30일(월)"])
        #expect(!result.runs.contains { $0.inlinePresentationIntent?.contains(.strikethrough) == true })
    }

    @Test func headingsBulletsAndParagraphs() {
        let blocks = AnswerBlockParser.parse("## 결론\n**누사두아**가 맞아요.\n둘째 줄\n\n- 해변이 잔잔해요\n* 리조트가 많아요\n#태그는 제목이 아님")
        #expect(blocks == [
            .heading("결론"),
            .paragraph("**누사두아**가 맞아요.\n둘째 줄"),
            .bullet("해변이 잔잔해요"),
            .bullet("리조트가 많아요"),
            .paragraph("#태그는 제목이 아님"),
        ])
    }

    @Test func validTablePadsShortRowsAndKeepsEscapedPipe() {
        let text = "비교예요.\n| 기준 | 리스본 | 포르투 |\n| --- | :---: | ---: |\n| 날씨 | 온화 | 비 \\| 바람 |\n| 음식 | 해산물 |\n끝."
        #expect(AnswerBlockParser.parse(text) == [
            .paragraph("비교예요."),
            .table(header: ["기준", "리스본", "포르투"], rows: [["날씨", "온화", "비 | 바람"], ["음식", "해산물", ""]]),
            .paragraph("끝."),
        ])
    }

    @Test func brokenTablesStayAsText() {
        // 구분 줄 없음, 구분 줄 열 수 불일치, 칸을 나눈 문장
        for text in ["| 도시 | 날씨 |\n| 리스본 | 맑음 |", "| 도시 | 날씨 |\n| --- |\n| 리스본 | 맑음 |", "리스본 | 포르투 중에 골라요"] {
            #expect(AnswerBlockParser.parse(text) == [.paragraph(text)], "\(text)")
        }
    }

    @Test func rowWithExtraCellsEndsTableAndStaysAsText() {
        let blocks = AnswerBlockParser.parse("| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 | 5 |")
        #expect(blocks == [.table(header: ["a", "b"], rows: [["1", "2"]]), .paragraph("| 3 | 4 | 5 |")])
    }
}
