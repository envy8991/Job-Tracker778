import SwiftUI
import FirebaseStorage

struct YellowSheetView: View {
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var yellowSheetsVM = UserYellowSheetsViewModel()
    
    // This date determines the current week boundaries.
    @State private var selectedDate = Date()
    // Controls whether the full calendar is shown.
    @State private var showCalendar: Bool = false
    
    // State for showing an alert after saving.
    @State private var showSaveAlert = false
    @State private var partnerUid: String? = nil
    @State private var saveAlertMessage = ""
    
    private var topContentPadding: CGFloat {
        horizontalSizeClass == .compact ? 72 : 32
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient.
                JTGradients.background(stops: 4)
                .ignoresSafeArea()
                
                VStack {
                    // Minimal Week Picker
                    minimalWeekPicker

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(sortedJobGroups, id: \.key) { group in
                                Section(header: Text("Job Number: \(group.key)")
                                            .font(.headline)
                                            .foregroundColor(JTColors.textPrimary)
                                            .padding(.vertical, 4)) {
                                    ForEach(group.value) { job in
                                        YellowSheetJobCard(job: job)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.top)
                    }
                    
                    Button("Save Yellow Sheet") {
                        saveCurrentYellowSheet()
                    }
                    .foregroundColor(JTColors.onAccent)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(JTColors.accent.opacity(0.9))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }
                .padding(.top, topContentPadding)
            }
            .navigationTitle("     ")
            .onAppear {
                if let me = authViewModel.currentUser?.id {
                    FirebaseService.shared.fetchPartnerId(for: me) { pid in
                        DispatchQueue.main.async { self.partnerUid = pid }
                    }
                } else {
                    self.partnerUid = nil
                }
                jobsViewModel.fetchJobsForWeek(selectedDate)
            }
            .onChange(of: selectedDate) { _ in
                jobsViewModel.fetchJobsForWeek(selectedDate)
            }
            .onReceive(authViewModel.$currentUser) { _ in
                if let me = authViewModel.currentUser?.id {
                    FirebaseService.shared.fetchPartnerId(for: me) { pid in
                        DispatchQueue.main.async { self.partnerUid = pid }
                    }
                } else {
                    self.partnerUid = nil
                }
            }
            .alert(isPresented: $showSaveAlert) {
                Alert(title: Text("Yellow Sheet"), message: Text(saveAlertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        // Full calendar sheet.
        .sheet(isPresented: $showCalendar) {
            NavigationView {
                DatePicker("Select a Date", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .navigationTitle("Select Week")
                    .navigationBarItems(trailing: Button("Done") {
                        showCalendar = false
                    })
                    .padding()
            }
        }
    }
    
    // Compute the Sunday (start) of the selected week.
    private var startOfWeek: Date {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: selectedDate)
        let offset = weekday - 1  // Sunday is 1
        return calendar.date(byAdding: .day, value: -offset, to: selectedDate) ?? selectedDate
    }
    
    private var endOfWeek: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? startOfWeek
    }
    
    // Array of dates for Sunday → Saturday.
    private var weekdays: [Date] {
        (0..<7).compactMap { i in
            Calendar.current.date(byAdding: .day, value: i, to: startOfWeek)
        }
    }
    
    // Minimal Week Picker with left/right arrows and a tappable center label.
    private var minimalWeekPicker: some View {
        HStack {
            Button(action: {
                if let newDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) {
                    selectedDate = newDate
                }
            }) {
                Image(systemName: "chevron.left")
                    .padding(8)
            }
            Spacer(minLength: 0)
            Button(action: {
                showCalendar = true
            }) {
                Text("Week of \(formattedDate(startOfWeek))")
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundColor(.white)
            }
            Spacer(minLength: 0)
            Button(action: {
                if let newDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) {
                    selectedDate = newDate
                }
            }) {
                Image(systemName: "chevron.right")
                    .padding(8)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func filteredJobs() -> [Job] {
        guard let me = authViewModel.currentUser?.id else { return [] }
        let other = partnerUid
        let cal = Calendar.current
        return jobsViewModel.jobs.filter { job in
            let mine = (job.createdBy == me || job.assignedTo == me)
            let partners = (other != nil) && (job.createdBy == other || job.assignedTo == other)
            let inWeek = cal.isDate(job.date, inSameDayAs: startOfWeek) ||
                         (job.date >= startOfWeek && job.date <= endOfWeek)
            let notPending = job.status.lowercased() != "pending"
            return (mine || partners) && inWeek && notPending
        }
    }
    
    private var sortedJobGroups: [(key: String, value: [Job])] {
        let groups = Dictionary(grouping: filteredJobs()) { job in
            let jobNum = job.jobNumber?.isEmpty == false ? job.jobNumber! : "No Job Number"
            return jobNum
        }
        return groups.sorted { $0.key < $1.key }
    }
    
    private func saveCurrentYellowSheet() {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return }
        let weekStart = weekInterval.start
        let totalJobs = filteredJobs().count
        guard let currentUserID = authViewModel.currentUser?.id,
              let currentUser = authViewModel.currentUser else { return }
        let ownerId: String = {
            if let p = partnerUid, !p.isEmpty { return [currentUserID, p].sorted().first ?? currentUserID }
            return currentUserID
        }()
        var sheet = YellowSheet(
            userId: ownerId,
            partnerId: partnerUid,
            weekStart: weekStart,
            totalJobs: totalJobs,
            pdfURL: nil
        )
        let pdfGenerator = YellowSheetPDFGenerator(weekStart: weekStart, jobs: filteredJobs(), user: currentUser)
        guard let pdfFileURL = pdfGenerator.generatePDF() else {
            saveAlertMessage = "Failed to generate PDF."
            showSaveAlert = true
            return
        }
        uploadPDF(data: try? Data(contentsOf: pdfFileURL), timesheetId: "\(ownerId)_\(weekStartString(from: weekStart))") { downloadURL in
            if let downloadURL = downloadURL {
                sheet.pdfURL = downloadURL
                yellowSheetsVM.saveYellowSheet(sheet) { success in
                    DispatchQueue.main.async {
                        saveAlertMessage = success ? "Yellow Sheet saved successfully!" : "Failed to save Yellow Sheet."
                        showSaveAlert = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    saveAlertMessage = "Failed to upload PDF."
                    showSaveAlert = true
                }
            }
        }
    }
    
    private func weekStartString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func uploadPDF(data: Data?, timesheetId: String, completion: @escaping (String?) -> Void) {
        guard let data = data else {
            completion(nil)
            return
        }
        let storageRef = Storage.storage().reference().child("yellowSheets/\(timesheetId).pdf")
        storageRef.putData(data, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading PDF: \(error)")
                completion(nil)
                return
            }
            storageRef.downloadURL { url, error in
                if let error = error {
                    print("Error fetching download URL: \(error)")
                    completion(nil)
                } else if let url = url {
                    completion(url.absoluteString)
                } else {
                    completion(nil)
                }
            }
        }
    }
}
