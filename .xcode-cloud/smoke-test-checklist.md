# Xcode Cloud Smoke-Test Checklist

Run this checklist on pull requests and release candidates after the safety-net XCTest plan passes:

1. Build and test the iOS app target with the shared `Job Tracker` scheme and `Job Tracker Safety Net` plan.
2. Build the `Job Tracker Companion Watch App` target for a watchOS Simulator destination.
3. Build the iMessage extension target when the project target is present; until then, validate that `imessage cs/` remains checked in and compiles when re-added to the project.
4. Confirm the host app still embeds the watch app for archive/build workflows.
5. Confirm UI-test launch arguments use seeded data only in UI-test runs (`JT_UI_TESTING=1`) and never in Release archive actions.

Suggested local command set on macOS:

```sh
ci_scripts/ci_pre_xcodebuild.sh
xcodebuild test -project "Job Tracker.xcodeproj" -scheme "Job Tracker" -testPlan "Job Tracker Safety Net" -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild build -project "Job Tracker.xcodeproj" -target "Job Tracker Companion Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)'
```
