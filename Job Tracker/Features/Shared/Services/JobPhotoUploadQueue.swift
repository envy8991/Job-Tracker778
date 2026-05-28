import Foundation
import Combine
import FirebaseAuth
import FirebaseCore
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
    let bodyFileName: String?
    let storagePath: String
    let downloadToken: String
    let createdAt: Date
    var attempts: Int
    var lastErrorDescription: String?
    var uploadedURL: String?

    init(
        id: String,
        jobID: String,
        slot: JobPhotoSlot,
        fileName: String,
        bodyFileName: String? = nil,
        storagePath: String? = nil,
        downloadToken: String = UUID().uuidString,
        createdAt: Date,
        attempts: Int,
        lastErrorDescription: String?,
        uploadedURL: String? = nil
    ) {
        self.id = id
        self.jobID = jobID
        self.slot = slot
        self.fileName = fileName
        self.bodyFileName = bodyFileName
        self.storagePath = storagePath ?? "jobPhotos/\(jobID)/\(fileName)"
        self.downloadToken = downloadToken
        self.createdAt = createdAt
        self.attempts = attempts
        self.lastErrorDescription = lastErrorDescription
        self.uploadedURL = uploadedURL
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case jobID
        case slot
        case fileName
        case bodyFileName
        case storagePath
        case downloadToken
        case createdAt
        case attempts
        case lastErrorDescription
        case uploadedURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let jobID = try container.decode(String.self, forKey: .jobID)
        let slot = try container.decode(JobPhotoSlot.self, forKey: .slot)
        let fileName = try container.decode(String.self, forKey: .fileName)
        let bodyFileName = try container.decodeIfPresent(String.self, forKey: .bodyFileName)
        let storagePath = try container.decodeIfPresent(String.self, forKey: .storagePath)
        let downloadToken = try container.decodeIfPresent(String.self, forKey: .downloadToken) ?? UUID().uuidString
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let attempts = try container.decode(Int.self, forKey: .attempts)
        let lastErrorDescription = try container.decodeIfPresent(String.self, forKey: .lastErrorDescription)
        let uploadedURL = try container.decodeIfPresent(String.self, forKey: .uploadedURL)
        self.init(
            id: id,
            jobID: jobID,
            slot: slot,
            fileName: fileName,
            bodyFileName: bodyFileName,
            storagePath: storagePath,
            downloadToken: downloadToken,
            createdAt: createdAt,
            attempts: attempts,
            lastErrorDescription: lastErrorDescription,
            uploadedURL: uploadedURL
        )
    }
}

/// Persists selected job photos locally and uploads them with a background URLSession.
///
/// A background URLSession lets iOS continue an already-started upload after the app is
/// suspended and relaunch the app to deliver completion events. Pending files and upload
/// metadata are persisted so incomplete uploads can also resume when the app is opened
/// again. iOS still does not guarantee background work after a user force-quits the app.
@MainActor
final class JobPhotoUploadQueue: NSObject, ObservableObject {
    static let shared = JobPhotoUploadQueue()

    static var backgroundSessionIdentifier: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.quinton.JobTracker"
        return "\(bundleID).jobPhotoUploads.background"
    }

    @Published private(set) var pendingCount: Int = 0
    @Published private(set) var inFlightCount: Int = 0
    @Published private(set) var completedCount: Int = 0

    private let fileManager: FileManager
    private let queueDirectory: URL
    private let manifestURL: URL
    private let db = Firestore.firestore()

    private var items: [PendingJobPhotoUpload] = []
    private var activeUploadIDs: Set<String> = []
    private var responseDataByTaskID: [Int: Data] = [:]
    private var retryTask: Task<Void, Never>?
    private var cycleTotalCount: Int = 0
    private var cycleDoneCount: Int = 0
    private var backgroundSessionCompletionHandler: (() -> Void)?
    private var didReceiveBackgroundSessionEvents = false
    private var patchInFlightCount: Int = 0
    private var uploadSetupBackgroundTask: UIBackgroundTaskIdentifier = .invalid

    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.backgroundSessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.waitsForConnectivity = true
        configuration.isDiscretionary = false
        configuration.allowsConstrainedNetworkAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.queueDirectory = applicationSupport.appendingPathComponent("PendingJobPhotoUploads", isDirectory: true)
        self.manifestURL = queueDirectory.appendingPathComponent("manifest.json")

        super.init()

        try? fileManager.createDirectory(at: queueDirectory, withIntermediateDirectories: true)
        loadManifest()
        cycleTotalCount = items.count
        pendingCount = items.count
        publishSyncState()
        reconcileBackgroundTasksThenProcess()
    }

    deinit {
        retryTask?.cancel()
        backgroundSession.invalidateAndCancel()
    }

    func enqueue(_ photos: [(slot: JobPhotoSlot, image: UIImage)], for jobID: String) {
        guard !photos.isEmpty else { return }

        var addedItems: [PendingJobPhotoUpload] = []
        for photo in photos {
            guard let data = photo.image.jpegData(compressionQuality: 0.82) else { continue }
            let id = UUID().uuidString
            let fileName = "\(id).jpg"
            let storagePath = "jobPhotos/\(jobID)/\(fileName)"
            let fileURL = queueDirectory.appendingPathComponent(fileName)

            do {
                try data.write(to: fileURL, options: [.atomic])
                addedItems.append(
                    PendingJobPhotoUpload(
                        id: id,
                        jobID: jobID,
                        slot: photo.slot,
                        fileName: fileName,
                        bodyFileName: nil,
                        storagePath: storagePath,
                        downloadToken: UUID().uuidString,
                        createdAt: Date(),
                        attempts: 0,
                        lastErrorDescription: nil,
                        uploadedURL: nil
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
        cycleTotalCount += addedItems.count
        pendingCount = items.count
        saveManifest()
        publishSyncState()
        retryPendingUploads()
    }

    func retryPendingUploads() {
        retryTask?.cancel()
        retryTask = nil
        reconcileBackgroundTasksThenProcess()
    }

    func publishCurrentSyncState() {
        publishSyncState()
    }

    func setBackgroundSessionCompletionHandler(_ completionHandler: @escaping () -> Void, for identifier: String) {
        guard identifier == Self.backgroundSessionIdentifier else {
            completionHandler()
            return
        }
        backgroundSessionCompletionHandler = completionHandler
        _ = backgroundSession
    }

    private func reconcileBackgroundTasksThenProcess() {
        backgroundSession.getAllTasks { [weak self] tasks in
            Task { @MainActor in
                guard let self else { return }
                self.activeUploadIDs = Set(tasks.compactMap { $0.taskDescription })
                self.inFlightCount = self.activeUploadIDs.count
                self.publishSyncState()
                self.processQueue()
            }
        }
    }

    private func processQueue() {
        guard activeUploadIDs.isEmpty else { return }
        guard let next = items.first else {
            resetCycleIfFinished()
            drainBackgroundSessionCompletionIfReady()
            return
        }

        if let uploadedURL = next.uploadedURL {
            patchJob(next, photoURL: uploadedURL)
            return
        }

        startBackgroundUpload(for: next)
    }

    private func startBackgroundUpload(for item: PendingJobPhotoUpload) {
        beginUploadSetupBackgroundTask()

        guard let currentUser = Auth.auth().currentUser else {
            endUploadSetupBackgroundTask()
            handleFailure(for: item, error: queueError("Not signed in"))
            return
        }

        currentUser.getIDToken { [weak self] token, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.endUploadSetupBackgroundTask()
                    self.handleFailure(for: item, error: error)
                    return
                }
                guard let token else {
                    self.endUploadSetupBackgroundTask()
                    self.handleFailure(for: item, error: self.queueError("Missing Firebase auth token"))
                    return
                }

                do {
                    let requestAndBody = try self.makeBackgroundUploadRequest(for: item, idToken: token)
                    var updatedItem = item
                    updatedItem = PendingJobPhotoUpload(
                        id: item.id,
                        jobID: item.jobID,
                        slot: item.slot,
                        fileName: item.fileName,
                        bodyFileName: requestAndBody.bodyURL.lastPathComponent,
                        storagePath: item.storagePath,
                        downloadToken: item.downloadToken,
                        createdAt: item.createdAt,
                        attempts: item.attempts,
                        lastErrorDescription: nil,
                        uploadedURL: item.uploadedURL
                    )
                    self.replaceItem(updatedItem)

                    let task = self.backgroundSession.uploadTask(with: requestAndBody.request, fromFile: requestAndBody.bodyURL)
                    task.taskDescription = item.id
                    self.activeUploadIDs.insert(item.id)
                    self.inFlightCount = self.activeUploadIDs.count
                    self.publishSyncState()
                    task.resume()
                    self.endUploadSetupBackgroundTask()
                } catch {
                    self.endUploadSetupBackgroundTask()
                    self.handleFailure(for: item, error: error)
                }
            }
        }
    }

    private func makeBackgroundUploadRequest(for item: PendingJobPhotoUpload, idToken: String) throws -> (request: URLRequest, bodyURL: URL) {
        guard let bucket = FirebaseApp.app()?.options.storageBucket, !bucket.isEmpty else {
            throw queueError("Missing Firebase Storage bucket")
        }
        guard var components = URLComponents(string: "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o") else {
            throw queueError("Invalid Firebase Storage upload URL")
        }
        components.queryItems = [
            URLQueryItem(name: "uploadType", value: "multipart"),
            URLQueryItem(name: "name", value: item.storagePath)
        ]
        guard let url = components.url else {
            throw queueError("Invalid Firebase Storage upload URL")
        }

        let imageURL = queueDirectory.appendingPathComponent(item.fileName)
        let imageData = try Data(contentsOf: imageURL)
        let boundary = "job-photo-boundary-\(UUID().uuidString)"
        let metadata: [String: Any] = [
            "name": item.storagePath,
            "contentType": "image/jpeg",
            "metadata": ["firebaseStorageDownloadTokens": item.downloadToken]
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)

        var body = Data()
        append("--\(boundary)\r\n", to: &body)
        append("Content-Type: application/json; charset=UTF-8\r\n\r\n", to: &body)
        body.append(metadataData)
        append("\r\n--\(boundary)\r\n", to: &body)
        append("Content-Type: image/jpeg\r\n\r\n", to: &body)
        body.append(imageData)
        append("\r\n--\(boundary)--\r\n", to: &body)

        let bodyFileName = item.bodyFileName ?? "\(item.id)-multipart-upload.body"
        let bodyURL = queueDirectory.appendingPathComponent(bodyFileName)
        try body.write(to: bodyURL, options: [.atomic])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        return (request, bodyURL)
    }

    private func append(_ string: String, to data: inout Data) {
        data.append(Data(string.utf8))
    }

    private func handleUploadTaskCompletion(task: URLSessionTask, error: Error?) {
        guard let uploadID = task.taskDescription, let item = items.first(where: { $0.id == uploadID }) else {
            responseDataByTaskID[task.taskIdentifier] = nil
            return
        }

        activeUploadIDs.remove(uploadID)
        inFlightCount = activeUploadIDs.count

        if let error {
            responseDataByTaskID[task.taskIdentifier] = nil
            handleFailure(for: item, error: error)
            return
        }

        guard let response = task.response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            let status = (task.response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = responseDataByTaskID[task.taskIdentifier].flatMap { String(data: $0, encoding: .utf8) } ?? ""
            responseDataByTaskID[task.taskIdentifier] = nil
            handleFailure(for: item, error: queueError("Photo upload failed with status \(status). \(responseText)"))
            return
        }

        responseDataByTaskID[task.taskIdentifier] = nil
        let uploadedURL = downloadURL(for: item)
        var uploadedItem = item
        uploadedItem.uploadedURL = uploadedURL
        uploadedItem.lastErrorDescription = nil
        replaceItem(uploadedItem)
        patchJob(uploadedItem, photoURL: uploadedURL)
    }

    private func patchJob(_ item: PendingJobPhotoUpload, photoURL: String) {
        patchInFlightCount += 1
        db.collection("jobs").document(item.jobID).updateData([item.slot.firestoreField: photoURL]) { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.patchInFlightCount = max(self.patchInFlightCount - 1, 0)
                if let error {
                    self.handleFailure(for: item, error: error)
                } else {
                    self.finish(item, removingLocalFiles: true)
                }
                self.drainBackgroundSessionCompletionIfReady()
            }
        }
    }

    private func handleFailure(for item: PendingJobPhotoUpload, error: Error) {
        if isFirestoreNotFound(error) {
            finish(item, removingLocalFiles: true)
            return
        }

        activeUploadIDs.remove(item.id)
        inFlightCount = activeUploadIDs.count

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].attempts += 1
            items[index].lastErrorDescription = error.localizedDescription
        }

        pendingCount = items.count
        saveManifest()
        publishSyncState()
        scheduleRetry(after: retryDelay(forAttempts: (items.first { $0.id == item.id }?.attempts ?? item.attempts + 1)))
        drainBackgroundSessionCompletionIfReady()
    }

    private func isFirestoreNotFound(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == FirestoreErrorDomain && nsError.code == FirestoreErrorCode.notFound.rawValue
    }

    private func finish(_ item: PendingJobPhotoUpload, removingLocalFiles: Bool) {
        activeUploadIDs.remove(item.id)
        inFlightCount = activeUploadIDs.count

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let removed = items.remove(at: index)
            if removingLocalFiles {
                try? fileManager.removeItem(at: queueDirectory.appendingPathComponent(removed.fileName))
                if let bodyFileName = removed.bodyFileName {
                    try? fileManager.removeItem(at: queueDirectory.appendingPathComponent(bodyFileName))
                }
            }
        }

        cycleDoneCount += 1
        completedCount = cycleDoneCount
        pendingCount = items.count
        saveManifest()
        publishSyncState()
        processQueue()
    }

    private func replaceItem(_ item: PendingJobPhotoUpload) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        saveManifest()
    }

    private func scheduleRetry(after delay: TimeInterval) {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            let nanoseconds = UInt64(max(delay, 1) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            await MainActor.run {
                self?.retryTask = nil
                self?.reconcileBackgroundTasksThenProcess()
            }
        }
    }

    private func retryDelay(forAttempts attempts: Int) -> TimeInterval {
        let cappedAttempts = min(max(attempts, 1), 5)
        return min(pow(2.0, Double(cappedAttempts)) * 3.0, 60.0)
    }

    private func resetCycleIfFinished() {
        guard activeUploadIDs.isEmpty, items.isEmpty else { return }
        if cycleTotalCount > 0, cycleDoneCount >= cycleTotalCount {
            publishSyncState()
        }
        cycleTotalCount = 0
        cycleDoneCount = 0
        completedCount = 0
        pendingCount = 0
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL) else { return }
        do {
            let decoded = try JSONDecoder().decode([PendingJobPhotoUpload].self, from: data)
            items = decoded.filter { item in
                fileManager.fileExists(atPath: queueDirectory.appendingPathComponent(item.fileName).path)
            }
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

    private func downloadURL(for item: PendingJobPhotoUpload) -> String {
        let bucket = FirebaseApp.app()?.options.storageBucket ?? ""
        var allowedPathCharacters = CharacterSet.urlPathAllowed
        allowedPathCharacters.remove(charactersIn: "/")
        let encodedPath = item.storagePath.addingPercentEncoding(withAllowedCharacters: allowedPathCharacters) ?? item.storagePath
        return "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/\(encodedPath)?alt=media&token=\(item.downloadToken)"
    }

    private func queueError(_ message: String) -> NSError {
        NSError(domain: "JobPhotoUploadQueue", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func beginUploadSetupBackgroundTask() {
        guard uploadSetupBackgroundTask == .invalid else { return }
        uploadSetupBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Start job photo upload") { [weak self] in
            Task { @MainActor in
                self?.endUploadSetupBackgroundTask()
            }
        }
    }

    private func endUploadSetupBackgroundTask() {
        guard uploadSetupBackgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(uploadSetupBackgroundTask)
        uploadSetupBackgroundTask = .invalid
    }

    private func drainBackgroundSessionCompletionIfReady() {
        guard didReceiveBackgroundSessionEvents,
              activeUploadIDs.isEmpty,
              patchInFlightCount == 0,
              let completionHandler = backgroundSessionCompletionHandler else { return }
        didReceiveBackgroundSessionEvents = false
        backgroundSessionCompletionHandler = nil
        completionHandler()
    }
}

extension JobPhotoUploadQueue: URLSessionDataDelegate, URLSessionTaskDelegate, URLSessionDelegate {
    nonisolated func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Task { @MainActor in
            self.responseDataByTaskID[dataTask.taskIdentifier, default: Data()].append(data)
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            self.handleUploadTaskCompletion(task: task, error: error)
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Task { @MainActor in
            self.didReceiveBackgroundSessionEvents = true
            self.drainBackgroundSessionCompletionIfReady()
        }
    }
}

extension Notification.Name {
    static let jobPhotoUploadsSyncStateDidChange = Notification.Name("jobPhotoUploadsSyncStateDidChange")
}
