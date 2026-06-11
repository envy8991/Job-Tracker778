import CarPlay
import CoreLocation
import Foundation
import MapKit
import UIKit

@objc(JobDispatchCarPlaySceneDelegate)
@MainActor
final class JobDispatchCarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private let service = CarPlayJobDispatchService()

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        interfaceController.setRootTemplate(loadingTemplate(), animated: false, completion: nil)
        Task { await reloadJobs(animated: true) }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        if self.interfaceController === interfaceController {
            self.interfaceController = nil
        }
    }

    private func reloadJobs(animated: Bool) async {
        let state = await service.loadTodayDashboardJobs()
        let template: CPListTemplate

        switch state {
        case let .jobs(displays, locationAvailable):
            template = jobsTemplate(displays: displays, locationAvailable: locationAvailable)
        case .signedOut:
            template = messageTemplate(
                title: "Job Tracker",
                message: "Sign in on your iPhone to see today's dashboard jobs in CarPlay."
            )
        case let .error(message):
            template = messageTemplate(
                title: "Can't Load Jobs",
                message: message.isEmpty ? "Check your connection and try again." : message
            )
        }

        interfaceController?.setRootTemplate(template, animated: animated, completion: nil)
    }

    private func loadingTemplate() -> CPListTemplate {
        messageTemplate(title: "Today's Jobs", message: "Loading your dashboard jobs…")
    }

    private func jobsTemplate(displays: [CarPlayJobDisplay], locationAvailable: Bool) -> CPListTemplate {
        let title = "Today's Jobs"
        var sections: [CPListSection] = []

        if displays.isEmpty {
            sections.append(
                CPListSection(items: [
                    informationalItem(
                        title: "No jobs on your dashboard today",
                        detail: "Jobs you created for today will appear here."
                    )
                ])
            )
        } else {
            let jobItems = displays.map { display in
                let item = CPListItem(text: display.title, detailText: display.detail)
                item.accessoryType = .disclosureIndicator
                item.handler = { [weak self] _, completion in
                    Task { @MainActor in
                        self?.showDetail(for: display)
                        completion()
                    }
                }
                return item
            }
            sections.append(CPListSection(items: jobItems))
        }

        let refreshItem = CPListItem(
            text: "Refresh Jobs",
            detailText: locationAvailable ? "Update today's dashboard jobs" : "Update jobs; location unavailable"
        )
        refreshItem.handler = { [weak self] _, completion in
            Task { @MainActor in
                await self?.reloadJobs(animated: true)
                completion()
            }
        }
        sections.append(CPListSection(items: [refreshItem]))

        return CPListTemplate(title: title, sections: sections)
    }

    private func messageTemplate(title: String, message: String) -> CPListTemplate {
        let retry = CPListItem(text: "Refresh", detailText: "Try loading jobs again")
        retry.handler = { [weak self] _, completion in
            Task { @MainActor in
                await self?.reloadJobs(animated: true)
                completion()
            }
        }

        return CPListTemplate(
            title: title,
            sections: [
                CPListSection(items: [informationalItem(title: message, detail: nil)]),
                CPListSection(items: [retry])
            ]
        )
    }

    private func showDetail(for display: CarPlayJobDisplay) {
        let directionsItem = CPListItem(text: "Start Directions", detailText: display.fullAddress)
        directionsItem.handler = { [weak self] _, completion in
            Task { @MainActor in
                await self?.openDirections(to: display)
                completion()
            }
        }

        let statusItem = informationalItem(title: "Status", detail: display.job.displayStatus)
        let addressItem = informationalItem(title: "Address", detail: display.fullAddress)
        var details = [directionsItem, statusItem, addressItem]

        if let jobNumber = display.job.jobNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !jobNumber.isEmpty {
            details.append(informationalItem(title: "Job Number", detail: jobNumber))
        }
        if let locationNumber = display.job.locationNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !locationNumber.isEmpty {
            details.append(informationalItem(title: "Location Number", detail: locationNumber))
        }
        if let portalID = display.job.portalID?.trimmingCharacters(in: .whitespacesAndNewlines), !portalID.isEmpty {
            details.append(informationalItem(title: "Portal ID", detail: portalID))
        }
        if let assignments = display.job.assignments?.trimmingCharacters(in: .whitespacesAndNewlines), !assignments.isEmpty {
            details.append(informationalItem(title: "Assignment", detail: assignments))
        }
        if let materials = display.job.materialsUsed?.trimmingCharacters(in: .whitespacesAndNewlines), !materials.isEmpty {
            details.append(informationalItem(title: "Materials", detail: materials))
        }
        if let nidFootage = display.job.nidFootage?.trimmingCharacters(in: .whitespacesAndNewlines), !nidFootage.isEmpty {
            details.append(informationalItem(title: "NID Footage", detail: nidFootage))
        }
        if let canFootage = display.job.canFootage?.trimmingCharacters(in: .whitespacesAndNewlines), !canFootage.isEmpty {
            details.append(informationalItem(title: "Can Footage", detail: canFootage))
        }
        if let placement = display.job.jobPlacement?.trimmingCharacters(in: .whitespacesAndNewlines), !placement.isEmpty {
            details.append(informationalItem(title: "Placement", detail: placement))
        }
        if let notes = display.job.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            details.append(informationalItem(title: "Notes", detail: notes))
        }

        let template = CPListTemplate(
            title: display.title,
            sections: [CPListSection(items: details)]
        )
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func informationalItem(title: String, detail: String?) -> CPListItem {
        let item = CPListItem(text: title, detailText: detail)
        item.isEnabled = false
        return item
    }

    private func openDirections(to display: CarPlayJobDisplay) async {
        if UserDefaults.standard.string(forKey: "addressSuggestionProvider") == "google",
           await openGoogleMaps(to: display) {
            return
        }

        if let coordinate = display.coordinate {
            openAppleMaps(coordinate: coordinate, name: display.title)
            return
        }

        let geocodedCoordinate = await geocode(display.fullAddress)
        if let geocodedCoordinate {
            openAppleMaps(coordinate: geocodedCoordinate, name: display.title)
            return
        }

        openAppleMapsAddress(display.fullAddress)
    }

    private func openGoogleMaps(to display: CarPlayJobDisplay) async -> Bool {
        let destination: String
        if let coordinate = display.coordinate {
            destination = "\(coordinate.latitude),\(coordinate.longitude)"
        } else {
            destination = display.fullAddress
        }

        guard let encoded = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "comgooglemaps://?daddr=\(encoded)&directionsmode=driving") else {
            return false
        }

        return await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
    }

    private func geocode(_ address: String) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(address) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }

    private func openAppleMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let source = MKMapItem.forCurrentLocation()
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        destination.name = name
        MKMapItem.openMaps(
            with: [source, destination],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        )
    }

    private func openAppleMapsAddress(_ address: String) {
        guard let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "maps://?saddr=Current%20Location&daddr=\(encoded)&dirflg=d") else { return }
        UIApplication.shared.open(url)
    }
}
