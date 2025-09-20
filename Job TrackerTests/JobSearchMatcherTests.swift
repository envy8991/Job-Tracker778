import XCTest
@testable import Job_Tracker

final class JobSearchMatcherTests: XCTestCase {
    private let sampleJob = Job(
        id: "job-1",
        address: "123 Main Street",
        date: Date(timeIntervalSince1970: 1_700_000_000),
        status: "Completed",
        createdBy: "user-1",
        notes: "",
        jobNumber: "123"
    )

    private let creator = AppUser(
        id: "user-1",
        firstName: "Taylor",
        lastName: "Foreman",
        email: "taylor@example.com",
        position: "Technician"
    )

    func testMatchesAllTokensRegardlessOfOrder() {
        XCTAssertTrue(JobSearchMatcher.matches(job: sampleJob, query: "completed 123", creator: creator))
        XCTAssertTrue(JobSearchMatcher.matches(job: sampleJob, query: " 123   completed ", creator: creator))
    }

    func testMatchFailsWhenAnyTokenMissing() {
        XCTAssertFalse(JobSearchMatcher.matches(job: sampleJob, query: "completed 999", creator: creator))
    }

    func testCreatorNameIncludedInHaystack() {
        XCTAssertTrue(JobSearchMatcher.matches(job: sampleJob, query: "foreman", creator: creator))
        XCTAssertFalse(JobSearchMatcher.matches(job: sampleJob, query: "foreman", creator: nil))
    }
}
