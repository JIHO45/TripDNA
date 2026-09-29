import XCTest

final class TasteQuizFlowTests: XCTestCase {
    @MainActor func testBroadAndUnknownAnswersRemainDistinctThroughOnboarding() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.buttons["시작하기"].waitForExistence(timeout: 15))
        app.buttons["시작하기"].tap()
        XCTAssertTrue(app.buttons["내 지문 만들기"].waitForExistence(timeout: 10))
        app.buttons["내 지문 만들기"].tap()
        XCTAssertTrue(app.buttons["계속하기"].waitForExistence(timeout: 10))
        app.textFields["국가 검색"].tap()
        app.textFields["국가 검색"].typeText("대한민국")
        let country = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "대한민국")).firstMatch
        XCTAssertTrue(country.waitForExistence(timeout: 5))
        country.tap()
        XCTAssertTrue(app.buttons["계속하기"].isEnabled)
        app.buttons["계속하기"].tap()
        let quiz = app.buttons["여행 이력이 없어요 · 사진 퀴즈로 시작"]
        XCTAssertTrue(quiz.waitForExistence(timeout: 10))
        quiz.tap()
        XCTAssertTrue(app.buttons["둘 다 좋아요"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["둘 다 좋아요"].isHittable)
        XCTAssertTrue(app.buttons["모르겠어요"].isHittable)
        app.buttons["둘 다 좋아요"].tap()
        // Keep the nature breadth answer and leave other preferences unknown.
        for prompt in ["숙소 창밖으로 보고 싶은 풍경은?", "여행 중 완벽한 오후는?",
                       "여행 다녀온 뒤 듣고 싶은 말은?", "아름다운 야경 앞에서 드는 생각은?",
                       "여행지에서의 저녁은?", "\"같이 다닐래요?\" 우연한 동행 제안, 내 마음은?",
                       "출발 전날 밤, 나는?", "맛집은 어떻게 찾나요?",
                       "여행지에서 맞이한 첫 아침, 내 발걸음은?", "낯선 현지 음식 앞에서 나는?",
                       "여행 사진첩에 더 많길 바라는 장면은?", "지금 당장 순간이동한다면?"] {
            XCTAssertTrue(app.staticTexts[prompt].waitForExistence(timeout: 5))
            app.buttons["모르겠어요"].tap()
        }
        let food = app.buttons["미식"]
        XCTAssertTrue(food.waitForExistence(timeout: 5))
        food.tap()
        app.buttons["내 지문 만들기"].tap()
        let breadth = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "모두 좋다고 답했어요")).firstMatch
        XCTAssertTrue(breadth.waitForExistence(timeout: 15))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Explicit breadth on onboarding result"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
