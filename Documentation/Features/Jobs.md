# Jobs

The Jobs feature handles creating, editing, importing, and sharing job records. It owns the Firestore synchronization logic for assignments and supplies the data that powers the dashboard, search, and timesheet experiences.

## Responsibilities

- Listen to Firestore for job documents belonging to the signed-in technician (participant) and expose them via `JobsViewModel.jobs`.
- Maintain a global job search index (`searchJobs`) combining the lightweight public index with locally owned jobs.
- Track pending writes and broadcast sync state updates so the dashboard and other screens can display upload progress.
- Provide CRUD flows: creation (`CreateJobView`), editing (`JobDetailView`), supervisor imports (`SupervisorJobImportView`), and extra work capture (`ExtraWorkView`).
- Generate share payloads (`SharedJobPayload`) and deep links for the iMessage extension and cross-device sharing.
- Parse inbound share links using `DeepLinkRouter` to route to job detail screens.

## Key Types

| Type | Role |
| --- | --- |
| `JobsViewModel` | Central observable object responsible for Firestore listeners, pending write tracking, and share payload building. |
| `Job` | Codable model representing a job document with metadata, coordinates, media URLs, and participant IDs. |
| `CreateJobView` / `JobDetailView` | SwiftUI forms for creating and editing jobs. Support photo uploads, status updates, and partner assignments. |
| `SupervisorJobImportView` | Flow for importing CSVs or PDFs that supervisors provide. Uses parsing utilities tested in `JobSheetParserTests`. |
| `JobImportPreviewView` | Preview surface that shows parsed jobs before committing them to Firestore. |
| `DeepLinkRouter` | Resolves inbound URLs into navigation destinations tested via `DeepLinkRouterTests`. |

## Data & Sync Flow

1. **Fetching** – `fetchJobs(startDate:endDate:)` attaches a Firestore snapshot listener filtered by the current user ID. Metadata flags are used to determine pending writes and last server sync time.
2. **Indexing** – `startSearchIndexForAllJobs()` listens to the global `job_search_index` collection. The view model merges these entries with locally fetched jobs to power cross-company search.
3. **Creating/Updating** – Forms call helper methods on `FirebaseService` to create or update jobs. Pending write IDs are tracked so the UI can show optimistic state.
4. **Sharing** – `JobsViewModel` builds `SharedJobPayload` values that encode job metadata and optional images. These are consumed by ShareLink, AirDrop, and the iMessage extension.
5. **Notifications** – After job arrays change, `JobsViewModel` posts `.jobsDidChange` and `.jobsSyncStateDidChange` notifications for other features.

## Integration Notes

- Inject `JobsViewModel` as an `@StateObject` near the top of the authenticated shell. Other features observe it via `@EnvironmentObject`.
- Ensure Firestore rules allow read/write access for participants listed in a job document while guarding cross-team data.
- When adding new job attributes, update `Job`, the Firestore serialization logic, and any share payload or parser utilities that rely on the schema.
