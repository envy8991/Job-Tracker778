import SwiftUI

struct MainTabView: View {
    var body: some View {
        PrimaryTabContainer()
            .environment(\.shellChromeHeight, 0)
    }
}

// MARK: - Tab container

private struct PrimaryTabContainer: View {
    @EnvironmentObject private var navigation: AppNavigationViewModel
    @EnvironmentObject private var jobsViewModel: JobsViewModel
    @EnvironmentObject private var usersViewModel: UsersViewModel

    private var selection: Binding<AppNavigationViewModel.PrimaryDestination> {
        Binding(
            get: { navigation.selectedPrimary },
            set: { navigation.selectPrimary($0) }
        )
    }

    var body: some View {
        TabView(selection: selection) {
            DashboardView()
                .tag(AppNavigationViewModel.PrimaryDestination.dashboard)
                .tabItem {
                    Label(AppNavigationViewModel.PrimaryDestination.dashboard.title,
                          systemImage: AppNavigationViewModel.PrimaryDestination.dashboard.systemImage)
                }

            WeeklyTimesheetView()
                .tag(AppNavigationViewModel.PrimaryDestination.timesheets)
                .tabItem {
                    Label(AppNavigationViewModel.PrimaryDestination.timesheets.title,
                          systemImage: AppNavigationViewModel.PrimaryDestination.timesheets.systemImage)
                }

            YellowSheetView()
                .tag(AppNavigationViewModel.PrimaryDestination.yellowSheet)
                .tabItem {
                    Label(AppNavigationViewModel.PrimaryDestination.yellowSheet.title,
                          systemImage: AppNavigationViewModel.PrimaryDestination.yellowSheet.systemImage)
                }

            JobSearchView(viewModel: JobSearchViewModel(jobsViewModel: jobsViewModel, usersViewModel: usersViewModel))
                .tag(AppNavigationViewModel.PrimaryDestination.search)
                .tabItem {
                    Label(AppNavigationViewModel.PrimaryDestination.search.title,
                          systemImage: AppNavigationViewModel.PrimaryDestination.search.systemImage)
                }

            MoreTabView()
                .tag(AppNavigationViewModel.PrimaryDestination.more)
                .tabItem {
                    Label(AppNavigationViewModel.PrimaryDestination.more.title,
                          systemImage: AppNavigationViewModel.PrimaryDestination.more.systemImage)
                }
        }
        .jtNavigationBarStyle()
    }
}

// MARK: - More navigation

struct MoreTabView: View {
    @EnvironmentObject private var navigation: AppNavigationViewModel

    private var morePathBinding: Binding<[AppNavigationViewModel.Destination]> {
        Binding(
            get: { navigation.morePath },
            set: { navigation.updateMorePath($0) }
        )
    }

    var body: some View {
        NavigationStack(path: morePathBinding) {
            MoreMenuList()
                .navigationTitle("More")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: AppNavigationViewModel.Destination.self) { destination in
                    MoreDestinationView(destination: destination)
                }
        }
        .jtNavigationBarStyle()
        .background(JTGradients.background(stops: 4).ignoresSafeArea())
        .onAppear {
            if !navigation.activeDestination.isMoreStackDestination {
                navigation.navigate(to: .more)
            }
        }
    }
}

private struct MoreMenuList: View {
    @EnvironmentObject private var navigation: AppNavigationViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        List {
            Section("Account") {
                NavigationLink(value: AppNavigationViewModel.Destination.profile) {
                    Label("Profile", systemImage: AppNavigationViewModel.Destination.profile.systemImage)
                }
                NavigationLink(value: AppNavigationViewModel.Destination.settings) {
                    Label("Settings", systemImage: AppNavigationViewModel.Destination.settings.systemImage)
                }
            }

            Section("Team") {
                NavigationLink(value: AppNavigationViewModel.Destination.findPartner) {
                    Label("Find a Partner", systemImage: AppNavigationViewModel.Destination.findPartner.systemImage)
                }
            }

            Section("Jobs") {
                NavigationLink(value: AppNavigationViewModel.Destination.recentCrewJobs) {
                    Label(AppNavigationViewModel.Destination.recentCrewJobs.title,
                          systemImage: AppNavigationViewModel.Destination.recentCrewJobs.systemImage)
                }
            }

            Section("Resources") {
                NavigationLink(value: AppNavigationViewModel.Destination.maps) {
                    Label(AppNavigationViewModel.Destination.maps.title,
                          systemImage: AppNavigationViewModel.Destination.maps.systemImage)
                }
            }

            if authViewModel.isSupervisorFlag {
                Section("Supervisor") {
                    NavigationLink(value: AppNavigationViewModel.Destination.supervisor) {
                        Label("Supervisor", systemImage: AppNavigationViewModel.Destination.supervisor.systemImage)
                    }
                }
            }

            if authViewModel.isAdminFlag {
                Section("Admin") {
                    NavigationLink(value: AppNavigationViewModel.Destination.admin) {
                        Label("Admin", systemImage: AppNavigationViewModel.Destination.admin.systemImage)
                    }
                }
            }

            Section("Support") {
                NavigationLink(value: AppNavigationViewModel.Destination.helpCenter) {
                    Label("Help Center", systemImage: AppNavigationViewModel.Destination.helpCenter.systemImage)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(
            JTGradients.background(stops: 4)
                .ignoresSafeArea()
        )
        .listStyle(.insetGrouped)
    }
}

private struct MoreDestinationView: View {
    let destination: AppNavigationViewModel.Destination

    @EnvironmentObject private var jobsViewModel: JobsViewModel
    @EnvironmentObject private var usersViewModel: UsersViewModel

    @ViewBuilder
    var body: some View {
        switch destination {
        case .profile:
            ProfileView()
        case .search:
            JobSearchView(viewModel: JobSearchViewModel(jobsViewModel: jobsViewModel, usersViewModel: usersViewModel))
        case .maps:
            MapsView()
        case .findPartner:
            FindPartnerView()
        case .supervisor:
            SupervisorDashboardView()
        case .admin:
            AdminPanelView()
        case .settings:
            SettingsView()
        case .helpCenter:
            HelpCenterView()
        case .recentCrewJobs:
            RecentCrewJobsView()
        case .more:
            MoreMenuList()
        default:
            EmptyView()
        }
    }
}

// MARK: - Placeholder screens

struct AdminPanelView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var usersViewModel: UsersViewModel
    @StateObject private var viewModel = AdminPanelViewModel()
    @State private var pendingToggle: PendingToggle?
    @State private var showingBackfillConfirmation = false

    var body: some View {
        List {
            rosterSection
            maintenanceSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(
            JTGradients.background(stops: 4)
                .ignoresSafeArea()
        )
        .navigationTitle("Admin")
        .alert(item: $viewModel.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            "Confirm role change",
            isPresented: Binding(
                get: { pendingToggle != nil },
                set: { newValue in
                    if !newValue {
                        pendingToggle = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pending = pendingToggle {
                Button(role: .destructive) {
                    finalizePendingToggle(pending)
                } label: {
                    switch pending.flag {
                    case .admin:
                        Text("Remove admin for \(pending.user.firstName)")
                    case .supervisor:
                        Text("Remove supervisor for \(pending.user.firstName)")
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                pendingToggle = nil
            }
        } message: {
            Text("This updates Firebase immediately and may change the user's access right away.")
        }
        .confirmationDialog(
            "Run participants backfill?",
            isPresented: $showingBackfillConfirmation,
            titleVisibility: .visible
        ) {
            Button("Run Backfill", role: .destructive) {
                showingBackfillConfirmation = false
                viewModel.runParticipantsBackfill()
            }
            Button("Cancel", role: .cancel) {
                showingBackfillConfirmation = false
            }
        } message: {
            Text("Merges legacy job creators and assignees into each job's participants array. Only run when you understand the impact.")
        }
        .onAppear {
            viewModel.attach(usersViewModel: usersViewModel)
            viewModel.refreshRosterSnapshot()
            let authVM = authViewModel
            viewModel.onUserFlagsUpdated = { uid in
                if authVM.currentUser?.id == uid {
                    authVM.refreshCurrentUser()
                }
            }
            authViewModel.refreshCurrentUser()
        }
    }

    @ViewBuilder
    private var rosterSection: some View {
        Section("Roster") {
            if viewModel.roster.isEmpty {
                Text("No teammates found.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.roster) { user in
                    VStack(alignment: .leading, spacing: 12) {
                        header(for: user)
                        Toggle(isOn: Binding(
                            get: { user.isAdmin },
                            set: { newValue in requestAdminChange(for: user, newValue: newValue) }
                        )) {
                            Label("Admin", systemImage: "person.crop.badge.shield")
                                .font(.subheadline)
                        }
                        .disabled(viewModel.isMutating(userID: user.id))

                        Toggle(isOn: Binding(
                            get: { user.isSupervisor },
                            set: { newValue in requestSupervisorChange(for: user, newValue: newValue) }
                        )) {
                            Label("Supervisor", systemImage: "person.2.badge.gearshape")
                                .font(.subheadline)
                        }
                        .disabled(viewModel.isMutating(userID: user.id))
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var maintenanceSection: some View {
        Section("Maintenance") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Backfill job participants")
                    .font(.headline)
                Text("Ensure every job document contains a participants array by merging legacy creators and assignees.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if viewModel.maintenanceStatus.isRunning, let progress = viewModel.maintenanceStatus.progress {
                    if let fraction = progress.fractionComplete {
                        ProgressView(value: fraction) {
                            Text(progress.message)
                                .font(.subheadline)
                        } currentValueLabel: {
                            Text("\(progress.processed)/\(progress.total)")
                                .font(.caption.monospacedDigit())
                        }
                    } else {
                        ProgressView(progress.message)
                    }
                }

                if let lastCount = viewModel.maintenanceStatus.lastRunCount, !viewModel.maintenanceStatus.isRunning {
                    Text("Last run updated \(lastCount) job\(lastCount == 1 ? "" : "s").")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let error = viewModel.maintenanceStatus.lastErrorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button(role: .destructive) {
                    showingBackfillConfirmation = true
                } label: {
                    Label("Run Backfill", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(viewModel.maintenanceStatus.isRunning)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func header(for user: AppUser) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(user.firstName) \(user.lastName)")
                    .font(.headline)
                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !user.position.isEmpty {
                    Text(user.position)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if viewModel.isMutating(userID: user.id) {
                ProgressView()
            } else if authViewModel.currentUser?.id == user.id {
                Label("You", systemImage: "person.fill")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
        }
    }

    private func requestAdminChange(for user: AppUser, newValue: Bool) {
        guard !viewModel.isMutating(userID: user.id) else { return }
        if newValue {
            viewModel.setAdmin(true, for: user)
        } else {
            pendingToggle = PendingToggle(user: user, flag: .admin, newValue: false)
        }
    }

    private func requestSupervisorChange(for user: AppUser, newValue: Bool) {
        guard !viewModel.isMutating(userID: user.id) else { return }
        if newValue {
            viewModel.setSupervisor(true, for: user)
        } else {
            pendingToggle = PendingToggle(user: user, flag: .supervisor, newValue: false)
        }
    }

    private func finalizePendingToggle(_ pending: PendingToggle) {
        switch pending.flag {
        case .admin:
            viewModel.setAdmin(pending.newValue, for: pending.user)
        case .supervisor:
            viewModel.setSupervisor(pending.newValue, for: pending.user)
        }
        pendingToggle = nil
    }

    private struct PendingToggle: Identifiable {
        enum Flag {
            case admin
            case supervisor
        }

        let id = UUID()
        let user: AppUser
        let flag: Flag
        let newValue: Bool
    }
}
