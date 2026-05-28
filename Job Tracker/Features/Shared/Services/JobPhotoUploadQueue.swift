import Foundation
import Combine
import FirebaseFirestore
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

    private let fileManager: FileManager
    private let queueDirectory: URL
    private let manifestURL: URL
    private let db = Firestore.firestore()

    private var items: [PendingJobPhotoUpload] = []
    private var activeUploadID: String?
    private var retryTask: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
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
        pendingCount = items.count
        publishSyncState()
        processQueue()
    }

    deinit {
        retryTask?.cancel()
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
                        lastErrorDescription: nil
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
        pendingCount = items.count
        saveManifest()
        publishSyncState()
        scheduleRetry(after: 1.0)
    }

    func retryPendingUploads() {
        retryTask?.cancel()
        retryTask = nil
        processQueue()
    }

    func publishCurrentSyncState() {
        publishSyncState()
    }

    private func processQueue() {
        guard activeUploadID == nil else { return }
        guard let next = items.first else {
            resetCycleIfFinished()
            return
        }

        ensureBackgroundTaskIfNeeded()
        activeUploadID = next.id
        inFlightCount = 1
        publishSyncState()

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
                    self.patchJob(next, photoURL: urlString)
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

        if isFirestoreNotFound(error) {
            finish(item, removingLocalFile: true)
            return
        }

        activeUploadID = nil
        inFlightCount = 0

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].attempts += 1
            items[index].lastErrorDescription = error.localizedDescription
        }

        pendingCount = items.count
        saveManifest()
        publishSyncState()
        ensureBackgroundTaskIfNeeded()
        scheduleRetry(after: retryDelay(forAttempts: (items.first { $0.id == item.id }?.attempts ?? item.attempts + 1)))
    }

    private func isFirestoreNotFound(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == FirestoreErrorDomain && nsError.code == FirestoreErrorCode.notFound.rawValue
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
        pendingCount = items.count
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
        guard activeUploadID == nil, items.isEmpty else { return }
        if cycleTotalCount > 0, cycleDoneCount >= cycleTotalCount {
            publishSyncState()
        }
        cycleTotalCount = 0
        cycleDoneCount = 0
        completedCount = 0
        pendingCount = 0
        endBackgroundTaskIfIdle()
    }

    private func ensureBackgroundTaskIfNeeded() {
        guard backgroundTaskID == .invalid, !items.isEmpty else { return }

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
        pendingCount = items.count
        saveManifest()
        publishSyncState()
        endBackgroundTaskIfNeeded()
    }

    private func endBackgroundTaskIfIdle() {
        guard activeUploadID == nil, items.isEmpty else { return }
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

    private func publishSyncState() {
        let total = max(cycleTotalCount, items.count + cycleDoneCount)
        let done = min(cycleDoneCount, total)
        NotificationCenter.default.post(
            name: .jobPhotoUploadsSyncStateDidChange,
            object: nil,
            userInfo: [
                "total": total,
                "done": done,
                "uploaded": done,
                "inFlight": inFlightCount,
                "pending": items.count
            ]
        )
    }
}

extension Notification.Name {
    static let jobPhotoUploadsSyncStateDidChange = Notification.Name("jobPhotoUploadsSyncStateDidChange")
}
