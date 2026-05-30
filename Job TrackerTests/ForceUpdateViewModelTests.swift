import XCTest
import FirebaseFirestore
@testable import Job_Tracker

@MainActor
final class ForceUpdateViewModelTests: XCTestCase {
    func testStartMonitoringAppliesProviderRequirementDecision() async {
        let provider = MockAppUpdateRequirementProvider()
        let viewModel = ForceUpdateViewModel(
            provider: provider,
            currentVersionProvider: { "2.0.0" },
            currentBuildProvider: { "10" }
        )

        viewModel.startMonitoring()
        provider.send(.success(AppUpdateRequirement(latestVersion: "2.1.0")))
        await Task.yield()

        XCTAssertEqual(provider.observeCallCount, 1)
        XCTAssertEqual(viewModel.decision, .updateRequired(AppUpdateRequirement(latestVersion: "2.1.0")))
        XCTAssertNil(viewModel.lastErrorMessage)
    }

    func testStartMonitoringIsIdempotent() {
        let provider = MockAppUpdateRequirementProvider()
        let viewModel = ForceUpdateViewModel(provider: provider)

        viewModel.startMonitoring()
        viewModel.startMonitoring()

        XCTAssertEqual(provider.observeCallCount, 1)
    }

    func testProviderFailureRecordsErrorAndKeepsCurrentDecision() async {
        let provider = MockAppUpdateRequirementProvider()
        let viewModel = ForceUpdateViewModel(
            provider: provider,
            currentVersionProvider: { "2.0.0" },
            currentBuildProvider: { "10" }
        )

        viewModel.startMonitoring()
        provider.send(.success(nil))
        await Task.yield()
        XCTAssertEqual(viewModel.decision, .upToDate)

        provider.send(.failure(MockUpdateRequirementError.unavailable))
        await Task.yield()

        XCTAssertEqual(viewModel.decision, .upToDate)
        XCTAssertEqual(viewModel.lastErrorMessage, MockUpdateRequirementError.unavailable.localizedDescription)
    }
}

private final class MockAppUpdateRequirementProvider: AppUpdateRequirementProviding {
    private(set) var observeCallCount = 0
    private var onChange: ((Result<AppUpdateRequirement?, Error>) -> Void)?

    @discardableResult
    func observeRequirement(_ onChange: @escaping (Result<AppUpdateRequirement?, Error>) -> Void) -> ListenerRegistration? {
        observeCallCount += 1
        self.onChange = onChange
        return MockListenerRegistration()
    }

    func send(_ result: Result<AppUpdateRequirement?, Error>) {
        onChange?(result)
    }
}

private final class MockListenerRegistration: ListenerRegistration {
    func remove() {}
}

private enum MockUpdateRequirementError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        "Update requirement unavailable"
    }
}
