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
    /// 이번 결과에서만 넘긴 도시. 저장하지 않는다.
    private(set) var skippedCityIDs: Set<String> = []
    /// 방금 "다시 추천하지 않기"한 도시. 되돌리기 안내에 쓴다.
    private(set) var exclusionNotice: ExcludedCity?
    /// 저장·제외를 저장하지 못했을 때 화면에 띄울 짧은 안내.
    private(set) var actionError: String?
    /// 넘기기·제외로 빈 자리를 채운 카드. 이번 결과에서만 쓴다.
    private(set) var refills: [CityRecommendationRecord.Card] = []
    /// 마지막으로 요청한 조건. 실패했을 때 다시 시도에 쓴다.
    private(set) var lastRequest: RecommendationRequest?
    private var task: Task<Void, Never>?

    /// 마지막 결과에 비용 범위가 있어 예산만 바꿔 다시 계산할 수 있는지.
    var canEditBudget: Bool { lastRecord?.input.budgetMaxKRW != nil }

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
            lastRequest = record.input
            state = .done(record)
        }
        fillVacancies()
    }

    // MARK: 추천받기

    /// 예산만 바꿔 컷을 다시 계산한다. LLM을 부르지 않는다.
    func updateBudget(_ budgetMaxKRW: Int, catalog: CityCatalog? = CityCatalog.load()) {
        guard let lastRecord, let catalog else { return }
        let service = CityRecommendationService(catalog: catalog, client: nil, log: .standard)
        if let derived = service.recut(lastRecord, budgetMaxKRW: budgetMaxKRW) {
            self.lastRecord = derived
            skippedCityIDs = []
            refills = []
            state = .done(derived)
        }
    }

    func applyBudget(_ budgetMaxKRW: Int, dependencies: AppDependencies) async {
        updateBudget(budgetMaxKRW)
        if let lastRecord { try? await dependencies.store.updateCityState { $0.lastRecord = lastRecord } }
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
        if !request.includeVisited {
            excludedCountries.formUnion(await dependencies.allTrips().flatMap { $0.legs.map(\.countryCode) })
        }
        excludedCountries.formUnion((try? await dependencies.recommendationService.activeDislikes())?.map(\.countryCode) ?? [])
        let homeExcluded = dependencies.homeCountryCode != nil && !request.includeHomeCountry
        if homeExcluded, let home = dependencies.homeCountryCode { excludedCountries.insert(home) }
        // 제외 목록을 읽지 못하면 제외한 도시가 다시 나올 수 있으므로 추천을 받지 않는다.
        guard let excludedCities = try? await dependencies.store.cityState().excludedCityIDs else {
            state = .failed("제외한 도시를 읽지 못했어요. 다시 시도해 주세요.")
            return
        }

        let memories = CityMemoryConsent.state == .granted
            ? CityMemory.recent(from: await dependencies.allTrips())
            : []
        let service = CityRecommendationService(
            catalog: catalog, client: CityLLMConfiguration.makeClient(), log: .standard
        )
        do {
            let record = try await service.recommend(
                request: request, tiers: tiers, excludedCountries: excludedCountries, excludedCities: excludedCities,
                homeCountryExcluded: homeExcluded, memories: memories
            )
            guard !Task.isCancelled else { return }
            lastRecord = record
            skippedCityIDs = []
            refills = []
            state = .done(record)
            try? await dependencies.store.updateCityState { $0.lastRecord = record }
        } catch {
            guard !Task.isCancelled else { return }
            switch error {
            case CityRecommendationError.notConfigured:
                state = .failed("LLM 연결이 아직 준비되지 않았어요. 프록시 주소(CityLLMProxyURL) 또는 개발용 키가 필요해요.")
            case CityRecommendationError.noCandidates:
                state = .failed("조건에 맞는 도시를 찾지 못했어요.")
            default:
                state = .failed("추천을 받지 못했어요. 다시 시도해 주세요. (\(error))")
            }
        }
    }

    // MARK: 카드 행동

    /// 이번 결과에서만 넘긴다. 영구 제외가 아니다. 빈 자리는 같은 풀의 다음 도시로 채운다.
    func skip(_ cityID: String) {
        skippedCityIDs.insert(cityID)
        fillVacancies()
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
