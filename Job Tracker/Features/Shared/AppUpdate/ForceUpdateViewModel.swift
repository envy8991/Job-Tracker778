import Foundation
import Combine
import FirebaseFirestore

protocol AppUpdateRequirementProviding {
    @discardableResult
    func observeRequirement(_ onChange: @escaping (Result<AppUpdateRequirement?, Error>) -> Void) -> ListenerRegistration?
}

struct AppUpdateRemoteConfigDocument: Equatable {
    static let collection = "app_config"
    static let documentID = "ios_version"
    static let trustedSourceDescription = "Firestore app_config/ios_version"

    let latestVersion: String
    let minimumRequiredVersion: String?
    let latestBuild: String?
    let minimumRequiredBuild: String?
    let updateURLString: String?
    let releaseNotes: String?
    let forceUpdateEnabled: Bool

    init(
        latestVersion: String,
        minimumRequiredVersion: String? = nil,
        latestBuild: String? = nil,
        minimumRequiredBuild: String? = nil,
        updateURLString: String? = nil,
        releaseNotes: String? = nil,
        forceUpdateEnabled: Bool = true
    ) {
        self.latestVersion = latestVersion
        self.minimumRequiredVersion = minimumRequiredVersion
        self.latestBuild = latestBuild
        self.minimumRequiredBuild = minimumRequiredBuild
        self.updateURLString = updateURLString
        self.releaseNotes = releaseNotes
        self.forceUpdateEnabled = forceUpdateEnabled
    }

    init(data: [String: Any]) {
        self.init(
            latestVersion: data["latestVersion"] as? String ?? data["minimumRequiredVersion"] as? String ?? "0",
            minimumRequiredVersion: data["minimumRequiredVersion"] as? String,
            latestBuild: data["latestBuild"] as? String,
            minimumRequiredBuild: data["minimumRequiredBuild"] as? String,
            updateURLString: data["updateURL"] as? String,
            releaseNotes: data["releaseNotes"] as? String,
            forceUpdateEnabled: data["forceUpdateEnabled"] as? Bool ?? true
        )
    }

    var requirement: AppUpdateRequirement {
        AppUpdateRequirement(
            latestVersion: latestVersion,
            minimumRequiredVersion: minimumRequiredVersion,
            latestBuild: latestBuild,
            minimumRequiredBuild: minimumRequiredBuild,
            updateURL: trustedUpdateURL,
            releaseNotes: releaseNotes,
            isEnabled: forceUpdateEnabled
        )
    }

    private var trustedUpdateURL: URL? {
        guard let updateURLString else { return nil }
        let trimmed = updateURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), ["https", "itms-apps"].contains(url.scheme?.lowercased()) else {
            return nil
        }
        return url
    }
}

final class FirestoreAppUpdateRequirementProvider: AppUpdateRequirementProviding {
    private let db: Firestore
    private let collection: String
    private let documentID: String

    init(
        db: Firestore = Firestore.firestore(),
        collection: String = AppUpdateRemoteConfigDocument.collection,
        documentID: String = AppUpdateRemoteConfigDocument.documentID
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

            let remoteConfig = AppUpdateRemoteConfigDocument(data: data)
            onChange(.success(remoteConfig.requirement))
        }
    }
}

enum ForceUpdateMonitoringState: Equatable {
    case idle
    case monitoring(source: String)
    case upToDate(source: String)
    case updateRequired(source: String)
    case failed(source: String, message: String)
}

@MainActor
final class ForceUpdateViewModel: ObservableObject {
    @Published private(set) var decision: AppUpdateDecision = .upToDate
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var monitoringState: ForceUpdateMonitoringState = .idle

    private let provider: AppUpdateRequirementProviding
    private let currentVersionProvider: () -> String
    private let currentBuildProvider: () -> String
    private let trustedConfigSource: String
    private var listener: ListenerRegistration?

    init(
        provider: AppUpdateRequirementProviding = FirestoreAppUpdateRequirementProvider(),
        currentVersionProvider: @escaping () -> String = { Bundle.main.appShortVersion },
        currentBuildProvider: @escaping () -> String = { Bundle.main.appBuildVersion },
        trustedConfigSource: String = AppUpdateRemoteConfigDocument.trustedSourceDescription
    ) {
        self.provider = provider
        self.currentVersionProvider = currentVersionProvider
        self.currentBuildProvider = currentBuildProvider
        self.trustedConfigSource = trustedConfigSource
    }

    deinit {
        listener?.remove()
    }

    func startMonitoring() {
        guard listener == nil else { return }
        monitoringState = .monitoring(source: trustedConfigSource)

        listener = provider.observeRequirement { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case let .success(requirement):
                    self.lastErrorMessage = nil
                    let decision = AppVersionComparator.decision(
                        currentVersion: self.currentVersionProvider(),
                        currentBuild: self.currentBuildProvider(),
                        requirement: requirement
                    )
                    self.decision = decision
                    switch decision {
                    case .upToDate:
                        self.monitoringState = .upToDate(source: self.trustedConfigSource)
                    case .updateRequired:
                        self.monitoringState = .updateRequired(source: self.trustedConfigSource)
                    }
                case let .failure(error):
                    let message = error.localizedDescription
                    self.lastErrorMessage = message
                    self.monitoringState = .failed(source: self.trustedConfigSource, message: message)
                }
            }
        }
    }
}
