import Foundation

/// 대화를 시작한 탭. 맥락의 강조점과 목록 필터에 쓴다.
nonisolated enum ChatTab: String, Codable, Sendable {
    case recommendation
    case trips
}

/// 대화 한 줄. 원문은 기기에 계속 남긴다(요약해도 화면은 전체 대화를 보여준다).
nonisolated struct ChatMessage: Codable, Equatable, Sendable, Identifiable {
    var id = UUID()
    let role: ChatTurn.Role
    let text: String
    var sources: [CityAnswer.Source] = []
    let date: Date
}

/// 대화를 시작할 때 고정한, AI가 아는 사용자 정보. 나중에 여행을 바꿔도 이 대화에는 반영되지 않는다.
nonisolated struct ChatContextSnapshot: Codable, Equatable, Sendable {
    let text: String
    let builtAt: Date
    /// 지난 여행 평가(별점·메모·다녀온 도시)가 들어 있는지. 전송을 끄면 이 대화는 이어갈 수 없다.
    let includesRatings: Bool
}

/// 오래된 대화의 요약. `messages[..<coveredCount]`가 이 요약에 들어 있다.
nonisolated struct ChatSummary: Codable, Equatable, Sendable {
    let text: String
    let coveredCount: Int
}

nonisolated struct ChatConversation: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let tab: ChatTab
    var title: String
    let createdAt: Date
    var updatedAt: Date
    let context: ChatContextSnapshot
    var messages: [ChatMessage] = []
    var summary: ChatSummary?

    /// 지금의 평가 전송 설정으로 이 대화를 이어갈 수 있는지. 평가가 담긴 대화는 전송을 끄면 읽기만 한다.
    func canContinue(ratingsAllowed: Bool) -> Bool { ratingsAllowed || !context.includesRatings }
}

nonisolated struct ChatState: Codable, Equatable, Sendable {
    /// 최근에 바뀐 것이 앞.
    var conversations: [ChatConversation] = []
    /// 마지막으로 받은 AI 사용량. 화면의 게이지가 쓴다.
    var usage: AIUsage?

    mutating func upsert(_ conversation: ChatConversation) {
        conversations.removeAll { $0.id == conversation.id }
        conversations.insert(conversation, at: 0)
    }

    mutating func delete(id: UUID) { conversations.removeAll { $0.id == id } }
}

extension AppStore {
    /// 응답을 기다린 작업의 결과를 저장한다. 작업을 시작한 뒤 전체 삭제가 있었으면 저장하지 않고 false.
    @discardableResult
    func updateChatState(ifGeneration generation: Int, _ change: (inout ChatState) -> Void) async throws -> Bool {
        var state = try await loadChatState()
        change(&state)
        return try await saveChatState(state, ifGeneration: generation)
    }
}
