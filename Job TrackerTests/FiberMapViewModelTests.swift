import XCTest
import CoreLocation
@testable import Job_Tracker

final class FiberMapViewModelTests: XCTestCase {
    private var tempDirectory: URL!
    private var storage: FiberMapStorage!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        storage = FiberMapStorage(directoryURL: tempDirectory, fileName: "FiberMapTest.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        storage = nil
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testPersistenceAcrossViewModelInstances() {
        let viewModel = FiberMapViewModel(storage: storage)

        let newPole = Pole(
            id: UUID(),
            name: "Persisted Pole",
            coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 2),
            status: .good,
            installDate: nil,
            lastInspection: nil,
            material: "Steel",
            notes: "Persistence test",
            imageUrl: nil
        )

        viewModel.saveItem(newPole)

        let reloadedViewModel = FiberMapViewModel(storage: storage)
        XCTAssertTrue(reloadedViewModel.poles.contains(where: { $0.id == newPole.id }))
    }
}
