import XCTest
@testable import Job_Tracker

final class InteractiveTutorialStagesTests: XCTestCase {
    func testAuthStageCompletesAfterVisitingAllSteps() {
        let model = AuthTutorialStageModel()
        XCTAssertFalse(model.isActionComplete)

        model.select(step: .signUp)
        XCTAssertFalse(model.isActionComplete)

        model.select(step: .reset)
        XCTAssertTrue(model.isActionComplete)
    }

    func testDashboardStageRequiresStatusChangeAndShare() {
        let model = DashboardTutorialStageModel()
        guard let firstJob = model.jobs.first else {
            XCTFail("Expected sample jobs")
            return
        }

        XCTAssertFalse(model.isActionComplete)

        model.recordShareTap()
        XCTAssertFalse(model.isActionComplete, "Status change should also be required")

        model.changeStatus(for: firstJob.id, to: .done)
        XCTAssertTrue(model.isActionComplete)
    }

    func testCreateJobStageRequiresValidSubmission() {
        let model = CreateJobTutorialStageModel()
        XCTAssertFalse(model.isActionComplete)

        XCTAssertFalse(model.attemptSubmit(), "Submission should fail when job number missing")
        XCTAssertFalse(model.isActionComplete)

        model.jobNumber = "JT-451"
        XCTAssertTrue(model.attemptSubmit())
        XCTAssertTrue(model.isActionComplete)
    }

    func testTimesheetStageCompletesAfterEditingHours() {
        let model = TimesheetTutorialStageModel()
        guard let entry = model.entries.first else {
            XCTFail("Expected seeded entries")
            return
        }

        XCTAssertFalse(model.isActionComplete)

        model.updateHours(for: entry.id, to: entry.hours)
        XCTAssertFalse(model.isActionComplete, "Changing to same hours should not complete stage")

        model.updateHours(for: entry.id, to: entry.hours + 0.5)
        XCTAssertTrue(model.isActionComplete)
    }
}
