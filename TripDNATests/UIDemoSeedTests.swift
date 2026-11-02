import Testing
@testable import TripDNA

@MainActor
struct UIDemoSeedTests {
    /// 모든 시나리오가 인메모리 저장소에 던지지 않고 시드되고, 추천 시나리오는 마지막 결과를 남긴다.
    @Test(arguments: UIDemoSeed.Scenario.allCases)
    func scenarioSeedsIntoInMemoryStore(_ scenario: UIDemoSeed.Scenario) async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let session = SessionStore()
        try await UIDemoSeed.apply(scenario, dependencies: dependencies, session: session)

        #expect(session.isReadyForMainApp)
        let state = try await dependencies.store.cityState()
        let hasRecord = [.recoResult, .recoPhotos, .recoZero, .recoHomeExcluded].contains(scenario)
        #expect((state.lastRecord != nil) == hasRecord)
        if scenario == .recoZero {
            #expect(state.lastRecord?.cards.isEmpty == true)
        }
        if scenario == .recoPhotos {
            #expect(state.lastRecord?.cards.map(\.cityID) == ["kr-seoul", "ch-zurich", "us-washington", "es-valencia", "pl-krakow", "sa-riyadh", "id-denpasar", "sa-mecca", "gb-london", "in-delhi", "ar-buenos-aires", "it-verona", "us-los-angeles", "qa-doha", "vn-nha-trang"])
            #expect(state.lastRecord?.input.wants == "")
            #expect(state.lastRecord?.input.budgetMax == nil)
        }
    }
}
