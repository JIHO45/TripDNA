import SwiftUI

private func won(_ amount: Int) -> String { "\(amount / 10_000)만원" }

/// 도시 추천 결과(시안 RecoResult ③④). 받는 중·실패·지난 결과 복원까지 한 곳에서 그린다.
struct CityRecommendationSection: View {
    let model: CityRecommendationViewModel
    let retry: () -> Void
    @Environment(AppDependencies.self) private var dependencies
    @State private var showingKeyEntry = false

    /// 안내 문구는 임시다. 문구와 시점은 사용자가 정한다(docs/data/storage-and-privacy.md).
    static let sendNotice = "추천을 받으면 입력한 여행 조건과 문장이 AI 서버로 전송돼요."

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            switch model.state {
            case .idle:
                EmptyView()
            case .loading:
                loadingView
            case .failed(let message):
                failureBanner(message)
                if let record = model.lastRecord { resultBody(record, isPrevious: true) }
            case .done(let record):
                resultBody(record, isPrevious: false)
            }
            if let notice = model.exclusionNotice { exclusionBanner(notice) }
            if let message = model.actionError {
                Text(message)
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaError)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #if DEBUG
        .sheet(isPresented: $showingKeyEntry) { NavigationStack { DevKeyForm() } }
        #endif
    }

    // MARK: ⓐ 받는 중

    private var loadingView: some View {
        VStack(spacing: DNASpacing.md) {
            ProgressView().tint(Color.dnaData)
            Text("도시를 고르고 이유를 쓰고 있어요")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Button("취소") { model.cancel() }
                .buttonStyle(.dnaGhost)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DNASpacing.xl)
    }

    // MARK: ⓘ 실패

    private func failureBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.sm) {
            Text(message)
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextPrimary)
            if model.lastRecord != nil {
                Text("지난 결과를 아래에 그대로 보여줘요.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Button("다시 시도", action: retry)
                .buttonStyle(.dnaSecondary)
            #if DEBUG
            Button("개발용 키 입력") { showingKeyEntry = true }
                .buttonStyle(.dnaGhost)
            #endif
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dnaUnverifiedBackground, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }

    // MARK: ③ 결과

    @ViewBuilder
    private func resultBody(_ record: CityRecommendationRecord, isPrevious: Bool) -> some View {
        let cards = model.visibleCards(record)
        let main = cards.filter { !$0.needsCheck }
        let check = cards.filter(\.needsCheck)

        if isPrevious {
            Text("\(record.createdAt.formatted(.dateTime.month().day()))에 받은 결과")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
        if record.derivedFrom != nil {
            Text("설명과 유의점은 처음 입력한 예산 기준으로 쓰였어요. 새 예산으로 다시 쓰려면 추천을 다시 받아 주세요.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaWarning)
        }
        understandingCard(record)

        if cards.isEmpty {
            emptyNote(record)
        } else {
            if !main.isEmpty {
                Text("추천 도시 \(main.count)곳")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                CityCardCarousel(cards: main, model: model, request: record.input)
            }
            if !record.budgetCutCityIDs.isEmpty {
                Text("예상 비용이 예산을 넘는 \(record.budgetCutCityIDs.count)곳은 뺐어요.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            if !check.isEmpty { checkGroup(check, request: record.input) }
        }
    }

    private func emptyNote(_ record: CityRecommendationRecord) -> some View {
        Text(record.cards.isEmpty
             ? "예상 비용이 예산을 넘는 도시뿐이에요. 예산이나 기간을 조정해 보세요."
             : "보여드릴 도시가 남지 않았어요. 새 여행 추천으로 다시 받아 보세요.")
            .dnaFont(.body)
            .foregroundStyle(Color.dnaTextSecondary)
    }

    /// 시안 ③④: 처음엔 펼쳐 보이고, 스크롤하거나 카드를 넘기면 한 줄로 접힌다. 접힌 줄에도 꼭 지킬 조건은 남긴다.
    @ViewBuilder
    private func understandingCard(_ record: CityRecommendationRecord) -> some View {
        let required = record.conditions.filter { $0.level == .required }.map(\.text)
        if model.understandingExpanded {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                HStack {
                    Text("이렇게 이해했어요")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Spacer(minLength: 0)
                    Button {
                        Task { await model.collapseUnderstanding(dependencies: dependencies) }
                    } label: {
                        Image(systemName: "chevron.up")
                            .dnaFont(size: 14, weight: .bold)
                            .foregroundStyle(Color.dnaTextSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("이해한 내용 접기")
                }
                .padding(.trailing, -DNASpacing.xs)
                if let understanding = record.understanding {
                    Text(understanding)
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextPrimary)
                } else if let primary = record.input.primary {
                    Text(primary.labelKo)
                        .dnaFont(.cardTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                }
                DNAFlowLayout(spacing: DNASpacing.xs) {
                    ForEach(record.input.conditionChips, id: \.self) { chip in
                        Text(chip)
                            .dnaFont(.button)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .padding(.horizontal, DNASpacing.sm)
                            .padding(.vertical, DNASpacing.xs)
                            .background(Color.dnaRaised, in: RoundedRectangle(cornerRadius: DNARadius.chip, style: .continuous))
                    }
                }
                if !required.isEmpty {
                    Text("꼭 지킬 조건: \(required.joined(separator: ", "))")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                // 예산 수정은 저장된 응답을 다시 거를 뿐이라 횟수를 쓰지 않는다. 예산 없이 받은 결과는 수정할 수 없어 말하지 않는다.
                if model.canEditBudget {
                    Text("예산은 바꿔도 추천 횟수를 쓰지 않아요")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                if !record.memoriesUsed.isEmpty {
                    VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                        Text("지난 여행에서 참고").dnaFont(.caption)
                        ForEach(record.memoriesUsed, id: \.id) { use in Text("· \(use.how)").dnaFont(.caption) }
                    }
                    .foregroundStyle(Color.dnaTextSecondary)
                }
            }
            .padding(.horizontal, DNASpacing.md)
            .padding(.bottom, DNASpacing.md)
            .padding(.top, DNASpacing.xxs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        } else {
            Button { withAnimation { model.expandUnderstanding() } } label: {
                HStack(spacing: DNASpacing.xs) {
                    Text(record.input.collapsedLine(required: required))
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .dnaFont(size: 14, weight: .bold)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                .padding(.horizontal, DNASpacing.md)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("이해한 내용 펼치기: \(record.input.collapsedLine(required: required))")
        }
    }

    /// "추가 확인 필요" 묶음. 기본 추천과 섞지 않고 확인할 조건 이름을 적는다.
    private func checkGroup(_ cards: [CityRecommendationRecord.Card], request: RecommendationRequest) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text("추가 확인 필요 \(cards.count)곳")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("꼭 지킬 조건을 아직 확인하지 못해 위 추천과 섞지 않았어요.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            ForEach(cards, id: \.cityID) { card in
                HStack(spacing: 0) {
                NavigationLink {
                    CityDetailView(card: card, conditionSummary: request.summaryText, request: request, savedAt: nil)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(card.cityName) · \(CountryCatalog.name(for: card.country))")
                                .dnaFont(.cardTitle)
                                .foregroundStyle(Color.dnaTextPrimary)
                            if case .needsCheck(let names) = card.badge {
                                Text("확인 필요: \(names.joined(separator: ", "))")
                                    .dnaFont(.caption)
                                    .foregroundStyle(Color.dnaTextSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.dnaTextTertiary)
                    }
                    .padding(DNASpacing.md)
                }
                .buttonStyle(.plain)
                CityCardMenu(card: card, model: model)
                }
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            }
        }
    }

    private func exclusionBanner(_ notice: ExcludedCity) -> some View {
        HStack(spacing: DNASpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(notice.cityName)은(는) 다시 추천하지 않아요")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("설정 > 추천에서 제외한 곳에서 바꿀 수 있어요")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Spacer(minLength: 0)
            Button("되돌리기") { Task { await model.undoExclusion(dependencies: dependencies) } }
                .dnaFont(.button)
                .foregroundStyle(Color.dnaActionText)
                .frame(minHeight: 44)
        }
        .padding(DNASpacing.md)
        .background(Color.dnaSurface2, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }
}

// MARK: - 카드 한 장씩 넘기기

private struct CityCardCarousel: View {
    let cards: [CityRecommendationRecord.Card]
    let model: CityRecommendationViewModel
    let request: RecommendationRequest
    @State private var page: String?
    @Environment(AppDependencies.self) private var dependencies

    private var index: Int { cards.firstIndex { $0.cityID == page } ?? 0 }

    var body: some View {
        VStack(spacing: DNASpacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: DNASpacing.sm) {
                    ForEach(cards, id: \.cityID) { card in
                        CityCardView(card: card, model: model, request: request)
                            .containerRelativeFrame(.horizontal) { width, _ in width }
                            .id(card.cityID)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page)
            .onChange(of: page) { _, new in
                // 처음 자리를 잡는 변화는 넘긴 것이 아니다.
                guard let new, new != cards.first?.cityID else { return }
                Task { await model.collapseUnderstanding(dependencies: dependencies) }
            }
            // "1/3" 같은 숫자는 순위로 읽혀 쓰지 않는다. 점과 화살표로만 위치를 알린다.
            if cards.count > 1 {
                HStack(spacing: DNASpacing.md) {
                    arrow("chevron.left", label: "이전 도시", target: index - 1)
                    HStack(spacing: DNASpacing.xxs) {
                        ForEach(cards.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == index ? Color.dnaTextPrimary : Color.dnaDivider)
                                .frame(width: i == index ? 18 : 6, height: 6)
                        }
                    }
                    .accessibilityHidden(true)
                    arrow("chevron.right", label: "다음 도시", target: index + 1)
                }
            }
        }
    }

    private func arrow(_ symbol: String, label: String, target: Int) -> some View {
        Button {
            guard cards.indices.contains(target) else { return }
            withAnimation { page = cards[target].cityID }
        } label: {
            Image(systemName: symbol)
                .dnaFont(size: 15, weight: .semibold)
                .foregroundStyle(cards.indices.contains(target) ? Color.dnaTextPrimary : Color.dnaTextTertiary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(label)
    }
}

// MARK: - 카드

/// 사진 없는 도시 카드. 도시 사진 자료가 없어 색 면과 이름으로 그린다. 가짜 사진은 넣지 않는다.
private struct CityCardView: View {
    let card: CityRecommendationRecord.Card
    let model: CityRecommendationViewModel
    let request: RecommendationRequest
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                CityDetailView(card: card, conditionSummary: request.summaryText, request: request, savedAt: nil)
            } label: {
                content
            }
            .buttonStyle(.plain)
            controls.padding(DNASpacing.xs)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            CityNameArea(card: card, height: 140)
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                if card.isExploration {
                    Text("다른 장점이 있는 후보")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaData)
                }
                CityBadgeView(card: card)
                Text(card.reason)
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextPrimary)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                if let cost = card.cost {
                    Text("예상 \(won(cost.low))~\(won(cost.high)) (추정)")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                if card.seasonCheckNeeded {
                    Text("선택한 시기에 가능한지 확인이 필요해요")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaWarning)
                }
            }
            .padding(DNASpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous).strokeBorder(Color.dnaDivider, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }

    private var controls: some View {
        let isSaved = model.isSaved(card.cityID)
        return HStack(spacing: DNASpacing.xs) {
            Button {
                Task { await model.toggleSave(card, dependencies: dependencies) }
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(Color.dnaTextPrimary)
                    .frame(width: 44, height: 44)
                    .dnaGlass(in: Circle())
            }
            .accessibilityLabel(isSaved ? "저장 해제" : "저장")
            CityCardMenu(card: card, model: model, glass: true)
        }
    }
}

/// 카드 더 보기 메뉴. 결과 카드와 "추가 확인 필요" 행이 같이 쓴다.
private struct CityCardMenu: View {
    let card: CityRecommendationRecord.Card
    let model: CityRecommendationViewModel
    var glass = false
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        Menu {
            Button("이번 결과에서 넘기기", systemImage: "arrow.right") {
                Task { await model.skip(card.cityID, dependencies: dependencies) }
            }
            Button("다시 추천하지 않기", systemImage: "hand.raised", role: .destructive) {
                Task { await model.exclude(card, dependencies: dependencies) }
            }
        } label: {
            if glass {
                icon.dnaGlass(in: Circle())
            } else {
                icon
            }
        }
        .accessibilityLabel("더 보기")
    }

    private var icon: some View {
        Image(systemName: "ellipsis")
            .foregroundStyle(Color.dnaTextPrimary)
            .frame(width: 44, height: 44)
    }
}

/// 사진 자리. 색 면 위에 도시·나라 이름만 올린다.
private struct CityNameArea: View {
    let card: CityRecommendationRecord.Card
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.dnaSurface2
            Color.dnaData.opacity(0.12)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.cityName)
                    .dnaFont(.screenTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("\(CountryFlag.emoji(for: card.country)) \(CountryCatalog.name(for: card.country))")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            .padding(DNASpacing.md)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}

/// docs/screens/recommendations.md 배지 표. 필수 조건이 없으면 아무것도 그리지 않는다.
private struct CityBadgeView: View {
    let card: CityRecommendationRecord.Card

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
            switch card.badge {
            case .requiredMet(let scope):
                Label("필수조건 충족 · \(scope.joined(separator: ", "))", systemImage: "checkmark.circle")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaData)
                    .padding(.horizontal, DNASpacing.xs)
                    .padding(.vertical, DNASpacing.xxs)
                    .background(Color.dnaData.opacity(0.12), in: Capsule())
            case .needsCheck, nil:
                EmptyView()
            }
            // 선호 조건의 미확인은 필수 조건의 배지와 따로 안내한다.
            if !card.unconfirmedPreferences.isEmpty {
                Text("확인 필요: \(card.unconfirmedPreferences.joined(separator: ", "))")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
        }
    }
}

// MARK: - ⑥ 상세

/// 도시 상세. 추천 결과와 저장한 도시에서 같은 화면을 연다. 저장한 도시에서 열면 저장 당시 조건 기준임을 밝힌다.
struct CityDetailView: View {
    let card: CityRecommendationRecord.Card
    let conditionSummary: String
    /// 저장하거나 받을 때의 요청. 있으면 조건 요약을 여기서 만든다.
    var request: RecommendationRequest?
    /// 저장한 도시에서 열었을 때만 값이 있다.
    let savedAt: Date?
    @Environment(AppDependencies.self) private var dependencies
    @State private var isSaved = false
    @State private var cityExcluded = false
    @State private var countryExcluded = false
    @State private var errorMessage: String?
    @State private var question = ""
    @State private var questionState: QuestionState = .idle
    @FocusState private var questionFocused: Bool
    @State private var keyboardUp = false

    private enum QuestionState { case idle, loading, answered(CityAnswer), failed(String) }

    private var summary: String { request?.summaryText ?? conditionSummary }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.md) {
                CityNameArea(card: card, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
                basis
                CityBadgeView(card: card)
                if cityExcluded || countryExcluded { exclusionRow }
                SectionCard(title: "이번 여행에 맞는 이유") {
                    Text(card.reason)
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextPrimary)
                }
                caveatSection
                if let cost = card.cost {
                    SectionCard(title: "예상 비용") {
                        Text("\(won(cost.low))~\(won(cost.high))")
                            .dnaFont(.heroTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Text("추정이에요. 실제 가격이나 예산 충족을 보장하지 않으니 항공·숙박 가격은 출발 전에 직접 확인해 주세요.")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                }
                questionSection.id(Self.questionID)
            }
            .padding(DNASpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: questionFocused) { _, focused in
            guard focused else { return }
            // 키보드가 올라오는 동안 기다렸다가 질문 칸이 보이게 올린다.
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation { proxy.scrollTo(Self.questionID, anchor: .top) }
            }
        }
        .dnaBackground()
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(card.cityName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await toggleSave() } } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(isSaved ? "저장 해제" : "저장")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        .safeAreaInset(edge: .bottom) {
            // 키보드가 떠 있는 동안은 숨겨 키보드와 함께 올라와 내용을 가리지 않게 한다.
            if !keyboardUp { bottomBar }
        }
        .task {
            let state = try? await dependencies.store.cityState()
            isSaved = state?.saved.contains { $0.id == card.cityID } ?? false
            // 도시 제외는 따로 저장되고, 나라 제외는 평가 서비스에 있다.
            countryExcluded = ((try? await dependencies.recommendationService.activeDislikes()) ?? [])
                .contains { $0.countryCode == card.country }
            cityExcluded = state?.excludedCityIDs.contains(card.cityID) ?? false
        }
        }
    }

    private static let questionID = "question"

    /// 아래 고정 막대. 배경을 채워 뒤의 내용이 비치지 않고, 위에 구분선을 둔다.
    private var bottomBar: some View {
        DNABottomCTA {
            NavigationLink {
                TripRegistrationView(prefilledCountryCode: card.country, prefilledCity: card.cityName)
            } label: {
                Text("이곳으로 여행 등록")
            }
            .buttonStyle(.dnaPrimary)
            Text("날짜·동행은 자동으로 정하지 않아요")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            if let errorMessage {
                Text(errorMessage)
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaError)
            }
        }
        .background(Color.dnaCanvas.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var exclusionRow: some View {
        HStack(spacing: DNASpacing.sm) {
            VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                Text(cityExcluded ? "추천에서 제외 중" : "추천에서 제외한 나라예요")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextPrimary)
                if countryExcluded {
                    Text("나라 제외는 설정 > 추천에서 제외한 곳에서 풀 수 있어요")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            }
            Spacer(minLength: 0)
            if cityExcluded {
                Button("제외 풀기") { Task { await releaseExclusion() } }
                    .dnaFont(.button)
                    .foregroundStyle(Color.dnaActionText)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, DNASpacing.md)
        .background(Color.dnaSurface2, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }

    // 답은 화면이 열려 있는 동안만 메모리에 둔다. 질문 횟수는 세지 않는다.
    // 초안: 답의 세 부분 이름(자료 근거 / 조언 / 확인하지 못한 것)은 시안 ⓖ의 임시 문구다.
    private var questionSection: some View {
        SectionCard(title: "궁금한 점") {
            Text(savedAt != nil ? "저장할 때의 조건 기준으로 답해요" : "이 추천의 조건 기준으로 답해요")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            HStack(spacing: DNASpacing.sm) {
                TextField("이 도시에 대해 물어보세요", text: $question, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .focused($questionFocused)
                Button { Task { await ask() } } label: {
                    Image(systemName: "arrow.up.circle.fill").dnaFont(size: 28)
                }
                .foregroundStyle(Color.dnaActionText)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isAsking)
                .accessibilityLabel("질문 보내기")
            }
            switch questionState {
            case .idle: EmptyView()
            case .loading: ProgressView("확인하고 있어요")
            case .failed(let message):
                Text(message).dnaFont(.body).foregroundStyle(Color.dnaError)
                Button("다시 시도") { Task { await ask() } }.buttonStyle(.dnaSecondary)
            case .answered(let answer): answerView(answer)
            }
        }
    }

    private var isAsking: Bool { if case .loading = questionState { true } else { false } }

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

    private func ask() async {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let catalog = CityCatalog.load() else { return }
        questionState = .loading
        let service = CityQuestionService(catalog: catalog, client: CityLLMConfiguration.makeSearchClient())
        do {
            let answer = try await service.ask(text, card: card, request: request, conditionSummary: summary)
            questionState = .answered(answer)
        } catch CityQuestionError.notConfigured {
            questionState = .failed("LLM 연결이 아직 준비되지 않았어요. 프록시 주소(CityLLMProxyURL) 또는 개발용 키가 필요해요.")
        } catch {
            guard !Task.isCancelled else { return }
            questionState = .failed("답을 확인하지 못했어요. 다시 시도해 주세요.")
        }
    }

    private func releaseExclusion() async {
        do {
            try await dependencies.store.updateCityState { $0.release(cityID: card.cityID) }
            errorMessage = nil
            cityExcluded = false
        } catch {
            errorMessage = CityRecommendationViewModel.saveFailure
        }
    }

    @ViewBuilder
    private var basis: some View {
        if let savedAt {
            Text("\(savedAt.formatted(.dateTime.year().month().day())) 저장 당시 조건(\(summary)) 기준이에요. 지금 조건과 다를 수 있어요.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaWarning)
        } else if !summary.isEmpty {
            Text("조건: \(summary)")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    private var notes: [String] {
        var result = [card.caveat].filter { !$0.isEmpty }
        if card.seasonCheckNeeded { result.append("선택한 시기에 가능한지 확인이 필요해요") }
        if case .needsCheck(let names) = card.badge { result.append("확인 필요(꼭 지킬 조건): \(names.joined(separator: ", "))") }
        result += card.unconfirmedPreferences.map { "확인 필요: \($0)" }
        return result
    }

    @ViewBuilder
    private var caveatSection: some View {
        if !notes.isEmpty {
            SectionCard(title: "안 맞을 수 있는 점 · 확인할 것") {
                ForEach(notes, id: \.self) { note in
                    Text("· \(note)")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextPrimary)
                }
            }
        }
    }

    private func toggleSave() async {
        let wasSaved = isSaved
        do {
            let updated = try await dependencies.store.updateCityState {
                if wasSaved { $0.unsave(cityID: card.cityID) } else { $0.save(card, conditionSummary: summary, request: request) }
            }
            isSaved = updated.saved.contains { $0.id == card.cityID }
            errorMessage = nil
        } catch {
            errorMessage = CityRecommendationViewModel.saveFailure
        }
    }
}

// MARK: - ⓑ 첫 전송 동의

/// 지난 여행 평가를 처음 보내기 전의 안내·동의 시트.
/// 문구는 초안이다. 최종 문구와 절차는 사용자가 정한다(docs/data/storage-and-privacy.md, 시안 RecoStates ⓑ).
struct CityConsentSheet: View {
    let model: CityRecommendationViewModel
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Button("취소") { model.cancelConsent() }
                .buttonStyle(.dnaGhost)
            Text("추천을 위해 이 정보를 보내요")
                .dnaFont(.heroTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("도시를 고르고 이유를 쓰는 데 외부 AI 모델을 써요. 이 정보는 외부 AI 모델로 보내져 처리돼요.")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
            group("보내는 것", [
                "고른 여행 컨셉과 조건, 적은 문장",
                "동의하면: 최근 여행 평가의 별점과 메모 원문, 다녀온 도시"
            ])
            group("보내지 않는 것", ["원본 사진, 위치 기록"])
            Text("동의하지 않아도 평가 없이 추천받을 수 있어요. 나중에 설정 > 권한과 보내는 정보에서 바꿀 수 있어요.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            Spacer(minLength: 0)
            Button("동의하고 추천 받기") { model.answerConsent(true, dependencies: dependencies) }
                .buttonStyle(.dnaPrimary)
            Button("평가는 빼고 추천 받기") { model.answerConsent(false, dependencies: dependencies) }
                .buttonStyle(.dnaSecondary)
        }
        .padding(DNASpacing.gutter)
        .background(Color.dnaSheet.ignoresSafeArea())
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }

    private func group(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
            Text(title).dnaFont(.cardTitle).foregroundStyle(Color.dnaTextPrimary)
            ForEach(lines, id: \.self) { Text("· \($0)").dnaFont(.body).foregroundStyle(Color.dnaTextPrimary) }
        }
    }
}

// MARK: - ⓓ 조건 수정

/// 받은 도시를 예산으로 다시 거르기만 한다. 새 LLM 호출이 없다.
struct CityConditionEditSheet: View {
    let model: CityRecommendationViewModel
    let onNewRequest: () -> Void
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var budgetText = ""

    /// 곱셈 오버플로를 막는 상한(10억 원).
    private static let maxBudgetMan = 100_000

    private var man: Int? { Int(budgetText).flatMap { (1...Self.maxBudgetMan).contains($0) ? $0 : nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            HStack {
                Text("조건 수정")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .dnaFont(size: 15, weight: .bold)
                        .foregroundStyle(Color.dnaTextPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.dnaRaised, in: Circle())
                }
                .accessibilityLabel("닫기")
            }
            if model.canEditBudget {
                Text("예산 (만원, 최대 금액)")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                TextField("예: 100", text: $budgetText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Text("새로 추천받지 않고 받은 도시만 다시 걸러요. 추천 횟수를 쓰지 않아요.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                Button("이 조건으로 다시 보기") {
                    guard let man else { return }
                    Task {
                        await model.applyBudget(man * 10_000, dependencies: dependencies)
                        dismiss()
                    }
                }
                .buttonStyle(.dnaPrimary(isDisabled: man == nil))
                .disabled(man == nil)
            } else {
                Text("이번 결과는 예산 없이 받아서 예산으로 다시 거를 수 없어요.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Text("시기·기간이나 컨셉을 바꾸려면 새 여행 추천으로 다시 받아 주세요.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            Button("새 여행 추천") { dismiss(); onNewRequest() }
                .buttonStyle(.dnaSecondary)
            Spacer(minLength: 0)
        }
        .padding(DNASpacing.gutter)
        .background(Color.dnaSheet.ignoresSafeArea())
        .presentationDetents([.medium])
        .onAppear {
            if budgetText.isEmpty, let current = model.lastRecord?.input.budgetMaxKRW { budgetText = String(current / 10_000) }
        }
    }
}
