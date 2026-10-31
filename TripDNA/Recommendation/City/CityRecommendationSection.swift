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
    var canEditBudget: Bool { (originalRecord ?? lastRecord)?.input.budgetMaxKRW != nil }

    var isConfigured: Bool { CityLLMConfiguration.makeClient() != nil }

    /// 동의를 아직 묻지 않았고 보낼 평가가 있을 때 채워진다. 화면이 시트로 묻고 `answerConsent`로 답한다.
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
        if state == .idle, lastRecord == nil, let record = stored.lastRecord {
            lastRecord = record
            originalRecord = stored.originalRecord
            lastRequest = record.input
            skipOrder = stored.skippedCityIDs
            skippedCityIDs = Set(skipOrder)
            understandingExpanded = !stored.understandingSeen
            state = .done(record)
        }
        fillVacancies()
    }

    // MARK: 추천받기

    struct BudgetChange: Equatable {
        let previous: Int?
        /// 조사까지 붙인 바꾼 예산 문구. 예: "1인 100만 원 이하로", "미정으로".
        let phrase: String
        let removed: Int
        let added: Int

        var message: String {
            if removed > 0 { return "예산을 \(phrase) 바꿔서 \(removed)곳이 빠졌어요" }
            if added > 0 { return "예산을 \(phrase) 바꿔서 \(added)곳이 늘었어요" }
            return "예산을 \(phrase) 바꿨어요"
        }
    }

    /// 예산만 바꿔 컷을 다시 계산한다. LLM을 부르지 않는다. 넘긴 도시는 그대로 두고, 바뀐 만큼을 안내로 남긴다.
    func updateBudget(_ budgetMaxKRW: Int?, catalog: CityCatalog? = CityCatalog.load()) {
        guard let before = lastRecord else { return }
        let previous = before.input.budgetMaxKRW
        let shown = Set(visibleCards(before).map(\.cityID))
        guard recut(budgetMaxKRW, catalog: catalog), let now = lastRecord else { return }
        // 처음 예산으로 돌아오면 원본을 다시 보여주므로 바뀐 안내가 없다.
        guard previous != budgetMaxKRW, now.derivedFrom != nil else { budgetChange = nil; return }
        let after = Set(visibleCards(now).map(\.cityID))
        budgetChange = BudgetChange(
            previous: previous, phrase: now.input.budgetText.map { $0 + "로" } ?? "미정으로",
            removed: shown.subtracting(after).count, added: after.subtracting(shown).count
        )
    }

    /// 항상 처음 받은 원본에서 다시 계산한다. 원본의 예산과 같으면 계산 없이 원본을 그대로 쓴다.
    private func recut(_ budgetMaxKRW: Int?, catalog: CityCatalog?) -> Bool {
        guard let base = originalRecord ?? lastRecord else { return false }
        let result: CityRecommendationRecord
        if budgetMaxKRW == base.input.budgetMaxKRW {
            result = base
        } else {
            guard let catalog,
                  let derived = CityRecommendationService(catalog: catalog, client: nil, log: .standard)
                    .recut(base, budgetMaxKRW: budgetMaxKRW) else { return false }
            result = derived
        }
        originalRecord = result.derivedFrom == nil ? nil : base
        lastRecord = result
        refills = []
        state = .done(result)
        fillVacancies(catalog: catalog ?? CityCatalog.load())
        return true
    }

    func applyBudget(_ budgetMaxKRW: Int?, dependencies: AppDependencies) async {
        updateBudget(budgetMaxKRW)
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

    /// 지난 여행 평가를 처음 보내기 전에는 동의를 먼저 묻는다.
    private func start(request: RecommendationRequest, dependencies: AppDependencies) async {
        if CityMemoryConsent.state == .undecided,
           !CityMemory.recent(from: await dependencies.allTrips()).isEmpty {
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

    private func run(request: RecommendationRequest, dependencies: AppDependencies) async {
        guard let catalog = CityCatalog.load() else {
            state = .failed("도시 자료를 읽지 못했어요.")
            return
        }
        state = .loading
        let tiers = (try? await dependencies.store.loadWantedTiers()) ?? WantedConceptTiers()
        var excludedCountries = Set<String>()
        excludedCountries.formUnion((try? await dependencies.recommendationService.activeDislikes())?.map(\.countryCode) ?? [])
        let homeExcluded = dependencies.homeCountryCode != nil && !request.includeHomeCountry
        if homeExcluded, let home = dependencies.homeCountryCode { excludedCountries.insert(home) }
        // 제외 목록을 읽지 못하면 제외한 도시가 다시 나올 수 있으므로 추천을 받지 않는다.
        guard let storedExcludedCities = try? await dependencies.store.cityState().excludedCityIDs else {
            state = .failed("제외한 도시를 읽지 못했어요. 다시 시도해 주세요.")
            return
        }
        // 다녀온 곳은 도시 단위로 뺀다. 나라에 다녀왔다고 그 나라의 다른 도시까지 빼지 않는다.
        let visitedCities = request.includeVisited ? [] : catalog.cityIDs(visitedIn: await dependencies.allTrips())
        let excludedCities = storedExcludedCities.union(visitedCities)

        let memories = CityMemoryConsent.state == .granted
            ? CityMemory.recent(from: await dependencies.allTrips())
            : []
        let service = CityRecommendationService(
            catalog: catalog, client: CityLLMConfiguration.makeClient(), log: .standard
        )
        do {
            let record = try await service.recommend(
                request: request, tiers: tiers, excludedCountries: excludedCountries, excludedCities: excludedCities,
                homeCountryExcluded: homeExcluded, homeCountry: dependencies.homeCountryCode, memories: memories
            )
            guard !Task.isCancelled else { return }
            lastRecord = record
            originalRecord = nil
            budgetChange = nil
            skippedCityIDs = []
            skipOrder = []
            refills = []
            understandingExpanded = true
            state = .done(record)
            _ = try? await dependencies.store.updateCityState {
                $0.lastRecord = record
                $0.originalRecord = nil
                $0.skippedCityIDs = []
                $0.understandingSeen = false
            }
            await dependencies.recordFirstRecommendationIfNeeded(source: "city")
            await dependencies.track(.cityRecommendationReceived)
        } catch {
            guard !Task.isCancelled else { return }
            switch error {
            case CityRecommendationError.notConfigured:
                state = .failed("LLM 연결이 아직 준비되지 않았어요. 프록시 주소(CityLLMProxyURL) 또는 개발용 키가 필요해요.")
            case CityRecommendationError.noCandidates:
                state = .failed("조건에 맞는 도시를 찾지 못했어요.")
            default:
                state = .failed("추천을 받지 못했어요. 다시 시도해 주세요. (\(error))")
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

    static let saveFailure = "저장하지 못했어요. 다시 시도해 주세요."

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
    private func fillVacancies(catalog: CityCatalog? = CityCatalog.load()) {
        guard let record = lastRecord else { return }
        let vacancies = record.cards.count - visibleCards(record).count
        guard vacancies > 0, let catalog else { return }
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
                SecureField("Anthropic API 키", text: $key)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("저장") {
                    DevAPIKeyStore.save(key)
                    key = ""
                    saved = DevAPIKeyStore.read() != nil
                    dismiss()
                }
                .disabled(key.isEmpty)
                if saved {
                    Button("저장된 키 지우기", role: .destructive) {
                        DevAPIKeyStore.save("")
                        saved = false
                    }
                }
            } header: {
                Text(saved ? "저장된 키가 있어요" : "저장된 키가 없어요")
            } footer: {
                Text("이 기기의 Keychain에만 저장돼요. 디버그 빌드에서만 쓰여요.")
            }
        }
        .navigationTitle("개발용 API 키")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DevKeySheet: View {
    var body: some View {
        NavigationStack { DevKeyForm() }
    }
}
#endif
