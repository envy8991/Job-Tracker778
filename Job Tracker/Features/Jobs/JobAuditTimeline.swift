import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// A deliberately small audit record. `before` and `after` contain display summaries only;
/// job documents, note text, and attachment URLs must never be copied into this collection.
struct JobAuditEvent: Identifiable {
    let id: String
    let actorID: String
    let occurredAt: Date?
    let type: String
    let before: [String: String]
    let after: [String: String]
    let isPending: Bool
}

enum JobAudit {
    static let pageSize = 20

    static func summary(_ job: Job) -> [String: String] {
        [
            "status": job.status,
            "assignment": job.assignedTo?.isEmpty == false ? job.assignedTo! : "Unassigned",
            "schedule": ISO8601DateFormatter().string(from: job.date),
            "notes": job.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? "Present" : "None",
            "attachments": String(job.photos.count + [job.housePhotoURL, job.nidPhotoURL, job.canPhotoURL, job.mapDesignPhotoURL].compactMap { $0 }.count),
            "deletion": "Active"
        ]
    }

    static func write(jobID: String, type: String, before: [String: String], after: [String: String], completion: ((Error?) -> Void)? = nil) {
        guard let actorID = Auth.auth().currentUser?.uid else {
            completion?(NSError(domain: "JobAudit", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sign in is required to record job history."]))
            return
        }
        Firestore.firestore().collection("jobs").document(jobID).collection("events").document().setData([
            "actorID": actorID,
            "occurredAt": FieldValue.serverTimestamp(),
            "type": type,
            "before": before,
            "after": after
        ]) { completion?($0) }
    }
}

@MainActor
final class JobAuditTimelineModel: ObservableObject {
    @Published var events: [JobAuditEvent] = []
    @Published var errorMessage: String?
    @Published var isLoading = false
    private var cursor: DocumentSnapshot?
    private var hasMore = true

    func load(jobID: String, reset: Bool = false) {
        guard !isLoading, reset || hasMore else { return }
        if reset { cursor = nil; hasMore = true }
        isLoading = true
        var query: Query = Firestore.firestore().collection("jobs").document(jobID).collection("events")
            .order(by: "occurredAt", descending: true).limit(to: JobAudit.pageSize)
        if let cursor { query = query.start(afterDocument: cursor) }
        query.getDocuments(source: .default) { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                if let error { self.errorMessage = error.localizedDescription; return }
                let docs = snapshot?.documents ?? []
                let decoded = docs.compactMap(Self.decode)
                self.events = reset ? decoded : self.events + decoded
                self.cursor = docs.last
                self.hasMore = docs.count == JobAudit.pageSize
            }
        }
    }

    private static func decode(_ doc: QueryDocumentSnapshot) -> JobAuditEvent? {
        let data = doc.data()
        guard let actor = data["actorID"] as? String, let type = data["type"] as? String else { return nil }
        return JobAuditEvent(id: doc.documentID, actorID: actor,
                             occurredAt: (data["occurredAt"] as? Timestamp)?.dateValue(), type: type,
                             before: data["before"] as? [String: String] ?? [:],
                             after: data["after"] as? [String: String] ?? [:],
                             isPending: doc.metadata.hasPendingWrites)
    }
}

struct JobAuditTimeline: View {
    let jobID: String
    let displayName: (String) -> String
    @StateObject private var model = JobAuditTimelineModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline").font(.headline)
            if model.events.isEmpty && !model.isLoading { Text("No history yet.").foregroundStyle(.secondary) }
            ForEach(model.events) { event in
                VStack(alignment: .leading, spacing: 3) {
                    Text(label(event)).font(.subheadline).fontWeight(.medium)
                    HStack {
                        Text(event.occurredAt?.formatted(date: .abbreviated, time: .shortened) ?? "Waiting for server time")
                        if event.isPending { Text("Offline").foregroundStyle(.orange) }
                    }.font(.caption).foregroundStyle(.secondary)
                }
            }
            if model.isLoading { ProgressView() }
            if let message = model.errorMessage, model.events.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
            if !model.events.isEmpty {
                Button("Load earlier activity") { model.load(jobID: jobID) }.disabled(model.isLoading)
            }
        }
        .onAppear { model.load(jobID: jobID, reset: true) }
    }

    private func label(_ event: JobAuditEvent) -> String {
        let actor = displayName(event.actorID)
        let keys = ["status", "assignment", "schedule", "notes", "attachments", "deletion"]
        if let key = keys.first(where: { event.before[$0] != event.after[$0] }) {
            return "\(key.capitalized) changed from \(event.before[key] ?? "None") to \(event.after[key] ?? "None") by \(actor)"
        }
        return "\(event.type.replacingOccurrences(of: "_", with: " ").capitalized) by \(actor)"
    }
}
