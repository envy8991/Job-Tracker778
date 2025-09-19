import XCTest
@testable import Job_Tracker

final class JobSheetParserTests: XCTestCase {
    func testParseEntriesResolvesAssigneeIdFromSchema() async throws {
        await Task.yield()

        let payload: [[String: Any]] = [
            [
                "address": "123 Main St",
                "jobNumber": "12345",
                "assigneeName": "Taylor Foreman",
                "assigneeId": "user-123",
                "notes": "Call ahead",
                "rawText": "Row 1"
            ],
            [
                "address": "500 Market Ave",
                "jobNumber": NSNull(),
                "assigneeName": "Riley Jones",
                "assigneeId": NSNull(),
                "notes": NSNull(),
                "rawText": "Row 2"
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [])

        let users = [
            AppUser(
                id: "user-123",
                firstName: "Taylor",
                lastName: "Foreman",
                email: "taylor@example.com",
                position: "Technician"
            ),
            AppUser(
                id: "user-456",
                firstName: "Riley",
                lastName: "Jones",
                email: "riley@example.com",
                position: "Technician"
            )
        ]

        let entries = try JobSheetParser.shared.parseEntries(from: data, users: users)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].address, "123 Main St")
        XCTAssertEqual(entries[0].jobNumber, "12345")
        XCTAssertEqual(entries[0].assigneeID, "user-123")
        XCTAssertEqual(entries[1].assigneeID, "user-456")
        XCTAssertEqual(entries[1].assigneeName, "Riley Jones")
        XCTAssertNil(entries[1].jobNumber)
        XCTAssertNil(entries[1].notes)
        XCTAssertEqual(entries[1].rawText, "Row 2")
    }
}
