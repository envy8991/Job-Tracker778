import XCTest
@testable import Job_Tracker

#if DEBUG
@MainActor
final class AdminUpdateViewModelTests: XCTestCase {
    func testDebugUpdateHappyPathAndRollback() async {
        let service = MockAdminUpdateService()
        let viewModel = AdminUpdateViewModel(bundle: .main, service: service)
        let originalVersion = viewModel.currentVersion

        viewModel.checkForUpdates()
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.availableVersion, "9.9.0-debug")
        XCTAssertEqual(viewModel.changelog, ["Test release"])

        viewModel.downloadUpdate()
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.downloadedVersion, "9.9.0-debug")
        XCTAssertTrue(viewModel.hasDownloadedUpdate)

        viewModel.verifyDownload()
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.verificationStatus, .verified)

        viewModel.applyUpdate()
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.errorReason, "Enable maintenance mode and verify the package before applying.")
        XCTAssertEqual(viewModel.currentVersion, originalVersion)

        viewModel.resetError()
        viewModel.maintenanceModeEnabled = true
        viewModel.applyUpdate()
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.currentVersion, "9.9.0-debug")
        XCTAssertNil(viewModel.downloadedVersion)
        XCTAssertEqual(viewModel.verificationStatus, .notVerified)

        viewModel.rollbackUpdate()
        await waitForIdle(viewModel)
        XCTAssertEqual(viewModel.currentVersion, originalVersion)
        XCTAssertNil(viewModel.errorReason)
    }

    func testFailureStatesAreReportedAndResetBusyState() async {
        let service = MockAdminUpdateService(error: TestError.offline)
        let viewModel = AdminUpdateViewModel(bundle: .main, service: service)

        viewModel.checkForUpdates()
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.actionState, .idle)
        XCTAssertEqual(viewModel.errorReason, "Update check failed: offline")
        XCTAssertFalse(viewModel.logs.isEmpty)
    }

    func testVerificationFailureMarksPackageFailed() async {
        let service = MockAdminUpdateService(verificationError: TestError.badSignature)
        let viewModel = AdminUpdateViewModel(bundle: .main, service: service)

        viewModel.checkForUpdates()
        await waitForIdle(viewModel)
        viewModel.downloadUpdate()
        await waitForIdle(viewModel)
        viewModel.verifyDownload()
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.verificationStatus, .failed("bad signature"))
        XCTAssertEqual(viewModel.errorReason, "Verification failed: bad signature")
        XCTAssertFalse(viewModel.canApplyUpdate)
    }

    private func waitForIdle(_ viewModel: AdminUpdateViewModel) async {
        for _ in 0..<25 where viewModel.actionState != .idle {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }
}

private final class MockAdminUpdateService: AdminUpdateService {
    private let error: Error?
    private let verificationError: Error?

    init(error: Error? = nil, verificationError: Error? = nil) {
        self.error = error
        self.verificationError = verificationError
    }

    func checkForUpdates(currentVersion: String) async throws -> AdminUpdateViewModel.UpdateManifest? {
        if let error { throw error }
        return AdminUpdateViewModel.UpdateManifest(version: "9.9.0-debug", changelog: ["Test release"])
    }

    func downloadUpdate(version: String, progress: @escaping @MainActor (Double) -> Void) async throws -> AdminUpdateViewModel.DownloadedPackage {
        if let error { throw error }
        await progress(1)
        return AdminUpdateViewModel.DownloadedPackage(version: version, checksum: "checksum")
    }

    func verifyDownload(_ package: AdminUpdateViewModel.DownloadedPackage, progress: @escaping @MainActor (Double) -> Void) async throws {
        if let verificationError { throw verificationError }
        if let error { throw error }
        await progress(1)
    }

    func applyUpdate(_ package: AdminUpdateViewModel.DownloadedPackage) async throws {
        if let error { throw error }
    }

    func rollback(to version: String) async throws {
        if let error { throw error }
    }
}

private enum TestError: LocalizedError {
    case offline
    case badSignature

    var errorDescription: String? {
        switch self {
        case .offline: return "offline"
        case .badSignature: return "bad signature"
        }
    }
}
#endif
