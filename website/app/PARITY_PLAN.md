# Job Tracker Web App Parity Plan

This audit compares the Firebase-backed web app in `website/app/` against the native iOS flow that matters for the web release: dashboard, job creation/detail/search, timesheets, yellow sheets, sharing, More/Profile/Settings/Find a Partner, and login.

## What was checked

- Native authentication flow in `Job Tracker/Features/Authentication/AuthFlowView.swift`.
- Native tab structure and More destinations in `Job Tracker/Features/Shared/Shell/MainTabView.swift` and `Job Tracker/Features/Shared/Shell/AppNavigationViewModel.swift`.
- Web routes, forms, Firebase REST calls, and client-side state in `website/app/index.html`, `website/app/styles.css`, and `website/app/script.js`.

## Immediate fixes completed

1. Match the native auth flow more closely by using three segmented actions: Sign In, Sign Up, and Reset.
2. Replace the login-only password reset button with a dedicated Reset form, matching the app copy and validation path.
3. Align signup positions with the native crew position picker: Aerial, Underground, Nid, and Can.
4. Add client-side validation before Firebase requests so blank/short values fail with clear messages instead of awkward browser or API errors.
5. Guard against missing Firebase config before building Firestore URLs and fix the missing-config message to point at `website/app/config.js`.
6. Correct the More page copy to say Firebase-backed persistence instead of local persistence.
7. Add a web Share action that writes the native-compatible minimal `sharedJobs` payload and copies a `jobtracker://importJob?token=...` link.
8. Add a first-class Job Detail dialog for dashboard/search results with edit, route, share, and remove actions.
9. Add shared-job import preview/claiming from pasted tokens or links.
10. Add Profile shortcuts to past timesheets and yellow sheets.

## Remaining parity work

### 1. Visual system pass

- Replace the current desktop-first hero treatment with a closer SwiftUI glass-card layout: centered auth header, segmented controls, card spacing, and button sizing that mirrors the native `JTPrimaryButton` and `JTTextField` components.
- Add icon affordances to web inputs where the app uses SF Symbols: envelope, lock, person, map pin, clock, and document symbols.
- Normalize terminology and capitalization so the web uses the same labels as the app: `Sign In`, `Create Account`, `Yellow Sheet`, `Find a Partner`, and native status labels.

### 2. Dashboard parity

- Keep the current Monday-Friday picker, selected-day rollups, next-job card, timesheet hours, yellow sheet state, and partner card.
- Completed: dashboard/search cards now open a dedicated Job Detail dialog for inspect/edit actions.
- Completed baseline: Job Detail includes an `Open route` action using the address in a web map search; provider-specific routing can still be refined later.

### 3. Job creation, detail, search, and sharing

- Completed baseline: Job Detail supports status, notes, assignment/material fields, footage fields, participants, route, share, save, and remove actions.
- Completed baseline: Job Search includes shared-token/link preview and import claiming for the same `SharedJobPayload` flow the web app publishes.
- Expand search results so each result can open the same detail drawer and show matching fields.

### 4. Timesheets and yellow sheets

- Keep the current web editors for weekly timesheets and daily yellow sheets.
- Replace text exports with browser PDF generation or a shared server-side PDF service that matches the native PDF output.
- Completed baseline: Profile now shows shortcuts/counts for past timesheets and yellow sheets.

### 5. More tab scope

- Required for web release: Profile, Settings, and Find a Partner.
- Consider adding Recent Crew Jobs only after the required web scope is stable because it exists in native More but was not in the web release minimum.
- Keep Admin/Supervisor-only sections out of the default web navigation unless the role gate and Firestore rules are confirmed.

### 6. Testing checklist

- Login, signup, reset, sign-out, and persisted-session refresh.
- Create/update/remove jobs as technician and supervisor/admin roles.
- Save/reopen timesheets and yellow sheets across refreshes.
- Search by job number, address, type, status, date, notes, assignment, and materials.
- Send/accept/decline partner requests between two test users.
- Verify the UI at phone, tablet, and desktop widths.
