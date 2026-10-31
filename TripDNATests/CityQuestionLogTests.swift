import Foundation
import Testing
@testable import TripDNA

struct CityQuestionLogTests {
    static func entry(_ question: String) -> CityQuestionEntry {
        let source = CityAnswer.Source(title: "공식", url: URL(string: "https://example.com")!, published: nil, retrievedAt: Date(timeIntervalSince1970: 0))
        return CityQuestionEntry(
            question: question, askedAt: Date(timeIntervalSince1970: 100), conditionSummary: "미식 · 11월",
            answer: CityAnswer(evidence: "근거", advice: "조언", unconfirmed: "", sources: [source], searchFailed: false)
        )
    }

    @Test func questionsSurviveReopenAndStayPerCity() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let store = SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(url: url), countries: [], tags: [])
            try await store.updateCityState {
                $0.addQuestion(Self.entry("첫 질문"), cityID: "osaka")
                $0.addQuestion(Self.entry("둘째 질문"), cityID: "osaka")
                $0.addQuestion(Self.entry("교토 질문"), cityID: "kyoto")
            }
        }
        let reopened = SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(url: url), countries: [], tags: [])
        let questions = try await reopened.cityState().questions
        #expect(questions["osaka"]?.map(\.question) == ["첫 질문", "둘째 질문"])
        #expect(questions["osaka"]?.first?.answer.sources.first?.url.absoluteString == "https://example.com")
        #expect(questions["kyoto"]?.count == 1)
    }

    /// 예전 저장 데이터(질문 키 없음)와 읽을 수 없는 질문 기록은 빈 기록으로 읽고, 저장한 도시는 잃지 않는다.
    @Test func oldOrBrokenDataKeepsOtherState() throws {
        var state = CityRecommendationState()
        state.save(CityStateTests.card("kyoto"), conditionSummary: "x")
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        json.removeValue(forKey: "questions")
        let old = try JSONDecoder().decode(CityRecommendationState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.questions.isEmpty && old.saved.count == 1)

        json["questions"] = ["osaka": [["question": 1]]]
        let broken = try JSONDecoder().decode(CityRecommendationState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(broken.questions.isEmpty && broken.saved.count == 1)
    }

    @Test func deleteAllUserDataRemovesQuestions() async throws {
        let stores: [any AppStore] = [
            SwiftDataAppStore(container: try SwiftDataAppStore.makeContainer(inMemory: true), countries: [], tags: []),
            InMemoryAppStore(countries: [], tags: [])
        ]
        for store in stores {
            try await store.updateCityState { $0.addQuestion(Self.entry("질문"), cityID: "osaka") }
            #expect(try await store.cityState().questions["osaka"]?.count == 1)
            try await store.deleteAllUserData()
            #expect(try await store.cityState().questions.isEmpty)
        }
    }
}
