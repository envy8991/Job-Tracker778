# Xcode Cloud Testing Setup

The `Job Tracker` shared scheme is wired to run the `Job TrackerTests` XCTest bundle. That means local Xcode test runs and Xcode Cloud test actions use the same target and scheme.

## Run tests locally

From Xcode, select the `Job Tracker` scheme and press `⌘U`.

From Terminal on a Mac with Xcode installed, run:

```sh
xcodebuild test -scheme "Job Tracker" -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Recommended Xcode Cloud workflow

Create a workflow in Xcode with these settings:

1. Open **Product → Xcode Cloud → Create Workflow**.
2. Use the repository's shared `Job Tracker` scheme.
3. Add a **Test** action.
4. Choose an iOS Simulator destination, such as a current iPhone simulator.
5. Enable the workflow for pull requests once the suite is stable.

A separate Build action is not required before the Test action because Xcode builds the app for testing as part of the test action.

## What belongs in this suite

Keep pull-request tests fast and deterministic:

- Prefer unit tests for parsing, search matching, version comparison, routing, and view model logic.
- Use mocks or in-memory fakes for Firebase, location, map search, and network-backed services.
- Avoid tests that write to production Firebase data.
- Move slow or device-sensitive tests into a separate workflow or test plan later if needed.
