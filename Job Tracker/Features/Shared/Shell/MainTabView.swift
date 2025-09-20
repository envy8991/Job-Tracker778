import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var navigation: AppNavigationViewModel

    private var menuPresentation: Binding<Bool> {
        Binding(
            get: { navigation.isPrimaryMenuPresented },
            set: { navigation.isPrimaryMenuPresented = $0 }
        )
    }

    var body: some View {
        PrimaryTabContainer()
            .safeAreaInset(edge: .top) {
                if navigation.selectedPrimary != .timesheets {
                    ShellActionButtons(
                        onShowMenu: { navigation.isPrimaryMenuPresented = true },
                        onOpenHelp: { navigation.navigate(to: .helpCenter) }
                    )
                }
            }
            .sheet(isPresented: menuPresentation) {
                PrimaryDestinationMenu()
                    .presentationDetents([.medium, .large])
            }
    }
}

// MARK: - Tab container

private struct PrimaryTabContainer: View {
    @EnvironmentObject private var navigation: AppNavigationViewModel

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

            JobSearchView()
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

    @ViewBuilder
    var body: some View {
        switch destination {
        case .profile:
            ProfileView()
        case .search:
            JobSearchView()
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
        case .more:
            MoreMenuList()
        default:
            EmptyView()
        }
    }
}

// MARK: - Action buttons & menu

struct ShellActionButtons: View {
    var onShowMenu: () -> Void
    var onOpenHelp: () -> Void
    var horizontalPadding: CGFloat = 16
    var topPadding: CGFloat = 12

    var body: some View {
        HStack(spacing: 12) {
            RoundedActionButton(icon: "line.3.horizontal", label: "Menu", action: onShowMenu)
            Spacer()
            RoundedActionButton(icon: "questionmark.circle", label: "Help", action: onOpenHelp)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .background(Color.clear)
    }
}

struct RoundedActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(JTColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(JTColors.glassHighlight)
                        .overlay(
                            Capsule()
                                .stroke(JTColors.glassStroke, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
    }
}

private struct PrimaryDestinationMenu: View {
    @EnvironmentObject private var navigation: AppNavigationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Primary Destinations") {
                    ForEach(navigation.primaryDestinations, id: \.self) { destination in
                        Button {
                            navigation.navigate(to: destination)
                            dismiss()
                        } label: {
                            HStack {
                                Label(destination.title, systemImage: destination.systemImage)
                                Spacer()
                                if navigation.activeDestination.primaryDestination == destination.primaryDestination {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Navigate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Placeholder screens

struct AdminPanelView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Admin Panel")
                .font(.title2).bold()
            Text("Use this area to manage users, flags, and global settings.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .navigationTitle("Admin")
    }
}
