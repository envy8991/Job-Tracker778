import SwiftUI

final class AppNavigationViewModel: ObservableObject {
    // MARK: - Destinations
    enum Destination: Hashable, Identifiable {
        case dashboard
        case timesheets
        case yellowSheet
        case maps
        case recentCrewJobs
        case search
        case more
        case profile
        case findPartner
        case supervisor
        case admin
        case settings
        case helpCenter
        case spliceAssist

        var id: String { title }

        var title: String {
            switch self {
            case .dashboard:   return "Dashboard"
            case .timesheets:  return "Timesheets"
            case .yellowSheet: return "Yellow Sheet"
            case .maps:        return "Route Mapper"
            case .recentCrewJobs: return "Recent Crew Jobs"
            case .search:      return "Job Search"
            case .more:        return "More"
            case .profile:     return "Profile"
            case .findPartner: return "Find Partner"
            case .supervisor:  return "Supervisor"
            case .admin:       return "Admin"
            case .settings:    return "Settings"
            case .helpCenter:  return "Help Center"
            case .spliceAssist: return "Splice Assist"
        }
        }

        var systemImage: String {
            switch self {
            case .dashboard:   return "rectangle.grid.2x2"
            case .timesheets:  return "clock"
            case .yellowSheet: return "doc.text"
            case .maps:        return "map"
            case .recentCrewJobs: return "clock.arrow.circlepath"
            case .search:      return "magnifyingglass"
            case .more:        return "ellipsis.circle"
            case .profile:     return "person.crop.circle"
            case .findPartner: return "person.2"
            case .supervisor:  return "person.text.rectangle"
            case .admin:       return "gearshape.2"
            case .settings:    return "gearshape"
            case .helpCenter:  return "questionmark.circle"
            case .spliceAssist: return "wand.and.stars"
        }
        }

        var primaryDestination: PrimaryDestination {
            switch self {
            case .dashboard:   return .dashboard
            case .timesheets:  return .timesheets
            case .yellowSheet: return .yellowSheet
            case .maps:        return .more
            case .recentCrewJobs: return .more
            case .search:      return .search
            case .more,
                 .profile,
                 .findPartner,
                 .supervisor,
                 .admin,
                 .settings,
                 .helpCenter,
                 .spliceAssist:
                return .more
        }
        }

        var isMoreStackDestination: Bool {
            switch self {
            case .more, .profile, .findPartner, .supervisor, .admin, .settings, .helpCenter, .maps, .recentCrewJobs, .spliceAssist:
                return true
            default:
                return false
            }
        }
    }

    enum PrimaryDestination: String, CaseIterable, Identifiable {
        case dashboard
        case timesheets
        case yellowSheet
        case search
        case more

        var id: String { rawValue }

        var destination: Destination {
            switch self {
            case .dashboard:   return .dashboard
            case .timesheets:  return .timesheets
            case .yellowSheet: return .yellowSheet
            case .search:      return .search
            case .more:        return .more
            }
        }

        var title: String { destination.title }
        var systemImage: String { destination.systemImage }
    }

    // MARK: - Published state
    @Published var selectedPrimary: PrimaryDestination = .dashboard
    @Published var activeDestination: Destination = .dashboard
    @Published var isPrimaryMenuPresented: Bool = false
    @Published private(set) var morePath: [Destination] = []
    @Published var shouldShowShellChrome: Bool = true

    var primaryDestinations: [Destination] {
        PrimaryDestination.allCases.map { $0.destination }
    }

    // MARK: - Selection
    func selectPrimary(_ destination: PrimaryDestination) {
        selectedPrimary = destination
        switch destination {
        case .dashboard:
            activeDestination = .dashboard
            morePath.removeAll()
        case .timesheets:
            activeDestination = .timesheets
            morePath.removeAll()
        case .yellowSheet:
            activeDestination = .yellowSheet
            morePath.removeAll()
        case .search:
            activeDestination = .search
            morePath.removeAll()
        case .more:
            if !activeDestination.isMoreStackDestination {
                activeDestination = .more
            }
        }
        isPrimaryMenuPresented = false
    }

    func navigate(to destination: Destination) {
        activeDestination = destination
        selectedPrimary = destination.primaryDestination

        if destination.primaryDestination == .more {
            if destination == .more {
                morePath.removeAll()
            } else {
                morePath = [destination]
            }
        } else {
            morePath.removeAll()
        }

        isPrimaryMenuPresented = false
    }

    func updateMorePath(_ newPath: [Destination]) {
        morePath = newPath
        if let last = newPath.last {
            activeDestination = last
        } else {
            activeDestination = .more
        }
    }
}
