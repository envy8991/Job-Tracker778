import Foundation
import Combine
import FirebaseFirestore

protocol AppUpdateRequirementProviding {
    @discardableResult
    func observeRequirement(_ onChange: @escaping (Result<AppUpdateRequirement?, Error>) -> Void) -> ListenerRegistration?
}

final class FirestoreAppUpdateRequirementProvider: AppUpdateRequirementProviding {
    private let db: Firestore
    private let collection: String
    private let documentID: String

    init(
        db: Firestore = Firestore.firestore(),
        collection: String = "app_config",
        documentID: String = "ios_version"
    ) {
        self.db = db
        self.collection = collection
        self.documentID = documentID
    }

    @discardableResult
    func observeRequirement(_ onChange: @escaping (Result<AppUpdateRequirement?, Error>) -> Void) -> ListenerRegistration? {
        db.collection(collection).document(documentID).addSnapshotListener { snapshot, error in
            if let error {
                onChange(.failure(error))
                return
            }

            guard let data = snapshot?.data(), snapshot?.exists == true else {
                onChange(.success(nil))
                return
            }

            let updateURL: URL?
            if let urlString = data["updateURL"] as? String {
                updateURL = URL(string: urlString)
            } else {
                updateURL = nil
            }

            let requirement = AppUpdateRequirement(
                latestVersion: data["latestVersion"] as? String ?? data["minimumRequiredVersion"] as? String ?? "0",
                minimumRequiredVersion: data["minimumRequiredVersion"] as? String,
                latestBuild: data["latestBuild"] as? String,
                minimumRequiredBuild: data["minimumRequiredBuild"] as? String,
                updateURL: updateURL,
                releaseNotes: data["releaseNotes"] as? String,
                isEnabled: data["forceUpdateEnabled"] as? Bool ?? true
            )
            onChange(.success(requirement))
        }
    }
}

@MainActor
final class ForceUpdateViewModel: ObservableObject {
    @Published private(set) var decision: AppUpdateDecision = .upToDate
    @Published private(set) var lastErrorMessage: String?

    private let provider: AppUpdateRequirementProviding
    private let currentVersionProvider: () -> String
    private let currentBuildProvider: () -> String
    private var listener: ListenerRegistration?

    init(
        provider: AppUpdateRequirementProviding = FirestoreAppUpdateRequirementProvider(),
        currentVersionProvider: @escaping () -> String = { Bundle.main.appShortVersion },
        currentBuildProvider: @escaping () -> String = { Bundle.main.appBuildVersion }
    ) {
        self.provider = provider
        self.currentVersionProvider = currentVersionProvider
        self.currentBuildProvider = currentBuildProvider
    }

    deinit {
        listener?.remove()
    }

    func startMonitoring() {
        guard listener == nil else { return }

        listener = provider.observeRequirement { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case let .success(requirement):
                    self.lastErrorMessage = nil
                    self.decision = AppVersionComparator.decision(
                        currentVersion: self.currentVersionProvider(),
                        currentBuild: self.currentBuildProvider(),
                        requirement: requirement
                    )
                case let .failure(error):
                    self.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }
}
