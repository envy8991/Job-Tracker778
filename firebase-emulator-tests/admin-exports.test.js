import { beforeAll, afterAll, beforeEach, describe, it } from "vitest";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc } from "firebase/firestore";
import { readFileSync } from "node:fs";

let env;
beforeAll(async () => { env = await initializeTestEnvironment({ projectId: "job-tracker-export-test", firestore: { rules: readFileSync("firestore.rules", "utf8") } }); });
afterAll(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => setDoc(doc(context.firestore(), "adminExports/export-1"), { requestedBy: "admin-1", status: "running" }));
});

describe("administrator export status security", () => {
  it("lets only the requesting administrator read status", async () => {
    await assertSucceeds(getDoc(doc(env.authenticatedContext("admin-1", { admin: true }).firestore(), "adminExports/export-1")));
    await assertFails(getDoc(doc(env.authenticatedContext("admin-2", { admin: true }).firestore(), "adminExports/export-1")));
    await assertFails(getDoc(doc(env.authenticatedContext("technician-1").firestore(), "adminExports/export-1")));
  });
  it("prevents clients, including administrators, from creating export jobs directly", async () => {
    await assertFails(setDoc(doc(env.authenticatedContext("admin-1", { admin: true }).firestore(), "adminExports/client-created"), { requestedBy: "admin-1", status: "ready" }));
  });
});
