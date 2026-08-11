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

        let detailsButton = app.buttons["dashboard.job.ui-test-job-1.details"]
        waitForElement(detailsButton)
        detailsButton.tap()
        waitForElement(app.navigationBars["Job Detail"])
        XCTAssertTrue(app.buttons["Save"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Delete")).firstMatch.exists)
    }

    func testDashboardCardActionsAreIndependentlyActionable() {
        let app = JobTrackerUITestSupport.launch()

        let statusButton = app.buttons["dashboard.job.ui-test-job-1.status"]
        let deleteButton = app.buttons["dashboard.job.ui-test-job-1.delete"]
        waitForElement(statusButton)
        waitForElement(deleteButton)

        statusButton.tap()
        waitForElement(app.buttons["Pending"])
        XCTAssertFalse(app.navigationBars["Job Detail"].exists)
        app.buttons["Pending"].tap()

        deleteButton.tap()
        waitForElement(app.alerts["Delete this job?"])
        XCTAssertFalse(app.navigationBars["Job Detail"].exists)
        app.alerts.buttons["Cancel"].tap()
    }
}
