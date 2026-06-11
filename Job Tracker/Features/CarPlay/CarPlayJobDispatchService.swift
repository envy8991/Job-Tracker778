import CoreLocation
import Foundation

struct CarPlayJobDisplay: Identifiable, Hashable {
    let job: Job
    let distance: CLLocationDistance?

    var id: String { job.id }

    var title: String {
        let short = job.shortAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return short.isEmpty ? "Job" : short
    }

    var detail: String {
        var parts: [String] = []
        if let distance {
            parts.append(Self.formatDistance(distance))
        }
        parts.append(job.displayStatus)
        if let jobNumber = job.jobNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !jobNumber.isEmpty {
            parts.append("Job #\(jobNumber)")
        }
        return parts.joined(separator: " • ")
    }

    var fullAddress: String {
        job.address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude = job.latitude, let longitude = job.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func formatDistance(_ meters: CLLocationDistance) -> String {
        guard meters.isFinite else { return "" }
        let miles = meters / 1_609.344
        if miles >= 10 {
            return "\(Int(miles.rounded())) mi"
        }
        if miles >= 0.1 {
            return String(format: "%.1f mi", miles)
        }
        let feet = meters * 3.28084
        return "\(Int(feet.rounded())) ft"
    }
}

@MainActor
final class CarPlayJobDispatchService {
    enum SnapshotState {
        case jobs([CarPlayJobDisplay], locationAvailable: Bool, smartRoutingEnabled: Bool, orderedByDistance: Bool, sortedClosestFirst: Bool)
        case signedOut
        case error(String)
    }

    private let locationProvider: CarPlayLocationProvider
    private let firebaseService: FirebaseService
    private let userDefaults: UserDefaults
    private let maxJobs = 12

    init(
        locationProvider: CarPlayLocationProvider = .shared,
        firebaseService: FirebaseService = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.locationProvider = locationProvider
        self.firebaseService = firebaseService
        self.userDefaults = userDefaults
    }

    func loadTodayPendingJobs() async -> SnapshotState {
        guard let currentUserID = firebaseService.currentUserID() else {
            return .signedOut
        }

        do {
            let shouldOrderByDistance = userDefaults.bool(forKey: "smartRoutingEnabled")
            let sortedClosestFirst = userDefaults.string(forKey: "routingOptimizeBy") != "farthest"
            let here = shouldOrderByDistance ? await locationProvider.currentLocation() : nil
            let jobs = try await firebaseService.fetchJobsAsync(for: Date())
            let pendingCreatedByUser = jobs.filter { job in
                job.isPending && job.createdBy == currentUserID
            }
            let displays = sortedDisplays(
                for: pendingCreatedByUser,
                currentLocation: here,
                orderByDistance: shouldOrderByDistance,
                sortedClosestFirst: sortedClosestFirst
            )
            return .jobs(
                Array(displays.prefix(maxJobs)),
                locationAvailable: here != nil,
                smartRoutingEnabled: shouldOrderByDistance,
                orderedByDistance: shouldOrderByDistance && here != nil,
                sortedClosestFirst: sortedClosestFirst
            )
        } catch {
            return .error(error.localizedDescription)
        }
    }

    private func sortedDisplays(
        for jobs: [Job],
        currentLocation: CLLocation?,
        orderByDistance: Bool,
        sortedClosestFirst: Bool
    ) -> [CarPlayJobDisplay] {
        let displays = jobs.map { job -> CarPlayJobDisplay in
            let distance = currentLocation.flatMap { here in job.clLocation?.distance(from: here) }
            return CarPlayJobDisplay(job: job, distance: distance)
        }

        return displays.sorted { lhs, rhs in
            if orderByDistance, currentLocation != nil {
                switch (lhs.distance, rhs.distance) {
                case let (left?, right?):
                    if left != right {
                        return sortedClosestFirst ? left < right : left > right
                    }
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    break
                }
            }

            if lhs.job.date != rhs.job.date {
                return lhs.job.date < rhs.job.date
            }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

@MainActor
final class CarPlayLocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = CarPlayLocationProvider()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var timeoutWorkItem: DispatchWorkItem?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
        manager.activityType = .automotiveNavigation
    }

    func currentLocation() async -> CLLocation? {
        if let recent = manager.location, abs(recent.timestamp.timeIntervalSinceNow) < 300 {
            return recent
        }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return await withCheckedContinuation { continuation in
                finish(with: nil)
                self.continuation = continuation
                manager.requestLocation()

                let timeout = DispatchWorkItem { [weak self] in
                    Task { @MainActor in
                        self?.finish(with: self?.manager.location)
                    }
                }
                timeoutWorkItem = timeout
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeout)
            }
        case .notDetermined, .restricted, .denied:
            return manager.location
        @unknown default:
            return manager.location
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.last ?? manager.location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: manager.location)
    }

    private func finish(with location: CLLocation?) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: location)
    }
}
