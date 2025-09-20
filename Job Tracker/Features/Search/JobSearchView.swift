import SwiftUI
import UIKit

struct JobSearchView: View {
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var usersViewModel: UsersViewModel
    @EnvironmentObject private var navigation: AppNavigationViewModel
    @Environment(\.shellChromeHeight) private var shellChromeHeight

    @State private var searchText: String = ""
    @State private var path: [Route] = []

    enum Route: Hashable {
        case aggregate(id: String)
        case job(id: String)
    }

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

    private var scrollContentTopPadding: CGFloat {
        shellChromeHeight > 0 ? JTSpacing.xl : JTSpacing.lg
    }

    private func updateShellChrome(for path: [Route]) {
        navigation.shouldShowShellChrome = path.isEmpty
    }

    var body: some View {
        NavigationStack(path: $path) {
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
                    .padding(.top, scrollContentTopPadding)
                    .padding(.horizontal, JTSpacing.lg)
                    .padding(.bottom, JTSpacing.lg)
                }
            }
        }
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .aggregate(let aggregateID):
                if let aggregate = aggregate(forID: aggregateID) {
                    AggregatedDetailView(aggregate: aggregate)
                        .environmentObject(usersViewModel)
                        .environmentObject(jobsViewModel)
                } else {
                    MissingSearchDestinationView(message: "Job results are no longer available. Try running your search again.")
                }
            case .job(let jobID):
                if let job = job(forID: jobID) {
                    destination(for: job)
                } else {
                    MissingSearchDestinationView(message: "We couldn't load that job. It may have been removed.")
                }
            }
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: shellChromeHeight)
        }
        .onAppear {
            jobsViewModel.startSearchIndexForAllJobs()
            updateShellChrome(for: path)
        }
        .onChange(of: path) { newValue in
            updateShellChrome(for: newValue)
        }
        .onDisappear {
            navigation.shouldShowShellChrome = true
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
                    NavigationLink(value: Route.aggregate(id: agg.id)) {
                        AggregatedJobCard(aggregate: agg)
                            .contentShape(JTShapes.roundedRectangle(cornerRadius: JTShapes.smallCardCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Navigation

    private func binding(for job: Job) -> Binding<Job>? {
        guard jobsViewModel.jobs.contains(where: { $0.id == job.id }) else { return nil }
        return Binding(
            get: {
                jobsViewModel.jobs.first(where: { $0.id == job.id }) ?? job
            },
            set: { newValue in
                if let index = jobsViewModel.jobs.firstIndex(where: { $0.id == job.id }) {
                    var copy = jobsViewModel.jobs
                    copy[index] = newValue
                    jobsViewModel.jobs = copy
                }
            }
        )
    }

    private func aggregate(forID id: String) -> JobAggregate? {
        aggregatedResults.first { $0.id == id }
    }

    private func job(forID id: String) -> Job? {
        if let fromAggregates = aggregatedResults.flatMap({ $0.jobs }).first(where: { $0.id == id }) {
            return fromAggregates
        }
        if let job = jobsViewModel.searchJobs.first(where: { $0.id == id }) {
            return job
        }
        return jobsViewModel.jobs.first(where: { $0.id == id })
    }

    @ViewBuilder
    private func destination(for job: Job) -> some View {
        if let binding = binding(for: job) {
            JobDetailView(job: binding)
        } else {
            JobSearchDetailView(job: job)
        }
    }

    // MARK: - Helpers

    /// Returns true if the job matches the query across several fields.
    private func matches(job: Job, query: String) -> Bool {
        let creator = job.createdBy.flatMap { usersViewModel.usersDict[$0] }
        return JobSearchMatcher.matches(job: job, query: query, creator: creator)
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
            .allowsHitTesting(false)
        )
    }
}

// MARK: - Aggregated Detail
private struct AggregatedDetailView: View {
    @EnvironmentObject var usersViewModel: UsersViewModel
    let aggregate: JobSearchView.JobAggregate

    @AppStorage("addressSuggestionProvider") private var suggestionProviderRaw = "apple"

    @State private var isGeneratingShareLink = false
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @State private var shareErrorMessage: String? = nil
    @State private var jobForShareSheet: Job? = nil

    private func creator(for job: Job) -> AppUser? {
        guard let id = job.createdBy else { return nil }
        return usersViewModel.usersDict[id]
    }

    private var primaryJob: Job? { aggregate.jobs.first }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareErrorMessage != nil },
            set: { newValue in
                if !newValue { shareErrorMessage = nil }
            }
        )
    }

    private func openInMaps(job: Job) {
        guard let encoded = job.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        if suggestionProviderRaw == "google" {
            if let url = URL(string: "comgooglemaps://?daddr=\(encoded)&directionsmode=driving") {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success { return }
                    if let appleURL = URL(string: "maps://?saddr=Current%20Location&daddr=\(encoded)") {
                        UIApplication.shared.open(appleURL)
                    }
                }
                return
            }
        }
        if let appleURL = URL(string: "maps://?saddr=Current%20Location&daddr=\(encoded)") {
            UIApplication.shared.open(appleURL)
        }
    }

    private func share(job: Job) {
        guard !isGeneratingShareLink else { return }
        shareErrorMessage = nil
        jobForShareSheet = nil
        shareURL = nil
        isGeneratingShareLink = true

        Task {
            do {
                let url = try await SharedJobService.shared.publishShareLink(job: job)
                await MainActor.run {
                    shareURL = url
                    jobForShareSheet = job
                    isGeneratingShareLink = false
                    showShareSheet = true
                }
            } catch {
                await MainActor.run {
                    shareErrorMessage = error.localizedDescription
                    jobForShareSheet = nil
                    isGeneratingShareLink = false
                }
            }
        }
    }

    @ViewBuilder
    private func quickActions(for job: Job) -> some View {
        HStack(spacing: JTSpacing.sm) {
            Button {
                openInMaps(job: job)
            } label: {
                HStack(spacing: JTSpacing.xs) {
                    Image(systemName: "map")
                    Text("Directions")
                }
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textPrimary)
                .padding(.vertical, JTSpacing.xs)
                .padding(.horizontal, JTSpacing.sm)
                .jtGlassBackground(shape: Capsule(), strokeColor: JTColors.glassSoftStroke)
            }
            .buttonStyle(.plain)

            Button {
                share(job: job)
            } label: {
                HStack(spacing: JTSpacing.xs) {
                    if isGeneratingShareLink {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(JTColors.textPrimary)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text("Share")
                }
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textPrimary)
                .padding(.vertical, JTSpacing.xs)
                .padding(.horizontal, JTSpacing.sm)
                .jtGlassBackground(shape: Capsule(), strokeColor: JTColors.glassSoftStroke)
            }
            .buttonStyle(.plain)
            .disabled(isGeneratingShareLink)
        }
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

                        if let job = primaryJob {
                            quickActions(for: job)
                                .padding(.top, JTSpacing.sm)
                        }
                    }

                    // Timeline of all entries (newest first)
                    VStack(alignment: .leading, spacing: JTSpacing.md) {
                        ForEach(aggregate.jobs, id: \.id) { job in
                            NavigationLink(value: JobSearchView.Route.job(id: job.id)) {
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
                                .overlay(
                                    HStack {
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(JTColors.textMuted)
                                            .padding(.trailing, JTSpacing.md)
                                    }
                                    .allowsHitTesting(false)
                                )
                                .contentShape(JTShapes.roundedRectangle(cornerRadius: JTShapes.smallCardCornerRadius))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(JTSpacing.lg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet, onDismiss: { shareURL = nil; jobForShareSheet = nil }) {
            if let url = shareURL {
                let subject = jobForShareSheet?.shortAddress ?? aggregate.address
                ActivityView(activityItems: [url], subject: "Job link for \(subject)")
            }
        }
        .alert("Couldn't Share Job", isPresented: shareErrorBinding, actions: {
            Button("OK", role: .cancel) { shareErrorMessage = nil }
        }, message: {
            if let message = shareErrorMessage {
                Text(message)
            }
        })
    }
}

private struct MissingSearchDestinationView: View {
    let message: String

    var body: some View {
        ZStack {
            JTGradients.background
                .ignoresSafeArea()

            VStack(spacing: JTSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(JTColors.warning)

                Text(message)
                    .multilineTextAlignment(.center)
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)
                    .padding(.horizontal, JTSpacing.lg)
            }
            .padding(.horizontal, JTSpacing.lg)
        }
    }
}

// MARK: - Matching Helpers

struct JobSearchMatcher {
    static func matches(job: Job, query: String, creator: AppUser?) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = normalizedQuery
            .split { $0.isWhitespace }
            .map { String($0).lowercased() }

        guard !tokens.isEmpty else { return false }

        let haystack = normalizedHaystack(for: job, creator: creator)
        return tokens.allSatisfy { haystack.contains($0) }
    }

    private static func normalizedHaystack(for job: Job, creator: AppUser?) -> String {
        let creatorName: String
        if let creator {
            creatorName = "\(creator.firstName) \(creator.lastName)"
        } else {
            creatorName = ""
        }

        let fields: [String] = [
            job.address,
            job.jobNumber ?? "",
            job.status,
            creatorName,
            DateFormatter.localizedString(from: job.date, dateStyle: .short, timeStyle: .none)
        ]

        return fields
            .joined(separator: " ")
            .lowercased()
    }
}

// MARK: - Hashable support

extension JobSearchView.JobAggregate: Hashable {
    static func == (lhs: JobSearchView.JobAggregate, rhs: JobSearchView.JobAggregate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
