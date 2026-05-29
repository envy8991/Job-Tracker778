import AppIntents
import CoreLocation
import Foundation

@available(iOS 16.0, *)
struct JobIntentTarget {
    let job: Job
    let locationWasUsed: Bool
    let distanceInMeters: CLLocationDistance?
    let fallbackReason: String?
}

@available(iOS 16.0, *)
enum JobIntentFormatter {
    static func shortAddress(_ full: String) -> String {
        if let comma = full.firstIndex(of: ",") { return String(full[..<comma]) }
        return full
    }

    static func spokenValue(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func footageLabel(_ rawValue: String?) -> String? {
        guard let value = spokenValue(rawValue) else { return nil }
        let lower = value.lowercased()
        if lower.contains("foot") || lower.contains("feet") || lower.contains("'") { return value }
        return "\(value) feet"
    }

    static func jobContext(_ target: JobIntentTarget) -> String {
        let address = shortAddress(target.job.address)
        if let distance = target.distanceInMeters, target.locationWasUsed {
            if distance < 80 { return "the job you're at, \(address)" }
            let miles = distance / 1609.344
            return String(format: "the closest job, %@, %.1f miles away", address, miles)
        }
        return address
    }
}

@available(iOS 16.0, *)
final class JobIntentLocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func currentLocation() async -> CLLocation? {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            }
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { self?.finish(with: nil) }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }

    private func finish(with location: CLLocation?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation?.resume(returning: location)
        continuation = nil
    }
}

@available(iOS 16.0, *)
enum JobIntentResolution {
    case success(JobIntentTarget)
    case failure(IntentDialog)
}

@available(iOS 16.0, *)
enum JobIntentResolver {
    static func todayJobs() async throws -> [Job] {
        try await FirebaseService.shared.fetchJobsAsync(for: Date())
    }

    static func nearestTodayJob() async throws -> JobIntentTarget? {
        let jobs = try await todayJobs()
        guard !jobs.isEmpty else { return nil }

        let locationProvider = JobIntentLocationProvider()
        let currentLocation = await locationProvider.currentLocation()
        if let currentLocation {
            let locatedJobs = jobs.compactMap { job -> (job: Job, distance: CLLocationDistance)? in
                guard let jobLocation = job.clLocation else { return nil }
                return (job, jobLocation.distance(from: currentLocation))
            }

            if let nearest = locatedJobs.min(by: { $0.distance < $1.distance }) {
                return JobIntentTarget(
                    job: nearest.job,
                    locationWasUsed: true,
                    distanceInMeters: nearest.distance,
                    fallbackReason: nil
                )
            }
        }

        let fallback = jobs
            .sorted { lhs, rhs in
                if lhs.status.lowercased() == "done" && rhs.status.lowercased() != "done" { return false }
                if lhs.status.lowercased() != "done" && rhs.status.lowercased() == "done" { return true }
                return lhs.date < rhs.date
            }
            .first

        guard let fallback else { return nil }
        return JobIntentTarget(
            job: fallback,
            locationWasUsed: false,
            distanceInMeters: nil,
            fallbackReason: "I couldn't use your current location, so I used your next job for today."
        )
    }

    static func nearestJobOrDialog() async throws -> JobIntentResolution {
        guard let target = try await nearestTodayJob() else {
            return .failure(IntentDialog("You don't have any jobs scheduled for today."))
        }
        return .success(target)
    }
}
