# Meta Smart Glasses Capture Assistant

Job Tracker includes a production-safe Meta Smart Glasses capture assistant that prepares the app for Meta's Wearables Device Access Toolkit while still working when the gated SDK package is not present in the build. The assistant treats the glasses as a field capture accessory and keeps the iPhone app responsible for job selection, technician review, Firebase uploads, and sync status.

## What Works Now

- Settings exposes a **Meta Smart Glasses** section where technicians can enable the capture assistant, keep review-before-upload on, prefer the nearest/current job for voice workflows, and see whether the current build is ready for the SDK package.
- Job detail screens include a **Meta Smart Glasses** capture panel with House, NID, and CAN evidence categories.
- If Meta's SDK is not linked, the panel automatically falls back to phone camera/photo-library capture so the same evidence-routing workflow remains usable today.
- Captured images populate the existing job photo slots and are queued through `JobPhotoUploadQueue` when the technician taps **Save**.
- The queue persists image files locally, retries uploads, patches the correct Firestore photo field, and reports progress through the existing dashboard sync banner.
- Siri/Shortcuts includes a **Meta Evidence** shortcut for hands-free notes such as footage comments, NID/CAN observations, or house-photo context on the current/nearest job.

## SDK Adapter Boundary

`MetaSmartGlassesService` owns the future SDK boundary through the `MetaSmartGlassesCapturing` protocol. The current `MetaSmartGlassesSDKAdapter` intentionally reports that the SDK is unavailable so the app can compile, ship, and be tested without private or preview binaries. Once the team has access to Meta's iOS package, replace the adapter internals with the real connect/disconnect/capture calls and keep the rest of the app unchanged.

The adapter boundary keeps SDK churn isolated from:

- `JobDetailView`, which only receives `UIImage` captures for a selected `JobPhotoSlot`.
- `SettingsView`, which only displays connection state and preference toggles.
- `JobPhotoUploadQueue`, which remains the single durable upload pipeline for job evidence.
- App Intents, which continue to resolve the current/nearest job and append structured evidence notes.

## Field Workflow

1. Open **Settings** and enable **Meta Smart Glasses → Enable capture assistant**.
2. Open a job from Dashboard, Search, Yellow Sheet, or Timesheets.
3. In **Meta Smart Glasses**, choose **House Photo**, **NID Photo**, or **CAN Photo**.
4. Tap **Capture from Glasses**. If the SDK is not available, Job Tracker explains the limitation and opens the phone fallback capture choices.
5. Review the image in the normal job photo slot.
6. Tap **Save** to queue the upload and patch Firestore through the existing sync pipeline.

## Voice Workflow

Use Shortcuts/Siri phrases such as:

- "Meta add evidence to my current job in Job Tracker."
- "Add Meta glasses note with Job Tracker."
- "Add this footage to my current job with Job Tracker."

The intent resolves the nearest pending job for today when location is available; otherwise it falls back to the next pending job and includes that fallback reason in the spoken response. It appends notes in this format:

```text
[Meta Glasses • Footage • Jun 13, 10:45 AM] Added 130 feet from CAN to NID.
```

## Guardrails

- The feature is off by default.
- Review-before-upload is on by default.
- Capture is explicit and tied to a visible job/address.
- Photos reuse existing Firebase Storage and Firestore rules instead of introducing a new storage path.
- The SDK adapter can fail gracefully without blocking phone capture.
- The app Info.plist includes camera, photo-library, microphone, and MWDAT analytics opt-out keys needed for the capture workflow and future SDK swap-in.
- Voice notes do not upload media; they only append structured text to the resolved job.

## Next SDK Swap-In Step

When Meta grants SDK access, implement `MetaSmartGlassesSDKAdapter` in `Job Tracker/Features/MetaSmartGlasses/MetaSmartGlassesService.swift` by importing the package and mapping its device connection/photo APIs into `connect()`, `disconnect()`, and `capturePhoto()`. No other Job Tracker screens should need to change unless Meta requires additional permission UI.
