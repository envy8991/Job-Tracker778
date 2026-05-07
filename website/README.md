# Job Tracker Website

This folder contains a standalone browser version of Job Tracker. It is dependency-free and can be opened directly from `index.html` or served by any static host while preserving app-like workflows in `localStorage`.

## Implemented app areas

- **Authentication** – working login, signup, password-reset confirmation, sign-out, and a demo supervisor account (`demo@jobtracker.local` / `password123`).
- **Dashboard** – Monday-Friday selector, daily job rollups, completion progress, sync banner, next-job routing hint, daily summary copy/download, quick job creation, status updates, and job removal.
- **Timesheets** – weekly timesheet editor with supervisor/partner fields, Gibson/Cable South/Other hour totals, local history, and text export.
- **Yellow Sheets** – daily compliance checklist with job reference, materials, notes, technician signature, local history, and text export.
- **Job Search** – global job index search across job number, address, status, type, date, and notes with inline status updates.
- **More** – functional Profile, Settings, and Find a Partner sections with persisted profile/settings and partner request accept/post flows.

## Files

- `index.html` – semantic single-page application structure for auth and the main Job Tracker sections.
- `styles.css` – responsive dark design system inspired by the native app's glass-card field interface.
- `script.js` – localStorage-backed state, form handling, job/timesheet/yellow-sheet/search/profile/settings/partner interactions, and export helpers.

## Run locally

From the repository root:

```sh
python3 -m http.server 8000 --directory website
```

Then open <http://localhost:8000> in a browser.

## Data model notes

The web version currently stores demo data in browser `localStorage` so it works without Firebase credentials. Use the **Reload demo jobs** button on the dashboard to restore the seeded job board.

## Next integration steps

1. Replace local `users`, `jobs`, `timesheets`, `yellowSheets`, `partnerRequests`, and `settings` storage in `script.js` with Firestore/Auth calls that mirror the native app services.
2. Replace text exports with the native PDF generation pipeline or a shared server-side PDF service.
3. Connect routing distances and address suggestions to production map providers.
4. Route partner requests and future chat messages to shared team collections.
