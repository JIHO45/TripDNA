import XCTest

/// 영어로 실행했을 때 화면 어디에도 한글이 없는지 확인한다. 화면마다 스크린샷을 xcresult에 남긴다.
/// 도달 못 한 화면은 `visited`/`skipped` 로그로 남기고(테스트 실패 아님), 한글이 나오면 화면 이름과 줄을 실패로 보고한다.
final class EnglishLocalizationUITests: XCTestCase {
    private static let english = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: helpers

    @MainActor private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments + Self.english
        app.launch()
    }

    @MainActor private func launchDemo(_ scenario: String) {
        launch(["-uiTesting", "-uiDemo", scenario, "-disableAffiliateActivities"])
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 20), "demo \(scenario) did not reach Home")
    }

    private static func isHangul(_ scalar: Unicode.Scalar) -> Bool {
        (0xAC00...0xD7A3).contains(scalar.value) || (0x3131...0x318E).contains(scalar.value)
    }

    /// 현재 화면 계층(label/value/placeholder 포함)에서 한글이 든 줄을 찾아 실패로 보고하고 스크린샷을 붙인다.
    @MainActor private func assertNoHangul(_ screen: String) {
        let offending = app.debugDescription.split(separator: "\n").filter { $0.unicodeScalars.contains(where: Self.isHangul) }
        if !offending.isEmpty {
            XCTFail("Hangul on screen '\(screen)':\n" + offending.map { "  " + $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n"))
        }
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = screen
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// 화면을 위로 스크롤하며 각 위치를 검사한다(지연 로딩되는 아래쪽 내용까지).
    @MainActor private func check(_ screen: String, scrolls: Int = 2) {
        assertNoHangul(screen)
        for i in 1...max(scrolls, 1) where scrolls > 0 {
            app.swipeUp()
            assertNoHangul("\(screen) (scroll \(i))")
        }
        for _ in 0..<scrolls { app.swipeDown() }
    }

    private func skip(_ what: String) {
        let note = XCTAttachment(string: what)
        note.name = "SKIPPED: \(what)"
        note.lifetime = .keepAlways
        add(note)
    }

    /// 라벨이 포함된 첫 요소(버튼 우선)를 반환한다.
    @MainActor private func element(_ label: String) -> XCUIElement {
        let byId = app.descendants(matching: .any).matching(identifier: label).firstMatch
        if byId.exists { return byId }
        let predicate = NSPredicate(format: "label CONTAINS %@", label)
        let button = app.buttons.matching(predicate).firstMatch
        if button.exists { return button }
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// 있으면 누르고 true. 없으면 SKIPPED를 남기고 false.
    @MainActor @discardableResult private func tap(_ label: String, wait: TimeInterval = 4, swipes: Int = 0) -> Bool {
        var el = element(label)
        if !el.waitForExistence(timeout: wait) { skip("no element '\(label)'"); return false }
        for _ in 0..<swipes where !el.isHittable { app.swipeUp(); el = element(label) }
        guard el.isHittable else { skip("'\(label)' not hittable"); return false }
        el.tap()
        return true
    }

    @MainActor private func tapTab(_ name: String) {
        for _ in 0..<3 where !app.tabBars.buttons[name].exists { dismissSheet(["Later", "Close", "Cancel", "Done"]); back(); sleep(1) }
        app.tabBars.buttons[name].tap()
    }

    /// 내비게이션 뒤로 가기.
    @MainActor private func back() {
        let button = app.navigationBars.buttons.firstMatch
        if button.exists { button.tap() }
    }

    @MainActor private func dismissSheet(_ labels: [String] = ["Close", "Cancel", "Done"]) {
        for label in labels where app.buttons[label].exists && app.buttons[label].isHittable {
            app.buttons[label].tap()
            return
        }
        app.swipeDown(velocity: .fast)
    }

    /// 탭 하나 + 화면 이름으로 열고 검사한 뒤 뒤로 간다.
    @MainActor private func push(_ label: String, as screen: String, scrolls: Int = 1, swipes: Int = 0) {
        guard tap(label, swipes: swipes) else { return }
        sleep(1)
        check(screen, scrolls: scrolls)
        back()
    }

    // MARK: demo: upcoming

    @MainActor func testUpcomingHomeTripsAndSettings() throws {
        launchDemo("upcoming")
        check("Home (upcoming)", scrolls: 3)

        if tap("home.profile") {
            sleep(1)
            check("Settings root", scrolls: 3)
            push("Wanted Trips", as: "Settings: Wanted Trips")
            push("Remembered Tastes", as: "Settings: Remembered Tastes")
            push("Excluded from Recommendations", as: "Settings: Excluded")
            push("Saved Cities", as: "Settings: Saved Cities")
            push("Default Departure Airport", as: "Settings: Departure Airport")
            push("Home Country", as: "Settings: Home Country")
            push("Permissions and shared info", as: "Settings: Permissions", swipes: 3)
            if tap("Delete data", swipes: 4) {
                sleep(1)
                check("Settings: Delete data")
                if tap("Delete all data") {
                    sleep(1)
                    check("Delete data: confirm sheet (never confirmed)", scrolls: 1)
                    dismissSheet(["Cancel", "Close"])
                    sleep(1)
                }
                push("One Memory", as: "Delete data: One Memory")
                back()
            }
            // 백업은 iCloud 위치가 격리되면 링크가 없다.
            if !tap("iCloud backup", swipes: 0) { skip("iCloud backup page (no backup in uiTesting)") } else { check("Settings: Backup"); back() }
            dismissSheet(["Close"])
        }

        tapTab("Trips")
        sleep(1)
        check("Trips list", scrolls: 2)
        if tap("Lisbon") {
            sleep(1)
            check("Trip detail (upcoming)", scrolls: 3)
            if tap("Manage Trip") { sleep(1); assertNoHangul("Trip menu"); app.buttons["Edit Trip Info"].tapIfExists(); sleep(1); check("Trip edit sheet", scrolls: 2); dismissSheet(["Cancel", "Close"]) }
            if tap("Edit Concepts", swipes: 4) { sleep(1); check("Trip concepts sheet", scrolls: 1); dismissSheet() }
            back()
        }
        if tap("Kyoto", swipes: 3) {
            sleep(1)
            check("Trip detail (evaluated)", scrolls: 3)
            if tap("trip.sharePreview") { sleep(1); check("Trip share card sheet", scrolls: 2); dismissSheet() }
            if tap("Manage Trip") { sleep(1); assertNoHangul("Trip menu (evaluated)"); app.buttons["Edit Evaluation"].tapIfExists(); sleep(1); check("Evaluation edit", scrolls: 3); dismissSheet(["Later", "Cancel", "Close", "Done"]) }
            back()
        }
        // 여행 등록
        for label in ["Register a Trip", "Add Trip", "Add a Trip", "plus"] where tap(label, wait: 1) {
            sleep(1); check("Trip registration", scrolls: 3); dismissSheet(); break
        }

        tapTab("Home")
        if tap("home.fingerprint", swipes: 6) { sleep(1); check("Fingerprint detail (upcoming)", scrolls: 3); back() }
    }

    // MARK: demo: active (daily photo)

    @MainActor func testActiveTripDailyPhoto() throws {
        launchDemo("active")
        check("Home (active)", scrolls: 3)
        if tap("home.dailyPhoto") {
            sleep(1)
            check("Daily photo (from Home)", scrolls: 2)
            back()
        }
        tapTab("Trips")
        if tap("Lisbon") {
            sleep(1)
            check("Trip detail (active)", scrolls: 3)
            for label in ["Choose Today", "Change Today"] where tap(label, wait: 1, swipes: 4) {
                sleep(1); check("Daily photo editor", scrolls: 2); dismissSheet(); break
            }
            if tap("Back Early", swipes: 4) { sleep(1); assertNoHangul("End trip alert (not confirmed)"); app.buttons["Keep Traveling"].tapIfExists() }
            if tap("Cover Photo", wait: 1) || tap("Change Cover", wait: 1) { sleep(1); check("Cover photo picker"); dismissSheet() }
        }
    }

    // MARK: demo: pendingEval (evaluation)

    @MainActor func testPendingEvaluation() throws {
        launchDemo("pendingEval")
        check("Home (pending evaluation)", scrolls: 3)
        if tap("home.evaluate") {
            sleep(2)
            check("Evaluation: step 1", scrolls: 3)
            app.buttons["3 stars"].tapIfExists()
            if tap("Trip Concepts") { sleep(1); check("Evaluation: trip concepts", scrolls: 2); dismissSheet(["Done", "Close", "Cancel"]) }
            skip("BUTTONS (eval): " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
            // 다음 단계가 있으면 몇 단계 따라간다(저장·제출은 하지 않는다).
            for step in 2...4 {
                let next = app.buttons.matching(NSPredicate(format: "label IN %@", ["Next", "Continue"])).firstMatch
                guard next.exists, next.isEnabled, next.isHittable else { break }
                next.tap(); sleep(1)
                check("Evaluation: step \(step)", scrolls: 2)
            }
            dismissSheet(["Close", "Cancel"])
            // 닫기 확인창이 뜨면 이어서 쓰기로 둔다.
            if app.alerts.firstMatch.exists { assertNoHangul("Evaluation close alert"); app.alerts.buttons.firstMatch.tap() }
        }
    }

    // MARK: demo: many (fingerprint, ranking)

    @MainActor func testManyFingerprintAndRanking() throws {
        launchDemo("many")
        check("Home (many)", scrolls: 4)
        if tap("home.fingerprint", swipes: 6) {
            sleep(1)
            check("Fingerprint detail (many)", scrolls: 4)
            if tap("fingerprint.sharePreview") { sleep(1); check("Fingerprint share sheet", scrolls: 2); dismissSheet() }
            back()
        }
        tapTab("Trips")
        sleep(1)
        check("Trips list (many)", scrolls: 3)
        for label in ["Ranking", "Rankings"] where tap(label, wait: 1) {
            sleep(1); check("Ranking", scrolls: 3); break
        }
        // 다음에 쓸 만한 탭 탐색: 세그먼트/버튼이 더 있으면 라벨만 로그
        skip("BUTTONS (trips): " + app.buttons.allElementsBoundByIndex.prefix(40).map(\.label).joined(separator: " | "))
    }

    // MARK: demo: recommendations

    @MainActor func testRecommendationResult() throws {
        launchDemo("recoResult")
        tapTab("Recommendations")
        sleep(2)
        check("Recommendations (result)", scrolls: 4)
        skip("BUTTONS (reco): " + app.buttons.allElementsBoundByIndex.prefix(40).map(\.label).joined(separator: " | "))
        if tap("Edit Filters") { sleep(1); check("Edit filters sheet", scrolls: 3); dismissSheet() }
        if tap("New Trip Recommendation") {
            sleep(1)
            check("Recommendation input", scrolls: 4)
            dismissSheet(["Close", "Cancel"])
        }
        // 카드 상세
        if tap("Osaka,", swipes: 3) {
            sleep(1); check("City recommendation detail", scrolls: 4)
            for label in ["Ask", "Question"] where tap(label, wait: 1) { sleep(1); check("City question sheet"); dismissSheet(); break }
            back()
        }
        if tap("More") {
            sleep(1); check("City card menu / more", scrolls: 1)
            dismissSheet()
        }
    }

    @MainActor func testRecommendationEmptyAndVariants() throws {
        launchDemo("recoZero")
        tapTab("Recommendations"); sleep(2)
        check("Recommendations (zero)", scrolls: 3)
        app.terminate()
        launchDemo("recoHomeExcluded")
        tapTab("Recommendations"); sleep(2)
        check("Recommendations (home excluded)", scrolls: 3)
        app.terminate()
        launchDemo("empty")
        check("Home (empty)", scrolls: 3)
        tapTab("Recommendations"); sleep(1)
        check("Recommendations (empty)", scrolls: 2)
        if tap("recommendation.new") {
            sleep(1)
            check("Recommendation input (empty)", scrolls: 4)
            dismissSheet(["Close", "Cancel"])
        }
        tapTab("Trips"); sleep(1)
        check("Trips (empty)", scrolls: 2)
        tapTab("Home")
        if tap("home.scanPhotos", swipes: 4) { sleep(2); check("Photo scan sheet", scrolls: 2); dismissSheet() }
        if tap("home.registerTrip", swipes: 4) { sleep(1); check("Trip registration (Home)", scrolls: 3); dismissSheet() }
        if tap("home.pickWanted", swipes: 4) { sleep(1); check("Wanted tiers (Home)", scrolls: 3); dismissSheet() }
    }

    @MainActor func testMemoryAndSaved() throws {
        launchDemo("memory")
        check("Home (memory)", scrolls: 3)
        if tap("home.profile") {
            sleep(1)
            push("Wanted Trips", as: "Settings: Wanted Trips (memory)", scrolls: 2)
            push("Remembered Tastes", as: "Settings: Remembered Tastes (memory)", scrolls: 2)
            dismissSheet(["Close"])
        }
        app.terminate()
        launchDemo("saved")
        if tap("home.profile") {
            sleep(1)
            push("Saved Cities", as: "Settings: Saved Cities (saved)", scrolls: 3)
            push("Excluded from Recommendations", as: "Settings: Excluded (saved)", scrolls: 2)
            dismissSheet(["Close"])
        }
    }

    // MARK: demo: Wrapped

    @MainActor func testWrapped() throws {
        launchDemo("wrappedPast")
        check("Home (wrapped past)", scrolls: 4)
        if tap("home.wrapped", swipes: 8) {
            sleep(2)
            check("Wrapped intro", scrolls: 1)
            for page in 1...10 {
                if app.buttons["wrapped.sharePreview"].exists { break }
                app.swipeLeft(); sleep(1)
                assertNoHangul("Wrapped page \(page)")
            }
            if tap("wrapped.sharePreview", wait: 2) { sleep(1); check("Wrapped share sheet", scrolls: 2); dismissSheet() }
        }
        app.terminate()
        launchDemo("wrappedOne")
        if tap("home.wrapped", swipes: 8) {
            sleep(2)
            for page in 1...6 { assertNoHangul("Wrapped (one trip) page \(page)"); app.swipeLeft(); sleep(1) }
        }
    }

    /// 탐지기 자체 확인: 한국어로 띄우면 한글이 잡혀야 한다.
    @MainActor func testDetectorFindsHangulInKorean() throws {
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiDemo", "upcoming", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["홈"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.debugDescription.unicodeScalars.contains(where: Self.isHangul))
    }

    // MARK: onboarding

    @MainActor func testOnboardingEnglish() throws {
        launch(["-uiTesting"])
        let start = app.buttons.matching(NSPredicate(format: "label == 'Get Started'")).firstMatch
        _ = start.waitForExistence(timeout: 15)
        check("Onboarding: welcome", scrolls: 1)
        skip("BUTTONS (onb 1): " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        guard start.exists else { return skip("onboarding start button not found") }
        start.tap()
        sleep(1)
        check("Onboarding: intro", scrolls: 1)
        skip("BUTTONS (onb 2): " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        check("Onboarding: home country", scrolls: 1)
        let search = app.textFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap(); search.typeText("Korea"); sleep(1)
            assertNoHangul("Onboarding: country search results")
            let country = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Korea'")).firstMatch
            if country.waitForExistence(timeout: 5) { country.tap() }
        }
        let next = app.buttons.matching(NSPredicate(format: "label == 'Continue'")).firstMatch
        guard next.waitForExistence(timeout: 5), next.isEnabled else { return skip("continue disabled after country") }
        next.tap()
        sleep(1)
        check("Onboarding: history choice", scrolls: 2)
        skip("BUTTONS (onb 4): " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
        let quiz = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Start with Tastes'")).firstMatch
        guard quiz.waitForExistence(timeout: 5) else { return skip("quiz entry not found") }
        quiz.tap()
        // 취향 선택 화면들: 항목을 고르고 Next(없으면 Skip)로 넘기며 매 단계 검사한다.
        for q in 1...8 {
            sleep(1)
            assertNoHangul("Onboarding step \(q)")
            if q <= 3 { skip("BUTTONS (step \(q)): " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | ")) }
            for pick in ["Nature", "Food"] { app.buttons[pick].tapIfExists() }
            if q == 1, tap("Add something to avoid") { sleep(1); check("Onboarding: avoid note", scrolls: 1); dismissSheet(["Done", "Close", "Cancel"]) }
            let candidates = ["Next", "Skip", "Get My First Recommendation"].map { app.buttons[$0] }
            guard let go = candidates.first(where: { $0.exists && $0.isEnabled }) else { break }
            go.tap()
        }
        sleep(1)
        check("Onboarding: after quiz", scrolls: 3)
        skip("BUTTONS (after quiz): " + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
    }
}

private extension XCUIElement {
    func tapIfExists() { if waitForExistence(timeout: 2), isHittable { tap() } }
}
