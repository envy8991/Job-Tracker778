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
        var materialsUsed: String?
        var nidFootage: String?
        var canFootage: String?
        var jobPlacement: String?
        var scheduledDate: Date
        var distanceText: String?

        var isPending: Bool {
            status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "pending"
        }
    }

    struct ArrivalMonitoring: Codable, Hashable {
        enum State: String, Codable, Hashable {
            case inactive
            case active
            case warning
            case error
        }

        var state: State
        var message: String

        static let inactive = ArrivalMonitoring(
            state: .inactive,
            message: "Arrival monitoring is off."
        )
    }

    var generatedAt: Date
    var selectedDate: Date
    var totalCount: Int
    var pendingCount: Int
    var completedCount: Int
    var nextJob: Item?
    var activeJob: Item?
    var arrivalMonitoring: ArrivalMonitoring
    var jobs: [Item]

    static let empty = JobSystemSnapshot(
        generatedAt: Date(),
        selectedDate: Date(),
        totalCount: 0,
        pendingCount: 0,
        completedCount: 0,
        nextJob: nil,
        activeJob: nil,
        arrivalMonitoring: .inactive,
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
            materialsUsed: job.materialsUsed,
            nidFootage: job.nidFootage,
            canFootage: job.canFootage,
            jobPlacement: job.jobPlacement,
            scheduledDate: job.date,
            distanceText: distanceText
        )
    }
}
