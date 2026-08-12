"use strict";
const admin = require("firebase-admin");
const archiver = require("archiver");
const crypto = require("crypto");
const { PassThrough, Readable } = require("stream");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");
const { createHandlers } = require("./ai-functions");
const { ARCHIVE_VERSION, COLLECTIONS, minimizeUser, csvRecord } = require("./export-helpers");
admin.initializeApp();
const db = admin.firestore();
const bucket = admin.storage().bucket();
const REGION = "us-central1", STEP_UP_SECONDS = 300, DOWNLOAD_SECONDS = 300, RETENTION_MS = 7 * 86400000;
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");
const aiHandlers = createHandlers({ db, openAIKey: OPENAI_API_KEY });

exports.parseJobSheet = onCall({ region: REGION, secrets: [OPENAI_API_KEY], timeoutSeconds: 60, memory: "512MiB", maxInstances: 20 }, aiHandlers.parseJobSheet);

function requireAdmin(auth) {
  if (!auth || auth.token.admin !== true) throw new HttpsError("permission-denied", "Company exports are restricted to administrators.");
  if (Date.now() / 1000 - Number(auth.token.auth_time || 0) > STEP_UP_SECONDS) throw new HttpsError("failed-precondition", "Recent sign-in required. Sign in again and retry within five minutes.");
}

async function* records(collection, format, counter) {
  let cursor, first = true;
  if (format === "json") yield "["; else yield "id,json\n";
  do {
    let query = db.collection(collection).orderBy(admin.firestore.FieldPath.documentId()).limit(500);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      const record = collection === "users" ? minimizeUser(doc.id, doc.data()) : { id: doc.id, ...doc.data() };
      if (format === "json") { yield `${first ? "" : ","}\n${JSON.stringify(record)}`; first = false; counter.value++; }
      else { const { id, ...data } = record; yield csvRecord(id, data); }
    }
    cursor = page.docs.at(-1);
    if (page.size < 500) cursor = undefined;
  } while (cursor);
  if (format === "json") yield "\n]\n";
}

async function appendGenerated(zip, generator, name) {
  const stream = Readable.from(generator);
  const done = new Promise((resolve, reject) => stream.on("end", resolve).on("error", reject));
  zip.append(stream, { name });
  await done;
}

exports.requestCompanyExport = onCall({ region: REGION }, async request => {
  requireAdmin(request.auth);
  const ref = db.collection("adminExports").doc();
  const now = admin.firestore.Timestamp.now();
  await ref.set({ archiveVersion: ARCHIVE_VERSION, status: "queued", progress: { completed: 0, total: COLLECTIONS.length + 1, phase: "Queued" }, recordCounts: {}, requestedBy: request.auth.uid, requestedAt: now, expiresAt: admin.firestore.Timestamp.fromMillis(now.toMillis() + RETENTION_MS) });
  await ref.collection("audit").add({ event: "requested", actorUid: request.auth.uid, at: now });
  return { exportId: ref.id };
});

exports.buildCompanyExport = onDocumentCreated({ document: "adminExports/{exportId}", region: REGION, timeoutSeconds: 540, memory: "1GiB" }, async event => {
  const ref = event.data.ref;
  if (event.data.data().status !== "queued") return;
  const path = `admin-exports/${ref.id}/job-tracker-export-v${ARCHIVE_VERSION}.zip`;
  const output = bucket.file(path).createWriteStream({ resumable: false, contentType: "application/zip", metadata: { cacheControl: "private, no-store" } });
  const hash = crypto.createHash("sha256"), tee = new PassThrough(), zip = archiver("zip", { zlib: { level: 6 } });
  tee.on("data", chunk => hash.update(chunk)); tee.pipe(output); zip.pipe(tee);
  const counts = {};
  try {
    await ref.update({ status: "running", startedAt: admin.firestore.FieldValue.serverTimestamp(), "progress.phase": "Reading records" });
    for (let i = 0; i < COLLECTIONS.length; i++) {
      const collection = COLLECTIONS[i], counter = { value: 0 };
      await appendGenerated(zip, records(collection, "json", counter), `data/${collection}.json`);
      await appendGenerated(zip, records(collection, "csv", counter), `data/${collection}.csv`);
      counts[collection] = counter.value;
      await ref.update({ recordCounts: counts, progress: { completed: i + 1, total: COLLECTIONS.length + 1, phase: `Archived ${collection}` } });
    }
    const [files] = await bucket.getFiles({ prefix: "attachments/" });
    const attachments = files.map(file => ({ path: file.name, size: Number(file.metadata.size || 0), contentType: file.metadata.contentType || null, md5Hash: file.metadata.md5Hash || null, updated: file.metadata.updated || null }));
    counts.attachments = attachments.length;
    zip.append(JSON.stringify(attachments, null, 2), { name: "attachments/manifest.json" });
    zip.append(JSON.stringify(require("./schemas/archive.schema.json"), null, 2), { name: "schemas/archive.schema.json" });
    zip.append(JSON.stringify({ archiveVersion: ARCHIVE_VERSION, createdAt: new Date().toISOString(), recordCounts: counts, personalDataPolicy: "Email, profile-picture URL, phone, tokens, and unknown user fields are omitted." }, null, 2), { name: "manifest.json" });
    await zip.finalize();
    await new Promise((resolve, reject) => output.on("finish", resolve).on("error", reject));
    await ref.update({ status: "ready", checksum: { algorithm: "SHA-256", value: hash.digest("hex") }, storagePath: path, recordCounts: counts, progress: { completed: COLLECTIONS.length + 1, total: COLLECTIONS.length + 1, phase: "Ready" }, completedAt: admin.firestore.FieldValue.serverTimestamp() });
  } catch (error) {
    logger.error("Company export failed", { exportId: ref.id, error }); zip.abort();
    await bucket.file(path).delete({ ignoreNotFound: true }).catch(() => {});
    await ref.update({ status: "failed", failure: { code: "archive_generation_failed", message: String(error.message || error).slice(0, 500) }, failedAt: admin.firestore.FieldValue.serverTimestamp() });
  }
});

exports.createCompanyExportDownload = onCall({ region: REGION }, async request => {
  requireAdmin(request.auth);
  const exportId = String(request.data?.exportId || ""), ref = db.collection("adminExports").doc(exportId), snapshot = await ref.get(), data = snapshot.data();
  if (!data || data.requestedBy !== request.auth.uid) throw new HttpsError("permission-denied", "This export belongs to a different administrator.");
  if (data.status !== "ready" || data.expiresAt.toMillis() <= Date.now()) throw new HttpsError("failed-precondition", "The export is not ready or has expired.");
  const token = crypto.randomBytes(32).toString("hex");
  await ref.collection("downloadTokens").doc(token).set({ actorUid: request.auth.uid, expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + DOWNLOAD_SECONDS), used: false });
  return { url: `https://${REGION}-${process.env.GCLOUD_PROJECT}.cloudfunctions.net/downloadCompanyExport?exportId=${encodeURIComponent(exportId)}&token=${token}`, expiresInSeconds: DOWNLOAD_SECONDS };
});

exports.downloadCompanyExport = onRequest({ region: REGION }, async (req, res) => {
  const exportRef = db.collection("adminExports").doc(String(req.query.exportId || ""));
  const tokenRef = exportRef.collection("downloadTokens").doc(String(req.query.token || ""));
  let exportData;
  try {
    await db.runTransaction(async tx => {
      const [exportSnap, tokenSnap] = await Promise.all([tx.get(exportRef), tx.get(tokenRef)]); exportData = exportSnap.data(); const token = tokenSnap.data();
      if (!exportData || exportData.status !== "ready" || exportData.expiresAt.toMillis() <= Date.now() || !token || token.used || token.expiresAt.toMillis() <= Date.now()) throw new Error("invalid");
      tx.update(tokenRef, { used: true, usedAt: admin.firestore.FieldValue.serverTimestamp() });
      tx.set(exportRef.collection("audit").doc(), { event: "downloaded", actorUid: token.actorUid, at: admin.firestore.FieldValue.serverTimestamp(), userAgent: String(req.get("user-agent") || "").slice(0, 200) });
    });
  } catch (_) { res.status(401).send("Invalid or expired download link."); return; }
  res.set({ "Content-Type": "application/zip", "Content-Disposition": `attachment; filename="job-tracker-export-v${ARCHIVE_VERSION}.zip"`, "Cache-Control": "private, no-store" });
  bucket.file(exportData.storagePath).createReadStream().on("error", () => res.destroy()).pipe(res);
});

exports.deleteExpiredCompanyExports = onSchedule({ schedule: "every 24 hours", region: REGION }, async () => {
  const expired = await db.collection("adminExports").where("expiresAt", "<=", admin.firestore.Timestamp.now()).limit(100).get();
  await Promise.all(expired.docs.map(async doc => { const data = doc.data(); if (data.storagePath) await bucket.file(data.storagePath).delete({ ignoreNotFound: true }); await doc.ref.update({ status: "expired", storagePath: admin.firestore.FieldValue.delete(), expiredAt: admin.firestore.FieldValue.serverTimestamp() }); }));
});
