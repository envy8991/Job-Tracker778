# CarPlay Job Dispatch

The CarPlay experience is intentionally limited to safe, driving-focused job dispatch tasks. It is not a turn-by-turn navigation app; it surfaces the technician's current pending jobs and hands route guidance to Maps.

## Responsibilities

- Show only today's pending jobs created by the signed-in technician, matching the dashboard's personal job-list behavior.
- Respect the existing Smart Routing settings: closest-first or farthest-first when enabled and location is available, otherwise scheduled time/address order.
- Limit the CarPlay list to twelve pending jobs so the in-car UI stays focused.
- Provide a job detail screen with a primary **Start Directions** action.
- Open the user's selected maps provider (Google Maps when configured, with Apple Maps fallback) using stored job coordinates, geocoding the address only when coordinates are missing.
- Keep editing, photos, chat, timesheets, admin tools, and long-form search out of CarPlay.

## Key Types

| Type | Role |
| --- | --- |
| `JobDispatchCarPlaySceneDelegate` | CarPlay scene delegate that owns the template stack, loading states, refresh actions, job details, and Maps handoff. |
| `CarPlayJobDispatchService` | Loads today's jobs from `FirebaseService`, filters pending jobs to `createdBy == currentUserID`, and applies the same Smart Routing order preference used by the dashboard. |
| `CarPlayLocationProvider` | Requests a short-lived location fix when the app already has location authorization. It does not request new permissions from CarPlay. |
| `CarPlayJobDisplay` | Lightweight presentation wrapper for address title, status, job number, coordinates, and formatted distance. |

## Entitlement Strategy

Apple grants CarPlay through managed capabilities after reviewing the app category and use case. The project now includes the CarPlay scene and implementation code, but the app entitlements file should not add a CarPlay entitlement until Apple approves the managed capability and the provisioning profile is regenerated.

Recommended request positioning:

> Job Tracker is a private field-service dispatch app for technicians who drive between assigned job sites. The CarPlay experience shows today's pending jobs created by the signed-in technician, honors the existing closest/farthest Smart Routing setting, and lets the technician start driving directions without using the phone. It excludes editing, media capture, messaging, timesheets, admin workflows, and other non-driving tasks.

## Testing Notes

- Apple documents CarPlay simulator testing from Xcode by opening Simulator's CarPlay external display after configuring the project.
- Real-device, TestFlight, and App Store distribution require Apple to approve the appropriate CarPlay managed capability and require a provisioning profile that contains the matching entitlement.
- Because this is a driving-task/job-dispatch experience rather than a navigation app, do not add navigation-only dashboard, instrument-cluster, or map-window scenes.
