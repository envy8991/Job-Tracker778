import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var navigation: AppNavigationViewModel

    private static var hasConfiguredAppearance = false

    private var menuPresentation: Binding<Bool> {
        Binding(
            get: { navigation.isPrimaryMenuPresented },
            set: { navigation.isPrimaryMenuPresented = $0 }
        )
    }

    init() {
        MainTabView.configureTabBarAppearance()
    }

    var body: some View {
        ZStack {
            JTGradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ShellActionBar(
                    onShowMenu: { navigation.isPrimaryMenuPresented = true },
                    onOpenHelp: { navigation.navigate(to: .helpCenter) }
                )

                PrimaryTabContainer()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: menuPresentation) {
            PrimaryDestinationMenu()
                .presentationDetents([.medium, .large])
        }
    }

    private static func configureTabBarAppearance() {
        guard !hasConfiguredAppearance else { return }

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        appearance.backgroundColor = UIColor(JTColors.backgroundTop.opacity(0.92))
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.25)

        let selectedColor = UIColor(JTColors.accent)
        let unselectedColor = UIColor(JTColors.textMuted)

        let layouts = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]

        layouts.forEach { layout in
            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = [.foregroundColor: selectedColor]
            layout.normal.iconColor = unselectedColor
            layout.normal.titleTextAttributes = [.foregroundColor: unselectedColor]
        }

        let tabBarAppearance = UITabBar.appearance()
        tabBarAppearance.standardAppearance = appearance
        tabBarAppearance.scrollEdgeAppearance = appearance
        tabBarAppearance.tintColor = selectedColor
        tabBarAppearance.unselectedItemTintColor = unselectedColor
        tabBarAppearance.isTranslucent = false

        hasConfiguredAppearance = true
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

            MapsView()
                .tag(AppNavigationViewModel.PrimaryDestination.maps)
                .tabItem {
                    Label(AppNavigationViewModel.PrimaryDestination.maps.title,
                          systemImage: AppNavigationViewModel.PrimaryDestination.maps.systemImage)
                }

            MoreTabView()
                .tag(AppNavigationViewModel.PrimaryDestination.more)
                .tabItem {
                    Label(AppNavigationViewModel.PrimaryDestination.more.title,
                          systemImage: AppNavigationViewModel.PrimaryDestination.more.systemImage)
                }
        }
        .tint(JTColors.accent)
        .background(Color.clear)
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
        .background(JTGradients.background.ignoresSafeArea())
        .onAppear {
            if !navigation.activeDestination.isMoreStackDestination {
                navigation.navigate(to: .more)
            }
        }
    }
}

private struct MoreMenuList: View {
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
                NavigationLink(value: AppNavigationViewModel.Destination.search) {
                    Label("Job Search", systemImage: AppNavigationViewModel.Destination.search.systemImage)
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
            JTGradients.background
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
        case .findPartner:
            FindPartnerView()
        case .search:
            JobSearchView()
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

// MARK: - Action bar & menu

private struct ShellActionBar: View {
    @Environment(\.safeAreaInsets) private var safeAreaInsets

    var onShowMenu: () -> Void
    var onOpenHelp: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: JTSpacing.md) {
                ShellActionButton(icon: "line.3.horizontal", label: "Menu", action: onShowMenu)
                Spacer(minLength: JTSpacing.sm)
                ShellActionButton(icon: "questionmark.circle", label: "Help", action: onOpenHelp)
            }
            .padding(.horizontal, JTSpacing.xl)
            .padding(.top, safeAreaInsets.top + JTSpacing.md)
            .padding(.bottom, JTSpacing.md)
        }
        .background(.ultraThinMaterial)
        .background(
            LinearGradient(
                colors: [
                    JTColors.backgroundTop.opacity(0.95),
                    JTColors.backgroundTop.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1),
            alignment: .bottom
        )
        .jtShadow(JTElevations.raised)
    }
}

private struct ShellActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(JTTypography.button)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, JTSpacing.lg)
                .padding(.vertical, JTSpacing.sm)
                .foregroundStyle(JTColors.textPrimary)
                .jtGlassBackground(shape: Capsule())
                .jtShadow(JTElevations.button)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
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
                                        .foregroundStyle(JTColors.accent)
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

struct FindPartnerView: View {
    var body: some View {
        Text("Find Partner")
            .navigationTitle("Find Partner")
    }
}

struct SupervisorDashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Text("Supervisor Dashboard")
            .navigationTitle("Supervisor")
    }
}

struct ProfileView: View {
    var body: some View {
        Text("Profile")
            .navigationTitle("Profile")
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .navigationTitle("Settings")
    }
}
