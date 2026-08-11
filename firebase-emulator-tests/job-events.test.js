import { beforeAll, afterAll, beforeEach, describe, expect, it } from "vitest";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp } from "firebase/firestore";
import { readFileSync } from "node:fs";

let env;
const projectId = "job-tracker-audit-test";
beforeAll(async () => { env = await initializeTestEnvironment({ projectId, firestore: { rules: readFileSync("firestore.rules", "utf8") } }); });
afterAll(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => setDoc(doc(context.firestore(), "jobs/job-1"), {
    createdBy: "member", assignedTo: "member", participants: ["member"], status: "Pending"
  }));
});

describe("job event security", () => {
  it("allows members to append valid events", async () => {
    const db = env.authenticatedContext("member").firestore();
    await assertSucceeds(setDoc(doc(db, "jobs/job-1/events/event-1"), {
      actorID: "member", occurredAt: serverTimestamp(), type: "status_changed",
      before: { status: "Pending" }, after: { status: "Needs OH" }
    }));
  });
  it("prevents every client, including admins, from rewriting or deleting history", async () => {
    await env.withSecurityRulesDisabled(async context => setDoc(doc(context.firestore(), "jobs/job-1/events/event-1"), {
      actorID: "member", occurredAt: new Date(), type: "created", before: {}, after: { status: "Pending" }
    }));
    const admin = env.authenticatedContext("boss", { admin: true }).firestore();
    await assertFails(updateDoc(doc(admin, "jobs/job-1/events/event-1"), { type: "tampered" }));
    await assertFails(deleteDoc(doc(admin, "jobs/job-1/events/event-1")));
  });
  it("denies unrelated users access to events", async () => {
    const db = env.authenticatedContext("stranger").firestore();
    await assertFails(getDoc(doc(db, "jobs/job-1/events/event-1")));
  });
});
