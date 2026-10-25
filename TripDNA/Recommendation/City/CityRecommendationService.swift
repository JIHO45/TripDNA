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
    /// 코드가 계산한 순위 상위 id. 같은 입력과 시드로 다시 계산해 대조할 수 있다.
    let rankedCityIDs: [String]
    /// LLM이 설명·비용을 낸 후보(순위 상위). 카드는 이 중 예산 컷을 통과한 도시에서 고른다.
    let poolCityIDs: [String]
    /// 예상 비용 범위의 아래쪽이 예산보다 커서 컷된 도시.
    let budgetCutCityIDs: [String]
    /// LLM에 보낸 그대로. 프롬프트·표를 다시 만들지 않고도 재현·검토할 수 있다.
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
        homeCountryExcluded: Bool,
        seed: UInt64 = UInt64.random(in: .min ... .max),
        now: Date = Date()
    ) async throws -> CityRecommendationRecord {
        guard let primary = request.primary else { throw CityRecommendationError.notReady }
        let month = request.month ?? request.startDate.map { Calendar.current.component(.month, from: $0) }
        var input = CityRankingInput(primary: primary, secondary: request.secondary, tiers: tiers, month: month)
        input.seed = seed
        input.excludedCountries = excludedCountries
        let ranked = CityRanker.rank(catalog: catalog, input: input)
        let pool = Array(ranked.prefix(CityLLMRequestBuilder.poolSize))
        guard !pool.isEmpty else { throw CityRecommendationError.noCandidates }

        input.excludedCountries = []
        let excludedRanked = CityRanker.rank(catalog: catalog, input: input)
            .filter { excludedCountries.contains($0.city.country) }
        let llmRequest = CityLLMRequestBuilder.build(
            context: .init(
                request: request, tiers: tiers, catalog: catalog, model: model,
                excludedCountries: excludedCountries, homeCountryExcluded: homeCountryExcluded
            ),
            ranked: ranked, excludedRanked: excludedRanked, pool: pool
        )

        var raw: String?
        var parsed: CityLLMResponse?
        var failure: CityRecommendationError?
        let start = Date()
        if let client {
            do {
                raw = try await client.complete(system: llmRequest.system, user: llmRequest.user)
                let response = try CityResponseValidator.parse(raw ?? "")
                try CityResponseValidator.validate(
                    response, cardIDs: llmRequest.cardIDs, requiresCost: llmRequest.requiresCost
                )
                parsed = response
            } catch let error as CityResponseError {
                failure = .invalidResponse(String(describing: error))
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
            rankedCityIDs: ranked.prefix(CityLLMRequestBuilder.tableLimit).map(\.city.id),
            poolCityIDs: pool.map(\.city.id), budgetCutCityIDs: selection.cutIDs,
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
                    reason: card.reason, caveat: card.caveat, cost: card.cost
                )
            }
        }
        return Selection(cards: cards, cutIDs: cutIDs)
    }

    /// 예산만 바꿔 컷을 다시 계산한다. 이미 받은 응답을 쓰므로 LLM을 부르지 않고 횟수도 쓰지 않는다.
    /// 원래 추천에 예산이 없어 비용 범위가 없으면 nil.
    func recut(_ record: CityRecommendationRecord, budgetMaxKRW: Int?, now: Date = Date()) -> CityRecommendationRecord? {
        guard let raw = record.rawResponse, let response = try? CityResponseValidator.parse(raw),
              response.cards.allSatisfy({ $0.cost != nil }),
              let primary = record.input.primary else { return nil }
        let month = record.input.month ?? record.input.startDate.map { Calendar.current.component(.month, from: $0) }
        let input = CityRankingInput(
            primary: primary, secondary: record.input.secondary, tiers: record.tiers, month: month,
            excludedCountries: Set(record.excludedCountries), seed: record.seed
        )
        let pool = Array(CityRanker.rank(catalog: catalog, input: input).prefix(CityLLMRequestBuilder.poolSize))
        guard pool.map(\.city.id) == record.poolCityIDs else { return nil }
        var request = record.input
        request.budgetMaxKRW = budgetMaxKRW
        let selection = Self.select(pool: pool, response: response, budget: budgetMaxKRW, seed: record.seed)
        let derived = CityRecommendationRecord(
            id: UUID().uuidString, derivedFrom: record.id, createdAt: now, version: record.version, seed: record.seed,
            input: request, tiers: record.tiers, excludedCountries: record.excludedCountries,
            rankedCityIDs: record.rankedCityIDs, poolCityIDs: record.poolCityIDs, budgetCutCityIDs: selection.cutIDs,
            system: record.system, user: record.user, rawResponse: record.rawResponse,
            understanding: record.understanding, cards: selection.cards,
            error: selection.cards.isEmpty ? "noneWithinBudget" : nil, latencySeconds: 0
        )
        try? log.save(derived)
        return derived
    }
}
