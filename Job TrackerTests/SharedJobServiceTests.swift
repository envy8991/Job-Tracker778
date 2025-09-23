import XCTest
import CoreLocation
import FirebaseFirestore
@testable import Job_Tracker

final class SharedJobServiceTests: XCTestCase {
    func testMakeJobAssignsCoordinatesWhenGeocodingSucceeds() async {
        let service = SharedJobService.shared
        let originalGeocoder = service.geocoder
        defer { service.geocoder = originalGeocoder }

        let expectedCoordinate = CLLocationCoordinate2D(latitude: 37.3317, longitude: -122.0301)
        let mockGeocoder = MockGeocoder(coordinate: expectedCoordinate)
        service.geocoder = mockGeocoder

        let payload = SharedJobPayload(
            v: 2,
            createdAt: Timestamp(date: Date()),
            fromUserId: "sender-123",
            address: "1 Infinite Loop, Cupertino, CA",
            date: Timestamp(date: Date()),
            status: "Pending",
            jobNumber: "JT-101",
            assignment: nil,
            senderIsCan: false
        )

        let job = await service.makeJob(
            from: payload,
            receiverIsCAN: false,
            currentUserID: "receiver-456"
        )

        XCTAssertEqual(job.latitude, expectedCoordinate.latitude)
        XCTAssertEqual(job.longitude, expectedCoordinate.longitude)
    }

    func testMakeJobLeavesCoordinatesNilWhenGeocodingFails() async {
        let service = SharedJobService.shared
        let originalGeocoder = service.geocoder
        defer { service.geocoder = originalGeocoder }

        service.geocoder = MockGeocoder(coordinate: nil, error: MockGeocoder.MockError.failed)

        let payload = SharedJobPayload(
            v: 2,
            createdAt: Timestamp(date: Date()),
            fromUserId: "sender-123",
            address: "Unknown",
            date: Timestamp(date: Date()),
            status: "Pending",
            jobNumber: nil,
            assignment: nil,
            senderIsCan: false
        )

        let job = await service.makeJob(
            from: payload,
            receiverIsCAN: false,
            currentUserID: "receiver-456"
        )

        XCTAssertNil(job.latitude)
        XCTAssertNil(job.longitude)
    }
}

private final class MockGeocoder: SharedJobGeocoding {
    enum MockError: Error {
        case failed
    }

    private let coordinateResult: CLLocationCoordinate2D?
    private let error: Error?

    init(coordinate: CLLocationCoordinate2D?, error: Error? = nil) {
        self.coordinateResult = coordinate
        self.error = error
    }

    func coordinate(for address: String) async throws -> CLLocationCoordinate2D? {
        if let error {
            throw error
        }
        return coordinateResult
    }
}
