import SwiftUI

struct JobSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var usersViewModel: UsersViewModel

    @State private var searchText: String = ""

    // MARK: - Filter + Group

    /// Filter across multiple fields so *all* jobs are searchable regardless of who created them.
    private var filteredJobs: [Job] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        // Prefer the global search index if it's populated; otherwise fall back to the user's jobs.
        let source = jobsViewModel.searchJobs.isEmpty ? jobsViewModel.jobs : jobsViewModel.searchJobs

        return source.filter { job in
            matches(job: job, query: q)
        }
        // Stable ordering: newest first, then address
        .sorted {
            if $0.date != $1.date {
                return $0.date > $1.date
            }
            return $0.address.localizedCaseInsensitiveCompare($1.address) == .orderedAscending
        }
    }

    // Aggregated groups: collapse identical jobs (same address + job number) and collect creators
    struct JobAggregate: Identifiable {
        let id: String // unique key
        let address: String
        let jobNumber: String
        let jobs: [Job]
        let creators: [AppUser]
    }

    private var aggregatedResults: [JobAggregate] {
        // Group by (address + job #). If job # is missing, group by address only.
        let dict = Dictionary(grouping: filteredJobs) { (job) -> String in
            let num = (job.jobNumber ?? "").trimmingCharacters(in: .whitespaces)
            return job.address.lowercased() + "|#" + num.lowercased()
        }
        // Map to aggregates with unique creators
        let mapped: [JobAggregate] = dict.map { (key, jobs) in
            let address = jobs.first?.address ?? ""
            let jobNumber = jobs.first?.jobNumber ?? ""
            // Build unique creators (by id) from usersViewModel
            var seen: Set<String> = []
            let creators: [AppUser] = jobs.compactMap { j in
                guard let id = j.createdBy else { return nil }
                guard !seen.contains(id), let u = usersViewModel.usersDict[id] else { return nil }
                seen.insert(id)
                return u
            }
            // Keep newest-first inside the aggregate
            let ordered = jobs.sorted { $0.date > $1.date }
            return JobAggregate(id: key, address: address, jobNumber: jobNumber, jobs: ordered, creators: creators)
        }
        // Sort groups by newest job date, then address
        return mapped.sorted { a, b in
            guard let ad = a.jobs.first?.date, let bd = b.jobs.first?.date else {
                return a.address.localizedCaseInsensitiveCompare(b.address) == .orderedAscending
            }
            if ad != bd { return ad > bd }
            return a.address.localizedCaseInsensitiveCompare(b.address) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                JTGradients.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: JTSpacing.lg) {
                        Text("Search Jobs")
                            .font(JTTypography.screenTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(JTColors.textPrimary)

                        JTTextField("Address, #, status, user…", text: $searchText, icon: "magnifyingglass")
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)

                        resultsContent
                    }
                    .padding(JTSpacing.lg)
                }
            }
        }
        .onAppear {
            jobsViewModel.startSearchIndexForAllJobs()
        }
    }

    // MARK: - View Content

    @ViewBuilder
    private var resultsContent: some View {
        if searchText.isEmpty {
            VStack(spacing: JTSpacing.md) {
                Spacer(minLength: 40)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 42, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(JTColors.textSecondary)
                Text("Search all jobs")
                    .font(JTTypography.title3)
                    .foregroundStyle(JTColors.textPrimary)
                Text("Type part of an address, job #, status (e.g. \"Completed\"), or the name of the person who added it — results include jobs from all users.")
                    .multilineTextAlignment(.center)
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)
                    .padding(.horizontal, JTSpacing.xl)
                Spacer(minLength: 20)
            }
        } else if aggregatedResults.isEmpty {
            VStack(spacing: JTSpacing.sm) {
                Spacer(minLength: 40)
                Text("No jobs found for “\(searchText)”")
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)
                Text("Try fewer keywords, or search by street, city, job #, status, or creator name.")
                    .multilineTextAlignment(.center)
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)
                    .padding(.horizontal, JTSpacing.xl)
                Spacer(minLength: 20)
            }
        } else {
            LazyVStack(spacing: JTSpacing.md) {
                ForEach(aggregatedResults) { agg in
                    NavigationLink {
                        AggregatedDetailView(aggregate: agg)
                            .environmentObject(usersViewModel)
                    } label: {
                        AggregatedJobCard(aggregate: agg)
                            .contentShape(JTShapes.roundedRectangle(cornerRadius: JTShapes.smallCardCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Returns true if the job matches the query across several fields.
    private func matches(job: Job, query: String) -> Bool {
        let q = query.lowercased()

        // Creator full name if available
        var creatorName: String = ""
        if let creatorId = job.createdBy,
           let u = usersViewModel.usersDict[creatorId] {
            creatorName = "\(u.firstName) \(u.lastName)".lowercased()
        }

        // Build a single search index string
        let fields: [String] = [
            job.address,
            job.jobNumber ?? "",
            job.status,
            creatorName,
            // Safe date string
            DateFormatter.localizedString(from: job.date, dateStyle: .short, timeStyle: .none)
        ]

        let haystack = fields.joined(separator: " ").lowercased()
        return haystack.contains(q)
    }

    private func creator(for job: Job) -> AppUser? {
        guard let id = job.createdBy else { return nil }
        return usersViewModel.usersDict[id]
    }
}

// MARK: - Row

private struct JobRow: View {
    let job: Job
    let creator: AppUser?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(job.address)
                    .font(JTTypography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(JTColors.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let num = job.jobNumber, !num.isEmpty {
                    Text("#\(num)")
                        .font(JTTypography.caption)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .jtGlassBackground(shape: Capsule(), strokeColor: JTColors.glassSoftStroke)
                        .foregroundStyle(JTColors.textPrimary)
                }
            }

            HStack(spacing: 10) {
                Label(job.status, systemImage: "checkmark.seal")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
                Text(job.date, style: .date)
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)
                if let creator {
                    Text("·")
                        .foregroundStyle(JTColors.textMuted)
                    Text("\(creator.firstName) \(creator.lastName)")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Aggregated Card
private struct AggregatedJobCard: View {
    let aggregate: JobSearchView.JobAggregate

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "done", "completed": return JTColors.success
        case "pending": return JTColors.warning
        default: return JTColors.info
        }
    }

    var body: some View {
        GlassCard(cornerRadius: JTShapes.smallCardCornerRadius,
                  strokeColor: JTColors.glassSoftStroke,
                  shadow: JTShadow.none) {
            VStack(alignment: .leading, spacing: JTSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(aggregate.address)
                        .font(JTTypography.headline)
                        .foregroundStyle(JTColors.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: JTSpacing.sm)
                    if !aggregate.jobNumber.isEmpty {
                        Text("#\(aggregate.jobNumber)")
                            .font(JTTypography.caption)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .jtGlassBackground(shape: Capsule(), strokeColor: JTColors.glassSoftStroke)
                            .foregroundStyle(JTColors.textPrimary)
                    }
                }

                if let recent = aggregate.jobs.first {
                    HStack(spacing: JTSpacing.sm) {
                        Label(recent.status, systemImage: "checkmark.seal")
                            .font(JTTypography.caption)
                            .foregroundStyle(statusColor(recent.status))
                        Text(recent.date, style: .date)
                            .font(JTTypography.caption)
                            .foregroundStyle(JTColors.textSecondary)
                    }
                }

                if !aggregate.creators.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: JTSpacing.xs) {
                            ForEach(aggregate.creators, id: \.id) { u in
                                Text("\(u.firstName) \(u.lastName)")
                                    .font(JTTypography.caption)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .jtGlassBackground(shape: Capsule(), strokeColor: JTColors.glassSoftStroke)
                                    .foregroundStyle(JTColors.textPrimary)
                            }
                        }
                    }
                }

                if aggregate.jobs.count > 1 {
                    HStack(spacing: JTSpacing.xs) {
                        Image(systemName: "square.stack.3d.down.right")
                            .imageScale(.small)
                            .foregroundStyle(JTColors.textSecondary)
                        Text("\(aggregate.jobs.count) entries – latest shown")
                            .font(JTTypography.caption)
                            .foregroundStyle(JTColors.textSecondary)
                    }
                }
            }
            .padding(JTSpacing.md)
        }
        .overlay(
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(JTColors.textMuted)
                    .padding(.trailing, JTSpacing.md)
            }
        )
    }
}

// MARK: - Aggregated Detail
private struct AggregatedDetailView: View {
    @EnvironmentObject var usersViewModel: UsersViewModel
    let aggregate: JobSearchView.JobAggregate

    private func creator(for job: Job) -> AppUser? {
        guard let id = job.createdBy else { return nil }
        return usersViewModel.usersDict[id]
    }

    var body: some View {
        ZStack(alignment: .top) {
            JTGradients.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: JTSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(aggregate.address)
                            .font(JTTypography.screenTitle)
                            .foregroundStyle(JTColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !aggregate.jobNumber.isEmpty {
                            Text("#\(aggregate.jobNumber)")
                                .font(JTTypography.caption)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .jtGlassBackground(shape: Capsule(), strokeColor: JTColors.glassSoftStroke)
                                .foregroundStyle(JTColors.textPrimary)
                        }

                        if !aggregate.creators.isEmpty {
                            HStack(spacing: JTSpacing.xs) {
                                Image(systemName: "person.2")
                                    .foregroundStyle(JTColors.textSecondary)
                                Text("\(aggregate.creators.count) contributor\(aggregate.creators.count == 1 ? "" : "s")")
                                    .foregroundStyle(JTColors.textSecondary)
                                    .font(JTTypography.subheadline)
                            }
                        }
                    }

                    // Timeline of all entries (newest first)
                    VStack(alignment: .leading, spacing: JTSpacing.md) {
                        ForEach(aggregate.jobs, id: \.id) { job in
                            GlassCard(cornerRadius: JTShapes.smallCardCornerRadius,
                                      strokeColor: JTColors.glassSoftStroke,
                                      shadow: JTShadow.none) {
                                VStack(alignment: .leading, spacing: JTSpacing.sm) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(job.status)
                                            .font(JTTypography.headline)
                                            .foregroundStyle(JTColors.textPrimary)
                                        Spacer()
                                        Text(job.date, style: .date)
                                            .font(JTTypography.caption)
                                            .foregroundStyle(JTColors.textSecondary)
                                    }

                                    if let u = creator(for: job) {
                                        HStack(spacing: JTSpacing.xs) {
                                            Image(systemName: "person.crop.circle")
                                            Text("\(u.firstName) \(u.lastName)")
                                        }
                                        .font(JTTypography.caption)
                                        .foregroundStyle(JTColors.textSecondary)
                                    }
                                }
                                .padding(JTSpacing.md)
                            }
                        }
                    }
                }
                .padding(JTSpacing.lg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
