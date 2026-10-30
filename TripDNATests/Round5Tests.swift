import Foundation
import Testing
@testable import TripDNA

@MainActor
struct OnboardingConceptEditTests {
    private func registered(_ dependencies: AppDependencies, _ primary: TripConcept, _ secondary: [TripConcept]) async throws -> Trip {
        let start = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let trip = try Trip(
            legs: [TripLeg(countryCode: "JP", cities: ["교토"], startDate: start, endDate: start)],
            companion: .alone, purpose: .leisure, concepts: TripConcepts(primary: primary, secondary: secondary)
        )
        try await dependencies.store.create(trip)
        return trip
    }

    /// 직접 등록으로 컨셉이 이미 있는 여행도 수정 대상이고, 들어가면 저장된 주·보조 컨셉이 보인다.
    @Test func editLoadsSavedConceptsAndKeepsSecondaryWhenOnlyPrimaryChanges() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        let trip = try await registered(dependencies, .food, [.shopping, .relaxation])
        let viewModel = OnboardingViewModel()
        await viewModel.finishManualRegistration(dependencies: dependencies)
        #expect(viewModel.conceptQueue.isEmpty)   // 컨셉이 있어 "컨셉 없는 여행" 큐는 비어 있다
        #expect(viewModel.stage == .tiers)

        viewModel.editTripConcepts()
        #expect(viewModel.stage == .concepts)
        #expect(viewModel.conceptQueue == [trip.id])
        #expect(viewModel.conceptPrimary == .food)
        #expect(viewModel.conceptSecondary == [.shopping, .relaxation])

        viewModel.selectConceptPrimary(.cultureHistory)
        await viewModel.saveCurrentConcept(dependencies: dependencies)
        #expect(viewModel.stage == .summary)   // 끝나면 확인 화면으로 돌아간다
        let saved = try await dependencies.store.trip(id: trip.id)?.concepts
        #expect(saved?.primary == .cultureHistory)
        #expect(saved?.secondary == [.shopping, .relaxation])
    }

    @Test func editWalksEveryRecordedTripAndShowsEachOnesChoice() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        _ = try await registered(dependencies, .food, [.shopping])
        _ = try await registered(dependencies, .relaxation, [])
        let viewModel = OnboardingViewModel()
        await viewModel.finishManualRegistration(dependencies: dependencies)
        viewModel.editTripConcepts()
        #expect(viewModel.conceptQueue.count == 2)
        let first = viewModel.conceptPrimary
        await viewModel.saveCurrentConcept(dependencies: dependencies)
        #expect(viewModel.stage == .concepts)
        #expect(viewModel.conceptPrimary != nil && viewModel.conceptPrimary != first)
    }
}

struct DemoIsolationTests {
    @Test func isolatedDefaultsDoNotTouchStandard() {
        let key = "tripdna.isolationTest.\(UUID().uuidString)"
        let isolated = AppStorageLocation.makeDefaults(isolated: true)
        isolated.set(true, forKey: key)
        #expect(UserDefaults.standard.object(forKey: key) == nil)
        isolated.removeObject(forKey: key)
        #expect(AppStorageLocation.makeDefaults(isolated: false) === UserDefaults.standard)
    }

    @Test func isolatedDirectoryIsOutsideRealOne() {
        let real = AppStorageLocation.directory(.documentDirectory, isolated: false)
        let demo = AppStorageLocation.directory(.documentDirectory, isolated: true)
        #expect(demo != real)
        #expect(demo.path.hasPrefix(FileManager.default.temporaryDirectory.path))
    }
}

@MainActor
struct DemoRecoSeedTests {
    @Test(arguments: [UIDemoSeed.Scenario.recoResult, .recoZero, .recoHomeExcluded])
    func seededRecordCanRecutAndRefill(_ scenario: UIDemoSeed.Scenario) async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        try await UIDemoSeed.apply(scenario, dependencies: dependencies, session: SessionStore())
        let record = try #require(try await dependencies.store.cityState().lastRecord)
        #expect(record.rawResponse != nil)
        #expect(!record.poolCityIDs.isEmpty)
        #expect(record.cards.allSatisfy { record.poolCityIDs.contains($0.cityID) && !record.budgetCutCityIDs.contains($0.cityID) })

        let service = CityRecommendationService(
            catalog: try #require(CityCatalog.load()), client: nil,
            log: CityRecommendationLog(directory: FileManager.default.temporaryDirectory.appendingPathComponent("demo-reco-test"))
        )
        let recut = try #require(service.recut(record, budgetMaxKRW: 2_000_000))
        #expect(!recut.cards.isEmpty)
        #expect(recut.budgetCutCityIDs.isEmpty)
        if scenario == .recoZero { #expect(record.cards.isEmpty) }
    }
}

@MainActor
struct HomeCountryAtRequestTests {
    private func seeded() async throws -> CityRecommendationRecord {
        let dependencies = AppDependencies(persistence: .inMemory)
        try await UIDemoSeed.apply(.recoHomeExcluded, dependencies: dependencies, session: SessionStore())
        return try #require(try await dependencies.store.cityState().lastRecord)
    }

    /// 예전 기록(필드 없음)은 nil로 읽히고 안내하지 않는다.
    @Test func oldRecordsDecodeWithoutHomeAndShowNoNotice() async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try #require(JSONSerialization.jsonObject(with: encoder.encode(try await seeded())) as? [String: Any])
        object.removeValue(forKey: "homeCountryAtRequest")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let old = try decoder.decode(CityRecommendationRecord.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(old.homeCountryAtRequest == nil)
        #expect(old.excludedHomeName(catalog: CityCatalog.load()) == nil)
    }

    /// 안내는 기록에 남은 값만 보므로 현재 설정(dependencies)이 바뀌어도 같다.
    @Test func noticeUsesHomeCountryStoredInRecord() async throws {
        let catalog = CityCatalog.load()
        var record = try await seeded()
        #expect(record.homeCountryAtRequest == "JP")
        #expect(record.excludedHomeName(catalog: catalog) == "일본")
        record.homeCountryAtRequest = "KR"   // 제외 목록에 없는 나라
        #expect(record.excludedHomeName(catalog: catalog) == nil)
    }

    @Test func collapsedLineNoLongerCarriesTheExclusion() {
        var request = RecommendationRequest()
        request.setPrimary(.food)
        #expect(!request.collapsedLine(required: ["비행 5시간 이내"]).contains("제외"))
    }
}
