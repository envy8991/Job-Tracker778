

import CoreLocation   // for distance / CLLocation
import SwiftUI
import UIKit // for UIImage in share attachments

// MARK: – Glass utilities (file-scoped)
fileprivate struct GlassStroke: View {
    var cornerRadius: CGFloat = 16
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
    }
}

fileprivate struct GlassBackground: View {
    var cornerRadius: CGFloat = 16
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
    }
}

fileprivate extension View {
    func glassCard(cornerRadius: CGFloat = 16, shadow: CGFloat = 10) -> some View {
        self
            .background(GlassBackground(cornerRadius: cornerRadius))
            .overlay(GlassStroke(cornerRadius: cornerRadius))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.20), radius: shadow, x: 0, y: 6)
    }
}

struct DashboardView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var jobsViewModel: JobsViewModel

    // Smart‑routing settings
    @AppStorage("smartRoutingEnabled") private var smartRoutingEnabled = false
    @AppStorage("routingOptimizeBy")  private var routingOptimizeBy   = "closest" // or "farthest"
    @AppStorage("addressSuggestionProvider") private var suggestionProviderRaw = "apple" // "apple" or "google"
    
    // Live location
    @EnvironmentObject var locationService: LocationService

    private var sortClosest: Bool { routingOptimizeBy == "closest" }

    @State private var selectedJob: Job?
    @State private var nearestJobID: String?

    // Per‑job share state (simplified)
    @State private var jobShareURL: URL? = nil
    @State private var showSystemShareForJob = false
    @State private var isGeneratingShareLink = false

    // Import result toast
    @State private var showImportToast = false
    @State private var importToastMessage = ""
    @State private var importToastIsError = false
    
    // This tracks the user’s chosen date from the DatePicker:
    @State private var selectedDate = Date()
    
    /// Weekday labels and their 0‑based offset from Monday.
    private let weekdays: [(label: String, offset: Int)] = [
        ("Mon", 0),
        ("Tue", 1),
        ("Wed", 2),
        ("Thu", 3),
        ("Fri", 4)
    ]
    @State private var selectedOffset: Int? = nil
    
    // Status options for updating job status
    private let statusOptions = [
        "Pending",
        "Needs Aerial",
        "Needs Underground",
        "Needs Nid",
        "Needs Can",
        "Done",
        "Talk to Rick",   // new fixed option
        "Custom"          // opens manual entry
    ]

    // MARK: – Shared Gradient
    private static let topColor  = Color(red: 0.1725, green: 0.2431, blue: 0.3137)
    private static let bottomColor = Color(red: 0.2980, green: 0.6314, blue: 0.6863)
    private static let appGradient = LinearGradient(
        gradient: Gradient(colors: [topColor, bottomColor]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // For animated transitions
    @Namespace private var animation
    
    // Unified sheet controller
    private enum ActiveSheet: Identifiable {
        case datePicker
        case share
        case createJob
        
        var id: Int { hashValue }
    }
    @State private var activeSheet: ActiveSheet?
    @State private var shareItems: [Any] = []

    // Sync banner state (offline/online uploads)
    @State private var syncTotal: Int = 0
    @State private var syncDone: Int = 0
    @State private var syncInFlight: Int = 0
    @State private var showSyncBanner: Bool = false

    // Water animation phase
    @State private var wavePhase: CGFloat = 0

    // Scroll and summary state
    @State private var scrollY: CGFloat = 0

    private var jobsForSelectedDay: [Job] {
        filteredJobs()
    }
    private var pendingCountForDay: Int {
        jobsForSelectedDay.filter { $0.status.lowercased() == "pending" }.count
    }
    private var completedCountForDay: Int {
        max(0, jobsForSelectedDay.count - pendingCountForDay)
    }


    // MARK: – Main Content (broken out to reduce compiler load)
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 12) {
            // Floating toolbar header
            headerView

            // Summary (Liquid Glass)
            SummaryCard(date: selectedDate,
                        total: jobsForSelectedDay.count,
                        pending: pendingCountForDay,
                        completed: completedCountForDay)
                .padding(.horizontal)

            // Monday–Friday picker.
            weekdayPickerView
                .padding(.top, 4)

            // Full-width Create Job button
            Button {
                activeSheet = .createJob
            } label: {
                Label("Create Job", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(radius: 4)
            }
            .padding(.horizontal)
            .padding(.top, 6)

            // Job list grouped into Not Completed and Completed sections.
            let allJobs = filteredJobs()
            let rawNotCompleted = allJobs.filter { $0.status.lowercased() == "pending" }
            let completed       = allJobs.filter { $0.status.lowercased() != "pending" }

            // Distance strings keyed by job id (used by JobCard)
            let (notCompleted, distanceStrings): ([Job], [String: String]) = {
                guard smartRoutingEnabled, let here = locationService.current else {
                    return (rawNotCompleted, [:])
                }
                // Pre‑compute distances to lighten the sort closure
                let pairs: [(Job, CLLocationDistance)] = rawNotCompleted.map { job in
                    let d = job.clLocation?.distance(from: here) ?? .greatestFiniteMagnitude
                    return (job, d)
                }
                let sortedPairs = pairs.sorted { a, b in
                    sortClosest ? a.1 < b.1 : a.1 > b.1
                }
                var map: [String: String] = [:]
                for (job, d) in sortedPairs {
                    if d.isFinite, d < .greatestFiniteMagnitude {
                        map[job.id] = formatDistance(d)
                    }
                }
                return (sortedPairs.map { $0.0 }, map)
            }()

            if allJobs.isEmpty {
                HStack { // keep it centered and give it width for layout
                    Text("No jobs for this date")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 28)
                .padding(.horizontal)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Not Completed section
                        if !notCompleted.isEmpty {
                            Text("Not Completed")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)

                            ForEach(notCompleted, id: \.id) { job in
                                JobCard(
                                    job: job,
                                    isHere: job.id == nearestJobID,
                                    statusOptions: statusOptions,
                                    onMapTap: { openJobInMaps(job) },
                                    onStatusChange: { newStatus in
                                        DispatchQueue.main.async {
                                            jobsViewModel.updateJobStatus(job: job, newStatus: newStatus)
                                        }
                                    },
                                    onDelete: { jobsViewModel.deleteJob(documentID: job.id) },
                                    onShare: {
                                        Task { await shareJob(job) }
                                    },
                                    distanceString: distanceStrings[job.id]
                                )
                                .id("\(job.id)_\(job.status)")
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .transaction { $0.disablesAnimations = true }
                                .onTapGesture { selectedJob = job }
                            }
                        }

                        // Completed section
                        if !completed.isEmpty {
                            Text("Completed")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                                .padding(.horizontal, 8)

                            ForEach(completed, id: \.id) { job in
                                JobCard(
                                    job: job,
                                    isHere: job.id == nearestJobID,
                                    statusOptions: statusOptions,
                                    onMapTap: { openJobInMaps(job) },
                                    onStatusChange: { newStatus in
                                        DispatchQueue.main.async {
                                            jobsViewModel.updateJobStatus(job: job, newStatus: newStatus)
                                        }
                                    },
                                    onDelete: { jobsViewModel.deleteJob(documentID: job.id) },
                                    onShare: {
                                        Task { await shareJob(job) }
                                    },
                                    distanceString: distanceStrings[job.id]
                                )
                                .id("\(job.id)_\(job.status)")
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .transaction { $0.disablesAnimations = true }
                                .onTapGesture { selectedJob = job }
                            }
                        }
                    }
                    .padding()
                }
                .coordinateSpace(name: "dashScroll")
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Self.appGradient
                    .ignoresSafeArea()
                
                mainContent
            }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    // Syncing banner (appears only when there are pending uploads)
                    if showSyncBanner, syncTotal > 0, syncDone <= syncTotal {
                        SyncBanner(done: syncDone, total: syncTotal, inFlight: syncInFlight, phase: wavePhase)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Existing toast(s)
                    if showImportToast {
                        HStack(spacing: 10) {
                            Image(systemName: importToastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .imageScale(.medium)
                                .foregroundColor(importToastIsError ? .yellow : .green)
                            Text(importToastMessage)
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.top, 18)
            }
            // .overlay(alignment: .bottomTrailing) { ... } // AI Helper button removed
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                // Extra breathing room so the hamburger/menu button doesn't overlap the header card
                Color.clear.frame(height: 66) // extra headroom so the floating hamburger button never overlaps the header
            }
            .sheet(item: $selectedJob) { job in
                if let index = jobsViewModel.jobs.firstIndex(where: { $0.id == job.id }) {
                    JobDetailView(job: $jobsViewModel.jobs[index])
                } else {
                    Text("Job not found.")
                        .padding()
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .datePicker:
                    VStack {
                        DatePicker(
                            "Select a date",
                            selection: $selectedDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .labelsHidden()
                        .onChange(of: selectedDate) { _ in
                            activeSheet = nil
                        }
                    }
                    .padding()
                case .share:
                    ActivityView(
                        activityItems: shareItems,
                        subject: "Jobs for \(formattedDate(selectedDate))"
                    )
                case .createJob:
                    CreateJobView()
                }
            }
            // (Per‑job share sheet with privacy toggles removed)
            // System share sheet for the generated deep link
            .sheet(isPresented: $showSystemShareForJob) {
                if let url = jobShareURL {
                    ActivityView(
                        activityItems: [url],
                        subject: "Job link for \(formattedDate(selectedDate))"
                    )
                }
            }
            // When the view appears or selectedDate changes, fetch jobs for the week.
            .onAppear {
                jobsViewModel.fetchJobsForWeek(selectedDate)
                updateNearest(with: jobsViewModel.jobs)
            }
            .onChange(of: selectedDate) { _ in
                
                selectedOffset = weekdayOffset(for: selectedDate)
                jobsViewModel.fetchJobsForWeek(selectedDate)
            }
            .onReceive(locationService.$current) { _ in
                updateNearest(with: jobsViewModel.jobs)
            }
            .onReceive(jobsViewModel.$jobs) { newList in
                if activeSheet != nil { activeSheet = nil }
                updateNearest(with: newList)
            }
            .onReceive(authViewModel.$currentUser) { _ in
                // No-op: job visibility is handled by Firestore queries scoped via `participants`.
            }
            .onReceive(NotificationCenter.default.publisher(for: .jobImportSucceeded)) { _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    importToastIsError = false
                    importToastMessage = "Job imported to your dashboard"
                    showImportToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.25)) { showImportToast = false }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .jobImportFailed)) { note in
                let msg: String
                if let err = note.object as? NSError, !err.localizedDescription.isEmpty {
                    msg = err.localizedDescription
                } else {
                    msg = "Import failed"
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    importToastIsError = true
                    importToastMessage = msg
                    showImportToast = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeInOut(duration: 0.25)) { showImportToast = false }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .jobsSyncStateDidChange)) { note in
                // Expecting userInfo keys: "total", "uploaded" (or "done"), "inFlight"
                let info = note.userInfo ?? [:]
                let total = (info["total"] as? Int) ?? 0
                let done  = (info["uploaded"] as? Int) ?? (info["done"] as? Int) ?? 0
                let inFlight = (info["inFlight"] as? Int) ?? 0

                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    syncTotal = max(total, 0)
                    syncDone = max(min(done, total), 0)
                    syncInFlight = max(inFlight, 0)
                    showSyncBanner = (syncTotal > 0) && (syncDone < syncTotal)
                }

                // If finished, fade out banner shortly after
                if syncTotal > 0 && syncDone >= syncTotal {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.25)) { showSyncBanner = false }
                    }
                }
            }
            .onChange(of: showSyncBanner) { visible in
                // Drive the water "sloshing" while visible
                guard visible else { return }
                // Reset phase
                wavePhase = 0
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    wavePhase = 1.0
                }
            }
        }
    }
}

// MARK: - Header
extension DashboardView {
    /// Format a distance in meters into a short, human‑readable string (e.g., "650 m" or "0.4 mi").
    private func formatDistance(_ meters: CLLocationDistance) -> String {
        guard meters.isFinite else { return "" }
        // Simple heuristic: prefer miles in the US, meters/km otherwise.
        let usesUSUnits: Bool = Locale.current.usesMetricSystem == false
        if usesUSUnits {
            let miles = meters / 1609.344
            if miles < 0.1 { return "<0.1 mi" }
            return String(format: "%.1f mi", miles)
        } else {
            if meters < 1000 { return "\(Int(meters.rounded())) m" }
            let km = meters / 1000
            return String(format: "%.1f km", km)
        }
    }
    private var headerView: some View {
        HStack(spacing: 12) {
            Button {
                activeSheet = .datePicker
            } label: {
                Image(systemName: "calendar")
                    .font(.headline)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }

            VStack(spacing: 0) {
                Text("Jobs")
                    .font(.title3.weight(.semibold))
                Text(formattedDate(selectedDate))
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)

            Button {
                prepareShareItems()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.headline)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        )
        .padding(.horizontal)
        .padding(.top, 24)
    }
}

// MARK: - Sharing Helpers
extension DashboardView {
    /// Create a minimal deep link for a single job and present the system share sheet.
    private func shareJob(_ job: Job) async {
        guard !isGeneratingShareLink else { return }
        await MainActor.run { isGeneratingShareLink = true }
        defer { Task { await MainActor.run { isGeneratingShareLink = false } } }
        do {
            let url = try await SharedJobService.shared.publishShareLink(job: job)
            await MainActor.run {
                jobShareURL = url
                showSystemShareForJob = true
            }
        } catch {
            print("Share publish failed: \(error.localizedDescription)")
            await MainActor.run {
                importToastIsError = true
                importToastMessage = "Couldn't create link: \(error.localizedDescription)"
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showImportToast = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.25)) { showImportToast = false }
            }
        }
    }
    /// Build the items array for UIActivityViewController: summary text + any job images/links.
    private func prepareShareItems(limitImages: Int = 20) {
        // Keep the same text summary you already had
        let text = shareText()
        var items: [Any] = [text]

        // Collect attachments from jobs included in the summary
        let jobsForDay = filteredJobs().filter { $0.status.lowercased() != "pending" }
        var imagesOrLinks: [Any] = []
        for job in jobsForDay {
            imagesOrLinks.append(contentsOf: shareableAttachments(for: job))
            if imagesOrLinks.count >= limitImages { break }
        }
        if !imagesOrLinks.isEmpty {
            items.append(contentsOf: imagesOrLinks.prefix(limitImages))
        }
        // Ensure at least one string item for share sheet fallback
        if items.isEmpty { items = [" "] }
        // Store and present on next runloop tick to avoid first‑present race conditions with SwiftUI state changes
        // Store and present on next runloop tick (plus tiny delay) to avoid first-present race conditions with SwiftUI state changes
        shareItems = items
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            activeSheet = .share
        }
    }

    /// Try to find photo/image content on the Job using reflection so we don't rely on a specific model field name.
    /// Supports: [UIImage], UIImage, [Data] (converted to UIImage), [URL], [String] (converted to URL if possible)
    private func shareableAttachments(for job: Job) -> [Any] {
        var out: [Any] = []
        let mirror = Mirror(reflecting: job)
        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            // Heuristics: look for common photo/image keys
            if label.contains("photo") || label.contains("image") || label.contains("picture") {
                switch child.value {
                case let arr as [UIImage]:
                    out.append(contentsOf: arr)
                case let img as UIImage:
                    out.append(img)
                case let arr as [Data]:
                    out.append(contentsOf: arr.compactMap { UIImage(data: $0) })
                case let data as Data:
                    if let img = UIImage(data: data) { out.append(img) }
                case let arr as [URL]:
                    out.append(contentsOf: arr)
                case let arr as [String]:
                    out.append(contentsOf: arr.compactMap { URL(string: $0) })
                case let str as String:
                    if let url = URL(string: str) { out.append(url) }
                default:
                    break
                }
            }
        }
        return out
    }
}

// MARK: - Monday–Friday Picker
extension DashboardView {
    private var weekdayPickerView: some View {
        HStack(spacing: 10) {
            ForEach(weekdays, id: \.label) { day in
                Button {
                    selectedOffset = day.offset
                    selectedDate = dateForOffset(day.offset)
                    jobsViewModel.fetchJobsForWeek(selectedDate)
                } label: {
                    Text(day.label)
                        .fontWeight(selectedOffset == day.offset ? .bold : .regular)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedOffset == day.offset
                                      ? Color.accentColor.opacity(0.9)
                                      : Color.white.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white, lineWidth: selectedOffset == day.offset ? 2 : 0)
                        )
                        .foregroundColor(.white)
                        .scaleEffect(selectedOffset == day.offset ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: selectedOffset == day.offset)
                }
            }
        }
    }
    
    /// Return the `Date` for the weekday *offset* (0 = Mon … 4 = Fri) in the same week as `selectedDate`.
    private func dateForOffset(_ offset: Int) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        // Start (Monday) of the week containing selectedDate
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return calendar.date(byAdding: .day, value: offset, to: startOfWeek)!
    }
}

// MARK: - Helpers
extension DashboardView {
    /// Compose share text for the selected date: "Jobs for Apr 29 2025:\n123 Main St – Done"
    private func shareText() -> String {
        let jobsForDay = filteredJobs().filter { $0.status.lowercased() != "pending" }
        guard !jobsForDay.isEmpty else {
            return "No jobs to share for \(formattedDate(selectedDate))."
        }

        let header = "Jobs for \(formattedDate(selectedDate)):"
        let lines = jobsForDay.map { job in
            let address = houseNumberAndStreet(from: job.address)
            var entry = "\(address) – \(job.status)"
            // Include notes if present
            let noteText = (job.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !noteText.isEmpty {
                entry += " (Notes: \(noteText))"
            }
            return entry
        }
        return ([header] + lines).joined(separator: "\n")
    }
    
    /// Trim address to house number and street.
    private func houseNumberAndStreet(from fullAddress: String) -> String {
        if let comma = fullAddress.firstIndex(of: ",") {
            return String(fullAddress[..<comma]).trimmingCharacters(in: .whitespaces)
        }
        // Fallback: stop after common street suffix.
        let suffixes: Set<String> = ["st","street","rd","road","ave","avenue","blvd","circle","cir","ln","lane","dr","drive","ct","court","pkwy","pl","place","ter","terrace"]
        var tokens: [Substring] = []
        for token in fullAddress.split(separator: " ") {
            tokens.append(token)
            let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ",.")).lowercased()
            if suffixes.contains(cleaned) { break }
        }
        return tokens.joined(separator: " ")
    }
    
    /// Return 0 = Mon … 4 = Fri if the date is a weekday; otherwise nil.
    private func weekdayOffset(for date: Date) -> Int? {
        let weekday = Calendar.current.component(.weekday, from: date) // Sun = 1
        let monBased = (weekday + 5) % 7   // Sun→6, Mon→0, Tue→1, … Sat→5
        return monBased < 5 ? monBased : nil
    }
    /// Format selectedDate as "Apr 29 2025".
    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }
    
    /// Return the jobs for the selected date. JobsViewModel now provides only jobs the current user can see (via `participants`).
    private func filteredJobs() -> [Job] {
        // JobsViewModel now provides only jobs the current user can see (via `participants`).
        // Here we only filter by the selected calendar day and dedupe by id.
        let dayFiltered = jobsViewModel.jobs.filter { job in
            Calendar.current.isDate(job.date, inSameDayAs: selectedDate)
        }
        var seen = Set<String>()
        var uniqueReversed: [Job] = []
        for job in dayFiltered.reversed() {
            if !seen.contains(job.id) {
                seen.insert(job.id)
                uniqueReversed.append(job)
            }
        }
        return uniqueReversed.reversed()
    }

    /// Compute the single nearest job within 90 m (if any).
    private func updateNearest(with jobs: [Job]) {
        guard let here = locationService.current else {
            nearestJobID = nil
            return
        }
        let nearest = jobs
            .compactMap { job -> (String, CLLocationDistance)? in
                guard let d = job.clLocation?.distance(from: here) else { return nil }
                return (job.id, d)
            }
            .min { $0.1 < $1.1 }
        
        let newID: String? = (nearest?.1 ?? .greatestFiniteMagnitude) < 90 ? nearest?.0 : nil
        if newID != nearestJobID { nearestJobID = newID }
    }
    
    private func openJobInMaps(_ job: Job) {
        guard let encoded = job.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        // Honor the user's preference from Settings → Maps & Addresses
        if suggestionProviderRaw == "google" {
            // Try Google Maps app first; if unavailable, fall back to Apple Maps
            if let gURL = URL(string: "comgooglemaps://?daddr=\(encoded)&directionsmode=driving") {
                UIApplication.shared.open(gURL, options: [:]) { success in
                    if !success {
                        // Fallback to Apple Maps
                        if let appleURL = URL(string: "maps://?saddr=Current%20Location&daddr=\(encoded)") {
                            UIApplication.shared.open(appleURL)
                        }
                    }
                }
                return
            }
        }
        // Default (or fallback): Apple Maps
        if let appleURL = URL(string: "maps://?saddr=Current%20Location&daddr=\(encoded)") {
            UIApplication.shared.open(appleURL)
        }
    }
}



// MARK: - JobCard
struct JobCard: View {
    let isHere: Bool       // NEW flag
    let job: Job
    let onDelete: () -> Void   // NEW
    let statusOptions: [String]
    let onMapTap: () -> Void
    let onStatusChange: (String) -> Void
    let onShare: () -> Void
    @State private var showDeleteConfirm = false   // NEW
    @State private var showStatusDialog = false
    @State private var showCustomStatusEntry = false
    @State private var customStatusText = ""

    // NEW: Optional distance string displayed next to date
    var distanceString: String? = nil

    init(
        job: Job,
        isHere: Bool,
        statusOptions: [String],
        onMapTap: @escaping () -> Void,
        onStatusChange: @escaping (String) -> Void,
        onDelete: @escaping () -> Void,
        onShare: @escaping () -> Void,
        distanceString: String? = nil
    ) {
        self.job = job
        self.isHere = isHere
        self.statusOptions = statusOptions
        self.onMapTap = onMapTap
        self.onStatusChange = onStatusChange
        self.onDelete = onDelete
        self.onShare = onShare
        self.distanceString = distanceString
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // TITLE ROW
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.9))
                Text(job.address)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
            }

            // SUBTITLE ROW: date + distance + HERE
            HStack(spacing: 8) {
                Text(job.date, style: .date)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))

                if let d = distanceString, !d.isEmpty {
                    Text("• \(d)")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.8))
                        .accessibilityLabel("Distance \(d)")
                }

                if isHere {
                    Text("Here")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .accessibilityLabel("You are here")
                }

                Spacer()
            }

            // OPTIONAL FIELDS
            if let assignments = job.assignments?.trimmedNonEmpty {
                KeyValueRow(key: "Assignment:", value: assignments)
            }
            if let materials = job.materialsUsed?.trimmedNonEmpty {
                KeyValueRow(key: "Materials:", value: materials, lineLimit: 2)
            }
            if let notes = job.notes?.trimmedNonEmpty {
                KeyValueRow(key: "Notes:", value: notes, lineLimit: 2)
            }

            // STATUS + ACTIONS
            HStack(spacing: 10) {
                Text("Status:")
                    .foregroundColor(.white)

                Button {
                    showStatusDialog = true
                } label: {
                    Text(job.status)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(statusBackground(for: job.status))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .confirmationDialog("Change Status",
                                    isPresented: $showStatusDialog,
                                    titleVisibility: .visible) {
                    ForEach(statusOptions, id: \.self) { option in
                        if option == "Custom" {
                            Button("Custom…") { showCustomStatusEntry = true }
                        } else {
                            Button(option) { onStatusChange(option) }
                        }
                    }
                }

                Spacer()

                // Quick actions
                Button(action: onMapTap) {
                    Image(systemName: "map")
                        .imageScale(.medium)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Directions")
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .imageScale(.medium)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                Button {
                    showDeleteConfirm = true
#if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
                } label: {
                    Image(systemName: "trash")
                        .imageScale(.medium)
                        .foregroundColor(.red)
                        .padding(8)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
            }
            .alert("Delete this job?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) { onDelete() }
                Button("Cancel", role: .cancel) { }
            }
        }
        .padding()
        .glassCard(cornerRadius: 16, shadow: 12)
        .padding(.horizontal, 4)
        // Swipe actions (keeps your buttons too)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { onShare() } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }.tint(.blue)
        }
        .contextMenu {
            Button("Directions", systemImage: "map.fill", action: onMapTap)
            Button("Share", systemImage: "square.and.arrow.up", action: onShare)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(houseNumber(job.address)), \(DateFormatter.localizedString(from: job.date, dateStyle: .medium, timeStyle: .none))")
        .accessibilityHint("Double tap for details. Swipe actions for share and delete.")
    }

    private func statusBackground(for status: String) -> Color {
        let s = status.lowercased()
        if s == "done" { return Color.green.opacity(0.6) }
        if s == "pending" { return Color.gray.opacity(0.35) }
        if s.contains("needs") { return Color.orange.opacity(0.6) }
        return Color.white.opacity(0.12)
    }

    private func houseNumber(_ full: String) -> String {
        if let comma = full.firstIndex(of: ",") {
            return String(full[..<comma])
        }
        return full
    }
}

// Tiny helper view
private struct KeyValueRow: View {
    let key: String
    let value: String
    var lineLimit: Int = 1

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(key)
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let s = trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }
}


// MARK: - Sync Banner (water progress)
private struct SyncBanner: View {
    let done: Int
    let total: Int
    let inFlight: Int
    let phase: CGFloat

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(done) / CGFloat(total)
    }

    var body: some View {
        ZStack {
            // Background capsule with subtle border
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.76))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )

            // Water fill (masked to rounded rect)
            GeometryReader { geo in
                ZStack {
                    // Lower, slower wave
                    WaterWave(progress: progress, phase: phase, amplitude: 6)
                        .fill(Color.accentColor.opacity(0.55))
                        .blur(radius: 0.4)

                    // Upper, faster wave with slight offset for "sloshing"
                    WaterWave(progress: progress, phase: phase * 1.6 + 0.2, amplitude: 4)
                        .fill(Color.accentColor.opacity(0.75))
                }
                .mask(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }

            // Text overlay
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .imageScale(.medium)
                    .foregroundColor(.white.opacity(0.95))
                Text(syncTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(max(done,0))/\(max(total,0))")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 44)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(syncTitle)
    }

    private var syncTitle: String {
        if total == 0 { return "All changes are up to date" }
        if done >= total { return "All changes uploaded" }
        if inFlight > 0 { return "Uploading… (\(inFlight) in progress)" }
        return "Syncing changes…"
    }
}

/// A single sine-wave water fill. `phase` animates from 0→1 repeatedly, and we convert to radians inside.
private struct WaterWave: Shape {
    var progress: CGFloat    // 0…1 (fill level)
    var phase: CGFloat       // 0…1 (animation cycle)
    var amplitude: CGFloat   // wave height in points

    // Animate by phase only
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let twoPi = CGFloat.pi * 2
        let level = rect.height * (1 - max(0, min(progress, 1)))  // y where water meets air
        let wavelength = max(rect.width / 1.2, 1)                  // a little wider than rect for smoother shape
        let radians = phase * twoPi

        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: level))

        // Draw the wave across the width
        var x: CGFloat = 0
        while x <= rect.width {
            let relative = x / wavelength
            let y = level + sin(relative * twoPi + radians) * amplitude
            p.addLine(to: CGPoint(x: rect.minX + x, y: y))
            x += 1
        }

        // Close the shape at the bottom
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}



// MARK: - Summary Card
private struct SummaryCard: View {
    let date: Date
    let total: Int
    let pending: Int
    let completed: Int

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(formatted(date))
                    .font(.title3.weight(.semibold))
            }

            Spacer()

            MetricPill(title: "Total", value: total)
            MetricPill(title: "Pending", value: pending)
            MetricPill(title: "Done", value: completed)
        }
        .padding(16)
        .glassCard(cornerRadius: 18, shadow: 10)
    }

    private func formatted(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: d)
    }

    private struct MetricPill: View {
        let title: String
        let value: Int
        var body: some View {
            VStack(spacing: 4) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.85))
                Text("\(value)")
                    .font(.headline.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
    }
}
