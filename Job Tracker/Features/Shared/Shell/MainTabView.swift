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
    @EnvironmentObject private var authViewModel: AuthViewModel

    private var selection: Binding<AppNavigationViewModel.PrimaryDestination> {
        Binding(
            get: { navigation.selectedPrimary },
            set: { navigation.selectPrimary($0) }
        )
    }

    var body: some View {
        TabView(selection: selection) {
            Group {
                if authViewModel.isSupervisorFlag {
                    SupervisorHomeDashboardView()
                } else {
                    DashboardView()
                }
            }
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

            Section("Splice Assist") {
                NavigationLink(value: AppNavigationViewModel.Destination.spliceAssist) {
                    Label(AppNavigationViewModel.Destination.spliceAssist.title,
                          systemImage: AppNavigationViewModel.Destination.spliceAssist.systemImage)
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
            SupervisorHomeDashboardView()
        case .admin:
            AdminPanelView()
        case .settings:
            SettingsView()
        case .helpCenter:
            HelpCenterView()
        case .recentCrewJobs:
            RecentCrewJobsView()
        case .spliceAssist:
            SpliceAssistView()
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
    #if DEBUG
    @StateObject private var updateViewModel = AdminUpdateViewModel()
    #endif
    @State private var pendingToggle: PendingToggle?
    @State private var pendingDeleteUser: AppUser?
    @State private var showingBackfillConfirmation = false
    @State private var pendingUpdateAction: PendingUpdateAction?
    @State private var showingLogs = false

    var body: some View {
        List {
            updatesSection
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
            "Delete user?",
            isPresented: Binding(
                get: { pendingDeleteUser != nil },
                set: { newValue in
                    if !newValue {
                        pendingDeleteUser = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let user = pendingDeleteUser {
                Button("Delete \(user.firstName) \(user.lastName)", role: .destructive) {
                    viewModel.deleteUser(user)
                    pendingDeleteUser = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteUser = nil
            }
        } message: {
            if let user = pendingDeleteUser {
                Text("This removes \(user.firstName) \(user.lastName) from the app roster immediately. Use this only for accounts you no longer need.")
            } else {
                Text("This removes the selected user from the app roster immediately.")
            }
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
        #if DEBUG
        .confirmationDialog(
            pendingUpdateAction == .apply ? "Apply debug update?" : "Rollback debug update?",
            isPresented: Binding(
                get: { pendingUpdateAction != nil },
                set: { newValue in
                    if !newValue { pendingUpdateAction = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            if let action = pendingUpdateAction {
                switch action {
                case .apply:
                    Button("Apply Debug Update", role: .destructive) {
                        updateViewModel.applyUpdate()
                        pendingUpdateAction = nil
                    }
                case .rollback:
                    Button("Rollback Debug Update", role: .destructive) {
                        updateViewModel.rollbackUpdate()
                        pendingUpdateAction = nil
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                pendingUpdateAction = nil
            }
        } message: {
            if pendingUpdateAction == .apply {
                Text("This is a debug-only simulation. Production releases are distributed through App Store/TestFlight and gated by remote forced-update config.")
            } else {
                Text("Restores the previous debug demo version. This does not roll back a production App Store build.")
            }
        }
        .sheet(isPresented: $showingLogs) {
            NavigationStack {
                AdminUpdateLogsView(logs: updateViewModel.logs)
            }
        }
        #endif
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
    private var updatesSection: some View {
        Section("App Updates") {
            #if DEBUG
            VStack(alignment: .leading, spacing: 12) {
                Label("Debug-only update demo", systemImage: "ladybug")
                    .font(.headline)
                Text("Production iOS updates are released through App Store/TestFlight. The live forced-update gate is controlled by trusted Firestore remote config and shown to users automatically when required.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack {
                    Label("Current demo version", systemImage: "info.circle")
                    Spacer()
                    Text(updateViewModel.currentVersion)
                        .font(.subheadline.monospaced())
                }

                if let available = updateViewModel.availableVersion {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Demo update available", systemImage: "arrow.down.circle")
                            .font(.subheadline)
                        Text("Version \(available)")
                            .font(.subheadline.weight(.semibold))
                        if !updateViewModel.changelog.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Demo changelog")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(updateViewModel.changelog, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "checkmark.seal")
                                            .font(.caption2)
                                        Text(item)
                                            .font(.footnote)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("No pending demo updates", systemImage: "checkmark.seal")
                            .font(.subheadline)
                        if let lastCheck = updateViewModel.lastCheckDate {
                            Text("Last checked at \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Demo package status")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(updateViewModel.verificationStatus.message)
                        .font(.footnote)
                        .foregroundStyle(updateViewModel.verificationStatus.isVerified ? .green : .primary)
                }

                Toggle(isOn: $updateViewModel.maintenanceModeEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Demo maintenance mode")
                        Text("Required before applying the debug-only simulated update.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let progress = updateViewModel.progress {
                    if let fraction = progress.fractionComplete {
                        ProgressView(value: fraction) {
                            Text(progress.title)
                                .font(.subheadline)
                        } currentValueLabel: {
                            Text(String(format: "%.0f%%", fraction * 100))
                                .font(.caption.monospacedDigit())
                        }
                        Text(progress.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView(progress.title)
                        Text(progress.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = updateViewModel.errorReason {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .onTapGesture { updateViewModel.resetError() }
                }

                VStack(spacing: 8) {
                    Button {
                        updateViewModel.checkForUpdates()
                    } label: {
                        Label("Check Demo Updates", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(updateViewModel.isBusy)

                    Button {
                        updateViewModel.downloadUpdate()
                    } label: {
                        Label("Download Demo Package", systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(updateViewModel.isBusy || !updateViewModel.hasAvailableUpdate)

                    Button {
                        updateViewModel.verifyDownload()
                    } label: {
                        Label("Verify Demo Package", systemImage: "checkmark.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(updateViewModel.isBusy || !updateViewModel.hasDownloadedUpdate)

                    Button(role: .destructive) {
                        pendingUpdateAction = .apply
                    } label: {
                        Label("Apply Demo Update", systemImage: "hammer")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(updateViewModel.isBusy || !updateViewModel.canApplyUpdate)

                    Button {
                        pendingUpdateAction = .rollback
                    } label: {
                        Label("Rollback Demo", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(updateViewModel.isBusy)

                    Button {
                        showingLogs = true
                    } label: {
                        Label("View Demo Logs", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 4)
            #else
            VStack(alignment: .leading, spacing: 8) {
                Label("Release management", systemImage: "shippingbox")
                    .font(.headline)
                Text("Production builds do not include the admin package update demo. Ship releases through App Store/TestFlight, and use the trusted Firestore app_config/ios_version document to force users below the required version to update.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            #endif
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

                        Button(role: .destructive) {
                            pendingDeleteUser = user
                        } label: {
                            Label("Delete User", systemImage: "trash")
                                .font(.subheadline)
                        }
                        .disabled(viewModel.isMutating(userID: user.id) || authViewModel.currentUser?.id == user.id)
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

    private enum PendingUpdateAction {
        case apply
        case rollback
    }
}

struct AdminUpdateLogsView: View {
    let logs: [String]

    var body: some View {
        List {
            if logs.isEmpty {
                Text("No update activity yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(logs, id: \.self) { line in
                    Text(line)
                        .font(.caption.monospaced())
                        .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Update Logs")
    }
}
