import Foundation
import Combine

protocol AdminPanelService: AnyObject {
    func updateUserFlags(
        uid: String,
        isAdmin: Bool,
        isSupervisor: Bool,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    func adminBackfillParticipantsForAllJobs(
        progress: ((FirebaseService.AdminMaintenanceProgress) -> Void)?,
        completion: @escaping (Result<Int, Error>) -> Void
    )

    func refreshCustomClaims(for uid: String?, completion: ((Error?) -> Void)?)
}

@MainActor
final class AdminPanelViewModel: ObservableObject {
    struct AlertItem: Identifiable, Equatable {
        enum Kind: Equatable {
            case success
            case error
        }

        let id = UUID()
        let title: String
        let message: String
        let kind: Kind
    }

    struct MaintenanceStatus: Equatable {
        struct Progress: Equatable {
            let processed: Int
            let total: Int
            let message: String

            var fractionComplete: Double? {
                guard total > 0 else { return nil }
                return Double(processed) / Double(total)
            }
        }

        var isRunning: Bool = false
        var progress: Progress? = nil
        var lastRunCount: Int? = nil
        var lastErrorMessage: String? = nil

        static var idle: MaintenanceStatus { MaintenanceStatus() }
    }

    @Published private(set) var roster: [AppUser]
    @Published private(set) var updatingAdminIDs: Set<String> = []
    @Published private(set) var updatingSupervisorIDs: Set<String> = []
    @Published var alert: AlertItem?
    @Published private(set) var maintenanceStatus: MaintenanceStatus = .idle

    var onUserFlagsUpdated: ((String) -> Void)?

    private let service: AdminPanelService
    private let currentUserIDProvider: () -> String?
    private var rosterCancellable: AnyCancellable?
    private var observedUsersViewModel: UsersViewModel?

    init(
        service: AdminPanelService = FirebaseService.shared,
        currentUserIDProvider: @escaping () -> String? = { FirebaseService.shared.currentUserID() },
        initialRoster: [AppUser] = [],
        usersPublisher: AnyPublisher<[AppUser], Never>? = nil
    ) {
        self.service = service
        self.currentUserIDProvider = currentUserIDProvider
        self.roster = initialRoster.sorted { lhs, rhs in
            lhs.lastName.lowercased() < rhs.lastName.lowercased()
        }

        if let publisher = usersPublisher {
            subscribe(to: publisher)
        }
    }

    func attach(usersViewModel: UsersViewModel) {
        if let observed = observedUsersViewModel, observed === usersViewModel { return }
        observedUsersViewModel = usersViewModel
        roster = usersViewModel.allUsers
        let publisher = usersViewModel.$usersDict
            .map { dict in
                dict.values.sorted { lhs, rhs in
                    lhs.lastName.lowercased() < rhs.lastName.lowercased()
                }
            }
            .eraseToAnyPublisher()
        subscribe(to: publisher)
    }

    func refreshRosterSnapshot() {
        if let observedUsersViewModel {
            roster = observedUsersViewModel.allUsers
        }
    }

    func setAdmin(_ isAdmin: Bool, for user: AppUser) {
        updateFlags(for: user, admin: isAdmin, supervisor: user.isSupervisor, changedFlag: .admin)
    }

    func setSupervisor(_ isSupervisor: Bool, for user: AppUser) {
        updateFlags(for: user, admin: user.isAdmin, supervisor: isSupervisor, changedFlag: .supervisor)
    }

    func isMutating(userID: String) -> Bool {
        updatingAdminIDs.contains(userID) || updatingSupervisorIDs.contains(userID)
    }

    func runParticipantsBackfill() {
        guard !maintenanceStatus.isRunning else { return }

        maintenanceStatus = MaintenanceStatus(
            isRunning: true,
            progress: MaintenanceStatus.Progress(processed: 0, total: 0, message: "Preparing…"),
            lastRunCount: maintenanceStatus.lastRunCount,
            lastErrorMessage: nil
        )

        service.adminBackfillParticipantsForAllJobs(progress: { [weak self] update in
            guard let self else { return }
            Task { @MainActor in
                var status = self.maintenanceStatus
                status.isRunning = true
                status.progress = MaintenanceStatus.Progress(
                    processed: update.processed,
                    total: update.total,
                    message: update.message
                )
                status.lastErrorMessage = nil
                self.maintenanceStatus = status
            }
        }, completion: { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                var status = self.maintenanceStatus
                status.isRunning = false
                status.progress = nil
                switch result {
                case .success(let count):
                    status.lastRunCount = count
                    status.lastErrorMessage = nil
                    self.alert = AlertItem(
                        title: "Backfill Complete",
                        message: "Updated \(count) job\(count == 1 ? "" : "s").",
                        kind: .success
                    )
                case .failure(let error):
                    status.lastErrorMessage = error.localizedDescription
                    self.alert = AlertItem(
                        title: "Backfill Failed",
                        message: error.localizedDescription,
                        kind: .error
                    )
                }
                self.maintenanceStatus = status
            }
        })
    }

    private enum ChangedFlag {
        case admin
        case supervisor
    }

    private func subscribe(to publisher: AnyPublisher<[AppUser], Never>) {
        rosterCancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] users in
                self?.roster = users.sorted { lhs, rhs in
                    lhs.lastName.lowercased() < rhs.lastName.lowercased()
                }
            }
    }

    private func updateFlags(
        for user: AppUser,
        admin: Bool,
        supervisor: Bool,
        changedFlag: ChangedFlag
    ) {
        let userID = user.id
        if updatingAdminIDs.contains(userID) || updatingSupervisorIDs.contains(userID) {
            return
        }

        switch changedFlag {
        case .admin:
            updatingAdminIDs.insert(userID)
        case .supervisor:
            updatingSupervisorIDs.insert(userID)
        }

        service.updateUserFlags(uid: userID, isAdmin: admin, isSupervisor: supervisor) { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                self.updatingAdminIDs.remove(userID)
                self.updatingSupervisorIDs.remove(userID)

                switch result {
                case .success:
                    if self.currentUserIDProvider() == userID {
                        self.service.refreshCustomClaims(for: userID, completion: nil)
                    }
                    self.onUserFlagsUpdated?(userID)
                case .failure(let error):
                    self.alert = AlertItem(
                        title: "Update Failed",
                        message: error.localizedDescription,
                        kind: .error
                    )
                }
            }
        }
    }
}

extension AdminPanelViewModel.MaintenanceStatus.Progress {
    init(processed: Int, total: Int, message: String) {
        self.processed = processed
        self.total = total
        self.message = message
    }
}
