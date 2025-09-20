import SwiftUI

struct PastTimesheetsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var timesheetListVM = UserTimesheetsViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient (same as Dashboard/CreateJobView)
                JTGradients.background(stops: 4)
                .edgesIgnoringSafeArea(.all)
                
                List {
                    ForEach(timesheetListVM.timesheets) { timesheet in
                        NavigationLink(destination: TimesheetDetailView(timesheet: timesheet)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Week Starting: \(formattedDate(timesheet.weekStart))")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Total Hours: \(timesheet.totalHours)")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                if let pdfURL = timesheet.pdfURL, !pdfURL.isEmpty {
                                    Text("PDF Created")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("No PDF Available")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteSheet)
                }
                .listStyle(GroupedListStyle())
                // This modifier makes the List’s background transparent.
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Past Timesheets")
            .onAppear {
                if let user = authViewModel.currentUser {
                    timesheetListVM.fetchTimesheets(for: user.id)
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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
