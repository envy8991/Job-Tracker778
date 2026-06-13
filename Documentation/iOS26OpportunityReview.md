# iOS 26 and iPadOS 26 Opportunity Review

_Last reviewed: June 12, 2026_

This review maps the current Job Tracker codebase to Apple platform capabilities that are now practical because every iPhone/iPad target in the Xcode project is set to iOS/iPadOS 26.0 and the watch companion is set to watchOS 26.0. It focuses on features that can improve field-work speed, supervisor visibility, iPad productivity, privacy, and system-level discoverability.

## Review basis

### Current app footprint

- **Supported platforms**: The main app, widgets, unit tests, and UI tests are configured with `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; the app targets both iPhone and iPad; the watch app targets watchOS 26.0.
- **Core workflow**: Firebase-backed jobs, dashboard routing, search, weekly timesheets, yellow sheets, partner pairing, chat, admin maintenance, forced updates, CarPlay dispatch, watch companion, iMessage sharing, PDF export, widgets, Live Activities, and App Intents.
- **UI architecture**: A SwiftUI shell uses a `TabView` with `.sidebarAdaptable`, which is a strong base for iPhone tab navigation and iPad sidebars.
- **System experiences already started**: The code already publishes a shared job snapshot to widgets, reloads WidgetKit timelines, and creates/updates an ActivityKit Live Activity for the active or next job.
- **AI workflow already started**: Splice Assist currently sends image-backed prompts to Gemini, which creates an obvious migration/augmentation path for Apple Intelligence and Foundation Models.

### Apple documentation consulted

- [Liquid Glass overview](https://developer.apple.com/documentation/technologyoverviews/liquid-glass)
- [Adopting Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
- [SwiftUI Glass API](https://developer.apple.com/documentation/swiftui/glass)
- [Foundation Models](https://developer.apple.com/documentation/FoundationModels)
- [Apple Intelligence and Siri AI](https://developer.apple.com/documentation/appintents/apple-intelligence-and-siri-ai)
- [Visual intelligence App Intents schema](https://developer.apple.com/documentation/appintents/app-schema-domain-visual-intelligence)
- [Widgets, Live Activities, and Controls](https://developer.apple.com/documentation/appintents/widgets-and-live-activities)
- [MapKit for SwiftUI](https://developer.apple.com/documentation/mapkit/mapkit-for-swiftui)
- [Core Location live updates](https://developer.apple.com/documentation/corelocation/adopting-live-updates-in-core-location)
- [PencilKit](https://developer.apple.com/documentation/pencilkit)

## Executive priority list

| Priority | Opportunity | Best project fit | Why it should be considered |
| --- | --- | --- | --- |
| 1 | Finish the iOS 26 system-experience layer | Widgets, Live Activity, App Intents, Control Center controls, Action button | The app already has shared snapshots, WidgetKit, ActivityKit, and App Intents; this is the fastest route to daily technician value. |
| 2 | Adopt Liquid Glass intentionally | Design system, app shell, dashboard cards, tab/sidebar chrome, widget visual language | The app already has custom glass cards and gradients, so a focused refresh can feel native without rewriting every screen. |
| 3 | Add App Entities, Spotlight indexing, Siri/Apple Intelligence schemas, and visual intelligence | Jobs, addresses, active assignments, supervisor notes, timesheets, yellow sheets | Current intents are action-oriented. iOS 26 can understand app content better if jobs and documents become indexed app entities. |
| 4 | Add Foundation Models as a private/on-device AI tier | Splice Assist, job-note cleanup, timesheet summary, yellow-sheet QA, supervisor import validation | Splice Assist already proves the product need; Foundation Models can reduce latency and external API exposure for supported tasks. |
| 5 | Modernize iPad workflows | Sidebar, multiwindow documents, resizable detail panes, keyboard shortcuts, drag and drop | The app now targets iPadOS 26 and has large document/form workflows that are better on iPad than in phone-first sheets. |
| 6 | Upgrade mapping and location | MapKit for SwiftUI, route overlays, Look Around, Core Location live updates, arrival monitoring | Routing and dispatch are core to the product, and the current code mixes native location, Leaflet web maps, and MapKit search. |
| 7 | Improve photo/PDF capture and annotation | PhotosPicker/Transferable, Vision OCR, PencilKit, PDFKit | Yellow sheets, timesheets, Splice Assist, and job photos all benefit from safer import, OCR, and Apple Pencil markup. |
| 8 | Refactor state and local persistence | Observation, SwiftData local drafts/cache, async Firestore boundaries | The codebase has many `ObservableObject` view models; iOS 26-only support makes modern state and local draft storage easier to adopt gradually. |
| 9 | Expand watchOS 26 companion value | Smart Stack relevance, watch actions, current job status, location-aware glance | The watch target exists and syncs daily job data; adding actions would reduce phone use on job sites. |
| 10 | Strengthen privacy/security platform adoption | Passkeys, Sign in with Apple, App Privacy improvements, on-device AI fallback | Authentication is Firebase email/password today; passkeys and private AI align better with field-worker usage and sensitive job data. |

## Detailed recommendations

### 1. Finish the system-experience layer

**Current state**

- `JobSystemExperienceService` persists daily job snapshots to an app group, reloads WidgetKit timelines, and requests/updates a Live Activity for the active or next job.
- The widget extension includes Today Jobs and Current Job widgets plus an ActivityKit configuration for the Live Activity.
- The app already has App Intents for creating jobs, updating job status, getting today’s jobs, directions, nearest-job assignment/footage, and summaries.

**Next features to add**

1. **Control Center controls / Action button actions**
   - Add controls for “Open next route,” “Mark current job done,” “Set nearest job assignment,” “Add footage,” and “Start arrival monitoring.”
   - Reuse the existing App Intent resolver where possible.
   - Require confirmation for destructive/status-changing actions.

2. **Interactive widget actions**
   - Add intent-backed buttons directly inside the Current Job widget: open route, mark done, message partner, copy address.
   - Keep the widget read-only when the shared snapshot is stale or the user is signed out.

3. **Richer Live Activity states**
   - Include ETA, travel distance, arrival-monitoring status, partner assignment, and next required action.
   - End the Live Activity automatically when the active job becomes done or when the day changes.
   - Use deep links for job detail, dashboard, Maps directions, and partner chat.

4. **Testing**
   - Expand `AppIntentEntryPointTests` to verify the new intents, stale snapshot behavior, and permission-denied location fallbacks.

**Risk**: Any action available outside the app needs conservative permission checks because WidgetKit/App Intents can execute while the full app UI is not visible.

### 2. Adopt Liquid Glass through the design system, not one-off screens

**Current state**

- The app already defines a brand-specific design system (`JTColors`, `JTComponents`, theme presets, elevations, gradients, glass-card utilities).
- The SwiftUI tab shell uses modern tab APIs and `.sidebarAdaptable`, giving iPadOS a natural place to pick up system navigation behavior.

**Next features to add**

1. **Create a single `JTGlassSurface` abstraction**
   - Wrap iOS 26 `glassEffect` in the design system.
   - Apply it consistently to dashboard cards, more-menu cards, action buttons, and status HUDs.
   - Keep a plain material fallback only if a future target adds lower OS support again.

2. **Audit custom nav/background treatments**
   - Build with the iOS 26 SDK and compare screens that use standard `NavigationStack`, `TabView`, `List`, `Toolbar`, and custom gradient backgrounds.
   - Remove custom chrome where standard controls already receive Liquid Glass automatically.

3. **Refresh app icons and widget surfaces**
   - Prepare icons using the current Apple icon guidance and align widget backgrounds with the new material style.

**Risk**: Overusing custom glass can hurt readability. Prioritize hierarchy: navigation chrome first, primary action cards second, dense forms last.

### 3. Make jobs real App Entities and index them for Spotlight/Siri

**Current state**

- App Intents currently accept simple parameters such as address/job number/status rather than strongly typed app entities.
- `JobIntentResolver` can find today’s nearest pending job using Core Location and Firebase.

**Next features to add**

1. **Define `JobEntity` and `JobEntityQuery`**
   - Include job ID, address, short address, job number, status, assignment, scheduled date, participant names, and optional coordinate.
   - Provide queries for today’s jobs, pending jobs, nearest job, recent crew jobs, and job-number lookup.

2. **Adopt assistant schemas where applicable**
   - Map “open job,” “update job status,” “get current assignment,” “set assignment,” “get directions,” and “summarize current job” into schema-backed intents.
   - Add onscreen context so a user can say “mark this one done” while viewing a job detail.

3. **Index jobs and documents in Spotlight**
   - Index current/recent jobs, yellow sheets, timesheets, and supervisor documents that the signed-in user is allowed to access.
   - De-index on sign-out or role changes.

4. **Add visual intelligence search**
   - Use the visual intelligence semantic content search schema so a technician can point the camera at a work order, house number, or NID/CAN label and search matching jobs.
   - Return `JobEntity` results and route to job detail.

**Risk**: Spotlight and Siri integrations must respect Firebase security, user roles, partner scoping, and sign-out cleanup.

### 4. Add Foundation Models as an on-device/private AI tier

**Current state**

- Splice Assist encodes an image and sends it with task-specific prompts to Gemini.
- The current architecture already separates prompt generation in the view model from network execution in `GeminiService`.

**Next features to add**

1. **Introduce an `AIService` protocol**
   - Keep Gemini as one implementation.
   - Add a Foundation Models implementation for supported devices and tasks.
   - Route requests by capability: on-device first for summarization/extraction, cloud model for unsupported multimodal or complex cases.

2. **Start with low-risk structured outputs**
   - Job-note cleanup.
   - Timesheet week summary.
   - Yellow-sheet missing-field checklist.
   - Supervisor import validation.
   - Fiber color/assignment extraction when confidence is high.

3. **Use guided generation types**
   - Define typed outputs such as `JobSummary`, `TimesheetIssue`, `YellowSheetMissingField`, and `SpliceAnalysisResult`.
   - Store confidence and source text/image context for review.

4. **Add evaluations**
   - Build a small test corpus of real anonymized job notes, yellow-sheet samples, and splice images.
   - Compare Gemini and Foundation Models responses before enabling automatic suggestions.

**Risk**: Field operations should not rely on unchecked AI. Keep all AI output reviewable, auditable, and easy to reject.

### 5. Make iPadOS 26 a first-class productivity surface

**Current state**

- The app targets iPad and allows all iPad orientations.
- The tab container already uses `.sidebarAdaptable`.
- Timesheets, yellow sheets, maps, admin, and PDF review are naturally iPad-friendly workflows.

**Next features to add**

1. **Use split/detail layouts for dense workflows**
   - Jobs/search: list of jobs on the left, selected job detail/map on the right.
   - Timesheets: week/day list on the left, editable detail and PDF preview on the right.
   - Yellow sheets: checklist sections on the left, PDF/annotation preview on the right.
   - Admin: roster table on the left, selected-user flags/history on the right.

2. **Add keyboard shortcuts**
   - New job, search, next pending job, mark done, export PDF, open current route, switch tabs.

3. **Add drag and drop**
   - Drag job addresses into Maps/Messages.
   - Drop images/PDFs into Splice Assist or Yellow Sheet attachments.

4. **Evaluate multiwindow scenes**
   - Let supervisors keep dashboard, maps, and admin open in separate windows on iPad.

**Risk**: Avoid duplicating business logic. Build adaptive views over the same view models/services rather than separate iPad-only feature stacks.

### 6. Modernize maps, routing, and arrival monitoring

**Current state**

- The shared mapping feature includes `MapsView`, `RouteService`, `LocationService`, `GeofenceService`, `ArrivalAlertManager`, and a `LeafletWebMapView` for fiber assets.
- App Intents can find and route to the nearest job.

**Next features to add**

1. **Move job maps toward MapKit for SwiftUI**
   - Use native annotations for jobs, crew, and selected assets.
   - Use `MapPolyline` for routes and fiber spans where the geometry is available.
   - Add Look Around previews for job addresses when available.

2. **Use Core Location live updates for active route mode**
   - Replace one-off location callbacks in active workflows with async location streams.
   - Surface diagnostics when location updates are unavailable or throttled.

3. **Tie arrival monitoring to Live Activities and controls**
   - Starting arrival monitoring should update the Live Activity and expose a Stop/Resume action.
   - Arrival should offer “mark in progress,” “open job,” or “notify partner.”

4. **Keep Leaflet only where it is clearly better**
   - If fiber asset data depends on web mapping/GeoJSON behaviors, keep Leaflet for that surface.
   - Use native MapKit for routing, selected job detail, and user-location workflows.

**Risk**: Location and background behavior can affect battery. Add explicit user controls and clear status copy.

### 7. Upgrade photo import, OCR, PDF, and Apple Pencil workflows

**Current state**

- Job photos and Splice Assist use image pickers/Camera APIs.
- Timesheets and yellow sheets generate PDFs, preview PDFs, and support editable PDF views.

**Next features to add**

1. **Use PhotosPicker + Transferable for photo import**
   - Replace older picker wrappers where the source is the photo library.
   - Keep camera capture for direct job-site photos.

2. **Add Vision OCR pre-processing**
   - Extract addresses, job numbers, CAN/NID labels, material codes, and supervisor notes from images before upload.
   - Use extracted text as context for App Intents, Spotlight, and AI.

3. **Improve iPad Apple Pencil support**
   - Add PencilKit signatures and annotations for yellow sheets and timesheet sign-off.
   - Keep PDFKit output as the final export artifact.

4. **Add document quality checks**
   - Warn if a signature is missing, required yellow-sheet fields are blank, or photos are too blurry/dark.

**Risk**: OCR can create incorrect fields. Default to suggestions, not automatic overwrites.

### 8. Gradually adopt Observation and SwiftData where they help

**Current state**

- Most view models use `ObservableObject`/`@Published` and Firebase listeners.
- Firebase should remain the server source of truth.

**Next features to add**

1. **Observation for new/refactored local UI state**
   - Start with self-contained screens: Help/Tutorials, Settings/Profile, Splice Assist, PDF editors.
   - Avoid rewriting stable Firebase-heavy view models only for style.

2. **SwiftData for local drafts and caches**
   - Offline job creation drafts.
   - Timesheet/yellow-sheet drafts.
   - Recently viewed jobs.
   - Cached fiber map metadata.
   - AI result drafts awaiting technician approval.

3. **Sync conflict policy**
   - Store draft origin, last edited timestamp, Firebase document version, and conflict state.

**Risk**: A local database plus Firestore can create conflicting sources of truth. Restrict SwiftData to drafts/cache until a full sync strategy exists.

### 9. Expand watchOS 26 companion workflows

**Current state**

- The watch app uses WatchConnectivity and has dashboard/detail views for jobs.

**Next features to add**

1. **Current job glance**
   - Show next pending job, assignment, distance, and status.

2. **Watch App Intents/actions**
   - Mark current job done.
   - Open directions on phone.
   - Notify partner.
   - Add quick footage/status note.

3. **Smart Stack relevance**
   - Surface the current job near scheduled time or when arrival monitoring is active.

**Risk**: Keep watch actions short and confirmation-friendly; detailed editing belongs on iPhone/iPad.

### 10. Strengthen authentication and privacy

**Current state**

- The app uses Firebase Auth and role flags for admin/supervisor flows.
- Sensitive field data includes locations, job assignments, photos, notes, timesheets, yellow sheets, and partner messages.

**Next features to add**

1. **Passkeys and Sign in with Apple**
   - Add platform-native sign-in options alongside existing Firebase flows.
   - Reduce password-reset friction for field crews.

2. **Privacy-aware AI routing**
   - Use on-device/Foundation Models for summaries and extraction where possible.
   - Require explicit user action before sending job-site photos or notes to third-party AI.

3. **Data lifecycle controls**
   - On sign-out, clear app group snapshots, Spotlight indexes, cached SwiftData drafts that are not needed, and widget-visible data.

**Risk**: System experiences can display stale/sensitive data after sign-out if app group stores and indexes are not cleared.

## Suggested implementation roadmap

### Phase 1 — Fast wins, low architectural risk

1. Add intent-backed Control Center controls and Action button actions for next route and current job status.
2. Extend the Current Job widget with safe interactive actions.
3. Add Live Activity ETA/distance/arrival-monitoring state.
4. Wrap iOS 26 Liquid Glass in `JTGlassSurface` and update the dashboard/app shell first.
5. Clear app group/widget data on sign-out.

### Phase 2 — Content intelligence and iPad workflows

1. Add `JobEntity`, entity queries, and Spotlight indexing.
2. Add onscreen App Intent context to job detail and current dashboard cards.
3. Build iPad split layouts for search/jobs, timesheets, yellow sheets, and admin.
4. Add PhotosPicker/Transferable and OCR for job photos/yellow sheets/Splice Assist.
5. Add PencilKit signatures and annotation improvements.

### Phase 3 — AI and advanced mapping

1. Add an `AIService` protocol with Gemini and Foundation Models implementations.
2. Add guided-generation outputs and evaluations for Splice Assist and document QA.
3. Move route/job maps to MapKit for SwiftUI where native maps fit.
4. Add visual intelligence semantic content search for work orders, house numbers, CAN/NID labels, and job documents.
5. Add SwiftData local drafts for offline timesheets/yellow sheets/jobs.

## Decisions needed before implementation

- Which system actions are safe to execute without opening the app?
- Should status-changing widget/control actions require confirmation every time?
- Which job data is allowed in Spotlight and widgets for each role?
- Should Gemini remain the default AI backend, or should Foundation Models be the default when available?
- Which iPad screens should support multiwindow first?
- How long should local drafts, OCR text, and AI outputs be retained?
