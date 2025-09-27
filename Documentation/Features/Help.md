# Help

The Help feature contains self-service education surfaces that onboard new hires and provide contextual troubleshooting steps for seasoned technicians.

## Responsibilities

- Present a searchable help center (`HelpCenterView`) with quick links to top tasks and deep links into other feature tabs.
- Offer lightweight FAQ content, support contact shortcuts, and links to company policies.

## Key Types

| Type | Role |
| --- | --- |
| `HelpCenterView` | Entry point showing featured articles, sections, and navigation into tutorials or other screens. |
| `HelpArticle` (if added) | Model representing a help topic. Typically sourced from static JSON or Firestore collections. |

## Integration Notes

- The Help tab is reachable from the authenticated shell via `MainTabView`. Use `AppNavigationViewModel` to trigger deep links when launching from push notifications or help links.
- When expanding help content, prefer markdown/JSON payloads that can be fetched from Firestore so updates do not require app releases.
