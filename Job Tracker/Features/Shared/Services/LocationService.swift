//
//  LocationService.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 5/1/25.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

final class LocationService: NSObject, ObservableObject {
    @Published var current: CLLocation?
    
    private let manager = CLLocationManager()
    private var smartRoutingCancellable: AnyCancellable?
    
    override init() {
        super.init()
        manager.delegate = self

        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter  = 50
        manager.activityType    = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = true
        manager.allowsBackgroundLocationUpdates = false
        
        // React to Settings toggle
        smartRoutingCancellable =
            UserDefaults.standard
                .publisher(for: \.smartRoutingEnabled)
                .sink { [weak self] on in
                    on ? self?.start() : self?.stopAllUpdates()
                }
    }

    deinit {
        smartRoutingCancellable?.cancel()
    }
    
    // MARK: - Control
    
    private func start() {
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        #else
        let isActive = true
        #endif
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if isActive {
                // Foreground: standard updates
                manager.allowsBackgroundLocationUpdates = false
                manager.stopMonitoringSignificantLocationChanges()
                manager.startUpdatingLocation()
            } else {
                // Background/inactive: significant-change only
                manager.allowsBackgroundLocationUpdates = false
                manager.stopUpdatingLocation()
                manager.startMonitoringSignificantLocationChanges()
            }
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            stopAllUpdates()
        }
    }
    
    private func stop() {
        manager.stopUpdatingLocation()
    }

    /// Foreground: frequent updates
    func startStandardUpdates() {
        #if canImport(UIKit)
        guard UIApplication.shared.applicationState == .active else {
            stopStandardUpdates()
            return
        }
        #endif
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            stopStandardUpdates(); return
        }
        manager.allowsBackgroundLocationUpdates = false
        manager.stopMonitoringSignificantLocationChanges()
        manager.startUpdatingLocation()
    }

    func stopStandardUpdates() {
        manager.stopUpdatingLocation()
    }

    /// Background: battery-friendly updates
    func startSignificantChangeUpdates() {
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            stopSignificantChangeUpdates(); return
        }
        manager.allowsBackgroundLocationUpdates = false
        manager.stopUpdatingLocation()
        manager.startMonitoringSignificantLocationChanges()
    }

    func stopSignificantChangeUpdates() {
        manager.stopMonitoringSignificantLocationChanges()
    }

    func stopAllUpdates() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let last = locs.last else { return }
        // Publish on main for SwiftUI safety
        DispatchQueue.main.async { self.current = last }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        #if canImport(UIKit)
        let isActive = UIApplication.shared.applicationState == .active
        #else
        let isActive = true
        #endif
        switch m.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if UserDefaults.standard.bool(forKey: "smartRoutingEnabled") {
                if isActive {
                    self.startStandardUpdates()
                } else {
                    self.stopStandardUpdates()
                    self.startSignificantChangeUpdates()
                }
            } else {
                self.stopAllUpdates()
            }
        case .denied, .restricted:
            self.stopAllUpdates()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

// Allow Combine KVO on the toggle
extension UserDefaults {
    @objc dynamic var smartRoutingEnabled: Bool { bool(forKey: "smartRoutingEnabled") }
}
