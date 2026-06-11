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
        interfaceController.setRootTemplate(loadingTemplate(), animated: false)
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
        let state = await service.loadTodayPendingJobs()
        let template: CPListTemplate

        switch state {
        case let .jobs(displays, locationAvailable):
            template = jobsTemplate(displays: displays, locationAvailable: locationAvailable)
        case .signedOut:
            template = messageTemplate(
                title: "Job Tracker",
                message: "Sign in on your iPhone to see today's assigned jobs in CarPlay."
            )
        case let .error(message):
            template = messageTemplate(
                title: "Can't Load Jobs",
                message: message.isEmpty ? "Check your connection and try again." : message
            )
        }

        interfaceController?.setRootTemplate(template, animated: animated)
    }

    private func loadingTemplate() -> CPListTemplate {
        messageTemplate(title: "Today's Jobs", message: "Loading assigned jobs…")
    }

    private func jobsTemplate(displays: [CarPlayJobDisplay], locationAvailable: Bool) -> CPListTemplate {
        let title = "Today's Jobs"
        var sections: [CPListSection] = []

        if displays.isEmpty {
            sections.append(
                CPListSection(items: [
                    informationalItem(
                        title: "No pending jobs today",
                        detail: "You're clear for now."
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
            detailText: locationAvailable ? "Update today's assignments" : "Update jobs; location unavailable"
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
        if let assignments = display.job.assignments?.trimmingCharacters(in: .whitespacesAndNewlines), !assignments.isEmpty {
            details.append(informationalItem(title: "Assignment", detail: assignments))
        }

        let template = CPListTemplate(
            title: display.title,
            sections: [CPListSection(items: details)]
        )
        interfaceController?.pushTemplate(template, animated: true)
    }

    private func informationalItem(title: String, detail: String?) -> CPListItem {
        let item = CPListItem(text: title, detailText: detail)
        item.isEnabled = false
        return item
    }

    private func openDirections(to display: CarPlayJobDisplay) async {
        if let coordinate = display.coordinate {
            openMaps(coordinate: coordinate, name: display.title)
            return
        }

        let geocodedCoordinate = await geocode(display.fullAddress)
        if let geocodedCoordinate {
            openMaps(coordinate: geocodedCoordinate, name: display.title)
            return
        }

        if let encoded = display.fullAddress.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "maps://?saddr=Current%20Location&daddr=\(encoded)&dirflg=d") {
            UIApplication.shared.open(url)
        }
    }

    private func geocode(_ address: String) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            CLGeocoder().geocodeAddressString(address) { placemarks, _ in
                continuation.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }

    private func openMaps(coordinate: CLLocationCoordinate2D, name: String) {
        let source = MKMapItem.forCurrentLocation()
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        destination.name = name
        MKMapItem.openMaps(
            with: [source, destination],
            launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        )
    }
}
