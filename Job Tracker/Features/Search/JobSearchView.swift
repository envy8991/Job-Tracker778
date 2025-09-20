import SwiftUI
import UIKit

struct JobSearchView: View {
    @EnvironmentObject private var jobsViewModel: JobsViewModel
    @EnvironmentObject private var usersViewModel: UsersViewModel
    @EnvironmentObject private var navigation: AppNavigationViewModel
    @Environment(\.shellChromeHeight) private var shellChromeHeight

    @StateObject private var viewModel: JobSearchViewModel

    init(viewModel: JobSearchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var scrollContentTopPadding: CGFloat {
        shellChromeHeight > 0 ? JTSpacing.xl : JTSpacing.lg
    }

    private func updateShellChrome(for path: [JobSearchViewModel.Route]) {
        navigation.shouldShowShellChrome = path.isEmpty
    }

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ZStack(alignment: .top) {
                JTGradients.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: JTSpacing.lg) {
                        Text("Search Jobs")
                            .font(JTTypography.screenTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(JTColors.textPrimary)

                        JTTextField("Address, #, status, user…", text: $viewModel.query, icon: "magnifyingglass")
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)

                        JobSearchResultsContent(viewState: viewModel.resultsState)
                    }
                    .padding(.top, scrollContentTopPadding)
                    .padding(.horizontal, JTSpacing.lg)
                    .padding(.bottom, JTSpacing.lg)
                }
            }
        }
        .navigationDestination(for: JobSearchViewModel.Route.self) { route in
            destinationView(for: route)
        }
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: shellChromeHeight)
        }
        .onAppear {
            jobsViewModel.startSearchIndexForAllJobs()
            updateShellChrome(for: viewModel.navigationPath)
        }
        .onChange(of: viewModel.navigationPath) { newValue in
            updateShellChrome(for: newValue)
        }
        .onDisappear {
            navigation.shouldShowShellChrome = true
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private func destinationView(for route: JobSearchViewModel.Route) -> some View {
        if let destination = viewModel.destination(for: route) {
            switch destination {
            case .aggregate(let id):
                AggregatedDetailView(aggregateID: id, viewModel: viewModel)
                    .environmentObject(usersViewModel)
            case .job(let jobDestination):
                if let binding = jobDestination.binding {
                    JobDetailView(job: binding)
                } else {
                    JobSearchDetailView(job: jobDestination.job)
                }
            }
        } else {
            switch route {
            case .aggregate:
                MissingSearchDestinationView(message: "Job results are no longer available. Try running your search again.")
            case .job:
                MissingSearchDestinationView(message: "We couldn't load that job. It may have been removed.")
            }
        }
    }
}

// MARK: - Results

private struct JobSearchResultsContent: View {
    let viewState: JobSearchViewModel.ResultsState

    @ViewBuilder
    var body: some View {
        switch viewState.content {
        case .prompt:
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
        case .empty(let query):
            VStack(spacing: JTSpacing.sm) {
                Spacer(minLength: 40)
                Text("No jobs found for “\(query)”")
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)
                Text("Try fewer keywords, or search by street, city, job #, status, or creator name.")
                    .multilineTextAlignment(.center)
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)
                    .padding(.horizontal, JTSpacing.xl)
                Spacer(minLength: 20)
            }
        case .aggregates(let aggregates):
            JobSearchResultsList(aggregates: aggregates)
        }
    }
}

private struct JobSearchResultsList: View {
    let aggregates: [JobSearchViewModel.Aggregate]

    var body: some View {
        LazyVStack(spacing: JTSpacing.md) {
            ForEach(aggregates) { aggregate in
                NavigationLink(value: JobSearchViewModel.Route.aggregate(id: aggregate.id)) {
                    JobSearchAggregateRow(aggregate: aggregate)
                        .contentShape(JTShapes.roundedRectangle(cornerRadius: JTShapes.smallCardCornerRadius))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct JobSearchAggregateRow: View {
    let aggregate: JobSearchViewModel.Aggregate

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
                            ForEach(aggregate.creators, id: \.id) { creator in
                                Text(creator.displayName)
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

// MARK: - Aggregated Detail
private struct AggregatedDetailView: View {
    @EnvironmentObject var usersViewModel: UsersViewModel
    let aggregateID: JobSearchViewModel.Aggregate.ID
    @ObservedObject var viewModel: JobSearchViewModel

    @AppStorage("addressSuggestionProvider") private var suggestionProviderRaw = "apple"

    @State private var isGeneratingShareLink = false
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @State private var shareErrorMessage: String? = nil
    @State private var jobForShareSheet: Job? = nil

    private var aggregate: JobSearchViewModel.Aggregate? {
        viewModel.aggregate(forID: aggregateID)
    }

    private func primaryJob(for aggregate: JobSearchViewModel.Aggregate) -> Job? {
        guard let id = aggregate.jobs.first?.id else { return nil }
        return viewModel.job(forID: id)
    }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareErrorMessage != nil },
            set: { newValue in
                if !newValue { shareErrorMessage = nil }
            }
        )
    }

    private func creator(for job: JobSearchViewModel.Aggregate.JobDigest) -> AppUser? {
        guard let id = job.createdBy else { return nil }
        return usersViewModel.usersDict[id]
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

    @ViewBuilder
    private func content(for aggregate: JobSearchViewModel.Aggregate) -> some View {
        ZStack(alignment: .top) {
            JTGradients.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: JTSpacing.lg) {
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

                        if let job = primaryJob(for: aggregate) {
                            quickActions(for: job)
                                .padding(.top, JTSpacing.sm)
                        }
                    }

                    VStack(alignment: .leading, spacing: JTSpacing.md) {
                        ForEach(aggregate.jobs, id: \.id) { entry in
                            NavigationLink(value: JobSearchViewModel.Route.job(id: entry.id)) {
                                GlassCard(cornerRadius: JTShapes.smallCardCornerRadius,
                                          strokeColor: JTColors.glassSoftStroke,
                                          shadow: JTShadow.none) {
                                    VStack(alignment: .leading, spacing: JTSpacing.sm) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(entry.status)
                                                .font(JTTypography.headline)
                                                .foregroundStyle(JTColors.textPrimary)
                                            Spacer()
                                            Text(entry.date, style: .date)
                                                .font(JTTypography.caption)
                                                .foregroundStyle(JTColors.textSecondary)
                                        }

                                        if let u = creator(for: entry) {
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
    }

    var body: some View {
        Group {
            if let aggregate {
                content(for: aggregate)
            } else {
                MissingSearchDestinationView(message: "Job results are no longer available. Try running your search again.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet, onDismiss: { shareURL = nil; jobForShareSheet = nil }) {
            if let url = shareURL {
                let subject = jobForShareSheet?.shortAddress ?? aggregate?.address ?? "Job"
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
    static func matches(job: JobSearchMatchable, query: String, creator: AppUser?) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = normalizedQuery
            .split { $0.isWhitespace }
            .map { String($0).lowercased() }

        guard !tokens.isEmpty else { return false }

        let haystack = normalizedHaystack(for: job, creator: creator)
        return tokens.allSatisfy { haystack.contains($0) }
    }

    private static func normalizedHaystack(for job: JobSearchMatchable, creator: AppUser?) -> String {
        var fields: [String] = []

        if let address = normalizedNonEmpty(job.address) {
            fields.append(address)
        }

        if let jobNumber = normalizedNonEmpty(job.jobNumber) {
            fields.append(jobNumber)
        }

        if let status = normalizedNonEmpty(job.status) {
            fields.append(status)
        }

        if let creator,
           let creatorName = normalizedNonEmpty("\(creator.firstName) \(creator.lastName)") {
            fields.append(creatorName)
        }

        if let date = normalizedNonEmpty(
            DateFormatter.localizedString(from: job.date, dateStyle: .short, timeStyle: .none)
        ) {
            fields.append(date)
        }

        let optionalFields: [String?] = [
            job.notes,
            job.materialsUsed,
            job.assignments,
            job.nidFootage,
            job.canFootage
        ]

        for field in optionalFields {
            if let normalized = normalizedNonEmpty(field) {
                fields.append(normalized)
            }
        }

        return fields.joined(separator: " ")
    }

    private static func normalizedNonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.lowercased()
    }

    private static func normalizedNonEmpty(_ value: String?) -> String? {
        guard let value = value else { return nil }
        return normalizedNonEmpty(value)
    }
}

// MARK: - Hashable support

