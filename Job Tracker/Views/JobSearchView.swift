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
                // Same gradient used app-wide
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.17254902, green: 0.24313726, blue: 0.3137255, opacity: 1),
                        Color(red: 0.29803923, green: 0.6313726, blue: 0.6862745, opacity: 1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Title row
                        Text("Search Jobs")
                            .font(.largeTitle.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.white)

                        // Inline search bar (so the hamburger button never overlaps it)
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.white.opacity(0.9))
                            TextField("Address, #, status, user…", text: $searchText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        }
                        .padding(12)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                        // Results/content
                        resultsContent
                    }
                    .padding(16)
                    // Keep content below the floating hamburger (matches HelpCenterView)
                    .hamburgerClearance(72)
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
            VStack(spacing: 16) {
                Spacer(minLength: 40)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 42, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.8))
                Text("Search all jobs")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Type part of an address, job #, status (e.g. \"Completed\"), or the name of the person who added it — results include jobs from all users.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 24)
                Spacer(minLength: 20)
            }
        } else if aggregatedResults.isEmpty {
            VStack(spacing: 12) {
                Spacer(minLength: 40)
                Text("No jobs found for “\(searchText)”")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Try fewer keywords, or search by street, city, job #, status, or creator name.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 24)
                Spacer(minLength: 20)
            }
        } else {
            LazyVStack(spacing: 14) {
                ForEach(aggregatedResults) { agg in
                    NavigationLink {
                        AggregatedDetailView(aggregate: agg)
                            .environmentObject(usersViewModel)
                    } label: {
                        AggregatedJobCard(aggregate: agg)
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let num = job.jobNumber, !num.isEmpty {
                    Text("#\(num)")
                        .font(.caption2.monospaced())
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 10) {
                Label(job.status, systemImage: "checkmark.seal")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                Text(job.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                if let creator {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.5))
                    Text("\(creator.firstName) \(creator.lastName)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
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
        case "done", "completed": return Color.green.opacity(0.9)
        case "pending": return Color.yellow.opacity(0.9)
        default: return Color.blue.opacity(0.9)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            HStack(alignment: .firstTextBaseline) {
                Text(aggregate.address)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if !aggregate.jobNumber.isEmpty {
                    Text("#\(aggregate.jobNumber)")
                        .font(.caption2.monospaced())
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundStyle(.white)
                }
            }

            // Most recent line
            if let recent = aggregate.jobs.first {
                HStack(spacing: 10) {
                    Label(recent.status, systemImage: "checkmark.seal")
                        .font(.caption)
                        .foregroundStyle(statusColor(recent.status))
                    Text(recent.date, style: .date)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            // Creators (unique)
            if !aggregate.creators.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(aggregate.creators, id: \.id) { u in
                            Text("\(u.firstName) \(u.lastName)")
                                .font(.caption2)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.12), in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            // If duplicates exist, show a tiny summary row
            if aggregate.jobs.count > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "square.stack.3d.down.right")
                        .imageScale(.small)
                        .foregroundStyle(.white.opacity(0.8))
                    Text("\(aggregate.jobs.count) entries – latest shown")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .overlay(
            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.trailing, 10)
            }
        )
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06))
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.17254902, green: 0.24313726, blue: 0.3137255, opacity: 1),
                    Color(red: 0.29803923, green: 0.6313726, blue: 0.6862745, opacity: 1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(aggregate.address)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !aggregate.jobNumber.isEmpty {
                            Text("#\(aggregate.jobNumber)")
                                .font(.caption.monospaced())
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .foregroundStyle(.white)
                        }

                        if !aggregate.creators.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2")
                                    .foregroundStyle(.white.opacity(0.9))
                                Text("\(aggregate.creators.count) contributor\(aggregate.creators.count == 1 ? "" : "s")")
                                    .foregroundStyle(.white.opacity(0.9))
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Timeline of all entries (newest first)
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(aggregate.jobs, id: \.id) { job in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(job.status)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(job.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                }

                                if let u = creator(for: job) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.crop.circle")
                                        Text("\(u.firstName) \(u.lastName)")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                                }

                                // You can add more fields here if your Job model has them (e.g., notes, photos)
                                // Example (safe-guarded):
                                // if let notes = job.notes, !notes.isEmpty { Text(notes) ... }
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.06))
                            )
                        }
                    }
                }
                .padding(16)
                .hamburgerClearance(72)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Hamburger Clearance

extension View {
    /// Adds invisible top space so the floating hamburger button doesn’t cover content.
    /// Adjust the height if you change the button size/position.
    func hamburgerClearance(_ height: CGFloat = 64) -> some View {
        self.safeAreaInset(edge: .top) {
            Color.clear.frame(height: height)
        }
    }
}
