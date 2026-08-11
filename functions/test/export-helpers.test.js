"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const { minimizeUser, csvRecord } = require("../export-helpers");
test("user export omits contact and avatar data", () => {
  assert.deepEqual(minimizeUser("u1", { firstName: "Ada", lastName: "L", email: "private@example.com", profilePictureURL: "https://private", position: "OH", isAdmin: false, isSupervisor: true, phone: "555" }), { id: "u1", firstName: "Ada", lastName: "L", position: "OH", isAdmin: false, isSupervisor: true });
});
test("CSV safely quotes identifiers and JSON", () => {
  const row = csvRecord('a,"b', { note: 'x,"y' });
  assert.ok(row.startsWith('"a,""b","{'));
  assert.ok(row.endsWith('}"\n'));
  assert.equal(row.split("\n").length, 2);
});
