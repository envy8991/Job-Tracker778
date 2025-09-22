import SwiftUI

struct RecentCrewJobsView: View {
    @StateObject private var viewModel = RecentCrewJobsViewModel()
    @State private var selectedFilter: RecentCrewJobsViewModel.CrewRoleFilter = .all
    @State private var selectedJob: RecentCrewJob?

    var body: some View {
        ZStack {
            JTGradients.background(stops: 4).ignoresSafeArea()

            VStack(spacing: 0) {
                filterChips
                content
            }
        }
        .navigationTitle("Recent Crew Jobs")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.startListening() }
        .onDisappear { viewModel.stopListening() }
        .sheet(item: $selectedJob, onDismiss: { selectedJob = nil }) { job in
            RecentCrewJobDetailSheet(job: job)
        }
    }

    private var content: some View {
        let groups = viewModel.groups(for: selectedFilter)

        return Group {
            if viewModel.isLoading && viewModel.jobs.isEmpty {
                loadingState
            } else if let error = viewModel.errorMessage {
                stateView(
                    title: "Unable to load jobs",
                    systemImage: "exclamationmark.triangle",
                    message: error
                )
            } else if groups.isEmpty {
                stateView(
                    title: "No recent jobs",
                    systemImage: "tray",
                    message: "Crew submissions from the last 14 days will appear here once they’re completed."
                )
            } else {
                List {
                    ForEach(groups) { group in
                        NavigationLink {
                            RecentCrewJobGroupDetailView(group: group) { job in
                                selectedJob = job
                            }
                        } label: {
                            RecentCrewJobGroupRow(group: group)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: JTSpacing.sm) {
                ForEach(RecentCrewJobsViewModel.CrewRoleFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(JTTypography.subheadline)
                            .fontWeight(filter == selectedFilter ? .semibold : .regular)
                            .padding(.vertical, JTSpacing.xs)
                            .padding(.horizontal, JTSpacing.md)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(filter == selectedFilter ? JTColors.accent.opacity(0.9) : JTColors.glassHighlight)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(filter == selectedFilter ? JTColors.accent : JTColors.glassSoftStroke, lineWidth: 1)
                            )
                            .foregroundStyle(JTColors.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, JTSpacing.md)
            .padding(.vertical, JTSpacing.sm)
        }
    }

    private var loadingState: some View {
        VStack(spacing: JTSpacing.md) {
            ProgressView("Loading recent jobs…")
                .tint(JTColors.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, JTSpacing.xl)
    }

    private func stateView(title: String, systemImage: String, message: String) -> some View {
        VStack(spacing: JTSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(JTColors.textMuted)

            Text(title)
                .font(JTTypography.headline)
                .foregroundStyle(JTColors.textPrimary)

            Text(message)
                .font(JTTypography.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(JTColors.textSecondary)
                .padding(.horizontal, JTSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, JTSpacing.xl)
    }
}

private struct RecentCrewJobGroupRow: View {
    let group: RecentCrewJobGroup

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.title)
                    .font(JTTypography.subheadline.weight(.semibold))
                    .foregroundStyle(JTColors.textPrimary)
                Spacer()
                if let date = group.latestFormattedDate {
                    Text(date)
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                }
            }

            Text(group.subtitle)
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textSecondary)
                .lineLimit(1)

            HStack(spacing: JTSpacing.xs) {
                if let role = group.primaryRole {
                    CrewJobChip(text: role, tint: JTColors.accent)
                }
                CrewJobChip(text: group.latestStatus, tint: statusTint(for: group.latestStatus))
                if group.isMultiEntry {
                    CrewJobChip(text: "Multiple entries", tint: JTColors.info)
                }
            }
        }
        .padding(.vertical, JTSpacing.sm)
    }
}

private struct RecentCrewJobGroupDetailView: View {
    let group: RecentCrewJobGroup
    let onSelectJob: (RecentCrewJob) -> Void

    var body: some View {
        List {
            Section {
                RecentCrewJobGroupSummary(group: group)
                    .listRowInsets(EdgeInsets(top: JTSpacing.sm, leading: JTSpacing.md, bottom: JTSpacing.sm, trailing: JTSpacing.md))
                    .listRowBackground(Color.clear)
            }

            Section(group.entryCount == 1 ? "Submission" : "Submissions") {
                ForEach(group.jobs) { job in
                    Button {
                        onSelectJob(job)
                    } label: {
                        RecentCrewJobRow(job: job)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(JTGradients.background(stops: 4).ignoresSafeArea())
        .navigationTitle(group.title)
    }
}

private struct RecentCrewJobGroupSummary: View {
    let group: RecentCrewJobGroup

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                Text(group.title)
                    .font(JTTypography.title3)
                    .foregroundStyle(JTColors.textPrimary)

                Text(group.subtitle)
                    .font(JTTypography.subheadline)
                    .foregroundStyle(JTColors.textSecondary)

                HStack(spacing: JTSpacing.xs) {
                    if let role = group.primaryRole {
                        CrewJobChip(text: role, tint: JTColors.accent)
                    }
                    CrewJobChip(text: group.latestStatus, tint: statusTint(for: group.latestStatus))
                    if let date = group.latestFormattedDate {
                        CrewJobChip(text: date, tint: JTColors.info)
                    }
                    Spacer(minLength: JTSpacing.md)
                    if group.isMultiEntry {
                        CrewJobChip(text: "\(group.entryCount) entries", tint: JTColors.info)
                    }
                }
            }
            .padding(JTSpacing.lg)
        }
        .listRowSeparator(.hidden)
    }
}

private struct RecentCrewJobRow: View {
    let job: RecentCrewJob

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(job.status)
                    .font(JTTypography.subheadline.weight(.semibold))
                    .foregroundStyle(JTColors.textPrimary)
                Spacer()
                Text(job.formattedDate)
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
            }

            if let number = job.trimmedJobNumber {
                Text("Job #\(number)")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
            }

            Text(job.address)
                .font(JTTypography.body)
                .foregroundStyle(JTColors.textPrimary)
                .multilineTextAlignment(.leading)

            if let role = job.displayCrewRole {
                CrewJobChip(text: role, tint: JTColors.accent)
            }

            if let notes = job.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                Text(notes)
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, JTSpacing.sm)
    }
}

private struct CrewJobChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(JTTypography.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, JTSpacing.sm + 2)
            .padding(.vertical, JTSpacing.xs)
            .background(tint.opacity(0.18), in: Capsule(style: .continuous))
    }
}

@MainActor private func statusTint(for status: String) -> Color {
    let lower = status.lowercased()
    if lower.contains("done") || lower.contains("complete") {
        return JTColors.success
    }
    if lower.contains("need") || lower.contains("pending") {
        return JTColors.info
    }
    if lower.contains("talk") || lower.contains("hold") {
        return JTColors.warning
    }
    return JTColors.accent
}

private struct RecentCrewJobDetailSheet: View {
    let job: RecentCrewJob

    @EnvironmentObject private var jobsViewModel: JobsViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: JTSpacing.lg) {
                    summaryCard
                    metadataCard
                    notesCard
                }
                .padding(.horizontal, JTSpacing.lg)
                .padding(.top, JTSpacing.lg)
                .padding(.bottom, JTSpacing.xxl * 2)
            }
            .background(JTGradients.background(stops: 4).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: JTSpacing.sm) {
                    JTPrimaryButton(isAdding ? "Adding…" : "Add to Dashboard", systemImage: "plus.circle") {
                        addToDashboard()
                    }
                    .disabled(isAdding)
                }
                .padding(.horizontal, JTSpacing.lg)
                .padding(.top, JTSpacing.md)
                .padding(.bottom, JTSpacing.lg)
                .background(.ultraThinMaterial)
            }
            .alert("Unable to add job", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                Text(job.displayTitle)
                    .font(JTTypography.title3)
                    .foregroundStyle(JTColors.textPrimary)

                Text(job.address)
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: JTSpacing.xs) {
                    CrewJobChip(text: job.status, tint: statusTint(for: job.status))
                    CrewJobChip(text: job.formattedDate, tint: JTColors.info)
                    if let role = job.displayCrewRole {
                        CrewJobChip(text: role, tint: JTColors.accent)
                    }
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    private var metadataCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                ForEach(detailItems) { item in
                    HStack(alignment: .top, spacing: JTSpacing.md) {
                        Image(systemName: item.icon)
                            .font(.subheadline)
                            .foregroundStyle(JTColors.textSecondary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(JTTypography.caption)
                                .foregroundStyle(JTColors.textSecondary)
                            Text(item.value)
                                .font(JTTypography.subheadline)
                                .foregroundStyle(JTColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    @ViewBuilder private var notesCard: some View {
        if let notes = job.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: JTSpacing.sm) {
                    Text("Notes")
                        .font(JTTypography.headline)
                        .foregroundStyle(JTColors.textPrimary)
                    Text(notes)
                        .font(JTTypography.body)
                        .foregroundStyle(JTColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(JTSpacing.lg)
            }
        } else {
            EmptyView()
        }
    }

    private var detailItems: [DetailItem] {
        var items: [DetailItem] = []

        if let jobNumber = job.trimmedJobNumber {
            items.append(DetailItem(icon: "number", title: "Job Number", value: jobNumber))
        }

        if let role = job.displayCrewRole {
            items.append(DetailItem(icon: "person.3", title: "Crew Role", value: role))
        }

        items.append(DetailItem(icon: "calendar", title: "Date", value: job.formattedDate))
        items.append(DetailItem(icon: "flag.fill", title: "Status", value: job.status))

        if let crewName = normalizedNonEmpty(job.crewName) {
            items.append(DetailItem(icon: "person.2", title: "Crew Name", value: crewName))
        }

        if let crewLead = normalizedNonEmpty(job.crewLead) {
            items.append(DetailItem(icon: "person.crop.circle.badge.checkmark", title: "Crew Lead", value: crewLead))
        }

        if let hours = job.hours, hours > 0 {
            items.append(DetailItem(icon: "clock", title: "Hours", value: String(format: "%.1f", hours)))
        }

        if let materials = normalizedNonEmpty(job.materialsUsed) {
            items.append(DetailItem(icon: "shippingbox", title: "Materials Used", value: materials))
        }

        if let canFootage = normalizedNonEmpty(job.canFootage) {
            items.append(DetailItem(icon: "ruler", title: "CAN Footage", value: canFootage))
        }

        if let nidFootage = normalizedNonEmpty(job.nidFootage) {
            items.append(DetailItem(icon: "ruler", title: "NID Footage", value: nidFootage))
        }

        if let createdBy = normalizedNonEmpty(job.createdBy) {
            items.append(DetailItem(icon: "person.badge.key", title: "Created By", value: createdBy))
        }

        if let assignedTo = normalizedNonEmpty(job.assignedTo) {
            items.append(DetailItem(icon: "person.crop.circle.badge.exclam", title: "Assigned To", value: assignedTo))
        }

        return items
    }

    private func addToDashboard() {
        guard !isAdding else { return }

        isAdding = true
        errorMessage = nil

        let userID = authViewModel.currentUser?.id
        let newJob = Job(
            address: job.address,
            date: Date(),
            status: "Pending",
            assignedTo: nil,
            createdBy: userID,
            notes: "",
            jobNumber: job.trimmedJobNumber,
            assignments: nil,
            materialsUsed: nil,
            photos: [],
            participants: nil,
            hours: 0.0,
            nidFootage: nil,
            canFootage: nil
        )

        jobsViewModel.createJob(newJob) { success in
            isAdding = false
            if success {
                dismiss()
            } else {
                errorMessage = "We couldn’t add the job to your dashboard. Please try again."
            }
        }
    }

    private func normalizedNonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private struct DetailItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let value: String
    }
}
