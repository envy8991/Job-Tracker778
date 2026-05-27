# Project Documentation

This folder collects long-form guides for each feature area in Job Tracker. The Markdown files were moved out of the Xcode target so documentation updates no longer trigger resource conflicts during builds. Browse the sections below for architecture notes, view model responsibilities, and integration details.

## Feature Guides

- [Admin](Features/Admin.md)
- [Authentication](Features/Authentication.md)
- [Dashboard](Features/Dashboard.md)
- [Help](Features/Help.md)
- [Jobs](Features/Jobs.md)
- [Search](Features/Search.md)
- [Settings](Features/Settings.md)
- [Shared](Features/Shared.md)
- [Splice Assist](Features/SpliceAssist.md)
- [Timesheets](Features/Timesheets.md)
- [Yellow Sheet](Features/YellowSheet.md)

## Companion Experiences

- **watchOS** – The *Job Tracker Companion Watch App* mirrors daily job summaries and uses `WatchBridge` to stay in sync with the iOS app. The same Firebase models are reused, while the interface is tailored for glanceable updates.
- **iMessage Extension** – The *imessage cs* target renders job cards that supervisors can share in Messages. Payloads are produced by the `Jobs` feature's sharing helpers and parsed by `MessagesViewController` in the extension target.

## Supporting Materials

- The [Design System guide](../Job%20Tracker/DesignSystem/DesignSystem.md) documents shared colors, typography, glass cards, and button styles.
- Tests under `Job TrackerTests/` demonstrate integration points for Firestore, search matching, and PDF exports. Reviewing the tests is a fast way to see expected behaviours for each feature's view model.

When you add a new feature module, place a matching Markdown file under `Documentation/Features/` and link it above. This keeps the engineering and product teams aligned on workflows, data contracts, and UI responsibilities.
