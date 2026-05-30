import XCTest
import FirebaseFirestore
@testable import Job_Tracker

@MainActor
final class ForceUpdateViewModelTests: XCTestCase {
    func testStartMonitoringRequiresUpdateWhenProviderPublishesNewerMinimumVersion() async {
        let provider = MockAppUpdateRequirementProvider()
        let viewModel = ForceUpdateViewModel(
            provider: provider,
            currentVersionProvider: { "2.1.0" },
            currentBuildProvider: { "10" }
        )

        viewModel.startMonitoring()
        provider.publish(.success(AppUpdateRequirement(latestVersion: "2.2.0", minimumRequiredVersion: "2.1.1")))
        await Task.yield()

        guard case let .updateRequired(requirement) = viewModel.decision else {
            return XCTFail("Expected updateRequired decision")
        }
        XCTAssertEqual(requirement.latestVersion, "2.2.0")
        XCTAssertNil(viewModel.lastErrorMessage)
    }

    func testStartMonitoringLeavesCurrentAppUpToDateWhenRequirementIsDisabled() async {
        let provider = MockAppUpdateRequirementProvider()
        let viewModel = ForceUpdateViewModel(
            provider: provider,
            currentVersionProvider: { "2.1.0" },
            currentBuildProvider: { "10" }
        )

        viewModel.startMonitoring()
        provider.publish(.success(AppUpdateRequirement(latestVersion: "9.0.0", isEnabled: false)))
        await Task.yield()

        XCTAssertEqual(viewModel.decision, .upToDate)
        XCTAssertNil(viewModel.lastErrorMessage)
    }

    func testStartMonitoringStoresErrorWithoutChangingLastDecision() async {
        let provider = MockAppUpdateRequirementProvider()
        let viewModel = ForceUpdateViewModel(
            provider: provider,
            currentVersionProvider: { "2.1.0" },
            currentBuildProvider: { "10" }
        )
        let requirement = AppUpdateRequirement(latestVersion: "2.2.0")
        let error = NSError(domain: "ForceUpdateViewModelTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "offline"])

        viewModel.startMonitoring()
        provider.publish(.success(requirement))
        await Task.yield()
        provider.publish(.failure(error))
        await Task.yield()

        XCTAssertEqual(viewModel.decision, .updateRequired(requirement))
        XCTAssertEqual(viewModel.lastErrorMessage, "offline")
    }

    func testStartMonitoringOnlyRegistersOneProviderListener() {
        let provider = MockAppUpdateRequirementProvider()
        let viewModel = ForceUpdateViewModel(provider: provider)

        viewModel.startMonitoring()
        viewModel.startMonitoring()

        XCTAssertEqual(provider.observeCallCount, 1)
    }
}

private final class MockAppUpdateRequirementProvider: AppUpdateRequirementProviding {
    private var onChange: ((Result<AppUpdateRequirement?, Error>) -> Void)?
    private(set) var observeCallCount = 0

    @discardableResult
    func observeRequirement(_ onChange: @escaping (Result<AppUpdateRequirement?, Error>) -> Void) -> ListenerRegistration? {
        observeCallCount += 1
        self.onChange = onChange
        return nil
    }

    func publish(_ result: Result<AppUpdateRequirement?, Error>) {
        onChange?(result)
    }
}
