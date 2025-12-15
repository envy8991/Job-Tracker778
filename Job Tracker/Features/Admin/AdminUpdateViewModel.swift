import Foundation

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

    private var lastStableVersion: String?

    init(bundle: Bundle = .main) {
        if let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            currentVersion = version
        } else {
            currentVersion = "Unknown"
        }
        lastStableVersion = currentVersion
    }

    var hasAvailableUpdate: Bool { availableVersion != nil }
    var hasDownloadedUpdate: Bool { downloadedVersion != nil }
    var isBusy: Bool { actionState != .idle }
    var canApplyUpdate: Bool { verificationStatus.isVerified && hasDownloadedUpdate && maintenanceModeEnabled }

    func checkForUpdates() {
        guard startAction(.checking) else { return }
        errorReason = nil
        progress = ProgressState(title: "Checking for updates", message: "Reaching update server…", fractionComplete: nil)
        log("Started checking for updates")

        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            let sampleVersion = "2.5.0"
            let newChangelog = [
                "Security hardening for admin workflows",
                "Performance improvements for sync service",
                "Improved logging around update application"
            ]
            await MainActor.run {
                availableVersion = sampleVersion
                changelog = newChangelog
                lastCheckDate = Date()
                progress = nil
                finishAction()
                log("Update v\(sampleVersion) is available")
            }
        }
    }

    func downloadUpdate() {
        guard hasAvailableUpdate else {
            errorReason = "No update available to download."
            log("Download skipped: no available version")
            return
        }
        guard startAction(.downloading) else { return }
        errorReason = nil
        verificationStatus = .notVerified
        progress = ProgressState(title: "Downloading", message: "Fetching package…", fractionComplete: 0)
        log("Downloading update v\(availableVersion ?? "?")")

        Task {
            for step in 1...10 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                await MainActor.run {
                    progress = ProgressState(
                        title: "Downloading",
                        message: "Fetching package…",
                        fractionComplete: Double(step) / 10
                    )
                }
            }
            await MainActor.run {
                downloadedVersion = availableVersion
                progress = nil
                finishAction()
                log("Download completed for v\(availableVersion ?? "?")")
            }
        }
    }

    func verifyDownload() {
        guard hasDownloadedUpdate else {
            errorReason = "Download an update before verifying."
            log("Verification blocked: no downloaded package")
            return
        }
        guard startAction(.verifying) else { return }
        errorReason = nil
        verificationStatus = .verifying
        progress = ProgressState(title: "Verifying", message: "Checking signatures…", fractionComplete: 0)
        log("Started verification for v\(downloadedVersion ?? "?")")

        Task {
            for step in 1...5 {
                try? await Task.sleep(nanoseconds: 200_000_000)
                await MainActor.run {
                    progress = ProgressState(
                        title: "Verifying",
                        message: "Checking signatures…",
                        fractionComplete: Double(step) / 5
                    )
                }
            }
            await MainActor.run {
                verificationStatus = .verified
                progress = nil
                finishAction()
                log("Package verified for v\(downloadedVersion ?? "?")")
            }
        }
    }

    func applyUpdate() {
        guard canApplyUpdate else {
            errorReason = "Enable maintenance mode and verify the package before applying."
            log("Apply blocked: guardrails not satisfied")
            return
        }
        guard startAction(.applying) else { return }
        errorReason = nil
        progress = ProgressState(title: "Applying update", message: "Switching traffic to maintenance mode…", fractionComplete: nil)
        log("Applying update v\(downloadedVersion ?? "?")")

        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                lastStableVersion = currentVersion
                currentVersion = downloadedVersion ?? currentVersion
                availableVersion = nil
                downloadedVersion = nil
                verificationStatus = .notVerified
                progress = nil
                finishAction()
                log("Update applied; now running v\(currentVersion)")
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
        progress = ProgressState(title: "Rolling back", message: "Restoring stable build…", fractionComplete: nil)
        log("Rolling back to v\(stable)")

        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                currentVersion = stable
                availableVersion = nil
                downloadedVersion = nil
                verificationStatus = .notVerified
                progress = nil
                finishAction()
                log("Rollback complete; running v\(stable)")
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

    private func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        logs.insert("[\(timestamp)] \(message)", at: 0)
    }
}
