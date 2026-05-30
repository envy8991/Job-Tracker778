import XCTest

final class AdminNavigationUITests: XCTestCase {
    func testAdminNavigationIsHiddenForCrewUsers() {
        let app = JobTrackerUITestSupport.launch(admin: false)

        app.tabBars.buttons["More"].tap()
        waitForElement(app.staticTexts["More"])
        XCTAssertFalse(app.staticTexts["Admin"].exists)
    }

    func testAdminNavigationIsVisibleForAdminUsers() {
        let app = JobTrackerUITestSupport.launch(admin: true)

        app.tabBars.buttons["More"].tap()
        waitForElement(app.staticTexts["More"])
        waitForElement(app.staticTexts["Admin"])
        app.staticTexts["Admin"].tap()
        waitForElement(app.navigationBars["Admin"])
    }
}
