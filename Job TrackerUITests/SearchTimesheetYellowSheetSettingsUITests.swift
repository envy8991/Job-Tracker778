import XCTest

final class SearchTimesheetYellowSheetSettingsUITests: XCTestCase {
    func testSearchFindsSeededJob() {
        let app = JobTrackerUITestSupport.launch()

        app.tabBars.buttons["Search"].tap()
        waitForElement(app.staticTexts["Job Search"])
        let searchField = app.textFields["Address, job #, status, or teammate"]
        waitForElement(searchField)
        searchField.tap()
        searchField.typeText("Safety Net")
        waitForElement(app.staticTexts["100 Safety Net Lane"])
    }

    func testTimesheetsAndYellowSheetsAreReachable() {
        let app = JobTrackerUITestSupport.launch()

        app.tabBars.buttons["Timesheets"].tap()
        waitForElement(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Timesheet")).firstMatch)

        app.tabBars.buttons["Yellow Sheet"].tap()
        waitForElement(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Yellow")).firstMatch)
    }

    func testSettingsAreReachableFromMore() {
        let app = JobTrackerUITestSupport.launch()

        app.tabBars.buttons["More"].tap()
        waitForElement(app.staticTexts["More"])
        app.staticTexts["Settings"].tap()
        waitForElement(app.staticTexts["Settings"])
        XCTAssertTrue(app.switches.matching(NSPredicate(format: "label CONTAINS[c] %@", "Smart Routing")).firstMatch.exists)
    }
}
