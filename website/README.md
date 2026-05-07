# Job Tracker Website

This folder contains the browser version of Job Tracker. It is a static client that talks directly to the same Firebase Auth and Firestore project used by the native app, so accounts and records are real application data backed by the production collections.

## Implemented app areas

- **Authentication** – Firebase email/password login, signup, password reset email, persisted session refresh, and sign-out.
- **Dashboard** – Monday-Friday selector, daily job rollups, completion progress, Firebase sync status, next-job hint, daily summary copy/download, quick job creation, status updates, and job removal.
- **Timesheets** – weekly timesheet editor with supervisor/partner fields, Gibson/Cable South/Other hour totals, Firestore-backed history, and text export.
- **Yellow Sheets** – daily compliance checklist with job reference, materials, notes, technician signature, Firestore-backed history, and text export.
- **Job Search** – global searchable job index across job number, address, status, type/assignment, date, notes, and materials with inline status updates.
- **More** – functional Profile, Settings, and Find a Partner sections with Firestore-backed profile/settings and native-compatible partner request records.

## Files

- `index.html` – semantic single-page application structure for auth and the main Job Tracker sections.
- `config.js` – Firebase web/REST configuration for the current Job Tracker Firebase project.
- `styles.css` – responsive dark design system inspired by the native app's glass-card field interface.
- `script.js` – Firebase Auth + Firestore REST client, routing, form handling, records, exports, and UI rendering.

## Run locally

From the repository root:

```sh
python3 -m http.server 8000 --directory website
```

Then open <http://localhost:8000> in a browser and sign in with a real Firebase user or create a new account.

## Firebase data model

The web client reads and writes these existing app collections:

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
