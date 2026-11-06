import SwiftUI

@Observable
final class CityRecommendationViewModel {
    enum State: Equatable {
        case idle
        case loading
        case done(CityRecommendationRecord)
        case failed(String)
    }

    private(set) var state = State.idle
    /// 무료 한도를 다 쓴 사용자가 추천받기를 누르면 구독 화면을 연다(2026-10-17 결정). 지난 결과는 그대로 둔다.
    var showsSubscription = false
    /// 테스트가 가짜 LLM과 임시 로그 폴더를 넣는다.
    @ObservationIgnored var makeClient: (String) -> (any CityLLMClient)? = { CityLLMConfiguration.makeClient(usageID: $0) }
    @ObservationIgnored var log = CityRecommendationLog.standard

    /// 실패한 추천의 ID는 다음 추천받기에서 한 번 다시 써서(`CityRecommendationState.retryUsageID`), 실패로 무료 횟수를 잃지 않게 한다.
    /// 서버는 ID 하나를 호출 4번까지 1회로 센다. 한도 초과가 아닌 첫 실패만 넘기고, 다시 실패하면 새 ID(1회 차감)로 간다.
    static func retryID(after error: Error, usageID: String, isRetry: Bool) -> String? {
        if isRetry { return nil }
        if case CityRecommendationError.quotaExceeded = error { return nil }
        return usageID
    }
    /// 마지막으로 받은(또는 복원한) 결과. 실패해도 남아 있어 지난 결과를 계속 보여준다.
    private(set) var lastRecord: CityRecommendationRecord?
    private(set) var saved: [SavedCity] = []
    private(set) var excluded: [ExcludedCity] = []
    /// 받은 뒤에 "관심 없어요"로 뺀 나라. 결과를 보여줄 때 거른다.
    private(set) var hiddenCountries: Set<String> = []
    /// 이번 결과에서만 넘긴 도시. 결과와 함께 저장해 복원한다.
    private(set) var skippedCityIDs: Set<String> = []
    private var skipOrder: [String] = []
    /// 방금 "다시 추천하지 않기"한 도시. 되돌리기 안내에 쓴다.
    private(set) var exclusionNotice: ExcludedCity?
    /// 저장·제외를 저장하지 못했을 때 화면에 띄울 짧은 안내.
    private(set) var actionError: String?
    /// 넘기기·제외로 빈 자리를 채운 카드. 이번 결과에서만 쓴다.
    private(set) var refills: [CityRecommendationRecord.Card] = []
    /// 예산만 바꿔 다시 거른 결과를 보는 중일 때 처음 받은 원본. 처음 예산으로 돌아오면 이걸 다시 보여준다.
    private(set) var originalRecord: CityRecommendationRecord?
    /// 방금 예산을 바꾼 안내와 되돌릴 이전 예산. 한 단계만 두고, 복원하거나 새 결과를 받으면 없앤다(저장하지 않는다).
    private(set) var budgetChange: BudgetChange?
    /// 마지막으로 요청한 조건. 실패했을 때 다시 시도에 쓴다.
    private(set) var lastRequest: RecommendationRequest?
    private var task: Task<Void, Never>?
    @ObservationIgnored private var exposure: RecommendationExposure?

    /// 카드가 절반 이상 보였을 때 부른다. 결과가 바뀌면 새 노출 묶음을 연다.
    func recordExposure(_ card: CityRecommendationRecord.Card, screen: String, position: Int, dependencies: AppDependencies) {
        guard case .done(let record) = state else { return }
        if exposure?.id != record.id { exposure = RecommendationExposure(record: record) }
        guard let exposure else { return }
        Task { await exposure.record(card, screen: screen, position: position, dependencies: dependencies) }
    }

    /// "이렇게 이해했어요"를 펼쳐 보일지. 새 결과는 펼쳐서 시작하고, 접은 적 있는 결과를 복원하면 접힌 채로 시작한다.
    private(set) var understandingExpanded = true

    /// 마지막 결과에 비용 범위가 있어 예산만 바꿔 다시 계산할 수 있는지.
    var canEditBudget: Bool { (originalRecord ?? lastRecord)?.input.budgetMax != nil }

    var isConfigured: Bool { CityLLMConfiguration.makeClient() != nil }

    /// 동의를 아직 묻지 않았을 때 채워진다. 화면이 시트로 묻고 `answerConsent`로 답한다.
    private(set) var pendingConsentRequest: RecommendationRequest?

    func isSaved(_ cityID: String) -> Bool { saved.contains { $0.id == cityID } }

    func visibleCards(_ record: CityRecommendationRecord) -> [CityRecommendationRecord.Card] {
        (record.cards + refills).visible(excludedCities: Set(excluded.map(\.cityID)), excludedCountries: hiddenCountries)
            .filter { !skippedCityIDs.contains($0.cityID) }
    }

    // MARK: 복원

    /// 저장한 도시·제외와 마지막 결과를 읽는다. 화면에 올 때마다 불러 설정에서 바뀐 제외를 반영한다.
    func restore(dependencies: AppDependencies) async {
        // 읽지 못하면 기존 목록을 그대로 둔다. 빈 상태로 바꾸지 않는다.
        let loaded = try? await dependencies.store.cityState()
        let stored = loaded ?? CityRecommendationState()
        if loaded != nil { saved = stored.saved; excluded = stored.excluded }
        hiddenCountries = Set((try? await dependencies.recommendationService.activeDislikes())?.map(\.countryCode) ?? [])
        if state == .idle, lastRecord == nil, var record = stored.lastRecord {
            var original = stored.originalRecord
            // 예전 규칙으로 저장된 결과도 지금 규칙(예산을 넘는 추정 도시는 뒤로)으로 보여준다.
            if let catalog = CityCatalog.load() {
                let service = CityRecommendationService(catalog: catalog, client: nil, log: .standard)
                record = service.reselected(record)
                original = original.map(service.reselected)
            }
            lastRecord = record
            originalRecord = original
            lastRequest = record.input
            skipOrder = stored.skippedCityIDs
            skippedCityIDs = Set(skipOrder)
            understandingExpanded = !stored.understandingSeen
            state = .done(record)
        }
        fillVacancies(announce: false)
    }

    // MARK: 추천받기

    struct BudgetChange: Equatable {
        let previous: Int?
        /// 조사까지 붙인 바꾼 예산 문구. 예: "1인 100만 원 이하로", "미정으로".
        /// 바꾼 예산 문구(`budgetText`). 미정으로 바꿨으면 nil.
        let budget: String?
        /// 보이는 카드나 그 순서가 바뀌었는지. 예산을 넘는 추정 도시는 빠지지 않고 뒤로 가므로 개수는 적지 않는다.
        let reordered: Bool

        var message: String {
            if let budget {
                return reordered
                    ? String(localized: "Budget set to \(particled(budget, .euroRo)), so the recommendation order was adjusted")
                    : String(localized: "Budget set to \(particled(budget, .euroRo))")
            }
            return reordered
                ? String(localized: "Budget set to undecided, so the recommendation order was adjusted")
                : String(localized: "Budget set to undecided")
        }
    }

    /// 예산만 바꿔 순서를 다시 계산한다. LLM을 부르지 않는다. 넘긴 도시는 그대로 두고, 보이는 카드가 바뀌었는지를 안내로 남긴다.
    func updateBudget(_ budgetMax: Int?, catalog: CityCatalog? = CityCatalog.load()) {
        guard let before = lastRecord else { return }
        let previous = before.input.budgetMax
        let shown = visibleCards(before).map(\.cityID)
        guard recut(budgetMax, catalog: catalog), let now = lastRecord else { return }
        // 처음 예산으로 돌아오면 원본을 다시 보여주므로 바뀐 안내가 없다.
        guard previous != budgetMax, now.derivedFrom != nil else { budgetChange = nil; return }
        budgetChange = BudgetChange(
            previous: previous, budget: now.input.budgetText, reordered: visibleCards(now).map(\.cityID) != shown
        )
    }

    /// 항상 처음 받은 원본에서 다시 계산한다. 원본의 예산과 같으면 계산 없이 원본을 그대로 쓴다.
    private func recut(_ budgetMax: Int?, catalog: CityCatalog?) -> Bool {
        guard let base = originalRecord ?? lastRecord else { return false }
        let result: CityRecommendationRecord
        if budgetMax == base.input.budgetMax {
            result = base
        } else {
            if CityRecommendationService.rankingPolicyChanged(base) { actionError = Self.policyChanged; return false }
            guard let catalog,
                  let derived = CityRecommendationService(catalog: catalog, client: nil, log: .standard)
                    .recut(base, budgetMax: budgetMax) else { return false }
            result = derived
        }
        originalRecord = result.derivedFrom == nil ? nil : base
        lastRecord = result
        refills = []
        state = .done(result)
        fillVacancies(catalog: catalog ?? CityCatalog.load())
        return true
    }

    func applyBudget(_ budgetMax: Int?, dependencies: AppDependencies) async {
        updateBudget(budgetMax)
        await saveRecuts(dependencies)
    }

    /// 바꾸기 전 예산 조건으로 되돌린다(예산이 없었으면 없는 조건으로). LLM을 부르지 않는다.
    func revertBudget(dependencies: AppDependencies, catalog: CityCatalog? = CityCatalog.load()) async {
        guard let change = budgetChange, recut(change.previous, catalog: catalog) else { return }
        budgetChange = nil
        await saveRecuts(dependencies)
    }

    private func saveRecuts(_ dependencies: AppDependencies) async {
        guard let lastRecord else { return }
        let original = originalRecord
        _ = try? await dependencies.store.updateCityState { $0.lastRecord = lastRecord; $0.originalRecord = original }
    }

    /// 추천받기. 취소할 수 있게 작업을 들고 있는다.
    func begin(request: RecommendationRequest, dependencies: AppDependencies) {
        task?.cancel()
        lastRequest = request
        task = Task { await start(request: request, dependencies: dependencies) }
    }

    func cancel() {
        task?.cancel()
        pendingConsentRequest = nil
        state = lastRecord.map(State.done) ?? .idle
    }

    /// 처음 보내기 전에는 평가가 없어도 동의를 먼저 묻는다(조건·자유문장도 동의 대상, A1).
    private func start(request: RecommendationRequest, dependencies: AppDependencies) async {
        if CityMemoryConsent.state == .undecided {
            pendingConsentRequest = request
            return
        }
        await run(request: request, dependencies: dependencies)
    }

    func answerConsent(_ granted: Bool, dependencies: AppDependencies) {
        CityMemoryConsent.state = granted ? .granted : .declined
        guard let request = pendingConsentRequest else { return }
        pendingConsentRequest = nil
        begin(request: request, dependencies: dependencies)
    }

    func cancelConsent() { pendingConsentRequest = nil }

    func run(request: RecommendationRequest, dependencies: AppDependencies) async {
        guard let catalog = CityCatalog.load() else {
            state = .failed(String(localized: "Couldn't load the city data."))
            return
        }
        state = .loading
        let generation = dependencies.store.dataGeneration.current
        let tiers = (try? await dependencies.store.loadWantedTiers()) ?? WantedConceptTiers()
        var excludedCountries = Set<String>()
        excludedCountries.formUnion((try? await dependencies.recommendationService.activeDislikes())?.map(\.countryCode) ?? [])
        let homeExcluded = dependencies.homeCountryCode != nil && !request.includeHomeCountry
        if homeExcluded, let home = dependencies.homeCountryCode { excludedCountries.insert(home) }
        // 제외 목록을 읽지 못하면 제외한 도시가 다시 나올 수 있으므로 추천을 받지 않는다.
        guard let cityState = try? await dependencies.store.cityState() else {
            state = .failed(String(localized: "Couldn't load your excluded cities. Please try again."))
            return
        }
        // 다녀온 곳은 도시 단위로 뺀다. 나라에 다녀왔다고 그 나라의 다른 도시까지 빼지 않는다.
        let visitedCities = request.includeVisited ? [] : catalog.cityIDs(visitedIn: await dependencies.allTrips())
        let excludedCities = cityState.excludedCityIDs.union(visitedCities)

        let memories = CityMemoryConsent.state == .granted
            ? CityMemory.recent(from: await dependencies.allTrips())
            : []
        let departureAirport = (try? await dependencies.store.loadProfile())?.departureAirportCode
        let usageID = cityState.retryUsageID ?? UUID().uuidString
        let isRetry = cityState.retryUsageID != nil
        if isRetry { _ = try? await dependencies.store.updateCityState { $0.retryUsageID = nil } }
        let service = CityRecommendationService(
            catalog: catalog, client: makeClient(usageID), log: log, dataGeneration: dependencies.store.dataGeneration
        )
        do {
            let record = try await service.recommend(
                request: request, tiers: tiers, excludedCountries: excludedCountries, excludedCities: excludedCities,
                homeCountryExcluded: homeExcluded, homeCountry: dependencies.homeCountryCode,
                departureAirport: departureAirport, memories: memories
            )
            // 기다리는 사이 전체 삭제를 했으면 결과를 버린다.
            guard !Task.isCancelled, dependencies.store.dataGeneration.current == generation else { return }
            lastRecord = record
            originalRecord = nil
            budgetChange = nil
            skippedCityIDs = []
            skipOrder = []
            refills = []
            understandingExpanded = true
            state = .done(record)
            _ = try? await dependencies.store.updateCityState(ifGeneration: generation) {
                $0.lastRecord = record
                $0.originalRecord = nil
                $0.skippedCityIDs = []
                $0.understandingSeen = false
            }
            await dependencies.recordFirstRecommendationIfNeeded(source: "city")
            await dependencies.track(.cityRecommendationReceived)
        } catch {
            guard dependencies.store.dataGeneration.current == generation else { return }
            if let retryID = Self.retryID(after: error, usageID: usageID, isRetry: isRetry) {
                _ = try? await dependencies.store.updateCityState(ifGeneration: generation) { $0.retryUsageID = retryID }
            }
            guard !Task.isCancelled else { return }
            switch error {
            case CityRecommendationError.notConfigured:
                state = .failed(String(localized: "The AI connection isn't set up yet. A proxy URL (CityLLMProxyURL) or a development key is required."))
            case CityRecommendationError.noCandidates:
                state = .failed(String(localized: "Couldn't find a city that matches your conditions."))
            case CityRecommendationError.quotaExceeded(let resetAt):
                let subscribed = await Subscription.isActive()
                state = .failed(CityLLMProxyClient.quotaMessage(String(localized: "recommendations"), resetAt: resetAt, subscribed: subscribed))
                showsSubscription = !subscribed
            default:
                #if DEBUG
                state = .failed(String("Couldn't get recommendations. (\(String(describing: error)))"))
                #else
                // 내부 오류 문자열은 보이지 않는다. 기록(error)에는 남는다.
                state = .failed(String(localized: "Couldn't get recommendations. Check your internet connection and try again."))
                #endif
                await dependencies.track(.cityRecommendationFailed)
            }
        }
    }

    // MARK: 이해한 내용 접기

    /// 스크롤하거나 카드를 넘기면 한 줄로 접고, 다시 열면 접힌 채로 시작하도록 남긴다.
    func collapseUnderstanding(dependencies: AppDependencies) async {
        guard understandingExpanded, lastRecord != nil else { return }
        understandingExpanded = false
        _ = try? await dependencies.store.updateCityState { $0.understandingSeen = true }
    }

    /// 접힌 줄을 누르면 펼친다. 이번 화면에서만이고 저장한 "봤음"은 그대로 둔다.
    func expandUnderstanding() { understandingExpanded = true }

    // MARK: 카드 행동

    /// 이번 결과에서만 넘긴다. 영구 제외가 아니다. 빈 자리는 같은 풀의 다음 도시로 채운다.
    func skip(_ cityID: String, dependencies: AppDependencies) async {
        guard !skippedCityIDs.contains(cityID) else { return }
        let order = skipOrder + [cityID]
        do {
            try await dependencies.store.updateCityState { $0.skippedCityIDs = order }
            skipOrder = order
            skippedCityIDs.insert(cityID)
            actionError = nil
            fillVacancies()
            await dependencies.track(.citySkipped)
        } catch {
            actionError = Self.saveFailure
        }
    }

    static var saveFailure: String { String(localized: "Couldn't save. Please try again.") }
    static var policyChanged: String { String(localized: "Recommendation criteria have changed. Get new recommendations to use this.") }

    func toggleSave(_ card: CityRecommendationRecord.Card, dependencies: AppDependencies) async {
        let request = lastRecord?.input
        let wasSaved = isSaved(card.cityID)
        do {
            let updated = try await dependencies.store.updateCityState {
                if wasSaved { $0.unsave(cityID: card.cityID) } else { $0.save(card, conditionSummary: request?.summaryText ?? "", request: request) }
            }
            saved = updated.saved
            actionError = nil
            if !wasSaved { await dependencies.track(.citySaved) }
        } catch {
            actionError = Self.saveFailure
        }
    }

    /// 도시를 계속 뺀다. 다음 추천의 순위 계산에서 빠지고, 지금 결과에서도 숨긴다. 저장에 실패하면 그대로 둔다.
    func exclude(_ card: CityRecommendationRecord.Card, dependencies: AppDependencies) async {
        do {
            let updated = try await dependencies.store.updateCityState { $0.exclude(card) }
            excluded = updated.excluded
            exclusionNotice = updated.excluded.first { $0.cityID == card.cityID }
            actionError = nil
            fillVacancies()
            await dependencies.track(.cityExcluded)
        } catch {
            actionError = Self.saveFailure
        }
    }

    func undoExclusion(dependencies: AppDependencies) async {
        guard let notice = exclusionNotice else { return }
        do {
            let updated = try await dependencies.store.updateCityState { $0.release(cityID: notice.cityID) }
            excluded = updated.excluded
            exclusionNotice = nil
            actionError = nil
        } catch {
            actionError = Self.saveFailure
        }
    }

    func dismissExclusionNotice() { exclusionNotice = nil }

    func dismissActionError() { actionError = nil }

    /// 넘기거나 제외해 빈 자리가 생기면 저장된 응답에서 다음 도시로 채운다. LLM을 부르지 않는다.
    /// `announce`: 기준이 바뀌어 채울 수 없을 때 이유를 띄울지. 사용자가 넘기기·제외를 했을 때만 띄운다(복원할 때는 띄우지 않음).
    private func fillVacancies(catalog: CityCatalog? = CityCatalog.load(), announce: Bool = true) {
        guard let record = lastRecord else { return }
        let vacancies = record.cards.count - visibleCards(record).count
        guard vacancies > 0, let catalog else { return }
        if CityRecommendationService.rankingPolicyChanged(record) {
            if announce { actionError = Self.policyChanged }
            return
        }
        let service = CityRecommendationService(catalog: catalog, client: nil, log: .standard)
        refills += service.refill(
            record, count: vacancies, shown: Set((record.cards + refills).map(\.cityID)),
            removedCities: skippedCityIDs.union(excluded.map(\.cityID)), removedCountries: hiddenCountries
        )
    }
}

#if DEBUG
/// 개발용 API 키를 Keychain에만 저장한다. 소스·번들·로그에는 남지 않는다. 설정 화면의 "개발용" 항목과 추천 화면에서 연다.
struct DevKeyForm: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var saved = DevAPIKeyStore.read().map { !$0.isEmpty } ?? false

    var body: some View {
        Form {
            Section {
                SecureField(String("Anthropic API Key"), text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Save") {
                    DevAPIKeyStore.save(key)
                    key = ""
                    saved = DevAPIKeyStore.read() != nil
                    dismiss()
                }
                .disabled(key.isEmpty)
                if saved {
                    Button(String("Delete Saved Key"), role: .destructive) {
                        DevAPIKeyStore.save("")
                        saved = false
                    }
                }
            } header: {
                Text(verbatim: saved ? "A key is saved" : "No key saved")
            } footer: {
                Text(verbatim: "Stored only in this device's Keychain. Used in debug builds only.")
            }
        }
        .navigationTitle(Text(verbatim: "Development API Key"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DevKeySheet: View {
    var body: some View {
        NavigationStack { DevKeyForm() }
    }
}
#endif
