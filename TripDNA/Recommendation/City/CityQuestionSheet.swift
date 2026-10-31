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

    var isLoading: Bool { if case .loading = status { true } else { false } }

    func load(cityID: String, store: any AppStore) async {
        entries = (try? await store.cityState().questions[cityID]) ?? []
    }

    /// 질문은 이전 기록 없이 따로 보낸다(LLM에 지난 질문·답을 붙이지 않는다).
    func ask(_ raw: String, card: CityRecommendationRecord.Card, request: RecommendationRequest?, summary: String, store: any AppStore) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        guard let catalog = CityCatalog.load() else {
            status = .failed(question: text, message: "도시 자료를 읽지 못했어요.")
            return
        }
        status = .loading(question: text)
        if draft.trimmingCharacters(in: .whitespacesAndNewlines) == text { draft = "" }
        Task {
            let service = CityQuestionService(catalog: catalog, client: CityLLMConfiguration.makeSearchClient())
            do {
                let answer = try await service.ask(text, card: card, request: request, conditionSummary: summary)
                let entry = CityQuestionEntry(question: text, askedAt: Date(), conditionSummary: summary, answer: answer)
                entries.append(entry)
                status = .idle
                do {
                    try await store.updateCityState { $0.addQuestion(entry, cityID: card.cityID) }
                } catch {
                    status = .notSaved
                }
            } catch CityQuestionError.notConfigured {
                status = .failed(question: text, message: "LLM 연결이 아직 준비되지 않았어요. 프록시 주소(CityLLMProxyURL) 또는 개발용 키가 필요해요.")
            } catch {
                status = .failed(question: text, message: "답을 확인하지 못했어요. 다시 시도해 주세요.")
            }
        }
    }
}

/// "이 도시에 대해 묻기" 시트. 중간 높이로 열려 지난 질문을 먼저 보여주고, 입력칸을 누르면 전체 높이로 늘어난다.
/// 초안: 답의 세 부분 이름(자료 근거 / 조언 / 확인하지 못한 것)은 시안 ⓖ의 임시 문구다.
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
                            Text("아직 물어본 게 없어요. 날씨, 이동, 동행에게 맞는지처럼 궁금한 걸 물어보세요.")
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
            .navigationTitle("\(card.cityName)에 대해 묻기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
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
            Text("각 질문은 이전 대화 없이 답해요")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            HStack(spacing: DNASpacing.sm) {
                TextField("이 도시에 대해 물어보세요", text: $model.draft, axis: .vertical)
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
                .accessibilityLabel("질문 보내기")
            }
        }
        .padding(.horizontal, DNASpacing.lg)
        .padding(.vertical, DNASpacing.sm)
        .background(Color.dnaCanvas.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
    }

    private var conditionLine: String {
        let basis = isSavedBasis ? "저장할 때의 조건" : "이 추천의 조건"
        return summary.isEmpty ? "\(basis) 기준으로 답해요" : "\(basis) 기준으로 답해요: \(summary)"
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
                ProgressView("확인하고 있어요")
                Text("시트를 닫아도 답이 오면 여기에 남아요")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        case .notSaved:
            Text("답을 기기에 저장하지 못했어요. 상세 화면을 나가면 이 답은 사라져요.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaError)
        case .failed(let question, let message):
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                questionBubble(question)
                Text(message).dnaFont(.body).foregroundStyle(Color.dnaError)
                Button("다시 시도") { send(question) }.buttonStyle(.dnaSecondary)
            }
        }
    }

    private func entryView(_ entry: CityQuestionEntry) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            questionBubble(entry.question)
            Text(entry.conditionSummary.isEmpty
                 ? entry.askedAt.formatted(.dateTime.year().month().day())
                 : "\(entry.askedAt.formatted(.dateTime.year().month().day())) · \(entry.conditionSummary) 기준")
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

    @ViewBuilder
    private func answerView(_ answer: CityAnswer) -> some View {
        answerPart("자료 근거", answer.evidence)
        answerPart("조언", answer.advice)
        answerPart("확인하지 못한 것", answer.unconfirmed)
        if !answer.sources.isEmpty {
            VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                // 출처는 답 전체에 대한 것이다. 문장별로 어느 출처인지 연결하지 않으므로 본문에 번호를 달지 않는다.
                Text("검색에서 확인한 출처")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                ForEach(Array(answer.sources.enumerated()), id: \.offset) { index, source in
                    let published = source.published.map { "게시일 \($0)" } ?? "게시일 미확인"
                    Link(destination: source.url) {
                        Text("[\(index + 1)] \(source.title) · \(published) · \(source.retrievedAt.formatted(.dateTime.month().day())) 조회")
                            .dnaFont(.caption)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(Color.dnaActionText)
                }
            }
        }
    }

    @ViewBuilder
    private func answerPart(_ title: String, _ text: String) -> some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                Text(title).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
                Text(text).dnaFont(.body).foregroundStyle(Color.dnaTextPrimary)
            }
        }
    }
}
