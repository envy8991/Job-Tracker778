import XCTest
@testable import Job_Tracker

final class CrewPositionTests: XCTestCase {
    func testLegacyOHAliasesDisplayAsOH() {
        XCTAssertEqual(CrewPosition.positionDisplayName(from: "Aerial"), "OH")
        XCTAssertEqual(CrewPosition.positionDisplayName(from: " ariel "), "OH")
        XCTAssertEqual(CrewPosition.positionDisplayName(from: "Arial"), "OH")
        XCTAssertEqual(CrewPosition.positionDisplayName(from: "Overhead"), "OH")
    }

    func testNormalizedKeyCollapsesKnownCrewPositions() {
        XCTAssertEqual(CrewPosition.normalizedKey(from: " underground "), "UG")
        XCTAssertEqual(CrewPosition.normalizedKey(from: "ug"), "UG")
        XCTAssertEqual(CrewPosition.normalizedKey(from: "can"), "Can")
        XCTAssertEqual(CrewPosition.normalizedKey(from: "nid"), "Nid")
        XCTAssertEqual(CrewPosition.normalizedKey(from: nil), "")
    }

    func testMatchesComparesRawValuesAgainstNormalizedCrewPosition() {
        XCTAssertTrue(CrewPosition.matches("aerial", .oh))
        XCTAssertTrue(CrewPosition.matches("Underground", .ug))
        XCTAssertTrue(CrewPosition.matches(" CAN ", .can))
        XCTAssertFalse(CrewPosition.matches("Nid", .oh))
    }

    func testStatusNormalizationKeepsNeedsOHConsistent() {
        XCTAssertEqual(CrewPosition.normalizedStatusForSaving("Needs Aerial"), "Needs OH")
        XCTAssertEqual(CrewPosition.statusDisplayName(from: " needs overhead "), "Needs OH")
        XCTAssertEqual(CrewPosition.normalizedStatusForSaving("Complete"), "Complete")
    }
}
