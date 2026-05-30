import XCTest
import FirebaseFirestore
@testable import Job_Tracker

final class ForceUpdateViewModelTests: XCTestCase {
    @MainActor
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

    @MainActor
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

    @MainActor
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


    @MainActor
    func testMonitoringStateTracksTrustedRemoteConfigSourceAndRequiredUI() async {
        let provider = MockAppUpdateRequirementProvider()
        let viewModel = ForceUpdateViewModel(
            provider: provider,
            currentVersionProvider: { "2.1.0" },
            currentBuildProvider: { "10" },
            trustedConfigSource: "test trusted source"
        )
        let requirement = AppUpdateRequirement(
            latestVersion: "2.3.0",
            latestBuild: "20",
            updateURL: URL(string: "https://apps.apple.com/app/job-tracker"),
            releaseNotes: "Security fix"
        )

        viewModel.startMonitoring()
        XCTAssertEqual(viewModel.monitoringState, .monitoring(source: "test trusted source"))
        provider.publish(.success(requirement))
        await Task.yield()

        XCTAssertEqual(viewModel.monitoringState, .updateRequired(source: "test trusted source"))
        let content = ForceUpdateViewContent(requirement: requirement, currentVersion: "2.1.0", currentBuild: "10")
        XCTAssertEqual(content.title, "Update Required")
        XCTAssertEqual(content.installedText, "Installed: 2.1.0 (10)")
        XCTAssertEqual(content.availableText, "Available: 2.3.0 (20)")
        XCTAssertEqual(content.releaseNotes, "Security fix")
        XCTAssertTrue(content.isUpdateButtonEnabled)
        XCTAssertEqual(content.accessibilityIdentifier, "ForceUpdateView")
    }

    @MainActor
    func testForcedUpdateUIExplainsMissingUpdateURL() {
        let requirement = AppUpdateRequirement(latestVersion: "2.3.0", updateURL: nil, releaseNotes: "   ")
        let content = ForceUpdateViewContent(requirement: requirement, currentVersion: "2.1.0", currentBuild: "10")

        XCTAssertEqual(content.availableText, "Available: 2.3.0")
        XCTAssertNil(content.releaseNotes)
        XCTAssertFalse(content.isUpdateButtonEnabled)
        XCTAssertEqual(content.missingUpdateURLMessage, "Ask your administrator for the latest install link.")
    }

    func testRemoteConfigDocumentParsesTrustedFirestorePayloadAndRejectsUntrustedURLScheme() {
        let document = AppUpdateRemoteConfigDocument(data: [
            "latestVersion": "2.4.0",
            "minimumRequiredVersion": "2.3.0",
            "latestBuild": "30",
            "minimumRequiredBuild": "25",
            "updateURL": "javascript:alert(1)",
            "releaseNotes": "Required security update",
            "forceUpdateEnabled": true
        ])

        let requirement = document.requirement
        XCTAssertEqual(requirement.latestVersion, "2.4.0")
        XCTAssertEqual(requirement.minimumRequiredVersion, "2.3.0")
        XCTAssertEqual(requirement.latestBuild, "30")
        XCTAssertEqual(requirement.minimumRequiredBuild, "25")
        XCTAssertNil(requirement.updateURL)
        XCTAssertEqual(requirement.releaseNotes, "Required security update")
        XCTAssertTrue(requirement.isEnabled)
    }

    @MainActor
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
