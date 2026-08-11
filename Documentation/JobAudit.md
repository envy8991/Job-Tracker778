# Job audit history

Job activity is stored in the append-only `jobs/{jobId}/events/{eventId}` subcollection. Events contain the authenticated actor ID, a server timestamp, an event type, and small before/after display summaries. Note bodies, attachment URLs, and complete job snapshots are intentionally excluded.

Firestore's local cache makes already-read pages available offline; locally queued events display as **Offline** until their server timestamp resolves. The UI requests 20 newest events at a time and lets the reader page backward.

## Retention

Audit events are retained for **seven years after the event timestamp**, including after a job is soft-deleted or restored. A scheduled privileged backend retention task should delete expired events under the organization's records policy; clients can never update or delete an event. Legal holds must suspend that task for affected jobs. Export events before destructive account or project removal.
