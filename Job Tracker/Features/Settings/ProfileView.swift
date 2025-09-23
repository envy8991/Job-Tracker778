import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var timesheetHistory = UserTimesheetsViewModel()
    @StateObject private var yellowSheetHistory = UserYellowSheetsViewModel()

    @State private var hasRequestedHistory = false
    @State private var isTimesheetLoading = false
    @State private var isYellowSheetLoading = false

    private let gridColumns = [GridItem(.adaptive(minimum: 160), spacing: JTSpacing.lg)]

    var body: some View {
        NavigationView {
            ZStack {
                JTGradients.background(stops: 5)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: JTSpacing.xl) {
                        if let user = authViewModel.currentUser {
                            profileHeader(for: user)
                            historySection
                            quickActionsSection
                            accountSection
                        } else {
                            signedOutPlaceholder
                        }
                    }
                    .padding(.horizontal, JTSpacing.lg)
                    .padding(.vertical, JTSpacing.xxl)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .jtNavigationBarStyle()
        }
        .onAppear {
            if let user = authViewModel.currentUser {
                loadHistory(for: user)
            }
        }
        .onChange(of: authViewModel.currentUser?.id) { _ in
            if let user = authViewModel.currentUser {
                loadHistory(for: user, forceReload: true)
            } else {
                resetHistoryState()
            }
        }
        .onReceive(timesheetHistory.$timesheets) { _ in
            if isTimesheetLoading {
                isTimesheetLoading = false
            }
        }
        .onReceive(yellowSheetHistory.$yellowSheets) { _ in
            if isYellowSheetLoading {
                isYellowSheetLoading = false
            }
        }
    }
}

// MARK: - Header

private extension ProfileView {
    @ViewBuilder
    func profileHeader(for user: AppUser) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: JTSpacing.lg) {
                HStack(alignment: .center, spacing: JTSpacing.lg) {
                    ProfileAvatarView(user: user)

                    VStack(alignment: .leading, spacing: JTSpacing.xs) {
                        Text("\(user.firstName) \(user.lastName)")
                            .font(JTTypography.title)
                            .foregroundStyle(JTColors.textPrimary)

                        Text(user.email)
                            .font(JTTypography.subheadline)
                            .foregroundStyle(JTColors.textSecondary)
                            .textSelection(.enabled)

                        roleBadges(for: user)
                    }

                    Spacer()
                }

                Divider()
                    .background(JTColors.glassStroke.opacity(0.3))

                VStack(alignment: .leading, spacing: JTSpacing.xs) {
                    Text("Primary role")
                        .font(JTTypography.captionEmphasized)
                        .foregroundStyle(JTColors.textSecondary)

                    Text(user.normalizedPosition.isEmpty ? "Not specified" : user.normalizedPosition)
                        .font(JTTypography.body)
                        .foregroundStyle(JTColors.textPrimary)
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    @ViewBuilder
    func roleBadges(for user: AppUser) -> some View {
        if user.isSupervisor || user.isAdmin {
            HStack(spacing: JTSpacing.sm) {
                if user.isSupervisor {
                    roleBadge(title: "Supervisor",
                              systemImage: "person.2.fill",
                              tint: JTColors.info)
                }

                if user.isAdmin {
                    roleBadge(title: "Admin",
                              systemImage: "star.fill",
                              tint: Color.orange.opacity(0.95))
                }
            }
        }
    }

    func roleBadge(title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: JTSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(JTTypography.captionEmphasized)
                .foregroundStyle(JTColors.textPrimary)
        }
        .padding(.vertical, JTSpacing.xs)
        .padding(.horizontal, JTSpacing.sm)
        .background(tint.opacity(0.18), in: Capsule())
    }
}

// MARK: - History

private extension ProfileView {
    @ViewBuilder
    var historySection: some View {
        VStack(alignment: .leading, spacing: JTSpacing.md) {
            Text("History at a glance")
                .font(JTTypography.headline)
                .foregroundStyle(JTColors.textPrimary)

            LazyVGrid(columns: gridColumns, spacing: JTSpacing.lg) {
                historyCard(
                    title: "Timesheets",
                    icon: "clock.badge.checkmark",
                    accent: JTColors.accent,
                    primaryValue: timesheetCountText,
                    detail: timesheetDetailText,
                    isLoading: isTimesheetLoading
                )

                historyCard(
                    title: "Yellow Sheets",
                    icon: "folder.fill.badge.person.crop",
                    accent: JTColors.info,
                    primaryValue: yellowSheetCountText,
                    detail: yellowSheetDetailText,
                    isLoading: isYellowSheetLoading
                )
            }
        }
    }

    func historyCard(title: String,
                     icon: String,
                     accent: Color,
                     primaryValue: String,
                     detail: String?,
                     isLoading: Bool) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                HStack(spacing: JTSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.18))
                            .frame(width: 42, height: 42)

                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(accent)
                    }

                    Text(title)
                        .font(JTTypography.headline)
                        .foregroundStyle(JTColors.textPrimary)
                }

                if isLoading {
                    ProgressView()
                        .tint(accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(primaryValue)
                        .font(JTTypography.title3)
                        .foregroundStyle(JTColors.textPrimary)

                    if let detail {
                        Text(detail)
                            .font(JTTypography.caption)
                            .foregroundStyle(JTColors.textSecondary)
                    }
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    var timesheetCountText: String {
        let count = timesheetHistory.timesheets.count
        return count == 1 ? "1 entry" : "\(count) entries"
    }

    var yellowSheetCountText: String {
        let count = yellowSheetHistory.yellowSheets.count
        return count == 1 ? "1 archive" : "\(count) archives"
    }

    var timesheetDetailText: String? {
        guard let latest = timesheetHistory.timesheets.first else {
            return timesheetHistory.timesheets.isEmpty ? "Save a weekly timesheet to build your history." : nil
        }

        let date = ProfileView.weekFormatter.string(from: latest.weekStart)
        let total = latest.totalHours.trimmingCharacters(in: .whitespacesAndNewlines)

        if total.isEmpty {
            return "Most recent: Week of \(date)"
        }

        return "Most recent: Week of \(date) • \(total) hrs"
    }

    var yellowSheetDetailText: String? {
        guard let latest = sortedYellowSheets.first else {
            return yellowSheetHistory.yellowSheets.isEmpty ? "Capture a yellow sheet to see it appear here." : nil
        }

        let date = ProfileView.weekFormatter.string(from: latest.weekStart)
        return "Most recent: Week of \(date) • \(latest.totalJobs) jobs"
    }

    var sortedYellowSheets: [YellowSheet] {
        yellowSheetHistory.yellowSheets.sorted { $0.weekStart > $1.weekStart }
    }
}

// MARK: - Quick actions & account management

private extension ProfileView {
    @ViewBuilder
    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: JTSpacing.md) {
            Text("Quick actions")
                .font(JTTypography.headline)
                .foregroundStyle(JTColors.textPrimary)

            QuickActionLink(
                title: "Past Timesheets",
                subtitle: "Review, export, or delete previous submissions.",
                icon: "calendar.badge.clock",
                accent: JTColors.accent,
                isLoading: isTimesheetLoading,
                badgeValue: timesheetHistory.timesheets.count
            ) {
                PastTimesheetsView()
                    .environmentObject(authViewModel)
            }

            QuickActionLink(
                title: "Past Yellow Sheets",
                subtitle: "Keep tabs on weekly job groupings.",
                icon: "folder.badge.person.crop",
                accent: JTColors.info,
                isLoading: isYellowSheetLoading,
                badgeValue: yellowSheetHistory.yellowSheets.count
            ) {
                PastYellowSheetsView()
                    .environmentObject(authViewModel)
            }
        }
    }

    @ViewBuilder
    var accountSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                Text("Account")
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)

                Text("Sign out to switch profiles or secure this device.")
                    .font(JTTypography.caption)
                    .foregroundStyle(JTColors.textSecondary)

                JTPrimaryButton("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                    authViewModel.signOut()
                }
            }
            .padding(JTSpacing.lg)
        }
    }

    var signedOutPlaceholder: some View {
        GlassCard {
            VStack(spacing: JTSpacing.md) {
                Image(systemName: "person.crop.circle.badge.exclam")
                    .font(.system(size: 42, weight: .regular))
                    .foregroundStyle(JTColors.textSecondary)

                Text("No user is currently signed in")
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)

                Text("Sign in from the main screen to see your profile, timesheets, and yellow sheets in one place.")
                    .font(JTTypography.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(JTColors.textSecondary)
            }
            .padding(JTSpacing.xxl)
        }
    }
}

// MARK: - Data loading helpers

private extension ProfileView {
    static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    func loadHistory(for user: AppUser, forceReload: Bool = false) {
        if forceReload {
            hasRequestedHistory = false
            timesheetHistory.timesheets = []
            yellowSheetHistory.yellowSheets = []
        }

        guard !hasRequestedHistory else { return }

        hasRequestedHistory = true
        isTimesheetLoading = true
        isYellowSheetLoading = true

        timesheetHistory.fetchTimesheets(for: user.id)
        yellowSheetHistory.fetchYellowSheets(for: user.id)
    }

    func resetHistoryState() {
        hasRequestedHistory = false
        isTimesheetLoading = false
        isYellowSheetLoading = false
        timesheetHistory.timesheets = []
        yellowSheetHistory.yellowSheets = []
    }
}

// MARK: - Supporting views

private struct ProfileAvatarView: View {
    let user: AppUser

    var body: some View {
        ZStack {
            if let urlString = user.profilePictureURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                    case .empty:
                        ProgressView()
                            .tint(JTColors.accent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 76, height: 76)
        .background(JTColors.glassHighlight.opacity(0.25))
        .clipShape(Circle())
        .overlay(Circle().stroke(JTColors.glassSoftStroke, lineWidth: 1.2))
    }

    @ViewBuilder
    private var fallback: some View {
        Text(user.initials.isEmpty ? "JT" : user.initials)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(JTColors.textPrimary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(JTColors.glassHighlight.opacity(0.25))
    }
}

private struct QuickActionLink<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let isLoading: Bool
    let badgeValue: Int
    let destination: () -> Destination

    init(title: String,
         subtitle: String,
         icon: String,
         accent: Color,
         isLoading: Bool,
         badgeValue: Int,
         @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
        self.isLoading = isLoading
        self.badgeValue = badgeValue
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            GlassCard {
                HStack(alignment: .center, spacing: JTSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.18))
                            .frame(width: 48, height: 48)

                        Image(systemName: icon)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(JTTypography.headline)
                            .foregroundStyle(JTColors.textPrimary)

                        Text(subtitle)
                            .font(JTTypography.caption)
                            .foregroundStyle(JTColors.textSecondary)
                    }

                    Spacer(minLength: JTSpacing.lg)

                    if isLoading {
                        ProgressView()
                            .tint(accent)
                    } else if badgeValue > 0 {
                        Text("\(badgeValue)")
                            .font(JTTypography.captionEmphasized)
                            .padding(.vertical, JTSpacing.xs)
                            .padding(.horizontal, JTSpacing.sm)
                            .background(accent.opacity(0.18), in: Capsule())
                            .foregroundStyle(accent)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(JTColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(JTSpacing.lg)
            }
        }
        .buttonStyle(.plain)
    }
}
