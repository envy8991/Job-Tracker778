import ActivityKit
import Foundation
import WidgetKit

@MainActor
final class JobSystemExperienceService {
    static let shared = JobSystemExperienceService()

    static let appGroupIdentifier = "group.com.quinton.Job-Tracker-CS25"
    static let snapshotKey = "com.jobtracker.systemExperiences.snapshot"

    private var activeActivityID: String?

    private init() {}

    func publish(snapshot: JobSystemSnapshot) {
        persist(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await updateLiveActivity(using: snapshot.activeJob ?? snapshot.nextJob, monitoring: snapshot.arrivalMonitoring) }
    }

    func publish(jobs: [Job], selectedDate: Date, distanceStrings: [String: String] = [:]) {
        let dayJobs = jobs
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
        let items = dayJobs.map { JobSystemSnapshot.Item(job: $0, distanceText: distanceStrings[$0.id]) }
        let pending = items.filter(\.isPending)
        let completed = max(0, items.count - pending.count)
        let existingMonitoring = loadSnapshot()?.arrivalMonitoring ?? .inactive
        let snapshot = JobSystemSnapshot(
            generatedAt: Date(),
            selectedDate: selectedDate,
            totalCount: items.count,
            pendingCount: pending.count,
            completedCount: completed,
            nextJob: pending.first ?? items.first,
            activeJob: pending.first,
            arrivalMonitoring: existingMonitoring,
            jobs: Array(items.prefix(8))
        )
        publish(snapshot: snapshot)
    }

    func publishStatusChange(job: Job, status: String, distanceText: String? = nil) {
        var item = JobSystemSnapshot.Item(job: job, distanceText: distanceText)
        item.status = CrewPosition.statusDisplayName(from: status)
        Task { await updateLiveActivity(using: item, monitoring: loadSnapshot()?.arrivalMonitoring ?? .inactive) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func publishArrivalMonitoring(state: JobSystemSnapshot.ArrivalMonitoring.State, message: String) {
        let monitoring = JobSystemSnapshot.ArrivalMonitoring(state: state, message: message)
        var snapshot = loadSnapshot() ?? .empty
        snapshot.arrivalMonitoring = monitoring
        snapshot.generatedAt = Date()
        persist(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await updateLiveActivity(using: snapshot.activeJob ?? snapshot.nextJob, monitoring: monitoring) }
    }

    func clearSensitiveSystemExperienceData() {
        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
        defaults.removeObject(forKey: Self.snapshotKey)
        defaults.synchronize()
        WidgetCenter.shared.reloadAllTimelines()
        Task {
            for activity in Activity<JobLiveActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            activeActivityID = nil
        }
    }

    private func loadSnapshot() -> JobSystemSnapshot? {
        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
        guard let data = defaults.data(forKey: Self.snapshotKey) else { return nil }
        return try? JSONDecoder.jobTrackerSystemExperiences.decode(JobSystemSnapshot.self, from: data)
    }

    private func persist(_ snapshot: JobSystemSnapshot) {
        guard let data = try? JSONEncoder.jobTrackerSystemExperiences.encode(snapshot) else { return }
        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
        defaults.set(data, forKey: Self.snapshotKey)
    }

    private func updateLiveActivity(
        using item: JobSystemSnapshot.Item?,
        monitoring: JobSystemSnapshot.ArrivalMonitoring = .inactive
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let existing = Activity<JobLiveActivityAttributes>.activities.first
        guard let item else {
            if let existing {
                await existing.end(nil, dismissalPolicy: .default)
            }
            activeActivityID = nil
            return
        }

        let state = JobLiveActivityAttributes.ContentState(
            status: item.status,
            etaText: nil,
            distanceText: item.distanceText,
            arrivalMonitoringState: monitoring.state.rawValue,
            arrivalMonitoringMessage: monitoring.message,
            lastUpdated: Date()
        )

        if let existing {
            await existing.update(ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60)))
            activeActivityID = existing.id
            return
        }

        let attributes = JobLiveActivityAttributes(
            jobID: item.id,
            shortAddress: item.shortAddress,
            assignment: item.assignment,
            jobNumber: item.jobNumber,
            scheduledDate: item.scheduledDate
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60)),
                pushType: nil
            )
            activeActivityID = activity.id
        } catch {
            #if DEBUG
            print("[SystemExperiences] Live Activity request failed: \(error.localizedDescription)")
            #endif
        }
    }
}

private extension JSONDecoder {
    static var jobTrackerSystemExperiences: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private extension JSONEncoder {
    static var jobTrackerSystemExperiences: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
