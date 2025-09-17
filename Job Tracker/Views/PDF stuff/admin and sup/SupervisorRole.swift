//
//  SupervisorRole.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/31/25.
//

//
//  SupervisorDashboardView.swift
//  Job Tracker
//
//  Created Aug 2025
//

import SwiftUI
import Foundation
import FirebaseFirestore
import CoreLocation

private extension Notification.Name {
    static let toggleSideMenu = Notification.Name("toggleSideMenu")
}

// MARK: - Role & Status filters

enum SupervisorRole: String, CaseIterable, Identifiable {
    case ug = "UG"
    case aerial = "Aerial"
    case can = "Can"
    case nid = "Nid"

    var id: String { rawValue }
}

enum StatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case pending = "Pending"
    case completed = "Completed"

    var id: String { rawValue }
}

// MARK: - ViewModel

final class SupervisorJobsViewModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isLoading = false
    @Published var error: String? = nil

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    /// Stream all jobs within an optional date range. View handles role/status filtering.
    func start(range: DateInterval?) {
        stop()
        isLoading = true
        error = nil

        var q: Query = db.collection("jobs")

        if let r = range {
            q = q.whereField("date", isGreaterThanOrEqualTo: Timestamp(date: r.start))
                 .whereField("date", isLessThan: Timestamp(date: r.end))
        }

        // Sort newest first to make grouping snappy
        q = q.order(by: "date", descending: true)

        listener = q.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }
            if let err = err {
                DispatchQueue.main.async {
                    self.error = err.localizedDescription
                    self.isLoading = false
                }
                return
            }
            let docs = snap?.documents ?? []
            let mapped: [Job] = docs.compactMap { try? $0.data(as: Job.self) }
            DispatchQueue.main.async {
                self.jobs = mapped
                self.isLoading = false
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}

// MARK: - UI helpers
private func roleColor(_ role: SupervisorRole) -> Color {
    switch role {
    case .ug:     return Color.green.opacity(0.35)
    case .aerial: return Color.blue.opacity(0.35)
    case .can:    return Color.orange.opacity(0.35)
    case .nid:    return Color.purple.opacity(0.35)
    }
}

// MARK: - View

struct SupervisorDashboardView: View {
    @EnvironmentObject var usersViewModel: UsersViewModel
    @EnvironmentObject var authViewModel:  AuthViewModel
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @StateObject private var vm = SupervisorJobsViewModel()
    @State private var showingCreate = false
    @State private var showingImport = false

    @State private var role: SupervisorRole = .ug
    @State private var status: StatusFilter = .all
    @State private var searchText = ""

    @State private var dateRange: DateInterval = {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date()))!
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        return DateInterval(start: start, end: end)
    }()

    var body: some View {
        ZStack {
            // App-wide gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.1725, green: 0.2431, blue: 0.3137),
                    Color(red: 0.2980, green: 0.6314, blue: 0.6863)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Title
                    HStack {
                        Text("Supervisor")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.top, 8)

                    // Search
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search address, job #, notes…", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Filters card
                    filtersCard

                    // Summary chips
                    summaryRow
                        .padding(.top, 4)

                    // Pending section
                    if !pendingJobs.isEmpty {
                        sectionHeader("Not Completed")
                        let pendingGroups = groupedByDay(pendingJobs).sorted { lhs, rhs in lhs.key > rhs.key }
                        VStack(spacing: 12) {
                            ForEach(pendingGroups, id: \.key) { day, jobs in
                                dayHeader(day)
                                ForEach(jobs, id: \.id) { job in
                                    SupervisorJobRow(
                                        job: job,
                                        userRoleResolver: resolveRole(forUserId:),
                                        userNameResolver: resolveUserName(forUserId:)
                                    )
                                }
                            }
                        }
                    }

                    // Completed section
                    if !completedJobs.isEmpty {
                        sectionHeader("Completed")
                        let completedGroups = groupedByDay(completedJobs).sorted { lhs, rhs in lhs.key > rhs.key }
                        VStack(spacing: 12) {
                            ForEach(completedGroups, id: \.key) { day, jobs in
                                dayHeader(day)
                                ForEach(jobs, id: \.id) { job in
                                    SupervisorJobRow(
                                        job: job,
                                        userRoleResolver: resolveRole(forUserId:),
                                        userNameResolver: resolveUserName(forUserId:)
                                    )
                                }
                            }
                        }
                    }

                    if pendingJobs.isEmpty && completedJobs.isEmpty && !vm.isLoading {
                        Text("No jobs match these filters.")
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 56)
                .padding(.bottom, 24)
            }
        }
        .onAppear { vm.start(range: dateRange) }
        .onDisappear { vm.stop() }
        .onChange(of: dateRange) { _ in vm.start(range: dateRange) }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if authViewModel.isSupervisorFlag || authViewModel.isAdminFlag {
                    Menu {
                        Button("Create Single Job") { showingCreate = true }
                        Button("Import Job Sheet") { showingImport = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create or Import Job")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            SupervisorCreateJobView()
                .environmentObject(jobsViewModel)
                .environmentObject(authViewModel)
                .environmentObject(usersViewModel)
        }
        .sheet(isPresented: $showingImport) {
            if authViewModel.isSupervisorFlag || authViewModel.isAdminFlag {
                SupervisorJobImportView()
                    .environmentObject(jobsViewModel)
                    .environmentObject(authViewModel)
                    .environmentObject(usersViewModel)
            } else {
                Text("Unauthorized")
            }
        }
    }

    // MARK: – Styled sections matching Dashboard
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title3).bold()
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.top, 8)
    }

    private func dayHeader(_ date: Date) -> some View {
        HStack {
            Text(dayString(date))
                .font(.subheadline).bold()
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
    }

    // Filters shown as a card instead of a DisclosureGroup
    private var filtersCard: some View {
        VStack(spacing: 12) {
            // Role tabs
            Picker("Role", selection: $role) {
                ForEach(SupervisorRole.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            // Status tabs
            Picker("Status", selection: $status) {
                ForEach(StatusFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            // Date range row + quick presets
            HStack(spacing: 12) {
                Menu {
                    Button("Today") { setPresetToday() }
                    Button("Last 7 days") { setPreset(days: 7) }
                    Button("Last 14 days") { setPreset(days: 14) }
                    Button("This month") { setPresetThisMonth() }
                } label: {
                    Label("Quick Range", systemImage: "calendar.badge.clock")
                        .foregroundColor(.white)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                DatePicker(
                    "From",
                    selection: Binding(get: { dateRange.start }, set: { dateRange = DateInterval(start: $0, end: dateRange.end) }),
                    displayedComponents: .date
                )
                .labelsHidden()
                DatePicker(
                    "To",
                    selection: Binding(get: { dateRange.end }, set: { dateRange = DateInterval(start: dateRange.start, end: $0) }),
                    displayedComponents: .date
                )
                .labelsHidden()
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func setPreset(days: Int) {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let start = cal.date(byAdding: .day, value: -max(1, days-1), to: cal.startOfDay(for: Date()))!
        dateRange = DateInterval(start: start, end: end)
        vm.start(range: dateRange)
    }

    private func setPresetThisMonth() {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let start = cal.date(from: comps) ?? cal.startOfDay(for: now)
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? now
        dateRange = DateInterval(start: start, end: end)
        vm.start(range: dateRange)
    }

    private func setPresetToday() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        dateRange = DateInterval(start: start, end: end)
        vm.start(range: dateRange)
    }

    // MARK: Derived sets

    private var filteredForRole: [Job] {
        // Treat a job as part of a role if creator or assignee has that role.
        vm.jobs.filter { job in
            let createdRole  = resolveRole(forUserId: job.createdBy)
            let assignedRole = resolveRole(forUserId: job.assignedTo)
            return createdRole == role.rawValue || assignedRole == role.rawValue
        }
    }

    private var filteredByStatus: [Job] {
        switch status {
        case .all: return filteredForRole
        case .pending: return filteredForRole.filter { $0.status.lowercased() == "pending" }
        case .completed: return filteredForRole.filter { $0.status.lowercased() != "pending" }
        }
    }

    private var searched: [Job] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return filteredByStatus }
        return filteredByStatus.filter { job in
            job.address.lowercased().contains(q)
            || (job.jobNumber ?? "").lowercased().contains(q)
            || (job.notes ?? "").lowercased().contains(q)
        }
    }

    private var pendingJobs: [Job] {
        searched.filter { $0.status.lowercased() == "pending" }
    }

    private var completedJobs: [Job] {
        searched.filter { $0.status.lowercased() != "pending" }
    }

    private func groupedByDay(_ jobs: [Job]) -> [Date: [Job]] {
        Dictionary(grouping: jobs) { Calendar.current.startOfDay(for: $0.date) }
    }

    private func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE MMM d"
        return f.string(from: date)
    }

    private func resolveRole(forUserId uid: String?) -> String {
        guard let uid = uid, let user = usersViewModel.user(id: uid) else {
            return ""
        }
        let pos = user.position.trimmingCharacters(in: .whitespacesAndNewlines)
        return pos.caseInsensitiveCompare("Ariel") == .orderedSame ? "Aerial" : pos
    }

    private func resolveUserName(forUserId uid: String?) -> String {
        guard let uid = uid, let user = usersViewModel.user(id: uid) else { return "" }
        let first = user.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last  = user.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        return [first, last].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // Summary chips
    private var summaryRow: some View {
        HStack(spacing: 12) {
            chip("\(filteredForRole.count) jobs", system: "tray.full")
            chip("\(pendingJobs.count) pending", system: "clock")
            chip("\(completedJobs.count) completed", system: "checkmark.circle")
            Spacer()
        }
    }

    private func chip(_ text: String, system: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system)
            Text(text)
        }
        .font(.caption)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.15))
        .clipShape(Capsule())
        .foregroundColor(.white)
    }
}

// MARK: - Row

private struct SupervisorJobRow: View {
    let job: Job
    let userRoleResolver: (String?) -> String
    let userNameResolver: (String?) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(job.address)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(job.status)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(job.status.lowercased() == "pending" ? Color.orange.opacity(0.35) : Color.teal.opacity(0.35))
                    .clipShape(Capsule())
            }

            HStack(spacing: 10) {
                if let jn = job.jobNumber, !jn.isEmpty {
                    Label(jn, systemImage: "number.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Label(dateString(job.date), systemImage: "calendar")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Prefer assignedTo name; fall back to creator
                let workerName = !((job.assignedTo ?? "").isEmpty) ? userNameResolver(job.assignedTo) : userNameResolver(job.createdBy)
                if !workerName.isEmpty {
                    Label(workerName, systemImage: "person")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                let creatorRole = userRoleResolver(job.createdBy)
                if !creatorRole.isEmpty {
                    Label(creatorRole, systemImage: "person.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let assignee = job.assignedTo, !assignee.isEmpty {
                    let role = userRoleResolver(assignee)
                    if !role.isEmpty {
                        Label("→ \(role)", systemImage: "arrowshape.turn.up.right.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text(String(format: "%.1f h", job.hours))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.30))
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        )
    }

    private func dateString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: d)
    }
}

// MARK: - Role filter (local to create view)
private enum RoleFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case underground = "UG"
    case aerial = "Aerial"
    case can = "Can"
    case nid = "Nid"
    var id: String { rawValue }
}

// MARK: - Supervisor Create Job
struct SupervisorCreateJobView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var usersViewModel: UsersViewModel

    // Allow prefill from Import/Review flow
    init(
        prefillAddress: String? = nil,
        prefillDate: Date? = nil,
        prefillJobNumber: String? = nil,
        prefillUserID: String? = nil,
        prefillNotes: String? = nil
    ) {
        _address = State(initialValue: prefillAddress ?? "")
        _date = State(initialValue: prefillDate ?? Date())
        _jobNumber = State(initialValue: prefillJobNumber ?? "")
        _selectedUserID = State(initialValue: prefillUserID)
        _notes = State(initialValue: prefillNotes ?? "")
    }

    // Role filter for users
    @State private var roleFilter: RoleFilter = .all

    // Form fields
    @State private var address = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var materialsUsed = ""
    @State private var jobNumber = ""
    @State private var assignmentsText: String = ""
    @State private var selectedUserID: String? = nil
    @State private var showUserPicker = false

    @FocusState private var isAssignmentsFocused: Bool
    @FocusState private var isAddressFocused: Bool

    // Reuse autocomplete
    @StateObject private var addressSearch = AddressSearchCompleter()
    @StateObject private var locationProvider = LocationProvider()

    @State private var showAlert = false

    // No statusOptions needed; status always Pending

    private var selectedUserName: String {
        guard let id = selectedUserID, let u = usersViewModel.user(id: id) else { return "Unassigned" }
        let first = u.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last  = u.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Unassigned" : name
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.1725, green: 0.2431, blue: 0.3137),
                        Color(red: 0.2980, green: 0.6314, blue: 0.6863)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Form {
                    // Worker Role filter
                    Section(header: Text("Worker Role")) {
                        Picker("Role", selection: $roleFilter) {
                            ForEach(RoleFilter.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Assign to user (filtered by role)
                    Section(header: Text("Assign To")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedUserName)
                                    .font(.body)
                                Text(roleFilter == .all ? "Choose from all users" : "Filtered by \(roleFilter.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button {
                                showUserPicker = true
                            } label: {
                                Label("Select", systemImage: "person.crop.circle.badge.plus")
                            }
                        }
                    }

                    // Address with suggestions
                    Section(header: Text("Address")) {
                        ZStack(alignment: .topLeading) {
                            TextField("Enter address", text: $address)
                                .disableAutocorrection(true)
                                .textInputAutocapitalization(.never)
                                .focused($isAddressFocused)
                                .onChange(of: address) { newValue in
                                    if newValue.trimmingCharacters(in: .whitespaces).count >= 3 {
                                        addressSearch.update(query: newValue)
                                    } else {
                                        addressSearch.results = []
                                    }
                                }
                                .onAppear { locationProvider.request() }
                                .onChange(of: addressSearch.results) { _ in
                                    addressSearch.updateDistances(from: locationProvider.location)
                                }
                                .onChange(of: locationProvider.location) { _ in
                                    addressSearch.updateDistances(from: locationProvider.location)
                                }

                            if isAddressFocused && !addressSearch.results.isEmpty {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(addressSearch.results.prefix(6).enumerated()), id: \.offset) { _, item in
                                        Button(action: {
                                            address = item.subtitle.isEmpty ? item.title : "\(item.title) \(item.subtitle)"
                                            addressSearch.results = []
                                            isAddressFocused = false
                                            UIApplication.shared.endEditing()
                                        }) {
                                            HStack(alignment: .center, spacing: 10) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(item.title).font(.body)
                                                    if !item.subtitle.isEmpty {
                                                        Text(item.subtitle).font(.caption).foregroundColor(.secondary)
                                                    }
                                                }
                                                Spacer()
                                                let key = item.subtitle.isEmpty ? item.title : "\(item.title) \(item.subtitle)"
                                                if let miles = addressSearch.distances[key] {
                                                    Text(String(format: "%.1f mi", miles))
                                                        .font(.caption.bold())
                                                        .padding(.vertical, 5)
                                                        .padding(.horizontal, 8)
                                                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                                                        .overlay(Capsule().stroke(Color.gray.opacity(0.25)))
                                                }
                                            }
                                            .padding(.vertical, 10)
                                            .padding(.horizontal, 12)
                                            .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.plain)

                                        if item != addressSearch.results.prefix(6).last {
                                            Divider().padding(.leading, 12)
                                        }
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                        .shadow(radius: 6)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2))
                                )
                                .padding(.top, 44)
                            }
                        }
                    }

                    Section(header: Text("Date")) {
                        DatePicker("Select Date", selection: $date, displayedComponents: [.date])
                            .datePickerStyle(.compact)
                    }

                    Section(header: Text("Job Number *")) {
                        TextField("Required", text: $jobNumber)
                    }

                    Section(header: Text("Materials Used")) {
                        TextField("Enter materials info…", text: $materialsUsed)
                    }

                    Section(header: Text("Notes")) {
                        TextEditor(text: $notes).frame(minHeight: 80)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveJob() }
                        .disabled(jobNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showUserPicker) {
                UserSelectSheet(
                    users: filteredUsers,
                    selectedUserID: $selectedUserID
                )
                .presentationDetents([.medium, .large])
                .environmentObject(usersViewModel)
            }
        }
    }

    // Filter users by selected roleFilter (normalize legacy spellings)
    private var filteredUsers: [AppUser] {
        let users = usersViewModel.allUsers
        let base: [AppUser]
        switch roleFilter {
        case .all:
            base = users
        case .underground, .aerial, .can, .nid:
            base = users.filter { user in
                let pos = user.position.trimmingCharacters(in: .whitespacesAndNewlines)
                let norm = pos.caseInsensitiveCompare("Ariel") == .orderedSame ? "Aerial" : pos
                return norm.caseInsensitiveCompare(roleFilter.rawValue) == .orderedSame
            }
        }
        return base.sorted { ($0.firstName + $0.lastName)
            .localizedCaseInsensitiveCompare($1.firstName + $1.lastName) == .orderedAscending }
    }

    private func saveJob() {
        guard let supervisorID = authViewModel.currentUser?.id else { dismiss(); return }

        // New jobs created by supervisors always start as Pending
        let finalStatus = "Pending"

        CLGeocoder().geocodeAddressString(address) { placemarks, _ in
            let coord = placemarks?.first?.location?.coordinate

            let job = Job(
                address: address,
                date: date,
                status: finalStatus,
                assignedTo: selectedUserID,
                createdBy: supervisorID,
                notes: notes,
                jobNumber: jobNumber.isEmpty ? nil : jobNumber,
                assignments: assignmentsText.isEmpty ? nil : assignmentsText,
                materialsUsed: materialsUsed,
                latitude: coord?.latitude,
                longitude: coord?.longitude
            )
            DispatchQueue.main.async {
                jobsViewModel.createJob(job)
                dismiss()
            }
        }
    }
}

// MARK: - User selector sheet
private struct UserSelectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var usersViewModel: UsersViewModel

    let users: [AppUser]
    @Binding var selectedUserID: String?
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedUserID = nil
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle")
                            Text("Unassigned")
                            if selectedUserID == nil { Spacer(); Image(systemName: "checkmark").foregroundColor(.accentColor) }
                        }
                    }
                }

                Section(header: Text("Users")) {
                    ForEach(filtered, id: \.id) { u in
                        Button {
                            selectedUserID = u.id
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .imageScale(.large)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(u.firstName) \(u.lastName)")
                                    Text(normalizedRole(u.position))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if selectedUserID == u.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose User")
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search users…")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var filtered: [AppUser] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return users }
        return users.filter { u in
            let name = (u.firstName + " " + u.lastName).lowercased()
            return name.contains(q)
        }
    }

    private func normalizedRole(_ s: String) -> String {
        let pos = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return pos.caseInsensitiveCompare("Ariel") == .orderedSame ? "Aerial" : pos
    }
}
