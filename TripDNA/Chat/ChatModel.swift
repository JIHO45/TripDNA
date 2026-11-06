import Foundation

/// AI 대화 전송 동의. 대화는 추천·도시 질문보다 보내는 정보가 많아서(대화 내용, 저장한 도시, 여행 기록) 처음 한 번 따로 묻는다.
/// 지난 여행 평가를 보낼지는 추천과 같은 설정(`CityMemoryConsent`)을 쓴다.
nonisolated enum ChatConsent {
    static let key = "tripdna.chatConsent"

    static var given: Bool {
        get { AppStorageLocation.defaults.bool(forKey: key) }
        set { AppStorageLocation.defaults.set(newValue, forKey: key) }
    }

    static func reset() { AppStorageLocation.defaults.removeObject(forKey: key) }

    // 처리방침 4·7절과 맞춘다.
    static var alwaysSent: String { String(localized: "Your chat messages, how many past trips had each concept, the trip types you want and want to avoid, and your saved cities") }
    static var sentIfGranted: String { String(localized: "Your trip list (places, dates, concepts, satisfaction), plus star ratings and notes from up to 10 recent trip reviews (up to 500 characters per note)") }
    static var summaryNote: String { String(localized: "When a conversation gets long, its earlier part is sent once more to be summarized. Conversations are stored only on this device and in your iCloud backup.") }
}

/// AI 대화 화면의 상태. 버튼이 들고 있어서 화면을 닫아도 기다리던 답을 받아 저장한다.
@Observable
final class ChatModel {
    enum Status: Equatable {
        case idle
        case loading(question: String)
        case failed(question: String, message: String, canRetry: Bool)
    }

    let tab: ChatTab
    private(set) var state = ChatState()
    /// 열려 있는 대화. nil이면 새 대화(첫 질문을 보낼 때 그 시점의 정보로 맥락을 고정한다).
    var selectedID: UUID?
    private(set) var status = Status.idle
    var draft = ""
    var showsSubscription = false
    /// 동의 시트를 띄운다. 동의하면 이 질문을 보낸다.
    var pendingQuestion: String?
    /// 테스트가 가짜 LLM을 넣는다.
    @ObservationIgnored var makeClient: () -> (any ChatClient)? = { CityLLMConfiguration.makeSearchClient() }

    init(tab: ChatTab) { self.tab = tab }

    var selected: ChatConversation? { selectedID.flatMap { id in state.conversations.first { $0.id == id } } }
    var isLoading: Bool { if case .loading = status { true } else { false } }
    var ratingsAllowed: Bool { CityMemoryConsent.state == .granted }
    /// 지금 대화에 입력할 수 있는지. 평가가 담긴 대화는 평가 전송을 끄면 읽기만 한다.
    var canSendInSelected: Bool { selected?.canContinue(ratingsAllowed: ratingsAllowed) ?? true }

    func load(store: any AppStore) async {
        if let loaded = try? await store.loadChatState() { state = loaded }
    }

    func startNew() {
        guard !isLoading else { return }
        selectedID = nil
        status = .idle
    }

    func select(_ id: UUID) {
        guard !isLoading else { return }
        selectedID = id
        status = .idle
    }

    func delete(_ id: UUID, store: any AppStore) async {
        let generation = store.dataGeneration.current
        _ = try? await store.updateChatState(ifGeneration: generation) { $0.delete(id: id) }
        if selectedID == id { selectedID = nil }
        await load(store: store)
    }

    func deleteAll(store: any AppStore) async {
        let generation = store.dataGeneration.current
        _ = try? await store.updateChatState(ifGeneration: generation) { $0.conversations.removeAll() }
        selectedID = nil
        await load(store: store)
    }

    /// 동의 시트에서 고른 결과. 평가 전송 설정은 추천과 함께 쓴다.
    func answerConsent(includeReviews: Bool, dependencies: AppDependencies) {
        ChatConsent.given = true
        CityMemoryConsent.state = includeReviews ? .granted : .declined
        if let question = pendingQuestion {
            pendingQuestion = nil
            send(question, dependencies: dependencies)
        }
    }

    @discardableResult
    func send(_ raw: String, dependencies: AppDependencies) -> Task<Void, Never>? {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isLoading else { return nil }
        guard ChatConsent.given else {
            pendingQuestion = question
            return nil
        }
        guard let client = makeClient() else {
            status = .failed(question: question, message: String(localized: "The AI connection isn't set up yet. A proxy URL (CityLLMProxyURL) or a development key is required."), canRetry: false)
            return nil
        }
        status = .loading(question: question)
        if draft.trimmingCharacters(in: .whitespacesAndNewlines) == question { draft = "" }
        let store = dependencies.store
        let generation = store.dataGeneration.current
        let ratingsAllowed = ratingsAllowed
        let existing = selected
        let tab = tab
        return Task {
            do {
                let conversation: ChatConversation
                if let existing {
                    conversation = existing
                } else {
                    let now = Date()
                    let context = ChatContextBuilder.build(
                        tab: tab, trips: await dependencies.allTrips(),
                        tiers: try? await store.loadWantedTiers(),
                        saved: (try? await store.cityState().saved) ?? [],
                        ratingsAllowed: ratingsAllowed, now: now
                    )
                    conversation = ChatService.newConversation(tab: tab, context: context, now: now)
                }
                let done = try await ChatService(client: client).respond(to: question, in: conversation, ratingsAllowed: ratingsAllowed) { updated, usage in
                    let saved = try await store.updateChatState(ifGeneration: generation) {
                        $0.upsert(updated)
                        if let usage { $0.usage = usage }
                    }
                    if !saved { throw ChatError.discarded }
                }
                await load(store: store)
                selectedID = done.id
                status = .idle
            } catch {
                // 요약만 저장된 경우도 화면에 반영한다.
                await load(store: store)
                status = failure(for: error, question: question)
            }
        }
    }

    private func failure(for error: Error, question: String) -> Status {
        switch error {
        case ChatError.discarded:
            return .idle
        case ChatError.questionTooLong:
            return .failed(question: question, message: String(localized: "This question is too long. Please shorten it."), canRetry: false)
        case ChatError.readOnly:
            return .failed(question: question, message: String(localized: "Sending trip ratings is off. Start a new conversation."), canRetry: false)
        case CityLLMError.usageLimit(let limit):
            showsSubscription = limit.offersSubscription
            if let share = limit.share { state.usage = AIUsage(share: share, resetAt: limit.resetAt, subscribed: limit.subscribed) }
            return .failed(question: question, message: limit.message, canRetry: false)
        case CityLLMError.quotaExceeded(let resetAt):
            // 새 서버를 배포하기 전의 횟수 한도 응답.
            return .failed(question: question, message: CityLLMProxyClient.quotaMessage(String(localized: "questions"), resetAt: resetAt), canRetry: false)
        default:
            return .failed(question: question, message: String(localized: "Couldn't get an answer. Please try again."), canRetry: true)
        }
    }
}
