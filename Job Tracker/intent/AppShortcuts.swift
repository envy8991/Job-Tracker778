//
//  AppShortcuts.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/17/25.
//

// AppShortcuts.swift
import AppIntents

@available(iOS 16.0, *)
struct JobTrackerShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        return [
            AppShortcut(
                intent: CreateJobIntent(),
                phrases: [
                    "Create a job in \(.applicationName)",
                    "Add job with \(.applicationName)"
                ],
                shortTitle: "Create Job",
                systemImageName: "plus.circle"
            ),
            AppShortcut(
                intent: UpdateJobStatusIntent(),
                phrases: [
                    "Mark job as \(.applicationName)",
                    "Update job status in \(.applicationName)"
                ],
                shortTitle: "Update Job Status",
                systemImageName: "checkmark.circle"
            ),
            AppShortcut(
                intent: GetTodayJobsIntent(),
                phrases: [
                    "What are my jobs today in \(.applicationName)",
                    "Show today's jobs with \(.applicationName)"
                ],
                shortTitle: "Today’s Jobs",
                systemImageName: "calendar"
            ),
            AppShortcut(
                intent: DirectionsToNextJobIntent(),
                phrases: [
                    "Directions to my next job in \(.applicationName)",
                    "Navigate to next job with \(.applicationName)"
                ],
                shortTitle: "Directions to Next Job",
                systemImageName: "map"
            )
            ,
            AppShortcut(
                intent: NextJobAddressIntent(),
                phrases: [
                    "What is my next job address in \(.applicationName)",
                    "Next job address with \(.applicationName)"
                ],
                shortTitle: "Next Job Address",
                systemImageName: "mappin.and.ellipse"
            )
        ]
    }
}
