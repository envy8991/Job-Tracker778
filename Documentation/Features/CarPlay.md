# CarPlay Job Dispatch

The CarPlay experience is intentionally limited to safe, driving-focused job dispatch tasks. It is not a turn-by-turn navigation app; it surfaces the technician's current dashboard jobs and hands route guidance to Maps.

## Responsibilities

- Show only today's dashboard jobs created by the signed-in technician, matching the phone dashboard's ownership scope rather than exposing another user's jobs.
- Sort jobs by current distance when location is available, honoring the dashboard routing preference for closest-first or furthest-first; fall back to scheduled time and address when distance is unavailable.
- Limit the CarPlay list to twelve jobs after applying the routing preference so the in-car UI stays focused.
- Provide a read-only job detail screen with a primary **Start Directions** action and only compact driving-relevant reference fields. Editing and adding info stay on the phone for CarPlay safety.
- Open driving directions with the dashboard's selected map provider: Google Maps when selected and available, otherwise Apple Maps, using stored job coordinates and geocoding the address only when needed.
- Keep editing, photos, chat, timesheets, admin tools, and long-form search out of CarPlay.

## Key Types

| Type | Role |
| --- | --- |
| `JobDispatchCarPlaySceneDelegate` | CarPlay scene delegate that owns the template stack, loading states, refresh actions, job details, and Maps handoff. |
| `CarPlayJobDispatchService` | Loads today's jobs from `FirebaseService`, filters to jobs created by the current user, and prepares routing-preference-aware display models. |
| `CarPlayLocationProvider` | Requests a short-lived location fix when the app already has location authorization. It does not request new permissions from CarPlay. |
| `CarPlayJobDisplay` | Lightweight presentation wrapper for address title, status, job number, coordinates, and formatted distance. |

## Entitlement Strategy

Apple grants CarPlay through managed capabilities after reviewing the app category and use case. The project includes the CarPlay scene and implementation code, but the app entitlements file must not add a CarPlay entitlement until Apple approves the managed capability and the provisioning profile is regenerated.

Request the **Driving Task** category because Job Tracker provides a limited dispatch workflow for choosing a job destination and starting directions; it is not a turn-by-turn navigation app. Use the complete request packet in [CarPlayEntitlementRequest.md](../CarPlayEntitlementRequest.md) when submitting the request.

Recommended request positioning:

> Job Tracker is a private field-service dispatch app for technicians who drive between assigned job sites. The CarPlay experience shows today's dashboard jobs created by the signed-in technician, sorts them by the user's routing preference, and lets the technician start driving directions without using the phone. It excludes editing, media capture, messaging, timesheets, admin workflows, and other non-driving tasks.

## Testing Notes

- Apple documents CarPlay simulator testing from Xcode by opening Simulator's CarPlay external display after configuring the project.
- Real-device, TestFlight, and App Store distribution require Apple to approve the appropriate CarPlay managed capability and require a provisioning profile that contains the matching entitlement.
- Because this is a driving-task/job-dispatch experience rather than a navigation app, do not add navigation-only dashboard, instrument-cluster, or map-window scenes.
