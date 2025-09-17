// Watch App target → JobTrackerWatchApp.swift

import SwiftUI

@main
struct JobTrackerWatchApp: App {
    @StateObject private var bridge = WatchBridge()
    @StateObject private var jobsVM = WatchJobsViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchDashboardView()
            }
            .environmentObject(bridge)
            .environmentObject(jobsVM)
            .onAppear {
                bridge.activate()
                jobsVM.bind(to: bridge)
            }
        }
    }
}
