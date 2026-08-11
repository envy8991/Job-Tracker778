"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { HttpsError } = require("firebase-functions/v2/https");
const { requireRole, decodeImage, enforceRateLimit, createHandlers, RATE_LIMIT } = require("../ai-functions");

const jpeg = Buffer.from([0xff, 0xd8, 1, 2, 0xff, 0xd9]).toString("base64");
function rejectsCode(action, code) { return assert.rejects(action, error => error instanceof HttpsError && error.code === code); }

test("rejects unauthenticated callers", () => assert.throws(() => requireRole(null, ["supervisor"]), error => error.code === "unauthenticated"));
test("rejects unauthorized roles", () => assert.throws(() => requireRole({ uid: "u", token: { role: "employee" } }, ["supervisor"]), error => error.code === "permission-denied"));
test("accepts supervisor and admin claims", () => { requireRole({ uid: "s", token: { role: "supervisor" } }, ["supervisor"]); requireRole({ uid: "a", token: { admin: true } }, []); });
test("rejects malformed images", () => assert.throws(() => decodeImage({ imageBase64: Buffer.from("not image").toString("base64") }), error => error.code === "invalid-argument"));
test("rejects oversized requests before decoding", () => assert.throws(() => decodeImage({ imageBase64: "A".repeat(6_000_000) }), error => error.code === "invalid-argument"));

test("enforces per-user rate limits", async () => {
  let state;
  const db = { collection: () => ({ doc: () => ({}) }), runTransaction: async callback => callback({ get: async () => ({ data: () => state }), set: (_ref, value) => { state = value; } }) };
  for (let i = 0; i < RATE_LIMIT; i++) await enforceRateLimit(db, "user", "operation", 1000);
  await rejectsCode(() => enforceRateLimit(db, "user", "operation", 1000), "resource-exhausted");
});

test("maps provider failures to a narrow callable error", async () => {
  const db = { collection: () => ({ doc: () => ({}) }), runTransaction: async callback => callback({ get: async () => ({ data: () => null }), set: () => {} }) };
  const handlers = createHandlers({ db, fetchImpl: async () => ({ ok: false }), openAIKey: { value: () => "secret" }, geminiKey: { value: () => "secret" } });
  await rejectsCode(() => handlers.spliceAssist({ auth: { uid: "s", token: { role: "supervisor" } }, data: { imageBase64: jpeg, prompt: "p", systemPrompt: "s" } }), "unavailable");
});
