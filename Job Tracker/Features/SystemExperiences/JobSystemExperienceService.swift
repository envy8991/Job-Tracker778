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
        Task { await updateLiveActivity(using: snapshot.activeJob ?? snapshot.nextJob) }
    }

    func publish(jobs: [Job], selectedDate: Date, distanceStrings: [String: String] = [:]) {
        let dayJobs = jobs
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
        let items = dayJobs.map { JobSystemSnapshot.Item(job: $0, distanceText: distanceStrings[$0.id]) }
        let pending = items.filter(\.isPending)
        let completed = max(0, items.count - pending.count)
        let snapshot = JobSystemSnapshot(
            generatedAt: Date(),
            selectedDate: selectedDate,
            totalCount: items.count,
            pendingCount: pending.count,
            completedCount: completed,
            nextJob: pending.first ?? items.first,
            activeJob: pending.first,
            jobs: Array(items.prefix(8))
        )
        publish(snapshot: snapshot)
    }

    func publishStatusChange(job: Job, status: String, distanceText: String? = nil) {
        var item = JobSystemSnapshot.Item(job: job, distanceText: distanceText)
        item.status = CrewPosition.statusDisplayName(from: status)
        Task { await updateLiveActivity(using: item) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func persist(_ snapshot: JobSystemSnapshot) {
        guard let data = try? JSONEncoder.jobTrackerSystemExperiences.encode(snapshot) else { return }
        let defaults = UserDefaults(suiteName: Self.appGroupIdentifier) ?? .standard
        defaults.set(data, forKey: Self.snapshotKey)
    }

    private func updateLiveActivity(using item: JobSystemSnapshot.Item?) async {
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

private extension JSONEncoder {
    static var jobTrackerSystemExperiences: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
