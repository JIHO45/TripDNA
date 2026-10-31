import SwiftUI

private func won(_ amount: Int) -> String { shortKRW(amount, koreanUnit: "만원") } // l10n-ignore Korean amount unit

private func wonRange(_ low: Int, _ high: Int) -> String {
    AppLanguage.isKorean ? "\(won(low))~\(won(high))" : "\(won(low))–\(won(high))"
}

/// 도시 추천 결과(시안 RecoResult ③④). 받는 중·실패·지난 결과 복원까지 한 곳에서 그린다.
struct CityRecommendationSection: View {
    let model: CityRecommendationViewModel
    let retry: () -> Void
    let editConditions: () -> Void
    /// 새 입력 시트를 연다. 인자가 있으면 그 조건을 채워서 연다.
    let newRequest: (RecommendationRequest?) -> Void
    @Environment(AppDependencies.self) private var dependencies
    @State private var showingKeyEntry = false

    private static let catalog = CityCatalog.load()

    private func excludedHomeName(_ record: CityRecommendationRecord) -> String? {
        record.excludedHomeName(catalog: Self.catalog)
    }

    /// 안내 문구는 임시다. 문구와 시점은 사용자가 정한다(docs/data/storage-and-privacy.md).
    static var sendNotice: String { String(localized: "When you get recommendations, your trip conditions and text are sent to an AI server.") }

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
            Text("Picking cities and writing the reasons")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Button("Cancel") { model.cancel() }
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
                Text("Your previous results are shown below.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Button("Try Again", action: retry)
                .buttonStyle(.dnaSecondary)
            #if DEBUG
            Button("Enter Dev Key") { showingKeyEntry = true }
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
            Text("Results from \(record.createdAt.formatted(.dateTime.month().day()))")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
        if record.derivedFrom != nil {
            Text("The descriptions and cautions were written for your original budget. To rewrite them for the new budget, get recommendations again.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaWarning)
        }
        understandingCard(record)
        if let change = model.budgetChange { budgetChangeNotice(change) }

        if cards.isEmpty {
            emptyCard(record)
        } else {
            if !main.isEmpty {
                CityCardCarousel(cards: main, model: model, request: record.input)
            }
            if !record.budgetCutCityIDs.isEmpty {
                Text("\(record.budgetCutCityIDs.count) cities with estimated costs over your budget were left out.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            if !check.isEmpty { checkGroup(check, request: record.input) }
        }
    }

    private func budgetChangeNotice(_ change: CityRecommendationViewModel.BudgetChange) -> some View {
        HStack(spacing: DNASpacing.sm) {
            Text(change.message + " ·")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            Button("Undo") { Task { await model.revertBudget(dependencies: dependencies) } }
                .dnaFont(.caption)
                .frame(minHeight: 44)
        }
    }

    /// 시안 ⓙ: 보여줄 카드가 없을 때. 실제 이유를 적고 조건 수정·새 추천으로 이어 준다.
    private func emptyCard(_ record: CityRecommendationRecord) -> some View {
        let cut = record.budgetCutCityIDs.count
        let (title, reason): (String, String) = if record.cards.isEmpty, cut > 0 {
            (String(localized: "Couldn't find a city within your budget"),
             String(localized: "After removing \(cut) cities with estimated costs over your budget, none are left. Try adjusting your budget or trip length."))
        } else if record.cards.isEmpty {
            (String(localized: "Couldn't find a city that matches your conditions"),
             String(localized: "No cities came back for these conditions. Change them and try again."))
        } else {
            (String(localized: "No cities left to show"),
             String(localized: "You skipped or excluded all \(record.cards.count) cities. Get new ones with a new trip recommendation."))
        }
        return VStack(spacing: DNASpacing.sm) {
            Image(systemName: "magnifyingglass")
                .dnaFont(size: 22)
                .foregroundStyle(Color.dnaActionText)
                .frame(width: 52, height: 52)
                .background(Color.dnaSurface2, in: Circle())
            Text(title)
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
                .multilineTextAlignment(.center)
            Text(reason)
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
                .multilineTextAlignment(.center)
            Button("Edit Conditions", action: editConditions)
                .buttonStyle(.dnaPrimary)
            Button("New Trip Recommendation") { newRequest(nil) }
                .buttonStyle(.dnaSecondary)
        }
        .padding(DNASpacing.md)
        .frame(maxWidth: .infinity)
        .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
    }

    /// 시안 ③④: 처음엔 펼쳐 보이고, 스크롤하거나 카드를 넘기면 한 줄로 접힌다. 접힌 줄에도 꼭 지킬 조건은 남긴다.
    @ViewBuilder
    private func understandingCard(_ record: CityRecommendationRecord) -> some View {
        let required = record.conditions.filter { $0.level == .required }.map(\.text)
        let collapsed = record.input.collapsedLine(required: required)
        if model.understandingExpanded {
            VStack(alignment: .leading, spacing: DNASpacing.sm) {
                HStack {
                    Text("Here's what I understood")
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
                    .accessibilityLabel("Collapse summary")
                }
                .padding(.trailing, -DNASpacing.xs)
                if let understanding = record.understanding {
                    Text(understanding)
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextPrimary)
                } else if let primary = record.input.primary {
                    Text(primary.label)
                        .dnaFont(.cardTitle)
                        .foregroundStyle(Color.dnaTextPrimary)
                }
                DNAFlowLayout(spacing: DNASpacing.xs) {
                    ForEach(record.input.conditionChips, id: \.self) { chip in
                        Button(action: editConditions) {
                            Text(chip)
                                .dnaFont(.button)
                                .foregroundStyle(Color.dnaTextPrimary)
                                .padding(.horizontal, DNASpacing.sm)
                                .padding(.vertical, DNASpacing.xs)
                                .background(Color.dnaRaised, in: RoundedRectangle(cornerRadius: DNARadius.chip, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(chip == record.input.budgetText ? String(localized: "Budget \(chip), change") : String(localized: "\(chip), change"))
                    }
                }
                if let home = excludedHomeName(record) {
                    Divider()
                    HStack(spacing: DNASpacing.xs) {
                        Image(systemName: "minus.circle").foregroundStyle(Color.dnaTextSecondary)
                        Text("\(home) (your home country) was left out")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Spacer(minLength: 0)
                        Button("Include") {
                            var request = record.input
                            request.includeHomeCountry = true
                            newRequest(request)
                        }
                        .dnaFont(.button)
                        .foregroundStyle(Color.dnaActionText)
                        .frame(minHeight: 44)
                        .accessibilityHint("Opens a new recommendation screen with your conditions filled in. You need to get recommendations again")
                    }
                }
                if !required.isEmpty {
                    Text("Must-have conditions: \(required.joined(separator: ", "))")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                // 예산 수정은 저장된 응답을 다시 거를 뿐이라 횟수를 쓰지 않는다. 예산 없이 받은 결과는 수정할 수 없어 말하지 않는다.
                if model.canEditBudget {
                    Text("Changing the budget doesn't use up a recommendation")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                if !record.memoriesUsed.isEmpty {
                    VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                        Text("From your past trips").dnaFont(.caption)
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
                // 접어도 사는 나라를 뺀 사실은 자르지 않고 별도 줄에 남긴다.
                VStack(alignment: .leading, spacing: DNASpacing.xxs) {
                    HStack(spacing: DNASpacing.xs) {
                        Text(collapsed)
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaTextPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .dnaFont(size: 14, weight: .bold)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                    if let home = excludedHomeName(record) {
                        Text("\(home) excluded")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, DNASpacing.md)
                .padding(.vertical, DNASpacing.xs)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dnaSurface1, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Expand summary: \(collapsed)") + (excludedHomeName(record).map { String(localized: ", \($0) excluded") } ?? ""))
        }
    }

    /// "추가 확인 필요" 묶음. 기본 추천과 섞지 않고 확인할 조건 이름을 적는다.
    private func checkGroup(_ cards: [CityRecommendationRecord.Card], request: RecommendationRequest) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.xs) {
            Text("\(cards.count) cities need a check")
                .dnaFont(.sectionTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("We couldn't confirm your must-have conditions yet, so these are kept apart from the recommendations above.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            ForEach(Array(cards.enumerated()), id: \.element.cityID) { index, card in
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
                                Text("Needs checking: \(names.joined(separator: ", "))")
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
                .onScrollVisibilityChange(threshold: 0.5) { visible in
                    if visible { model.recordExposure(card, screen: "check", position: index + 1, dependencies: dependencies) }
                }
            }
        }
    }

    private func exclusionBanner(_ notice: ExcludedCity) -> some View {
        HStack(spacing: DNASpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(notice.cityName) won't be recommended again")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextPrimary)
                Text("You can change this in Settings > Excluded from Recommendations")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Spacer(minLength: 0)
            Button("Undo") { Task { await model.undoExclusion(dependencies: dependencies) } }
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
            HStack {
                Text("\(cards.count) Recommended Cities")
                    .dnaFont(.sectionTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                Spacer(minLength: 0)
                if cards.count > 1 {
                    arrow("chevron.left", label: "Previous city", target: index - 1)
                    arrow("chevron.right", label: "Next city", target: index + 1)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: DNASpacing.sm) {
                    ForEach(Array(cards.enumerated()), id: \.element.cityID) { index, card in
                        CityCardView(card: card, model: model, request: request)
                            .containerRelativeFrame(.horizontal) { width, _ in width }
                            .onScrollVisibilityChange(threshold: 0.5) { visible in
                                if visible { model.recordExposure(card, screen: "cards", position: index + 1, dependencies: dependencies) }
                            }
                            .id(card.cityID)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page)
            // "1/3" 같은 숫자는 순위로 읽혀 쓰지 않는다. 점과 화살표로만 위치를 알린다.
            if cards.count > 1 {
                HStack(spacing: DNASpacing.md) {
                    HStack(spacing: DNASpacing.xxs) {
                        ForEach(cards.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == index ? Color.dnaTextPrimary : Color.dnaDivider)
                                .frame(width: i == index ? 18 : 6, height: 6)
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private func arrow(_ symbol: String, label: LocalizedStringKey, target: Int) -> some View {
        Button {
            guard cards.indices.contains(target) else { return }
            withAnimation { page = cards[target].cityID }
        } label: {
            Image(systemName: symbol)
                .dnaFont(size: 15, weight: .semibold)
                .foregroundStyle(cards.indices.contains(target) ? Color.dnaTextPrimary : Color.dnaTextTertiary)
                .frame(width: 44, height: 44)
                .background(Color.dnaSurface1, in: Circle())
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
            Color.dnaData.opacity(0.12)
                .background(Color.dnaSurface2)
                .frame(height: 96)
            VStack(alignment: .leading, spacing: DNASpacing.xs) {
                CityTitleBlock(card: card)
                if card.isExploration {
                    Text("Candidate with other strengths")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaData)
                }
                CityBadgeView(card: card)
                Text(card.reason)
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let cost = card.cost {
                    Divider()
                    Text(request.nights.map { String(localized: "Estimated for \($0) nights: \(wonRange(cost.low, cost.high)) (estimate)") } ?? String(localized: "Estimated \(wonRange(cost.low, cost.high)) (estimate)"))
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
                if card.seasonCheckNeeded {
                    Text("Check that this works for your chosen dates")
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
            .accessibilityLabel(isSaved ? String(localized: "Remove from saved") : String(localized: "Save"))
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
    @Environment(\.openURL) private var openURL

    var body: some View {
        Menu {
            Button("Skip for This Result", systemImage: "arrow.right") {
                Task { await model.skip(card.cityID, dependencies: dependencies) }
            }
            Button("Never Recommend Again", systemImage: "hand.raised", role: .destructive) {
                Task { await model.exclude(card, dependencies: dependencies) }
            }
            if let record = model.lastRecord, let url = CityErrorReport.mailURL(card: card, record: record) {
                Button("Report an Error", systemImage: "exclamationmark.bubble") {
                    openURL(url)
                    Task { await dependencies.track(.errorReportOpened) }
                }
            }
        } label: {
            if glass {
                icon.dnaGlass(in: Circle())
            } else {
                icon
            }
        }
        .accessibilityLabel("More")
    }

    private var icon: some View {
        Image(systemName: "ellipsis")
            .foregroundStyle(Color.dnaTextPrimary)
            .frame(width: 44, height: 44)
    }
}

/// "틀린 내용 알리기": 메일 앱에 도시와 결과의 버전을 채워 연다. 보낼지와 무엇을 적을지는 사용자가 정한다.
/// 조건·메모·추천 문장은 넣지 않는다(필요하면 사용자가 직접 적는다).
enum CityErrorReport {
    static let address = "joe45dev@gmail.com"

    static func mailURL(card: CityRecommendationRecord.Card, record: CityRecommendationRecord,
                        appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") -> URL? {
        let body = [
            String(localized: "What was wrong or didn't match?"), "", "", "---",
            String(localized: "City: \(card.cityName) (\(card.cityID))"),
            String(localized: "Result: \(record.id) · \(record.createdAt.formatted(.iso8601))"),
            String(localized: "Version: \(record.version.prompt) · \(record.version.ranking) · \(record.version.catalog) · \(record.version.model) · app \(appVersion)"),
        ].joined(separator: "\n")
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: String(localized: "[TripDNA] Recommendation feedback: \(card.cityName)")),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}

/// 사진 아래 흰 영역의 도시·나라 이름.
private struct CityTitleBlock: View {
    let card: CityRecommendationRecord.Card

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.cityName)
                .dnaFont(.screenTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            Text("\(CountryFlag.emoji(for: card.country)) \(CountryCatalog.name(for: card.country))")
                .dnaFont(.body)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }
}

/// docs/screens/recommendations.md 배지 표. 필수 조건이 없으면 아무것도 그리지 않는다.
private struct CityBadgeView: View {
    let card: CityRecommendationRecord.Card

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.xxs) {
            switch card.badge {
            case .requiredMet(let scope):
                Label("Requirements met · \(scope.joined(separator: ", "))", systemImage: "checkmark.circle")
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
                Text("Needs checking: \(card.unconfirmedPreferences.joined(separator: ", "))")
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
    /// 시트를 닫아도 기다리던 답을 받도록 상세가 들고 있는다.
    @State private var questions = CityQuestionModel()
    @State private var showingQuestions = false
    @State private var questionDetent = PresentationDetent.medium

    private var summary: String { request?.summaryText ?? conditionSummary }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DNASpacing.md) {
                // 도시 사진 자료가 없어 색 면으로 둔다. 이름은 사진 아래에 둔다.
                Color.dnaData.opacity(0.12)
                    .background(Color.dnaSurface2)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
                CityTitleBlock(card: card)
                CityBadgeView(card: card)
                basis
                if cityExcluded || countryExcluded { exclusionRow }
                plainSection("Why It Fits This Trip") {
                    Text(card.reason)
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextPrimary)
                }
                caveatSection
                if let cost = card.cost {
                    plainSection("Estimated Cost") {
                        Text(wonRange(cost.low, cost.high))
                            .dnaFont(.heroTitle)
                            .foregroundStyle(Color.dnaTextPrimary)
                        Text("This is an estimate. It doesn't guarantee actual prices or that your budget is met, so check flight and hotel prices yourself before you go.")
                            .dnaFont(.caption)
                            .foregroundStyle(Color.dnaTextSecondary)
                    }
                }
            }
            .padding(DNASpacing.lg)
            // 떠 있는 질문 버튼이 마지막 문단을 덮지 않게 그 높이만큼 더 내린다.
            .padding(.bottom, 56)
        }
        // 누르면 질문 시트를 중간 높이로 연다. 지난 질문을 먼저 읽고, 입력하면 전체 높이로 늘어난다.
        .overlay(alignment: .bottomTrailing) {
                Button {
                    questionDetent = .medium
                    showingQuestions = true
                } label: {
                    Image(systemName: "questionmark.bubble")
                        .dnaFont(size: 20, weight: .bold)
                        .foregroundStyle(Color.dnaSelectedForeground)
                        .frame(width: 56, height: 56)
                        .background(Color.dnaSelectedBackground, in: Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .padding(DNASpacing.gutter)
                .accessibilityLabel("Ask about this city")
        }
        .sheet(isPresented: $showingQuestions) {
            CityQuestionSheet(
                model: questions, card: card, request: request, summary: summary,
                isSavedBasis: savedAt != nil, detent: $questionDetent
            )
            .presentationDetents([.medium, .large], selection: $questionDetent)
            .presentationDragIndicator(.visible)
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
                .accessibilityLabel(isSaved ? String(localized: "Remove from saved") : String(localized: "Save"))
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .task {
            await questions.load(cityID: card.cityID, store: dependencies.store)
            let state = try? await dependencies.store.cityState()
            isSaved = state?.saved.contains { $0.id == card.cityID } ?? false
            // 도시 제외는 따로 저장되고, 나라 제외는 평가 서비스에 있다.
            countryExcluded = ((try? await dependencies.recommendationService.activeDislikes()) ?? [])
                .contains { $0.countryCode == card.country }
            cityExcluded = state?.excludedCityIDs.contains(card.cityID) ?? false
        }
    }

    /// 아래 고정 막대. 배경을 채워 뒤의 내용이 비치지 않고, 위에 구분선을 둔다.
    private var bottomBar: some View {
        DNABottomCTA {
            NavigationLink {
                TripRegistrationView(prefilledCountryCode: card.country, prefilledCity: card.cityName)
            } label: {
                Text("Register a Trip Here")
            }
            .buttonStyle(.dnaPrimary)
            Text("Dates and companions aren't set automatically")
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
                Text(cityExcluded ? String(localized: "Excluded from recommendations") : String(localized: "This country is excluded from recommendations"))
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextPrimary)
                if countryExcluded {
                    Text("You can undo a country exclusion in Settings > Excluded from Recommendations")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                }
            }
            Spacer(minLength: 0)
            if cityExcluded {
                Button("Remove Exclusion") { Task { await releaseExclusion() } }
                    .dnaFont(.button)
                    .foregroundStyle(Color.dnaActionText)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, DNASpacing.md)
        .background(Color.dnaSurface2, in: RoundedRectangle(cornerRadius: DNARadius.card, style: .continuous))
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
            Text("Based on the conditions when you saved this on \(savedAt.formatted(.dateTime.year().month().day())) (\(summary)). They may differ from your current conditions.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaWarning)
        } else if !summary.isEmpty {
            Text("Conditions: \(summary)")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
        }
    }

    /// 카드 없이 제목과 본문을 잇는 섹션.
    private func plainSection<C: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: DNASpacing.titleGap) {
            Text(title).dnaFont(.sectionTitle).foregroundStyle(Color.dnaTextPrimary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 섹션 사이를 제목·본문 간격보다 넓혀 구분한다(바깥 간격 md + 이 값 = section).
        .padding(.top, DNASpacing.section - DNASpacing.md)
    }

    private var notes: [String] {
        var result = [card.caveat].filter { !$0.isEmpty }
        if card.seasonCheckNeeded { result.append(String(localized: "Check that this works for your chosen dates")) }
        if case .needsCheck(let names) = card.badge { result.append(String(localized: "Needs checking (must-have): \(names.joined(separator: ", "))")) }
        result += card.unconfirmedPreferences.map { String(localized: "Needs checking: \($0)") }
        return result
    }

    @ViewBuilder
    private var caveatSection: some View {
        if !notes.isEmpty {
            plainSection("Things That May Not Fit · To Check") {
                VStack(alignment: .leading, spacing: DNASpacing.xs) {
                    ForEach(notes, id: \.self) { note in
                        Text(note)
                            .dnaFont(.body)
                            .foregroundStyle(Color.dnaUnverifiedText)
                    }
                }
                .padding(DNASpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.dnaUnverifiedBackground, in: RoundedRectangle(cornerRadius: DNARadius.control, style: .continuous))
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

/// 처음 보내기 전의 안내·동의 시트. 취소하면 아무것도 보내지 않는다.
/// 무엇을 누구에게 보내는지는 처리방침 4·7절과 같다(docs/data/storage-and-privacy.md A1).
struct CityConsentSheet: View {
    let model: CityRecommendationViewModel
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            Button("Cancel") { model.cancelConsent() }
                .buttonStyle(.dnaGhost)
            Text("We send this info to make recommendations")
                .dnaFont(.heroTitle)
                .foregroundStyle(Color.dnaTextPrimary)
            ScrollView {
                VStack(alignment: .leading, spacing: DNASpacing.md) {
                    Text("An external AI model writes city recommendations and answers to city questions, so the info below is sent to it through a relay server.")
                        .dnaFont(.body)
                        .foregroundStyle(Color.dnaTextSecondary)
                    group("Always Sent", CityMemoryConsent.alwaysSent)
                    group("Sent Only If You Agree", CityMemoryConsent.sentIfGranted)
                    group("Never Sent", CityMemoryConsent.neverSent)
                    group("Recipients", CityMemoryConsent.recipients)
                    Text("You can get recommendations without sharing reviews. You can change this later in Settings > Permissions and Data Sent. If you cancel, nothing is sent.")
                        .dnaFont(.caption)
                        .foregroundStyle(Color.dnaTextSecondary)
                    Link("View Privacy Policy", destination: SettingsRootView.privacyPolicyURL)
                        .dnaFont(.caption)
                }
            }
            Button("Agree and Get Recommendations") { model.answerConsent(true, dependencies: dependencies) }
                .buttonStyle(.dnaPrimary)
            Button("Get Recommendations Without Reviews") { model.answerConsent(false, dependencies: dependencies) }
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

// MARK: - ⓓ 조건 수정

/// 받은 도시를 예산으로 다시 거르기만 한다. 새 LLM 호출이 없다.
struct CityConditionEditSheet: View {
    let model: CityRecommendationViewModel
    let onNewRequest: () -> Void
    @Environment(AppDependencies.self) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var budgetText = ""
    @State private var budget: Int?
    @State private var isCustom = false

    /// 곱셈 오버플로를 막는 상한(10억 원).
    private static let maxBudgetMan = 100_000

    private var man: Int? { Int(budgetText).flatMap { (1...Self.maxBudgetMan).contains($0) ? $0 : nil } }
    /// 지금 고른 예산이 적용할 수 있는 값인지. "직접 입력"은 올바른 금액이 있어야 한다.
    private var canApply: Bool { !isCustom || man != nil }

    var body: some View {
        // 직접 입력 칸까지 열리면 중간 높이를 넘으므로 스크롤로 감싸 위가 잘리지 않게 한다.
        ScrollView {
        VStack(alignment: .leading, spacing: DNASpacing.md) {
            HStack {
                Text("Edit Conditions")
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
                .accessibilityLabel("Close")
            }
            if model.canEditBudget {
                Text("Budget (Max Amount)")
                    .dnaFont(.cardTitle)
                    .foregroundStyle(Color.dnaTextPrimary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        DNATagChip(title: String(localized: "Undecided"), isSelected: budget == nil && !isCustom) {
                            isCustom = false
                            budget = nil
                        }
                        ForEach(RecommendationRequest.budgetPresets, id: \.self) { amount in
                            DNATagChip(title: String(localized: "Up to \(shortKRW(amount, koreanUnit: "만 원"))"), isSelected: !isCustom && budget == amount) { // l10n-ignore Korean amount unit
                                isCustom = false
                                budget = amount
                            }
                        }
                        DNATagChip(title: String(localized: "Custom"), isSelected: isCustom) { isCustom = true }
                    }
                }
                if isCustom {
                    HStack {
                        TextField("Amount", text: $budgetText)
                            .keyboardType(.numberPad)
                        Text("× ₩10,000 or less").foregroundStyle(Color.dnaTextSecondary)
                    }
                    .textFieldStyle(.roundedBorder)
                }
                Text("This only re-filters the cities you already got, without new recommendations. It doesn't use up a recommendation.")
                    .dnaFont(.caption)
                    .foregroundStyle(Color.dnaTextSecondary)
                Button("View with These Conditions") {
                    guard canApply else { return }
                    let amount = isCustom ? man.map { $0 * 10_000 } : budget
                    Task {
                        await model.applyBudget(amount, dependencies: dependencies)
                        dismiss()
                    }
                }
                .buttonStyle(.dnaPrimary(isDisabled: !canApply))
                .disabled(!canApply)
            } else {
                Text("This result was received without a budget, so it can't be re-filtered by budget.")
                    .dnaFont(.body)
                    .foregroundStyle(Color.dnaTextSecondary)
            }
            Text("To change the timing, length, or concept, get recommendations again with a new trip recommendation.")
                .dnaFont(.caption)
                .foregroundStyle(Color.dnaTextSecondary)
            Button("New Trip Recommendation") { dismiss(); onNewRequest() }
                .buttonStyle(.dnaSecondary(onSheet: true))
        }
        .padding(DNASpacing.gutter)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.dnaSheet.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .onAppear {
            let current = model.lastRecord?.input.budgetMaxKRW
            budget = current
            if let current, !RecommendationRequest.budgetPresets.contains(current) {
                isCustom = true
                budgetText = String(current / 10_000)
            }
        }
    }
}

extension CityRecommendationRecord {
    /// 이번 결과가 사는 나라를 뺀 채 받은 것이고 그 나라에 추천 도시가 있을 때, 그 나라 이름.
    /// 추천을 받던 때의 사는 나라(`homeCountryAtRequest`)를 쓴다. 예전 기록에는 없어 안내하지 않는다.
    func excludedHomeName(catalog: CityCatalog?) -> String? {
        guard let home = homeCountryAtRequest, !input.includeHomeCountry,
              excludedCountries.contains(home),
              catalog?.cities.contains(where: { $0.country == home }) == true else { return nil }
        return CountryCatalog.name(for: home)
    }
}
