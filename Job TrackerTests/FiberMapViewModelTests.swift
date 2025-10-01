import XCTest
import CoreLocation
import Combine
@testable import Job_Tracker

@MainActor
final class FiberMapViewModelTests: XCTestCase {
    private var dataService: MockFiberAssetSyncService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        dataService = MockFiberAssetSyncService()
    }

    override func tearDownWithError() throws {
        dataService = nil
        try super.tearDownWithError()
    }

    func testPersistenceAcrossViewModelInstances() {
        let viewModel = FiberMapViewModel(dataService: dataService, searchProvider: MockMapSearchProvider())
        waitForInitialLoad(of: viewModel)

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

        let saveExpectation = expectation(description: "Remote save triggered")
        dataService.onSave = { snapshot in
            if snapshot.poles.contains(where: { $0.id == newPole.id }) {
                saveExpectation.fulfill()
            }
        }

        viewModel.saveItem(newPole)
        wait(for: [saveExpectation], timeout: 1.0)
        dataService.onSave = nil

        let reloadedViewModel = FiberMapViewModel(dataService: dataService, searchProvider: MockMapSearchProvider())
        waitForInitialLoad(of: reloadedViewModel)
        XCTAssertTrue(reloadedViewModel.poles.contains(where: { $0.id == newPole.id }))
    }

    func testSearchResultsUpdateAndPersistCenter() async throws {
        let expectedResult = MapSearchResult(
            title: "Test Location",
            subtitle: "123 Test Street",
            coordinate: CLLocationCoordinate2D(latitude: 37.3317, longitude: -122.0301)
        )

        let searchProvider = MockMapSearchProvider(results: [expectedResult])
        let viewModel = FiberMapViewModel(dataService: dataService, searchProvider: searchProvider)
        waitForInitialLoad(of: viewModel)

        await viewModel.searchLocations(for: "Test")
        XCTAssertEqual(viewModel.searchResults.count, 1)
        XCTAssertEqual(viewModel.searchResults.first?.title, expectedResult.title)

        guard let result = viewModel.searchResults.first else {
            XCTFail("Missing search result")
            return
        }

        let persisted = expectation(description: "Camera saved remotely")
        dataService.onSave = { snapshot in
            if snapshot.mapCamera?.latitude == expectedResult.coordinate.latitude {
                persisted.fulfill()
            }
        }

        viewModel.selectSearchResult(result)
        XCTAssertEqual(viewModel.mapCamera.latitude, expectedResult.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(viewModel.mapCamera.longitude, expectedResult.coordinate.longitude, accuracy: 0.0001)
        XCTAssertEqual(viewModel.pendingCenterCommand?.label, expectedResult.title)
        XCTAssertEqual(viewModel.pendingCenterCommand?.latitude, expectedResult.coordinate.latitude, accuracy: 0.0001)

        viewModel.acknowledgeCenterCommand()
        XCTAssertNil(viewModel.pendingCenterCommand)

        await viewModel.waitForPendingSync()
        wait(for: [persisted], timeout: 1.0)
        dataService.onSave = nil

        let reloadedViewModel = FiberMapViewModel(dataService: dataService, searchProvider: MockMapSearchProvider())
        waitForInitialLoad(of: reloadedViewModel)
        XCTAssertEqual(reloadedViewModel.mapCamera.latitude, expectedResult.coordinate.latitude, accuracy: 0.0001)
        XCTAssertEqual(reloadedViewModel.mapCamera.longitude, expectedResult.coordinate.longitude, accuracy: 0.0001)
    }

    func testPendingCenterCommandUpdatesWhenLocationServicePublishes() {
        let service = MockLocationService()
        let viewModel = FiberMapViewModel(dataService: dataService, searchProvider: MockMapSearchProvider())
        waitForInitialLoad(of: viewModel)
        viewModel.bindLocationService(service)

        let expectation = expectation(description: "Center command emitted")
        let cancellable = viewModel.$pendingCenterCommand
            .compactMap { $0 }
            .sink { command in
                XCTAssertEqual(command.latitude, 10.0, accuracy: 0.0001)
                XCTAssertEqual(command.longitude, 20.0, accuracy: 0.0001)
                XCTAssertEqual(command.kind, .userLocation)
                expectation.fulfill()
            }

        service.send(CLLocation(latitude: 10, longitude: 20))

        waitForExpectations(timeout: 1.0)
        cancellable.cancel()
    }

    func testLocateUserFallsBackToAuthorizationFlow() {
        let service = MockLocationService()
        let viewModel = FiberMapViewModel(dataService: dataService, searchProvider: MockMapSearchProvider())
        waitForInitialLoad(of: viewModel)

        viewModel.locateUser(using: service, authorizationStatus: .notDetermined)
        XCTAssertEqual(service.requestAuthorizationCallCount, 1)
        XCTAssertEqual(service.startUpdatesCallCount, 0)

        viewModel.locateUser(using: service, authorizationStatus: .authorizedWhenInUse)
        XCTAssertEqual(service.startUpdatesCallCount, 1)
    }

    private func waitForInitialLoad(of viewModel: FiberMapViewModel, timeout: TimeInterval = 1.0) {
        guard viewModel.isLoadingSnapshot else { return }

        let expectation = expectation(description: "Initial snapshot loaded")
        var cancellable: AnyCancellable?
        cancellable = viewModel.$isLoadingSnapshot
            .dropFirst()
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }

        wait(for: [expectation], timeout: timeout)
        cancellable?.cancel()
    }

    func testLocateButtonAccessibilityLabel() {
        XCTAssertEqual(MapsView.Accessibility.locateButtonLabel, "Show my location")
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

private final class MockLocationService: LocationServiceProviding {
    @Published private var currentValue: CLLocation?

    var current: CLLocation? { currentValue }
    var currentPublisher: AnyPublisher<CLLocation?, Never> { $currentValue.eraseToAnyPublisher() }

    private(set) var startUpdatesCallCount = 0
    private(set) var requestAuthorizationCallCount = 0

    init() {
        currentValue = nil
    }

    func send(_ location: CLLocation) {
        currentValue = location
    }

    func startStandardUpdates() {
        startUpdatesCallCount += 1
    }

    func requestAlwaysAuthorizationIfNeeded() {
        requestAuthorizationCallCount += 1
    }
}

private final class MockFiberAssetSyncService: FiberAssetSyncService {
    var currentSnapshot: FiberMapSnapshot?
    var onSave: ((FiberMapSnapshot) -> Void)?

    private var listener: ((Result<FiberMapSnapshot?, Error>) -> Void)?
    var shouldEmitErrorOnStart: Error?

    func beginListening(onChange: @escaping (Result<FiberMapSnapshot?, Error>) -> Void) {
        listener = onChange
        if let error = shouldEmitErrorOnStart {
            onChange(.failure(error))
        } else {
            onChange(.success(currentSnapshot))
        }
    }

    func stopListening() {
        listener = nil
    }

    func save(snapshot: FiberMapSnapshot) async throws {
        onSave?(snapshot)
        currentSnapshot = snapshot
    }

    func sendRemoteUpdate(_ snapshot: FiberMapSnapshot?) {
        listener?(.success(snapshot))
    }

    func sendError(_ error: Error) {
        listener?(.failure(error))
    }
}
