# Job Tracker

Job Tracker is a SwiftUI application for fiber technicians and supervisors. It centralizes daily job assignments, collaborative tools, compliance paperwork, and supervisor controls in a single workspace backed by Firebase. The repository also contains a watchOS companion for quick-glance updates and an iMessage extension for sharing assignments in conversation.

The app targets modern Apple platforms (iOS 17+ and watchOS 10+) and leans on Combine, MapKit, and the system share APIs to deliver live collaboration features such as partner chat, location-aware routing, and document exports.

## Feature Highlights

- **Authentication** – Email/password sign-in backed by Firebase Auth, password reset, and account deletion that preserves historical job documents.
- **Dashboard** – Technician home screen with smart routing, sync status, quick creation shortcuts, and sharing flows for daily job summaries.
- **Jobs** – CRUD surface for job records, media uploads, supervisor import tools, deep link routing, and iMessage share payloads.
- **Search** – Address-aware search across the global job index with MapKit autocomplete and detailed result inspection.
- **Timesheets & Yellow Sheets** – Weekly timesheet tracking, PDF export, and yellow sheet compliance workflow with editable PDF annotations.
- **Settings** – Smart routing preferences, arrival alert toggles, theme customization, and account management.
- **Admin & Team Tools** – Admin flag management, maintenance utilities, roster sync, partner pairing, and crew chat.
- **Assistive Workflows** – Gemini-powered splice troubleshooting, Help center tutorials, and watchOS glanceable status updates.
- **Siri & Shortcuts** – App Intents-backed voice actions for creating jobs, updating status, listing today’s work, and launching navigation to the next job.

See the [Documentation](Documentation/README.md) index for deep dives into each feature area.

## Architecture Overview

The project is structured around lightweight feature modules under `Job Tracker/Features`. Each feature encapsulates its SwiftUI views, Combine view models, and service facades. Shared building blocks live under `Features/Shared`, including:

- **Shell**: Tab scaffolding, authenticated navigation, and global view model wiring.
- **Services**: `FirebaseService`, `LocationService`, and `ArrivalAlertManager` for Firestore, Auth, and Core Location integration.
- **Mapping & Messaging**: MapKit wrappers, route calculations, and partner chat surfaces.

Models (`Job`, `AppUser`, `PartnerRequest`) live under `Job Tracker/Models` and use Codable/Firebase annotations. The design system tokens and reusable components are centralised in `Job Tracker/DesignSystem`.

### Data & Integrations

- **Firebase**: Firestore backs job, timesheet, and yellow sheet documents. Firebase Auth powers account management and custom claims for admin/supervisor roles.
- **Generative AI**: `Features/SpliceAssist` wraps the Gemini API to analyse uploaded splice maps for troubleshooting, assignment suggestions, and CAN analysis.
- **Maps & Location**: MapKit and Core Location surface routing assistance, arrival alerts, and job distance calculations.
- **Sharing**: ShareLink, PDF generation, and deep-link routes enable exporting jobs to teammates, supervisors, and the iMessage extension.

## Project Structure

```
Job Tracker778
├── Job Tracker/                # Primary iOS app sources
│   ├── Features/               # Feature-specific views and view models
│   ├── Models/                 # Shared data models for Firestore
│   ├── DesignSystem/           # Colors, typography, glass cards, reusable controls
│   ├── Assets.xcassets/        # App icon and image assets
│   └── GoogleService-Info.plist# Firebase configuration (replace with your own)
├── Job Tracker Companion Watch App/  # watchOS companion app
├── imessage cs/                # iMessage extension for sharing job summaries
├── Job TrackerTests/           # XCTest coverage for services and view models
├── Documentation/              # Markdown feature guides and process docs
├── website/                    # Standalone browser prototype for Job Tracker workflows
└── Job Tracker.xcodeproj       # Xcode project workspace
```

## Getting Started

1. **Prerequisites**
   - Xcode 15 or newer.
   - A Firebase project with Firestore, Authentication (email/password), and Storage enabled.
   - Optional: A Gemini API key for Splice Assist.

2. **Configuration**
   - Replace `Job Tracker/GoogleService-Info.plist` with the configuration for your Firebase project.
   - Populate any environment secrets used by `FirebaseService` (e.g. Gemini key, storage buckets). The service expects appropriate keys in the app bundle or your preferred secret storage.
   - Review `FirebaseService.swift` for endpoints specific to your deployment (Firestore collection names, callable functions).

3. **Build & Run**
   - Open `Job Tracker.xcodeproj` in Xcode.
   - Select the *Job Tracker* target and your preferred simulator or device.
   - Build and run (`⌘R`). Ensure push notification and location permissions are granted for arrival alerts and smart routing.

4. **Companion Apps**
   - **watchOS**: Select the *Job Tracker Companion Watch App* target to build the Watch app. `WatchBridge` mirrors daily jobs and leverages the same Firebase-backed models.
   - **iMessage Extension**: The *imessage cs* target adds interactive job cards to Messages. Use a Messages simulator to preview.

## Siri / Shortcuts Commands

Job Tracker includes App Intents (iOS 16+) so technicians can run voice commands through Siri or configure automations in the Shortcuts app.

### Available actions

- **Create Job**
  - Example phrases:
    - “Create a job in Job Tracker”
    - “Add job with Job Tracker”
  - Siri will ask for:
    - Address
    - Status
    - Scheduled Date

- **Update Job Status**
  - Example phrases:
    - “Mark job as Job Tracker”
    - “Update job status in Job Tracker”
  - Siri will ask for:
    - Address or job number
    - New status (`Pending`, `Needs Ariel`, `Needs Underground`, `Needs Nid`, `Needs Can`, `Done`, `Talk to Rick`, or custom)

- **Get Today’s Jobs**
  - Example phrases:
    - “What are my jobs today in Job Tracker”
    - “Show today’s jobs with Job Tracker”
  - Returns a short spoken list (up to five non-pending jobs).

- **Directions to Next Job**
  - Example phrases:
    - “Directions to my next job in Job Tracker”
    - “Navigate to next job with Job Tracker”
  - Opens Apple Maps to the earliest pending job for today.

- **Next Job Address**
  - Example phrases:
    - “What is my next job address in Job Tracker”
    - “Next job address with Job Tracker”
  - Speaks the next pending address for today.

### How to use

1. Build and run the app once on device or simulator.
2. Open **Shortcuts** → **+** → **Add Action**.
3. Search for **Job Tracker** and pick one of the actions above.
4. (Optional) Add it to Siri with a custom invocation phrase.

## Testing

Automated tests live under `Job TrackerTests`. The suite exercises:

- Admin panel mutations and maintenance workflows.
- Deep link routing and job share payload parsing.
- Job search matching heuristics and crew job summaries.
- Yellow sheet and timesheet PDF generation pipelines.

Run the full suite from Xcode (`⌘U`) or via command line:

```sh
xcodebuild test -scheme "Job Tracker" -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Contributing & Documentation

- Review the [Design System guide](Job%20Tracker/DesignSystem/DesignSystem.md) for UI consistency.
- Use the [feature guides](Documentation/README.md) for workflows and view model responsibilities.
- Keep Firebase rules and Cloud Functions aligned with the data access patterns described in the documentation.

For issues or enhancements, open a ticket describing the desired behaviour, environment, and screenshots/logs when applicable.
