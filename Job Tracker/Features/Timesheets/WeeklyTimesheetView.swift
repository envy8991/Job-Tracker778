import SwiftUI
import PDFKit
import UIKit   // for haptics

// MARK: - Model for header rows
// Each worker has separate Gibson and CS hours.
// Row total is computed as gibson + cs.
struct WorkerHours: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var gibson: String
    var cs: String
    var total: Double { (Double(gibson) ?? 0) + (Double(cs) ?? 0) }
}

struct WeeklyTimesheetView: View {
    // Top padding to provide breathing room above the week picker and action buttons.
    private let topContentPadding: CGFloat = 20
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject private var navigation: AppNavigationViewModel
    // Use an independent view model for timesheet jobs.
    @StateObject private var timesheetJobsVM = TimesheetJobsViewModel()
    @StateObject private var timesheetVM = TimesheetViewModel()
    
    // Top fields (Supervisor, etc.)
    @State private var supervisor = ""
    
    // Two users max (matches header design)
    @State private var workers: [WorkerHours] = [
        WorkerHours(name: "", gibson: "", cs: ""),
        WorkerHours(name: "", gibson: "", cs: "")
    ]
    
    // For editing a job (when tapped)
    @State private var selectedJob: Job? = nil
    
    // Dictionary to hold daily total hours keyed by each day’s start.
    @State private var dailyTotalHours: [Date: String] = [:]
    
    // For PDF preview / printing
    @State private var showPDFPreview = false
    @State private var previewURL: URL? = nil
    @State private var partnerUid: String? = nil
    
    // State for selecting the week.
    @State private var selectedDate = Date()
    // Controls whether the full calendar is shown.
    @State private var showCalendar: Bool = false
    
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
    
    /// Sum of all daily totals (as Doubles); falls back to job hours if custom total missing.
    private var weeklyTotalHours: Double {
        weekdays.reduce(0) { running, day in
            let key = Calendar.current.startOfDay(for: day)
            if let str = dailyTotalHours[key], let val = Double(str) {
                return running + val
            } else {
                let daySum = filteredJobs(for: day).reduce(0.0) { $0 + $1.hours }
                return running + daySum
            }
        }
    }
    
    // Grand total across both users in the header
    private var workersTotalHours: Double {
        workers.reduce(0.0) { $0 + $1.total }
    }
    
    // Array of dates for Sunday → Saturday.
    private var weekdays: [Date] {
        (0..<7).compactMap { i in
            Calendar.current.date(byAdding: .day, value: i, to: startOfWeek)
        }
    }
    
    // MARK: - Minimal Week Picker with Calendar Sheet
    private var minimalWeekPicker: some View {
        HStack {
            Button(action: {
                if let newDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) {
                    selectedDate = newDate
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }) {
                Image(systemName: "chevron.left")
                    .padding(8)
                    .foregroundStyle(JTColors.textPrimary)
            }
            Spacer(minLength: 0)
            // Tappable center label shows the week start.
            Button(action: {
                showCalendar = true
            }) {
                Text("Week of \(formattedDate(startOfWeek))")
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(JTColors.textPrimary)
            }
            Spacer(minLength: 0)
            Button(action: {
                if let newDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) {
                    selectedDate = newDate
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }) {
                Image(systemName: "chevron.right")
                    .padding(8)
                    .foregroundStyle(JTColors.textPrimary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(JTColors.glassStroke, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient matching your Dashboard and CreateJobView.
                JTGradients.background(stops: 4)
                    .edgesIgnoringSafeArea(.all)
                RadialGradient(colors: [JTColors.textPrimary.opacity(0.05), .clear], center: .topLeading, startRadius: 0, endRadius: 400)
                    .allowsHitTesting(false)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Minimal week picker.
                        minimalWeekPicker

                        // Global quick actions placed below the week picker to avoid overlaps.
                        ShellActionButtons(
                            onShowMenu: { navigation.isPrimaryMenuPresented = true },
                            onOpenHelp: { navigation.navigate(to: .helpCenter) },
                            horizontalPadding: 0,
                            topPadding: 0
                        )

                        // Timesheet header.
                        timesheetHeader
                        
                        Text("Gibson Connect Weekly")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(JTColors.textPrimary)
                        
                        // Display each day in a vertical list (Sun → Sat) with shadow
                        ForEach(weekdays, id: \.self) { day in
                            DayTimesheetBox(
                                date: day,
                                jobs: filteredJobs(for: day),
                                totalHoursEditable: bindingFor(day: day),
                                onJobTap: { tappedJob in
                                    selectedJob = tappedJob
                                }
                            )
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 4)
                            .padding(.bottom, 12)
                        }
                        
                        Spacer().frame(height: 100)
                    }
                    // Provide consistent spacing above the week picker and action buttons
                    .padding(.top, topContentPadding)
                    .padding()
                }
                .scrollIndicators(.hidden)
                .overlay(alignment: .bottom) {
                    HStack {
                        Spacer()
                        Text("Total: \(String(format: "%.1f", weeklyTotalHours)) hrs")
                            .font(.headline)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                    .background(.ultraThinMaterial)
                    .overlay(
                        Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.5), alignment: .top
                    )
                }
            }
            .navigationTitle("Timesheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Generate the PDF off-main-thread.
                        DispatchQueue.global(qos: .userInitiated).async {
                            if let url = generatePDF() {
                                DispatchQueue.main.async {
                                    previewURL = url
                                    // Give the system ~300 ms to load the PDF before showing the sheet.
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        showPDFPreview = true
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "doc.richtext")
                    }
                }
            }
            // Job editing sheet.
            .sheet(item: $selectedJob) { job in
                if let index = timesheetJobsVM.jobs.firstIndex(where: { $0.id == job.id }) {
                    JobEditView(job: $timesheetJobsVM.jobs[index])
                        .environmentObject(timesheetJobsVM)
                } else {
                    Text("Job not found.")
                }
            }
            .sheet(isPresented: $showPDFPreview) {
                if let url = previewURL {
                    PDFPreviewSheet(pdfURL: url) {
                        printPDF(url: url)
                    }
                }
            }
            .onAppear {
                if let me = authViewModel.currentUser?.id {
                    FirebaseService.shared.fetchPartnerId(for: me) { pid in
                        DispatchQueue.main.async { self.partnerUid = pid }
                    }
                } else {
                    self.partnerUid = nil
                }
                loadTimesheet()
            }
            .onChange(of: selectedDate) { _ in
                loadTimesheet()
            }
            .onReceive(timesheetVM.$timesheet) { newTimesheet in
                if let ts = newTimesheet {
                    supervisor = ts.supervisor
                    // Map legacy name1/2 into the new workers array (hours start empty)
                    var newWorkers: [WorkerHours] = []
                    if !ts.name1.isEmpty { newWorkers.append(WorkerHours(name: ts.name1, gibson: "", cs: "")) }
                    if !ts.name2.isEmpty { newWorkers.append(WorkerHours(name: ts.name2, gibson: "", cs: "")) }
                    if newWorkers.isEmpty {
                        newWorkers = [WorkerHours(name: "", gibson: "", cs: ""),
                                      WorkerHours(name: "", gibson: "", cs: "")]
                    }
                    workers = Array(newWorkers.prefix(2))
                }
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
        }
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
}

extension WeeklyTimesheetView {
    // MARK: - Header with Name | Gibson | CS | Total
    private var timesheetHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Supervisor row
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Supervisor:").foregroundColor(.white)
                TextField("", text: $supervisor)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Column headers + rows (Name expands; other columns fixed so it always fits)
            let gibsonWidth: CGFloat = 64
            let csWidth: CGFloat = 84
            let totalWidth: CGFloat = 64
            let rowSpacing: CGFloat = 8

            // Header row
            HStack(spacing: rowSpacing) {
                Text("Name")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                Text("Gibson")
                    .foregroundColor(.white)
                    .frame(width: gibsonWidth, alignment: .leading)
                Text("CS Hours")
                    .foregroundColor(.white)
                    .frame(width: csWidth, alignment: .leading)
                Text("Total")
                    .foregroundColor(.white)
                    .frame(width: totalWidth, alignment: .leading)
            }
            .font(.subheadline)
            .opacity(0.9)
            .padding(.bottom, 4)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.5)
                    .padding(.top, 28), alignment: .bottom
            )

            // Rows aligned to header widths
            VStack(alignment: .leading, spacing: rowSpacing) {
                ForEach($workers) { $worker in
                    HStack(spacing: rowSpacing) {
                        // Name expands to fill remaining width
                        TextField("Name", text: $worker.name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: .infinity)
                            .lineLimit(1)
                            .layoutPriority(1)

                        TextField("0", text: $worker.gibson)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: gibsonWidth)

                        TextField("0", text: $worker.cs)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: csWidth)

                        Text(String(format: "%.1f", worker.total))
                            .frame(width: totalWidth, alignment: .leading)
                            .foregroundColor(.white)
                            .font(.headline)

                        Button(role: .destructive) {
                            if let idx = workers.firstIndex(where: { $0.id == worker.id }), workers.count > 1 {
                                workers.remove(at: idx)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .opacity(workers.count > 1 ? 1 : 0.3)
                        .disabled(workers.count <= 1)
                    }
                }

                Button {
                    if workers.count < 2 { workers.append(WorkerHours(name: "", gibson: "", cs: "")) }
                } label: {
                    Label("Add Name", systemImage: "plus.circleFill")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.white)
                .opacity(workers.count < 2 ? 1 : 0.3)
                .disabled(workers.count >= 2)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func filteredJobs(for day: Date) -> [Job] {
        guard let me = authViewModel.currentUser?.id else { return [] }
        let other = partnerUid
        return timesheetJobsVM.jobs.filter { job in
            let mine = (job.createdBy == me || job.assignedTo == me)
            let partners = (other != nil) && (job.createdBy == other || job.assignedTo == other)
            return (mine || partners)
                && Calendar.current.isDate(job.date, inSameDayAs: day)
                && job.status.lowercased() != "pending"
        }
    }
    
    private func bindingFor(day: Date) -> Binding<String> {
        let key = Calendar.current.startOfDay(for: day)
        return Binding<String>(
            get: {
                if let value = dailyTotalHours[key] {
                    return value
                } else {
                    let sum = filteredJobs(for: day).reduce(0.0) { $0 + $1.hours }
                    return String(format: "%.1f", sum)
                }
            },
            set: { newValue in
                dailyTotalHours[key] = newValue
            }
        )
    }
    
    /// Generates the weekly PDF and returns its file URL.
    private func generatePDF() -> URL? {
        // Person 1
        let name1Val = workers.indices.contains(0) ? workers[0].name : ""
        let g1 = workers.indices.contains(0) ? (Double(workers[0].gibson) ?? 0) : 0
        let c1 = workers.indices.contains(0) ? (Double(workers[0].cs) ?? 0) : 0
        let t1 = g1 + c1

        // Person 2
        let name2Val = workers.indices.contains(1) ? workers[1].name : ""
        let g2 = workers.indices.contains(1) ? (Double(workers[1].gibson) ?? 0) : 0
        let c2 = workers.indices.contains(1) ? (Double(workers[1].cs) ?? 0) : 0
        let t2 = g2 + c2

        let generator = WeeklyTimesheetPDFGenerator(
            startOfWeek: startOfWeek,
            endOfWeek: endOfWeek,
            jobs: timesheetJobsVM.jobs,
            currentUserID: authViewModel.currentUser?.id ?? "",
            partnerUserID: partnerUid,
            supervisor: supervisor,
            name1: name1Val,
            name2: name2Val,
            gibsonHours: String(format: "%.1f", g1),
            cableSouthHours: String(format: "%.1f", c1),
            totalHours: String(format: "%.1f", t1),
            gibsonHours2: String(format: "%.1f", g2),
            cableSouthHours2: String(format: "%.1f", c2),
            totalHours2: String(format: "%.1f", t2),
            dailyTotalHours: dailyTotalHours
        )
        return generator.generatePDF()
    }
    
    /// Opens the iOS print dialog for a given PDF file.
    private func printPDF(url: URL) {
        guard UIPrintInteractionController.isPrintingAvailable else { return }
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = "Weekly Timesheet"
        
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printingItem = url
        controller.present(animated: true, completionHandler: nil)
    }
    
    private func loadTimesheet() {
        guard let userId = authViewModel.currentUser?.id else { return }
        timesheetVM.fetchTimesheet(for: startOfWeek, userId: userId)
        // Also fetch jobs for the selected week in our independent model.
        timesheetJobsVM.fetchJobsForWeek(selectedDate: selectedDate)
    }
    
    private func weekStartString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - PDF Preview Sheet
struct PDFPreviewSheet: View {
    let pdfURL: URL
    let onPrint: () -> Void
    
    var body: some View {
        NavigationView {
            PDFKitView(url: pdfURL)
                .navigationTitle("Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Print") { onPrint() }
                    }
                }
        }
    }
}
