import Combine
import CoreLocation
import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ArrivalAlertManager: ObservableObject {
    struct Status: Equatable {
        enum Kind: Equatable {
            case inactive
            case active
            case warning
            case error
        }

        let kind: Kind
        let message: String
    }

    @Published private(set) var status: Status
    @Published private(set) var authorizationStatus: UNAuthorizationStatus

    private let locationService: LocationService
    private let notificationCenter: UNUserNotificationCenter
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private var cancellables: Set<AnyCancellable> = []
    private var jobs: [Job] = []
    private var jobLookup: [String: Job] = [:]
    private var monitoredJobIDs: Set<String> = []

    private var lastPendingCount: Int = 0
    private var lastMonitorableCount: Int = 0
    private var lastMissingLocationCount: Int = 0
    private var lastTruncatedCount: Int = 0

    private let regionRadius: CLLocationDistance = 120
    private let maxRegionCount = 20
    private let regionIdentifierPrefix = "arrival-alert-job-"
    private let notificationIdentifierPrefix = "arrival-alert-notification-"
    private let regionMonitoringSupported: Bool

    init(
        locationService: LocationService,
        notificationCenter: UNUserNotificationCenter = .current(),
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .current()
    ) {
        self.locationService = locationService
        self.notificationCenter = notificationCenter
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.status = Status(kind: .inactive, message: "Arrival alerts are off for today.")
        self.authorizationStatus = .notDetermined
        self.regionMonitoringSupported = CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
        configureObservers()
        refreshNotificationAuthorizationStatus()
        refreshMonitors()
    }

    // MARK: - Public API

    func updateJobs(_ jobs: [Job]) {
        self.jobs = jobs
        self.jobLookup = Dictionary(uniqueKeysWithValues: jobs.map { ($0.id, $0) })
        refreshMonitors()
    }

    // MARK: - Setup

    private func configureObservers() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.authorizationStatus = settings.authorizationStatus
            }
        }

        NotificationCenter.default.publisher(for: .jobsDidChange)
            .compactMap { $0.object as? [Job] }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] jobs in
                self?.updateJobs(jobs)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleDayChange()
            }
            .store(in: &cancellables)

        userDefaults.publisher(for: \.arrivalAlertsEnabledToday)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMonitors()
            }
            .store(in: &cancellables)

        locationService.regionEventsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handle(regionEvent: event)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .arrivalNotificationAuthorizationDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshNotificationAuthorizationStatus()
            }
            .store(in: &cancellables)

        #if canImport(UIKit)
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshNotificationAuthorizationStatus()
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Monitoring Lifecycle

    private func refreshNotificationAuthorizationStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                let previous = self?.authorizationStatus
                self?.authorizationStatus = settings.authorizationStatus
                if previous != settings.authorizationStatus {
                    self?.refreshMonitors()
                } else {
                    self?.updateStatusForActiveMonitors()
                }
            }
        }
    }

    private func handleDayChange() {
        stopAllMonitors()
        refreshMonitors()
    }

    private func refreshMonitors() {
        guard regionMonitoringSupported else {
            stopAllMonitors()
            status = Status(kind: .error, message: "This device doesn't support arrival alerts.")
            return
        }

        guard userDefaults.bool(forKey: "arrivalAlertsEnabledToday") else {
            stopAllMonitors()
            status = Status(kind: .inactive, message: "Arrival alerts are off for today.")
            return
        }

        let locationStatus = CLLocationManager.authorizationStatus()
        guard locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse else {
            stopAllMonitors()
            switch locationStatus {
            case .denied, .restricted:
                status = Status(kind: .warning, message: "Location access is required for arrival alerts. Enable it in Settings.")
            case .notDetermined:
                status = Status(kind: .warning, message: "Grant location access to finish turning on arrival alerts.")
            default:
                status = Status(kind: .warning, message: "Arrival alerts need location access to run.")
            }
            return
        }

        guard isNotificationAuthorized else {
            stopAllMonitors()
            switch authorizationStatus {
            case .denied:
                status = Status(kind: .warning, message: "Notifications are turned off. Enable them in Settings to get arrival alerts.")
            case .notDetermined:
                status = Status(kind: .warning, message: "Allow notifications to enable arrival alerts.")
            default:
                status = Status(kind: .warning, message: "Notifications must stay enabled for arrival alerts.")
            }
            return
        }

        guard !jobs.isEmpty else {
            stopAllMonitors()
            status = Status(kind: .inactive, message: "Jobs are still loading for today.")
            return
        }

        let today = Date()
        let pendingJobs = jobs.filter { job in
            calendar.isDate(job.date, inSameDayAs: today) && job.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "pending"
        }
        lastPendingCount = pendingJobs.count

        guard !pendingJobs.isEmpty else {
            stopAllMonitors()
            status = Status(kind: .inactive, message: "No pending jobs today to monitor.")
            return
        }

        let monitorableJobs: [(job: Job, location: CLLocation)] = pendingJobs.compactMap { job in
            guard let location = job.clLocation else { return nil }
            return (job, location)
        }
        lastMonitorableCount = monitorableJobs.count
        lastMissingLocationCount = max(0, pendingJobs.count - monitorableJobs.count)
        lastTruncatedCount = 0

        guard !monitorableJobs.isEmpty else {
            stopAllMonitors(resetCounters: false)
            status = Status(kind: .warning, message: "Add map locations to today's jobs to enable arrival alerts.")
            return
        }

        let limited = Array(monitorableJobs.prefix(maxRegionCount))
        lastTruncatedCount = max(0, monitorableJobs.count - limited.count)

        let newIDs = Set(limited.map { $0.job.id })
        let removed = monitoredJobIDs.subtracting(newIDs)
        if !removed.isEmpty {
            removeNotifications(for: removed)
            for id in removed {
                locationService.stopMonitoringRegion(withIdentifier: regionIdentifier(for: id))
            }
        }
        monitoredJobIDs.subtract(removed)

        for entry in limited where !monitoredJobIDs.contains(entry.job.id) {
            let identifier = regionIdentifier(for: entry.job.id)
            locationService.stopMonitoringRegion(withIdentifier: identifier)
            let region = CLCircularRegion(center: entry.location.coordinate, radius: regionRadius, identifier: identifier)
            region.notifyOnEntry = true
            region.notifyOnExit = false
            locationService.startMonitoring(region: region)
            monitoredJobIDs.insert(entry.job.id)
        }

        updateStatusForActiveMonitors()
    }

    private func stopAllMonitors(resetCounters: Bool = true) {
        removeNotifications(for: monitoredJobIDs)
        locationService.stopMonitoringRegions(withPrefix: regionIdentifierPrefix)
        monitoredJobIDs.removeAll()
        if resetCounters {
            lastPendingCount = 0
            lastMonitorableCount = 0
            lastMissingLocationCount = 0
            lastTruncatedCount = 0
        }
    }

    private func updateStatusForActiveMonitors() {
        guard !monitoredJobIDs.isEmpty else {
            if userDefaults.bool(forKey: "arrivalAlertsEnabledToday") {
                if lastPendingCount == 0 {
                    status = Status(kind: .inactive, message: "No pending jobs today to monitor.")
                } else if lastMonitorableCount == 0 && lastMissingLocationCount > 0 {
                    status = Status(kind: .warning, message: "Add map locations to today's jobs to enable arrival alerts.")
                } else {
                    status = Status(kind: .inactive, message: "Arrival alerts are ready when new jobs sync.")
                }
            } else {
                status = Status(kind: .inactive, message: "Arrival alerts are off for today.")
            }
            return
        }

        var components: [String] = []
        let count = monitoredJobIDs.count
        let jobWord = count == 1 ? "job" : "jobs"
        components.append("Monitoring \(count) pending \(jobWord) today.")

        if lastMissingLocationCount > 0 {
            let missingWord = lastMissingLocationCount == 1 ? "job" : "jobs"
            components.append("\(lastMissingLocationCount) pending \(missingWord) missing a map location won't alert.")
        }

        if lastTruncatedCount > 0 {
            components.append("Showing the first \(count) stops out of \(lastMonitorableCount).")
        }

        status = Status(kind: .active, message: components.joined(separator: " "))
    }

    // MARK: - Region Events

    private func handle(regionEvent: LocationService.RegionEvent) {
        switch regionEvent {
        case .entered(let identifier):
            guard let jobID = jobID(fromRegionIdentifier: identifier),
                  monitoredJobIDs.contains(jobID),
                  let job = jobLookup[jobID]
            else { return }

            locationService.stopMonitoringRegion(withIdentifier: identifier)
            monitoredJobIDs.remove(jobID)
            scheduleNotification(for: job)
            updateStatusForActiveMonitors()
        case .monitoringFailed(let identifier, let error):
            if let identifier, let jobID = jobID(fromRegionIdentifier: identifier) {
                monitoredJobIDs.remove(jobID)
            }
            status = Status(kind: .error, message: "Arrival alerts error: \(error.localizedDescription)")
        }
    }

    private func scheduleNotification(for job: Job) {
        guard isNotificationAuthorized else { return }

        let identifier = notificationIdentifier(for: job.id)
        removeNotifications(for: [job.id])

        let content = UNMutableNotificationContent()
        content.title = "You're at \(job.shortAddress)"
        content.body = "Open Job Tracker to update the job status when you're done."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        notificationCenter.add(request) { [weak self] error in
            guard let self = self else { return }
            Task { @MainActor in
                if let error = error {
                    self.status = Status(kind: .error, message: "Couldn't schedule arrival alert: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helpers

    private var isNotificationAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional:
            return true
        #if compiler(>=5.9)
        case .ephemeral:
            return true
        #endif
        default:
            return false
        }
    }

    private func regionIdentifier(for jobID: String) -> String {
        "\(regionIdentifierPrefix)\(jobID)"
    }

    private func jobID(fromRegionIdentifier identifier: String) -> String? {
        guard identifier.hasPrefix(regionIdentifierPrefix) else { return nil }
        return String(identifier.dropFirst(regionIdentifierPrefix.count))
    }

    private func notificationIdentifier(for jobID: String) -> String {
        "\(notificationIdentifierPrefix)\(jobID)"
    }

    private func removeNotifications<S: Sequence>(for jobIDs: S) where S.Element == String {
        let identifiers = jobIDs.map(notificationIdentifier)
        if !identifiers.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }
}

extension Notification.Name {
    static let arrivalNotificationAuthorizationDidChange = Notification.Name("arrivalNotificationAuthorizationDidChange")
}
