# Search

The search feature lets technicians find jobs across the entire company roster and quickly navigate to detail views or initiate routing.

## Responsibilities

- Provide a debounced search bar UI that supports both free text and address lookups.
- Query the combined search index exposed by `JobsViewModel` to match by address, customer name, can number, or job ID.
- Integrate with MapKit autocomplete via `SearchCompleterDelegate` to suggest street addresses as the user types.
- Display a result list with key metadata (status, partner, distance) and allow tapping into `JobSearchDetailView` for full context.
- Offer call-to-action buttons for navigation, calling the customer, or opening the job in the Jobs tab.

## Key Types

| Type | Role |
| --- | --- |
| `JobSearchView` | Entry view containing the search bar, segmented filters, and result list. |
| `JobSearchViewModel` | Performs filtering, manages autocomplete results, and formats display strings. |
| `SearchBar` | Reusable SwiftUI component with built-in debouncing and cancel handling. |
| `SearchCompleterDelegate` | Bridges MapKit's `MKLocalSearchCompleter` into Combine publishers. |
| `JobSearchDetailView` | Expanded detail sheet that shows the job summary, partners, notes, and quick actions. |

## Matching Behaviour

- Queries are normalised (case-insensitive, trimmed) and run against multiple fields of `JobSearchIndexEntry`.
- Autocomplete suggestions can be selected to refine the query or immediately jump into an address-based search.
- The view model computes `distanceString` values using the latest location provided by `LocationService` so techs can choose the closest job.

## Integration Notes

- Ensure `JobsViewModel` has started the global search index listener (`startSearchIndexForAllJobs`) before presenting the search tab; otherwise results will be empty.
- When customising matching heuristics, update the test coverage in `JobSearchMatcherTests` to reflect the new behaviour.
- Provide `LocationService` as an environment object if you want to display distance estimates in the result list.
