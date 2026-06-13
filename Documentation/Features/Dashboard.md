# Dashboard

The dashboard is the technician home screen. It surfaces the current week's assignments, highlights pending work, and exposes shortcuts into creation, sharing, and routing tools. `DashboardView` composes several reusable components and is powered by `DashboardViewModel`.

## Responsibilities

- Display the current weekday selection and allow quick navigation across the Monday–Friday work week.
- Query the `JobsViewModel` for assignments on the selected date and split them into pending/completed sections.
- Calculate nearest job distance strings when smart routing is enabled and a current location is available.
- Present sync status banners that reflect pending Firestore writes from `JobsViewModel`.
- Provide share sheets for daily summaries and individual jobs (via `DashboardShareSheets`).
- Trigger job creation sheets, date pickers, and import toasts through `ActiveSheet` management.

## Key Components

| Component | Description |
| --- | --- |
| `DashboardView` | Main SwiftUI surface containing the header, weekday picker, summary metrics, and job lists. |
| `DashboardViewModel` | Computes sections, summary counts, routing hints, and share payloads. Manages state for sheets and banners. |
| `DashboardWeekdayPicker` | Horizontal selector displaying weekday abbreviations and routing taps back into `DashboardViewModel`. |
| `DashboardSummaryCard` | Shows total, pending, and completed counts for the selected day. |
| `DashboardJobSectionsView` | Renders pending and completed job lists with optional distance badges. |
| `DashboardSyncBanner` | Animated banner showing upload progress when Firestore writes are in flight. |
| `DashboardShareSheets` | Hosts ShareLink presenters for daily PDF exports and job-specific payloads. |

## Data Flow

1. **Configuration** – `DashboardView` calls `configureIfNeeded(jobsViewModel:)` so the view model can request weekly jobs from the shared `JobsViewModel`.
2. **Selection** – Tapping a weekday updates `selectedDate`, which re-fetches the corresponding week's jobs and recalculates sections.
3. **Routing** – When smart routing is on, distances are calculated using `Job.clLocation` and the current location provided by `LocationService`.
4. **Sharing** – When a user taps the share action, `shareItems` is populated and `activeSheet` is set to `.share`, driving the system share sheet.
5. **Sync Banners** – The view model listens to `NotificationCenter.jobsSyncStateDidChange` updates (triggered from `JobsViewModel`) to update `syncTotal`, `syncDone`, and `syncInFlight` counts.

## Integration Notes

- Inject the shared `JobsViewModel`, `LocationService`, and `AuthViewModel` as environment objects so the dashboard can access live data and routing preferences.
- Respect `AuthViewModel.isSupervisor` to show supervisor-specific actions (e.g., import flows) when applicable.
- When adding new dashboard cards, favour `GlassCard` and design system tokens for visual consistency.
