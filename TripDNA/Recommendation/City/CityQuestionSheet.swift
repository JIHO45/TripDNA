import SwiftUI

/// 상세의 질문 기록과 진행 중인 요청. 시트가 아니라 상세가 들고 있어서 시트를 닫아도 기다리던 답을 받는다.
/// 요청은 화면 수명과 무관한 Task로 돌리므로 상세를 떠나도 끝나면 기기에 저장된다.
@Observable
final class CityQuestionModel {
    enum Status: Equatable {
        case idle
        case loading(question: String)
        case failed(question: String, message: String)
        /// 답은 받았지만 저장하지 못했다. 다시 보내면 한도를 또 쓰므로 다시 시도 버튼을 두지 않는다.
        case notSaved
    }

    private(set) var entries: [CityQuestionEntry] = []
    private(set) var status = Status.idle
    /// 시트를 닫았다 열어도 쓰던 질문이 남는다.
    var draft = ""
    /// 무료 한도를 다 쓴 사용자가 질문하면 구독 화면을 연다.
    var showsSubscription = false
    /// 테스트가 가짜 LLM을 넣는다.
    @ObservationIgnored var makeClient: () -> (any CitySearchClient)? = { CityLLMConfiguration.makeSearchClient() }

    var isLoading: Bool { if case .loading = status { true } else { false } }

    func load(cityID: String, store: any AppStore) async {
        entries = (try? await store.cityState().questions[cityID]) ?? []
    }

    /// 질문은 이전 기록 없이 따로 보낸다(LLM에 지난 질문·답을 붙이지 않는다).
    @discardableResult
    func ask(_ raw: String, card: CityRecommendationRecord.Card, request: RecommendationRequest?, summary: String, store: any AppStore) -> Task<Void, Never>? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return nil }
        guard let catalog = CityCatalog.load() else {
            status = .failed(question: text, message: String(localized: "Couldn't load the city data."))
            return nil
        }
        status = .loading(question: text)
        if draft.trimmingCharacters(in: .whitespacesAndNewlines) == text { draft = "" }
        let generation = store.dataGeneration.current
        return Task {
            let service = CityQuestionService(catalog: catalog, client: makeClient())
            do {
                let answer = try await service.ask(text, card: card, request: request, conditionSummary: summary)
                let entry = CityQuestionEntry(question: text, askedAt: Date(), conditionSummary: summary, answer: answer)
                do {
                    // 기다리는 사이 전체 삭제를 했으면 답을 버린다.
                    guard try await store.updateCityState(ifGeneration: generation, { $0.addQuestion(entry, cityID: card.cityID) }) else {
                        status = .idle
                        return
                    }
                    entries.append(entry)
                    status = .idle
                } catch {
                    entries.append(entry)
                    status = .notSaved
                }
            } catch CityQuestionError.notConfigured {
                status = .failed(question: text, message: String(localized: "The AI connection isn't set up yet. A proxy URL (CityLLMProxyURL) or a development key is required."))
            } catch CityLLMError.usageLimit(let limit) {
                status = .failed(question: text, message: limit.message)
                showsSubscription = limit.offersSubscription
            } catch CityLLMError.quotaExceeded(let resetAt) {
                // 새 서버를 배포하기 전의 횟수 한도 응답.
                let subscribed = await Subscription.isActive()
                status = .failed(question: text, message: CityLLMProxyClient.quotaMessage(String(localized: "questions"), resetAt: resetAt, subscribed: subscribed))
                showsSubscription = !subscribed
            } catch {
                status = .failed(question: text, message: String(localized: "Couldn't get an answer. Please try again."))
            }
        }
    }
}

/// "이 도시에 대해 묻기" 시트. 중간 높이로 열려 지난 질문을 먼저 보여주고, 입력칸을 누르면 전체 높이로 늘어난다.
struct CityQuestionSheet: View {
    @Bindable var model: CityQuestionModel
    let card: CityRecommendationRecord.Card
    let request: RecommendationRequest?
    let summary: String
    /// 저장한 도시에서 열었으면 저장 당시 조건 기준이다.
    let isSavedBasis: Bool
    @Binding var detent: PresentationDetent
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    private static let bottomID = "bottom"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DNASpacing.lg) {
                        if model.entries.isEmpty && model.status == .idle {
                            Text("Nothing asked yet. Ask about things like weather, getting around, or whether it suits your travel companions.")
                                .dnaFont(.body)
                                .foregroundStyle(Color.dnaTextSecondary)
                        }
                        ForEach(model.entries) { entry in
                            entryView(entry)
                        }
                        statusView
                        Color.clear.frame(height: 1).id(Self.bottomID)
                    }
                    .padding(DNASpacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                .onChange(of: model.entries.count) { _, _ in
                    withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                }
                .onChange(of: model.status) { _, _ in
                    withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                }
            }
            .safeAreaInset(edge: .bottom) { inputBar }
            .dnaBackground()
            .navigationTitle("Ask About \(card.cityName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $model.showsSubscription) { SubscriptionView() }
        // 입력을 시작하면 키보드와 기록이 함께 보이게 전체 높이로 늘린다.
        .onChange(of: focused) { _, isFocused in
            if isFocused { detent = .large }
        }
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text(conditionLine)
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            Text("Each question is answered without earlier conversation")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            HStack(spacing: DNASpacing.sm) {
                TextField("Ask about this city", text: $model.draft, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(.horizontal, DNASpacing.md)
                    .frame(minHeight: 44)
                    .background(Color.dnaSurface1, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.dnaDivider, lineWidth: 1))
                    .focused($focused)
                Button { send(model.draft) } label: {
                    Image(systemName: "arrow.up")
                        .dnaFont(size: 16, weight: .bold)
                        .foregroundStyle(Color.dnaSelectedForeground)
                        .frame(width: 44, height: 44)
                        .background(Color.dnaSelectedBackground, in: Circle())
                }
                .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isLoading)
                .accessibilityLabel("Send question")
            }
        }
        .padding(.horizontal, DNASpacing.lg)
        .padding(.vertical, DNASpacing.sm)
        .background(Color.dnaCanvas.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
    }

    private var conditionLine: String {
        switch (isSavedBasis, summary.isEmpty) {
        case (true, true): String(localized: "Answering based on the conditions when you saved this")
        case (true, false): String(localized: "Answering based on the conditions when you saved this: \(summary)")
        case (false, true): String(localized: "Answering based on this recommendation's conditions")
        case (false, false): String(localized: "Answering based on this recommendation's conditions: \(summary)")
        }
    }

    private func send(_ text: String) {
        model.ask(text, card: card, request: request, summary: summary, store: dependencies.store)
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.status {
        case .idle:
            EmptyView()
        case .loading(let question):
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                questionBubble(question)
                AnswerLoadingText()
                Text("Even if you close this sheet, the answer will stay here")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        case .notSaved:
            Text("Couldn't save the answer to this device. It will disappear when you leave the details screen.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaError)
        case .failed(let question, let message):
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                questionBubble(question)
                Text(message).dnaFont(.body).foregroundStyle(Color.dnaError)
                Button("Try Again") { send(question) }.buttonStyle(.dnaSecondary)
            }
        }
    }

    private func entryView(_ entry: CityQuestionEntry) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            questionBubble(entry.question)
            Text(entry.conditionSummary.isEmpty
                 ? entry.askedAt.formatted(.dateTime.year().month().day())
                 : String(localized: "\(entry.askedAt.formatted(.dateTime.year().month().day())) · \(entry.conditionSummary) basis"))
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            answerView(entry.answer)
        }
    }

    private func questionBubble(_ text: String) -> some View {
        Text(text)
            .dnaFont(.cardTitle)
            .foregroundStyle(Color.dnaTextPrimary)
            .padding(.horizontal, DNASpacing.md)
            .padding(.vertical, DNASpacing.sm)
            .background(Color.dnaSurface2, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }

    private func answerView(_ answer: CityAnswer) -> some View {
        AIAnswerView(text: answer.text, sources: answer.sources)
    }
}
