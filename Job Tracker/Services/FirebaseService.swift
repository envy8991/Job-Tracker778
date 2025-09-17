//
//  FirebaseService.swift
//  Job Tracking Cable South
//
//  Created by Quinton Thompson on 1/30/25.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage



class FirebaseService {
    static let shared = FirebaseService()
    private init() { }
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - Authentication
    
    func signUpUser(firstName: String,
                    lastName: String,
                    position: String,
                    email: String,
                    password: String,
                    completion: @escaping (Result<AppUser, Error>) -> Void) {
        
        auth.createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user returned"])))
                return
            }
            
            let appUser = AppUser(
                id: user.uid,
                firstName: firstName,
                lastName: lastName,
                email: email,
                position: position
            )
            
            do {
                try self.db.collection("users").document(user.uid).setData(from: appUser) { err in
                    if let err = err {
                        completion(.failure(err))
                    } else {
                        completion(.success(appUser))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func signInUser(email: String,
                    password: String,
                    completion: @escaping (Result<String, Error>) -> Void) {
        auth.signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let user = result?.user {
                completion(.success(user.uid))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: nil)))
            }
        }
    }
    
    func signOutUser() throws {
        try auth.signOut()
    }
    
    func currentUserID() -> String? {
        return auth.currentUser?.uid
    }

    // Admin check via Firebase custom claims (expects { admin: true } on the user)
    private func isCurrentUserAdmin(_ completion: @escaping (Bool) -> Void) {
        guard let user = Auth.auth().currentUser else { completion(false); return }
        user.getIDTokenResult(forcingRefresh: true) { result, _ in
            let claims = result?.claims ?? [:]
            completion((claims["admin"] as? Bool) == true)
        }
    }
    
    // Fetch current user doc from Firestore
    func fetchCurrentUser(completion: @escaping (Result<AppUser, Error>) -> Void) {
        guard let uid = currentUserID() else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let snapshot = snapshot, snapshot.exists else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User doc not found"])))
                return
            }
            do {
                var user = try snapshot.data(as: AppUser.self)
                // Backfill missing email from Firebase Auth if needed
                if user.email.isEmpty, let authEmail = self.auth.currentUser?.email {
                    self.db.collection("users").document(uid)
                        .setData(["email": authEmail], merge: true)
                    // Also update the local instance so callers receive a populated email immediately
                    user.email = authEmail
                }
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        }
    }
    // Manual mapper for PartnerRequest (no FirebaseFirestoreSwift dependency)
    private func mapPartnerRequest(doc: DocumentSnapshot) -> PartnerRequest? {
        let data = doc.data() ?? [:]
        guard let fromUid = data["fromUid"] as? String,
              let toUid = data["toUid"] as? String,
              let status = data["status"] as? String else {
            return nil
        }
        var createdAtDate = Date()
        if let ts = data["createdAt"] as? Timestamp {
            createdAtDate = ts.dateValue()
        } else if let secs = data["createdAt"] as? Double {
            createdAtDate = Date(timeIntervalSince1970: secs)
        }
        return PartnerRequest(id: doc.documentID,
                              fromUid: fromUid,
                              toUid: toUid,
                              status: status,
                              createdAt: createdAtDate)
    }

    // MARK: - Partnerships
    func sendPartnerRequest(from: String, to: String, completion: @escaping (Bool) -> Void) {
        let doc = db.collection("partnerRequests").document()
        let payload: [String: Any] = [
            "fromUid": from,
            "toUid": to,
            "status": "pending",
            "createdAt": Timestamp(date: Date())
        ]
        doc.setData(payload) { err in completion(err == nil) }
    }

    func listenIncomingRequests(for uid: String, handler: @escaping ([PartnerRequest]) -> Void) {
        db.collection("partnerRequests")
            .whereField("toUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snap, _ in
                let items = snap?.documents.compactMap { self.mapPartnerRequest(doc: $0) } ?? []
                handler(items)
            }
    }

    func listenOutgoingRequests(for uid: String, handler: @escaping ([PartnerRequest]) -> Void) {
        db.collection("partnerRequests")
            .whereField("fromUid", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { snap, _ in
                let items = snap?.documents.compactMap { self.mapPartnerRequest(doc: $0) } ?? []
                handler(items)
            }
    }

    func acceptPartnerRequest(request: PartnerRequest, completion: @escaping (Bool) -> Void) {
        guard let reqId = request.id else { completion(false); return }
        let uid1 = request.fromUid
        let uid2 = request.toUid
        let pairId = [uid1, uid2].sorted().joined(separator: "_")
        let batch = db.batch()
        let pairRef = db.collection("partnerships").document(pairId)
        batch.setData(["members": [uid1, uid2], "createdAt": Timestamp(date: Date())], forDocument: pairRef)
        let reqRef = db.collection("partnerRequests").document(reqId)
        batch.deleteDocument(reqRef)
        batch.commit { err in completion(err == nil) }
    }

    func declinePartnerRequest(request: PartnerRequest, completion: @escaping (Bool) -> Void) {
        guard let reqId = request.id else { completion(false); return }
        db.collection("partnerRequests").document(reqId).updateData(["status": "declined"]) { err in
            completion(err == nil)
        }
    }

    func unpair(uid: String, partnerUid: String, completion: @escaping (Bool) -> Void) {
        let pairId = [uid, partnerUid].sorted().joined(separator: "_")
        db.collection("partnerships").document(pairId).delete { err in
            completion(err == nil)
        }
    }

    /// Returns the partner's uid if a partnership exists, else nil.
    func fetchPartnerId(for uid: String, completion: @escaping (String?) -> Void) {
        db.collection("partnerships").whereField("members", arrayContains: uid).limit(to: 1).getDocuments { snap, _ in
            guard let doc = snap?.documents.first,
                  let members = doc["members"] as? [String],
                  let partner = members.first(where: { $0 != uid }) else { completion(nil); return }
            completion(partner)
        }
    }
    
    // MARK: - Jobs
    
    /// Creation visibility invariant:
    /// - Only the assignee should see the job on their dashboard.
    /// - On create, we set `participants = [assignedTo]` (if present) and do NOT include `createdBy` or partner.
    /// - Updates must not modify `participants` unless intentionally changing access.
    func createJob(_ job: Job, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let docRef = db.collection("jobs").document(job.id)
            try docRef.setData(from: job, merge: true) { err in
                if let err = err {
                    completion(.failure(err))
                    return
                }
                // New visibility logic:
                if let assignee = job.assignedTo, !assignee.isEmpty {
                    // Assigned job: only the assignee should see it
                    docRef.updateData(["participants": [assignee]]) { patchErr in
                        if let patchErr = patchErr {
                            completion(.failure(patchErr))
                        } else {
                            completion(.success(()))
                        }
                    }
                } else if let creator = job.createdBy, !creator.isEmpty {
                    // Unassigned (e.g. Pending) but created by a user on-device: make it visible to the creator only
                    docRef.updateData(["participants": [creator]]) { patchErr in
                        if let patchErr = patchErr {
                            completion(.failure(patchErr))
                        } else {
                            completion(.success(()))
                        }
                    }
                } else {
                    // No assignee and no creator — leave participants unset
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Creation visibility invariant:
    /// - Only the assignee should see the job on their dashboard.
    /// - On create, we set `participants = [assignedTo]` (if present) and do NOT include `createdBy` or partner.
    /// - Updates must not modify `participants` unless intentionally changing access.
    func updateJob(_ job: Job, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try db.collection("jobs").document(job.id).setData(from: job, merge: true) { err in
                if let err = err {
                    completion(.failure(err))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func deleteJob(_ job: Job, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let me = currentUserID() else {
            completion(.failure(NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }
        let ref = db.collection("jobs").document(job.id)
        if job.createdBy == me {
            // Creator can hard delete
            ref.delete { err in
                if let err = err { completion(.failure(err)) }
                else { completion(.success(())) }
            }
        } else {
            // Non-creator: soft delete (leave job)
            leaveJob(jobId: job.id) { result in
                switch result {
                case .success: completion(.success(()))
                case .failure(let e): completion(.failure(e))
                }
            }
        }
    }
    
    func listenToJobs(completion: @escaping ([Job]) -> Void) -> ListenerRegistration {
        // If not signed in, return a benign listener that yields no results.
        guard let me = currentUserID() else {
            let q = db.collection("jobs").whereField("participants", arrayContains: "__unauth__")
            return q.addSnapshotListener { _, _ in completion([]) }
        }
        return db.collection("jobs")
            .whereField("participants", arrayContains: me)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Error listening to jobs: \(error.localizedDescription)")
                    completion([])
                    return
                }
                guard let docs = snapshot?.documents else {
                    completion([])
                    return
                }
                let jobs = docs.compactMap { try? $0.data(as: Job.self) }
                completion(jobs)
            }
    }

    // Fetch jobs for a specific calendar day for the current user (and partner if paired)
    func fetchJobsForDate(_ date: Date, completion: @escaping (Result<[Job], Error>) -> Void) {
        guard let me = currentUserID() else {
            completion(.failure(NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])));
            return
        }

        // Compute start/end of day
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        guard let endOfDay = cal.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) else {
            completion(.failure(NSError(domain: "FirebaseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Date math failed"])));
            return
        }

        let group = DispatchGroup()
        var jobsDict: [String: Job] = [:]
        var firstError: Error?

        func collect(from snapshot: QuerySnapshot?) {
            snapshot?.documents.forEach { doc in
                if let job = try? doc.data(as: Job.self) {
                    jobsDict[job.id] = job
                }
            }
        }

        // Query A: participants contains me (durable access)
        group.enter()
        db.collection("jobs")
            .whereField("participants", arrayContains: me)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endOfDay))
            .getDocuments { snap, err in
                if let err = err, firstError == nil { firstError = err }
                collect(from: snap)
                group.leave()
            }

        // Query B (legacy): createdBy == me
        group.enter()
        db.collection("jobs")
            .whereField("createdBy", isEqualTo: me)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endOfDay))
            .getDocuments { snap, err in
                if let err = err, firstError == nil { firstError = err }
                collect(from: snap)
                group.leave()
            }

        // Query C (legacy): assignedTo == me
        group.enter()
        db.collection("jobs")
            .whereField("assignedTo", isEqualTo: me)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endOfDay))
            .getDocuments { snap, err in
                if let err = err, firstError == nil { firstError = err }
                collect(from: snap)
                group.leave()
            }

        group.notify(queue: .main) {
            if let err = firstError { completion(.failure(err)) }
            else { completion(.success(Array(jobsDict.values))) }
        }
    }

    /// NOTE: Do not modify 'participants' here; historical access is preserved even if users unpair later.
    /// Update only the status field of a job document.
    func updateJobStatus(jobId: String, newStatus: String, completion: @escaping (Error?) -> Void) {
        db.collection("jobs").document(jobId).updateData(["status": newStatus]) { error in
            completion(error)
        }
    }

    /// Remove the current user from a job's participants (soft delete for non-creators).
    /// If participants becomes empty, the job is deleted.
    func leaveJob(jobId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let me = currentUserID() else {
            completion(.failure(NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }
        let ref = db.collection("jobs").document(jobId)
        db.runTransaction({ txn, errorPointer in
            do {
                let snap = try txn.getDocument(ref)
                guard var data = snap.data() else {
                    throw NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Job not found"])
                }
                var participants = data["participants"] as? [String] ?? []
                participants.removeAll { $0 == me }
                if participants.isEmpty {
                    txn.deleteDocument(ref)
                } else {
                    txn.updateData(["participants": participants], forDocument: ref)
                }
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }) { _, err in
            if let err = err { completion(.failure(err)) } else { completion(.success(())) }
        }
    }

    /// Hard delete a job if and only if the current user is the creator.
    func deleteJobIfCreator(jobId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let me = currentUserID() else {
            completion(.failure(NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }
        let ref = db.collection("jobs").document(jobId)
        ref.getDocument { snap, err in
            if let err = err { completion(.failure(err)); return }
            guard let data = snap?.data(),
                  let creator = data["createdBy"] as? String else {
                completion(.failure(NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Job not found"])))
                return
            }
            if creator == me {
                ref.delete { delErr in
                    if let delErr = delErr { completion(.failure(delErr)) }
                    else { completion(.success(())) }
                }
            } else {
                completion(.failure(NSError(domain: "FirebaseService", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only the creator can delete this job. Use leaveJob instead."])))
            }
        }
    }

    // Rules intent:
    // - allow delete if user is the document creator OR (is paired with the other participant AND both are participants on the job) at deletion time.
    // - allow update if user is in participants.
    // Implementing the dynamic "paired" check may require Cloud Functions or a secure schema; client enforces it here.

    /// Delete logic that respects current pairing:
    /// - If the current user is actively paired with another participant on this job at deletion time, HARD delete the job (removes for both).
    /// - If not paired, SOFT delete (remove only the current user from `participants`; delete doc only if no one remains).
    func deleteJobRespectingPairing(jobId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let me = currentUserID() else {
            completion(.failure(NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }
        let ref = db.collection("jobs").document(jobId)
        ref.getDocument { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err { completion(.failure(err)); return }
            guard let data = snap?.data() else {
                completion(.failure(NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Job not found"])))
                return
            }
            let participants = (data["participants"] as? [String]) ?? []
            // Who am I currently paired with?
            self.fetchPartnerId(for: me) { currentPartner in
                // If we're currently paired and the partner is also a participant on this job, HARD delete (removes for both).
                if let partner = currentPartner, participants.contains(partner) {
                    ref.delete { delErr in
                        if let delErr = delErr { completion(.failure(delErr)) }
                        else { completion(.success(())) }
                    }
                } else {
                    // Not paired (or partner not on this job): SOFT delete (leave the job)
                    self.leaveJob(jobId: jobId) { result in
                        switch result {
                        case .success: completion(.success(()))
                        case .failure(let e): completion(.failure(e))
                        }
                    }
                }
            }
        }
    }
    
    // One-time helper: backfill `participants` for existing jobs that were created before we added durable access.
    // It merges `createdBy` and `assignedTo` into `participants` if the field is missing or empty.
    // Safe to run multiple times; only updates docs that need it. Batches in chunks to respect Firestore limits.
    //
    // For admin global migration, enforce via rules or callable Cloud Functions:
    // match /databases/{db}/documents {
    //   function isAdmin() { return request.auth.token.admin == true; }
    //   match /jobs/{jobId} {
    //     allow update: if request.auth.uid in resource.data.participants || isAdmin();
    //   }
    // }
    func backfillParticipantsForExistingJobs(completion: @escaping (Result<Int, Error>) -> Void) {
        guard let me = currentUserID() else {
            completion(.failure(NSError(domain: "FirebaseService", code: 401,
                                        userInfo: [NSLocalizedDescriptionKey: "Not signed in"])))
            return
        }

        let group = DispatchGroup()
        var allDocs: [DocumentSnapshot] = []
        var firstErr: Error?

        func collect(_ snap: QuerySnapshot?) { allDocs.append(contentsOf: snap?.documents ?? []) }

        // Legacy sources: jobs I created and jobs assigned to me
        group.enter()
        db.collection("jobs").whereField("createdBy", isEqualTo: me).getDocuments { s, e in
            if let e = e, firstErr == nil { firstErr = e }
            collect(s); group.leave()
        }
        group.enter()
        db.collection("jobs").whereField("assignedTo", isEqualTo: me).getDocuments { s, e in
            if let e = e, firstErr == nil { firstErr = e }
            collect(s); group.leave()
        }

        group.notify(queue: .main) {
            if let e = firstErr {
                completion(.failure(e)); return
            }

            // Dedupe by document ID
            var seen = Set<String>()
            let docs = allDocs.filter { seen.insert($0.documentID).inserted }

            // Prepare updates
            var updates: [(DocumentReference, [String: Any])] = []
            for doc in docs {
                let data = doc.data() ?? [:]
                let existing = (data["participants"] as? [String]) ?? []
                if !existing.isEmpty { continue }

                var ps = Set<String>()
                if let c = data["createdBy"] as? String, !c.isEmpty { ps.insert(c) }
                if let a = data["assignedTo"] as? String, !a.isEmpty { ps.insert(a) }
                if ps.isEmpty { continue }
                updates.append((doc.reference, ["participants": Array(ps)]))
            }

            if updates.isEmpty { completion(.success(0)); return }

            // Commit in chunks (<=450 per batch for safety)
            var updatedCount = 0
            func commitChunk(from start: Int) {
                if start >= updates.count {
                    completion(.success(updatedCount)); return
                }
                let end = min(start + 450, updates.count)
                let batch = self.db.batch()
                for i in start..<end {
                    let (ref, payload) = updates[i]
                    batch.updateData(payload, forDocument: ref)
                }
                batch.commit { err in
                    if let err = err { completion(.failure(err)); return }
                    updatedCount += (end - start)
                    commitChunk(from: end)
                }
            }
            commitChunk(from: 0)
        }
    }

    // GLOBAL migration: backfill `participants` for ALL jobs in the collection.
    // NOTE: This runs client-side and assumes your Firestore Rules allow the signed-in user to perform these updates.
    // Consider running this as a server-side (Callable Cloud Function) migration for very large datasets or stricter security.
    func adminBackfillParticipantsForAllJobs(completion: @escaping (Result<Int, Error>) -> Void) {
        self.db.collection("jobs").getDocuments { snapshot, error in
            if let error = error { completion(.failure(error)); return }
            let docs = snapshot?.documents ?? []
            var updates: [(DocumentReference, [String: Any])] = []
            for doc in docs {
                let data = doc.data()
                let existing = (data["participants"] as? [String]) ?? []
                if !existing.isEmpty { continue }
                var ps = Set<String>()
                if let c = data["createdBy"] as? String, !c.isEmpty { ps.insert(c) }
                if let a = data["assignedTo"] as? String, !a.isEmpty { ps.insert(a) }
                if ps.isEmpty { continue }
                updates.append((doc.reference, ["participants": Array(ps)]))
            }
            if updates.isEmpty { completion(.success(0)); return }
            // Commit in chunks (<=450 per batch for safety)
            var updatedCount = 0
            func commitChunk(from start: Int) {
                if start >= updates.count {
                    completion(.success(updatedCount)); return
                }
                let end = min(start + 450, updates.count)
                let batch = self.db.batch()
                for i in start..<end {
                    let (ref, payload) = updates[i]
                    batch.updateData(payload, forDocument: ref)
                }
                batch.commit { err in
                    if let err = err { completion(.failure(err)); return }
                    updatedCount += (end - start)
                    commitChunk(from: end)
                }
            }
            commitChunk(from: 0)
        }
    }

    // MARK: - Photo Upload
    
    func uploadImage(_ image: UIImage, for jobID: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"])))
            return
        }
        let fileName = UUID().uuidString + ".jpg"
        let ref = storage.reference().child("jobPhotos/\(jobID)/\(fileName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let url = url {
                    completion(.success(url.absoluteString))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No download URL"])))
                }
            }
        }
    }
    /// Deletes the current Firebase Auth user and (optionally) their `/users/{uid}` profile document.
    /// This preserves all job/timesheet documents.
    ///
    /// - Parameters:
    ///   - preserveJobs: Ignored internally (jobs are always preserved); present for API clarity.
    ///   - completion: Result indicating success or error.
    func deleteCurrentAuthUser(preserveJobs: Bool = true, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = self.currentUserID() else {
            completion(.failure(NSError(
                domain: "FirebaseService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No signed-in user."]
            )))
            return
        }

        let userDoc = db.collection("users").document(uid)

        // If you prefer to retain the profile doc as well, comment out this delete and only delete the Auth user.
        userDoc.delete { _ in
            if let user = Auth.auth().currentUser {
                user.delete { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            } else {
                completion(.failure(NSError(
                    domain: "FirebaseService",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "No current Auth user."]
                )))
            }
        }
    }
}

// MARK: - Async/Await Extension
// Ensure your deployment target is iOS 15+ for withCheckedThrowingContinuation.
@available(iOS 15.0, *)
extension FirebaseService {
    /// Creation visibility invariant:
    /// - Only the assignee should see the job on their dashboard.
    /// - On create, we set `participants = [assignedTo]` (if present) and do NOT include `createdBy` or partner.
    /// - Updates must not modify `participants` unless intentionally changing access.
    func createJobAsync(_ job: Job) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                let docRef = db.collection("jobs").document(job.id)
                try docRef.setData(from: job, merge: true) { err in
                    if let err = err {
                        continuation.resume(throwing: err)
                        return
                    }
                    // New visibility logic:
                    if let assignee = job.assignedTo, !assignee.isEmpty {
                        // Assigned job: only the assignee should see it
                        docRef.updateData(["participants": [assignee]]) { updateErr in
                            if let updateErr = updateErr {
                                continuation.resume(throwing: updateErr)
                            } else {
                                continuation.resume(returning: ())
                            }
                        }
                    } else if let creator = job.createdBy, !creator.isEmpty {
                        // Unassigned (e.g. Pending) self-created job: visible to creator only
                        docRef.updateData(["participants": [creator]]) { updateErr in
                            if let updateErr = updateErr {
                                continuation.resume(throwing: updateErr)
                            } else {
                                continuation.resume(returning: ())
                            }
                        }
                    } else {
                        // No assignee/creator present
                        continuation.resume(returning: ())
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Async: fetch jobs for a single day (includes partner when paired)
    func fetchJobsAsync(for date: Date) async throws -> [Job] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Job], Error>) in
            self.fetchJobsForDate(date) { result in
                switch result {
                case .success(let jobs): cont.resume(returning: jobs)
                case .failure(let err): cont.resume(throwing: err)
                }
            }
        }
    }

    /// Async: update job status
    func updateJobStatusAsync(jobId: String, newStatus: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.updateJobStatus(jobId: jobId, newStatus: newStatus) { error in
                if let error = error { cont.resume(throwing: error) }
                else { cont.resume(returning: ()) }
            }
        }
    }
}
