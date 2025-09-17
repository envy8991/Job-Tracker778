//
//  DirectionsToNextJobIntent.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/17/25.
//


// DirectionsToNextJobIntent.swift
import AppIntents
import CoreLocation
import UIKit
import MapKit

@available(iOS 16.0, *)
struct DirectionsToNextJobIntent: AppIntent {
    static var title: LocalizedStringResource = "Directions to Next Job"
    static var description = IntentDescription("Opens Maps to your next pending job today.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some ProvidesDialog {
        let today = Date()
        let jobs = try await FirebaseService.shared.fetchJobsAsync(for: today)
        // Next job should come from the Pending list only, choose earliest by date (today only)
        let candidates = jobs.filter { $0.status.lowercased() == "pending" }
        guard let target = candidates.sorted(by: { $0.date < $1.date }).first else {
            return .result(dialog: IntentDialog("You have no pending jobs to navigate to today."))
        }

        let short = shortAddress(target.address)

        // Prefer stored coordinates if present; otherwise geocode the address
        var targetCoordinate: CLLocationCoordinate2D? = nil
        if let lat = target.latitude, let lon = target.longitude {
            targetCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            // Geocode synchronously for a single best result (non-throwing continuation)
            let geocoded: CLPlacemark? = await withCheckedContinuation { (cont: CheckedContinuation<CLPlacemark?, Never>) in
                CLGeocoder().geocodeAddressString(target.address) { placemarks, _ in
                    cont.resume(returning: placemarks?.first)
                }
            }
            if let loc = geocoded?.location?.coordinate {
                targetCoordinate = loc
            }
        }

        guard let coord = targetCoordinate else {
            return .result(dialog: IntentDialog("Couldn't determine a location for that address."))
        }

        // Open Apple Maps using MKMapItem (allowed from App Intents when app is foregrounded)
        await MainActor.run {
            let src = MKMapItem.forCurrentLocation()
            let dst = MKMapItem(placemark: MKPlacemark(coordinate: coord))
            dst.name = short
            MKMapItem.openMaps(
                with: [src, dst],
                launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
            )
        }
        return .result(dialog: IntentDialog("Opening directions to \(short)."))
        }
    }



@available(iOS 16.0, *)
struct NextJobAddressIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Job Address"
    static var description = IntentDescription("Speaks the address of your next pending job today.")

    func perform() async throws -> some ProvidesDialog {
        let today = Date()
        let jobs = try await FirebaseService.shared.fetchJobsAsync(for: today)
        let candidates = jobs.filter { $0.status.lowercased() == "pending" }
        guard let target = candidates.sorted(by: { $0.date < $1.date }).first else {
            return .result(dialog: IntentDialog("You have no pending jobs lined up today."))
        }

        let parts = target.address.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let spoken = parts.count >= 2 ? "\(parts[0]), \(parts[1])" : target.address
        return .result(dialog: IntentDialog("Your next job is at \(spoken)."))
    }
}

fileprivate func shortAddress(_ full: String) -> String {
    if let comma = full.firstIndex(of: ",") { return String(full[..<comma]) }
    return full
}
