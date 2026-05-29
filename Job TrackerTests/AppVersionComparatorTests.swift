import XCTest
@testable import Job_Tracker

final class AppVersionComparatorTests: XCTestCase {
    func testSemanticVersionsCompareNumerically() {
        XCTAssertEqual(AppVersionComparator.compare("1.10.0", "1.2.9"), .orderedDescending)
        XCTAssertEqual(AppVersionComparator.compare("2.0", "2.0.0"), .orderedSame)
        XCTAssertEqual(AppVersionComparator.compare("2.0.1", "2.1"), .orderedAscending)
    }

    func testNewerLatestVersionRequiresUpdate() {
        let requirement = AppUpdateRequirement(latestVersion: "2.2.0")
        let decision = AppVersionComparator.decision(
            currentVersion: "2.1.10",
            currentBuild: "16",
            requirement: requirement
        )

        XCTAssertEqual(decision, .updateRequired(requirement))
    }

    func testDisabledRequirementDoesNotBlockApp() {
        let requirement = AppUpdateRequirement(latestVersion: "9.0.0", isEnabled: false)
        let decision = AppVersionComparator.decision(
            currentVersion: "1.0.0",
            currentBuild: "1",
            requirement: requirement
        )

        XCTAssertEqual(decision, .upToDate)
    }

    func testNewerBuildForSameVersionRequiresUpdate() {
        let requirement = AppUpdateRequirement(latestVersion: "2.1.10", latestBuild: "20")
        let decision = AppVersionComparator.decision(
            currentVersion: "2.1.10",
            currentBuild: "16",
            requirement: requirement
        )

        XCTAssertEqual(decision, .updateRequired(requirement))
    }
}
