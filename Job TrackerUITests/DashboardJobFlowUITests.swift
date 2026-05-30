import XCTest

final class DashboardJobFlowUITests: XCTestCase {
    func testDashboardShowsSeededJobsAndCreateJobEntryPoint() {
        let app = JobTrackerUITestSupport.launch()

        waitForElement(app.staticTexts["Jobs"])
        waitForElement(app.buttons["Create Job"])
        waitForElement(app.staticTexts["100 Safety Net Lane"])

        app.buttons["Create Job"].tap()
        waitForElement(app.navigationBars["Create Job"])
        XCTAssertTrue(app.buttons["Save"].exists)
        app.buttons["Close"].tap()
    }

    func testJobDetailSupportsEditSaveAndDeleteControls() {
        let app = JobTrackerUITestSupport.launch()

        waitForElement(app.staticTexts["100 Safety Net Lane"])
        app.staticTexts["100 Safety Net Lane"].tap()
        waitForElement(app.navigationBars["Job Detail"])
        XCTAssertTrue(app.buttons["Save"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Delete")).firstMatch.exists)
    }
}
