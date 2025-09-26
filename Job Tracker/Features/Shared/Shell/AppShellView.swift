import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var navigation: AppNavigationViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                MainTabView()
            } else {
                splitLayout
            }
        }
    }

    private var sidebarSelection: Binding<AppNavigationViewModel.Destination?> {
        Binding(
            get: {
                let active = navigation.activeDestination
                if navigation.primaryDestinations.contains(active) {
                    return active
                } else {
                    return .more
                }
            },
            set: { newValue in
                guard let destination = newValue else { return }
                navigation.navigate(to: destination)
            }
        )
    }

    private var splitLayout: some View {
        NavigationSplitView {
            SidebarList(selection: sidebarSelection)
        } detail: {
            AppShellDetailView(selection: sidebarSelection)
        }
        .navigationSplitViewColumnWidth(min: 260, ideal: 300)
    }
}

private struct SidebarList: View {
    let selection: Binding<AppNavigationViewModel.Destination?>

    @EnvironmentObject private var navigation: AppNavigationViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        List(selection: selection) {
            if let user = authViewModel.currentUser {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(user.firstName) \(user.lastName)")
                            .font(.headline)
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Main") {
                ForEach(navigation.primaryDestinations, id: \.self) { destination in
                    Label(destination.title, systemImage: destination.systemImage)
                        .tag(destination)
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct AppShellDetailView: View {
    let selection: Binding<AppNavigationViewModel.Destination?>

    @EnvironmentObject private var jobsViewModel: JobsViewModel
    @EnvironmentObject private var usersViewModel: UsersViewModel
    @EnvironmentObject private var navigation: AppNavigationViewModel

    private var destination: AppNavigationViewModel.Destination {
        selection.wrappedValue ?? navigation.activeDestination
    }

    @ViewBuilder
    var body: some View {
        switch destination {
        case .dashboard:
            DashboardView()
        case .timesheets:
            WeeklyTimesheetView()
        case .yellowSheet:
            YellowSheetView()
        case .recentCrewJobs:
            RecentCrewJobsView()
        case .search:
            JobSearchView(viewModel: JobSearchViewModel(jobsViewModel: jobsViewModel, usersViewModel: usersViewModel))
        case .maps:
            MapsView()
        case .spliceAssist:
            SpliceAssistView()
        case .more, .profile, .findPartner, .supervisor, .admin, .settings, .helpCenter:
            MoreTabView()
        }
    }
}
