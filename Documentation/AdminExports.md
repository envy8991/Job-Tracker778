# Administrator company exports

## Security and workflow

Company exports are available only through the Cloud Functions API. `requestCompanyExport` and `createCompanyExportDownload` require the Firebase `admin: true` custom claim and an ID token whose `auth_time` is no more than five minutes old. The app must reauthenticate the administrator before each call. Supervisor or technician UI visibility is not authorization; the backend rejects them.

Requesting an export creates an `adminExports` job and immediately returns its ID. A Firestore-triggered backend worker reads jobs, timesheets, materials, and users in bounded pages, inventories attachments, and streams a ZIP to private Cloud Storage. The phone only observes its small status document: `status`, `progress`, `expiresAt`, `checksum`, `recordCounts`, and a bounded `failure` object. It never assembles the archive.

When the job is `ready`, call `createCompanyExportDownload` after reauthentication. It returns a random, single-use URL valid for five minutes. The HTTP endpoint atomically consumes that token, records a `downloaded` audit event with the actor UID, and streams the private object. Requests and downloads are append-only audit documents. Do not place export URLs in analytics, logs, email, or support tickets.

## Archive format and import compatibility

The ZIP and its root `manifest.json` use semantic `archiveVersion` **1.0**. Importers must reject unsupported major versions and may accept newer minor versions while ignoring unknown fields.

* `data/jobs.{json,csv}`, `data/timesheets.{json,csv}`, and `data/yellowSheets.{json,csv}` contain operational records. The `yellowSheets` export path is retained as a legacy compatibility name for materials data.
* `data/users.{json,csv}` retains UID, name, crew position, and role flags so relationships can be reconstructed. Email, profile-picture URL, phone, tokens, and all unknown profile fields are deliberately omitted.
* Each JSON file is an array. Each RFC 4180 CSV has `id,json` columns; `json` is the canonical complete record, avoiding lossy flattening of arrays and nested Firestore data.
* `attachments/manifest.json` inventories path, byte size, content type, update time, and MD5 metadata. Attachment bytes are not included in v1.0; recovery tooling must restore them from the separately retained Storage backup.
* `schemas/archive.schema.json` describes the root manifest and documents record encoding. Importers should validate the manifest, verify the SHA-256 checksum exposed on the export status, import users before relationship-bearing records, preserve IDs, and perform import in a staging project before production cutover.

The format supports business-transfer and compliance review, but data minimization means it is not an identity-provider backup. Firebase Authentication accounts, passwords, custom claims, deleted records, and attachment bytes require their own controlled backup or transfer process.

## Retention and operations

Archives expire seven days after request. A scheduled function deletes expired Storage objects and marks status `expired`; download links expire after five minutes and after one successful use. Firestore status and audit metadata remain for the organization's audit-retention policy and should be covered by an explicit Firestore TTL or records policy if eventual deletion is required. The Storage bucket should also have a defense-in-depth lifecycle rule for the `admin-exports/` prefix.

For disaster recovery, schedule and test independent Firestore, Authentication, and Storage backups: this on-demand export is a portable business archive, not the sole backup. Operators should monitor `failed` jobs, Cloud Function errors, and scheduled expiration, and compare every downloaded file's SHA-256 digest with the status document before custody transfer.
