import XCTest

final class ReachNewsUITests: XCTestCase {
    func testBriefingNavigationAndSearch() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Briefing"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Explore"].tap()
        let search = app.textFields["search-field"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("forest")
        XCTAssertTrue(app.descendants(matching: .any)["story-logging-forest"].waitForExistence(timeout: 5))
    }
}

