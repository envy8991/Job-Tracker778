//
//  SharedJobPayload.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/24/25.
//

import Foundation
import CoreLocation
import Firebase
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

/// What we allow to travel across users when sharing a job (minimal & privacy-safe).
/// We removed the old includeMaterials/Notes/Photos flags. Now we only share:
///  - address, date, status, jobNumber
///  - assignment (but only applied if sender **and** receiver are CAN users)
struct SharedJobPayload: Codable, Equatable {
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

    static func == (lhs: SharedJobPayload, rhs: SharedJobPayload) -> Bool {
        lhs.v == rhs.v &&
        lhs.createdAt.seconds == rhs.createdAt.seconds &&
        lhs.createdAt.nanoseconds == rhs.createdAt.nanoseconds &&
        lhs.fromUserId == rhs.fromUserId &&
        lhs.address == rhs.address &&
        lhs.date.seconds == rhs.date.seconds &&
        lhs.date.nanoseconds == rhs.date.nanoseconds &&
        lhs.status == rhs.status &&
        lhs.jobNumber == rhs.jobNumber &&
        lhs.assignment == rhs.assignment &&
        lhs.senderIsCan == rhs.senderIsCan
    }
}

struct SharedJobPreview: Identifiable, Equatable {
    let token: String
    let payload: SharedJobPayload

    var id: String { token }
}

final class SharedJobService {
    static let shared = SharedJobService()
    var geocoder: SharedJobGeocoding = CLSharedJobGeocoder()
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
        let senderRole = await currentUserNormalizedRole()
        let senderIsCan = senderRole == "can"

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

    /// Loads a shared job without mutating remote state.
    func loadSharedJob(token: String) async throws -> SharedJobPreview {
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

        return SharedJobPreview(token: token, payload: payload)
    }

    /// Consumes a token, creates a new Job for the current user and returns it.
    @discardableResult
    func importJob(using token: String) async throws -> Job {
        let preview = try await loadSharedJob(token: token)
        let payload = preview.payload

        let db = Firestore.firestore()
        let ref = db.collection("sharedJobs").document(token)

        // Assignment handling: only apply if sender **and** receiver are CAN
        let receiverRole = await currentUserNormalizedRole()
        let receiverIsCan = receiverRole == "can"
        let myID = Auth.auth().currentUser?.uid

        let newJob = await makeJob(
            from: payload,
            receiverIsCAN: receiverIsCan,
            currentUserID: myID
        )

        try await FirebaseService.shared.createJobAsync(newJob)

        // Mark token as consumed (but keep the doc for audit/abuse mitigation)
        let claimedBy = Auth.auth().currentUser?.uid ?? "unknown"
        try await ref.updateData([
            "claimedBy": claimedBy,
            "claimedAt": FieldValue.serverTimestamp()
        ])

        return newJob
    }

    func makeJob(
        from payload: SharedJobPayload,
        receiverIsCAN: Bool,
        currentUserID: String?
    ) async -> Job {
        // Build the recipient’s Job. Keep only shared fields.
        // (Adjust initializer to your actual Job model)
        var newJob = Job(
            address: payload.address,
            date: payload.date.dateValue(),
            status: payload.status
        )
        newJob.jobNumber = payload.jobNumber

        if payload.senderIsCan, receiverIsCAN, let assignment = payload.assignment, !assignment.isEmpty {
            newJob.assignments = assignment
        }

        newJob.createdBy = currentUserID
        newJob.assignedTo = currentUserID

        if let coordinate = await geocodeCoordinate(for: payload.address) {
            newJob.latitude = coordinate.latitude
            newJob.longitude = coordinate.longitude
        }

        return newJob
    }

    private func geocodeCoordinate(for address: String) async -> CLLocationCoordinate2D? {
        do {
            return try await geocoder.coordinate(for: address)
        } catch {
            #if DEBUG
            print("[Share] Failed to geocode address \(address): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private static func randomToken(length: Int) -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789abcdefghijklmnopqrstuvwxyz")
        return String((0..<length).compactMap { _ in chars.randomElement() })
    }

    /// Reads the current user’s normalized role (lowercased) from `/users/{uid}`.
    private func currentUserNormalizedRole() async -> String? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        do {
            let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()
            guard doc.exists else { return nil }
            var user = try doc.data(as: AppUser.self)
            if user.id.isEmpty {
                user.id = doc.documentID
            }
            return user.normalizedPosition.lowercased()
        } catch {
            #if DEBUG
            print("[Share] Failed to fetch user role: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}

protocol SharedJobGeocoding: AnyObject {
    func coordinate(for address: String) async throws -> CLLocationCoordinate2D?
}

final class CLSharedJobGeocoder: SharedJobGeocoding {
    private let geocoder = CLGeocoder()

    func coordinate(for address: String) async throws -> CLLocationCoordinate2D? {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                if let coordinate = placemarks?.first?.location?.coordinate {
                    continuation.resume(returning: coordinate)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
