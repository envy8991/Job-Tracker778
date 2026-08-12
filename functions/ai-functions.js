"use strict";

const admin = require("firebase-admin");
const { HttpsError } = require("firebase-functions/v2/https");

const MAX_IMAGE_BYTES = 4 * 1024 * 1024;
const WINDOW_MS = 60_000;
const RATE_LIMIT = 8;

function requireRole(auth, allowedRoles) {
  if (!auth?.uid) throw new HttpsError("unauthenticated", "Sign in before using AI assistance.");
  const role = String(auth.token?.role || "").toLowerCase();
  if (auth.token?.admin !== true && !(auth.token?.supervisor === true && allowedRoles.includes("supervisor")) && !allowedRoles.includes(role)) {
    throw new HttpsError("permission-denied", "This AI operation is restricted to supervisors and administrators.");
  }
}

function decodeImage(data) {
  if (!data || typeof data.imageBase64 !== "string" || data.imageBase64.length > Math.ceil(MAX_IMAGE_BYTES * 4 / 3) + 8) {
    throw new HttpsError("invalid-argument", "A JPEG or PNG image under 4 MB is required.");
  }
  const image = Buffer.from(data.imageBase64, "base64");
  if (!image.length || image.length > MAX_IMAGE_BYTES) throw new HttpsError("invalid-argument", "A JPEG or PNG image under 4 MB is required.");
  const jpeg = image[0] === 0xff && image[1] === 0xd8 && image[image.length - 2] === 0xff && image[image.length - 1] === 0xd9;
  const png = image.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]));
  if (!jpeg && !png) throw new HttpsError("invalid-argument", "The uploaded data is not a valid JPEG or PNG image.");
  return { image, mimeType: png ? "image/png" : "image/jpeg" };
}

async function enforceRateLimit(db, uid, operation, now = Date.now()) {
  const ref = db.collection("aiRateLimits").doc(`${uid}_${operation}`);
  await db.runTransaction(async transaction => {
    const snapshot = await transaction.get(ref);
    const current = snapshot.data();
    const windowStart = Number(current?.windowStart || 0);
    const count = now - windowStart < WINDOW_MS ? Number(current?.count || 0) : 0;
    if (count >= RATE_LIMIT) throw new HttpsError("resource-exhausted", "Too many AI requests. Wait a minute and try again.");
    transaction.set(ref, { uid, operation, windowStart: count ? windowStart : now, count: count + 1, expiresAt: admin.firestore.Timestamp.fromMillis(now + WINDOW_MS * 2) });
  });
}

async function providerJSON(fetchImpl, url, options, provider) {
  let response;
  try { response = await fetchImpl(url, options); } catch (_) { throw new HttpsError("unavailable", `${provider} is temporarily unavailable.`); }
  if (!response.ok) throw new HttpsError("unavailable", `${provider} could not process the image.`);
  try { return await response.json(); } catch (_) { throw new HttpsError("internal", `${provider} returned an invalid response.`); }
}

function cleanString(value, max = 2000) {
  return typeof value === "string" && value.trim() ? value.trim().slice(0, max) : null;
}

async function resolveAssignees(db, items) {
  const users = await db.collection("users").select("firstName", "lastName").get();
  const normalized = value => String(value || "").toLocaleLowerCase().replace(/[^a-z0-9]/g, "");
  const names = users.docs.map(doc => ({ id: doc.id, full: normalized(`${doc.get("firstName") || ""} ${doc.get("lastName") || ""}`), first: normalized(doc.get("firstName")), last: normalized(doc.get("lastName")) }));
  return items.slice(0, 100).map(raw => {
    const assigneeName = cleanString(raw?.assigneeName, 200);
    const needle = normalized(assigneeName);
    const match = needle ? names.find(user => user.full === needle || user.first === needle || user.last === needle) : null;
    return { address: cleanString(raw?.address, 500) || "", jobNumber: cleanString(raw?.jobNumber, 100), assigneeName, assigneeId: match?.id || null, notes: cleanString(raw?.notes), rawText: cleanString(raw?.rawText, 2000) };
  }).filter(item => item.address || item.rawText);
}

function createHandlers({ db, fetchImpl = fetch, openAIKey }) {
  return {
    async parseJobSheet(request) {
      requireRole(request.auth, ["supervisor", "admin"]);
      const { image, mimeType } = decodeImage(request.data);
      await enforceRateLimit(db, request.auth.uid, "jobSheet");
      const body = { model: "gpt-4o-mini", response_format: { type: "json_object" }, messages: [
        { role: "system", content: "Extract job-sheet rows. Return only an object {\"items\":[{address,jobNumber,assigneeName,notes,rawText}]}. Use null for missing optional values." },
        { role: "user", content: [{ type: "text", text: "Read every job row. Do not invent values." }, { type: "image_url", image_url: { url: `data:${mimeType};base64,${image.toString("base64")}` } }] }
      ] };
      const json = await providerJSON(fetchImpl, "https://api.openai.com/v1/chat/completions", { method: "POST", headers: { Authorization: `Bearer ${openAIKey.value()}`, "Content-Type": "application/json" }, body: JSON.stringify(body) }, "Job-sheet parsing");
      const content = json?.choices?.[0]?.message?.content;
      let parsed;
      try { parsed = JSON.parse(content); } catch (_) { throw new HttpsError("internal", "The parser returned malformed job data."); }
      if (!Array.isArray(parsed?.items)) throw new HttpsError("internal", "The parser returned malformed job data.");
      return { items: await resolveAssignees(db, parsed.items) };
    }
  };
}

module.exports = { MAX_IMAGE_BYTES, RATE_LIMIT, WINDOW_MS, requireRole, decodeImage, enforceRateLimit, createHandlers };
