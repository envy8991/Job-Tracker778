import SwiftUI

struct DashboardJobSectionsView: View {
    let sections: DashboardViewModel.JobSections
    let statusOptions: [String]
    let nearestJobID: String?
    let distanceStrings: [String: String]
    let onJobTap: (Job) -> Void
    let onMapTap: (Job) -> Void
    let onStatusChange: (Job, String) -> Void
    let onDelete: (Job) -> Void
    let onShare: (Job) -> Void

    var body: some View {
        if sections.isEmpty {
            VStack { // keep centered width for layout parity
                Text("No jobs for this date")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, JTSpacing.lg)
                    .padding(.vertical, JTSpacing.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, JTSpacing.xl)
        } else {
            ScrollView {
                LazyVStack(spacing: JTSpacing.lg) {
                    if !sections.notCompleted.isEmpty {
                        DashboardJobSectionHeader(title: "Not Completed")
                        ForEach(sections.notCompleted, id: \.id) { job in
                            JobCard(
                                job: job,
                                isHere: job.id == nearestJobID,
                                statusOptions: statusOptions,
                                onMapTap: { onMapTap(job) },
                                onStatusChange: { newStatus in onStatusChange(job, newStatus) },
                                onDelete: { onDelete(job) },
                                onShare: { onShare(job) },
                                distanceString: distanceStrings[job.id]
                            )
                            .id("\(job.id)_\(job.status)")
                            .onTapGesture { onJobTap(job) }
                        }
                    }

                    if !sections.completed.isEmpty {
                        DashboardJobSectionHeader(title: "Completed")
                            .padding(.top, JTSpacing.sm)
                        ForEach(sections.completed, id: \.id) { job in
                            JobCard(
                                job: job,
                                isHere: job.id == nearestJobID,
                                statusOptions: statusOptions,
                                onMapTap: { onMapTap(job) },
                                onStatusChange: { newStatus in onStatusChange(job, newStatus) },
                                onDelete: { onDelete(job) },
                                onShare: { onShare(job) },
                                distanceString: distanceStrings[job.id]
                            )
                            .id("\(job.id)_\(job.status)")
                            .onTapGesture { onJobTap(job) }
                        }
                    }
                }
                .padding(JTSpacing.lg)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct DashboardJobSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(JTTypography.headline)
            .foregroundStyle(Color.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, JTSpacing.sm)
    }
}

struct JobCard: View {
    let job: Job
    let isHere: Bool
    let statusOptions: [String]
    let onMapTap: () -> Void
    let onStatusChange: (String) -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    let distanceString: String?

    @State private var showDeleteConfirm = false
    @State private var showStatusDialog = false
    @State private var showCustomStatusEntry = false
    @State private var customStatusText = ""

    init(
        job: Job,
        isHere: Bool,
        statusOptions: [String],
        onMapTap: @escaping () -> Void,
        onStatusChange: @escaping (String) -> Void,
        onDelete: @escaping () -> Void,
        onShare: @escaping () -> Void,
        distanceString: String?
    ) {
        self.job = job
        self.isHere = isHere
        self.statusOptions = statusOptions
        self.onMapTap = onMapTap
        self.onStatusChange = onStatusChange
        self.onDelete = onDelete
        self.onShare = onShare
        self.distanceString = distanceString
    }

    var body: some View {
        GlassCard(cornerRadius: JTShapes.cardCornerRadius) {
            VStack(alignment: .leading, spacing: JTSpacing.sm) {
                header
                details
                actions
            }
            .padding(JTSpacing.md)
        }
        .padding(.horizontal, JTSpacing.xs)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onShare) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button("Directions", systemImage: "map.fill", action: onMapTap)
            Button("Share", systemImage: "square.and.arrow.up", action: onShare)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .alert("Delete this job?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) { }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(houseNumber(job.address)), \(DateFormatter.localizedString(from: job.date, dateStyle: .medium, timeStyle: .none))")
        .accessibilityHint("Double tap for details. Swipe actions for share and delete.")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: JTSpacing.sm) {
            Image(systemName: "mappin.and.ellipse")
                .font(.callout)
                .foregroundStyle(JTColors.textSecondary)
            Text(job.address)
                .font(JTTypography.headline)
                .fontWeight(.semibold)
                .foregroundStyle(JTColors.textPrimary)
                .lineLimit(2)
                .truncationMode(.tail)
            Spacer(minLength: JTSpacing.sm)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: JTSpacing.xs) {
            HStack(spacing: JTSpacing.xs) {
                Text(job.date, style: .date)
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)

                if let distanceString, !distanceString.isEmpty {
                    Text("• \(distanceString)")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                        .accessibilityLabel("Distance \(distanceString)")
                }

                if isHere {
                    Text("Here")
                        .font(JTTypography.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, JTSpacing.sm)
                        .padding(.vertical, JTSpacing.xs)
                        .background(JTColors.success)
                        .foregroundStyle(JTColors.textPrimary)
                        .clipShape(Capsule())
                        .accessibilityLabel("You are here")
                }

                Spacer()
            }

            if let assignments = job.assignments?.trimmedNonEmpty {
                KeyValueRow(key: "Assignment:", value: assignments)
            }
            if let materials = job.materialsUsed?.trimmedNonEmpty {
                KeyValueRow(key: "Materials:", value: materials, lineLimit: 2)
            }
            if let notes = job.notes?.trimmedNonEmpty {
                KeyValueRow(key: "Notes:", value: notes, lineLimit: 2)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: JTSpacing.sm) {
            Text("Status:")
                .foregroundStyle(JTColors.textPrimary)

            Button {
                showStatusDialog = true
            } label: {
                Text(job.status)
                    .font(JTTypography.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, JTSpacing.md)
                    .padding(.vertical, JTSpacing.xs)
                    .background(statusBackground(for: job.status))
                    .foregroundStyle(JTColors.textPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .confirmationDialog("Change Status", isPresented: $showStatusDialog, titleVisibility: .visible) {
                ForEach(statusOptions, id: \.self) { option in
                    if option == "Custom" {
                        Button("Custom…") { showCustomStatusEntry = true }
                    } else {
                        Button(option) { onStatusChange(option) }
                    }
                }
            }
            .sheet(isPresented: $showCustomStatusEntry) {
                NavigationStack {
                    Form {
                        TextField("Status", text: $customStatusText)
                    }
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                let trimmed = customStatusText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty {
                                    onStatusChange(trimmed)
                                }
                                customStatusText = ""
                                showCustomStatusEntry = false
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                customStatusText = ""
                                showCustomStatusEntry = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }

            Spacer()

            Button(action: onMapTap) {
                Image(systemName: "map")
                    .imageScale(.medium)
                    .foregroundStyle(JTColors.textPrimary)
                    .padding(JTSpacing.xs)
                    .jtGlassBackground(shape: Circle(), strokeColor: JTColors.glassSoftStroke)
            }
            .accessibilityLabel("Directions")

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .imageScale(.medium)
                    .foregroundStyle(JTColors.textPrimary)
                    .padding(JTSpacing.xs)
                    .jtGlassBackground(shape: Circle(), strokeColor: JTColors.glassSoftStroke)
            }

            Button {
                showDeleteConfirm = true
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            } label: {
                Image(systemName: "trash")
                    .imageScale(.medium)
                    .foregroundColor(.red)
                    .padding(JTSpacing.xs)
                    .jtGlassBackground(shape: Circle(), strokeColor: JTColors.glassSoftStroke)
            }
        }
    }

    private func statusBackground(for status: String) -> Color {
        let s = status.lowercased()
        if s == "done" { return JTColors.success.opacity(0.7) }
        if s == "pending" { return JTColors.warning.opacity(0.6) }
        if s.contains("needs") { return JTColors.info.opacity(0.6) }
        return JTColors.glassHighlight
    }

    private func houseNumber(_ full: String) -> String {
        if let comma = full.firstIndex(of: ",") {
            return String(full[..<comma])
        }
        return full
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String
    var lineLimit: Int = 1

    var body: some View {
        HStack(alignment: .top, spacing: JTSpacing.xs) {
            Text(key)
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textSecondary)
            Text(value)
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textPrimary)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private struct DashboardJobSectionsPreviewContainer: View {
    let sections: DashboardViewModel.JobSections

    init() {
        let today = Date()
        let pending = Job(
            id: "1",
            address: "123 Main Street, Springfield, IL",
            date: today,
            status: "Pending",
            notes: "Call ahead",
            assignments: "12.3.2",
            materialsUsed: "Coax, Splitter"
        )
        let done = Job(
            id: "2",
            address: "456 Elm Road, Springfield, IL",
            date: today,
            status: "Done",
            notes: "Customer not home",
            hours: 2
        )
        sections = DashboardViewModel.JobSections(
            notCompleted: [pending],
            completed: [done],
            distanceStrings: ["1": "0.4 mi", "2": "1.2 mi"]
        )
    }

    var body: some View {
        DashboardJobSectionsView(
            sections: sections,
            statusOptions: DashboardViewModel().statusOptions,
            nearestJobID: sections.notCompleted.first?.id,
            distanceStrings: sections.distanceStrings,
            onJobTap: { _ in },
            onMapTap: { _ in },
            onStatusChange: { _, _ in },
            onDelete: { _ in },
            onShare: { _ in }
        )
        .background(JTGradients.background.ignoresSafeArea())
    }
}

#Preview("Job Sections – iPhone") {
    DashboardJobSectionsPreviewContainer()
}

#Preview("Job Sections – iPad") {
    DashboardJobSectionsPreviewContainer()
        .frame(maxWidth: 820)
}
