import XCTest

final class ShareFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(_ scenario: String = "upcoming") -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiDemo", scenario, "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["홈"].waitForExistence(timeout: 20))
        return app
    }

    @MainActor func testFingerprintSharing() throws {
        let app = launch()
        let share = app.buttons["home.fingerprintShare"]
        reveal(share, in: app)
        share.tap()
        try verifyExport(app, destinations: false)
    }

    @MainActor func testTripSharing() throws {
        let app = launch()
        app.tabBars.buttons["여행"].tap()
        let trip = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Kyoto")).firstMatch
        reveal(trip, in: app)
        trip.tap()
        let share = app.buttons["trip.sharePreview"]
        reveal(share, in: app)
        share.tap()
        try verifyExport(app, destinations: true)
    }

    @MainActor func testWrappedSharing() throws {
        let app = launch("wrappedPast")
        let wrapped = app.buttons["home.wrapped"]
        reveal(wrapped, in: app)
        wrapped.tap()
        let share = app.buttons["wrapped.sharePreview"]
        for _ in 0..<6 where !share.exists { app.swipeLeft() }
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        try verifyExport(app, destinations: true)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 10)
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    @MainActor private func verifyExport(_ app: XCUIApplication, destinations: Bool) throws {
        XCTAssertTrue(app.images["shareCard.preview"].waitForExistence(timeout: 10))
        let share = app.buttons["shareCard.share"]
        let save = app.buttons["shareCard.save"]
        XCTAssertFalse(share.isEnabled)
        XCTAssertFalse(save.isEnabled)
        let confirmation = app.switches["shareCard.confirm"]
        app.swipeUp()
        reveal(confirmation, in: app)
        confirmation.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertTrue(share.isEnabled)
        if destinations {
            let toggle = app.switches["shareCard.destinations"]
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            XCTAssertFalse(share.isEnabled)
            confirmation.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        }
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Share preview and disclosure"
        preview.lifetime = .keepAlways
        add(preview)
        save.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "(label CONTAINS[c] 'Allow' AND NOT label CONTAINS[c] 'Don') OR (label CONTAINS '허용' AND NOT label CONTAINS '안')")).firstMatch
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        XCTAssertTrue(app.staticTexts["사진첩에 저장했어요."].waitForExistence(timeout: 15))
        share.tap()
        let copyAction = app.cells.matching(NSPredicate(format: "label IN %@", ["복사", "Copy"])).firstMatch
        XCTAssertTrue(copyAction.waitForExistence(timeout: 15))
        let sheet = XCTAttachment(screenshot: app.screenshot())
        sheet.name = "System share sheet"
        sheet.lifetime = .keepAlways
        add(sheet)
    }
}
