import Foundation
import Testing
@testable import TripDNA

/// 요청을 보낸 뒤 응답을 기다리는 사이 전체 삭제를 하면, 늦게 온 응답이 질문·추천·추천 로그를 되살리지 않는다.
/// 세대는 저장소마다 따로 있어 다른 테스트와 섞이지 않는다.
@MainActor
struct DeleteAllDuringRequestTests {
    /// `deletes`이면 답을 돌려주기 직전에 전체 삭제를 한다(사용자가 기다리는 사이 삭제한 상황).
    struct QuestionClient: CitySearchClient, @unchecked Sendable {
        let store: any AppStore
        let deletes: Bool
        let reply: CitySearchReply
        func completeWithSearch(system: String, user: String, maxUses: Int) async throws -> CitySearchReply {
            if deletes { try await store.deleteAllUserData() }
            return reply
        }
    }

    /// 추천 본 호출(조건 추출이 아닌 호출)에서 전체 삭제를 한다. 앱의 전체 삭제처럼 추천 로그도 지운다.
    struct RecommendationClient: CityLLMClient, @unchecked Sendable {
        let store: any AppStore
        let log: CityRecommendationLog
        let deletes: Bool
        let inner = CityRecommendationServiceTests.fake()
        func complete(system: String, user: String) async throws -> String {
            if deletes, !user.contains("[Chosen concepts]") {
                try await store.deleteAllUserData()
                try log.deleteAll()
            }
            return try await inner.complete(system: system, user: user)
        }
    }

    static let card = CityRecommendationRecord.Card(
        cityID: "c", cityName: "리스본", country: "PT", isExploration: false, seasonCheckNeeded: false,
        reason: "미식", caveat: "", cost: nil, conditions: [], conditionCheckNeeded: false
    )

    private func askQuestion(deletes: Bool) async throws -> (CityQuestionModel, any AppStore) {
        let store: any AppStore = InMemoryAppStore()
        let reply = try CityQuestionTests.reply(
            CityQuestionTests.fixture(results: CityQuestionTests.okResults, citedURL: "https://a.example/x")
        )
        let model = CityQuestionModel()
        model.makeClient = { QuestionClient(store: store, deletes: deletes, reply: reply) }
        let task = try #require(model.ask("입장료는?", card: Self.card, request: nil, summary: "음식", store: store))
        await task.value
        return (model, store)
    }

    @Test func questionAnsweredAfterDeleteAllIsNotSaved() async throws {
        // 대조: 삭제가 없으면 저장된다(테스트가 저장 경로를 실제로 탄다는 확인).
        let (kept, keptStore) = try await askQuestion(deletes: false)
        #expect(kept.entries.count == 1)
        #expect(try await keptStore.cityState().questions["c"]?.count == 1)

        let (model, store) = try await askQuestion(deletes: true)
        #expect(model.entries.isEmpty)
        #expect(model.status == .idle)
        #expect(try await store.cityState().questions.isEmpty)
    }

    private func recommend(deletes: Bool) async throws -> (CityRecommendationState, CityRecommendationLog) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("delete-during-\(UUID().uuidString)")
        let dependencies = AppDependencies(persistence: .inMemory)
        let log = CityRecommendationLog(directory: dir)
        let model = CityRecommendationViewModel()
        model.log = log
        model.makeClient = { _ in RecommendationClient(store: dependencies.store, log: log, deletes: deletes) }
        await model.run(request: CityRecommendationServiceTests.request(), dependencies: dependencies)
        return (try await dependencies.store.cityState(), log)
    }

    @Test func recommendationArrivingAfterDeleteAllIsNotSavedOrLogged() async throws {
        // 대조: 삭제가 없으면 결과와 로그가 남는다.
        let (keptState, keptLog) = try await recommend(deletes: false)
        defer { try? keptLog.deleteAll() }
        #expect(keptState.lastRecord != nil)
        #expect(keptLog.load().count == 1)

        let (state, log) = try await recommend(deletes: true)
        defer { try? log.deleteAll() }
        #expect(state.lastRecord == nil)
        #expect(state.retryUsageID == nil)
        #expect(log.load().isEmpty)
    }

    /// 확인과 저장 사이에 삭제가 끼어들 수 없다: 삭제 전에 받은 세대로는 삭제 뒤에 저장되지 않는다.
    @Test func staleGenerationCannotWriteToEitherStore() async throws {
        let stores: [any AppStore] = [
            InMemoryAppStore(),
            SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(inMemory: true), countries: [], tags: [])
        ]
        for store in stores {
            let generation = store.dataGeneration.current
            try await store.deleteAllUserData()
            let saved = try await store.updateCityState(ifGeneration: generation) { $0.understandingSeen = true }
            #expect(!saved)
            #expect(try await store.cityState().understandingSeen == false)
            #expect(try await store.updateCityState(ifGeneration: store.dataGeneration.current) { $0.understandingSeen = true })
        }
    }
}
