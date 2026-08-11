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

    func testLegacySupervisorStatusUsesCurrentDisplayText() {
        XCTAssertEqual(CrewPosition.statusDisplayName(from: " Talk to Rick "), "Talk to Supervisor")
        XCTAssertEqual(CrewPosition.statusDisplayName(from: "Talk to Supervisor"), "Talk to Supervisor")
    }

    func testLegacySupervisorStatusDecodesAsCurrentValue() throws {
        let legacyJob = Job(address: "1 Main St", date: Date(timeIntervalSinceReferenceDate: 1), status: "Pending")
        let encoded = try JSONEncoder().encode(legacyJob)
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        document["status"] = "Talk to Rick"

        let decoded = try JSONDecoder().decode(Job.self, from: JSONSerialization.data(withJSONObject: document))

        XCTAssertEqual(decoded.status, "Talk to Supervisor")
    }

    func testNewSupervisorStatusIsSavedAsDisplayLabel() throws {
        let job = Job(address: "1 Main St", date: Date(), status: " talk to supervisor ")
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(job)) as? [String: Any])

        XCTAssertEqual(job.status, "Talk to Supervisor")
        XCTAssertEqual(document["status"] as? String, "Talk to Supervisor")
    }

    @available(iOS 26.0, *)
    func testAppIntentSupervisorStatusRawAndDisplayValues() {
        XCTAssertEqual(JobStatusIntentEnum.talkToSupervisor.rawValue, "Talk to Supervisor")
        let representation = JobStatusIntentEnum.caseDisplayRepresentations[.talkToSupervisor]
        XCTAssertEqual(representation.map { String(localized: $0.title) }, "Talk to Supervisor")
        XCTAssertNil(JobStatusIntentEnum(rawValue: "Talk to Rick"))
    }
}
