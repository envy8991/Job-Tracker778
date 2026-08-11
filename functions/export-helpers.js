"use strict";
const crypto = require("crypto");
const ARCHIVE_VERSION = "1.0";
const COLLECTIONS = ["jobs", "timesheets", "yellowSheets", "users"];
const USER_FIELDS = new Set(["id", "firstName", "lastName", "position", "isAdmin", "isSupervisor"]);
function minimizeUser(id, data) { const result = { id }; for (const field of USER_FIELDS) if (field !== "id" && data[field] !== undefined) result[field] = data[field]; return result; }
function csvCell(value) { const text = value == null ? "" : String(value); return `"${text.replaceAll('"', '""')}"`; }
function csvRecord(id, data) { return `${csvCell(id)},${csvCell(JSON.stringify(data))}\n`; }
function sha256(value) { return crypto.createHash("sha256").update(value).digest("hex"); }
module.exports = { ARCHIVE_VERSION, COLLECTIONS, USER_FIELDS, minimizeUser, csvCell, csvRecord, sha256 };
