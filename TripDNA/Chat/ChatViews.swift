import SwiftUI

// MARK: - 답 표시(도시 질문과 대화가 같이 쓴다)

/// 답 본문의 덩어리. 제목·목록·표만 따로 그리고 나머지는 인라인 서식 문단이다.
nonisolated enum AnswerBlock: Equatable {
    case paragraph(String)
    case heading(String)
    case bullet(String)
    case table(header: [String], rows: [[String]])
}

/// 모델이 쓰는 가벼운 마크다운을 줄 단위로 나눈다. 표는 머리 줄 바로 다음에 같은 열 수의 구분 줄(`| --- |`)이 있을 때만 표로 본다.
/// 표로 볼 수 없는 줄(구분 줄 없음, 열 수가 머리보다 많은 줄)은 원문 그대로 문단에 남긴다.
nonisolated enum AnswerBlockParser {
    static func parse(_ text: String) -> [AnswerBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [AnswerBlock] = []
        var paragraph: [String] = []
        func flush() {
            let joined = paragraph.joined(separator: "\n").trimmingCharacters(in: .newlines)
            if !joined.trimmingCharacters(in: .whitespaces).isEmpty { blocks.append(.paragraph(joined)) }
            paragraph = []
        }
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if let table = table(at: i, in: lines) {
                flush()
                blocks.append(.table(header: table.header, rows: table.rows))
                i = table.end
                continue
            }
            if let match = line.wholeMatch(of: #/\s{0,3}#{1,6}\s+(.+?)[\s#]*/#) {
                flush()
                blocks.append(.heading(String(match.1)))
            } else if let match = line.wholeMatch(of: #/\s*[-*•]\s+(.+)/#) {
                flush()
                blocks.append(.bullet(String(match.1)))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                flush()
            } else {
                paragraph.append(line)
            }
            i += 1
        }
        flush()
        return blocks
    }

    /// `start`에서 시작하는 표. 본문 줄은 `|`가 있는 줄이 끝날 때까지다. 열이 모자란 줄은 빈칸으로 채운다.
    private static func table(at start: Int, in lines: [String]) -> (header: [String], rows: [[String]], end: Int)? {
        guard start + 1 < lines.count, let header = cells(lines[start]), header.count >= 2,
              let separator = cells(lines[start + 1]), separator.count == header.count,
              separator.allSatisfy({ $0.wholeMatch(of: #/:?-+:?/#) != nil }) else { return nil }
        var rows: [[String]] = []
        var end = start + 2
        while end < lines.count, let row = cells(lines[end]) {
            // 머리보다 열이 많으면 잘라 버리지 않고 표를 거기서 끝낸다(그 줄은 문단으로 보인다).
            guard row.count <= header.count else { break }
            rows.append(row + Array(repeating: "", count: header.count - row.count))
            end += 1
        }
        return (header, rows, end)
    }

    /// `|`로 나눈 칸. 앞뒤의 `|`는 떼고 `\|`는 글자로 둔다. `|`가 없는 줄은 nil.
    static func cells(_ line: String) -> [String]? {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return nil }
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") && !trimmed.hasSuffix("\\|") { trimmed.removeLast() }
        let placeholder = "\u{0}"
        return trimmed.replacingOccurrences(of: "\\|", with: placeholder)
            .components(separatedBy: "|")
            .map { $0.replacingOccurrences(of: placeholder, with: "|").trimmingCharacters(in: .whitespaces) }
    }
}

/// LLM 답 본문(가벼운 마크다운)과 그 아래 검색 출처.
struct AIAnswerView: View {
    let text: String
    let sources: [CityAnswer.Source]
    /// 표 한 칸의 최대 폭. 넘으면 칸 안에서 줄을 바꾼다.
    @ScaledMetric(relativeTo: .subheadline) private var cellWidth: CGFloat = 200

    /// 굵게·기울임·링크만 살린다.
    /// - `**…**`는 직접 굵게 만든다. 마크다운 규칙으로는 "**페낭(말레이시아)**이나"처럼 문장부호 뒤에 조사가 붙으면 굵게가 안 되고 `**`가 보인다.
    /// - `~`는 글자 그대로 둔다: "25~50달러, 60~120달러"처럼 범위를 쓴 두 물결표 사이가 취소선이 되지 않게.
    static func inline(_ text: String) -> AttributedString {
        var result = AttributedString()
        var rest = Substring(text)
        while let match = rest.firstMatch(of: #/\*\*(.+?)\*\*/#) {
            result += markdown(rest[..<match.range.lowerBound])
            var bold = markdown(match.1)
            for run in bold.runs {
                bold[run.range].inlinePresentationIntent = (run.inlinePresentationIntent ?? []).union(.stronglyEmphasized)
            }
            result += bold
            rest = rest[match.range.upperBound...]
        }
        return result + markdown(rest)
    }

    private static func markdown(_ text: Substring) -> AttributedString {
        let escaped = text.replacingOccurrences(of: "~", with: "\\~")
        return (try? AttributedString(markdown: escaped, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                ForEach(Array(AnswerBlockParser.parse(text).enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .dnaFont(.body)
            .foregroundStyle(Color.dnaTextPrimary)
            .textSelection(.enabled)
            if !sources.isEmpty {
                VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                    // 출처는 답 전체에 대한 것이다. 문장별로 어느 출처인지 연결하지 않으므로 본문에 번호를 달지 않는다.
                    Text("Sources found in search")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    ForEach(Array(sources.enumerated()), id: \.offset) { index, source in
                        let published = source.published.map { String(localized: "Published \($0)") } ?? String(localized: "Publication date unknown")
                        Link(destination: source.url) {
                            Text(String(localized: "[\(index + 1)] \(source.title) · \(published) · retrieved \(source.retrievedAt.formatted(.dateTime.month().day()))"))
                                .dnaFont(.caption)
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundStyle(Color.dnaActionText)
                    }
                }
            }
        }
    }

    @ViewBuilder private func blockView(_ block: AnswerBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(Self.inline(text))
        case .heading(let text):
            Text(Self.inline(text)).dnaFont(.sectionTitle).padding(.top, DNASpacing.xxs)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: DNASpacing.xs) {
                Text(verbatim: "•")
                Text(Self.inline(text))
            }
        case .table(let header, let rows):
            // 열이 많거나 칸이 넓어도 읽을 수 있게 가로로 넘긴다.
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: DNASpacing.sm, verticalSpacing: DNASpacing.xs) {
                    GridRow {
                        ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                            CappedWidth(cap: cellWidth) { Text(Self.inline(cell)).dnaFont(.cardTitle) }
                        }
                    }
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Divider().overlay(Color.dnaDivider)
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                CappedWidth(cap: cellWidth) { Text(Self.inline(cell)) }
                            }
                        }
                    }
                }
                .padding(.vertical, DNASpacing.xxs)
            }
            .scrollIndicators(.automatic)
        }
    }
}

/// 자식을 원래 폭과 `cap` 중 작은 폭으로 둔다. 가로 스크롤 안에서는 글이 한 줄로 끝없이 늘어나므로, 넘치는 칸만 줄을 바꾸게 한다.
private struct CappedWidth: Layout {
    let cap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let width = min(child.sizeThatFits(.unspecified).width, cap)
        return child.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}

// MARK: - 떠 있는 버튼

extension View {
    /// 탭 첫 화면 아래 오른쪽의 AI 대화 버튼. 다른 화면으로 들어가면 함께 사라진다.
    func aiChatButton(tab: ChatTab) -> some View { modifier(AIChatButtonModifier(tab: tab)) }
}

private struct AIChatButtonModifier: ViewModifier {
    let tab: ChatTab
    /// 버튼이 들고 있어서 대화 화면을 닫아도 기다리던 답을 받아 저장한다.
    @State private var model: ChatModel
    @State private var showing = false

    init(tab: ChatTab) {
        self.tab = tab
        _model = State(initialValue: ChatModel(tab: tab))
    }

    func body(content: Content) -> some View {
        content
            // 안쪽 여백으로 두어 스크롤 끝의 내용이 버튼에 가리지 않게 한다.
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                Button { showing = true } label: {
                    Image(systemName: "sparkles")
                        .dnaFont(size: 20, weight: .bold)
                        .foregroundStyle(Color.dnaSelectedForeground)
                        .frame(width: 56, height: 56)
                        .background(Color.dnaSelectedBackground, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .padding(.trailing, DNASpacing.gutter)
                .padding(.bottom, DNASpacing.xs)
                .accessibilityLabel("Ask AI")
            }
            .fullScreenCover(isPresented: $showing) {
                ChatView(model: model)
            }
    }
}

// MARK: - 대화 화면

/// 대화 목록 | 대화. 아이폰에서는 한 줄로 접혀 대화가 먼저 보이고, 왼쪽 위 버튼으로 목록을 연다.
struct ChatView: View {
    @Bindable var model: ChatModel
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var column = NavigationSplitViewColumn.detail
    @State private var confirmingDeleteAll = false

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $column) {
            list
        } detail: {
            ChatConversationView(model: model, close: { dismiss() }, startNew: startNew)
        }
        .task { await model.load(store: dependencies.store) }
        .sheet(isPresented: $model.showsSubscription) { SubscriptionView() }
        .sheet(isPresented: Binding(get: { model.pendingQuestion != nil }, set: { if !$0 { model.pendingQuestion = nil } })) {
            ChatConsentSheet(model: model)
        }
    }

    private func startNew() {
        model.startNew()
        column = .detail
    }

    private var list: some View {
        List {
            Section {
                usageGauge
            }
            Section {
                ForEach(model.state.conversations) { conversation in
                    Button {
                        model.select(conversation.id)
                        column = .detail
                    } label: {
                        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                            Text(conversation.title.isEmpty ? String(localized: "New Conversation") : conversation.title)
                                .dnaFont(.cardTitle)
                                .foregroundStyle(Color.dnaTextPrimary)
                                .lineLimit(1)
                            Text("\(conversation.tab == .recommendation ? String(localized: "Recommendations") : String(localized: "Trips")) · \(conversation.updatedAt.formatted(.dateTime.month().day()))")
                                .dnaFont(.caption)
                                .foregroundStyle(Color.dnaTextSecondary)
                        }
                    }
                    .listRowBackground(conversation.id == model.selectedID ? Color.dnaSurface2 : nil)
                }
                .onDelete { offsets in
                    let ids = offsets.map { model.state.conversations[$0].id }
                    Task { for id in ids { await model.delete(id, store: dependencies.store) } }
                }
            } footer: {
                if model.state.conversations.isEmpty {
                    Text("No conversations yet.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .dnaBackground()
        .navigationTitle("AI Conversations")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("New Conversation", systemImage: "square.and.pencil", action: startNew)
                    Button("Delete All Conversations", systemImage: "trash", role: .destructive) { confirmingDeleteAll = true }
                        .disabled(model.state.conversations.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .confirmationDialog("Delete all conversations?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                Task { await model.deleteAll(store: dependencies.store) }
            }
        } message: {
            Text("They're removed from this device and your iCloud backup. This can't be undone.")
        }
    }

    /// 서버가 마지막으로 알려준 사용량. 한 번도 쓰지 않았으면 비어 있다.
    @ViewBuilder
    private var usageGauge: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            if let usage = model.state.usage {
                HStack {
                    Text(usage.subscribed ? "This Period's AI Usage" : "This Month's AI Usage")
                    Spacer()
                    Text(usage.share.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit()
                }
                .dnaFont(.cardTitle)
                ProgressView(value: min(1, max(0, usage.share)))
                    .tint(usage.share >= 0.9 ? Color.dnaError : Color.dnaActionText)
                Text("Refills on \(usage.resetAt.formatted(.dateTime.month().day().hour().minute())). As of your last AI answer.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            } else {
                Text("This Month's AI Usage")
                    .dnaFont(.cardTitle)
                Text("Shown after your first answer. Long conversations and web searches use more.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
        .padding(.vertical, DNASpacing.xxs)
    }
}

/// 대화 한 개. 위에 이 대화가 아는 정보의 기준 날짜, 아래에 입력칸.
private struct ChatConversationView: View {
    @Bindable var model: ChatModel
    let close: () -> Void
    let startNew: () -> Void
    @Environment(AppDependencies.self) private var dependencies
    @FocusState private var focused: Bool

    private static let bottomID = "bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DNASpacing.lg) {
                    header
                    ForEach(model.selected?.messages ?? []) { message in
                        if message.role == .user {
                            bubble(message.text)
                        } else {
                            AIAnswerView(text: message.text, sources: message.sources)
                        }
                    }
                    statusView
                    Color.clear.frame(height: 1).id(Self.bottomID)
                }
                .padding(DNASpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            .onChange(of: model.selected?.messages.count) { _, _ in
                withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            }
            .onChange(of: model.status) { _, _ in
                withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .dnaBackground()
        .navigationTitle(model.selected.map { $0.title.isEmpty ? String(localized: "New Conversation") : $0.title } ?? String(localized: "New Conversation"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: startNew) { Image(systemName: "square.and.pencil") }
                    .accessibilityLabel("New Conversation")
                    .disabled(model.isLoading)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: close) { Image(systemName: "xmark") }
                    .accessibilityLabel("Close")
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if let conversation = model.selected {
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                Text("Based on your info as of \(conversation.context.builtAt.formatted(.dateTime.year().month().day())). Later changes to your trips aren't reflected in this conversation.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                Button("Start a New Conversation with the Latest Info", action: startNew)
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaActionText)
                    .disabled(model.isLoading)
            }
        } else if model.status == .idle {
            Text(model.tab == .recommendation
                 ? "Ask anything about where to go next. The AI knows your trip taste and saved cities."
                 : "Ask anything about your trips. The AI knows your trip records if you allow sending them.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.status {
        case .idle:
            EmptyView()
        case .loading(let question):
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                bubble(question)
                AnswerLoadingText()
                Text("Even if you close this screen, the answer will be saved here")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        case .failed(let question, let message, let canRetry):
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                bubble(question)
                Text(message).dnaFont(.body).foregroundStyle(Color.dnaError)
                if canRetry {
                    Button("Try Again") { model.send(question, dependencies: dependencies) }
                        .buttonStyle(.dnaSecondary(fullWidth: false))
                }
            }
        }
    }

    @ViewBuilder
    private var inputBar: some View {
        Group {
            if model.canSendInSelected {
                HStack(spacing: DNASpacing.sm) {
                    TextField("Ask AI", text: $model.draft, axis: .vertical)
                        .lineLimit(1...5)
                        .padding(.horizontal, DNASpacing.md)
                        .padding(.vertical, DNASpacing.xs)
                        .frame(minHeight: 44)
                        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.dnaDivider, lineWidth: 1))
                        .focused($focused)
                    Button { model.send(model.draft, dependencies: dependencies) } label: {
                        Image(systemName: "arrow.up")
                            .dnaFont(size: 16, weight: .bold)
                            .foregroundStyle(Color.dnaSelectedForeground)
                            .frame(width: 44, height: 44)
                            .background(Color.dnaSelectedBackground, in: Circle())
                    }
                    .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isLoading)
                    .accessibilityLabel("Send")
                }
            } else {
                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    Text("Sending trip ratings is off, so this conversation, which includes them, can only be read.")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Button("Start a New Conversation", action: startNew)
                        .buttonStyle(.dnaSecondary(fullWidth: false))
                }
            }
        }
        .padding(.horizontal, DNASpacing.lg)
        .padding(.vertical, DNASpacing.sm)
        .background(Color.dnaCanvas.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
    }

    private func bubble(_ text: String) -> some View {
        HStack {
            Spacer(minLength: DNASpacing.lg * 2)
            Text(text)
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextPrimary)
                .textSelection(.enabled)
                .padding(.horizontal, DNASpacing.md)
                .padding(.vertical, DNASpacing.sm)
                .background(Color.dnaSurface2, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        }
    }
}

// MARK: - 처음 전송 동의

/// 첫 대화 전 안내·동의. 취소하면 아무것도 보내지 않는다. 처리방침 4·7절과 같은 내용이다.
private struct ChatConsentSheet: View {
    let model: ChatModel
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Button("Cancel") { model.pendingQuestion = nil }
                .buttonStyle(.dnaGhost)
            Text("We send this info to the AI")
                .dnaFont(.heroTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    Text("An external AI model writes the answers, so the info below is sent to it through a relay server.")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                    group("Always Sent", ChatConsent.alwaysSent)
                    group("Sent Only If You Agree", ChatConsent.sentIfGranted)
                    group("Never Sent", CityMemoryConsent.neverSent)
                    group("Recipients", CityMemoryConsent.recipients)
                    Text(ChatConsent.summaryNote)
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Text("Whether trip records and reviews are sent is the same setting as for recommendations. You can change it later in Settings > Permissions and Data Sent. If you cancel, nothing is sent.")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Link("View Privacy Policy", destination: SettingsRootView.privacyPolicyURL)
                        .dnaFont(.caption)
                }
            }
            Button("Agree, Including Trip Records") { model.answerConsent(includeReviews: true, dependencies: dependencies) }
                .buttonStyle(.dnaPrimary)
            Button("Agree Without Trip Records") { model.answerConsent(includeReviews: false, dependencies: dependencies) }
                .buttonStyle(.dnaSecondary(onSheet: true))
        }
        .padding(DNASpacing.gutter)
        .background(Color.dnaSheet.ignoresSafeArea())
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }

    private func group(_ title: LocalizedStringKey, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
            Text(title).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
            Text(text).dnaFont(.body).foregroundStyle(Color.dnaTextPrimary)
        }
    }
}
