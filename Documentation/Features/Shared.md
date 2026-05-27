# Shared

Cross-cutting building blocks used by many screens are collected under `Features/Shared`. This module keeps foundational services, navigation scaffolding, and reusable UI components in one place.

## Submodules

- **Shell** – Hosts the authenticated container (`ContentView`, `AppShellView`, `MainTabView`, `AppNavigationViewModel`) that wires environment objects, tab selection, and deep link routing.
- **Components** – Reusable SwiftUI helpers such as `GlassCard`, `ActivityView` (for share sheets), `ImagePicker`, `DateRangePicker`, and gradient backgrounds.
- **Services** – Wrappers around app-wide data sources including `FirebaseService`, `LocationService`, and `ArrivalAlertManager`. They abstract Firestore queries, Cloud Functions, push notifications, and Core Location.
- **Mapping** – The interactive `MapsView`, `RouteService`, and geometry types used for smart routing and driving directions.
- **Messaging** – Chat UI (`ChatView`) and `ChatViewModel` for partner conversations backed by Firestore collections.
- **Team** – Roster utilities like `UsersViewModel` and `FindPartnerView` that allow technicians to pair up and monitor recent crew jobs.
- **More** – Additional shared experiences such as `RecentCrewJobsView`, which surfaces partner activity within other tabs.

## Responsibilities

- Provide dependency injection points for services consumed across feature modules.
- Normalize map and location logic so job-related views can render annotations and directions consistently.
- Emit notifications (`Notification.Name`) that coordinate data refreshes between tabs (e.g., when jobs or partners change).
- Offer UI building blocks that adopt the design system tokens, ensuring every screen shares the same look and feel.

## Integration Notes

- Initialize long-lived services (e.g., `FirebaseService`, `UsersViewModel`) in the app delegate or shell view and pass them via environment objects.
- When adding a new cross-cutting helper, place it here so other features can reuse it without creating import cycles.
- Follow the design system conventions (`JTColors`, `JTSpacing`, `JTShapes`) when composing new shared components.
