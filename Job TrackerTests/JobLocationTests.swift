import CoreLocation
import XCTest
@testable import Job_Tracker

final class JobLocationTests: XCTestCase {
    func testLocationUsesValidCoordinates() throws {
        let job = makeJob(latitude: 36.1627, longitude: -86.7816)

        let location = try XCTUnwrap(job.clLocation)
        XCTAssertEqual(location.coordinate.latitude, 36.1627, accuracy: 0.000_001)
        XCTAssertEqual(location.coordinate.longitude, -86.7816, accuracy: 0.000_001)
    }

    func testLocationRejectsMissingNonFiniteAndOutOfRangeCoordinates() {
        XCTAssertNil(makeJob(latitude: nil, longitude: -86).clLocation)
        XCTAssertNil(makeJob(latitude: 36, longitude: nil).clLocation)
        XCTAssertNil(makeJob(latitude: .nan, longitude: -86).clLocation)
        XCTAssertNil(makeJob(latitude: 36, longitude: .infinity).clLocation)
        XCTAssertNil(makeJob(latitude: 90.000_001, longitude: 0).clLocation)
        XCTAssertNil(makeJob(latitude: 0, longitude: -180.000_001).clLocation)
    }

    func testLocationAcceptsBoundaryCoordinates() {
        XCTAssertNotNil(makeJob(latitude: -90, longitude: -180).clLocation)
        XCTAssertNotNil(makeJob(latitude: 90, longitude: 180).clLocation)
    }

    private func makeJob(latitude: Double?, longitude: Double?) -> Job {
        Job(
            address: "123 Main Street",
            date: Date(),
            status: "Pending",
            latitude: latitude,
            longitude: longitude
        )
    }
}
