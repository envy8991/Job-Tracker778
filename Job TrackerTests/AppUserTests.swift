import XCTest
@testable import Job_Tracker

final class AppUserTests: XCTestCase {
    func testInitialsUseFirstAndLastNameFallbackLetters() {
        XCTAssertEqual(
            AppUser(id: "1", firstName: "Taylor", lastName: "Foreman", email: "taylor@example.com", position: "OH").initials,
            "TF"
        )
        XCTAssertEqual(
            AppUser(id: "2", firstName: "", lastName: "Solo", email: "solo@example.com", position: "Nid").initials,
            "S"
        )
    }

    func testNormalizedPositionUsesCrewPositionAliases() {
        let user = AppUser(id: "3", firstName: "Ari", lastName: "Legacy", email: "ari@example.com", position: "Aerial")
        XCTAssertEqual(user.normalizedPosition, "OH")
    }

    func testDecodingMissingOptionalFieldsFallsBackToSafeDefaults() throws {
        let data = #"{"firstName":"Quinn","lastName":"Tester"}"#.data(using: .utf8)!
        let user = try JSONDecoder().decode(AppUser.self, from: data)

        XCTAssertFalse(user.id.isEmpty)
        XCTAssertEqual(user.firstName, "Quinn")
        XCTAssertEqual(user.lastName, "Tester")
        XCTAssertEqual(user.email, "")
        XCTAssertEqual(user.position, "")
        XCTAssertFalse(user.isAdmin)
        XCTAssertFalse(user.isSupervisor)
        XCTAssertNil(user.profilePictureURL)
    }
}
