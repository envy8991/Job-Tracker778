# Job Tracker

Job Tracker is a SwiftUI field-operations app for fiber technicians, supervisors, and administrators. It centralizes job dispatch, daily routing, crew collaboration, paperwork, maps, AI-assisted splice troubleshooting, Siri/App Intents, a watchOS companion, an iMessage extension, CarPlay job dispatch, and a browser prototype in one Firebase-backed workspace.

The repository is intentionally organized so future contributors can understand how each feature works before making changes. Start here, then use the linked feature documentation and tests as the safety net for implementation details.

## Table of Contents

- [Platform Targets](#platform-targets)
- [Repository Map](#repository-map)
- [Core Architecture](#core-architecture)
- [Runtime Flow](#runtime-flow)
- [Feature Guide](#feature-guide)
- [Data Model and Firebase Collections](#data-model-and-firebase-collections)
- [External Integrations](#external-integrations)
- [Configuration](#configuration)
- [Build and Run](#build-and-run)
- [Testing and Quality Gates](#testing-and-quality-gates)
- [Companion Targets](#companion-targets)
- [Website Prototype](#website-prototype)
- [Development Rules for Future Updates](#development-rules-for-future-updates)
- [Troubleshooting](#troubleshooting)
- [Documentation Index](#documentation-index)

## Platform Targets

- **iOS/iPadOS app:** SwiftUI app target in `Job Tracker/`, deployed through the shared `Job Tracker` Xcode scheme.
- **Minimum iOS target:** iOS 26.0 for the main app, unit tests, and UI tests.
- **watchOS companion:** `Job Tracker Companion Watch App/`, minimum watchOS 26.0.
- **iMessage extension:** `imessage cs/`, used to share job cards in Messages.
- **CarPlay scene:** Dispatch-focused CarPlay scene configured in `Job-Tracker-Info.plist` and implemented under `Job Tracker/Features/CarPlay/`.
- **Browser prototype:** Static and parity-enhanced web prototype under `website/`.

## Repository Map

```text
Job-Tracker778/
├── Job Tracker/                         # Primary SwiftUI iOS/iPadOS application
│   ├── Job_TrackerApp.swift             # App entry point, environment object wiring, test seeding
│   ├── AppDelegate.swift                # Firebase configuration and app delegate hooks
│   ├── TestingSupport.swift             # UI-test launch argument helpers
│   ├── Models/                          # Codable Firestore models
│   ├── Features/                        # Feature modules grouped by product area
│   ├── DesignSystem/                    # Theme tokens, components, typography, elevations
│   ├── Resources/WebMaps/               # Web mapping resources embedded in the app
│   └── intent/                          # App Intents and App Shortcuts
├── Job Tracker Companion Watch App/     # watchOS companion app
├── imessage cs/                         # Messages extension target
├── Job TrackerTests/                    # Unit and integration-style XCTest coverage
├── Job TrackerUITests/                  # End-to-end UI tests
├── Documentation/                       # Long-form feature and process docs
├── firebase-emulator-tests/             # Firestore/Storage rules tests run by Vitest
├── ci_scripts/                          # Xcode Cloud and entitlement preflight scripts
├── website/                             # Static marketing/prototype site and web app parity work
├── Job Tracker.xcodeproj/               # Xcode project and shared scheme
├── Job Tracker Safety Net.xctestplan    # Primary test plan for the shared scheme
├── Job-Tracker-Info.plist               # Main app Info.plist, URL schemes, CarPlay, Gemini key placeholder
└── package.json                         # Node scripts for Firebase rules tests
```

## Core Architecture

### App Composition

`Job_TrackerApp.swift` is the top-level composition root. It ensures Firebase is configured, creates long-lived state objects, injects app-wide services into the environment, seeds deterministic UI-test data when requested, and wraps the authenticated shell in forced-update handling. The shared state objects include:

- `AuthViewModel` for sign-in state, profile loading, role flags, and account actions.
- `JobsViewModel` for job listeners, CRUD, search index data, pending writes, and sync banners.
- `UsersViewModel` for roster and partner/team experiences.
- `LocationService` for location authorization, route helpers, smart routing, and arrival alerts.
- `ArrivalAlertManager` for notification/geofence-style arrival monitoring.
- `JTThemeManager` for app-wide themes.
- `ForceUpdateViewModel` for Firestore-driven minimum version enforcement.
- `AppNavigationViewModel` for tab navigation and deep links.

### Feature Modules

Feature code lives under `Job Tracker/Features/<FeatureName>/`. Each feature owns its SwiftUI screens, view models, local components, and service facades. Shared code that crosses feature boundaries belongs in `Job Tracker/Features/Shared/` to avoid import cycles and duplicated logic.

Use the following placement rule when adding code:

- A view or view model used by only one product area goes in that feature folder.
- Reusable UI, services, mapping, shell, messaging, or team helpers go in `Features/Shared/`.
- App-wide models that represent Firestore documents go in `Models/`.
- Visual constants and reusable design primitives go in `DesignSystem/`.
- Siri/App Intent entry points go in `intent/`.

### Design System

The design system centralizes app color, typography, shape, elevation, theme presets, and reusable components. New UI should prefer `JTColors`, `JTTypography`, `JTShapes`, `JTElevations`, `JTComponents`, `JTTheme`, and `JTThemeManager` instead of one-off constants. Read `Job Tracker/DesignSystem/DesignSystem.md` before redesigning screens.

### Dependency Management

The iOS project uses Swift Package Manager through Xcode. Firebase is the primary Swift package dependency and resolves products such as Auth, Firestore, Storage, Functions, and related Google SDK support packages through `Package.resolved`.

Node dependencies are limited to Firebase rules testing:

```sh
npm install
npm run test:firebase-rules
```

## Runtime Flow

1. The app launches through `JobTrackerApp`.
2. Firebase is configured unless the process is running in UI-test mode.
3. `AuthViewModel.checkAuthState()` restores the Firebase Auth user and loads the matching `users/{uid}` profile.
4. Once authenticated, `ContentView`, `AppShellView`, and `MainTabView` present the tab shell.
5. `JobsViewModel` starts Firestore listeners for participant jobs and the global search index.
6. `UsersViewModel` listens for roster data used by partner pairing, chat, admin tools, and supervisor flows.
7. `LocationService` and `ArrivalAlertManager` power smart routing, distance labels, maps, and arrival notifications.
8. `ForceUpdateViewModel` observes `app_config/ios_version`; if the installed version/build is below the configured minimum, `ForceUpdateView` blocks the app until the user updates.

## Feature Guide

### Authentication

Authentication uses Firebase Auth email/password plus a Firestore `users/{uid}` profile. Sign-up captures first name, last name, crew position, email, and password. Sign-in loads the `AppUser` profile and exposes `isAdmin` and `isSupervisor` flags to gate privileged screens. Password reset and account deletion are exposed through settings/profile flows. Account deletion removes the Firebase Auth user while preserving job history where configured.

Future update checklist:

- Keep Auth changes reflected in `AuthViewModel` tests.
- Ensure Firestore rules and custom claims match `isAdmin`/`isSupervisor` behavior.
- Do not remove historical job ownership fields during account deletion.

### Dashboard

The dashboard is the technician home screen. It shows the selected weekday, pending/completed job sections, quick job creation and import actions, routing/sync banners, daily summaries, and share flows. It consumes `JobsViewModel`, `AuthViewModel`, and `LocationService` from the environment. Supervisor users can see supervisor-specific actions and import workflows.

Future update checklist:

- Keep dashboard job filtering aligned with `JobsViewModel` date and status logic.
- Use `DashboardSyncBanner` and pending-write state for any new write-heavy workflow.
- Prefer existing dashboard components under `Features/Dashboard/Components/`.

### Jobs

Jobs are the central record type. `JobsViewModel` listens to participant-visible jobs, maintains local and global search data, tracks pending writes, and powers create/edit/delete/status flows. Job editing covers customer/job metadata, notes, photos, status, coordinates, partner assignment, extra work, and supervisor import paths. Sharing helpers build portable payloads and deep links for iMessage and cross-device import.

Future update checklist:

- When adding a job field, update `Job`, create/edit/detail views, Firestore serialization, search entries, share payloads, tests, and any PDF/export usage.
- Maintain the `participants` array because security rules, dashboards, search, and CarPlay depend on it.
- Keep pending-write tracking accurate so sync banners do not lie to technicians.

### Search

Search combines local participant jobs and a global job index. It supports debounced free-text matching by address, customer, can number, and job ID, plus MapKit autocomplete suggestions. Results can show distance using `LocationService`, open details, start navigation, or route the user back to the job in the app.

Future update checklist:

- Update `JobSearchMatcherTests` whenever matching behavior changes.
- Start the global search listener before presenting search UI.
- Keep address autocomplete provider selection in sync with settings.

### Timesheets

Timesheets manage weekly labor records for the signed-in user and optional partner. The feature fetches weekly documents, supports daily job/hour editing, computes company and total-hour rollups, lists historical records, and generates shareable PDF exports.

Future update checklist:

- Keep Firestore indexes available for user/week queries.
- Update PDF generator tests and templates when changing document layout.
- Keep job suggestions connected to `TimesheetJobsViewModel` and `JobsViewModel`.

### Yellow Sheets

Yellow sheets support daily compliance/safety paperwork, material usage, supervisor review, historical records, PDF generation, and in-app PDF viewing/annotation. Records may link to specific jobs so forms can prefill addresses and partner details.

Future update checklist:

- Update `YellowSheetPDFGenerator` and PDF tests together.
- Keep Storage rules aligned with generated PDF upload/download paths.
- Preserve supervisor review flows when changing record ownership fields.

### Settings and Profile

Settings centralizes preferences and account management. It includes smart routing toggles, route optimization order, arrival alerts, address suggestion provider, theme customization, profile details, password reset, sign out, and account deletion. Persistent preferences use namespaced `@AppStorage` keys.

Future update checklist:

- Document every new persisted preference in `Documentation/Features/Settings.md`.
- Keep settings environment dependencies available: `AuthViewModel`, `JTThemeManager`, `ArrivalAlertManager`, and `LocationService`.
- Treat account deletion and sign-out as high-risk flows and keep confirmation/error states explicit.

### Admin and Supervisor Tools

Admin tools expose user roster management, role toggles, supervisor/admin flags, and maintenance jobs such as participant backfills. Production app updates are not installed by the admin panel; forced updates are driven by trusted Firestore remote configuration. Debug package-update screens must remain behind `#if DEBUG` and must not become production distribution or rollback tooling.

Future update checklist:

- Gate admin navigation with `AuthViewModel.isAdmin`.
- Gate supervisor-only operations with `AuthViewModel.isSupervisor` where appropriate.
- Keep Cloud Functions and Firestore rules authoritative; UI gates are not sufficient security.
- Add tests for every new maintenance action.

### Team, Partner Pairing, and Messaging

Shared team features include roster lookup, partner requests, partnerships, recent crew jobs, and partner chat. Firestore collections include `partnerRequests`, `partnerships`, `conversations/{id}/messages`, and `userUnread`. These features live under `Features/Shared/Team`, `Features/Shared/Messaging`, and `Features/Shared/More`.

Future update checklist:

- Keep unread counters and message listener cleanup correct to avoid stale badges.
- Preserve member arrays/IDs used by security rules.
- Keep recent crew job visibility aligned with role and participant rules.

### Maps, Routing, and Location

Mapping support includes MapKit geocoding, Leaflet-based web map rendering resources, route storage/sync, fiber asset overlays, smart routing, dashboard distance labels, navigation handoff, and CarPlay direction actions. Location-dependent features must gracefully degrade when authorization is denied or unavailable.

Future update checklist:

- Always handle missing coordinates by falling back to address geocoding or user-facing unavailable states.
- Keep Apple Maps and Google Maps provider behavior consistent across dashboard, job detail, and CarPlay.
- Do not block core job workflows on location permission.

### Splice Assist

Splice Assist accepts cropped splice map images, normalizes image orientation/size, gathers CAN/T2 context, and sends multimodal requests to Gemini for missing-light troubleshooting, spare assignment suggestions, or general CAN analysis. `SpliceAssistViewModel` controls request state and user-facing results.

Future update checklist:

- Store the Gemini API key securely and avoid committing real production secrets.
- Keep prompts and response handling testable where possible.
- Prevent duplicate submissions while requests are active.

### Help and Tutorial

The Help feature contains a searchable help center, quick links, FAQ/support shortcuts, and a multi-step interactive tutorial. Tutorial stage transitions are covered by tests and should remain deterministic so new technicians can resume safely.

Future update checklist:

- Update `InteractiveTutorialStagesTests` when tutorial stages change.
- Prefer remotely configurable help content for copy-only updates.
- Keep help deep links routed through `AppNavigationViewModel`.

### App Updates

Forced update policy is controlled by Firestore document `app_config/ios_version`. The app observes version/build fields and can require users to update through the configured URL. This is the production update path; executable package updates are not downloaded or applied in production builds.

Expected document fields:

- `latestVersion`
- `minimumRequiredVersion`
- `latestBuild`
- `minimumRequiredBuild`
- `updateURL`
- `releaseNotes`
- `forceUpdateEnabled`

### Siri, Shortcuts, and App Intents

App Intents under `Job Tracker/intent/` expose voice and shortcut actions for job creation, job status updates, today’s jobs, next-job directions, next-job address, nearest job assignment details, and nearest job footage. `AppShortcuts.swift` groups actions for Shortcuts discovery.

Common actions:

- Create Job
- Update Job Status
- Get Today’s Jobs
- Directions to Next Job
- Next Job Address
- Get/Set Nearest Job Assignment
- Get/Set Nearest Job Footage
- Get Nearest Job Summary

Future update checklist:

- Keep intent parameter names stable when possible because users may have Shortcuts automations.
- Ensure intent code uses the same job-selection rules as dashboard and routing.
- Test intents on-device or in a simulator that supports App Intents discovery.

### CarPlay

CarPlay is limited to safe, read-only job dispatch. It shows today’s dashboard-scoped jobs for the signed-in technician, sorts by distance when available, limits list size, displays compact details, and starts directions using the selected map provider. Editing, photos, chat, timesheets, admin tools, search, and long-form workflows must stay off CarPlay.

Future update checklist:

- Do not add distracting or editing-heavy screens to CarPlay.
- Keep entitlement checks and `ci_scripts/carplay_entitlement_preflight.sh` in the release process.
- Real-device/TestFlight/App Store CarPlay distribution requires Apple-approved managed capabilities.

## Data Model and Firebase Collections

### Primary Swift Models

- `Job`: Central assignment record with scheduling, address, customer/job metadata, status, participant/owner fields, coordinates, notes, photos, and extra-work-related fields.
- `AppUser`: Firestore profile backing authentication, display names, position, role flags, and team metadata.
- `CrewPosition`: Normalized role/position values for crew members.
- `PartnerRequest`: Partner pairing request lifecycle.
- `Timesheet` and related nested types: Weekly labor and job-hour entries.
- `YellowSheet` and related nested types: Daily compliance/safety paperwork records.
- `ChatMessage`: Partner/crew messaging payload.
- `MapShape` and route/fiber map types: Mapping overlays and route persistence.

### Firestore Collections Used by the App

| Collection | Purpose | Important Consumers |
| --- | --- | --- |
| `users` | `AppUser` profiles, role flags, roster data | Auth, Settings, Admin, Team, Shared Jobs |
| `jobs` | Job assignments and searchable job records | Dashboard, Jobs, Search, Timesheets, CarPlay |
| `sharedJobs` | Tokenized job share/import payloads | Deep links, iMessage, cross-device sharing |
| `timesheets` | Weekly timesheet documents | Timesheets, PDF export/history |
| `yellowSheets` | Daily yellow sheet documents | Yellow Sheet workflows, PDF export/history |
| `partnerRequests` | Pending/accepted/declined partner requests | Find Partner, Team |
| `partnerships` | Active partner pairings | Team, Messaging, Shared job context |
| `conversations/{id}/messages` | Chat messages | Partner chat |
| `userUnread` | Unread message counters | Chat badges/notifications |
| `routes` | Stored route/fiber map records and presence | Maps, RouteService, Fiber maps |
| `app_config/ios_version` | Forced update policy | ForceUpdateViewModel |

### Storage Usage

Firebase Storage is used for job photos and generated PDFs. `JobPhotoUploadQueue` handles deferred photo uploads and updates job document photo URL fields after upload succeeds. Timesheet and yellow sheet PDF generators produce shareable documents and should remain aligned with Storage rules.

### Security Expectations

- Firestore rules should authorize `jobs` access by participants/ownership and admin/supervisor claims where needed.
- `users` reads/writes should be scoped to authenticated users and privileged roles.
- Storage rules should prevent cross-user access to job photos and exported documents.
- Admin maintenance work should also be validated by Cloud Functions/security rules; UI hiding is not security.
- `firebase-emulator-tests/` should grow whenever rules change.

## External Integrations

- **Firebase Auth:** Email/password accounts and user lifecycle.
- **Cloud Firestore:** Realtime data for jobs, users, partner flows, chat, paperwork, routes, shared payloads, and update config.
- **Firebase Storage:** Photos and generated PDFs.
- **Firebase Functions:** Admin/custom-claim and maintenance workflows where configured.
- **MapKit/Core Location:** Address autocomplete, geocoding, distance calculations, and location authorization.
- **Apple Maps/Google Maps:** Navigation handoff based on user preference and availability.
- **App Intents/Siri/Shortcuts:** Voice and automation entry points.
- **CarPlay:** Read-only dispatch list and directions flow.
- **Messages framework:** iMessage job card extension.
- **Gemini API:** Splice Assist multimodal analysis.

## Configuration

### Required Local Configuration

1. Install Xcode 26 or newer with iOS 26 and watchOS 26 SDKs.
2. Use a Firebase project with Auth, Firestore, Storage, and any required Functions enabled.
3. Replace `Job Tracker/GoogleService-Info.plist` with the Firebase plist for your environment.
4. Confirm bundle IDs and app groups match your Apple Developer account/provisioning profiles.
5. Configure Firestore indexes for queries that combine user/date/week/status filters.
6. Configure Storage and Firestore rules before using production data.

### Sensitive Values

`Job-Tracker-Info.plist` contains a `GEMINI_API_KEY` key placeholder. Do not commit real production secrets. Prefer a secure build setting, encrypted configuration, remote config, or CI-secret injection strategy for real keys.

### Entitlements and Capabilities

Review these files when changing bundle IDs, app groups, CarPlay, or sharing:

- `Job Tracker/Job Tracker.entitlements`
- `imessage cs/imessage cs.entitlements`
- `Job-Tracker-Info.plist`
- `imessage cs/Info.plist`

The iMessage extension currently uses app group `group.com.quinton.JobTracker`; keep app group IDs synchronized across targets if shared storage changes.

## Build and Run

### Xcode

1. Open `Job Tracker.xcodeproj`.
2. Select the shared `Job Tracker` scheme.
3. Select an iOS 26 simulator or device.
4. Build and run with `⌘R`.
5. Sign in with a Firebase Auth user whose `users/{uid}` profile exists, or create an account through the app.

### Command Line Build

```sh
xcodebuild build \
  -scheme "Job Tracker" \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15'
```

### Command Line Tests

```sh
xcodebuild test \
  -scheme "Job Tracker" \
  -testPlan "Job Tracker Safety Net" \
  -destination 'platform=iOS Simulator,OS=latest,name=iPhone 15'
```

### Firebase Rules Tests

```sh
npm install
npm run test:firebase-rules
```

## Testing and Quality Gates

### XCTest Coverage

`Job TrackerTests/` covers important app behavior, including:

- Admin panel and admin update view models.
- App user decoding and app version comparisons.
- Crew-position normalization.
- Dashboard sync state.
- Deep links and shared job payload parsing.
- Firebase/service smoke tests.
- Force-update gating.
- Interactive tutorial stages.
- Job sheet parsing and search matching.
- Package update service behavior.
- Recent crew jobs and detail sheets.
- Shared job service behavior.
- Fiber map view model behavior.

`Job TrackerUITests/` covers user flows such as authentication, dashboard job flow, admin navigation, search, timesheets, yellow sheets, and settings.

### Test Launch Arguments

`TestingSupport.swift` defines process flags used by UI tests. Do not remove these without updating UI tests:

- `-jobTrackerUITesting`
- `-seedJobTrackerUITestData`
- `-jobTrackerUITestingAdmin`

These flags allow tests to bypass live Firebase configuration and use deterministic seeded state.

### CI and Release Scripts

- `.github/workflows/` contains GitHub workflow configuration.
- `.xcode-cloud/` and `ci_scripts/ci_pre_xcodebuild.sh` support Xcode Cloud setup.
- `ci_scripts/carplay_entitlement_preflight.sh` verifies CarPlay entitlement assumptions before release builds.

## Companion Targets

### watchOS Companion

The watch app displays glanceable daily job state. `WatchBridge` synchronizes data from the phone/app ecosystem, `WatchJobsViewModel` prepares watch-facing state, and `WatchDashboardView`/`WatchJobDetailView` render compact job information.

Future update checklist:

- Keep watch models lightweight.
- Avoid phone-only editing flows on watch unless explicitly designed and tested.
- Verify watch target membership when adding shared files.

### iMessage Extension

The iMessage extension renders job cards for Messages. Shared payloads originate from the Jobs sharing helpers and are parsed by `MessagesViewController`. Keep URL schemes, app groups, and payload schemas synchronized with `SharedJobPayload` and `DeepLinkRouter`.

## Website Prototype

The `website/` folder contains a browser-accessible prototype and parity work for Job Tracker workflows:

- `website/index.html`, `website/styles.css`, and `website/script.js` provide the outer site/prototype.
- `website/app/` contains a richer web app prototype with configuration, parity enhancements, search data helpers, implementation notes, and a parity plan.

Use this as a product/design reference, not as the source of truth for production mobile behavior. When web parity changes represent intended product behavior, update the SwiftUI feature docs and tests as well.

## Development Rules for Future Updates

### Before Changing a Feature

1. Read this README section for the feature.
2. Read the matching file in `Documentation/Features/`.
3. Inspect existing tests for the behavior you are touching.
4. Identify all companion surfaces affected by the change: watch, iMessage, CarPlay, Siri intents, PDFs, and website prototype.
5. Confirm Firestore/Storage schema and rules implications.

### When Adding or Renaming Firestore Fields

Update all applicable locations:

- Swift model in `Job Tracker/Models/` or feature model file.
- View model read/write logic.
- Create/edit/detail UI.
- Search index and matching tests.
- Share payloads and deep-link parsing.
- PDF generators.
- Watch app mappings.
- Firestore rules and emulator tests.
- Feature documentation.

### When Adding UI

- Use the design system for colors, typography, shapes, cards, and buttons.
- Respect environment-object wiring from the shell; do not create duplicate service instances inside child views unless explicitly intended.
- Keep loading, error, empty, and permission-denied states visible.
- For location, notifications, camera/photo, and external navigation, provide graceful fallbacks.

### When Adding Tests

- Add unit tests for pure logic, parsing, matching, and view-model state transitions.
- Add UI tests for critical user journeys.
- Add Firebase emulator tests for security rule changes.
- Keep UI-test seed data deterministic.

### When Updating Documentation

- Update this README for cross-cutting architecture or setup changes.
- Update `Documentation/Features/<Feature>.md` for feature-specific behavior.
- Update `Documentation/README.md` when adding a new feature guide.
- Update website parity notes if a prototype change mirrors production behavior.

### Release Safety Checklist

- Build the app target.
- Run the `Job Tracker Safety Net` test plan.
- Run Firebase rules tests when rules or collection access changes.
- Verify Firebase plist, bundle IDs, app groups, and entitlements for the target environment.
- Verify forced-update Firestore config before App Store/TestFlight rollout.
- Verify CarPlay managed capability before CarPlay distribution.
- Smoke test authentication, dashboard, job create/edit, search, PDF export, settings, and navigation handoff.

## Troubleshooting

### Firebase does not initialize

- Confirm `Job Tracker/GoogleService-Info.plist` exists and belongs to the app target.
- Confirm bundle ID in Firebase matches the Xcode build setting.
- UI tests intentionally bypass Firebase configuration when `-jobTrackerUITesting` is present.

### No jobs appear on dashboard

- Confirm the user is signed in and has a `users/{uid}` document.
- Confirm relevant job documents include the user UID in `participants` or the expected owner fields.
- Confirm selected dashboard date matches the job scheduled date.
- Check Firestore rules and indexes for denied/failed queries.

### Search returns no results

- Confirm `JobsViewModel` has started the global search listener.
- Confirm searchable fields are populated on job documents.
- Confirm rules allow the current role/user to read the intended search data.

### Location, smart routing, or arrival alerts do not work

- Confirm simulator/device location permissions are granted.
- Confirm Settings toggles are enabled.
- Confirm jobs have coordinates or geocodable addresses.
- Confirm notification permissions for arrival alerts.

### PDF export fails

- Confirm Storage rules allow writes for the signed-in user.
- Confirm linked jobs/timesheets/yellow sheets have required metadata.
- Re-run tests around PDF generator behavior after layout changes.

### CarPlay does not appear

- Confirm the CarPlay scene remains configured in `Job-Tracker-Info.plist`.
- Confirm entitlements/provisioning include the required Apple-approved CarPlay managed capability for real-device distribution.
- Use the Xcode simulator CarPlay external display for local testing when available.

## Documentation Index

- [Project Documentation](Documentation/README.md)
- [Admin](Documentation/Features/Admin.md)
- [Authentication](Documentation/Features/Authentication.md)
- [CarPlay Job Dispatch](Documentation/Features/CarPlay.md)
- [Forced App Updates](Documentation/Features/AppUpdate.md)
- [Dashboard](Documentation/Features/Dashboard.md)
- [Help](Documentation/Features/Help.md)
- [Jobs](Documentation/Features/Jobs.md)
- [Search](Documentation/Features/Search.md)
- [Settings](Documentation/Features/Settings.md)
- [Shared](Documentation/Features/Shared.md)
- [Splice Assist](Documentation/Features/SpliceAssist.md)
- [Timesheets](Documentation/Features/Timesheets.md)
- [Yellow Sheet](Documentation/Features/YellowSheet.md)
- [Design System](Job%20Tracker/DesignSystem/DesignSystem.md)
- [Testing Safety Net](Documentation/TestingSafetyNet.md)
- [Xcode Cloud Testing](Documentation/XcodeCloudTesting.md)
- [CarPlay Entitlement Request](Documentation/CarPlayEntitlementRequest.md)
- [iOS 26 Opportunity Review](Documentation/iOS26OpportunityReview.md)
