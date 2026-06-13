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

struct JobLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String
        var etaText: String?
        var distanceText: String?
        var arrivalMonitoringState: String?
        var arrivalMonitoringMessage: String?
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
        if Date().timeIntervalSince(snapshot.generatedAt) > 6 * 60 * 60 {
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

    private var completionRatio: Double {
        guard entry.snapshot.totalCount > 0 else { return 0 }
        return Double(entry.snapshot.completedCount) / Double(entry.snapshot.totalCount)
    }

    private var pendingLabel: String {
        entry.snapshot.pendingCount == 1 ? "1 pending" : "\(entry.snapshot.pendingCount) pending"
    }

    private var dateLabel: String {
        if Calendar.current.isDateInToday(entry.snapshot.selectedDate) {
            return "Today"
        }
        return entry.snapshot.selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            accessoryBody
        case .systemMedium:
            mediumBody
        default:
            smallBody
        }
    }

    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(entry.snapshot.pendingCount)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("left")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            progressBar
            if let next = entry.snapshot.nextJob {
                nextStopSummary(next)
            } else {
                emptyState
            }
        }
        .widgetURL(URL(string: "jobtracker://dashboard"))
    }

    private var mediumBody: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                header
                Text(pendingLabel)
                    .font(.title2.bold())
                Text("\(entry.snapshot.completedCount) done • \(entry.snapshot.totalCount) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                progressBar
                arrivalMonitoringBadge
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                if let next = entry.snapshot.nextJob {
                    Text("NEXT STOP")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    nextStopSummary(next)
                    let upcoming = Array(entry.snapshot.jobs.dropFirst().prefix(2))
                    if !upcoming.isEmpty {
                        Divider()
                        ForEach(upcoming) { upcomingJob in
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.caption2)
                                Text(upcomingJob.shortAddress)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                if let distance = upcomingJob.distanceText {
                                    Text(distance)
                                        .font(.caption2.bold())
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    jobActionLinks(for: next, includeDashboard: true)
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .widgetURL(URL(string: "jobtracker://dashboard"))
    }

    private var accessoryBody: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.snapshot.pendingCount == 0 ? "checkmark.seal.fill" : "briefcase.fill")
            VStack(alignment: .leading, spacing: 1) {
                Text("\(dateLabel): \(pendingLabel)")
                    .font(.headline)
                Text(entry.snapshot.nextJob?.shortAddress ?? "All caught up")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "jobtracker://dashboard"))
    }

    private var header: some View {
        HStack(spacing: 6) {
            Label(dateLabel, systemImage: "calendar.badge.clock")
                .font(.caption.bold())
            Spacer(minLength: 0)
            Text(entry.snapshot.generatedAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.22))
                Capsule()
                    .fill(entry.snapshot.pendingCount == 0 ? .green : .orange)
                    .frame(width: max(6, proxy.size.width * completionRatio))
            }
        }
        .frame(height: 6)
        .accessibilityLabel("\(entry.snapshot.completedCount) of \(entry.snapshot.totalCount) jobs complete")
    }

    @ViewBuilder
    private var arrivalMonitoringBadge: some View {
        switch entry.snapshot.arrivalMonitoring.state {
        case .active:
            Label("Arrival alerts on", systemImage: "location.badge.checkmark")
                .foregroundStyle(.green)
                .font(.caption2.bold())
        case .warning, .error:
            Label("Check arrival alerts", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.caption2.bold())
        case .inactive:
            EmptyView()
        }
    }

    private func nextStopSummary(_ job: JobSystemSnapshot.Item) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(job.shortAddress)
                .font(.headline)
                .lineLimit(2)
            Text([job.assignment, job.distanceText, job.jobNumber].compactMap { $0 }.joined(separator: " • "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("All caught up")
                .font(.headline)
            Text("No pending jobs for this day")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct CurrentJobWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: JobSnapshotEntry

    private var job: JobSystemSnapshot.Item? {
        entry.snapshot.activeJob ?? entry.snapshot.nextJob
    }

    private var statusColor: Color {
        switch entry.snapshot.arrivalMonitoring.state {
        case .active: return .green
        case .warning: return .yellow
        case .error: return .red
        case .inactive: return job?.isPending == true ? .orange : .blue
        }
    }

    var body: some View {
        Group {
            if let job {
                switch family {
                case .accessoryRectangular:
                    accessoryBody(job)
                case .systemMedium:
                    mediumBody(job)
                default:
                    smallBody(job)
                }
            } else {
                noJobBody
            }
        }
    }

    private func smallBody(_ job: JobSystemSnapshot.Item) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            statusPill(job)
            Text(job.shortAddress)
                .font(.headline)
                .lineLimit(2)
            Text(job.assignment ?? job.jobNumber ?? "Open Job Tracker for details")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let fieldSummary = fieldSummary(for: job) {
                Text(fieldSummary)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let notes = trimmed(job.notes) {
                Text(notes)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            jobActionLinks(for: job, includeDashboard: false)
            footer(job)
        }
        .widgetURL(URL(string: "jobtracker://job?id=\(job.id)"))
    }

    private func mediumBody(_ job: JobSystemSnapshot.Item) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                statusPill(job)
                Text(job.shortAddress)
                    .font(.title3.bold())
                    .lineLimit(2)
                Text([job.assignment, job.jobNumber].compactMap { $0 }.joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let fieldSummary = fieldSummary(for: job) {
                    Label(fieldSummary, systemImage: "ruler")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let notes = trimmed(job.notes) {
                    Label(notes, systemImage: "note.text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if let materials = trimmed(job.materialsUsed) {
                    Label(materials, systemImage: "shippingbox")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                footer(job)
                jobActionLinks(for: job, includeDashboard: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                metricTile(icon: "point.topleft.down.curvedto.point.bottomright.up", title: "Distance", value: job.distanceText ?? "Open map")
                metricTile(icon: "clock", title: "Scheduled", value: job.scheduledDate.formatted(.dateTime.hour().minute()))
                metricTile(icon: "bell.badge", title: "Alerts", value: alertSummary)
                if let placement = trimmed(job.jobPlacement) {
                    metricTile(icon: "wrench.and.screwdriver", title: "Type", value: placement)
                }
            }
            .frame(width: 125)
        }
        .widgetURL(URL(string: "jobtracker://job?id=\(job.id)"))
    }

    private func accessoryBody(_ job: JobSystemSnapshot.Item) -> some View {
        HStack(spacing: 8) {
            Image(systemName: entry.snapshot.arrivalMonitoring.state == .active ? "location.badge.checkmark" : "location.fill")
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(job.shortAddress)
                    .font(.headline)
                    .lineLimit(1)
                Text([job.status, job.distanceText].compactMap { $0 }.joined(separator: " • "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .widgetURL(URL(string: "jobtracker://job?id=\(job.id)"))
    }

    private func statusPill(_ job: JobSystemSnapshot.Item) -> some View {
        Label(job.status, systemImage: job.isPending ? "figure.walk" : "checkmark.circle.fill")
            .font(.caption.bold())
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.16), in: Capsule())
    }

    private func metricTile(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(statusColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.bold())
                    .lineLimit(1)
            }
        }
    }

    private func footer(_ job: JobSystemSnapshot.Item) -> some View {
        Label(alertSummary, systemImage: entry.snapshot.arrivalMonitoring.state == .inactive ? "arrow.up.forward.app" : "location.badge.checkmark")
            .font(.caption2.bold())
            .foregroundStyle(statusColor)
            .lineLimit(1)
    }

    private var alertSummary: String {
        switch entry.snapshot.arrivalMonitoring.state {
        case .active: return "Arrival alerts on"
        case .warning: return "Needs attention"
        case .error: return "Alert issue"
        case .inactive: return "Tap for job"
        }
    }

    private var noJobBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(.green)
            Text("All caught up")
                .font(.headline)
            Text("No active or pending job")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text("Updated \(entry.snapshot.generatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "jobtracker://dashboard"))
    }
}


private func jobActionLinks(for job: JobSystemSnapshot.Item, includeDashboard: Bool) -> some View {
    HStack(spacing: 6) {
        Link(destination: jobDeepLink(for: job)) {
            actionChip(title: "Details", systemImage: "doc.text.magnifyingglass")
        }
        Link(destination: directionsURL(for: job)) {
            actionChip(title: "Route", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
        }
        if includeDashboard {
            Link(destination: URL(string: "jobtracker://dashboard")!) {
                actionChip(title: "Board", systemImage: "rectangle.grid.2x2")
            }
        }
    }
    .buttonStyle(.plain)
}

private func actionChip(title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
        .font(.caption2.bold())
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule())
}

private func jobDeepLink(for job: JobSystemSnapshot.Item) -> URL {
    URL(string: "jobtracker://job?id=\(job.id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? job.id)")!
}

private func directionsURL(for job: JobSystemSnapshot.Item) -> URL {
    let encodedAddress = job.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? job.address
    return URL(string: "http://maps.apple.com/?daddr=\(encodedAddress)&dirflg=d")!
}

private func fieldSummary(for job: JobSystemSnapshot.Item) -> String? {
    var pieces: [String] = []
    if let can = trimmed(job.canFootage) { pieces.append("CAN \(can)") }
    if let nid = trimmed(job.nidFootage) { pieces.append("NID \(nid)") }
    return pieces.isEmpty ? nil : pieces.joined(separator: " • ")
}

private func trimmed(_ value: String?) -> String? {
    let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return text.isEmpty ? nil : text
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
                    VStack(alignment: .leading, spacing: 3) {
                        Label(context.state.status, systemImage: liveActivityIcon(for: context))
                            .font(.caption.bold())
                        Text(context.attributes.scheduledDate, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(context.state.distanceText ?? context.state.etaText ?? "Active")
                            .font(.caption.bold())
                        Text(context.state.lastUpdated, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.shortAddress)
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(context.attributes.assignment ?? context.attributes.jobNumber ?? "Open Job Tracker")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Label(liveActivityAlertText(for: context), systemImage: "bell.badge")
                                .font(.caption2.bold())
                                .foregroundStyle(liveActivityTint(for: context))
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: liveActivityIcon(for: context))
                    .foregroundStyle(liveActivityTint(for: context))
            } compactTrailing: {
                Text(context.state.distanceText ?? String(context.state.status.prefix(3)))
                    .font(.caption2.bold())
                    .lineLimit(1)
            } minimal: {
                Image(systemName: liveActivityIcon(for: context))
                    .foregroundStyle(liveActivityTint(for: context))
            }
            .widgetURL(URL(string: "jobtracker://job?id=\(context.attributes.jobID)"))
        }
    }
}

struct LiveActivityLockScreenView: View {
    let context: ActivityViewContext<JobLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: liveActivityIcon(for: context))
                    .font(.title2)
                    .foregroundStyle(liveActivityTint(for: context))
                    .frame(width: 34, height: 34)
                    .background(liveActivityTint(for: context).opacity(0.16), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(context.attributes.shortAddress)
                        .font(.headline)
                        .lineLimit(1)
                    Text(routeStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(context.state.status)
                    .font(.caption.bold())
                    .foregroundStyle(liveActivityTint(for: context))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(liveActivityTint(for: context).opacity(0.16), in: Capsule())
            }

            HStack(spacing: 10) {
                Label(context.attributes.scheduledDate.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                Label(liveActivityAlertText(for: context), systemImage: "bell.badge")
                Spacer(minLength: 0)
                Text("Updated \(context.state.lastUpdated.formatted(date: .omitted, time: .shortened))")
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
        }
        .padding()
        .widgetURL(URL(string: "jobtracker://job?id=\(context.attributes.jobID)"))
    }

    private var routeStatusText: String {
        let text = [context.attributes.assignment, context.state.distanceText, context.state.etaText]
            .compactMap { $0 }
            .joined(separator: " • ")
        return text.isEmpty ? context.state.status : text
    }
}

private func liveActivityTint(for context: ActivityViewContext<JobLiveActivityAttributes>) -> Color {
    switch context.state.arrivalMonitoringState {
    case "active": return .green
    case "warning": return .yellow
    case "error": return .red
    default: return .blue
    }
}

private func liveActivityIcon(for context: ActivityViewContext<JobLiveActivityAttributes>) -> String {
    switch context.state.arrivalMonitoringState {
    case "active": return "location.badge.checkmark"
    case "warning", "error": return "exclamationmark.triangle.fill"
    default: return "location.north.line.fill"
    }
}

private func liveActivityAlertText(for context: ActivityViewContext<JobLiveActivityAttributes>) -> String {
    guard let message = context.state.arrivalMonitoringMessage, !message.isEmpty else {
        return "Tap for job"
    }
    return message
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
