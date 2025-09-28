import XCTest
import CoreLocation
@testable import Job_Tracker

@MainActor
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
        let viewModel = FiberMapViewModel(storage: storage, searchProvider: MockMapSearchProvider())

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

        let reloadedViewModel = FiberMapViewModel(storage: storage, searchProvider: MockMapSearchProvider())
        XCTAssertTrue(reloadedViewModel.poles.contains(where: { $0.id == newPole.id }))
    }

    func testSearchResultsUpdateAndPersistCenter() async throws {
        let expectedResult = MapSearchResult(
            title: "Test Location",
            subtitle: "123 Test Street",
            coordinate: CLLocationCoordinate2D(latitude: 37.3317, longitude: -122.0301)
        )

        let searchProvider = MockMapSearchProvider(results: [expectedResult])
        let viewModel = FiberMapViewModel(storage: storage, searchProvider: searchProvider)

        await viewModel.searchLocations(for: "Test")
        XCTAssertEqual(viewModel.searchResults.count, 1)
        XCTAssertEqual(viewModel.searchResults.first?.title, expectedResult.title)

        guard let result = viewModel.searchResults.first else {
            XCTFail("Missing search result")
            return
        }

        viewModel.selectSearchResult(result)
        XCTAssertEqual(viewModel.mapCamera.latitude, expectedResult.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(viewModel.mapCamera.longitude, expectedResult.coordinate.longitude, accuracy: 0.0001)
        XCTAssertEqual(viewModel.pendingCenterCommand?.label, expectedResult.title)
        XCTAssertEqual(viewModel.pendingCenterCommand?.latitude, expectedResult.coordinate.latitude, accuracy: 0.0001)

        viewModel.acknowledgeCenterCommand()
        XCTAssertNil(viewModel.pendingCenterCommand)

        let reloadedViewModel = FiberMapViewModel(storage: storage, searchProvider: MockMapSearchProvider())
        XCTAssertEqual(reloadedViewModel.mapCamera.latitude, expectedResult.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(reloadedViewModel.mapCamera.longitude, expectedResult.coordinate.longitude, accuracy: 0.0001)
    }
}

private final class MockMapSearchProvider: MapSearchProviding {
    var results: [MapSearchResult]
    var error: Error?

    init(results: [MapSearchResult] = [], error: Error? = nil) {
        self.results = results
        self.error = error
    }

    func searchLocations(matching query: String) async throws -> [MapSearchResult] {
        if let error {
            throw error
        }
        return results
    }
}
