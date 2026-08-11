# Fiber map basemap operations

The embedded map uses the OpenStreetMap Foundation's standard raster tile service at `https://tile.openstreetmap.org/{z}/{x}/{y}.png`. Framework code and map styling are bundled; only raster basemap tiles require a network connection. A tile failure displays a non-blocking status while locally synced poles, splices, routes, jobs, controls, and attribution remain available.

## Production policy review

Reviewed against the [OpenStreetMap Foundation Tile Usage Policy](https://operations.osmfoundation.org/policies/tiles/) on August 11, 2026. The current implementation:

- uses the documented HTTPS tile URL and shows visible OpenStreetMap copyright attribution;
- relies on normal WebKit caching and does not bulk-download, prefetch, scrape, or provide offline tile packs;
- sends requests directly from `WKWebView`, allowing its normal User-Agent and Referer behavior rather than obscuring identification;
- treats the community service as best-effort, with no SLA, and keeps application data useful during an outage.

Before traffic becomes material, operations should reassess volume and availability needs. High-volume or SLA-backed production use must move to a commercial/provider-hosted tile endpoint or self-hosted tiles whose terms explicitly cover that usage. Do not add aggressive retries or an offline-download feature to the standard OSM endpoint.
