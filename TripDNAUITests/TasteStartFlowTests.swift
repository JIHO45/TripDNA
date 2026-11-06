import XCTest

/// 여행 기록 없이 취향부터 시작하는 온보딩을 끝까지 지나, 고른 칸이 확인 화면에 남고 추천 탭이 열리는지 본다.
/// 2026-10-24 온보딩 재구성(2294f0b)으로 사진 퀴즈 화면이 빠져, 그 화면을 보던 테스트를 이 흐름으로 바꿨다.
final class TasteStartFlowTests: XCTestCase {
    @MainActor func testTasteStartPlacesConceptAndOpensRecommendations() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()

        XCTAssertTrue(app.buttons["시작하기"].waitForExistence(timeout: 15))
        app.buttons["시작하기"].tap()
        // 사는 나라는 기기 지역(ko_KR)에서 미리 골라진다.
        XCTAssertTrue(app.buttons["계속하기"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["계속하기"].isEnabled)
        app.buttons["계속하기"].tap()

        let tastes = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "여행 기록 없이 취향부터")).firstMatch
        XCTAssertTrue(tastes.waitForExistence(timeout: 10))
        tastes.tap()

        // 아직 칸에 넣지 않은 컨셉 칩을 눌러 "가장 원해요"로 옮긴다.
        let food = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "미식")).firstMatch
        XCTAssertTrue(food.waitForExistence(timeout: 10))
        food.tap()
        let wantMost = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "가장 원해요")).firstMatch
        XCTAssertTrue(wantMost.waitForExistence(timeout: 5))
        wantMost.tap()
        app.buttons["다음"].tap()

        // 확인 화면에 고른 칸이 보이고, 첫 추천으로 넘어간다.
        XCTAssertTrue(app.staticTexts["원하는 여행"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["미식"].exists)
        app.buttons["첫 추천 받으러 가기"].tap()
        XCTAssertTrue(app.tabBars.buttons["추천"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.tabBars.buttons["추천"].isSelected)
    }
}
