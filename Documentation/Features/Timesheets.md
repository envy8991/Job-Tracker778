# Timesheets

Timesheets track weekly hours for technicians and generate PDFs supervisors can sign off on. The module handles both individual day entries and historical exports.

## Responsibilities

- Fetch weekly timesheet documents for the signed-in user and optional partner via `UserTimesheetsViewModel`.
- Allow editing of daily job entries (`JobEditView`) and hours within `WeeklyTimesheetView`.
- Compute rollups for Gibson, Cable South, and total hours using `TimesheetViewModel`.
- Generate shareable PDFs with `WeeklyTimesheetPDFGenerator` and upload/download links via Firebase Storage.
- Display historical records in `PastTimesheetsView` for quick reference.

## Key Types

| Type | Role |
| --- | --- |
| `Timesheet` | Codable Firestore model capturing week start, supervisors, technician names, per-day totals, and PDF URLs. |
| `UserTimesheetsViewModel` | Coordinates fetching, refreshing, and caching timesheet documents for the active user. |
| `TimesheetViewModel` | Handles form state for a single timesheet, validation, and saving back to Firestore. |
| `TimesheetJobsViewModel` | Supplies job pickers used when adding or editing timesheet entries. |
| `WeeklyTimesheetView` | Main UI for entering hours, selecting partners, and triggering PDF generation. |
| `WeeklyTimesheetPDFGenerator` | Renders SwiftUI templates into PDFs for sharing with supervisors. |

## Workflow

1. **Loading** – On appear, `UserTimesheetsViewModel` fetches the week containing the selected date. It subscribes to Firestore snapshots to stay up to date.
2. **Editing** – Users can adjust hours per day, assign partner names, and edit job notes. `TimesheetViewModel` validates input before saving.
3. **PDF Export** – Tapping export invokes `WeeklyTimesheetPDFGenerator`, saves the PDF locally, uploads it if needed, and exposes a ShareLink.
4. **History** – `PastTimesheetsView` shows prior weeks with quick access to their PDF downloads.

## Integration Notes

- Ensure Firestore indexes exist for queries filtering by `userId` and `weekStart`.
- Because timesheets reference jobs, keep `JobsViewModel` available so `TimesheetJobsViewModel` can suggest relevant assignments.
- Update the PDF layout when brand guidelines change by modifying the generator templates rather than ad-hoc drawing code.
