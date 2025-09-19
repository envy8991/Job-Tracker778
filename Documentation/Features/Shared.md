# Shared

Cross-cutting building blocks used by many screens are collected under Shared:

- **Shell** contains the authenticated container (`ContentView`, `AppShellView`, `MainTabView`, `AppNavigationViewModel`).
- **Components** houses reusable SwiftUI helpers such as `ActivityView`, `ImagePicker`, and the gradient background modifier.
- **Services** wraps app-wide data sources like `FirebaseService` and `LocationService`.
- **Mapping** groups the interactive `MapsView` experience plus geometry types and route syncing helpers.
- **Messaging** includes the chat UI and `ChatViewModel` used by partner conversations.
- **Team** centralizes pairing and roster support via `FindPartnerView` and `UsersViewModel`.
