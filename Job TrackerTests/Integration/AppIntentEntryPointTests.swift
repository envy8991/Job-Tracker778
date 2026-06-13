import XCTest
@testable import Job_Tracker

final class AppIntentEntryPointTests: XCTestCase {
    func testAppIntentEntryPointTitlesStayDiscoverable() throws {
        if #available(iOS 26.0, *) {
            XCTAssertTrue(String(describing: CreateJobIntent.title).contains("Create Job"))
            XCTAssertTrue(String(describing: GetTodayJobsIntent.title).contains("Today's Jobs"))
            XCTAssertTrue(String(describing: UpdateJobStatusIntent.title).contains("Update Job Status"))
            XCTAssertTrue(String(describing: DirectionsToNextJobIntent.title).contains("Directions"))
        }
    }

    func testJobIntentLocationFallbackReasonsAreUserReadable() throws {
        if #available(iOS 26.0, *) {
            let reason = JobIntentLocationResult.permissionDenied.fallbackReason
            XCTAssertTrue(reason.contains("permission"))
            XCTAssertTrue(reason.contains("next job"))
        }
    }
}
