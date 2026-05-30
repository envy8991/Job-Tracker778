import Foundation

#if DEBUG
protocol AdminUpdateService {
    func checkForUpdates(currentVersion: String) async throws -> AdminUpdateViewModel.UpdateManifest?
    func downloadUpdate(version: String, progress: @escaping @MainActor (Double) -> Void) async throws -> AdminUpdateViewModel.DownloadedPackage
    func verifyDownload(_ package: AdminUpdateViewModel.DownloadedPackage, progress: @escaping @MainActor (Double) -> Void) async throws
    func applyUpdate(_ package: AdminUpdateViewModel.DownloadedPackage) async throws
    func rollback(to version: String) async throws
}

struct DevelopmentAdminUpdateService: AdminUpdateService {
    func checkForUpdates(currentVersion: String) async throws -> AdminUpdateViewModel.UpdateManifest? {
        try await Task.sleep(nanoseconds: 300_000_000)
        return AdminUpdateViewModel.UpdateManifest(
            version: "2.5.0-dev-demo",
            changelog: [
                "Debug-only update workflow demo",
                "Production distribution remains App Store/TestFlight managed",
                "Forced-update gates are controlled by trusted Firestore remote config"
            ]
        )
    }

    func downloadUpdate(version: String, progress: @escaping @MainActor (Double) -> Void) async throws -> AdminUpdateViewModel.DownloadedPackage {
        for step in 1...10 {
            try await Task.sleep(nanoseconds: 75_000_000)
            await progress(Double(step) / 10)
        }
        return AdminUpdateViewModel.DownloadedPackage(version: version, checksum: "debug-demo-")
    }

    func verifyDownload(_ package: AdminUpdateViewModel.DownloadedPackage, progress: @escaping @MainActor (Double) -> Void) async throws {
        for step in 1...5 {
            try await Task.sleep(nanoseconds: 75_000_000)
            await progress(Double(step) / 5)
        }
    }

    func applyUpdate(_ package: AdminUpdateViewModel.DownloadedPackage) async throws {
        try await Task.sleep(nanoseconds: 250_000_000)
    }

    func rollback(to version: String) async throws {
        try await Task.sleep(nanoseconds: 250_000_000)
    }
}

@MainActor
final class AdminUpdateViewModel: ObservableObject {
    enum ActionState: String {
        case idle
        case checking
        case downloading
        case verifying
        case applying
        case rollingBack
    }

    enum VerificationStatus: Equatable {
        case notVerified
        case verifying
        case verified
        case failed(String)

        var message: String {
            switch self {
            case .notVerified:
                return "Not verified"
            case .verifying:
                return "Verifying…"
            case .verified:
                return "Package verified"
            case .failed(let reason):
                return "Verification failed: \(reason)"
            }
        }

        var isVerified: Bool {
            if case .verified = self { return true }
            return false
        }
    }

    struct ProgressState: Equatable {
        let title: String
        let message: String
        let fractionComplete: Double?
    }

    struct UpdateManifest: Equatable {
        let version: String
        let changelog: [String]
    }

    struct DownloadedPackage: Equatable {
        let version: String
        let checksum: String
    }

    @Published var currentVersion: String
    @Published var availableVersion: String?
    @Published var changelog: [String] = []
    @Published var verificationStatus: VerificationStatus = .notVerified
    @Published var maintenanceModeEnabled = false
    @Published var actionState: ActionState = .idle
    @Published var progress: ProgressState?
    @Published var errorReason: String?
    @Published var downloadedVersion: String?
    @Published var logs: [String] = []
    @Published var lastCheckDate: Date?

    private let service: AdminUpdateService
    private var downloadedPackage: DownloadedPackage?
    private var lastStableVersion: String?

    init(bundle: Bundle = .main, service: AdminUpdateService = DevelopmentAdminUpdateService()) {
        if let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            currentVersion = version
        } else {
            currentVersion = "Unknown"
        }
        self.service = service
        lastStableVersion = currentVersion
        log("Debug-only admin update demo initialized. Production updates use App Store/TestFlight plus forced-update remote config.")
    }

    var hasAvailableUpdate: Bool { availableVersion != nil }
    var hasDownloadedUpdate: Bool { downloadedPackage != nil }
    var isBusy: Bool { actionState != .idle }
    var canApplyUpdate: Bool { verificationStatus.isVerified && hasDownloadedUpdate && maintenanceModeEnabled }

    func checkForUpdates() {
        guard startAction(.checking) else { return }
        errorReason = nil
        progress = ProgressState(title: "Checking for debug demo update", message: "Reading development update service…", fractionComplete: nil)
        log("Started debug update check")

        Task { @MainActor [service, currentVersion] in
            do {
                let manifest = try await service.checkForUpdates(currentVersion: currentVersion)
                if let manifest {
                    availableVersion = manifest.version
                    changelog = manifest.changelog
                    log("Debug demo update v\(manifest.version) is available")
                } else {
                    availableVersion = nil
                    changelog = []
                    log("No debug demo update available")
                }
                downloadedPackage = nil
                downloadedVersion = nil
                verificationStatus = .notVerified
                lastCheckDate = Date()
                finishAction()
            } catch {
                failCurrentAction("Update check failed: \(error.localizedDescription)")
            }
        }
    }

    func downloadUpdate() {
        guard let availableVersion else {
            errorReason = "No update available to download."
            log("Download skipped: no available version")
            return
        }
        guard startAction(.downloading) else { return }
        errorReason = nil
        verificationStatus = .notVerified
        downloadedPackage = nil
        downloadedVersion = nil
        progress = ProgressState(title: "Downloading debug package", message: "Fetching development package…", fractionComplete: 0)
        log("Downloading debug demo update v\(availableVersion)")

        Task { @MainActor [service] in
            do {
                let package = try await service.downloadUpdate(version: availableVersion) { fraction in
                    self.progress = ProgressState(
                        title: "Downloading debug package",
                        message: "Fetching development package…",
                        fractionComplete: fraction
                    )
                }
                downloadedPackage = package
                downloadedVersion = package.version
                finishAction()
                log("Download completed for debug demo v\(package.version)")
            } catch {
                failCurrentAction("Download failed: \(error.localizedDescription)")
            }
        }
    }

    func verifyDownload() {
        guard let downloadedPackage else {
            errorReason = "Download an update before verifying."
            log("Verification blocked: no downloaded package")
            return
        }
        guard startAction(.verifying) else { return }
        errorReason = nil
        verificationStatus = .verifying
        progress = ProgressState(title: "Verifying debug package", message: "Checking development package signature…", fractionComplete: 0)
        log("Started verification for debug demo v\(downloadedPackage.version)")

        Task { @MainActor [service] in
            do {
                try await service.verifyDownload(downloadedPackage) { fraction in
                    self.progress = ProgressState(
                        title: "Verifying debug package",
                        message: "Checking development package signature…",
                        fractionComplete: fraction
                    )
                }
                verificationStatus = .verified
                finishAction()
                log("Debug demo package verified for v\(downloadedPackage.version)")
            } catch {
                verificationStatus = .failed(error.localizedDescription)
                failCurrentAction("Verification failed: \(error.localizedDescription)")
            }
        }
    }

    func applyUpdate() {
        guard canApplyUpdate, let downloadedPackage else {
            errorReason = "Enable maintenance mode and verify the package before applying."
            log("Apply blocked: guardrails not satisfied")
            return
        }
        guard startAction(.applying) else { return }
        errorReason = nil
        progress = ProgressState(title: "Applying debug update", message: "Simulating development update activation…", fractionComplete: nil)
        log("Applying debug demo update v\(downloadedPackage.version)")

        Task { @MainActor [service] in
            do {
                try await service.applyUpdate(downloadedPackage)
                lastStableVersion = currentVersion
                currentVersion = downloadedPackage.version
                availableVersion = nil
                changelog = []
                self.downloadedPackage = nil
                downloadedVersion = nil
                verificationStatus = .notVerified
                finishAction()
                log("Debug demo update applied; now showing v\(currentVersion)")
            } catch {
                failCurrentAction("Apply failed: \(error.localizedDescription)")
            }
        }
    }

    func rollbackUpdate() {
        guard let stable = lastStableVersion, stable != currentVersion else {
            errorReason = "No earlier version available to rollback to."
            log("Rollback blocked: no stored stable build")
            return
        }
        guard startAction(.rollingBack) else { return }
        errorReason = nil
        progress = ProgressState(title: "Rolling back debug update", message: "Restoring previous development state…", fractionComplete: nil)
        log("Rolling back debug demo to v\(stable)")

        Task { @MainActor [service] in
            do {
                try await service.rollback(to: stable)
                currentVersion = stable
                availableVersion = nil
                changelog = []
                downloadedPackage = nil
                downloadedVersion = nil
                verificationStatus = .notVerified
                finishAction()
                log("Rollback complete; showing v\(stable)")
            } catch {
                failCurrentAction("Rollback failed: \(error.localizedDescription)")
            }
        }
    }

    func refreshVerificationStatus() {
        if hasDownloadedUpdate && verificationStatus == .notVerified {
            verificationStatus = .failed("Package has not been verified.")
        }
    }

    func resetError() {
        errorReason = nil
    }

    private func startAction(_ action: ActionState) -> Bool {
        guard actionState == .idle else { return false }
        actionState = action
        return true
    }

    private func finishAction() {
        actionState = .idle
        progress = nil
    }

    private func failCurrentAction(_ message: String) {
        errorReason = message
        finishAction()
        log(message)
    }

    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        logs.insert("[\(timestamp)] \(message)", at: 0)
    }
}
#endif
