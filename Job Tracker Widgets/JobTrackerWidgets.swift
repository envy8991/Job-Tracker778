import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

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

private enum SharedStore {
    static let appGroupIdentifier = "group.com.quinton.Job-Tracker-CS25"
    static let snapshotKey = "com.jobtracker.systemExperiences.snapshot"

    static func loadSnapshot() -> JobSystemSnapshot {
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        guard let data = defaults.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder.jobTrackerSystemExperiences.decode(JobSystemSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }
}

struct JobSnapshotEntry: TimelineEntry {
    var date: Date
    var snapshot: JobSystemSnapshot
}

struct JobSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> JobSnapshotEntry {
        JobSnapshotEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (JobSnapshotEntry) -> Void) {
        completion(JobSnapshotEntry(date: Date(), snapshot: SharedStore.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JobSnapshotEntry>) -> Void) {
        let entry = JobSnapshotEntry(date: Date(), snapshot: SharedStore.loadSnapshot())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct TodayJobsWidget: Widget {
    let kind = "TodayJobsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JobSnapshotProvider()) { entry in
            TodayJobsWidgetView(entry: entry)
                .containerBackground(.blue.gradient, for: .widget)
        }
        .configurationDisplayName("Today's Jobs")
        .description("See today's job count, next stop, and pending work.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct CurrentJobWidget: Widget {
    let kind = "CurrentJobWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JobSnapshotProvider()) { entry in
            CurrentJobWidgetView(entry: entry)
                .containerBackground(.indigo.gradient, for: .widget)
        }
        .configurationDisplayName("Current Job")
        .description("Keep the current or next pending job on your Home Screen and Lock Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct TodayJobsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: JobSnapshotEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessoryBody
        default:
            VStack(alignment: .leading, spacing: 8) {
                Label("Today", systemImage: "calendar")
                    .font(.caption.bold())
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.snapshot.pendingCount)")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                    Text("pending")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                if let next = entry.snapshot.nextJob {
                    Divider()
                    Text(next.shortAddress)
                        .font(.headline)
                        .lineLimit(1)
                    Text(next.assignment ?? next.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Spacer()
                    Text("No jobs scheduled")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .widgetURL(URL(string: "jobtracker://dashboard"))
        }
    }

    private var accessoryBody: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Today")
                Text("\(entry.snapshot.pendingCount) pending")
            }
            Spacer()
            Image(systemName: "briefcase.fill")
        }
        .widgetURL(URL(string: "jobtracker://dashboard"))
    }
}

struct CurrentJobWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: JobSnapshotEntry

    private var job: JobSystemSnapshot.Item? {
        entry.snapshot.activeJob ?? entry.snapshot.nextJob
    }

    var body: some View {
        Group {
            if let job {
                VStack(alignment: .leading, spacing: 8) {
                    Label(job.status, systemImage: job.isPending ? "location.fill" : "checkmark.circle.fill")
                        .font(.caption.bold())
                    Text(job.shortAddress)
                        .font(family == .systemSmall ? .headline : .title3.bold())
                        .lineLimit(2)
                    if family != .accessoryRectangular {
                        Text([job.assignment, job.distanceText].compactMap { $0 }.joined(separator: " • "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text("Open Job Tracker")
                        .font(.caption2.bold())
                        .foregroundStyle(.tint)
                }
                .widgetURL(URL(string: "jobtracker://job?id=\(job.id)"))
            } else {
                VStack(alignment: .leading) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("All caught up")
                        .font(.headline)
                    Text("No active job")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .widgetURL(URL(string: "jobtracker://dashboard"))
            }
        }
    }
}

struct JobLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: JobLiveActivityAttributes.self) { context in
            LiveActivityLockScreenView(context: context)
                .activityBackgroundTint(.blue.opacity(0.2))
                .activitySystemActionForegroundColor(.blue)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.status, systemImage: "briefcase.fill")
                        .font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.distanceText ?? context.state.etaText ?? "Active")
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.shortAddress)
                            .font(.headline)
                        Text(context.attributes.assignment ?? context.attributes.jobNumber ?? "Open Job Tracker")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "briefcase.fill")
            } compactTrailing: {
                Text(context.state.status.prefix(1))
            } minimal: {
                Image(systemName: "location.fill")
            }
            .widgetURL(URL(string: "jobtracker://job?id=\(context.attributes.jobID)"))
        }
    }
}

struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<JobLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.north.line.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.shortAddress)
                    .font(.headline)
                    .lineLimit(1)
                Text([context.attributes.assignment, context.state.distanceText, context.state.etaText]
                    .compactMap { $0 }
                    .joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(context.state.status)
                .font(.caption.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.thinMaterial, in: Capsule())
        }
        .padding()
        .widgetURL(URL(string: "jobtracker://job?id=\(context.attributes.jobID)"))
    }
}

@main
struct JobTrackerWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayJobsWidget()
        CurrentJobWidget()
        JobLiveActivityWidget()
    }
}

private extension JSONDecoder {
    static var jobTrackerSystemExperiences: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
