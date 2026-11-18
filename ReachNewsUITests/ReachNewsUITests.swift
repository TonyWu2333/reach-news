import XCTest

final class ReachNewsUITests: XCTestCase {
    func testBriefingNavigationAndSearch() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing", "-appLanguage", "en"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Briefing"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Build"].tap()
        app.buttons["Stories"].tap()
        let search = app.textFields["search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("forest")
        XCTAssertTrue(app.descendants(matching: .any)["story-logging-forest"].waitForExistence(timeout: 5))
    }

    func testChineseBriefingSupportsNativeBackNavigation() {
        let app = XCUIApplication()
        app.launchArguments += ["-appLanguage", "zh-Hans"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["简报"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["你的每日视角。"].exists)

        let briefing = app.descendants(matching: .any)["last24"].firstMatch
        briefing.tap()
        let detail = app.navigationBars["过去 24 小时"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertTrue(detail.buttons.firstMatch.exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.45))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.45)))
        XCTAssertTrue(briefing.waitForExistence(timeout: 5))
        XCTAssertFalse(detail.exists)
    }
}

