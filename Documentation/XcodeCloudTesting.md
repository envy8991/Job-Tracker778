# Xcode Cloud Testing Setup

The repository now treats Xcode Cloud as the safety net for the full app project instead of a single one-off test target hookup.

## What is wired together

- The shared `Job Tracker` scheme runs `Job Tracker Safety Net.xctestplan`.
- The safety-net test plan includes the `Job TrackerTests` XCTest bundle and collects code coverage.
- The scheme still builds the main app target, which also builds the embedded watch app dependency through the project graph. The watch app must support both `watchos` and `watchsimulator`, and framework references must resolve from `SDKROOT` so iOS simulator test destinations can build the embedded watch app on any current Xcode Cloud image.
- `ci_scripts/ci_pre_xcodebuild.sh` runs before Xcode Cloud's build/test action and fails fast if the shared scheme, test plan, XCTest target coverage, or watch simulator compatibility drifts out of date.

## Run tests locally

From Xcode, select the `Job Tracker` scheme and press `⌘U`.

From Terminal on a Mac with Xcode installed, run the same test plan Xcode Cloud uses:

```sh
xcodebuild test \
  -project "Job Tracker.xcodeproj" \
  -scheme "Job Tracker" \
  -testPlan "Job Tracker Safety Net" \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

You can also run the configuration guardrail locally:

```sh
ci_scripts/ci_pre_xcodebuild.sh
```

## Safety-net expectations

The `Job TrackerTests` bundle is intentionally part of the shared `Job Tracker` scheme so Xcode Cloud and local developers run the same tests. See [Testing Safety Net](TestingSafetyNet.md) for the coverage map and the minimum expectations for future changes.

## Recommended Xcode Cloud workflow

Create or update the workflow in Xcode with these settings:

1. Open **Product → Xcode Cloud → Create Workflow** or edit the existing workflow.
2. Use the repository's shared `Job Tracker` scheme.
3. Add a **Test** action.
4. Select the `Job Tracker Safety Net` test plan.
5. Choose a current iOS Simulator destination that Xcode Cloud supports.
6. Enable code coverage for the workflow.
7. Run the workflow for pull requests and before release/archive workflows.

A separate Build action is not required before the Test action because Xcode builds the app, watch dependency, and test host as part of the test action.

## Future-proofing rules

Keep this setup as the default safety net when the project grows:

- Add every new XCTest or UI-test bundle to `Job Tracker Safety Net.xctestplan` before merging it.
- Keep the `Job Tracker` scheme shared and pointed at the safety-net test plan.
- Keep code coverage enabled in both the scheme and the test plan.
- Prefer deterministic unit tests for parsing, search matching, app-update checks, routing, view models, PDF helpers, import/export payloads, and admin logic.
- Use mocks or in-memory fakes for Firebase, location, map search, filesystem, and network-backed services.
- Avoid tests that write to production Firebase data or depend on physical devices.
- Move slow, flaky, device-only, or external-integration checks into an additional workflow/test plan instead of weakening this one.

The guardrail script intentionally detects new XCTest targets in the project and fails the workflow if they are not listed in the safety-net test plan. That makes future test bundles opt-out by exception instead of accidentally invisible to Xcode Cloud.
