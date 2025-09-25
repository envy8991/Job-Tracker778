# Settings

The Settings tab lets technicians configure routing preferences, manage notifications, customise the theme, and update account details.

## Responsibilities

- Toggle smart routing and choose whether to optimise routes by closest-first or farthest-first order.
- Manage arrival alert notifications for the current day, prompting the user to grant location permissions when necessary.
- Select the address suggestion provider (Apple Maps or Google Places) for job creation forms.
- Launch the theme editor (`JTThemeManager`) so techs can tweak accent colours and saved presets.
- Display the signed-in user's profile information and allow sign out, password reset, and account deletion.
- Offer quick access to privacy policies and support email links.

## Key Types

| Type | Role |
| --- | --- |
| `SettingsView` | Main SwiftUI surface composed of `GlassCard` sections for appearance, routing, notifications, maps, and account. |
| `ProfileView` | Secondary screen for editing profile details or viewing partner/supervisor information. |
| `JTThemeManager` | Environment object controlling the design system's current theme and presenting the theme editor sheet. |
| `ArrivalAlertManager` | Service that monitors and schedules location-based notifications for job arrival reminders. |

## Data Flow & State

- Persistent preferences use `@AppStorage` keys (`smartRoutingEnabled`, `routingOptimizeBy`, `arrivalAlertsEnabledToday`, `addressSuggestionProvider`).
- Deleting an account invokes `AuthViewModel.deleteAccount`, showing confirmation and error handling states while the request is in flight.
- Arrival alerts check `LocationService` to ensure `always` authorization is available before toggling on.

## Integration Notes

- Provide `AuthViewModel`, `JTThemeManager`, `ArrivalAlertManager`, and `LocationService` as environment objects when presenting `SettingsView`.
- If you add new persisted preferences, define a namespaced `@AppStorage` key and document the behaviour here so QA knows how to reset state.
- Keep support URLs and contact emails centralised in constants to simplify white-labelling for other deployments.
