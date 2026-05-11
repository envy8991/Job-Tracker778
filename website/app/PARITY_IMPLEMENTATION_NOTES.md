# Web App Parity Implementation Notes

These notes intentionally live outside `PARITY_PLAN.md` so the current PR can merge cleanly over the already-merged baseline plan.

## Completed in this follow-up

1. Added a first-class Job Detail dialog for dashboard/search results with edit, route, share, and remove actions.
2. Added shared-job import preview/claiming from pasted tokens or `jobtracker://importJob?token=...` links.
3. Added Profile shortcuts to past timesheets and yellow sheets.
4. Removed the duplicate top-level static website files so `website/app/` is the only web app surface.
5. Scoped Dashboard, Timesheets, Yellow Sheet, Job Search, and More content to their matching bottom tabs.

## Still remaining

- Replace text summary sharing with browser PDF generation or a shared server-side PDF service that matches the native PDF output.
- Continue visual-system polish for closer SwiftUI parity, including icon affordances and tighter glass-card spacing.
- Expand the shared-job import route into a richer preview/deep-link handoff if the web app is hosted with a production URL.
