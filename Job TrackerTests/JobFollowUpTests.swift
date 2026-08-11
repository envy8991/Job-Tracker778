import XCTest
@testable import Job_Tracker

final class JobFollowUpTests: XCTestCase {
    func testLegacyJobDecodesWithoutFollowUp() throws {
        let job = Job(address: "1 Main St", date: Date(), status: "Pending")
        let data = try JSONEncoder().encode(job)
        let decoded = try JSONDecoder().decode(Job.self, from: data)
        XCTAssertNil(decoded.followUp)
    }

    func testDueTodayAndOverdueExcludeCompletedFollowUps() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_786_377_600)
        var item = JobFollowUp(reason: "Needs OH", assignedUserID: "crew", dueDate: now,
                               createdAt: now, updatedAt: now, completedAt: nil,
                               notificationPreference: .dueDate)
        XCTAssertTrue(item.isDueToday(calendar: calendar, now: now))
        item.dueDate = calendar.date(byAdding: .day, value: -1, to: now)!
        XCTAssertTrue(item.isOverdue(calendar: calendar, now: now))
        item.completedAt = now
        XCTAssertFalse(item.isOverdue(calendar: calendar, now: now))
    }
}
