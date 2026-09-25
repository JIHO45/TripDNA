//
//  TripDNAUITests.swift
//  TripDNAUITests
//
//  Created by 박지호 on 7/24/26.
//

import XCTest

final class TripDNAUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testPlannedTripCityEditingAndActivityBrowser() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiDemo"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["여행"].waitForExistence(timeout: 20))
        app.tabBars.buttons["여행"].tap()
        let trip = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "포르투갈")).firstMatch
        XCTAssertTrue(trip.waitForExistence(timeout: 10))
        trip.tap()
        XCTAssertTrue(app.buttons["수정"].waitForExistence(timeout: 10))
        app.buttons["수정"].tap()
        let city = app.textFields["도시 (예: 도쿄, 오사카)"]
        XCTAssertTrue(city.waitForExistence(timeout: 10))
        XCTAssertEqual(city.value as? String, "리스본")
        city.tap()
        city.typeText(", Porto")
        app.buttons["변경 저장"].tap()
        XCTAssertTrue(app.buttons["수정"].waitForExistence(timeout: 10))
        app.buttons["수정"].tap()
        XCTAssertTrue(city.waitForExistence(timeout: 10))
        XCTAssertEqual(city.value as? String, "리스본, Porto")
        app.buttons["취소"].tap()
        let activity = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Porto · 인기 액티비티")).firstMatch
        for _ in 0..<5 where !activity.isHittable { app.swipeUp() }
        XCTAssertTrue(activity.isHittable)
        activity.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 15) || app.buttons["닫기"].exists)
    }

    @MainActor
    func testDisabledActivitiesHideTripSection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiDemo", "-disableAffiliateActivities"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["여행"].waitForExistence(timeout: 20))
        app.tabBars.buttons["여행"].tap()
        let trip = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "포르투갈")).firstMatch
        XCTAssertTrue(trip.waitForExistence(timeout: 10))
        trip.tap()
        XCTAssertTrue(app.buttons["수정"].waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertFalse(app.staticTexts["출발 전 뭐 할까"].exists)
        XCTAssertFalse(app.buttons["도시 추가하기"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
