# iOS 17–26 Opportunity Review

_Last reviewed: June 11, 2026_

This review looks at Job Tracker's current iOS codebase and identifies Apple platform features introduced after iOS 16 that are most likely to benefit the app now that the original iOS 16 baseline is no longer the main constraint.

## Current project baseline

- The Xcode project still sets the iPhone deployment target to iOS 16.0 for the app and test targets, even though the README describes the product as an iOS 17+ / watchOS 10+ app.
- The primary app is already a modern SwiftUI app with Firebase-backed jobs, timesheets, yellow sheets, partner chat, MapKit/Core Location routing, CarPlay dispatch, watchOS companion views, iMessage sharing, PDF export, and App Intents shortcuts.
- Existing post-iOS-16-ready surfaces include App Intents, ShareLink/PDF export, MapKit search/completer flows, watch synchronization, and a Gemini-backed Splice Assist workflow.

## Best opportunities

| Priority | Platform feature | Introduced after iOS 16 | Best fit in this project | Why it matters |
| --- | --- | --- | --- | --- |
| 1 | Live Activities + Dynamic Island | iOS 16.1, richer system adoption in later iOS releases | Dashboard, route-to-next-job, active job status, arrival alerts | Keeps the technician's active job, ETA, assignment, and status visible without opening the app. |
| 2 | Widgets + interactive widgets + controls | Interactive widgets in iOS 17; Control Center / Lock Screen controls in later releases | Today's jobs, quick status updates, partner pairing, timesheet clock/status shortcuts | Turns frequent actions into one-tap entry points from Home Screen, Lock Screen, StandBy, Action button, or Control Center. |
| 3 | App Intents schemas, entities, Spotlight indexing, and App Intents testing | Expanded substantially after iOS 16 and in the newest SDKs | Existing `CreateJobIntent`, `UpdateJobStatusIntent`, current-job intents, global job search | Lets Siri and Spotlight understand Job Tracker data naturally instead of relying only on fixed shortcut phrases. |
| 4 | Foundation Models / Apple Intelligence integration | iOS 26+ SDK family | Splice Assist, job-sheet parsing, timesheet summarization, supervisor import cleanup | Could move parts of the current Gemini workflow on-device/private and reduce latency/cost for text extraction, summarization, and guided troubleshooting. |
| 5 | MapKit for SwiftUI modernization | iOS 17+ | `MapsView`, route overlays, job search detail maps, fiber asset display | Replacing older UIKit/web-map wrappers where practical would simplify overlays, annotations, Look Around previews, selection, and route visualization. |
| 6 | TipKit | iOS 17+ | Help center, onboarding tutorial, first-use prompts on dashboard/search/timesheets | Contextual tips can replace some custom tutorial plumbing while remaining system-consistent and suppressible. |
| 7 | PhotosPicker + Transferable + Vision OCR | PhotosPicker in iOS 16, better fit once modernizing iOS 17+ code; Vision OCR continues to improve | Job photos, NID/CAN photos, yellow-sheet import, Splice Assist image intake | Safer photo-library privacy, better multi-select/import UX, and local text extraction before upload. |
| 8 | Observation + SwiftData for local-only state | iOS 17+ | View models with heavy `@Published` usage, offline drafts, cached map assets, local timesheet drafts | Observation can reduce redraw overhead; SwiftData can store local drafts/caches while Firebase remains the source of truth. |
| 9 | Liquid Glass / latest design system updates | iOS 26+ design language | App shell, dashboard cards, settings, navigation bars, icons | The app already has a custom glass design system, so it is well positioned for a visual refresh that feels native on iOS 26 while retaining brand colors. |
| 10 | Passkeys / Sign in with Apple improvements | Mature post-iOS-16 adoption | Authentication | Reduces password-reset support, improves security, and aligns with platform expectations for field workers. |

## Detailed recommendations

### 1. Raise the deployment target intentionally

The project should first decide whether the new supported minimum is iOS 17, iOS 18, or iOS 26. The best pragmatic move is usually:

1. Raise the minimum to **iOS 17** first, because it unlocks Observation, SwiftData, TipKit, MapKit for SwiftUI, and interactive widgets while leaving a broad install base.
2. Add **iOS 18/26 availability-gated enhancements** for controls, Apple Intelligence, and Liquid Glass rather than requiring every user to be on the newest OS immediately.
3. Update README/Xcode project alignment so documentation and build settings agree.

### 2. Add a Job Live Activity

Create a `JobTrackerLiveActivity` target using ActivityKit. Suggested states:

- active job address and assignment;
- current status: pending, in progress, completed, issue reported;
- ETA/distance if location permission is granted;
- quick deep links for directions, call/message partner, and open the job detail;
- arrival alert status.

This fits the existing dashboard and route/arrival-alert services. It would make the app much more useful while technicians are driving or working with gloves where opening the full app is inconvenient.

### 3. Add widgets and system controls

Recommended widgets/controls:

- **Today Jobs widget**: count of today's jobs, next address, current assignment, supervisor notes.
- **Current Job widget**: active job card with status and directions deep link.
- **Timesheet widget**: current week totals and submit/export status.
- **Control Center / Action button control**: “Mark current job complete,” “Open next route,” “Add footage,” or “Start arrival monitoring.”

The app already has App Intents for creating jobs, updating status, getting today’s jobs, directions, current assignment, and footage, so this work should extend existing intent code rather than starting from scratch.

### 4. Upgrade App Intents from shortcut phrases to entities and schemas

The current App Intents are useful but phrase-driven. A next-generation integration should add:

- `JobEntity` with stable IDs, address, scheduled date, status, assignment, and crew fields;
- `JobEntityQuery` so Siri, Spotlight, widgets, and Shortcuts can resolve specific jobs;
- indexed job entities for Spotlight results like “show the job on Main Street”;
- parameter summaries and dialogs that make shortcuts easier to configure;
- App Intents tests to validate Siri/Shortcuts behavior without full UI tests;
- view annotations where supported so users can say things like “update this job” from a visible job detail screen.

This is one of the highest leverage upgrades because the project already has many intent entry points.

### 5. Build an Apple Intelligence path for Splice Assist

Splice Assist currently sends cropped map images and prompts to Gemini. With the latest Apple Intelligence/Foundation Models direction, create a provider abstraction:

- keep Gemini as the cloud fallback for complex image reasoning;
- add an Apple Foundation Models provider for eligible devices/OS versions;
- use Vision OCR/barcode/text extraction locally before making any cloud call;
- support “summarize this yellow sheet,” “extract assignment from photo,” and “draft supervisor notes” workflows;
- add evaluation fixtures for common splice-map prompts so prompt and model changes can be tested.

This approach improves privacy and offline resilience while preserving existing functionality when Apple Intelligence is unavailable.

### 6. Modernize mapping incrementally

The app currently uses MapKit in several places and a Leaflet-backed web map for fiber assets. Do not rewrite the entire map surface at once. Instead:

- start with job detail/search maps using MapKit for SwiftUI markers, selection, polylines, and route previews;
- add Look Around previews for job addresses where available;
- keep Leaflet for dense fiber editing until native MapKit overlays can match the required editing workflow;
- expose the same map data model to both renderers so the app can migrate screen by screen.

### 7. Replace custom tutorial moments with TipKit where appropriate

The Help feature already has an interactive tutorial. TipKit is useful for smaller contextual prompts:

- first time opening dashboard quick actions;
- first time sharing a job;
- first time adding CAN/NID footage;
- first time cropping an image in Splice Assist;
- first time exporting/submitting a timesheet.

Keep the full tutorial for onboarding, but use TipKit for lightweight reminders where a modal tutorial is too heavy.

### 8. Improve image intake and document extraction

Recommended improvements:

- replace `UIImagePickerController` wrappers with SwiftUI `PhotosPicker` where photo-library import is needed;
- use `Transferable` models for job photo payloads and iMessage/share flows;
- run Vision OCR locally on yellow sheets, NID labels, CAN labels, and splice-map crops;
- pre-fill forms from OCR results while allowing technician confirmation before saving.

This should reduce typing in the field and improve data quality.

### 9. Add local-first drafts and caches

Firebase should remain the server source of truth, but iOS 17+ local persistence can improve field reliability:

- local job edit drafts before upload;
- offline photo-upload queue metadata;
- cached fiber map assets;
- partially completed timesheets/yellow sheets;
- last-known dashboard snapshot for no-service areas.

SwiftData is a candidate for these local-only records, but it should be introduced behind repository protocols so tests and Firebase sync remain clean.

### 10. Refresh design for iOS 26 without losing brand identity

The app already has design-system files and “glass” component language. A safe iOS 26 visual pass would:

- audit custom blur/material/elevation tokens against current system materials;
- adopt new navigation/tab/sidebar behaviors where available;
- refresh app icons through Apple's current icon tooling;
- keep the current brand palette but reduce custom effects that conflict with system Liquid Glass.

## Suggested implementation roadmap

### Phase 1: Low-risk modernization

- Align deployment target and README.
- Add `JobEntity`/`JobEntityQuery` and App Intents tests.
- Add a Today Jobs widget using existing data and intents.
- Replace photo-library-only `UIImagePickerController` paths with `PhotosPicker`.

### Phase 2: Field productivity

- Add Live Activity for current job.
- Add Control Center/Action button controls for current-job actions.
- Add OCR-assisted form/photo extraction.
- Add TipKit prompts around high-friction flows.

### Phase 3: Intelligent and native-feeling workflows

- Add Apple Intelligence/Foundation Models provider abstraction for Splice Assist and document summarization.
- Add SwiftData local drafts/caches.
- Migrate selected map screens to MapKit for SwiftUI.
- Refresh the design system for iOS 26 materials and iconography.

## Features to defer

- A full rewrite from Firebase models to SwiftData. SwiftData is better here for local caches/drafts, not as a replacement for Firestore collaboration.
- A full Leaflet-to-MapKit rewrite before validating native editing parity for fiber assets.
- Requiring iOS 26 as the minimum immediately. Prefer iOS 17 minimum plus availability gates unless the actual user base is already nearly all on iOS 26+.
- Image Playground/Genmoji integrations. They are interesting platform features, but they do not solve a core Job Tracker workflow as directly as Live Activities, widgets, intents, OCR, maps, or on-device assistance.

## Apple references reviewed

- Apple Developer: [What’s new in iOS](https://developer.apple.com/ios/whats-new/)
- Apple Developer: [What’s new in Apple Intelligence](https://developer.apple.com/apple-intelligence/whats-new/)
- Apple Developer Documentation: [App Intents](https://developer.apple.com/documentation/appintents/app-intents)
- Apple Developer Documentation: [Widgets, Live Activities, and controls](https://developer.apple.com/documentation/appintents/widgets-and-live-activities)
- Apple Developer Documentation: [MapKit for SwiftUI](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui)
