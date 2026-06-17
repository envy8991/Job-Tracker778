import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var jobsViewModel: JobsViewModel
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.shellChromeHeight) private var shellChromeHeight

    @AppStorage("smartRoutingEnabled") private var smartRoutingEnabled = false
    @AppStorage("routingOptimizeBy") private var routingOptimizeBy = "closest"
    @AppStorage("addressSuggestionProvider") private var suggestionProviderRaw = "apple"

    @StateObject private var viewModel = DashboardViewModel()

    private var sortClosest: Bool { routingOptimizeBy == "closest" }

    private var navigationBarVisibility: Visibility {
        horizontalSizeClass == .compact ? .hidden : .automatic
    }

    private var sections: DashboardViewModel.JobSections {
        viewModel.sections(
            for: jobsViewModel.jobs,
            smartRoutingEnabled: smartRoutingEnabled,
            sortClosest: sortClosest,
            currentLocation: locationService.current
        )
    }

    private var summaryCounts: (total: Int, pending: Int, completed: Int) {
        viewModel.summaryCounts(from: jobsViewModel.jobs)
    }

    private var selectedJobBinding: Binding<Job?> {
        Binding(
            get: { viewModel.selectedJob },
            set: { viewModel.selectedJob = $0 }
        )
    }

    private func binding(for selectedJob: Job) -> Binding<Job>? {
        let jobID = selectedJob.id
        guard jobsViewModel.jobs.contains(where: { $0.id == jobID }) else { return nil }

        return Binding(
            get: {
                jobsViewModel.jobs.first(where: { $0.id == jobID }) ?? selectedJob
            },
            set: { updatedJob in
                guard let index = jobsViewModel.jobs.firstIndex(where: { $0.id == jobID }) else { return }
                jobsViewModel.jobs[index] = updatedJob
            }
        )
    }

    private var activeSheetBinding: Binding<DashboardViewModel.ActiveSheet?> {
        Binding(
            get: { viewModel.activeSheet },
            set: { viewModel.activeSheet = $0 }
        )
    }

    private var showSystemShareBinding: Binding<Bool> {
        Binding(
            get: { viewModel.showSystemShareForJob },
            set: { viewModel.showSystemShareForJob = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                JTGradients.background
                    .ignoresSafeArea()

                VStack(spacing: JTSpacing.md) {
                    DashboardHeaderToolbar(
                        title: "Jobs",
                        subtitle: viewModel.formattedDate(viewModel.selectedDate),
                        isPreparingShare: viewModel.isPreparingDailyShare,
                        shareAccessibilityLabel: viewModel.shareSubject,
                        onCalendarTap: { viewModel.presentDatePicker() },
                        onShareTap: { Task { await viewModel.handleDailyShareTap() } }
                    )
                    .padding(.horizontal)
                    .padding(.top, JTSpacing.xl)

                    DashboardSummaryCard(
                        date: viewModel.selectedDate,
                        total: summaryCounts.total,
                        pending: summaryCounts.pending,
                        completed: summaryCounts.completed
                    )
                    .padding(.horizontal)

                    DashboardWeekdayPicker(
                        weekdays: viewModel.weekdays,
                        selectedOffset: viewModel.selectedOffset,
                        onSelect: { day in viewModel.selectWeekday(offset: day.offset) }
                    )
                    .padding(.top, JTSpacing.sm)

                    JTPrimaryButton("Create Job", systemImage: "plus") {
                        viewModel.presentCreateJob()
                    }
                    .padding(.horizontal)
                    .padding(.top, JTSpacing.sm)

                    DashboardJobSectionsView(
                        sections: sections,
                        statusOptions: viewModel.statusOptions,
                        nearestJobID: viewModel.nearestJobID,
                        distanceStrings: sections.distanceStrings,
                        onJobTap: { job in viewModel.selectedJob = job },
                        onMapTap: { job in viewModel.openJobInMaps(job, suggestionProviderRaw: suggestionProviderRaw) },
                        onStatusChange: { job, status in
                            DispatchQueue.main.async {
                                jobsViewModel.updateJobStatus(job: job, newStatus: status)
                            }
                        },
                        onDelete: { job in jobsViewModel.deleteJob(documentID: job.id) },
                        onShare: { job in
                            Task { await viewModel.share(job: job, userRole: authViewModel.currentUser?.normalizedPosition) }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: JTSpacing.sm) {
                    if viewModel.showSyncBanner, viewModel.syncTotal > 0, viewModel.syncDone <= viewModel.syncTotal {
                        DashboardSyncBanner(
                            done: viewModel.syncDone,
                            total: viewModel.syncTotal,
                            inFlight: viewModel.syncInFlight,
                            failed: viewModel.syncFailed,
                            waitingForNetwork: viewModel.syncWaitingForNetwork,
                            phase: viewModel.wavePhase
                        )
                        .onTapGesture { viewModel.presentSyncDetails() }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    if viewModel.showImportToast {
                        HStack(spacing: JTSpacing.sm) {
                            Image(systemName: viewModel.importToastIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .imageScale(.medium)
                                .foregroundStyle(viewModel.importToastIsError ? Color.yellow : Color.green)
                            Text(viewModel.importToastMessage)
                                .font(.subheadline)
                                .foregroundStyle(Color.white)
                        }
                        .padding(.horizontal, JTSpacing.md)
                        .padding(.vertical, JTSpacing.sm)
                        .background(Color.black.opacity(0.85))
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.top, JTSpacing.md)
            }
            .toolbar(navigationBarVisibility, for: .navigationBar)
            .jtNavigationBarStyle()
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: shellChromeHeight)
            }
            .sheet(item: selectedJobBinding) { job in
                if let jobBinding = binding(for: job) {
                    JobDetailView(job: jobBinding)
                } else {
                    Text("Job not found.")
                        .padding()
                }
            }
            .sheet(item: activeSheetBinding) { sheet in
                switch sheet {
                case .datePicker:
                    DashboardDatePickerSheet(
                        selectedDate: Binding(
                            get: { viewModel.selectedDate },
                            set: { viewModel.selectedDate = $0 }
                        )
                    ) { _ in
                        viewModel.dismissSheets()
                    }
                case .share:
                    DashboardDailyShareSheet(items: viewModel.shareItems, subject: viewModel.shareSubject)
                case .createJob:
                    CreateJobView { job in
                        viewModel.selectedDate = job.date
                        viewModel.dismissSheets()
                    }
                case .syncDetails:
                    DashboardSyncDetailsSheet(jobsViewModel: jobsViewModel)
                }
            }
            .sheet(isPresented: showSystemShareBinding) {
                if !viewModel.jobShareItems.isEmpty {
                    DashboardJobShareSheet(items: viewModel.jobShareItems, subject: viewModel.shareSubject)
                }
            }
            .onAppear {
                viewModel.configureIfNeeded(jobsViewModel: jobsViewModel)
                viewModel.updateNearestJob(with: jobsViewModel.jobs, currentLocation: locationService.current)
                if !ProcessInfo.processInfo.isJobTrackerUITesting {
                    JobPhotoUploadQueue.shared.publishCurrentSyncState()
                }
            }
            .onReceive(locationService.$current) { location in
                viewModel.updateNearestJob(with: jobsViewModel.jobs, currentLocation: location)
            }
            .onReceive(jobsViewModel.$jobs) { newJobs in
                viewModel.handleJobsListChange(newJobs, currentLocation: locationService.current)
            }

            .onReceive(NotificationCenter.default.publisher(for: .jobDeepLinkRequested)) { note in
                guard let jobID = note.userInfo?["jobID"] as? String else { return }
                viewModel.selectedJob = jobsViewModel.jobs.first { $0.id == jobID }
            }
            .onReceive(NotificationCenter.default.publisher(for: .jobImportSucceeded)) { _ in
                viewModel.presentImportSuccessToast()
            }
            .onReceive(NotificationCenter.default.publisher(for: .jobImportFailed)) { note in
                let message: String
                if let error = note.object as? NSError, !error.localizedDescription.isEmpty {
                    message = error.localizedDescription
                } else if let error = note.object as? Error, !error.localizedDescription.isEmpty {
                    message = error.localizedDescription
                } else {
                    message = "Import failed"
                }
                viewModel.presentImportFailureToast(message: message)
            }
            .onReceive(NotificationCenter.default.publisher(for: .jobsSyncStateDidChange)) { note in
                let info = note.userInfo ?? [:]
                let total = (info["total"] as? Int) ?? 0
                let done = (info["uploaded"] as? Int) ?? (info["done"] as? Int) ?? 0
                let inFlight = (info["inFlight"] as? Int) ?? 0
                viewModel.handleSyncStateChange(total: total, done: done, inFlight: inFlight)
            }
            .onReceive(NotificationCenter.default.publisher(for: .jobPhotoUploadsSyncStateDidChange)) { note in
                let info = note.userInfo ?? [:]
                let total = (info["total"] as? Int) ?? 0
                let done = (info["uploaded"] as? Int) ?? (info["done"] as? Int) ?? 0
                let inFlight = (info["inFlight"] as? Int) ?? 0
                let failed = (info["failed"] as? Int) ?? 0
                let waitingForNetwork = (info["waitingForNetwork"] as? Bool) ?? false
                viewModel.handlePhotoUploadSyncStateChange(
                    total: total,
                    done: done,
                    inFlight: inFlight,
                    failed: failed,
                    waitingForNetwork: waitingForNetwork
                )
            }
            .onChange(of: viewModel.showSyncBanner) { _, visible in
                if visible {
                    viewModel.startWaveAnimation()
                } else {
                    viewModel.resetWave()
                }
            }
        }
    }

}
