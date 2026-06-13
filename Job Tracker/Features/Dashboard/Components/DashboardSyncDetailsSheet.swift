import SwiftUI

struct DashboardSyncDetailsSheet: View {
    @ObservedObject var jobsViewModel: JobsViewModel
    @ObservedObject private var photoUploadQueue = JobPhotoUploadQueue.shared

    private var pendingJobCount: Int { jobsViewModel.pendingWriteIDs.count }
    private var pendingJobLabel: String {
        let suffix = pendingJobCount == 1 ? "" : "s"
        return "\(pendingJobCount) job change\(suffix) waiting to sync"
    }
    private var activePhotoStatuses: [JobPhotoUploadStatus] { photoUploadQueue.uploadStatuses }
    private var failedPhotoStatuses: [JobPhotoUploadStatus] {
        activePhotoStatuses.filter { $0.state == .failed }
    }
    private var locallyStoredPhotoStatuses: [JobPhotoUploadStatus] {
        activePhotoStatuses.filter { $0.state == .storedLocally }
    }

    var body: some View {
        NavigationStack {
            List {
                if pendingJobCount > 0 {
                    Section("Job changes") {
                        Label(pendingJobLabel, systemImage: "doc.badge.clock")
                            .foregroundStyle(.primary)
                    }
                }

                Section("Photo uploads") {
                    if activePhotoStatuses.isEmpty {
                        Label("No photo uploads waiting", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activePhotoStatuses) { status in
                            DashboardPhotoUploadStatusRow(status: status)
                        }
                    }
                }

                if !failedPhotoStatuses.isEmpty || !locallyStoredPhotoStatuses.isEmpty {
                    Section("Recovery") {
                        Button {
                            photoUploadQueue.retryFailedUploads()
                        } label: {
                            Label("Retry all photo uploads", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .navigationTitle("Sync Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct DashboardPhotoUploadStatusRow: View {
    let status: JobPhotoUploadStatus
    @ObservedObject private var photoUploadQueue = JobPhotoUploadQueue.shared

    private var iconName: String {
        switch status.state {
        case .pending:
            return "clock"
        case .uploading:
            return "arrow.up.circle.fill"
        case .waitingForNetwork:
            return "wifi.slash"
        case .retrying:
            return "arrow.clockwise.circle"
        case .failed:
            return "exclamationmark.triangle.fill"
        case .storedLocally:
            return "externaldrive.badge.checkmark"
        }
    }

    private var iconColor: Color {
        switch status.state {
        case .failed:
            return .orange
        case .uploading:
            return .accentColor
        case .waitingForNetwork, .storedLocally:
            return .secondary
        default:
            return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.xs) {
            HStack(alignment: .top, spacing: JTSpacing.sm) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.title)
                        .font(.subheadline.weight(.semibold))
                    Text(status.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if status.attempts > 0 {
                        Text("Attempts: \(status.attempts)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }

            if status.state == .failed || status.state == .storedLocally {
                HStack {
                    Button("Retry") { photoUploadQueue.retryUpload(id: status.id) }
                        .buttonStyle(.borderedProminent)
                    Button("Discard") { photoUploadQueue.discardUpload(id: status.id) }
                        .buttonStyle(.bordered)
                }
                .font(.caption.weight(.semibold))
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, JTSpacing.xs)
    }
}
