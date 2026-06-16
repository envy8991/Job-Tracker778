//
//  AppShortcuts.swift
//  Job Tracker
//
//  Created by Quinton Thompson on 8/17/25.
//

// AppShortcuts.swift
import AppIntents

@available(iOS 26.0, *)
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
            ,
            AppShortcut(
                intent: GetNearestJobAssignmentIntent(),
                phrases: [
                    "What's the assignment for my job in \(.applicationName)",
                    "What is my current job assignment in \(.applicationName)",
                    "Get my job assignment with \(.applicationName)"
                ],
                shortTitle: "Current Assignment",
                systemImageName: "list.number"
            ),
            AppShortcut(
                intent: SetNearestJobAssignmentIntent(),
                phrases: [
                    "Add assignment to my job in \(.applicationName)",
                    "Set my current job assignment with \(.applicationName)"
                ],
                shortTitle: "Set Assignment",
                systemImageName: "square.and.pencil"
            ),
            AppShortcut(
                intent: SetNearestJobFootageIntent(),
                phrases: [
                    "Add CAN and NID footage in \(.applicationName)",
                    "Add footage to my current job with \(.applicationName)",
                    "Save CAN and NID footage with \(.applicationName)"
                ],
                shortTitle: "Add Footage",
                systemImageName: "ruler"
            ),
            AppShortcut(
                intent: GetNearestJobFootageIntent(),
                phrases: [
                    "What's the footage for my job in \(.applicationName)",
                    "Get my current job footage with \(.applicationName)"
                ],
                shortTitle: "Current Footage",
                systemImageName: "ruler.fill"
            ),
            AppShortcut(
                intent: GetNearestJobSummaryIntent(),
                phrases: [
                    "What's my current job in \(.applicationName)",
                    "Tell me about my job with \(.applicationName)",
                    "Current job details in \(.applicationName)"
                ],
                shortTitle: "Current Job",
                systemImageName: "briefcase"
            )
        ]
    }
}
