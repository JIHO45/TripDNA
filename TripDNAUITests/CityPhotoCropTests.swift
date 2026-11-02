import XCTest

final class CityPhotoCropTests: XCTestCase {
    @MainActor
    func testPortraitAndPanoramaCards() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiDemo", "recoPhotos", "-disableAffiliateActivities",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Recommendations"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Recommendations"].tap()

        let cities = ["Seoul", "Zurich", "Washington", "Valencia", "Kraków", "Riyadh", "Denpasar", "Mecca", "London", "Delhi", "Buenos Aires", "Verona", "Los Angeles", "Doha", "Nha Trang"]
        for (index, city) in cities.enumerated() {
            let title = app.staticTexts[city].firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 10))
            for _ in 0..<4 where !title.isHittable { app.swipeUp() }
            XCTAssertTrue(title.isHittable, "Missing card for \(city)")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "128pt-\(city)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            if index < cities.count - 1 {
                let next = app.buttons["Next city"]
                XCTAssertTrue(next.isHittable)
                next.tap()
            }
        }
    }
}
