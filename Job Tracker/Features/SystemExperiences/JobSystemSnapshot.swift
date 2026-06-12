import Foundation

struct JobSystemSnapshot: Codable, Hashable {
    struct Item: Codable, Hashable, Identifiable {
        var id: String
        var address: String
        var shortAddress: String
        var status: String
        var assignment: String?
        var jobNumber: String?
        var notes: String?
        var scheduledDate: Date
        var distanceText: String?

        var isPending: Bool {
            status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "pending"
        }
    }

    var generatedAt: Date
    var selectedDate: Date
    var totalCount: Int
    var pendingCount: Int
    var completedCount: Int
    var nextJob: Item?
    var activeJob: Item?
    var jobs: [Item]

    static let empty = JobSystemSnapshot(
        generatedAt: Date(),
        selectedDate: Date(),
        totalCount: 0,
        pendingCount: 0,
        completedCount: 0,
        nextJob: nil,
        activeJob: nil,
        jobs: []
    )
}

extension JobSystemSnapshot.Item {
    init(job: Job, distanceText: String? = nil) {
        self.init(
            id: job.id,
            address: job.address,
            shortAddress: job.shortAddress,
            status: CrewPosition.statusDisplayName(from: job.status),
            assignment: job.assignments,
            jobNumber: job.jobNumber,
            notes: job.notes,
            scheduledDate: job.date,
            distanceText: distanceText
        )
    }
}
