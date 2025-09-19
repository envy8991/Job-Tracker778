import CoreLocation
import SwiftUI
import UIKit

@MainActor
final class DashboardViewModel: ObservableObject {
    struct Weekday: Identifiable {
        let label: String
        let offset: Int

        var id: String { label }
    }

    struct JobSections {
        let notCompleted: [Job]
        let completed: [Job]
        let distanceStrings: [String: String]

        var allJobs: [Job] { notCompleted + completed }
        var isEmpty: Bool { allJobs.isEmpty }
    }

    enum ActiveSheet: Identifiable {
        case datePicker
        case share
        case createJob

        var id: Int { hashValue }
    }

    // MARK: - Published State

    @Published var selectedDate: Date {
        didSet {
            selectedOffset = Self.weekdayOffset(for: selectedDate)
            jobsViewModel?.fetchJobsForWeek(selectedDate)
        }
    }
    @Published private(set) var selectedOffset: Int?
    @Published var activeSheet: ActiveSheet?
    @Published var shareItems: [Any] = []
    @Published var isPreparingDailyShare = false
    @Published var isGeneratingShareLink = false
    @Published var jobShareURL: URL?
    @Published var showSystemShareForJob = false
    @Published var showImportToast = false
    @Published var importToastMessage = ""
    @Published var importToastIsError = false
    @Published var showSyncBanner = false
    @Published var syncTotal: Int = 0
    @Published var syncDone: Int = 0
    @Published var syncInFlight: Int = 0
    @Published var wavePhase: CGFloat = 0
    @Published var nearestJobID: String?
    @Published var selectedJob: Job?

    // MARK: - Dependencies

    private var jobsViewModel: JobsViewModel?

    // MARK: - Constants

    let weekdays: [Weekday] = [
        .init(label: "Mon", offset: 0),
        .init(label: "Tue", offset: 1),
        .init(label: "Wed", offset: 2),
        .init(label: "Thu", offset: 3),
        .init(label: "Fri", offset: 4)
    ]

    let statusOptions: [String] = [
        "Pending",
        "Needs Aerial",
        "Needs Underground",
        "Needs Nid",
        "Needs Can",
        "Done",
        "Talk to Rick",
        "Custom"
    ]

    // MARK: - Init

    init(selectedDate: Date = Date()) {
        self.selectedDate = selectedDate
        self.selectedOffset = Self.weekdayOffset(for: selectedDate)
    }

    func configureIfNeeded(jobsViewModel: JobsViewModel) {
        guard self.jobsViewModel !== jobsViewModel else { return }
        self.jobsViewModel = jobsViewModel
        jobsViewModel.fetchJobsForWeek(selectedDate)
    }

    // MARK: - Date Helpers

    func selectWeekday(offset: Int) {
        let newDate = dateForOffset(offset)
        selectedDate = newDate
    }

    func dateForOffset(_ offset: Int) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)
        guard let startOfWeek = calendar.date(from: components) else { return selectedDate }
        return calendar.date(byAdding: .day, value: offset, to: startOfWeek) ?? selectedDate
    }

    static func weekdayOffset(for date: Date) -> Int? {
        let weekday = Calendar.current.component(.weekday, from: date)
        let mondayBased = (weekday + 5) % 7
        return mondayBased < 5 ? mondayBased : nil
    }

    // MARK: - Job Computations

    func filteredJobs(from jobs: [Job]) -> [Job] {
        let dayFiltered = jobs.filter { job in
            Calendar.current.isDate(job.date, inSameDayAs: selectedDate)
        }
        var seen = Set<String>()
        var uniqueReversed: [Job] = []
        for job in dayFiltered.reversed() {
            if seen.insert(job.id).inserted {
                uniqueReversed.append(job)
            }
        }
        return uniqueReversed.reversed()
    }

    func sections(
        for jobs: [Job],
        smartRoutingEnabled: Bool,
        sortClosest: Bool,
        currentLocation: CLLocation?
    ) -> JobSections {
        let filtered = filteredJobs(from: jobs)
        let rawNotCompleted = filtered.filter { $0.status.lowercased() == "pending" }
        let completed = filtered.filter { $0.status.lowercased() != "pending" }

        guard smartRoutingEnabled, let here = currentLocation else {
            return JobSections(
                notCompleted: rawNotCompleted,
                completed: completed,
                distanceStrings: [:]
            )
        }

        let pairs: [(Job, CLLocationDistance)] = rawNotCompleted.map { job in
            let distance = job.clLocation?.distance(from: here) ?? .greatestFiniteMagnitude
            return (job, distance)
        }

        let sortedPairs = pairs.sorted { lhs, rhs in
            sortClosest ? lhs.1 < rhs.1 : lhs.1 > rhs.1
        }

        var map: [String: String] = [:]
        for (job, distance) in sortedPairs where distance.isFinite && distance < .greatestFiniteMagnitude {
            map[job.id] = formatDistance(distance)
        }

        return JobSections(
            notCompleted: sortedPairs.map { $0.0 },
            completed: completed,
            distanceStrings: map
        )
    }

    func summaryCounts(from jobs: [Job]) -> (total: Int, pending: Int, completed: Int) {
        let filtered = filteredJobs(from: jobs)
        let pending = filtered.filter { $0.status.lowercased() == "pending" }.count
        let completed = max(0, filtered.count - pending)
        return (filtered.count, pending, completed)
    }

    func updateNearestJob(with jobs: [Job], currentLocation: CLLocation?) {
        guard let here = currentLocation else {
            nearestJobID = nil
            return
        }
        let nearest = jobs
            .compactMap { job -> (String, CLLocationDistance)? in
                guard let distance = job.clLocation?.distance(from: here) else { return nil }
                return (job.id, distance)
            }
            .min { $0.1 < $1.1 }

        let identifier: String?
        if let candidate = nearest, candidate.1 < 90 {
            identifier = candidate.0
        } else {
            identifier = nil
        }
        if identifier != nearestJobID {
            nearestJobID = identifier
        }
    }

    func handleJobsListChange(_ jobs: [Job], currentLocation: CLLocation?) {
        activeSheet = nil
        updateNearestJob(with: jobs, currentLocation: currentLocation)
    }

    // MARK: - Sharing

    var shareSubject: String {
        "Jobs for \(formattedDate(selectedDate))"
    }

    func handleDailyShareTap() async {
        guard let jobsViewModel else { return }
        guard jobsViewModel.hasLoadedInitialJobs else {
            showJobsStillLoadingToast()
            return
        }
        guard !isPreparingDailyShare else { return }

        isPreparingDailyShare = true
        defer { isPreparingDailyShare = false }

        await waitForLatestJobsData()
        presentDailyShareSheet()
    }

    func share(job: Job) async {
        guard !isGeneratingShareLink else { return }
        isGeneratingShareLink = true
        defer { isGeneratingShareLink = false }

        do {
            let url = try await SharedJobService.shared.publishShareLink(job: job)
            jobShareURL = url
            showSystemShareForJob = true
        } catch {
            presentShareError(message: "Couldn't create link: \(error.localizedDescription)")
        }
    }

    private func waitForLatestJobsData(maxWait: TimeInterval = 1.0) async {
        guard maxWait > 0 else { return }
        let deadline = Date().addingTimeInterval(maxWait)
        while Date() < deadline {
            if Task.isCancelled { return }
            let ready = !filteredJobs(from: jobsViewModel?.jobs ?? []).isEmpty || jobsViewModel?.lastServerSync != nil
            if ready { return }
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
    }

    private func presentDailyShareSheet(limitImages: Int = 20) {
        let jobs = filteredJobs(from: jobsViewModel?.jobs ?? [])
        shareItems = buildDailyShareItems(for: jobs, limitImages: limitImages)
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.activeSheet = .share
        }
    }

    private func buildDailyShareItems(for jobs: [Job], limitImages: Int) -> [Any] {
        let summarySource = DailyJobsSummaryItemSource(
            textProvider: { [weak self] in self?.shareText(for: jobs) ?? "" },
            fallbackProvider: { [weak self] in self?.shareEmptyFallbackText() ?? "" },
            subjectProvider: { [weak self] in self?.shareSubject ?? "" }
        )

        var items: [Any] = [summarySource]
        let completedJobs = jobs.filter { $0.status.lowercased() != "pending" }
        var attachments: [Any] = []
        for job in completedJobs {
            attachments.append(contentsOf: shareableAttachments(for: job))
            if attachments.count >= limitImages { break }
        }
        if !attachments.isEmpty {
            items.append(contentsOf: attachments.prefix(limitImages))
        }
        return items
    }

    private func shareText(for jobs: [Job]) -> String {
        let completedJobs = jobs.filter { $0.status.lowercased() != "pending" }
        guard !completedJobs.isEmpty else {
            return shareEmptyFallbackText() ?? ""
        }
        let header = "\(shareSubject):"
        let lines = completedJobs.map { job in
            let address = houseNumberAndStreet(from: job.address)
            var entry = "\(address) – \(job.status)"
            if let noteText = job.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !noteText.isEmpty {
                entry += " (Notes: \(noteText))"
            }
            return entry
        }
        return ([header] + lines).joined(separator: "\n")
    }

    private func shareEmptyFallbackText() -> String? {
        "No jobs to share for \(formattedDate(selectedDate))."
    }

    private func shareableAttachments(for job: Job) -> [Any] {
        var out: [Any] = []
        let mirror = Mirror(reflecting: job)
        for child in mirror.children {
            guard let label = child.label?.lowercased() else { continue }
            if label.contains("photo") || label.contains("image") || label.contains("picture") {
                switch child.value {
                case let array as [UIImage]:
                    out.append(contentsOf: array)
                case let image as UIImage:
                    out.append(image)
                case let array as [Data]:
                    out.append(contentsOf: array.compactMap { UIImage(data: $0) })
                case let data as Data:
                    if let image = UIImage(data: data) { out.append(image) }
                case let array as [URL]:
                    out.append(contentsOf: array)
                case let array as [String]:
                    out.append(contentsOf: array.compactMap { URL(string: $0) })
                case let string as String:
                    if let url = URL(string: string) { out.append(url) }
                default:
                    break
                }
            }
        }
        return out
    }

    func presentDatePicker() {
        activeSheet = .datePicker
    }

    func presentCreateJob() {
        activeSheet = .createJob
    }

    func dismissSheets() {
        activeSheet = nil
        showSystemShareForJob = false
    }

    // MARK: - Toasts & Sync

    func showJobsStillLoadingToast() {
        importToastIsError = true
        importToastMessage = "Jobs are still loading…"
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showImportToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showImportToast = false
            }
        }
    }

    func presentImportSuccessToast() {
        importToastIsError = false
        importToastMessage = "Job imported to your dashboard"
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showImportToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showImportToast = false
            }
        }
    }

    func presentImportFailureToast(message: String) {
        importToastIsError = true
        importToastMessage = message
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showImportToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showImportToast = false
            }
        }
    }

    func handleSyncStateChange(total: Int, done: Int, inFlight: Int) {
        syncTotal = max(total, 0)
        syncDone = max(min(done, total), 0)
        syncInFlight = max(inFlight, 0)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showSyncBanner = (syncTotal > 0) && (syncDone < syncTotal)
        }
        if syncTotal > 0 && syncDone >= syncTotal {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                withAnimation(.easeInOut(duration: 0.25)) {
                    self?.showSyncBanner = false
                }
            }
        }
    }

    func startWaveAnimation() {
        wavePhase = 0
        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
            wavePhase = 1
        }
    }

    func resetWave() {
        wavePhase = 0
    }

    private func presentShareError(message: String) {
        importToastIsError = true
        importToastMessage = message
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            showImportToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.showImportToast = false
            }
        }
    }

    // MARK: - Utilities

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatDistance(_ meters: CLLocationDistance) -> String {
        guard meters.isFinite else { return "" }
        switch Locale.current.measurementSystem {
        case .us:
            let miles = meters / 1609.344
            if miles < 0.1 { return "<0.1 mi" }
            return String(format: "%.1f mi", miles)
        case .metric, .uk:
            if meters < 1000 { return "\(Int(meters.rounded())) m" }
            let kilometers = meters / 1000
            return String(format: "%.1f km", kilometers)
        default:
            if meters < 1000 { return "\(Int(meters.rounded())) m" }
            let kilometers = meters / 1000
            return String(format: "%.1f km", kilometers)
        }
    }

    private func houseNumberAndStreet(from full: String) -> String {
        if let comma = full.firstIndex(of: ",") {
            return String(full[..<comma]).trimmingCharacters(in: .whitespaces)
        }
        let suffixes: Set<String> = [
            "st", "street", "rd", "road", "ave", "avenue", "blvd", "circle", "cir", "ln", "lane",
            "dr", "drive", "ct", "court", "pkwy", "pl", "place", "ter", "terrace"
        ]
        var tokens: [Substring] = []
        for token in full.split(separator: " ") {
            tokens.append(token)
            let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: ",.")).lowercased()
            if suffixes.contains(cleaned) { break }
        }
        return tokens.joined(separator: " ")
    }

    func openJobInMaps(_ job: Job, suggestionProviderRaw: String) {
        guard let encoded = job.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        if suggestionProviderRaw == "google" {
            if let url = URL(string: "comgooglemaps://?daddr=\(encoded)&directionsmode=driving") {
                UIApplication.shared.open(url, options: [:]) { success in
                    if success { return }
                    if let appleURL = URL(string: "maps://?saddr=Current%20Location&daddr=\(encoded)") {
                        UIApplication.shared.open(appleURL)
                    }
                }
                return
            }
        }
        if let appleURL = URL(string: "maps://?saddr=Current%20Location&daddr=\(encoded)") {
            UIApplication.shared.open(appleURL)
        }
    }
}

private final class DailyJobsSummaryItemSource: NSObject, UIActivityItemSource {
    private let textProvider: () -> String
    private let fallbackProvider: () -> String
    private let subjectProvider: () -> String

    init(textProvider: @escaping () -> String,
         fallbackProvider: @escaping () -> String,
         subjectProvider: @escaping () -> String) {
        self.textProvider = textProvider
        self.fallbackProvider = fallbackProvider
        self.subjectProvider = subjectProvider
        super.init()
    }

    private func resolvedText() -> NSString {
        let trimmed = textProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return NSString(string: trimmed)
        }
        let fallback = fallbackProvider().trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.isEmpty {
            return NSString(string: " ")
        }
        return NSString(string: fallback)
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        resolvedText()
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        resolvedText()
    }

    func activityViewController(_ activityViewController: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        subjectProvider().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
