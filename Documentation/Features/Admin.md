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
