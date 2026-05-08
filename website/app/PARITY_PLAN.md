# Job Tracker Web App Parity Plan

This audit compares the web app in `website/app/` against the native iOS flow that matters for the web release: Jobs/Dashboard, job creation/detail/search, timesheets, yellow sheets, sharing, More/Profile/Settings/Find a Partner, and login.

## What was checked

- Native authentication flow in `Job Tracker/Features/Authentication/AuthFlowView.swift`.
- Native tab structure and More destinations in `Job Tracker/Features/Shared/Shell/MainTabView.swift` and `Job Tracker/Features/Shared/Shell/AppNavigationViewModel.swift`.
- Web routes, forms, persistence calls, and client-side state in `website/app/index.html`, `website/app/styles.css`, `website/app/script.js`, and `website/app/parity-enhancements.js`.

## Immediate fixes completed

1. Match the native auth flow more closely by using three segmented actions: Sign In, Sign Up, and Reset.
2. Replace the login-only password reset button with a dedicated Reset form, matching the app copy and validation path.
3. Align signup positions with the native crew position picker: Aerial, Underground, Nid, and Can.
4. Add client-side validation before server requests so blank/short values fail with clear messages instead of awkward browser or API errors.
5. Guard against missing app config before building request URLs and keep the missing-config message pointed at `website/app/config.js`.
6. Add a web Share action from native-equivalent job actions that writes the native-compatible minimal `sharedJobs` payload and copies a `jobtracker://importJob?token=...` link.
7. Remove desktop-first/default UI that does not appear in the native Jobs or corresponding Swift flows: hero marketing copy, text download/export buttons, the shared import token preview on Job Search, dashboard shortcut cards unrelated to Jobs, sidebar workspace summary, and explanatory persistence copy.
8. Keep default copy focused on the native task flow by using a simple Jobs date header, job completion counts, job lists, save actions, and More sections without implementation details.

## Guardrails for future web work

- Do not add desktop marketing copy, product-positioning paragraphs, or implementation/persistence explanations to default authenticated screens.
- Do not reintroduce text download/export controls unless the native app exposes an equivalent user action for that surface. PDF parity work should be implemented as native-matching PDF output, not plain text exports.
- Do not place shared import token entry or preview controls in the default Job Search tab. If web import is revived, expose it only through a native-equivalent deep-link/import flow and keep it out of the normal search UI.
- Do not add dashboard shortcut cards for Timesheets, Yellow Sheets, partners, routing hints, or other non-Jobs destinations to the default Jobs screen. Keep those capabilities in their native-equivalent tabs or actions.
- Do not add sidebar workspace summaries or other desktop-shell status cards unless a matching native shell affordance exists.
- Keep underlying JavaScript helpers only when they support persistence/session behavior or are reachable from native-equivalent actions such as job detail, job sharing, saving forms, search, settings, profile, or partner requests.

## Remaining parity work

### 1. Visual system pass

- Replace the remaining desktop shell treatment with a closer SwiftUI glass-card layout: centered auth header, segmented controls, card spacing, and button sizing that mirrors the native `JTPrimaryButton` and `JTTextField` components.
- Add icon affordances to web inputs where the app uses SF Symbols: envelope, lock, person, map pin, clock, and document symbols.
- Normalize terminology and capitalization so the web uses the same labels as the app: `Sign In`, `Create Account`, `Yellow Sheet`, `Find a Partner`, and native status labels.

### 2. Jobs/Dashboard parity

- Keep the Monday-Friday picker, selected-day job completion counts, Create Job form, open jobs, closed jobs, and job detail actions.
- Continue improving the job detail drawer so users can inspect/edit status, notes, assignment/material fields, footage fields, participants, route, share, and remove actions from the native-equivalent job surfaces.
- Add route/map affordances for addresses only where the native job detail flow exposes an equivalent action and after map-provider integration is selected.

### 3. Job creation, detail, search, and sharing

- Expand job detail editing to cover any remaining native fields: assignment/material fields, footage fields, participants, and unshare/remove behavior.
- Keep shared-job publishing reachable from job actions. Revisit web import only as a deep-link/import flow, not as a default Job Search token preview.
- Expand search results so each result can open the same detail drawer and show matching fields without adding non-native shortcut cards.

### 4. Timesheets and yellow sheets

- Keep the current web editors for weekly timesheets and daily yellow sheets.
- Replace removed text exports with browser PDF generation or a shared server-side PDF service that matches the native PDF output.
- Keep profile shortcuts to past timesheets and past yellow sheets because they match the native Profile screen.

### 5. More tab scope

- Required for web release: Profile, Settings, and Find a Partner.
- Consider adding Recent Crew Jobs only after the required web scope is stable because it exists in native More but was not in the web release minimum.
- Keep Admin/Supervisor-only sections out of the default web navigation unless the role gate and server rules are confirmed.

### 6. Testing checklist

- Login, signup, reset, sign-out, and persisted-session refresh.
- Create/update/remove jobs as technician and supervisor/admin roles.
- Save/reopen timesheets and yellow sheets across refreshes.
- Search by job number, address, type, status, date, notes, assignment, and materials.
- Send/accept/decline partner requests between two test users.
- Verify the UI at phone, tablet, and desktop widths.
