import XCTest
@testable import Job_Tracker

final class AppUserTests: XCTestCase {
    func testInitialsUseFirstAndLastNameUppercased() {
        let user = AppUser(
            id: "user-1",
            firstName: "quinton",
            lastName: "thompson",
            email: "quinton@example.com",
            position: "OH"
        )

        XCTAssertEqual(user.initials, "QT")
    }

    func testInitialsHandleMissingNameParts() {
        let firstOnly = AppUser(firstName: "Alex", lastName: "", email: "alex@example.com", position: "UG")
        let lastOnly = AppUser(firstName: "", lastName: "Rivera", email: "rivera@example.com", position: "Can")

        XCTAssertEqual(firstOnly.initials, "A")
        XCTAssertEqual(lastOnly.initials, "R")
    }

    func testDecodingDefaultsMissingOptionalAndAccessFields() throws {
        let json = """
        {
          "id": "user-2",
          "firstName": "Blair",
          "lastName": "Stone",
          "email": "blair@example.com",
          "position": "Aerial"
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(AppUser.self, from: json)

        XCTAssertEqual(user.id, "user-2")
        XCTAssertEqual(user.firstName, "Blair")
        XCTAssertEqual(user.lastName, "Stone")
        XCTAssertEqual(user.email, "blair@example.com")
        XCTAssertEqual(user.position, "Aerial")
        XCTAssertNil(user.profilePictureURL)
        XCTAssertFalse(user.isAdmin)
        XCTAssertFalse(user.isSupervisor)
        XCTAssertEqual(user.normalizedPosition, "OH")
    }

    func testDecodingGeneratesIDWhenMissing() throws {
        let json = """
        {
          "firstName": "Casey",
          "lastName": "Nguyen",
          "email": "casey@example.com",
          "position": "Nid",
          "isAdmin": true,
          "isSupervisor": true
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(AppUser.self, from: json)

        XCTAssertFalse(user.id.isEmpty)
        XCTAssertTrue(user.isAdmin)
        XCTAssertTrue(user.isSupervisor)
    }
}
