# Job Tracker Firebase Web App

This folder contains the Firebase-backed browser version of Job Tracker. It is intentionally nested under `website/app/` so it can be merged alongside the already-existing static website prototype without conflicting with `website/index.html`, `website/script.js`, `website/styles.css`, or `website/README.md` on `main`.

## Implemented app areas

- **Authentication** – Firebase email/password login, signup, password reset email, persisted session refresh, and sign-out.
- **Dashboard** – Monday-Friday selector, daily job rollups, completion progress, Firebase sync status, next-job hint, daily summary copy/download, quick job creation, status updates, and job removal.
- **Timesheets** – weekly timesheet editor with supervisor/partner fields, Gibson/Cable South/Other hour totals, Firestore-backed history, and text export.
- **Yellow Sheets** – daily compliance checklist with job reference, materials, notes, technician signature, Firestore-backed history, and text export.
- **Job Search** – global searchable job index across job number, address, status, type/assignment, date, notes, and materials with inline status updates.
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
- `yellowSheets/{uid_date}` using the native weekly fields plus daily checklist details for editing.
- `partnerRequests/{requestId}` and `partnerships/{pairId}` using native-compatible partner request fields.

## Deployment notes

1. Keep `config.js` aligned with the Firebase project used by the native app.
2. Ensure Firestore rules allow authenticated users to read/write their own `users`, visible `jobs`, personal timesheets/yellow sheets, and incoming/outgoing partner requests.
3. Replace text exports with the native PDF generation pipeline or a shared server-side PDF service if browser-generated PDFs are required.
4. Connect routing distances and address suggestions to production map providers when web mapping is added.
