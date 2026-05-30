import XCTest

final class JobTrackerUITestSupport {
    static func launch(seedData: Bool = true, admin: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["JT_UI_TESTING"] = "1"
        if seedData { app.launchEnvironment["JT_UI_TESTING_SEED_DATA"] = "1" }
        if admin { app.launchEnvironment["JT_UI_TESTING_ADMIN"] = "1" }
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }
}

extension XCTestCase {
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 8, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Expected element to exist: \(element)", file: file, line: line)
    }
}
