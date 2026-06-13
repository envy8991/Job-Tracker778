import CoreLocation
import MapKit
import UIKit

/// MapKit-backed address lookup helpers that avoid the iOS 26-deprecated
/// `CLGeocoder` address APIs while keeping coordinate extraction isolated.
enum MapKitGeocoding {
    static func coordinate(for address: String) async -> CLLocationCoordinate2D? {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmedAddress
        request.resultTypes = .address

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.compactMap(coordinate(for:)).first
        } catch {
            return nil
        }
    }

    static func coordinate(for mapItem: MKMapItem) -> CLLocationCoordinate2D? {
        if #available(iOS 26.0, *) {
            return mapItem.location?.coordinate
        } else {
            return legacyCoordinate(for: mapItem)
        }
    }

    static func openDrivingDirections(to coordinate: CLLocationCoordinate2D, with application: UIApplication = .shared) {
        let destination = "\(coordinate.latitude),\(coordinate.longitude)"
        guard let encodedDestination = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "maps://?saddr=Current%20Location&daddr=\(encodedDestination)&dirflg=d") else { return }
        application.open(url)
    }

    @available(iOS, introduced: 2.0, obsoleted: 26.0, message: "Use MKMapItem.location instead.")
    private static func legacyCoordinate(for mapItem: MKMapItem) -> CLLocationCoordinate2D? {
        mapItem.placemark.location?.coordinate
    }
}
