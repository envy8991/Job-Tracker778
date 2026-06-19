# CarPlay Entitlement Request Packet

Use this packet when submitting Job Tracker for Apple CarPlay entitlement review.

## Recommended Request Category

Request the **Driving Task** CarPlay category. Job Tracker is not a turn-by-turn navigation provider, media app, messaging app, parking app, EV charging app, or quick-ordering app. The CarPlay surface is limited to a short, read-only dispatch workflow that helps a technician choose the next assigned job and hand directions to Maps.

Apple has approved the managed Driving Task capability for Job Tracker. Keep the App ID, regenerated provisioning profile, and `Job Tracker/Job Tracker.entitlements` aligned with the approved `com.apple.developer.carplay-driving-task` entitlement.

## Copy/Paste Use-Case Summary

> Job Tracker is a private field-service dispatch app for technicians who drive between assigned job sites. The CarPlay experience supports a driving task: it shows only today's jobs created by the signed-in technician, keeps the list capped and sorted by the technician's routing preference, and provides a single primary action to start driving directions through Maps. The CarPlay UI is read-only and excludes job editing, photo capture, messaging, chat, timesheets, admin tools, broad search, and any long-form workflow that should remain on iPhone.

## In-App Evidence to Mention

- The app registers one CarPlay scene named `JobDispatchCarPlay` that uses `CPTemplateApplicationScene` and `JobDispatchCarPlaySceneDelegate`.
- CarPlay data comes from `CarPlayJobDispatchService`, which loads today's dashboard jobs for the signed-in user only and limits the display to twelve jobs.
- The CarPlay detail view contains only driving-relevant reference fields and the `Start Directions` action.
- The CarPlay implementation does not create a navigation map, turn-by-turn route engine, dashboard scene, instrument-cluster scene, media playback UI, chat UI, or editing UI.

## Reviewer Demo Script

1. Sign in on iPhone with a technician account that has jobs scheduled for the current day.
2. Connect the app to the CarPlay Simulator from Xcode.
3. Open Job Tracker on CarPlay.
4. Confirm the first screen shows **Today's Jobs** with only the technician's own jobs.
5. Select a job and confirm the detail screen is read-only.
6. Tap **Start Directions** and confirm the app hands off driving directions to the selected Maps provider.
7. Return to the iPhone app to demonstrate that editing, photos, chat, timesheets, admin tools, and search are not available in CarPlay.

## Pre-Submission Checklist

- [ ] Apple Developer Program account is active and the bundle ID matches `com.quinton.Job-Tracker-CS25`.
- [ ] Request text uses the Driving Task positioning above and does not claim Job Tracker is a navigation app.
- [x] `Job Tracker/Job Tracker.entitlements` contains only the approved Driving Task CarPlay entitlement.
- [ ] Confirm the App ID has the approved CarPlay Driving Task managed capability enabled and regenerate/download provisioning profiles before archiving.
- [ ] Run the CarPlay Simulator demo script and capture screenshots/video for the request if Apple asks for supporting material.
- [ ] Verify the production build does not ship hard-coded service credentials in the app Info.plist.

## Post-Approval Implementation Step

After Apple grants the managed capability, the app entitlements file must include `com.apple.developer.carplay-driving-task` as a Boolean `true`. Update signing to use the regenerated provisioning profile and build on a Mac with Xcode before submitting a CarPlay-enabled archive.

## References

- Apple Developer: [CarPlay](https://developer.apple.com/carplay/) describes Driving Task apps as a CarPlay-supported use case.
- Apple Developer Documentation: [Requesting CarPlay Entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements) explains that CarPlay access is granted through managed capabilities and requires matching App ID, provisioning profile, and entitlements configuration after approval.
- Apple Human Interface Guidelines: [CarPlay](https://developer.apple.com/design/human-interface-guidelines/carplay/) emphasizes simplified, driving-optimized interfaces with minimal interaction.
