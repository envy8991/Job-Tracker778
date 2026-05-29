import FirebaseFirestore
import SwiftUI

struct SupervisorHomeDashboardView: View {
    @EnvironmentObject private var usersViewModel: UsersViewModel
    @StateObject private var viewModel = SupervisorHomeDashboardViewModel()
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                JTGradients.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: JTSpacing.lg) {
                        header
                        datePickerCard
                        positionGrid
                    }
                    .padding(.horizontal, JTSpacing.lg)
                    .padding(.vertical, JTSpacing.xl)
                }
            }
            .navigationTitle("Supervisor Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.start(for: selectedDate) }
            .onChange(of: selectedDate) { newDate in viewModel.start(for: newDate) }
            .onDisappear { viewModel.stop() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: JTSpacing.xs) {
            Text("Crew Overview")
                .font(JTTypography.screenTitle)
                .foregroundStyle(JTColors.textPrimary)
            Text("Review today's users by position and open their job notes, materials, assignments, and status updates.")
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textSecondary)
        }
    }

    private var datePickerCard: some View {
        GlassCard {
            DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .font(JTTypography.body)
                .padding(JTSpacing.lg)
        }
    }

    private var positionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: JTSpacing.md)], spacing: JTSpacing.md) {
            ForEach(CrewPosition.supervisorDashboardOptions) { position in
                NavigationLink {
                    SupervisorPositionUsersView(
                        position: position,
                        date: selectedDate,
                        users: users(for: position),
                        jobs: viewModel.jobs
                    )
                } label: {
                    SupervisorPositionCard(
                        position: position,
                        userCount: users(for: position).count,
                        jobCount: jobCount(for: position)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func users(for position: CrewPosition) -> [AppUser] {
        usersViewModel.allUsers.filter { CrewPosition.matches($0.position, position) }
    }

    private func jobCount(for position: CrewPosition) -> Int {
        let ids = Set(users(for: position).map(\.id))
        return viewModel.jobs.filter { job in
            job.involvesAnyUser(in: ids)
        }.count
    }
}

final class SupervisorHomeDashboardViewModel: ObservableObject {
    @Published private(set) var jobs: [Job] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func start(for date: Date) {
        stop()
        isLoading = true
        errorMessage = nil

        let start = Calendar.current.startOfDay(for: date)
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else {
            isLoading = false
            return
        }

        listener = db.collection("jobs")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("date", isLessThan: Timestamp(date: end))
            .order(by: "date", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                if let error {
                    DispatchQueue.main.async {
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                    return
                }

                let decoded: [Job] = snapshot?.documents.compactMap { doc in
                    var job = try? doc.data(as: Job.self)
                    job?.id = doc.documentID
                    return job
                } ?? []

                DispatchQueue.main.async {
                    self.jobs = decoded
                    self.isLoading = false
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}

private struct SupervisorPositionCard: View {
    let position: CrewPosition
    let userCount: Int
    let jobCount: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: JTSpacing.md) {
                HStack {
                    Text(position.displayName)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(JTColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(JTColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: JTSpacing.xs) {
                    Text("\(userCount) user\(userCount == 1 ? "" : "s")")
                    Text("\(jobCount) job\(jobCount == 1 ? "" : "s") today")
                }
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textSecondary)
            }
            .padding(JTSpacing.lg)
        }
    }
}

private struct SupervisorPositionUsersView: View {
    let position: CrewPosition
    let date: Date
    let users: [AppUser]
    let jobs: [Job]

    var body: some View {
        List {
            if users.isEmpty {
                Text("No users found for \(position.displayName).")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(users) { user in
                    NavigationLink {
                        SupervisorUserJobsView(user: user, date: date, jobs: jobsForUser(user))
                    } label: {
                        HStack {
                            Text(displayName(for: user))
                            Spacer()
                            Text("\(jobsForUser(user).count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(position.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func jobsForUser(_ user: AppUser) -> [Job] {
        jobs.filter { $0.involvesUser(user.id) }
            .sorted { $0.date < $1.date }
    }

    private func displayName(for user: AppUser) -> String {
        let name = [user.firstName, user.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "Unnamed User" : name
    }
}

private struct SupervisorUserJobsView: View {
    let user: AppUser
    let date: Date
    let jobs: [Job]

    var body: some View {
        List {
            if jobs.isEmpty {
                Text("No jobs for this date.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(jobs) { job in
                    SupervisorUserJobInfoCard(job: job)
                }
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayName: String {
        let name = [user.firstName, user.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? "Unnamed User" : name
    }
}

private struct SupervisorUserJobInfoCard: View {
    let job: Job

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.jobNumber?.trimmedNonEmpty ?? "No job number")
                        .font(JTTypography.captionEmphasized)
                        .foregroundStyle(JTColors.textSecondary)
                    Text(job.address)
                        .font(JTTypography.headline)
                        .foregroundStyle(JTColors.textPrimary)
                }
                Spacer()
                Text(job.displayStatus)
                    .font(JTTypography.captionEmphasized)
                    .padding(.horizontal, JTSpacing.sm)
                    .padding(.vertical, JTSpacing.xs)
                    .background(statusTint.opacity(0.18), in: Capsule())
                    .foregroundStyle(statusTint)
            }

            detailRows
        }
        .padding(.vertical, JTSpacing.sm)
    }

    @ViewBuilder
    private var detailRows: some View {
        if let portalID = job.portalID?.trimmedNonEmpty {
            detailRow("Portal ID", portalID)
        }
        if let locationNumber = job.locationNumber?.trimmedNonEmpty {
            detailRow("Location", locationNumber)
        }
        if let assignments = job.assignments?.trimmedNonEmpty {
            detailRow("Assignment", assignments)
        }
        if let materials = job.materialsUsed?.trimmedNonEmpty {
            detailRow("Materials", materials)
        }
        if let notes = job.notes?.trimmedNonEmpty {
            detailRow("Notes", notes)
        }
        if let placement = job.jobPlacement?.trimmedNonEmpty {
            detailRow("Placement", CrewPosition.positionDisplayName(from: placement))
        }
    }

    private var statusTint: Color {
        job.status.lowercased() == "pending" ? Color.orange : JTColors.success
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(JTColors.textSecondary)
            Text(value)
                .font(JTTypography.caption)
                .foregroundStyle(JTColors.textPrimary)
        }
    }
}

private extension Job {
    func involvesUser(_ userID: String) -> Bool {
        createdBy == userID || assignedTo == userID || (participants ?? []).contains(userID)
    }

    func involvesAnyUser(in userIDs: Set<String>) -> Bool {
        guard !userIDs.isEmpty else { return false }
        if let createdBy, userIDs.contains(createdBy) { return true }
        if let assignedTo, userIDs.contains(assignedTo) { return true }
        return (participants ?? []).contains { userIDs.contains($0) }
    }
}


private extension String {
    var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
