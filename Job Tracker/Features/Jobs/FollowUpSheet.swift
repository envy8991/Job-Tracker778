import SwiftUI

struct FollowUpSheet: View {
    let job: Job
    let statusReason: String
    let users: [AppUser]
    let onSave: (JobFollowUp) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var assignedUserID = ""
    @State private var dueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var notificationPreference: JobFollowUp.NotificationPreference = .dueDate

    var body: some View {
        NavigationStack {
            Form {
                Section("Follow-up (optional)") {
                    Text(statusReason).font(.subheadline).foregroundStyle(.secondary)
                    Picker("Responsible", selection: $assignedUserID) {
                        Text("Choose a person").tag("")
                        ForEach(users) { user in
                            Text("\(user.firstName) \(user.lastName) · \(user.normalizedPosition)").tag(user.id)
                        }
                    }
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    Picker("Reminder", selection: $notificationPreference) {
                        ForEach(JobFollowUp.NotificationPreference.allCases, id: \.self) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                }
            }
            .navigationTitle("Add Follow-up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Not Now") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let now = Date()
                        onSave(JobFollowUp(reason: statusReason, assignedUserID: assignedUserID, dueDate: dueDate,
                                           createdAt: now, updatedAt: now, completedAt: nil,
                                           notificationPreference: notificationPreference))
                        dismiss()
                    }.disabled(assignedUserID.isEmpty)
                }
            }
        }.presentationDetents([.medium])
    }
}

struct FollowUpDashboardSection: View {
    let jobs: [Job]
    let users: [String: AppUser]
    let onSelect: (Job) -> Void
    @State private var query = ""
    @State private var filter: Filter = .all
    enum Filter: String, CaseIterable { case all = "All", overdue = "Overdue", today = "Due Today" }

    private var visible: [Job] {
        jobs.filter { job in
            guard let item = job.followUp, !item.isCompleted, item.isOverdue() || item.isDueToday() else { return false }
            let correctKind = filter == .all || (filter == .overdue ? item.isOverdue() : item.isDueToday())
            let text = "\(job.address) \(item.reason) \(users[item.assignedUserID]?.firstName ?? "")"
            return correctKind && (query.isEmpty || text.localizedCaseInsensitiveContains(query))
        }.sorted { ($0.followUp?.dueDate ?? .distantFuture) < ($1.followUp?.dueDate ?? .distantFuture) }
    }

    var body: some View {
        if !visible.isEmpty || !query.isEmpty {
            VStack(alignment: .leading, spacing: JTSpacing.sm) {
                Label("Follow-ups", systemImage: "bell.badge").font(JTTypography.headline).foregroundStyle(JTColors.textPrimary)
                TextField("Search follow-ups", text: $query).textFieldStyle(.roundedBorder)
                Picker("Filter", selection: $filter) { ForEach(Filter.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                ForEach(visible) { job in
                    Button { onSelect(job) } label: {
                        HStack {
                            Image(systemName: job.followUp?.isOverdue() == true ? "exclamationmark.circle.fill" : "calendar.badge.clock")
                                .foregroundStyle(job.followUp?.isOverdue() == true ? .red : .orange)
                            VStack(alignment: .leading) {
                                Text(job.shortAddress).font(.subheadline.bold())
                                Text("\(job.followUp?.reason ?? "") · \(job.followUp?.dueDate.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }.buttonStyle(.plain)
                }
            }.padding().jtGlassBackground(shape: RoundedRectangle(cornerRadius: JTShapes.cardCornerRadius))
        }
    }
}
