//
//  AppDelegate.swift
//  Job Tracking Cable South
//
//  Created by Quinton  Thompson  on 1/30/25.
//


import UIKit
import CarPlay
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
        if !ProcessInfo.processInfo.isJobTrackerUITesting, FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #if canImport(GooglePlaces)
        GMSPlacesClient.provideAPIKey("AIzaSyABtSWf7_UPKKD-O83BYmhUlslXZHdp7U0")
        #endif

        if !ProcessInfo.processInfo.isJobTrackerUITesting {
            configureNotifications()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role.rawValue == "CPTemplateApplicationSceneSessionRoleApplication" {
            let configuration = UISceneConfiguration(
                name: "JobDispatchCarPlay",
                sessionRole: connectingSceneSession.role
            )
            configuration.sceneClass = CPTemplateApplicationScene.self
            configuration.delegateClass = JobDispatchCarPlaySceneDelegate.self
            return configuration
        }

        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
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
