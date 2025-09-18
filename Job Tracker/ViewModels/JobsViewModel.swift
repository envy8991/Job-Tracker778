import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

class JobsViewModel: ObservableObject {
    // Main data
    @Published var jobs: [Job] = []

    // Global search index: all jobs (used by JobSearchView to search across *everyone's* jobs)
    @Published var searchJobs: [Job] = []

    // Track whether the initial snapshot for the current query has been received.
    @Published var hasLoadedInitialJobs: Bool = false

    // NEW: robust sync state
    @Published var pendingWriteIDs: Set<String> = []   // which docs currently have local pending writes
    @Published var hasPendingWrites: Bool = false      // quick overall flag for UI
    @Published var lastServerSync: Date? = nil         // when a clean server-confirmed snapshot last arrived

    private var listenerRegistration: ListenerRegistration?
    private var searchListenerRegistration: ListenerRegistration?
    private let db = Firestore.firestore()

    private func currentUserID() -> String? {
        return Auth.auth().currentUser?.uid
    }

    init() {
        // No initial fetch in init()
    }

    deinit {
        listenerRegistration?.remove()
        searchListenerRegistration?.remove()
    }

    /// UI helper: true if this job has a local write waiting to upload
    func isJobPendingSync(_ id: String) -> Bool { pendingWriteIDs.contains(id) }

    private func notifyJobsChanged() {
        DispatchQueue.main.async { [jobs] in
            NotificationCenter.default.post(name: .jobsDidChange, object: jobs)
        }
    }

    // MARK: - Fetch

    func fetchJobs(startDate: Date? = nil, endDate: Date? = nil) {
        listenerRegistration?.remove()

        hasLoadedInitialJobs = false

        guard let me = currentUserID() else {
            // Not signed in – clear jobs and exit gracefully
            DispatchQueue.main.async {
                self.jobs = []
                self.pendingWriteIDs = []
                self.hasPendingWrites = false
                self.lastServerSync = nil
                self.hasLoadedInitialJobs = true
                self.notifyJobsChanged()
            }
            return
        }

        var query: Query = db.collection("jobs").whereField("participants", arrayContains: me)

        if let startDate = startDate, let endDate = endDate {
            query = query.whereField("date", isGreaterThanOrEqualTo: startDate)
                         .whereField("date", isLessThanOrEqualTo: endDate)
        } else if let startDate = startDate {
            query = query.whereField("date", isGreaterThanOrEqualTo: startDate)
        } else if let endDate = endDate {
            query = query.whereField("date", isLessThanOrEqualTo: endDate)
        }

        // IMPORTANT: includeMetadataChanges -> we get immediate cached results + pending write flags
        listenerRegistration = query.addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching jobs: \(error)")
                DispatchQueue.main.async {
                    if !self.hasLoadedInitialJobs {
                        self.hasLoadedInitialJobs = true
                    }
                }
                return
            }
            guard let snapshot = snapshot else {
                DispatchQueue.main.async {
                    if !self.hasLoadedInitialJobs {
                        self.hasLoadedInitialJobs = true
                    }
                }
                return
            }

            var seen: Set<String> = []
            var pending: Set<String> = []

            let decoded: [Job] = snapshot.documents.compactMap { doc in
                if doc.metadata.hasPendingWrites {
                    pending.insert(doc.documentID)
                }
                var job = try? doc.data(as: Job.self)
                job?.id = doc.documentID
                if let id = job?.id, !seen.contains(id) {
                    seen.insert(id)
                    return job
                }
                return nil
            }

            DispatchQueue.main.async {
                self.jobs = decoded
                self.pendingWriteIDs = pending
                self.hasPendingWrites = snapshot.metadata.hasPendingWrites || !pending.isEmpty

                if !snapshot.metadata.isFromCache && !self.hasPendingWrites {
                    self.lastServerSync = Date()
                }

                if !self.hasLoadedInitialJobs {
                    self.hasLoadedInitialJobs = true
                }

                self.notifyJobsChanged()
                NotificationCenter.default.post(name: .jobsSyncStateDidChange, object: nil)
            }
        }
    }

    // MARK: - Global Search Index (all jobs)

    /// Begin listening to *all* jobs so search can span the entire database (subject to Firestore rules).
    /// Safe to call multiple times; it will only attach once.
    func startSearchIndexForAllJobs() {
        if searchListenerRegistration != nil { return }

        searchListenerRegistration = db.collection("jobs")
            .addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error building search index: \(error)")
                    return
                }
                guard let snapshot = snapshot else { return }

                let decoded: [Job] = snapshot.documents.compactMap { doc in
                    var job = try? doc.data(as: Job.self)
                    job?.id = doc.documentID
                    return job
                }

                DispatchQueue.main.async {
                    self.searchJobs = decoded
                }
            }
    }

    // MARK: - Fetch By Day / Week

    func fetchJobsForDay(_ day: Date) {
        let startOfDay = Calendar.current.startOfDay(for: day)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        fetchJobs(startDate: startOfDay, endDate: endOfDay.addingTimeInterval(-1)) // inclusive day
    }

    func fetchJobsForWeek(_ selectedDate: Date) {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        if let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) {
            let adjustedEnd = interval.end.addingTimeInterval(-1)
            fetchJobs(startDate: interval.start, endDate: adjustedEnd)
        }
    }

    // MARK: - Create

    func createJob(_ job: Job, completion: @escaping (Bool) -> Void = { _ in }) {
        // Pre-generate the doc ID so it exists locally while offline & UI can show pending state
        let docRef = db.collection("jobs").document()
        var newJob = job
        newJob.id = docRef.documentID

        // Optimistically mark as pending so UI can show “Syncing…”
        DispatchQueue.main.async {
            self.pendingWriteIDs.insert(docRef.documentID)
            self.hasPendingWrites = true
        }

        FirebaseService.shared.createJob(newJob) { result in
            switch result {
            case .success:
                DispatchQueue.main.async { completion(true) }
            case .failure(let error):
                print("Error creating job via service: \(error)")
                DispatchQueue.main.async { completion(false) }
            }
            // Listener established by fetch methods will reconcile & clear pending when server ACKs
        }
    }

    // MARK: - Update

    func updateJob(_ job: Job, documentID: String) {
        let ref = db.collection("jobs").document(documentID)

        // 1) Read current participants so we never drop them during an update
        ref.getDocument { [weak self] snap, readErr in
            guard let self = self else { return }
            if let readErr = readErr {
                print("updateJob: failed to read existing doc: \(readErr)")
            }
            let existingParticipants = (snap?.data()?["participants"] as? [String]) ?? []

            // 2) Merge-write the updated fields (never a blind overwrite)
            do {
                try ref.setData(from: job, merge: true) { writeErr in
                    if let writeErr = writeErr {
                        print("updateJob: merge setData error: \(writeErr)")
                        return
                    }
                    // 3) Re-assert participants if they existed (protects against encoder omitting/clearing them)
                    if !existingParticipants.isEmpty {
                        ref.updateData(["participants": existingParticipants]) { patchErr in
                            if let patchErr = patchErr {
                                print("updateJob: failed to preserve participants: \(patchErr)")
                            }
                        }
                    }
                }
            } catch {
                print("Error updating job (encode): \(error)")
            }

            // 4) Optimistically update local cache so UI doesn't flicker
            if let index = self.jobs.firstIndex(where: { $0.id == documentID }) {
                DispatchQueue.main.async {
                    var copy = self.jobs
                    copy[index] = job
                    // Ensure our local copy keeps participants so list query still matches
                    if !existingParticipants.isEmpty {
                        // If the Job model has a `participants` property, set it here reflectively.
                        // Since we can't guarantee the model API here, we rely on the server-side preserve above.
                    }
                    self.jobs = copy
                    self.notifyJobsChanged()
                }
            } else {
                self.fetchJobs()
            }
        }
    }

    func updateJob(_ job: Job) {
        updateJob(job, documentID: job.id)
    }

    /// Update only the status; fast local feedback + safe offline queueing.
    func updateJobStatus(job: Job, newStatus: String) {
        let docID = job.id

        // Optimistic local update for snappy UI
        if let idx = self.jobs.firstIndex(where: { $0.id == docID }) {
            DispatchQueue.main.async {
                var copy = self.jobs
                copy[idx].status = newStatus
                self.jobs = copy
                self.pendingWriteIDs.insert(docID)
                self.hasPendingWrites = true
                self.notifyJobsChanged()
                NotificationCenter.default.post(name: .jobsSyncStateDidChange, object: nil)
            }
        }

        // Patch Firestore; if the doc isn't there offline, fallback to setData
        db.collection("jobs").document(docID).updateData(["status": newStatus]) { [weak self] err in
            if err != nil {
                var updated = job
                updated.status = newStatus
                self?.updateJob(updated)
            }
            // No success handler needed — listener will clear pending once synced
        }
    }

    // MARK: - Delete

    func deleteJob(documentID: String, completion: @escaping (Bool) -> Void = { _ in }) {
        FirebaseService.shared.deleteJobRespectingPairing(jobId: documentID) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.jobs.removeAll { $0.id == documentID }
                    self.notifyJobsChanged()
                    completion(true)
                case .failure(let e):
                    print("deleteJobRespectingPairing error: \(e)")
                    completion(false)
                }
            }
        }
    }
}

extension Notification.Name {
    static let jobsDidChange = Notification.Name("jobsDidChange")
    // NEW: broadcast when pending state toggles so UI/Watch can react instantly
    static let jobsSyncStateDidChange = Notification.Name("jobsSyncStateDidChange")
}
