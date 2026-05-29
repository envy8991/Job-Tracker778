import SwiftUI

struct PastTimesheetsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var timesheetListVM = UserTimesheetsViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                JTGradients.background(stops: 4)
                    .ignoresSafeArea()

                List {
                    ForEach(timesheetListVM.timesheets) { timesheet in
                        NavigationLink(destination: TimesheetDetailView(timesheet: timesheet)) {
                            PastTimesheetRow(timesheet: timesheet)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteSheet)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Past Timesheets")
            .navigationBarTitleDisplayMode(.inline)
            .jtNavigationBarStyle()
            .onAppear {
                if let user = authViewModel.currentUser {
                    timesheetListVM.fetchTimesheets(for: user.id)
                }
            }
        }
    }

    private func deleteSheet(at offsets: IndexSet) {
        offsets.forEach { index in
            let sheet = timesheetListVM.timesheets[index]
            if let id = sheet.id {
                timesheetListVM.deleteTimesheet(documentID: id) { success in
                    if !success {
                        print("Failed to delete timesheet with id \(id)")
                    }
                }
            }
        }
        timesheetListVM.timesheets.remove(atOffsets: offsets)
    }
}

private struct PastTimesheetRow: View {
    let timesheet: Timesheet

    var body: some View {
        VStack(alignment: .leading, spacing: JTSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Week Starting: \(formattedDate(timesheet.weekStart))")
                    .font(JTTypography.headline)
                    .foregroundStyle(JTColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(JTColors.textMuted)
            }

            Text("Total Hours: \(timesheet.totalHours)")
                .font(JTTypography.subheadline)
                .foregroundStyle(JTColors.textSecondary)

            Label(timesheet.pdfURL?.isEmpty == false ? "PDF Created" : "No PDF Available",
                  systemImage: timesheet.pdfURL?.isEmpty == false ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(JTTypography.caption)
                .foregroundStyle(timesheet.pdfURL?.isEmpty == false ? JTColors.success : JTColors.error)
        }
        .padding(.vertical, JTSpacing.sm)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
