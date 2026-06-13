import XCTest
@testable import Job_Tracker

@MainActor
final class DashboardSyncStateTests: XCTestCase {
    func testCompletedSyncCycleResetsBeforeNextCycle() async throws {
        let viewModel = DashboardViewModel()

        viewModel.handleSyncStateChange(total: 1, done: 1, inFlight: 0)
        XCTAssertEqual(viewModel.syncTotal, 1)
        XCTAssertEqual(viewModel.syncDone, 1)

        try await Task.sleep(nanoseconds: 1_200_000_000)

        XCTAssertFalse(viewModel.showSyncBanner)
        XCTAssertEqual(viewModel.syncTotal, 0)
        XCTAssertEqual(viewModel.syncDone, 0)

        viewModel.handleSyncStateChange(total: 1, done: 0, inFlight: 1)

        XCTAssertEqual(viewModel.syncTotal, 1)
        XCTAssertEqual(viewModel.syncDone, 0)
        XCTAssertEqual(viewModel.syncInFlight, 1)
        XCTAssertTrue(viewModel.showSyncBanner)
    }

    func testFailedPhotoUploadKeepsDetailsVisibleWithoutActiveUpload() {
        let viewModel = DashboardViewModel()

        viewModel.handlePhotoUploadSyncStateChange(total: 1, done: 0, inFlight: 0, failed: 1)

        XCTAssertEqual(viewModel.syncTotal, 1)
        XCTAssertEqual(viewModel.syncDone, 0)
        XCTAssertEqual(viewModel.syncFailed, 1)
        XCTAssertTrue(viewModel.showSyncBanner)
    }
}
