import XCTest

final class AuthenticationUITests: XCTestCase {
    func testSignedOutUserSeesAuthenticationActionsAndValidation() {
        let app = JobTrackerUITestSupport.launch(seedData: false)

        waitForElement(app.buttons["Sign In"])
        XCTAssertTrue(app.buttons["Create one"].exists)
        XCTAssertTrue(app.buttons["Forgot password?"].exists)

        app.buttons["Sign In"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "email")).firstMatch.waitForExistence(timeout: 3))
    }
}
