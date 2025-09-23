import SwiftUI

struct JobSearchView: View {
    @EnvironmentObject private var jobsViewModel: JobsViewModel
    @EnvironmentObject private var usersViewModel: UsersViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var navigation: AppNavigationViewModel
    @Environment(\.shellChromeHeight) private var shellChromeHeight

    @StateObject private var viewModel: JobSearchViewModel
    @State private var navigationPath: [JobSearchViewModel.Result] = []

    init(viewModel: JobSearchViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var topPadding: CGFloat {
        shellChromeHeight > 0 ? JTSpacing.xl : JTSpacing.lg
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                JTGradients.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: JTSpacing.xl) {
                        header
                        searchField
                        QuickFiltersSection(filters: viewModel.quickFilters) { filter in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.query = filter.suggestedQuery
                            }
                        }
                        SearchContentView(state: viewModel.viewState, resultsCount: viewModel.resultsCount)
                    }
                    .padding(.top, topPadding)
                    .padding(.horizontal, JTSpacing.lg)
                    .padding(.bottom, JTSpacing.xl)
                }
            }
            .navigationDestination(for: JobSearchViewModel.Result.self) { result in
                if let job = viewModel.job(for: result.id) {
                    JobSearchDetailView(job: job, metadata: result)
                        .environmentObject(jobsViewModel)
                        .environmentObject(usersViewModel)
                        .environmentObject(authViewModel)
                } else {
                    MissingSearchResultView()
                }
            }
        }
        .jtNavigationBarStyle()
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: shellChromeHeight)
        }
        .onAppear {
            jobsViewModel.startSearchIndexForAllJobs()
            updateChrome()
        }
        .onChange(of: navigationPath) { _ in
            updateChrome()
        }
        .onDisappear {
            navigation.shouldShowShellChrome = true
        }
    }

    private func updateChrome() {
        navigation.shouldShowShellChrome = navigationPath.isEmpty
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: JTSpacing.sm) {
            Text("Job Search")
                .font(JTTypography.screenTitle)
                .foregroundStyle(JTColors.textPrimary)
            Text("Look up any job across Cable South in seconds.")
                .font(JTTypography.subheadline)
                .foregroundStyle(JTColors.textSecondary)
        }
    }

    private var searchField: some View {
        JTTextField("Address, job #, status, or teammate", text: $viewModel.query, icon: "magnifyingglass")
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .submitLabel(.search)
    }
}

// MARK: - Quick Filters

private struct QuickFiltersSection: View {
    let filters: [JobSearchViewModel.QuickFilter]
    var onSelect: (JobSearchViewModel.QuickFilter) -> Void

    var body: some View {
        if filters.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: JTSpacing.sm) {
                Text("Quick filters")
                    .font(JTTypography.subheadline)
                    .foregroundStyle(JTColors.textSecondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: JTSpacing.sm) {
                        ForEach(filters) { filter in
                            Button {
                                onSelect(filter)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: JTSpacing.xs) {
                                        Image(systemName: filter.iconSystemName)
                                        Text(filter.title)
                                    }
                                    .font(JTTypography.caption)
                                    .foregroundStyle(JTColors.textPrimary)

                                    Text(filter.subtitle)
                                        .font(JTTypography.caption)
                                        .foregroundStyle(JTColors.textSecondary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .jtGlassBackground(shape: Capsule(), strokeColor: JTColors.glassSoftStroke)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - Content States

private struct SearchContentView: View {
    let state: JobSearchViewModel.ViewState
    let resultsCount: Int

    var body: some View {
        switch state {
        case .idle(let recents):
            IdleSearchStateView(recents: recents)
        case .empty(let query):
            EmptyResultsView(query: query)
        case .results(_, let items):
            SearchResultsList(
                title: "Results",
                subtitle: "\(resultsCount) match\(resultsCount == 1 ? "" : "es")",
                results: items
            )
        }
    }
}

private struct IdleSearchStateView: View {
    let recents: [JobSearchViewModel.Result]

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.xl) {
            GlassCard(cornerRadius: JTShapes.largeCardCornerRadius,
                      strokeColor: JTColors.glassSoftStroke,
                      shadow: JTShadow.none) {
                VStack(spacing: JTSpacing.md) {
                    Image(systemName: "waveform.magnifyingglass")
                        .font(.system(size: 42, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(JTColors.textSecondary)
                        .frame(maxWidth: .infinity)

                    Text("Search the entire company")
                        .font(JTTypography.title3)
                        .foregroundStyle(JTColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Type part of an address, job number, status, or teammate to explore every job in Job Tracker.")
                        .font(JTTypography.body)
                        .foregroundStyle(JTColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, JTSpacing.xl)
                .padding(.horizontal, JTSpacing.xl)
            }

            if !recents.isEmpty {
                SearchResultsList(
                    title: "Recent activity",
                    subtitle: "Jump back into the latest jobs from across your team.",
                    results: recents
                )
            }
        }
    }
}

private struct SearchResultsList: View {
    let title: String?
    let subtitle: String?
    let results: [JobSearchViewModel.Result]

    init(title: String? = nil, subtitle: String? = nil, results: [JobSearchViewModel.Result]) {
        self.title = title
        self.subtitle = subtitle
        self.results = results
    }

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.md) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(JTTypography.headline)
                            .foregroundStyle(JTColors.textPrimary)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(JTTypography.caption)
                            .foregroundStyle(JTColors.textSecondary)
                    }
                }
            }

            LazyVStack(spacing: JTSpacing.md) {
                ForEach(results) { result in
                    NavigationLink(value: result) {
                        JobSearchResultRow(result: result)
                            .contentShape(JTShapes.roundedRectangle(cornerRadius: JTShapes.smallCardCornerRadius))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct EmptyResultsView: View {
    let query: String

    var body: some View {
        GlassCard(cornerRadius: JTShapes.largeCardCornerRadius,
                  strokeColor: JTColors.glassSoftStroke,
                  shadow: JTShadow.none) {
            VStack(spacing: JTSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(JTColors.warning)

                Text("No jobs found for “\(query)”")
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Try fewer keywords or search by street, city, job number, status, or teammate name.")
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, JTSpacing.xl)
            .padding(.horizontal, JTSpacing.xl)
        }
    }
}

// MARK: - Result Row

private struct JobSearchResultRow: View {
    let result: JobSearchViewModel.Result

    private func statusColor(_ status: String) -> Color {
        let lower = status.lowercased()
        if lower.contains("done") || lower.contains("complete") {
            return JTColors.success
        }
        if lower.contains("pending") {
            return JTColors.warning
        }
        if lower.contains("hold") || lower.contains("blocked") || lower.contains("issue") {
            return JTColors.error
        }
        if lower.contains("need") {
            return JTColors.info
        }
        return JTColors.accent
    }

    var body: some View {
        GlassCard(cornerRadius: JTShapes.smallCardCornerRadius,
                  strokeColor: JTColors.glassSoftStroke,
                  shadow: JTShadow.none) {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                HStack(alignment: .top, spacing: JTSpacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.address.primary)
                            .font(JTTypography.headline)
                            .foregroundStyle(JTColors.textPrimary)
                            .lineLimit(2)

                        if let secondary = result.address.secondary {
                            Text(secondary)
                                .font(JTTypography.caption)
                                .foregroundStyle(JTColors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: JTSpacing.sm)
                    if let jobNumber = result.jobNumber {
                        Text("#\(jobNumber)")
                            .font(JTTypography.caption)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .jtGlassBackground(shape: Capsule(), strokeColor: JTColors.glassSoftStroke)
                            .foregroundStyle(JTColors.textPrimary)
                    }
                }

                HStack(spacing: JTSpacing.sm) {
                    Text(result.status)
                        .font(JTTypography.caption)
                        .fontWeight(.semibold)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(statusColor(result.status).opacity(0.15), in: Capsule())
                        .foregroundStyle(statusColor(result.status))

                    Text(result.date, style: .date)
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)

                    if let creator = result.creator {
                        Text("·")
                            .foregroundStyle(JTColors.textMuted)
                        Label {
                            if let role = creator.role, !role.isEmpty {
                                Text("Added by \(creator.name) · \(role)")
                            } else {
                                Text("Added by \(creator.name)")
                            }
                        } icon: {
                            Image(systemName: "person.crop.circle")
                        }
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.textSecondary)
                        .labelStyle(.titleAndIcon)
                    }
                }

                if let snippet = result.snippet {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snippet.title.uppercased())
                            .font(JTTypography.caption)
                            .foregroundStyle(JTColors.textSecondary)
                        Text(snippet.value)
                            .font(JTTypography.body)
                            .foregroundStyle(JTColors.textPrimary)
                            .lineLimit(3)
                    }
                }

                if result.isOwnedByCurrentUser {
                    Label("In your job list", systemImage: "checkmark.circle.fill")
                        .font(JTTypography.caption)
                        .foregroundStyle(JTColors.success)
                }
            }
            .padding(JTSpacing.md)
        }
    }
}

// MARK: - Missing Result

private struct MissingSearchResultView: View {
    var body: some View {
        ZStack {
            JTGradients.background
                .ignoresSafeArea()

            VStack(spacing: JTSpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(JTColors.warning)

                Text("Job unavailable")
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)

                Text("We couldn’t load that job. It may have been removed or you no longer have access to it.")
                    .font(JTTypography.body)
                    .foregroundStyle(JTColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, JTSpacing.lg)
            }
            .padding(.horizontal, JTSpacing.lg)
        }
    }
}
