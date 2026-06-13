import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import Network
import UIKit

/// Dedicated photo slots on a job document.
enum JobPhotoSlot: String, Codable, CaseIterable {
    case house
    case nid
    case can

    var firestoreField: String {
        switch self {
        case .house:
            return "housePhotoURL"
        case .nid:
            return "nidPhotoURL"
        case .can:
            return "canPhotoURL"
        }
    }
}

private struct PendingJobPhotoUpload: Identifiable, Codable, Equatable {
    let id: String
    let jobID: String
    let slot: JobPhotoSlot
    let fileName: String
    let createdAt: Date
    var attempts: Int
    var lastErrorDescription: String?
    var uploadedURL: String?
    var isFailed: Bool

    init(
        id: String,
        jobID: String,
        slot: JobPhotoSlot,
        fileName: String,
        createdAt: Date,
        attempts: Int,
        lastErrorDescription: String?,
        uploadedURL: String?,
        isFailed: Bool
    ) {
        self.id = id
        self.jobID = jobID
        self.slot = slot
        self.fileName = fileName
        self.createdAt = createdAt
        self.attempts = attempts
        self.lastErrorDescription = lastErrorDescription
        self.uploadedURL = uploadedURL
        self.isFailed = isFailed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        jobID = try container.decode(String.self, forKey: .jobID)
        slot = try container.decode(JobPhotoSlot.self, forKey: .slot)
        fileName = try container.decode(String.self, forKey: .fileName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        attempts = try container.decodeIfPresent(Int.self, forKey: .attempts) ?? 0
        lastErrorDescription = try container.decodeIfPresent(String.self, forKey: .lastErrorDescription)
        uploadedURL = try container.decodeIfPresent(String.self, forKey: .uploadedURL)
        isFailed = try container.decodeIfPresent(Bool.self, forKey: .isFailed) ?? false
    }
}

struct JobPhotoUploadStatus: Identifiable, Equatable {
    enum State: Equatable {
        case pending
        case uploading
        case waitingForNetwork
        case retrying
        case failed
    }

    let id: String
    let jobID: String
    let slot: JobPhotoSlot
    let createdAt: Date
    let attempts: Int
    let lastErrorDescription: String?
    let state: State

    var title: String {
        switch slot {
        case .house: return "House photo"
        case .nid: return "NID photo"
        case .can: return "Can photo"
        }
    }

    var subtitle: String {
        switch state {
        case .pending:
            return "Waiting to upload"
        case .uploading:
            return "Uploading now"
        case .waitingForNetwork:
            return "Waiting for connection"
        case .retrying:
            return "Will retry automatically"
        case .failed:
            return lastErrorDescription ?? "Upload failed"
        }
    }
}

/// Persists selected job photos locally, uploads them outside of the detail save flow,
/// and patches the job document with the Firebase Storage URL once each upload finishes.
///
/// Firestore queues document writes offline, but Firebase Storage does not provide the
/// same durable offline write queue. This service gives photo uploads the same user
/// experience as job saves by keeping local image files, requesting iOS background
/// execution time for active uploads, and retrying unfinished uploads when the app runs again.
@MainActor
final class JobPhotoUploadQueue: ObservableObject {
    static let shared = JobPhotoUploadQueue()

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var inFlightCount: Int = 0
    @Published private(set) var completedCount: Int = 0
    @Published private(set) var failedCount: Int = 0
    @Published private(set) var waitingForNetwork: Bool = false
    @Published private(set) var uploadStatuses: [JobPhotoUploadStatus] = []

    private let fileManager: FileManager
    private let queueDirectory: URL
    private let manifestURL: URL
    private let db = Firestore.firestore()

    private var items: [PendingJobPhotoUpload] = []
    private var activeUploadID: String?
    private var retryTask: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "com.jobtracker.photoUploadQueue.network")
    private var isNetworkAvailable = true
    private let maximumAttempts = 5
    private var cycleTotalCount: Int = 0
    private var cycleDoneCount: Int = 0

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.queueDirectory = applicationSupport.appendingPathComponent("PendingJobPhotoUploads", isDirectory: true)
        self.manifestURL = queueDirectory.appendingPathComponent("manifest.json")

        try? fileManager.createDirectory(at: queueDirectory, withIntermediateDirectories: true)
        loadManifest()
        cycleTotalCount = items.count
        refreshPublishedCounts()
        startNetworkMonitoring()
        publishSyncState()
        processQueue()
    }

    deinit {
        retryTask?.cancel()
        pathMonitor.cancel()

        let taskID = backgroundTaskID
        if taskID != .invalid {
            Task { @MainActor in
                UIApplication.shared.endBackgroundTask(taskID)
            }
        }
    }

    func enqueue(_ photos: [(slot: JobPhotoSlot, image: UIImage)], for jobID: String) {
        guard !photos.isEmpty else { return }

        var addedItems: [PendingJobPhotoUpload] = []
        for photo in photos {
            guard let data = photo.image.jpegData(compressionQuality: 0.82) else { continue }
            let id = UUID().uuidString
            let fileName = "\(id).jpg"
            let fileURL = queueDirectory.appendingPathComponent(fileName)

            do {
                try data.write(to: fileURL, options: [.atomic])
                addedItems.append(
                    PendingJobPhotoUpload(
                        id: id,
                        jobID: jobID,
                        slot: photo.slot,
                        fileName: fileName,
                        createdAt: Date(),
                        attempts: 0,
                        lastErrorDescription: nil,
                        uploadedURL: nil,
                        isFailed: false
                    )
                )
            } catch {
                #if DEBUG
                print("[JobPhotoUploadQueue] Failed to persist pending photo: \(error.localizedDescription)")
                #endif
            }
        }

        guard !addedItems.isEmpty else { return }
        items.append(contentsOf: addedItems)
        ensureBackgroundTaskIfNeeded()
        cycleTotalCount += addedItems.count
        refreshPublishedCounts()
        saveManifest()
        publishSyncState()
        scheduleRetry(after: 1.0)
    }

    func retryPendingUploads() {
        retryTask?.cancel()
        retryTask = nil
        refreshPublishedCounts()
        publishSyncState()
        processQueue()
    }

    func retryFailedUploads() {
        for index in items.indices where items[index].isFailed {
            items[index].attempts = 0
            items[index].isFailed = false
            items[index].lastErrorDescription = nil
        }
        refreshPublishedCounts()
        saveManifest()
        publishSyncState()
        processQueue()
    }

    func retryUpload(id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].attempts = 0
        items[index].isFailed = false
        items[index].lastErrorDescription = nil
        refreshPublishedCounts()
        saveManifest()
        publishSyncState()
        processQueue()
    }

    func discardUpload(id: String) {
        guard activeUploadID != id, let index = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: index)
        try? fileManager.removeItem(at: queueDirectory.appendingPathComponent(removed.fileName))
        if items.isEmpty {
            cycleTotalCount = 0
            cycleDoneCount = 0
            completedCount = 0
        }
        refreshPublishedCounts()
        saveManifest()
        publishSyncState()
        endBackgroundTaskIfIdle()
    }

    func publishCurrentSyncState() {
        publishSyncState()
    }

    private func processQueue() {
        guard activeUploadID == nil else { return }
        guard isNetworkAvailable else {
            waitingForNetwork = items.contains { !$0.isFailed }
            inFlightCount = 0
            refreshPublishedCounts()
            publishSyncState()
            return
        }
        guard let next = items.first(where: { !$0.isFailed }) else {
            resetCycleIfFinished()
            return
        }

        ensureBackgroundTaskIfNeeded()
        activeUploadID = next.id
        inFlightCount = 1
        publishSyncState()

        if let uploadedURL = next.uploadedURL {
            patchJob(next, photoURL: uploadedURL)
            return
        }

        let fileURL = queueDirectory.appendingPathComponent(next.fileName)
        guard let data = try? Data(contentsOf: fileURL) else {
            finish(next, removingLocalFile: true)
            return
        }

        FirebaseService.shared.uploadImageData(data, for: next.jobID) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let urlString):
                    if let index = self.items.firstIndex(where: { $0.id == next.id }) {
                        self.items[index].uploadedURL = urlString
                        self.saveManifest()
                    }
                    var uploadedItem = next
                    uploadedItem.uploadedURL = urlString
                    self.patchJob(uploadedItem, photoURL: urlString)
                case .failure(let error):
                    self.handleFailure(for: next, error: error)
                }
            }
        }
    }

    private func patchJob(_ item: PendingJobPhotoUpload, photoURL: String) {
        db.collection("jobs").document(item.jobID).updateData([item.slot.firestoreField: photoURL]) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.handleFailure(for: item, error: error)
                } else {
                    self.finish(item, removingLocalFile: true)
                }
            }
        }
    }

    private func handleFailure(for item: PendingJobPhotoUpload, error: Error) {
        guard activeUploadID == item.id else { return }

        activeUploadID = nil
        inFlightCount = 0

        var attempts = item.attempts + 1
        var shouldFailPermanently = isNonRetryable(error)
        if isFirestoreNotFound(error) {
            // A photo can finish uploading before an offline-created job document is visible on the
            // server. Keep the local file/manifest and retry the Firestore patch instead of deleting it.
            shouldFailPermanently = attempts >= maximumAttempts
        }

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].attempts += 1
            items[index].lastErrorDescription = error.localizedDescription
            items[index].isFailed = shouldFailPermanently || items[index].attempts >= maximumAttempts
            attempts = items[index].attempts
        }

        refreshPublishedCounts()
        saveManifest()
        publishSyncState()

        if items.contains(where: { !$0.isFailed }) {
            ensureBackgroundTaskIfNeeded()
            scheduleRetry(after: retryDelay(forAttempts: attempts))
        } else {
            endBackgroundTaskIfIdle()
        }
    }

    private func isFirestoreNotFound(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == FirestoreErrorDomain && nsError.code == FirestoreErrorCode.notFound.rawValue
    }

    private func isNonRetryable(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain {
            return nsError.code == FirestoreErrorCode.permissionDenied.rawValue
                || nsError.code == FirestoreErrorCode.unauthenticated.rawValue
        }
        if nsError.domain == StorageErrorDomain,
           let code = StorageErrorCode(rawValue: nsError.code) {
            switch code {
            case .unauthenticated, .unauthorized, .invalidArgument, .objectNotFound, .quotaExceeded:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func finish(_ item: PendingJobPhotoUpload, removingLocalFile: Bool) {
        guard activeUploadID == nil || activeUploadID == item.id else { return }

        if activeUploadID == item.id {
            activeUploadID = nil
            inFlightCount = 0
        }

        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            endBackgroundTaskIfIdle()
            return
        }

        let removed = items.remove(at: index)
        if removingLocalFile {
            try? fileManager.removeItem(at: queueDirectory.appendingPathComponent(removed.fileName))
        }

        cycleDoneCount += 1
        completedCount = cycleDoneCount
        refreshPublishedCounts()
        saveManifest()
        publishSyncState()
        processQueue()
    }

    private func scheduleRetry(after delay: TimeInterval) {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            let nanoseconds = UInt64(max(delay, 1) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            await MainActor.run {
                self?.retryTask = nil
                self?.processQueue()
            }
        }
    }

    private func retryDelay(forAttempts attempts: Int) -> TimeInterval {
        let cappedAttempts = min(max(attempts, 1), 5)
        return min(pow(2.0, Double(cappedAttempts)) * 3.0, 60.0)
    }

    private func resetCycleIfFinished() {
        guard activeUploadID == nil, !items.contains(where: { !$0.isFailed }) else { return }
        if cycleTotalCount > 0, cycleDoneCount >= cycleTotalCount {
            publishSyncState()
        }
        cycleTotalCount = 0
        cycleDoneCount = 0
        completedCount = 0
        refreshPublishedCounts()
        endBackgroundTaskIfIdle()
    }

    private func ensureBackgroundTaskIfNeeded() {
        guard backgroundTaskID == .invalid, items.contains(where: { !$0.isFailed }) else { return }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "JobPhotoUploadQueue") { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleBackgroundTaskExpired()
            }
        }
    }

    private func handleBackgroundTaskExpired() {
        retryTask?.cancel()
        retryTask = nil
        activeUploadID = nil
        inFlightCount = 0
        refreshPublishedCounts()
        saveManifest()
        publishSyncState()
        endBackgroundTaskIfNeeded()
    }

    private func endBackgroundTaskIfIdle() {
        guard activeUploadID == nil, !items.contains(where: { !$0.isFailed }) else { return }
        endBackgroundTaskIfNeeded()
    }

    private func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        let taskID = backgroundTaskID
        backgroundTaskID = .invalid
        UIApplication.shared.endBackgroundTask(taskID)
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL) else { return }
        do {
            let decoded = try JSONDecoder().decode([PendingJobPhotoUpload].self, from: data)
            items = decoded.filter { fileManager.fileExists(atPath: queueDirectory.appendingPathComponent($0.fileName).path) }
        } catch {
            #if DEBUG
            print("[JobPhotoUploadQueue] Failed to load manifest: \(error.localizedDescription)")
            #endif
            items = []
        }
    }

    private func saveManifest() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: manifestURL, options: [.atomic])
        } catch {
            #if DEBUG
            print("[JobPhotoUploadQueue] Failed to save manifest: \(error.localizedDescription)")
            #endif
        }
    }

    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let wasAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied
                self.waitingForNetwork = !self.isNetworkAvailable && self.items.contains { !$0.isFailed }
                self.refreshPublishedCounts()
                self.publishSyncState()
                if !wasAvailable && self.isNetworkAvailable {
                    self.retryPendingUploads()
                }
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    private func refreshPublishedCounts() {
        failedCount = items.filter(\.isFailed).count
        pendingCount = items.filter { !$0.isFailed }.count
        waitingForNetwork = !isNetworkAvailable && pendingCount > 0
        uploadStatuses = items.map { item in
            let state: JobPhotoUploadStatus.State
            if item.isFailed {
                state = .failed
            } else if activeUploadID == item.id {
                state = .uploading
            } else if waitingForNetwork {
                state = .waitingForNetwork
            } else if item.attempts > 0 {
                state = .retrying
            } else {
                state = .pending
            }
            return JobPhotoUploadStatus(
                id: item.id,
                jobID: item.jobID,
                slot: item.slot,
                createdAt: item.createdAt,
                attempts: item.attempts,
                lastErrorDescription: item.lastErrorDescription,
                state: state
            )
        }
    }

    private func publishSyncState() {
        refreshPublishedCounts()
        let activeCount = items.filter { !$0.isFailed }.count
        let total = max(cycleTotalCount, activeCount + failedCount + cycleDoneCount)
        let done = min(cycleDoneCount, total)
        NotificationCenter.default.post(
            name: .jobPhotoUploadsSyncStateDidChange,
            object: nil,
            userInfo: [
                "total": total,
                "done": done,
                "uploaded": done,
                "inFlight": inFlightCount,
                "pending": pendingCount,
                "failed": failedCount,
                "waitingForNetwork": waitingForNetwork
            ]
        )
    }
}

extension Notification.Name {
    static let jobPhotoUploadsSyncStateDidChange = Notification.Name("jobPhotoUploadsSyncStateDidChange")
}
