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

    func testOptionalFieldsIncludedInHaystack() {
        let jobWithOptionals = Job(
            id: "job-optional",
            address: "456 Elm Street",
            date: Date(timeIntervalSince1970: 1_700_100_000),
            status: "Pending",
            createdBy: "user-1",
            notes: "   Needs Ladder   ",
            jobNumber: nil,
            assignments: "  42.7.1  ",
            materialsUsed: "  Fiber Cable  ",
            nidFootage: "  150FT  ",
            canFootage: "  200 FT  "
        )

        XCTAssertTrue(JobSearchMatcher.matches(job: jobWithOptionals, query: "ladder", creator: creator))
        XCTAssertTrue(JobSearchMatcher.matches(job: jobWithOptionals, query: "fiber", creator: creator))
        XCTAssertTrue(JobSearchMatcher.matches(job: jobWithOptionals, query: "42.7.1", creator: creator))
        XCTAssertTrue(JobSearchMatcher.matches(job: jobWithOptionals, query: "150ft", creator: creator))
        XCTAssertTrue(JobSearchMatcher.matches(job: jobWithOptionals, query: "200 ft", creator: creator))
    }

    func testMatchesUsingSearchIndexEntry() {
        let entry = JobSearchIndexEntry(job: sampleJob)
        XCTAssertTrue(JobSearchMatcher.matches(job: entry, query: "main", creator: creator))
        XCTAssertTrue(JobSearchMatcher.matches(job: entry, query: "completed", creator: creator))
    }
}
