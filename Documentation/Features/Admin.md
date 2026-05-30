# Admin

The Admin module exposes elevated controls for supervisors and company administrators. Its primary surface is the `AdminPanelViewModel`, which powers a roster management screen and wraps backend maintenance operations supplied by `FirebaseService`.

## Responsibilities

- Present the current roster of `AppUser` records sorted by last name.
- Toggle the `isAdmin` and `isSupervisor` flags for crew members and propagate the changes through Firebase custom claims.
- Display optimistic loading state while role flags are being mutated to avoid duplicate submissions.
- Run backfill maintenance routines (for example, `adminBackfillParticipantsForAllJobs`) that ensure every job document has its participant list populated.
- Surface success and failure alerts whenever an admin action completes, along with the number of records affected.

## Key Types

| Type | Role |
| --- | --- |
| `AdminPanelViewModel` | Observable object driving the admin panel UI. Tracks roster snapshots, in-flight flag mutations, alert messaging, and maintenance progress. |
| `AdminPanelService` | Protocol satisfied by `FirebaseService`. Abstracts updating user flags, refreshing custom claims, and running maintenance backfills. |
| `MaintenanceStatus` | Captures the execution state of long-running admin tasks, including progress, last run count, and errors. |
| `UsersViewModel` | Shared roster publisher consumed by the admin module to stay in sync with the rest of the app. |

## Workflows

1. **Flag Management** – When an admin toggles a user flag, the view model records the user ID in `updatingAdminIDs`/`updatingSupervisorIDs`. The UI can check `isMutating(userID:)` to disable controls. On completion, `alert` is set to a `success` or `error` message.
2. **Roster Sync** – `attach(usersViewModel:)` subscribes to the shared users dictionary so the admin screen always displays the latest crew members without duplicating fetch logic.
3. **Maintenance Backfill** – `runParticipantsBackfill()` kicks off the Firebase maintenance function. The progress callback updates the `MaintenanceStatus.Progress` struct, allowing the UI to render a live progress view. Completion updates `alert` and `lastRunCount` for reporting.

## Integration Notes

- The admin panel should only be reachable for users whose `AuthViewModel` exposes `isAdmin == true`.
- Ensure Cloud Functions and Firestore security rules validate that only admins can invoke the maintenance endpoints described above.
- When adding new admin maintenance tasks, expose them through `AdminPanelService` so the existing dependency injection remains intact for testing.

## App Update Policy

- Production iOS releases are managed through App Store/TestFlight. The app does not download, verify, or apply executable update packages from the admin panel in production builds.
- Production forced-update behavior is driven by the trusted Firestore remote config document at `app_config/ios_version`, which is observed by `ForceUpdateViewModel` at launch. Admins can set `latestVersion`, `minimumRequiredVersion`, `latestBuild`, `minimumRequiredBuild`, `updateURL`, `releaseNotes`, and `forceUpdateEnabled` to block outdated clients until they install the approved release.
- The admin package-update screen is a debug/development demo only. It is compiled behind `#if DEBUG`, labeled as a demo in the admin UI, and must not be used as a production enterprise distribution or rollback mechanism.
