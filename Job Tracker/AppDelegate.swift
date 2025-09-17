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
        // Notifications feature disabled — skip UNUserNotificationCenter setup
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) { }
    func applicationWillEnterForeground(_ application: UIApplication) { }

    // Notifications feature disabled — notification permission and delegate methods removed.
}
