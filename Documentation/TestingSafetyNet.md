# Testing Safety Net

Automated tests are a regression safety net: they keep already-tested behavior from silently breaking when new work lands. They are not a one-time guarantee that the whole app is perfect. To keep the safety net useful, every feature change should either rely on existing coverage or add/adjust tests for the behavior that must not break.

## Current coverage map

| App area | Existing coverage | What it protects |
| --- | --- | --- |
| Admin panel | `AdminPanelViewModelTests` | Roster updates, admin/supervisor toggles, blocked self-destructive actions, maintenance progress. |
| App update gate | `AppVersionComparatorTests`, `ForceUpdateViewModelTests` | Version/build comparisons, disabled requirements, provider success/failure handling. |
| Crew roles | `CrewPositionTests`, recent crew tests | OH/Aerial alias normalization and crew dashboard grouping. |
| Deep links | `DeepLinkRouterTests` | Shared job import URL parsing and rejection of invalid links. |
| Fiber map | `FiberMapViewModelTests` | Mock-backed map persistence, search result centering, user-location flows. |
| Job model/search | `JobSearchMatcherTests`, `AppUserTests` | Job search tokens, Gibson portal/location normalization, user display helpers. |
| Job sheet imports | `JobSheetParserTests` | Parsed row fields and assignee resolution. |
| Package updates | `PackageUpdateServiceTests` | Local package retention and safe update conditions. |
| Shared jobs | `SharedJobServiceTests` | Shared payload encoding/decoding, sender names, geocoding outcomes. |
| Tutorial flows | `InteractiveTutorialStagesTests` | Completion rules for onboarding/tutorial stages. |

## Minimum test expectations for future work

When changing app behavior, add or update tests for at least one of these layers:

1. **Pure logic test** for parsing, filtering, formatting, permissions, version comparisons, or data normalization.
2. **View-model test with mocks** for screens backed by Firebase, location, map search, photo upload, or other services.
3. **Integration test against a non-production backend** only when the behavior depends on real Firebase rules, indexes, Cloud Functions, or Storage behavior.
4. **Manual smoke check** for UI-only polish that cannot be asserted reliably yet.

## Firebase safety rule

Pull-request tests should never write to production Firebase. Use mocks, in-memory fakes, the Firebase emulator, or a separate test Firebase project. Production writes from CI can create fake jobs, modify real job status/participants/photos, change user permissions, delete records, trigger Cloud Functions, and make test runs flaky because they depend on live data.

## Good triggers for adding tests

- A bug was fixed: add a test that fails before the fix and passes after it.
- A new field affects jobs, users, timesheets, yellow sheets, or shared payloads.
- A new filter, role, status, or permission rule is added.
- A Firebase write path changes.
- A feature depends on dates, locations, network state, update gating, or generated files.
