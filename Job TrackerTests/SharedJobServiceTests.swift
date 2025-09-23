import XCTest
import CoreLocation
import FirebaseFirestore
import FirebaseFirestoreSwift
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
            fromUserName: "Sender Example",
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
            fromUserName: nil,
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

    func testSharedJobPayloadRoundTripsSenderNameThroughFirestore() throws {
        let payload = SharedJobPayload(
            v: 2,
            createdAt: Timestamp(date: Date()),
            fromUserId: "user-42",
            fromUserName: "Pat Smith",
            address: "123 Main St",
            date: Timestamp(date: Date()),
            status: "Scheduled",
            jobNumber: "JT-500",
            assignment: "Crew A",
            senderIsCan: true
        )

        let encoded = try Firestore.Encoder().encode(payload)
        let decoded = try Firestore.Decoder().decode(SharedJobPayload.self, from: encoded)
        let preview = SharedJobPreview(token: "token-1", payload: decoded)

        XCTAssertEqual(decoded.fromUserName, "Pat Smith")
        XCTAssertEqual(decoded.senderDisplayName, "Pat Smith")
        XCTAssertEqual(preview.payload.senderDisplayName, "Pat Smith")
    }

    func testSharedJobPayloadSenderDisplayNameFallsBackToUserId() {
        let payload = SharedJobPayload(
            v: 2,
            createdAt: Timestamp(date: Date()),
            fromUserId: "user-42",
            fromUserName: nil,
            address: "123 Main St",
            date: Timestamp(date: Date()),
            status: "Scheduled",
            jobNumber: nil,
            assignment: nil,
            senderIsCan: false
        )

        XCTAssertEqual(payload.senderDisplayName, "user-42")

        let preview = SharedJobPreview(token: "token-1", payload: payload)
        XCTAssertEqual(preview.payload.senderDisplayName, "user-42")
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
