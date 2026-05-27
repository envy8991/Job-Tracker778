import XCTest
import Combine
@testable import Job_Tracker

@MainActor
final class AdminPanelViewModelTests: XCTestCase {
    private let sampleUsers: [AppUser] = [
        AppUser(id: "1", firstName: "Alex", lastName: "Anderson", email: "alex@example.com", position: "Tech"),
        AppUser(id: "2", firstName: "Blair", lastName: "Barnes", email: "blair@example.com", position: "Lead"),
        AppUser(id: "3", firstName: "Casey", lastName: "Chambers", email: "casey@example.com", position: "Supervisor")
    ]

    func testRosterUpdatesFromPublisher() async {
        let subject = CurrentValueSubject<[AppUser], Never>([sampleUsers[1], sampleUsers[0]])
        let mockService = MockAdminPanelService()
        let viewModel = AdminPanelViewModel(
            service: mockService,
            currentUserIDProvider: { nil },
            initialRoster: [],
            usersPublisher: subject.eraseToAnyPublisher()
        )

        await Task.yield()
        XCTAssertEqual(viewModel.roster.map(\.id), [sampleUsers[0].id, sampleUsers[1].id])

        subject.send([sampleUsers[2], sampleUsers[1]])
        await Task.yield()
        XCTAssertEqual(viewModel.roster.map(\.id), [sampleUsers[1].id, sampleUsers[2].id])
    }

    func testToggleAdminSuccessUpdatesState() async {
        let user = AppUser(id: "42", firstName: "Jamie", lastName: "Quinn", email: "jamie@example.com", position: "Tech")
        let subject = CurrentValueSubject<[AppUser], Never>([user])
        let mockService = MockAdminPanelService()
        let viewModel = AdminPanelViewModel(
            service: mockService,
            currentUserIDProvider: { user.id },
            initialRoster: [user],
            usersPublisher: subject.eraseToAnyPublisher()
        )

        var updatedUserIDs: [String] = []
        viewModel.onUserFlagsUpdated = { updatedUserIDs.append($0) }

        viewModel.setAdmin(true, for: user)
        XCTAssertTrue(viewModel.updatingAdminIDs.contains(user.id))
        XCTAssertEqual(mockService.lastUpdate?.uid, user.id)
        XCTAssertEqual(mockService.lastUpdate?.isAdmin, true)
        XCTAssertEqual(mockService.lastUpdate?.isSupervisor, user.isSupervisor)

        mockService.completeLastUpdate(with: .success(()))
        await Task.yield()

        XCTAssertTrue(updatedUserIDs.contains(user.id))
        XCTAssertTrue(mockService.didRefreshClaims)
        XCTAssertFalse(viewModel.updatingAdminIDs.contains(user.id))
        XCTAssertNil(viewModel.alert)
    }

    func testToggleSupervisorFailureShowsAlert() async {
        var user = AppUser(id: "55", firstName: "Morgan", lastName: "Reeves", email: "morgan@example.com", position: "Supervisor")
        user.isSupervisor = true
        let subject = CurrentValueSubject<[AppUser], Never>([user])
        let mockService = MockAdminPanelService()
        let viewModel = AdminPanelViewModel(
            service: mockService,
            currentUserIDProvider: { "other" },
            initialRoster: [user],
            usersPublisher: subject.eraseToAnyPublisher()
        )

        viewModel.setSupervisor(false, for: user)
        let expectedError = NSError(domain: "test", code: 99, userInfo: [NSLocalizedDescriptionKey: "Firestore write failed"])
        mockService.completeLastUpdate(with: .failure(expectedError))
        await Task.yield()

        XCTAssertNotNil(viewModel.alert)
        XCTAssertEqual(viewModel.alert?.message, expectedError.localizedDescription)
        XCTAssertFalse(mockService.didRefreshClaims)
    }

    func testBackfillProgressAndCompletion() async {
        let mockService = MockAdminPanelService()
        let viewModel = AdminPanelViewModel(service: mockService)

        XCTAssertFalse(viewModel.maintenanceStatus.isRunning)
        viewModel.runParticipantsBackfill()
        XCTAssertTrue(viewModel.maintenanceStatus.isRunning)

        let firstProgress = FirebaseService.AdminMaintenanceProgress(processed: 10, total: 50, message: "Batch 1 complete")
        mockService.sendProgress(firstProgress)
        await Task.yield()
        XCTAssertEqual(viewModel.maintenanceStatus.progress?.processed, firstProgress.processed)
        XCTAssertEqual(viewModel.maintenanceStatus.progress?.total, firstProgress.total)

        mockService.finishBackfill(.success(50))
        await Task.yield()

        XCTAssertFalse(viewModel.maintenanceStatus.isRunning)
        XCTAssertEqual(viewModel.maintenanceStatus.lastRunCount, 50)
        XCTAssertNil(viewModel.maintenanceStatus.progress)
        XCTAssertEqual(viewModel.alert?.kind, .success)
    }
}

private final class MockAdminPanelService: AdminPanelService {
    private(set) var lastUpdate: (uid: String, isAdmin: Bool, isSupervisor: Bool)?
    private var updateCompletion: ((Result<Void, Error>) -> Void)?
    private var backfillProgress: ((FirebaseService.AdminMaintenanceProgress) -> Void)?
    private var backfillCompletion: ((Result<Int, Error>) -> Void)?
    private(set) var didRefreshClaims = false

    func updateUserFlags(uid: String, isAdmin: Bool, isSupervisor: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        lastUpdate = (uid, isAdmin, isSupervisor)
        updateCompletion = completion
    }

    func adminBackfillParticipantsForAllJobs(progress: ((FirebaseService.AdminMaintenanceProgress) -> Void)?, completion: @escaping (Result<Int, Error>) -> Void) {
        backfillProgress = progress
        backfillCompletion = completion
    }

    func refreshCustomClaims(for uid: String?, completion: ((Error?) -> Void)?) {
        didRefreshClaims = true
        completion?(nil)
    }

    func completeLastUpdate(with result: Result<Void, Error>) {
        updateCompletion?(result)
        updateCompletion = nil
    }

    func sendProgress(_ progress: FirebaseService.AdminMaintenanceProgress) {
        backfillProgress?(progress)
    }

    func finishBackfill(_ result: Result<Int, Error>) {
        backfillCompletion?(result)
        backfillCompletion = nil
    }
}
