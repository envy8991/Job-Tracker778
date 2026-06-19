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
            return mapItem.location.coordinate
        } else {
            return legacyPlacemarkCoordinate(for: mapItem)
        }
    }

    @discardableResult
    static func openDrivingDirections(
        to coordinate: CLLocationCoordinate2D,
        name: String? = nil,
        with application: UIApplication = .shared
    ) -> Bool {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return false }

        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "dirflg", value: "d")
        ]

        guard let url = components?.url else { return false }
        application.open(url)
        return true
    }

    @discardableResult
    static func openDrivingDirections(to address: String, name: String? = nil) -> Bool {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else { return false }

        var components = URLComponents(string: "http://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: trimmedAddress),
            URLQueryItem(name: "dirflg", value: "d")
        ]

        guard let url = components?.url else { return false }
        UIApplication.shared.open(url)
        return true
    }

    @available(iOS, introduced: 2.0, deprecated: 26.0, message: "Use MKMapItem.location instead.")
    private static func legacyPlacemarkCoordinate(for mapItem: MKMapItem) -> CLLocationCoordinate2D? {
        mapItem.placemark.location?.coordinate
    }
}
