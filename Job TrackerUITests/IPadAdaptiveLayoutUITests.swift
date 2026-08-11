import XCTest
import UIKit

/// Adaptive-layout smoke coverage intended for an iPad simulator destination.
/// Window sizes controlled by Stage Manager and Split View remain manual QA checks
/// because XCTest cannot deterministically resize an iPad application window.
final class IPadAdaptiveLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Run this adaptive suite with the documented iPad destination")
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    func testDashboardCreateAndEditRemainReachableAcrossRotation() {
        let app = JobTrackerUITestSupport.launch()
        waitForElement(app.descendants(matching: .any)["IPadShell.Root"])
        waitForElement(app.descendants(matching: .any)["Dashboard.Root"])
        let create = app.buttons["Dashboard.CreateJob"]
        waitForElement(create)
        XCTAssertTrue(create.isHittable)

        XCUIDevice.shared.orientation = .landscapeLeft
        waitForElement(app.staticTexts["100 Safety Net Lane"])
        XCTAssertTrue(create.isHittable, "The dashboard selection and primary action should survive rotation")

        create.tap()
        waitForElement(app.descendants(matching: .any)["CreateJob.Root"])
        XCTAssertTrue(app.buttons["CreateJob.Save"].exists)
        app.swipeUp()
        XCTAssertTrue(app.buttons["CreateJob.Save"].exists, "The form toolbar must remain reachable after scrolling")
        app.buttons["Close"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["CreateJob.Root"].exists)

        app.staticTexts["100 Safety Net Lane"].tap()
        waitForElement(app.navigationBars["Job Detail"])
        app.swipeUp()
        XCTAssertTrue(app.buttons["Save"].exists)
        XCUIDevice.shared.orientation = .portrait
        waitForElement(app.navigationBars["Job Detail"])
    }

    func testSearchKeyboardEmptyStateAndDetailSelectionSurviveRotation() {
        let app = JobTrackerUITestSupport.launch()
        app.buttons["Search"].tap()
        waitForElement(app.descendants(matching: .any)["Search.Root"])
        let query = app.textFields["Search.Query"]
        waitForElement(query)
        query.tap()
        query.typeText("NoSuchAdaptiveJob")
        waitForElement(app.descendants(matching: .any)["Search.EmptyState"])
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Try fewer keywords")).firstMatch.exists)
        app.keyboards.buttons["Search"].tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 2), "The search keyboard should dismiss through its semantic submit action")

        query.tap()
        query.clearAndEnterText("Safety Net")
        app.keyboards.buttons["Search"].tap()
        let result = app.staticTexts["100 Safety Net Lane"]
        waitForElement(result)
        result.tap()
        waitForElement(app.navigationBars["Job Details"])
        XCUIDevice.shared.orientation = .landscapeRight
        waitForElement(app.staticTexts["100 Safety Net Lane"])
        XCTAssertTrue(app.navigationBars["Job Details"].exists, "The selected search detail should remain presented")
    }

    func testWeeklyTimesheetFormAndCalendarSheetAdapt() {
        let app = JobTrackerUITestSupport.launch()
        app.buttons["Timesheets"].tap()
        waitForElement(app.descendants(matching: .any)["Timesheet.Root"])
        let supervisor = app.textFields["Timesheet.Supervisor"]
        waitForElement(supervisor)
        supervisor.tap()
        supervisor.typeText("Adaptive Supervisor")
        app.keyboards.buttons[XCUIKeyboardKey.return.rawValue].tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 2))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(supervisor.value as? String, "Adaptive Supervisor")

        let week = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Week of")).firstMatch
        waitForElement(week)
        week.tap()
        waitForElement(app.navigationBars["Select Week"])
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Select Week"].waitForNonExistence(timeout: 2), "The calendar sheet must be dismissible without an edge gesture")
    }

    func testYellowSheetEmptyContentAndPrimaryActionRemainReadable() {
        let app = JobTrackerUITestSupport.launch()
        app.buttons["Yellow Sheet"].tap()
        waitForElement(app.descendants(matching: .any)["YellowSheet.Root"])
        let save = app.buttons["YellowSheet.Save"]
        waitForElement(save)
        XCTAssertTrue(save.isHittable)
        XCTAssertTrue(app.staticTexts["No yellow sheet jobs"].exists || app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Job Number:")).firstMatch.exists)
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForElement(save)
        XCTAssertTrue(save.isHittable)
    }

    func testRouteMapperControlsRemainReachableAfterResizing() {
        let app = JobTrackerUITestSupport.launch()
        app.buttons["More"].tap()
        waitForElement(app.navigationBars["More"])
        app.staticTexts["Route Mapper"].tap()
        waitForElement(app.descendants(matching: .any)["Maps.Root"])
        waitForElement(app.staticTexts["Map Controls"])
        XCUIDevice.shared.orientation = .landscapeRight
        waitForElement(app.staticTexts["Map Controls"])
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "location")).firstMatch.exists)
    }

    func testSettingsSelectionIsPreservedAcrossRotation() {
        let app = JobTrackerUITestSupport.launch()
        app.buttons["More"].tap()
        app.staticTexts["Settings"].tap()
        waitForElement(app.descendants(matching: .any)["Settings.Root"])
        let routing = app.switches["Enable Smart Routing"]
        waitForElement(routing)
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForElement(routing)
        XCTAssertTrue(app.staticTexts["Settings"].exists, "The More detail selection should survive an adaptive transition")
    }

    func testSupervisorDashboardPositionSelectionSurvivesRotation() {
        let app = JobTrackerUITestSupport.launch(admin: true)
        waitForElement(app.descendants(matching: .any)["SupervisorDashboard.Root"])
        waitForElement(app.descendants(matching: .any)["SupervisorDashboard.Positions"])
        waitForElement(app.staticTexts["Crew Overview"])
        XCUIDevice.shared.orientation = .landscapeRight
        waitForElement(app.staticTexts["Crew Overview"])
        XCTAssertTrue(app.datePickers["Date"].isHittable)
    }
}

private extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        tap()
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (value as? String)?.count ?? 0))
        typeText(text)
    }
}
