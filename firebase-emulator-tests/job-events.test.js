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

describe("job follow-up security", () => {
  const followUp = assignedUserID => ({
    reason: "Needs OH", assignedUserID, dueDate: new Date(), createdAt: new Date(),
    updatedAt: new Date(), completedAt: null, notificationPreference: "dueDate"
  });

  it("allows a participant to assign another participant", async () => {
    await env.withSecurityRulesDisabled(async context => updateDoc(doc(context.firestore(), "jobs/job-1"), {
      participants: ["member", "crew-2"]
    }));
    const db = env.authenticatedContext("member").firestore();
    await assertSucceeds(updateDoc(doc(db, "jobs/job-1"), { followUp: followUp("crew-2") }));
  });

  it("denies assignment to an unrelated user", async () => {
    const db = env.authenticatedContext("member").firestore();
    await assertFails(updateDoc(doc(db, "jobs/job-1"), { followUp: followUp("stranger") }));
  });

  it("allows a supervisor to manage a participant follow-up", async () => {
    await env.withSecurityRulesDisabled(async context => setDoc(doc(context.firestore(), "users/boss"), {
      isSupervisor: true
    }));
    const db = env.authenticatedContext("boss").firestore();
    await assertSucceeds(updateDoc(doc(db, "jobs/job-1"), { followUp: followUp("member") }));
  });
});
