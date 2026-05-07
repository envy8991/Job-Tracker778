# Web App Parity Implementation Notes

These notes intentionally live outside `PARITY_PLAN.md` so the current PR can merge cleanly over the already-merged baseline plan.

## Completed in this follow-up

1. Added a first-class Job Detail dialog for dashboard/search results with edit, route, share, and remove actions.
2. Added shared-job import preview/claiming from pasted tokens or `jobtracker://importJob?token=...` links.
3. Added Profile shortcuts to past timesheets and yellow sheets.
4. Kept the original parity plan stable to avoid merge conflicts with the already-merged baseline documentation.

## Still remaining

- Replace text exports with browser PDF generation or a shared server-side PDF service that matches the native PDF output.
- Continue visual-system polish for closer SwiftUI parity, including icon affordances and tighter glass-card spacing.
- Expand the shared-job import route into a richer preview/deep-link handoff if the web app is hosted with a production URL.
