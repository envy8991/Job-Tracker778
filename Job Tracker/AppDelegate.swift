//
//  AppDelegate.swift
//  Job Tracking Cable South
//
//  Created by Quinton  Thompson  on 1/30/25.
//


import UIKit
import UserNotifications
import FirebaseCore
import Firebase
#if canImport(GooglePlaces)
import GooglePlaces
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #if canImport(GooglePlaces)
        GMSPlacesClient.provideAPIKey("AIzaSyABtSWf7_UPKKD-O83BYmhUlslXZHdp7U0")
        #endif

        configureNotifications()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) { }
    func applicationWillEnterForeground(_ application: UIApplication) { }

    private func configureNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .arrivalNotificationAuthorizationDidChange, object: granted)
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
