import XCTest
@testable import Job_Tracker

final class AddressDuplicateMatcherTests: XCTestCase {
    func testMatchesSameAddressWithDifferentCaseAndStreetSuffix() {
        let comparison = AddressDuplicateMatcher.compare(
            "1207 S Lexington st",
            "1207 s lexington Street"
        )

        XCTAssertTrue(comparison.isExact)
        XCTAssertFalse(comparison.isClose)
    }

    func testDoesNotMatchDifferentHouseNumbersOnSameStreet() {
        let comparison = AddressDuplicateMatcher.compare(
            "1207 S Lexington st",
            "1215 S Lexington Street"
        )

        XCTAssertFalse(comparison.isExact)
        XCTAssertFalse(comparison.isClose)
    }

    func testAllowsCloseMatchWhenStreetNumberMatchesAndStreetTokensAreSimilar() {
        let comparison = AddressDuplicateMatcher.compare(
            "1207 S Lexington st",
            "1207 S. Lexington"
        )

        XCTAssertFalse(comparison.isExact)
        XCTAssertTrue(comparison.isClose)
    }
}
