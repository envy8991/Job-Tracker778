import ActivityKit
import Foundation

struct JobLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var etaText: String?
        var distanceText: String?
        var lastUpdated: Date
    }

    var jobID: String
    var shortAddress: String
    var assignment: String?
    var jobNumber: String?
    var scheduledDate: Date
}
