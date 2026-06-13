import Combine
import Foundation
import UIKit

extension Notification.Name {
    static let metaSmartGlassesSettingsDidChange = Notification.Name("metaSmartGlassesSettingsDidChange")
}

enum MetaSmartGlassesConnectionState: String, Equatable {
    case disabled
    case readyForSDK
    case connected
    case unavailable

    var title: String {
        switch self {
        case .disabled: return "Off"
        case .readyForSDK: return "Ready"
        case .connected: return "Connected"
        case .unavailable: return "SDK Needed"
        }
    }

    var detail: String {
        switch self {
        case .disabled:
            return "Enable the assistant before pairing glasses."
        case .readyForSDK:
            return "Job Tracker is ready for the Meta SDK package and can already route field captures into job photos."
        case .connected:
            return "Meta glasses are connected and available for capture."
        case .unavailable:
            return "Add Meta's Wearables Device Access Toolkit package to enable direct glasses capture."
        }
    }
}

enum MetaSmartGlassesSettings {
    static let enabledKey = "metaSmartGlassesAssistantEnabled"
    static let requireReviewKey = "metaSmartGlassesRequireReviewBeforeUpload"
    static let useNearestJobKey = "metaSmartGlassesUseNearestJob"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var requiresReviewBeforeUpload: Bool { UserDefaults.standard.object(forKey: requireReviewKey) as? Bool ?? true }
    static var usesNearestJob: Bool { UserDefaults.standard.object(forKey: useNearestJobKey) as? Bool ?? true }

    static func publishChange() {
        NotificationCenter.default.post(name: .metaSmartGlassesSettingsDidChange, object: nil)
    }
}

protocol MetaSmartGlassesCapturing {
    var isSDKAvailable: Bool { get }
    func connect() async throws
    func disconnect() async
    func capturePhoto() async throws -> UIImage
}

struct MetaSmartGlassesSDKAdapter: MetaSmartGlassesCapturing {
    var isSDKAvailable: Bool { false }

    func connect() async throws {
        throw MetaSmartGlassesServiceError.sdkUnavailable
    }

    func disconnect() async {}

    func capturePhoto() async throws -> UIImage {
        throw MetaSmartGlassesServiceError.sdkUnavailable
    }
}

enum MetaSmartGlassesServiceError: LocalizedError, Equatable {
    case disabled
    case sdkUnavailable
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "Meta Smart Glasses capture is turned off in Settings."
        case .sdkUnavailable:
            return "Meta's Wearables Device Access Toolkit SDK has not been added to this build yet."
        case .captureFailed:
            return "The glasses did not return a usable photo."
        }
    }
}

@MainActor
final class MetaSmartGlassesService: ObservableObject {
    static let shared = MetaSmartGlassesService()

    @Published private(set) var connectionState: MetaSmartGlassesConnectionState
    @Published private(set) var lastErrorMessage: String?

    private let adapter: MetaSmartGlassesCapturing
    private var cancellable: AnyCancellable?

    init(adapter: MetaSmartGlassesCapturing = MetaSmartGlassesSDKAdapter()) {
        self.adapter = adapter
        self.connectionState = Self.state(isEnabled: MetaSmartGlassesSettings.isEnabled, sdkAvailable: adapter.isSDKAvailable)
        cancellable = NotificationCenter.default.publisher(for: .metaSmartGlassesSettingsDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshState() }
            }
    }

    func refreshState() {
        connectionState = Self.state(isEnabled: MetaSmartGlassesSettings.isEnabled, sdkAvailable: adapter.isSDKAvailable)
    }

    func connect() async {
        guard MetaSmartGlassesSettings.isEnabled else {
            lastErrorMessage = MetaSmartGlassesServiceError.disabled.localizedDescription
            refreshState()
            return
        }

        do {
            try await adapter.connect()
            connectionState = .connected
            lastErrorMessage = nil
        } catch {
            connectionState = adapter.isSDKAvailable ? .readyForSDK : .unavailable
            lastErrorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        await adapter.disconnect()
        lastErrorMessage = nil
        refreshState()
    }

    func capturePhoto() async throws -> UIImage {
        guard MetaSmartGlassesSettings.isEnabled else { throw MetaSmartGlassesServiceError.disabled }
        guard adapter.isSDKAvailable else { throw MetaSmartGlassesServiceError.sdkUnavailable }
        return try await adapter.capturePhoto()
    }

    private static func state(isEnabled: Bool, sdkAvailable: Bool) -> MetaSmartGlassesConnectionState {
        guard isEnabled else { return .disabled }
        return sdkAvailable ? .readyForSDK : .unavailable
    }
}
