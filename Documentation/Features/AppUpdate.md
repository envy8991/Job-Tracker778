# Forced App Updates

The iOS app listens to a Firestore-backed version policy and blocks the main UI whenever the configured version is newer than the installed build. This lets administrators require technicians to update before continuing to use Job Tracker.

## Firestore Configuration

Create or update the document at `app_config/ios_version` with these fields:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `latestVersion` | String | Yes | Latest available marketing version, such as `2.2.0`. Any installed version lower than this is blocked. |
| `latestBuild` | String | No | Latest available build number. When the marketing version matches, lower installed builds are blocked. |
| `minimumRequiredVersion` | String | No | Optional hard floor. Installed versions below this value are blocked even if `latestVersion` is omitted. |
| `minimumRequiredBuild` | String | No | Optional hard floor for build numbers. |
| `updateURL` | String | Recommended | App Store, TestFlight, MDM, or internal distribution URL opened by the **Update Now** button. |
| `releaseNotes` | String | No | Short message shown on the blocking update screen. |
| `forceUpdateEnabled` | Bool | No | Defaults to `true`. Set to `false` to temporarily disable forced updates without deleting the document. |

## Runtime Flow

1. `JobTrackerApp` creates a `ForceUpdateViewModel` and starts monitoring Firestore when the root scene appears.
2. `FirestoreAppUpdateRequirementProvider` listens to `app_config/ios_version` in real time.
3. `AppVersionComparator` compares semantic version components numerically, so `1.10.0` correctly sorts after `1.2.9`.
4. If the policy describes a newer version or build, `ForceUpdateView` is rendered over the app and cannot be dismissed. The only action is to open `updateURL`.

## Testing Notes

Keep version comparison coverage in `AppVersionComparatorTests` when changing the policy schema or comparison rules.
