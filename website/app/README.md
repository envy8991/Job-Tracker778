# Job Tracker Firebase Web App

This folder contains the Firebase-backed browser version of Job Tracker. The older top-level static prototype has been replaced by tiny compatibility redirect files; `website/app/` is the single website implementation.

## Implemented app areas

- **Authentication** – Firebase email/password login, signup, password reset email, persisted session refresh, and sign-out.
- **Dashboard** – bottom-tab Dashboard view with a weekly selector, daily job rollups, completion progress, Firebase sync status, quick job creation, status updates, and job removal.
- **Timesheets** – weekly timesheet editor with supervisor/partner fields, Gibson and Cable South hour totals, and Firestore-backed history.
- **Yellow Sheet** – weekly Yellow Sheet view that shows jobs for the selected week, saves the native weekly record, and lists saved history.
- **Job Search** – searchable job index across job number, address, status, assignment, date, notes, and materials.
- **More** – functional Profile, Settings, and Find a Partner sections with Firestore-backed profile/settings and native-compatible partner request records.

## Run locally

From the repository root:

```sh
python3 -m http.server 8000 --directory website
```

Then open <http://localhost:8000/app/> in a browser and sign in with a real Firebase user or create a new account.

## Firebase data model

The web app reads and writes these existing app collections:

- `users/{uid}` for profile, role, and web settings.
- `jobs/{jobId}` using the native `Job` fields, including `date`, `status`, `createdBy`, `assignedTo`, and `participants`.
- `timesheets/{uid_weekStart}` using the native rollup fields plus web row details for editing.
- `yellowSheets/{uid_weekStart}` using the native weekly fields: `userId`, `partnerId`, `weekStart`, `totalJobs`, and optional `pdfURL`.
- `partnerRequests/{requestId}` and `partnerships/{pairId}` using native-compatible partner request fields.

## Deployment notes

1. Keep `config.js` aligned with the Firebase project used by the native app.
2. Ensure Firestore rules allow authenticated users to read/write their own `users`, visible `jobs`, personal timesheets/yellow sheets, and incoming/outgoing partner requests.
3. Replace text summary sharing with the native PDF generation pipeline or a shared server-side PDF service if browser-generated PDFs are required.
