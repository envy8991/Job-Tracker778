import XCTest
@testable import Job_Tracker

final class CrewPositionTests: XCTestCase {
    func testOHAliasesNormalizeToCurrentDisplayName() {
        XCTAssertEqual(CrewPosition.positionDisplayName(from: "Aerial"), "OH")
        XCTAssertEqual(CrewPosition.positionDisplayName(from: " ariel "), "OH")
        XCTAssertEqual(CrewPosition.positionDisplayName(from: "Overhead"), "OH")
        XCTAssertEqual(CrewPosition.positionDisplayName(from: "Underground"), "Underground")
    }

    func testNormalizedKeyMapsLegacyAndCanonicalRoles() {
        XCTAssertEqual(CrewPosition.normalizedKey(from: "Aerial"), CrewPosition.oh.rawValue)
        XCTAssertEqual(CrewPosition.normalizedKey(from: "underground"), CrewPosition.ug.rawValue)
        XCTAssertEqual(CrewPosition.normalizedKey(from: "can"), CrewPosition.can.rawValue)
        XCTAssertEqual(CrewPosition.normalizedKey(from: "NID"), CrewPosition.nid.rawValue)
        XCTAssertEqual(CrewPosition.normalizedKey(from: "Splicing"), "Splicing")
    }

    func testStatusNormalizationPreservesNeedsOHIntent() {
        XCTAssertEqual(CrewPosition.normalizedStatusForSaving("Needs Aerial"), "Needs OH")
        XCTAssertEqual(CrewPosition.statusDisplayName(from: "needs overhead"), "Needs OH")
        XCTAssertEqual(CrewPosition.normalizedStatusForSaving("Complete"), "Complete")
    }

    func testMatchesUsesNormalizedRoles() {
        XCTAssertTrue(CrewPosition.matches("Ariel", .oh))
        XCTAssertTrue(CrewPosition.matches("underground", .ug))
        XCTAssertFalse(CrewPosition.matches("can", .nid))
    }
}
