//
//  SharedJobPayload.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/24/25.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth

/// What we allow to travel across users when sharing a job (minimal & privacy-safe).
/// We removed the old includeMaterials/Notes/Photos flags. Now we only share:
///  - address, date, status, jobNumber
///  - assignment (but only applied if sender **and** receiver are CAN users)
struct SharedJobPayload: Codable {
    let v: Int               // schema version
    let createdAt: Timestamp
    let fromUserId: String?

    // Core fields (adjust to your Job model as needed)
    let address: String
    let date: Timestamp
    let status: String
    let jobNumber: String?

    // Conditional field: carried in payload but only applied when allowed
    let assignment: String?
    let senderIsCan: Bool
}

final class SharedJobService {
    static let shared = SharedJobService()
    private init() {}

    /// Creates a one-time token in Firestore and returns a deep link the user can share.
    /// Note: The old include toggles are ignored by design now. We always share minimal fields.
    func publishShareLink(
        job: Job,
        includeMaterials: Bool = false,   // Ignored
        includeNotes: Bool = false,       // Ignored
        includePhotos: Bool = false       // Ignored
    ) async throws -> URL {
        let token = Self.randomToken(length: 24)
        let db = Firestore.firestore()

        // Determine if the SENDER is a CAN user
        let senderIsCan = await currentUserIsCAN()

        // Map your Job -> payload here (adjust if your Job fields differ)
        let payload = SharedJobPayload(
            v: 2, // bump schema version
            createdAt: Timestamp(date: Date()),
            fromUserId: Auth.auth().currentUser?.uid,
            address: job.address,
            date: Timestamp(date: job.date),
            status: job.status,
            jobNumber: job.jobNumber,
            assignment: senderIsCan ? job.assignments : nil,
            senderIsCan: senderIsCan
        )

        // Build Firestore payload. Start from the encoded struct and add an expiry.
        var write = try Firestore.Encoder().encode(payload)
        // Soft expiration (+7 days). Omit claimedBy/claimedAt entirely on creation.
        write["expiresAt"] = Timestamp(date: Date().addingTimeInterval(7*24*3600))

        // Use merge:true to be safe when adding extra fields.
        try await db.collection("sharedJobs").document(token).setData(write, merge: true)

        // Custom URL scheme link (Universal Links optional later)
        guard let url = URL(string: "jobtracker://importJob?token=\(token)") else {
            throw NSError(domain: "DeepLink", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to build URL"])
        }

        #if DEBUG
        print("[Share] Created token: \(token) → \(url.absoluteString)")
        #endif
        return url
    }

    /// Consumes a token, creates a new Job for the current user and returns it.
    @discardableResult
    func importJob(using token: String) async throws -> Job {
        let db = Firestore.firestore()
        let ref = db.collection("sharedJobs").document(token)
        let snap = try await ref.getDocument()

        guard snap.exists, let data = snap.data() else {
            throw NSError(domain: "DeepLink", code: 404, userInfo: [NSLocalizedDescriptionKey: "Link expired or invalid"])
        }

        // Basic validity checks
        if let expires = data["expiresAt"] as? Timestamp, expires.dateValue() < Date() {
            throw NSError(domain: "DeepLink", code: 410, userInfo: [NSLocalizedDescriptionKey: "Link expired"])
        }
        if let claimedBy = data["claimedBy"] as? String, !claimedBy.isEmpty {
            throw NSError(domain: "DeepLink", code: 409, userInfo: [NSLocalizedDescriptionKey: "Link already used"])
        }

        let payload = try Firestore.Decoder().decode(SharedJobPayload.self, from: data)

        // Build the recipient’s Job. Keep only shared fields.
        // (Adjust initializer to your actual Job model)
        var newJob = Job(
            address: payload.address,
            date: payload.date.dateValue(),
            status: payload.status
        )
        newJob.jobNumber = payload.jobNumber

        // Assignment handling: only apply if sender **and** receiver are CAN
        let receiverIsCan = await currentUserIsCAN()
        if payload.senderIsCan, receiverIsCan, let assignment = payload.assignment, !assignment.isEmpty {
            newJob.assignments = assignment
        }

        // Ensure the imported job appears for the current user’s dashboard filters
        let myID = Auth.auth().currentUser?.uid
        newJob.createdBy = myID
        newJob.assignedTo = myID

        try await FirebaseService.shared.createJobAsync(newJob)

        // Mark token as consumed (but keep the doc for audit/abuse mitigation)
        let claimedBy = Auth.auth().currentUser?.uid ?? "unknown"
        try await ref.updateData([
            "claimedBy": claimedBy,
            "claimedAt": FieldValue.serverTimestamp()
        ])

        return newJob
    }

    private static func randomToken(length: Int) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghijklmnopqrstuvwxyz")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    /// Reads the current user’s role and returns true if it includes "can".
    /// Adjust the collection/name/key to match your schema.
    private func currentUserIsCAN() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            let role = (doc.data()?["role"] as? String)?.lowercased() ?? ""
            return role.contains("can")
        } catch {
            #if DEBUG
            print("[Share] Failed to fetch user role: \(error.localizedDescription)")
            #endif
            return false
        }
    }
}
