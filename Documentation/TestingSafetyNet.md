# Testing Safety Net

This project uses the shared `Job Tracker` scheme and `Job Tracker Safety Net.xctestplan` as the default unit-test safety net for local development and Xcode Cloud.

## Coverage map

The `Job TrackerTests` bundle should keep fast, deterministic XCTest coverage around the areas that are most likely to break core workflows:

- **User and role modeling**: `AppUserTests`, `CrewPositionTests`, and related model tests cover decoding defaults, fallback display helpers, and crew-position normalization for current and legacy labels.
- **App update gating**: `AppVersionComparatorTests` and `ForceUpdateViewModelTests` cover version/build comparisons, disabled update requirements, provider errors, and forced-update decisions.
- **Admin and maintenance workflows**: `AdminPanelViewModelTests`, `PackageUpdateServiceTests`, and admin update tests cover privileged mutations, package retention, and safe apply-window gates without touching production Firebase data.
- **Job intake, sharing, and search**: Deep-link, shared-payload, parser, and search-matcher tests cover import/export payloads and matching heuristics that affect daily job routing.
- **Dashboard and recent crew jobs**: View-model tests cover summaries and detail sheets that crew members use to understand current work.
- **Help and tutorial flows**: Tutorial stage tests protect onboarding guidance from accidental regressions.

## Minimum expectations for future work

Add or update tests in the same pull request when a change affects any of these behaviors:

1. Decoding or encoding app models that come from Firebase, links, files, or JSON payloads.
2. Crew-position, job-status, search, or matching normalization logic.
3. View models with business decisions, especially admin, update, dashboard, job list, timesheet, yellow sheet, and sharing workflows.
4. App update requirements, version comparisons, package downloads, package retention, or safe-apply conditions.
5. Deep links, shared job payloads, imported job sheets, or parsing of externally supplied data.
6. Bug fixes where a regression test can reproduce the failing case.

Prefer small unit tests with mocks, fakes, in-memory data, and injected closures. Do not depend on production Firebase documents, physical devices, wall-clock timing, or external network services in the safety-net plan. Slow integration tests should live in a separate plan or workflow so the main pull-request test action remains reliable.

## Keeping the safety net wired

- Keep `Job Tracker.xcodeproj/xcshareddata/xcschemes/Job Tracker.xcscheme` shared.
- Keep the scheme's Test action pointed at `Job Tracker Safety Net.xctestplan`.
- Keep code coverage enabled in both the shared scheme and the test plan.
- Add every new XCTest or UI-test target to `Job Tracker Safety Net.xctestplan` unless it is intentionally isolated in a separate documented workflow.
- Run `ci_scripts/ci_pre_xcodebuild.sh` after changing the Xcode project, shared scheme, or test plan. The script fails when the scheme no longer references the plan, coverage is disabled, or an XCTest target is missing from the plan.
