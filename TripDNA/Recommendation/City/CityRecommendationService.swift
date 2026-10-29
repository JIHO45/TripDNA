import Foundation

/// 추천 한 번의 입력·버전·결과. docs/evaluation/mvp-tester-log.md의 "입력"과 "받은 도시"에 대응한다.
/// 요청 문장과 티어가 들어 있어 기기 밖으로 내보내지 않는다.
nonisolated struct CityRecommendationRecord: Codable, Equatable, Sendable, Identifiable {
    struct Card: Codable, Equatable, Sendable {
        let cityID: String
        let cityName: String
        let country: String
        let isExploration: Bool
        let seasonCheckNeeded: Bool
        let reason: String
        let caveat: String
        /// LLM의 예상 총비용 범위(원). 예산이 없으면 nil. 검증되지 않은 추정이다.
        let cost: CostRange?
        /// 자유문장 조건의 코드 판정 결과.
        let conditions: [ConditionResult]
        /// 필수 조건을 확인하지 못해 "추가 확인 필요" 묶음에 속하는지.
        let conditionCheckNeeded: Bool
    }

    /// 1단계(조건 추출) 호출의 입력과 응답. 재현·검토용.
    struct Extraction: Codable, Equatable, Sendable {
        let system: String
        let user: String
        let raw: String?
        let error: String?
    }

    let id: String
    /// 예산만 바꿔 다시 계산한 경우 원래 추천의 id. LLM을 다시 부르지 않았다.
    var derivedFrom: String?
    let createdAt: Date
    let version: CityInputVersion
    let seed: UInt64
    let input: RecommendationRequest
    let tiers: WantedConceptTiers
    let excludedCountries: [String]
    /// 순위 계산에서 뺀 도시 id. 예전 기록에는 없다.
    var excludedCityIDs: [String]?
    /// 코드가 계산한 순위 상위 id. 같은 입력과 시드로 다시 계산해 대조할 수 있다.
    let rankedCityIDs: [String]
    /// LLM이 설명·비용을 낸 후보(순위 상위). 카드는 이 중 예산 컷을 통과한 도시에서 고른다.
    let poolCityIDs: [String]
    /// 예상 비용 범위의 아래쪽이 예산보다 커서 컷된 도시.
    let budgetCutCityIDs: [String]
    /// LLM에 보낸 그대로. 프롬프트·표를 다시 만들지 않고도 재현·검토할 수 있다.
    /// 코드가 받아들인 자유문장 조건과, 근거 원문이 없거나 판정할 수 없어 버린 조건 id.
    let conditions: [CityCondition]
    let rejectedConditionIDs: [String]
    let extraction: Extraction?
    /// 동의하고 보낸 지난 여행 평가와, 응답이 실제로 반영했다고 적은 것.
    let memories: [CityMemory]
    let memoriesUsed: [CityLLMResponse.MemoryUse]
    let system: String
    let user: String
    let rawResponse: String?
    let understanding: String?
    let cards: [Card]
    let error: String?
    let latencySeconds: Double
}

/// 기기의 Application Support에 레코드를 한 파일씩 남긴다.
nonisolated struct CityRecommendationLog: Sendable {
    let directory: URL

    static var standard: CityRecommendationLog {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return CityRecommendationLog(directory: base.appendingPathComponent("CityRecommendationLogs", isDirectory: true))
    }

    func save(_ record: CityRecommendationRecord) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(record).write(
            to: directory.appendingPathComponent("\(record.id).json"), options: .completeFileProtection
        )
    }

    /// 전체 데이터 삭제용. 폴더가 없으면 할 일이 없다.
    func deleteAll() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    func load() -> [CityRecommendationRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }
            .compactMap { (try? Data(contentsOf: $0)).flatMap { try? decoder.decode(CityRecommendationRecord.self, from: $0) } }
            .sorted { $0.createdAt > $1.createdAt }
    }
}

nonisolated enum CityRecommendationError: Error, Equatable {
    case notReady
    case notConfigured
    case noCandidates
    case extractionFailed(String)
    case invalidResponse(String)
    case network(String)
}

nonisolated struct CityRecommendationService: Sendable {
    let catalog: CityCatalog
    let client: (any CityLLMClient)?
    let log: CityRecommendationLog
    var model = CityLLMConfiguration.model

    /// 조건 필터(제외 나라·시즌)와 순위 계산은 코드가, 설명은 LLM이 한다. 성공이든 실패든 레코드를 남긴다.
    func recommend(
        request: RecommendationRequest,
        tiers: WantedConceptTiers,
        excludedCountries: Set<String>,
        excludedCities: Set<String> = [],
        homeCountryExcluded: Bool,
        memories: [CityMemory] = [],
        seed: UInt64 = UInt64.random(in: .min ... .max),
        now: Date = Date()
    ) async throws -> CityRecommendationRecord {
        guard let primary = request.primary else { throw CityRecommendationError.notReady }
        let month = request.month ?? request.startDate.map { Calendar.current.component(.month, from: $0) }
        var input = CityRankingInput(primary: primary, secondary: request.secondary, tiers: tiers, month: month)
        input.seed = seed
        input.excludedCountries = excludedCountries
        input.excludedCities = excludedCities

        // 1단계: 자유문장이 있으면 조건을 먼저 뽑는다. 실패해도 조건 없이 진행하고 기록에 남긴다.
        var conditions: [CityCondition] = []
        var rejected: [String] = []
        var extraction: CityRecommendationRecord.Extraction?
        var extractionFailure: String?
        let userText = request.wants + "\n" + request.avoids
        if let client, !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let prompt = CityConditionExtraction.build(request: request, catalog: catalog)
            var rawExtraction: String?
            var extractionError: String?
            do {
                rawExtraction = try await client.complete(system: prompt.system, user: prompt.user)
                let parsedConditions = try CityResponseValidator.parseConditions(rawExtraction ?? "")
                (conditions, rejected) = CityConditionJudge.accept(parsedConditions, userText: userText, catalog: catalog)
            } catch {
                extractionError = String(describing: error)
                extractionFailure = extractionError
            }
            extraction = .init(system: prompt.system, user: prompt.user, raw: rawExtraction, error: extractionError)
        }
        input.conditions = conditions
        let ranked = CityRanker.rank(catalog: catalog, input: input)
        let pool = Array(ranked.prefix(CityLLMRequestBuilder.poolSize))
        guard !pool.isEmpty else { throw CityRecommendationError.noCandidates }

        input.excludedCountries = []
        let excludedRanked = CityRanker.rank(catalog: catalog, input: input)
            .filter { excludedCountries.contains($0.city.country) }
        let llmRequest = CityLLMRequestBuilder.build(
            context: .init(
                request: request, tiers: tiers, catalog: catalog, model: model,
                excludedCountries: excludedCountries, homeCountryExcluded: homeCountryExcluded,
                conditions: conditions, memories: memories
            ),
            ranked: ranked, excludedRanked: excludedRanked, pool: pool
        )

        var raw: String?
        var parsed: CityLLMResponse?
        var failure: CityRecommendationError?
        let start = Date()
        if let extractionFailure {
            // 필수 조건이 사라진 채 정상 추천처럼 보이지 않도록 2단계를 부르지 않고 중단한다.
            failure = .extractionFailed(extractionFailure)
        } else if let client {
            do {
                raw = try await client.complete(system: llmRequest.system, user: llmRequest.user)
                parsed = try CityResponseValidator.validate(
                    CityResponseValidator.parse(raw ?? ""), cardIDs: llmRequest.cardIDs,
                    requiresCost: llmRequest.requiresCost, memoryIDs: Set(memories.map(\.id))
                )
            } catch let error as CityResponseError {
                var detail = String(describing: error)
                #if DEBUG
                // 기기에서 테스트할 때 원인을 바로 보도록 응답 앞부분을 붙인다. 출시 빌드에는 없다.
                detail += " · " + String((raw ?? "").prefix(300))
                #endif
                failure = .invalidResponse(detail)
            } catch CityLLMError.truncated {
                failure = .invalidResponse("truncated")
            } catch {
                failure = .network(String(describing: error))
            }
        } else {
            failure = .notConfigured
        }

        var selection = Selection(cards: [], cutIDs: [])
        if let parsed {
            selection = Self.select(pool: pool, response: parsed, budget: request.budgetMaxKRW, seed: seed)
        }
        let record = CityRecommendationRecord(
            id: UUID().uuidString, derivedFrom: nil, createdAt: now, version: llmRequest.version, seed: seed,
            input: request, tiers: tiers, excludedCountries: excludedCountries.sorted(),
            excludedCityIDs: excludedCities.sorted(),
            rankedCityIDs: ranked.prefix(CityLLMRequestBuilder.tableLimit).map(\.city.id),
            poolCityIDs: pool.map(\.city.id), budgetCutCityIDs: selection.cutIDs,
            conditions: conditions, rejectedConditionIDs: rejected, extraction: extraction,
            memories: memories, memoriesUsed: parsed?.memoriesUsed ?? [],
            system: llmRequest.system, user: llmRequest.user,
            rawResponse: raw, understanding: parsed?.understanding, cards: selection.cards,
            error: failure.map { String(describing: $0) } ?? (parsed != nil && selection.cards.isEmpty ? "noneWithinBudget" : nil), latencySeconds: Date().timeIntervalSince(start)
        )
        try? log.save(record)
        if let failure { throw failure }
        return record
    }

    struct Selection {
        var cards: [CityRecommendationRecord.Card]
        var cutIDs: [String]
    }

    /// 예산 컷: 예상 비용 범위의 아래쪽이 예산을 넘으면 후보에서 뺀다. 컷 뒤 남은 도시에서 카드를 고른다.
    static func select(pool: [RankedCity], response: CityLLMResponse, budget: Int?, seed: UInt64) -> Selection {
        let byID = Dictionary(uniqueKeysWithValues: response.cards.map { ($0.id, $0) })
        var cutIDs: [String] = []
        let survivors = pool.filter { item in
            guard let budget, let low = byID[item.city.id]?.cost?.low else { return true }
            if low > budget { cutIDs.append(item.city.id); return false }
            return true
        }
        let cards: [CityRecommendationRecord.Card] = CityRanker.pickCards(from: survivors, seed: seed).compactMap { pick in
            byID[pick.ranked.city.id].map { card in
                .init(
                    cityID: pick.ranked.city.id, cityName: pick.ranked.city.ko, country: pick.ranked.city.country,
                    isExploration: pick.isExploration, seasonCheckNeeded: pick.ranked.status == .needsSeasonCheck,
                    reason: card.reason, caveat: card.caveat, cost: card.cost,
                    conditions: pick.ranked.conditionResults, conditionCheckNeeded: pick.ranked.needsConditionCheck
                )
            }
        }
        return Selection(cards: cards, cutIDs: cutIDs)
    }

    /// 저장된 응답과 같은 입력으로 후보 풀을 다시 계산한다. 풀이 기록과 다르면(카탈로그가 바뀜) nil.
    private func replay(_ record: CityRecommendationRecord) -> (pool: [RankedCity], response: CityLLMResponse)? {
        guard let raw = record.rawResponse, let response = try? CityResponseValidator.parse(raw),
              let primary = record.input.primary else { return nil }
        let month = record.input.month ?? record.input.startDate.map { Calendar.current.component(.month, from: $0) }
        let input = CityRankingInput(
            primary: primary, secondary: record.input.secondary, tiers: record.tiers, month: month,
            excludedCountries: Set(record.excludedCountries), excludedCities: Set(record.excludedCityIDs ?? []),
            seed: record.seed, conditions: record.conditions
        )
        let pool = Array(CityRanker.rank(catalog: catalog, input: input).prefix(CityLLMRequestBuilder.poolSize))
        // 원문에는 검사에서 버린 후보 밖 카드가 남아 있다. 여기서도 버려야 같은 id가 겹쳐도 select가 멈추지 않는다.
        return pool.map(\.city.id) == record.poolCityIDs ? (pool, response.keepingCards(in: record.poolCityIDs)) : nil
    }

    /// 넘기기·제외로 빈 자리를 채울 카드. 저장된 응답에서 같은 풀의 다음 도시를 코드 순서대로 고르며 LLM을 부르지 않는다.
    /// `shown`(이번 결과에서 이미 보여준 도시)과 `removedCities`·`removedCountries`는 다시 나오지 않는다. 남은 도시가 없으면 적게 돌려준다.
    func refill(
        _ record: CityRecommendationRecord, count: Int, shown: Set<String>,
        removedCities: Set<String>, removedCountries: Set<String>
    ) -> [CityRecommendationRecord.Card] {
        guard count > 0, let (pool, response) = replay(record) else { return [] }
        let candidates = pool.filter {
            !shown.contains($0.city.id) && !removedCities.contains($0.city.id) && !removedCountries.contains($0.city.country)
        }
        let selection = Self.select(pool: candidates, response: response, budget: record.input.budgetMaxKRW, seed: record.seed)
        return Array(selection.cards.prefix(count))
    }

    /// 예산만 바꿔 컷을 다시 계산한다. 이미 받은 응답을 쓰므로 LLM을 부르지 않고 횟수도 쓰지 않는다.
    /// 원래 추천에 예산이 없어 비용 범위가 없으면 nil.
    func recut(_ record: CityRecommendationRecord, budgetMaxKRW: Int?, now: Date = Date()) -> CityRecommendationRecord? {
        guard let (pool, response) = replay(record), response.cards.allSatisfy({ $0.cost != nil }) else { return nil }
        var request = record.input
        request.budgetMaxKRW = budgetMaxKRW
        let selection = Self.select(pool: pool, response: response, budget: budgetMaxKRW, seed: record.seed)
        let derived = CityRecommendationRecord(
            id: UUID().uuidString, derivedFrom: record.id, createdAt: now, version: record.version, seed: record.seed,
            input: request, tiers: record.tiers, excludedCountries: record.excludedCountries,
            excludedCityIDs: record.excludedCityIDs,
            rankedCityIDs: record.rankedCityIDs, poolCityIDs: record.poolCityIDs, budgetCutCityIDs: selection.cutIDs,
            conditions: record.conditions, rejectedConditionIDs: record.rejectedConditionIDs, extraction: record.extraction,
            memories: record.memories, memoriesUsed: record.memoriesUsed,
            system: record.system, user: record.user, rawResponse: record.rawResponse,
            understanding: nil, cards: selection.cards,
            error: selection.cards.isEmpty ? "noneWithinBudget" : nil, latencySeconds: 0
        )
        try? log.save(derived)
        return derived
    }
}
