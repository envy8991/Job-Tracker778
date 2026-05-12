const config = window.JOB_TRACKER_FIREBASE_CONFIG || {};
const authBase = "https://identitytoolkit.googleapis.com/v1";
const tokenBase = "https://securetoken.googleapis.com/v1/token";
const firestoreBase = config.projectId ? `https://firestore.googleapis.com/v1/projects/${config.projectId}/databases/(default)/documents` : "";
const sessionKey = "job-tracker-web-firebase-session";
const appDataCachePrefix = "job-tracker-web-app-data";
const statuses = ["Pending", "Needs Aerial", "Needs Underground", "Needs Nid", "Needs Can", "Done", "Talk to Rick", "Custom"];
const weekDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
const shortDays = ["Mon", "Tue", "Wed", "Thu", "Fri"];
const shareTokenAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";

let currentUser = null;
let authSession = readSession();
let selectedDate = workdayForToday();
let appState = { jobs: [], searchJobs: [], users: [], timesheets: {}, yellowSheets: {}, partnerRequests: [] };
let currentMoreTab = "profile";
let createAddressCount = 1;

const authCopy = {
  login: { headline: "Welcome Back", lead: "Sign in with the credentials you use across the Job Tracker apps." },
  signup: { headline: "Create Your Account", lead: "Fill in your crew details below so we can personalize your dashboard." },
  reset: { headline: "Need a Reset?", lead: "Enter the email tied to your Job Tracker account and we'll send a reset link." },
};

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];

function createId() {
  return globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function randomToken(length = 24) {
  const bytes = new Uint8Array(length);
  if (globalThis.crypto?.getRandomValues) {
    globalThis.crypto.getRandomValues(bytes);
    return Array.from(bytes, (byte) => shareTokenAlphabet[byte % shareTokenAlphabet.length]).join("");
  }
  return Array.from({ length }, () => shareTokenAlphabet[Math.floor(Math.random() * shareTokenAlphabet.length)]).join("");
}

function readSession() {
  try { return JSON.parse(localStorage.getItem(sessionKey)); } catch { return null; }
}

function writeSession(session) {
  authSession = session;
  localStorage.setItem(sessionKey, JSON.stringify(session));
}

function clearSession() {
  authSession = null;
  localStorage.removeItem(sessionKey);
}

function toInputDate(date) {
  const value = new Date(date);
  value.setMinutes(value.getMinutes() - value.getTimezoneOffset());
  return value.toISOString().slice(0, 10);
}

function toTimestamp(value) {
  if (!value) return new Date().toISOString();
  if (typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value)) return `${value}T12:00:00.000Z`;
  return new Date(value).toISOString();
}

function dateLabel(dateString, options = { weekday: "short", month: "short", day: "numeric" }) {
  return new Intl.DateTimeFormat(undefined, options).format(new Date(`${dateString}T12:00:00`));
}

function mondayFor(date = new Date()) {
  const value = new Date(date);
  const day = value.getDay();
  value.setDate(value.getDate() - day + (day === 0 ? -6 : 1));
  return toInputDate(value);
}

function workdayForToday() {
  const today = new Date();
  const day = today.getDay();
  if (day === 0) return addDays(mondayFor(today), 4);
  if (day === 6) return mondayFor(today);
  return toInputDate(today);
}

function addDays(dateString, days) {
  const value = new Date(`${dateString}T12:00:00`);
  value.setDate(value.getDate() + days);
  return toInputDate(value);
}

function showToast(message) {
  const toast = $("#toast");
  toast.textContent = message;
  toast.classList.add("show");
  window.clearTimeout(showToast.timer);
  showToast.timer = window.setTimeout(() => toast.classList.remove("show"), 3000);
}

function setMessage(message) {
  $("#authMessage").textContent = message;
}

function showSync(message = "All server changes synced.") {
  $("#syncText").textContent = message;
}

function appDataCacheKey(uid = currentUser?.id || authSession?.uid) {
  return uid ? `${appDataCachePrefix}:${uid}` : appDataCachePrefix;
}

function cacheAppData() {
  if (!currentUser) return;
  try {
    localStorage.setItem(appDataCacheKey(), JSON.stringify({ ...appState, cachedAt: new Date().toISOString() }));
  } catch {
    // Storage can be unavailable in private browsing; Firebase remains the source of truth.
  }
}

function restoreCachedAppData() {
  if (!currentUser) return false;
  try {
    const cached = JSON.parse(localStorage.getItem(appDataCacheKey()) || "null");
    if (!cached) return false;
    appState = {
      jobs: cached.jobs || [],
      searchJobs: cached.searchJobs || cached.jobs || [],
      users: cached.users || [],
      timesheets: cached.timesheets || {},
      yellowSheets: cached.yellowSheets || {},
      partnerRequests: cached.partnerRequests || [],
    };
    showSync(`Showing saved app data from ${compactDateLabel(cached.cachedAt)} while Firebase refreshes…`);
    return true;
  } catch {
    return false;
  }
}

async function authRequest(path, payload) {
  if (!config.apiKey) throw new Error("Firebase config is missing. Update website/app/config.js before signing in.");
  const response = await fetch(`${authBase}/${path}?key=${config.apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const body = await response.json();
  if (!response.ok) throw new Error(body.error?.message?.replaceAll("_", " ") || "Authentication request failed");
  return body;
}

async function refreshTokenIfNeeded() {
  if (!authSession?.refreshToken) throw new Error("Not signed in");
  if (Date.now() < authSession.expiresAt - 60_000) return authSession.idToken;

  const response = await fetch(`${tokenBase}?key=${config.apiKey}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "refresh_token", refresh_token: authSession.refreshToken }),
  });
  const body = await response.json();
  if (!response.ok) throw new Error(body.error?.message || "Could not refresh session");
  writeSession({
    uid: body.user_id,
    email: authSession.email,
    idToken: body.id_token,
    refreshToken: body.refresh_token,
    expiresAt: Date.now() + Number(body.expires_in) * 1000,
  });
  return authSession.idToken;
}

async function apiFetch(url, options = {}) {
  const token = await refreshTokenIfNeeded();
  const response = await fetch(url, {
    ...options,
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${token}`, ...(options.headers || {}) },
  });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) throw new Error(body?.error?.message || "Server request failed");
  return body;
}

function encodeValue(value, key = "") {
  if (value === null || value === undefined) return { nullValue: null };
  if (["date", "weekStart", "createdAt", "savedAt", "expiresAt"].includes(key)) return { timestampValue: toTimestamp(value) };
  if (Array.isArray(value)) return { arrayValue: { values: value.map((item) => encodeValue(item)) } };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") return Number.isInteger(value) ? { integerValue: value } : { doubleValue: value };
  if (typeof value === "object") return { mapValue: { fields: encodeFields(value) } };
  return { stringValue: String(value) };
}

function encodeFields(data) {
  return Object.fromEntries(Object.entries(data).filter(([, value]) => value !== undefined).map(([key, value]) => [key, encodeValue(value, key)]));
}

function decodeValue(value) {
  if (!value) return null;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return Number(value.doubleValue);
  if ("booleanValue" in value) return value.booleanValue;
  if ("timestampValue" in value) return value.timestampValue.slice(0, 10);
  if ("arrayValue" in value) return (value.arrayValue.values || []).map(decodeValue);
  if ("mapValue" in value) return decodeFields(value.mapValue.fields || {});
  return null;
}

function decodeFields(fields = {}) {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decodeValue(value)]));
}

function decodeDoc(doc) {
  const id = doc.name.split("/").pop();
  return { id, ...decodeFields(doc.fields || {}) };
}

async function getDoc(collection, id) {
  try { return decodeDoc(await apiFetch(`${firestoreBase}/${collection}/${id}`)); }
  catch (error) { if (error.message.toLowerCase().includes("not found")) return null; throw error; }
}

async function listDocs(collection, options = {}) {
  const docs = [];
  let pageToken = "";
  const pageSize = options.pageSize || 300;
  do {
    const params = new URLSearchParams({ pageSize: String(pageSize) });
    if (pageToken) params.set("pageToken", pageToken);
    const body = await apiFetch(`${firestoreBase}/${collection}?${params}`);
    docs.push(...(body.documents || []).map(decodeDoc));
    pageToken = body.nextPageToken || "";
  } while (pageToken);
  return docs;
}

async function safeListDocs(collection, options = {}) {
  try {
    return await listDocs(collection, options);
  } catch (error) {
    console.warn(`Could not load ${collection}:`, error.message);
    return [];
  }
}

async function queryDocs(collection, where) {
  const body = {
    structuredQuery: {
      from: [{ collectionId: collection }],
      where,
    },
  };
  const rows = await apiFetch(`${firestoreBase}:runQuery`, { method: "POST", body: JSON.stringify(body) });
  return (rows || []).map((row) => row.document).filter(Boolean).map(decodeDoc);
}

function fieldEquals(fieldPath, value) {
  return { fieldFilter: { field: { fieldPath }, op: "EQUAL", value: encodeValue(value) } };
}

function fieldArrayContains(fieldPath, value) {
  return { fieldFilter: { field: { fieldPath }, op: "ARRAY_CONTAINS", value: encodeValue(value) } };
}

function mergeDocs(...sources) {
  const docs = new Map();
  sources.flat().filter(Boolean).forEach((doc) => docs.set(doc.id, { ...(docs.get(doc.id) || {}), ...doc }));
  return [...docs.values()];
}

async function loadVisibleJobs() {
  try {
    return await listDocs("jobs");
  } catch (error) {
    console.warn("Could not list every job; falling back to iOS participant/owner queries:", error.message);
    const [participantJobs, createdJobs, assignedJobs] = await Promise.all([
      safeQueryDocs("jobs", fieldArrayContains("participants", currentUser.id)),
      safeQueryDocs("jobs", fieldEquals("createdBy", currentUser.id)),
      safeQueryDocs("jobs", fieldEquals("assignedTo", currentUser.id)),
    ]);
    return mergeDocs(participantJobs, createdJobs, assignedJobs);
  }
}

async function safeQueryDocs(collection, where) {
  try {
    return await queryDocs(collection, where);
  } catch (error) {
    console.warn(`Could not query ${collection}:`, error.message);
    return [];
  }
}

async function setDoc(collection, id, data) {
  const body = { fields: encodeFields(data) };
  await apiFetch(`${firestoreBase}/${collection}/${id}`, { method: "PATCH", body: JSON.stringify(body) });
}

async function deleteDoc(collection, id) {
  await apiFetch(`${firestoreBase}/${collection}/${id}`, { method: "DELETE" });
}

async function signIn(email, password) {
  const body = await authRequest("accounts:signInWithPassword", { email, password, returnSecureToken: true });
  writeSession({ uid: body.localId, email: body.email, idToken: body.idToken, refreshToken: body.refreshToken, expiresAt: Date.now() + Number(body.expiresIn) * 1000 });
  await loadCurrentUser();
}

async function signUp(payload) {
  const body = await authRequest("accounts:signUp", { email: payload.email, password: payload.password, returnSecureToken: true });
  writeSession({ uid: body.localId, email: body.email, idToken: body.idToken, refreshToken: body.refreshToken, expiresAt: Date.now() + Number(body.expiresIn) * 1000 });
  currentUser = { id: body.localId, firstName: payload.firstName, lastName: payload.lastName, email: body.email, position: payload.position, isAdmin: false, isSupervisor: payload.position === "Supervisor", phone: "", yard: "" };
  await setDoc("users", currentUser.id, currentUser);
}

async function loadCurrentUser() {
  let user = await getDoc("users", authSession.uid);
  if (!user) {
    const [firstName] = (authSession.email || "Technician").split("@");
    user = { id: authSession.uid, firstName, lastName: "", email: authSession.email, position: "Technician", isAdmin: false, isSupervisor: false, phone: "", yard: "" };
    await setDoc("users", user.id, user);
  }
  currentUser = user;
}

async function loadAppData() {
  showSync("Syncing with Firebase…");
  const [jobs, searchIndex, users, timesheets, yellowSheets, partnerRequests] = await Promise.all([
    loadVisibleJobs(),
    safeListDocs("jobsSearch"),
    listDocs("users"),
    listDocs("timesheets"),
    listDocs("yellowSheets"),
    listDocs("partnerRequests"),
  ]);
  appState.users = users;
  appState.jobs = jobs.filter((job) => canSeeJob(job));
  appState.searchJobs = mergeSearchEntries(jobs, searchIndex);
  appState.timesheets = Object.fromEntries(timesheets.filter((sheet) => sheet.userId === currentUser.id).map((sheet) => [sheet.weekStart, normalizeTimesheet(sheet)]));
  appState.yellowSheets = Object.fromEntries(yellowSheets.filter((sheet) => sheet.userId === currentUser.id).map((sheet) => [sheet.date || sheet.weekStart, normalizeYellowSheet(sheet)]));
  appState.partnerRequests = partnerRequests.filter((request) => request.fromUid === currentUser.id || request.toUid === currentUser.id);
  cacheAppData();
  showSync();
}

function canSeeJob(job) {
  if (currentUser.isAdmin || currentUser.isSupervisor) return true;
  return [job.createdBy, job.assignedTo].includes(currentUser.id) || (job.participants || []).includes(currentUser.id);
}

function mergeSearchEntries(...sources) {
  const entries = new Map();
  sources.flat().filter(Boolean).forEach((job) => {
    const normalized = normalizeSearchEntry(job);
    if (!normalized.id) return;
    entries.set(normalized.id, { ...(entries.get(normalized.id) || {}), ...normalized });
  });
  return [...entries.values()];
}

function normalizeSearchEntry(job = {}) {
  return {
    id: job.id || "",
    address: job.address || "",
    date: job.date || selectedDate,
    status: job.status || "Pending",
    assignedTo: job.assignedTo || "",
    createdBy: job.createdBy || "",
    notes: job.notes || "",
    jobNumber: job.jobNumber || "",
    assignments: job.assignments || job.assignment || "",
    materialsUsed: job.materialsUsed || "",
    participants: job.participants || [],
    nidFootage: job.nidFootage || "",
    canFootage: job.canFootage || "",
  };
}

function normalizeJob(job) {
  return {
    id: job.id || createId(),
    address: job.address,
    date: job.date,
    status: job.status,
    assignedTo: job.assignedTo || (job.status === "Pending" ? "" : currentUser.id),
    createdBy: job.createdBy || currentUser.id,
    notes: job.notes || "",
    jobNumber: job.jobNumber || "",
    assignments: job.assignments || "",
    materialsUsed: job.materialsUsed || "",
    photos: job.photos || [],
    participants: Array.from(new Set([...(job.participants || []), currentUser.id, job.assignedTo].filter(Boolean))),
    latitude: job.latitude || null,
    longitude: job.longitude || null,
    hours: Number(job.hours || 0),
    nidFootage: job.nidFootage || "",
    canFootage: job.canFootage || "",
  };
}

function normalizeTimesheet(sheet) {
  const days = sheet.days || weekDays.map((name) => ({ name, notes: "", gibson: 0, cableSouth: 0, other: 0 }));
  return { id: sheet.id || sheet.weekStart, userId: currentUser.id, partnerId: sheet.partnerId || "", weekStart: sheet.weekStart, supervisor: sheet.supervisor || "", name1: sheet.name1 || `${currentUser.firstName} ${currentUser.lastName}`.trim(), name2: sheet.name2 || "", gibsonHours: sheet.gibsonHours || "0", cableSouthHours: sheet.cableSouthHours || "0", totalHours: sheet.totalHours || "0", dailyTotalHours: sheet.dailyTotalHours || {}, days, savedAt: sheet.savedAt || null, pdfURL: sheet.pdfURL || "" };
}

function normalizeYellowSheet(sheet) {
  return { id: sheet.id || sheet.date, userId: currentUser.id, partnerId: sheet.partnerId || "", date: sheet.date || sheet.weekStart || selectedDate, weekStart: sheet.weekStart || mondayFor(sheet.date || selectedDate), totalJobs: Number(sheet.totalJobs || 0), jobId: sheet.jobId || "", checks: sheet.checks || {}, materials: sheet.materials || "", notes: sheet.notes || "", signature: sheet.signature || "", savedAt: sheet.savedAt || null, pdfURL: sheet.pdfURL || "" };
}

function showApp() {
  $("#authScreen").classList.add("hidden");
  $("#appShell").classList.remove("hidden");
}

function showAuth() {
  $("#appShell").classList.add("hidden");
  $("#authScreen").classList.remove("hidden");
}

async function enterApp() {
  showApp();
  hydrateUserForms();
  if (restoreCachedAppData()) renderAll();
  await loadAppData();
  renderAll();
}

function setAuthMode(mode) {
  const selectedMode = authCopy[mode] ? mode : "login";
  $("#loginForm").classList.toggle("hidden", selectedMode !== "login");
  $("#signupForm").classList.toggle("hidden", selectedMode !== "signup");
  $("#resetForm").classList.toggle("hidden", selectedMode !== "reset");
  $$('[data-auth-mode]').forEach((button) => {
    const isActive = button.dataset.authMode === selectedMode && button.classList.contains("segment");
    button.classList.toggle("active", isActive);
    if (button.classList.contains("segment")) button.setAttribute("aria-selected", String(isActive));
  });
  $("#authHeadline").textContent = authCopy[selectedMode].headline;
  $("#authLead").textContent = authCopy[selectedMode].lead;
  if (selectedMode === "reset" && !$("#resetEmail").value) $("#resetEmail").value = $("#loginEmail").value.trim();
  setMessage("");
}

function emailError(email) {
  if (!email) return "Email is required.";
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? "" : "Enter a valid email address.";
}

function requiredError(value, label) {
  return value.trim() ? "" : `Please enter your ${label}.`;
}

function passwordError(password, minimum = 8) {
  if (!password) return "Password is required.";
  return password.length >= minimum ? "" : `Password must be at least ${minimum} characters.`;
}

function requireValid(errors) {
  const message = errors.find(Boolean);
  if (message) {
    setMessage(message);
    return false;
  }
  return true;
}

async function handleLogin(event) {
  event.preventDefault();
  const email = $("#loginEmail").value.trim();
  const password = $("#loginPassword").value;
  if (!requireValid([emailError(email), passwordError(password, 1)])) return;
  try {
    setMessage("Signing in…");
    await signIn(email, password);
    setMessage("");
    await enterApp();
    showToast(`Welcome back, ${currentUser.firstName}.`);
  } catch (error) { setMessage(error.message); }
}

async function handleSignup(event) {
  event.preventDefault();
  const payload = { firstName: $("#signupFirstName").value.trim(), lastName: $("#signupLastName").value.trim(), email: $("#signupEmail").value.trim(), position: $("#signupPosition").value, password: $("#signupPassword").value };
  if (!requireValid([requiredError(payload.firstName, "first name"), requiredError(payload.lastName, "last name"), emailError(payload.email), passwordError(payload.password)])) return;
  try {
    setMessage("Creating account…");
    await signUp(payload);
    setMessage("");
    await enterApp();
    showToast("Account created and synced.");
  } catch (error) { setMessage(error.message); }
}

async function resetPassword(event) {
  event?.preventDefault();
  const email = $("#resetEmail").value.trim() || $("#loginEmail").value.trim();
  if (!requireValid([emailError(email)])) return;
  try {
    setMessage("Sending reset link…");
    await authRequest("accounts:sendOobCode", { requestType: "PASSWORD_RESET", email });
    setMessage(`Check ${email} for reset instructions.`);
  } catch (error) { setMessage(error.message); }
}

function logout() {
  clearSession();
  currentUser = null;
  appState = { jobs: [], searchJobs: [], users: [], timesheets: {}, yellowSheets: {}, partnerRequests: [] };
  showAuth();
  showToast("Signed out.");
}

function selectedJobs() {
  return appState.jobs.filter((job) => job.date === selectedDate);
}

function isOpen(job) { return String(job.status || "Pending").toLowerCase() === "pending"; }
function statusClass(status) {
  const normalized = String(status || "").toLowerCase();
  if (normalized === "done") return "done";
  if (normalized.startsWith("needs") || normalized === "talk to rick" || normalized === "custom") return "warning";
  if (normalized === "pending") return "pending";
  return "";
}

function renderWeekdayPicker() {
  const monday = mondayFor(selectedDate);
  const picker = $("#weekdayPicker");
  picker.innerHTML = "";
  weekDays.forEach((_, index) => {
    const date = addDays(monday, index);
    const jobs = appState.jobs.filter((job) => job.date === date);
    const button = document.createElement("button");
    button.className = `day-button ${date === selectedDate ? "active" : ""}`.trim();
    button.type = "button";
    button.innerHTML = `<strong>${shortDays[index]}</strong><span>${dateLabel(date, { month: "short", day: "numeric" })}</span><small>${jobs.length} jobs</small>`;
    button.addEventListener("click", () => { selectedDate = date; updateCreateDateInput(selectedDate); renderAll(); });
    picker.append(button);
  });
}

function renderDashboard() {
  const jobs = selectedJobs();
  const pending = jobs.filter(isOpen);
  const done = jobs.filter((job) => !isOpen(job));
  const completion = jobs.length === 0 ? 0 : Math.round((done.length / jobs.length) * 100);
  const nextJob = pending[0];
  const timesheet = getTimesheet(mondayFor(selectedDate));
  const dayIndex = Math.max(0, Math.min(4, new Date(`${selectedDate}T12:00:00`).getDay() - 1));
  const yellow = getYellowSheet(selectedDate);
  const partner = appState.partnerRequests.find((request) => request.status === "accepted");

  $("#dashboardGreeting").textContent = `Hi ${currentUser.firstName}, here is ${dateLabel(selectedDate)}. Updates save to Firebase and stay aligned with the native app collections.`;
  $("#totalCount").textContent = jobs.length;
  $("#pendingCount").textContent = pending.length;
  $("#doneCount").textContent = done.length;
  $("#completionRate").textContent = `${completion}%`;
  $("#completionBar").style.width = `${completion}%`;
  $("#nextJobAddress").textContent = nextJob ? nextJob.address : "No next job";
  $("#nextJobHint").textContent = nextJob ? `${nextJob.jobNumber || "No job #"} • ${nextJob.status}` : "Create or assign jobs to get routing hints.";
  $("#dashboardHours").textContent = `${sumDay(timesheet.days[dayIndex]).toFixed(1)} hrs`;
  $("#yellowStatus").textContent = yellow.signature ? "Signed" : yellowHasContent(yellow) ? "In progress" : "Not started";
  $("#partnerStatus").textContent = partner ? partnerName(partner) : "No partner";
  renderJobList($("#pendingJobList"), pending, true);
  renderJobList($("#completedJobList"), done, true);
}

function renderJobList(container, jobs, withActions = false) {
  container.innerHTML = "";
  if (jobs.length === 0) { container.innerHTML = `<p class="empty-state">No jobs match this section.</p>`; return; }
  jobs.forEach((job) => container.append(jobCard(job, withActions)));
}

function jobCard(job, withActions = false) {
  const item = document.createElement("article");
  item.className = "job-item";
  const details = document.createElement("div");
  const title = document.createElement("h3");
  const meta = document.createElement("div");
  title.textContent = `${job.jobNumber || "No job #"} · ${job.address}`;
  meta.className = "job-meta";
  [job.type || job.assignments || "Job", dateLabel(job.date), job.status, job.notes || "No note added"].forEach((value, index) => {
    const span = document.createElement("span");
    span.textContent = value;
    span.className = index === 2 ? `badge ${statusClass(job.status)}`.trim() : index < 3 ? "badge" : "";
    meta.append(span);
  });
  details.append(title, meta);
  item.append(details);
  if (withActions) {
    const actions = document.createElement("div");
    actions.className = "job-actions";
    const select = document.createElement("select");
    statuses.forEach((status) => {
      const option = document.createElement("option");
      option.value = status; option.textContent = status; option.selected = status === job.status; select.append(option);
    });
    select.addEventListener("change", () => updateJob(job.id, { status: select.value }));
    const share = document.createElement("button");
    share.className = "button secondary"; share.type = "button"; share.textContent = "Share"; share.addEventListener("click", () => shareJob(job.id));
    const remove = document.createElement("button");
    remove.className = "button danger"; remove.type = "button"; remove.textContent = "Remove"; remove.addEventListener("click", () => removeJob(job.id));
    actions.append(select, share, remove); item.append(actions);
  }
  return item;
}

async function updateJob(id, patch) {
  const job = appState.jobs.find((item) => item.id === id);
  if (!job) return;
  const updated = normalizeJob({ ...job, ...patch });
  await setDoc("jobs", id, updated);
  await loadAppData();
  renderAll();
  cacheAppData();
  showToast("Job saved to Firebase.");
}

async function removeJob(id) {
  const job = appState.jobs.find((item) => item.id === id);
  if (!job) return;
  if (job.createdBy === currentUser.id || currentUser.isAdmin || currentUser.isSupervisor) await deleteDoc("jobs", id);
  else await setDoc("jobs", id, normalizeJob({ ...job, participants: (job.participants || []).filter((uid) => uid !== currentUser.id) }));
  await loadAppData();
  renderAll();
  cacheAppData();
  showToast("Job removed.");
}

async function shareJob(id) {
  const job = appState.jobs.find((item) => item.id === id);
  if (!job) return;
  try {
    const token = randomToken();
    const senderName = `${currentUser.firstName || ""} ${currentUser.lastName || ""}`.trim() || currentUser.email || currentUser.id;
    const senderIsCan = (currentUser.position || "").toLowerCase() === "can";
    await setDoc("sharedJobs", token, {
      v: 2,
      createdAt: new Date().toISOString(),
      expiresAt: addDays(toInputDate(new Date()), 7),
      fromUserId: currentUser.id,
      fromUserName: senderName,
      address: job.address,
      date: job.date,
      status: job.status,
      jobNumber: job.jobNumber || "",
      assignment: senderIsCan ? job.assignments || "" : "",
      senderIsCan,
    });
    await copyText(`jobtracker://importJob?token=${token}`, `shared-job-${job.jobNumber || token}.txt`);
    showToast("Share link copied. It expires in 7 days.");
  } catch (error) { showToast(error.message); }
}

function sanitizeAssignmentValue(raw = "", { allowTrailingDot = false } = {}) {
  let value = String(raw).trim().replace(/[^0-9.]/g, "");
  while (value.includes("..")) value = value.replaceAll("..", ".");
  while (value.startsWith(".")) value = value.slice(1);
  if (!allowTrailingDot) value = value.replace(/\.+$/g, "");
  return value.slice(0, 32);
}

function isValidAssignmentValue(value) {
  return !value || /^[0-9]+(\.[0-9]+)*$/.test(value);
}

async function saveJobsFromCreateValues({ addresses, date, status, jobNumber, assignments = "", materialsUsed = "", notes = "" }) {
  const trimmedAddresses = addresses.map((address) => address.trim()).filter(Boolean);
  const trimmedJobNumber = jobNumber.trim();
  const sanitizedAssignments = sanitizeAssignmentValue(assignments);

  if (!trimmedJobNumber) throw new Error("Please enter a Job Number before saving.");
  if (trimmedAddresses.length === 0) throw new Error("Please enter at least one address before saving.");
  if (!date) throw new Error("Please select a date before saving.");
  if (!isValidAssignmentValue(sanitizedAssignments)) throw new Error("Assignments must use digits separated by single dots.");

  const jobs = trimmedAddresses.map((address) => normalizeJob({
    id: createId(),
    jobNumber: trimmedJobNumber,
    address,
    date,
    status,
    assignedTo: status === "Pending" ? "" : currentUser.id,
    createdBy: currentUser.id,
    assignments: sanitizedAssignments,
    materialsUsed: materialsUsed.trim(),
    notes: notes.trim(),
  }));

  await Promise.all(jobs.map((job) => setDoc("jobs", job.id, job)));
  selectedDate = date;
  await loadAppData();
  renderAll();
  showToast(jobs.length > 1 ? `${jobs.length} jobs created in Firebase.` : "Job created in Firebase.");
}

async function handleJobSubmit(event) {
  event.preventDefault();
  const formData = new FormData(event.currentTarget);
  await saveJobsFromCreateValues({
    addresses: formData.getAll("address"),
    date: formData.get("scheduledDate"),
    status: formData.get("status"),
    jobNumber: formData.get("jobNumber"),
    assignments: formData.get("assignments"),
    materialsUsed: formData.get("materialsUsed"),
    notes: formData.get("notes"),
  });
}

async function saveJobFromCreatePanel(event) {
  await handleJobSubmit(event);
  navigate("dashboard");
  closeCreateJobPanel();
  resetCreateJobPanel();
}

function updateCreateDateChip() {
  const dateInput = $("#createDateInput");
  const chip = $("#createDateChip");
  if (!dateInput || !chip) return;
  chip.textContent = dateInput.value ? dateLabel(dateInput.value, { weekday: "short", month: "short", day: "numeric" }) : "Select a date";
}

function updateCreateDateInput(date = selectedDate) {
  const input = $("#createDateInput");
  if (!input) return;
  input.value = date;
  updateCreateDateChip();
}

function updateCreateStatusPicker() {
  $$("#createJobForm .status-picker .segment").forEach((label) => {
    const input = label.querySelector('input[type="radio"]');
    label.classList.toggle("active", Boolean(input?.checked));
  });
}

function openCreateJobPanel() {
  updateCreateDateInput(selectedDate);
  updateCreateStatusPicker();
  $("#createJobModal").classList.remove("hidden");
  document.body.classList.add("modal-open");
  window.setTimeout(() => $("#createAddressInput0")?.focus(), 0);
}

function closeCreateJobPanel() {
  $("#createJobModal").classList.add("hidden");
  document.body.classList.remove("modal-open");
}

function resetCreateJobPanel() {
  const form = $("#createJobForm");
  form.reset();
  createAddressCount = 1;
  $("#createAddressList").innerHTML = `<label class="sr-only" for="createAddressInput0">Address</label><input id="createAddressInput0" name="address" placeholder="Enter address" autocomplete="street-address" required />`;
  updateCreateDateInput(selectedDate);
  updateCreateStatusPicker();
}

function addCreateAddressField() {
  const id = `createAddressInput${createAddressCount}`;
  const label = document.createElement("label");
  label.className = "sr-only";
  label.htmlFor = id;
  label.textContent = `Address ${createAddressCount + 1}`;
  const input = document.createElement("input");
  input.id = id;
  input.name = "address";
  input.placeholder = "Enter address";
  input.autocomplete = "street-address";
  $("#createAddressList").append(label, input);
  createAddressCount += 1;
  input.focus();
}

function getTimesheet(weekStart) {
  if (!appState.timesheets[weekStart]) appState.timesheets[weekStart] = normalizeTimesheet({ id: `${currentUser.id}_${weekStart}`, userId: currentUser.id, weekStart });
  return appState.timesheets[weekStart];
}

function sumDay(day) { return Number(day?.gibson || 0) + Number(day?.cableSouth || 0) + Number(day?.other || 0); }

function renderTimesheet() {
  const weekStart = $("#timesheetWeekInput").value || mondayFor(selectedDate);
  const sheet = getTimesheet(weekStart);
  $("#timesheetWeekInput").value = weekStart;
  $("#timesheetSupervisorInput").value = sheet.supervisor;
  $("#timesheetPartnerInput").value = sheet.name2;
  const tbody = $("#timesheetRows");
  tbody.innerHTML = "";
  sheet.days.forEach((day, index) => {
    const row = document.createElement("tr");
    row.innerHTML = `<td><strong>${day.name}</strong><br><small>${dateLabel(addDays(weekStart, index), { month: "short", day: "numeric" })}</small></td><td><textarea rows="2" data-timesheet-field="notes" data-day-index="${index}">${day.notes || ""}</textarea></td><td><input type="number" min="0" step="0.25" value="${day.gibson || 0}" data-timesheet-field="gibson" data-day-index="${index}"></td><td><input type="number" min="0" step="0.25" value="${day.cableSouth || 0}" data-timesheet-field="cableSouth" data-day-index="${index}"></td><td><input type="number" min="0" step="0.25" value="${day.other || 0}" data-timesheet-field="other" data-day-index="${index}"></td><td><strong>${sumDay(day).toFixed(2)}</strong></td>`;
    tbody.append(row);
  });
  const total = sheet.days.reduce((sum, day) => sum + sumDay(day), 0);
  $("#timesheetTotal").textContent = `${total.toFixed(2)} total hours`;
  $("#timesheetSavedState").textContent = sheet.savedAt ? `Saved ${new Date(sheet.savedAt).toLocaleString()}` : "Not saved yet";
  renderPastTimesheets();
}

function captureTimesheet() {
  const weekStart = $("#timesheetWeekInput").value;
  const sheet = getTimesheet(weekStart);
  sheet.supervisor = $("#timesheetSupervisorInput").value.trim();
  sheet.name1 = `${currentUser.firstName} ${currentUser.lastName}`.trim();
  sheet.name2 = $("#timesheetPartnerInput").value.trim();
  $$("[data-timesheet-field]").forEach((input) => { const day = sheet.days[Number(input.dataset.dayIndex)]; const field = input.dataset.timesheetField; day[field] = field === "notes" ? input.value : Number(input.value || 0); });
  const total = sheet.days.reduce((sum, day) => sum + sumDay(day), 0);
  sheet.gibsonHours = String(sheet.days.reduce((sum, day) => sum + Number(day.gibson || 0), 0));
  sheet.cableSouthHours = String(sheet.days.reduce((sum, day) => sum + Number(day.cableSouth || 0), 0));
  sheet.totalHours = String(total);
  sheet.dailyTotalHours = Object.fromEntries(sheet.days.map((day, index) => [addDays(weekStart, index), String(sumDay(day))]));
  return sheet;
}

async function handleSaveTimesheet() {
  const sheet = captureTimesheet();
  sheet.savedAt = new Date().toISOString();
  await setDoc("timesheets", sheet.id, sheet);
  await loadAppData();
  renderAll();
  showToast("Timesheet saved to Firebase.");
}

function renderPastTimesheets() {
  const sheets = Object.values(appState.timesheets).filter((sheet) => sheet.savedAt);
  const list = $("#pastTimesheetsList");
  list.innerHTML = "";
  if (sheets.length === 0) { list.innerHTML = `<p class="empty-state">Saved weekly timesheets will appear here.</p>`; return; }
  sheets.sort((a, b) => b.weekStart.localeCompare(a.weekStart)).forEach((sheet) => { const item = document.createElement("article"); item.className = "compact-item"; item.innerHTML = `<div><h3>Week of ${dateLabel(sheet.weekStart)}</h3><span>${Number(sheet.totalHours || 0).toFixed(2)} hours • Supervisor: ${sheet.supervisor || "Not set"}</span></div>`; list.append(item); });
}

function getYellowSheet(date) {
  if (!appState.yellowSheets[date]) appState.yellowSheets[date] = normalizeYellowSheet({ id: `${currentUser.id}_${date}`, userId: currentUser.id, date });
  return appState.yellowSheets[date];
}

function yellowHasContent(sheet) { return Object.values(sheet.checks || {}).some(Boolean) || sheet.materials || sheet.notes || sheet.signature; }

function renderYellowSheet() {
  const date = $("#yellowDateInput").value || selectedDate;
  const sheet = getYellowSheet(date);
  $("#yellowDateInput").value = date;
  const select = $("#yellowJobSelect");
  select.innerHTML = `<option value="">General day sheet</option>`;
  appState.jobs.filter((job) => job.date === date).forEach((job) => { const option = document.createElement("option"); option.value = job.id; option.textContent = `${job.jobNumber || "No job #"} · ${job.address}`; option.selected = job.id === sheet.jobId; select.append(option); });
  $$('[data-yellow-check]').forEach((input) => { input.checked = Boolean(sheet.checks?.[input.dataset.yellowCheck]); });
  $("#yellowMaterialsInput").value = sheet.materials;
  $("#yellowNotesInput").value = sheet.notes;
  $("#yellowSignatureInput").value = sheet.signature;
  renderPastYellowSheets();
}

function captureYellowSheet() {
  const date = $("#yellowDateInput").value;
  const sheet = getYellowSheet(date);
  sheet.jobId = $("#yellowJobSelect").value;
  sheet.materials = $("#yellowMaterialsInput").value.trim();
  sheet.notes = $("#yellowNotesInput").value.trim();
  sheet.signature = $("#yellowSignatureInput").value.trim();
  sheet.weekStart = mondayFor(date);
  sheet.totalJobs = appState.jobs.filter((job) => job.date === date).length;
  sheet.checks = {};
  $$('[data-yellow-check]').forEach((input) => { sheet.checks[input.dataset.yellowCheck] = input.checked; });
  return sheet;
}

async function handleSaveYellowSheet() {
  const sheet = captureYellowSheet();
  sheet.savedAt = new Date().toISOString();
  await setDoc("yellowSheets", sheet.id, sheet);
  await loadAppData();
  renderAll();
  showToast("Yellow sheet saved to Firebase.");
}

function renderPastYellowSheets() {
  const sheets = Object.values(appState.yellowSheets).filter((sheet) => sheet.savedAt);
  const list = $("#pastYellowSheetsList");
  list.innerHTML = "";
  if (sheets.length === 0) { list.innerHTML = `<p class="empty-state">Saved yellow sheets will appear here.</p>`; return; }
  sheets.sort((a, b) => b.date.localeCompare(a.date)).forEach((sheet) => { const checks = Object.values(sheet.checks || {}).filter(Boolean).length; const item = document.createElement("article"); item.className = "compact-item"; item.innerHTML = `<div><h3>${dateLabel(sheet.date)}</h3><span>${checks}/4 checks complete • Signature: ${sheet.signature || "Missing"}</span></div>`; list.append(item); });
}

function downloadText(filename, text) { const blob = new Blob([text], { type: "text/plain" }); const link = document.createElement("a"); link.href = URL.createObjectURL(blob); link.download = filename; link.click(); URL.revokeObjectURL(link.href); }
async function copyText(text, fallbackName) { try { await navigator.clipboard.writeText(text); showToast("Summary copied to clipboard."); } catch { downloadText(fallbackName, text); showToast("Clipboard unavailable, downloaded a text summary instead."); } }
function dailySummaryText() { const lines = [`Job Tracker Daily Summary`, `Date: ${dateLabel(selectedDate)}`, `Technician: ${currentUser.firstName} ${currentUser.lastName}`, ""]; selectedJobs().forEach((job) => lines.push(`${job.jobNumber || "No job #"} • ${job.status} • ${job.address} • ${job.notes || "No note"}`)); if (selectedJobs().length === 0) lines.push("No jobs scheduled."); return lines.join("\n"); }
function timesheetText() { const sheet = captureTimesheet(); return [`Job Tracker Timesheet`, `Week: ${sheet.weekStart}`, `Technician: ${sheet.name1}`, `Supervisor: ${sheet.supervisor || "Not set"}`, `Partner: ${sheet.name2 || "None"}`, "", ...sheet.days.map((day) => `${day.name}: ${sumDay(day).toFixed(2)} hrs - ${day.notes || "No notes"}`), `Total: ${sheet.totalHours} hrs`].join("\n"); }
function yellowSheetText() { const sheet = captureYellowSheet(); const checks = Object.entries(sheet.checks).map(([key, value]) => `${key}: ${value ? "yes" : "no"}`).join("\n"); return [`Job Tracker Yellow Sheet`, `Date: ${sheet.date}`, `Technician: ${currentUser.firstName} ${currentUser.lastName}`, `Signature: ${sheet.signature || "Missing"}`, "", checks, "", `Materials: ${sheet.materials || "None"}`, `Notes: ${sheet.notes || "None"}`].join("\n"); }

function displayUserName(user) {
  if (!user) return "";
  return `${user.firstName || ""} ${user.lastName || ""}`.trim() || user.email || user.id || "";
}

function userById(uid) {
  return appState.users.find((user) => user.id === uid);
}

function searchTokens(query) {
  return query.trim().toLowerCase().split(/\s+/).filter(Boolean);
}

function compactDateLabel(value) {
  if (!value) return "No date";
  const date = new Date(/^\d{4}-\d{2}-\d{2}$/.test(value) ? `${value}T12:00:00` : value);
  if (Number.isNaN(date.valueOf())) return value;
  return new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric", year: "numeric" }).format(date);
}

function splitSearchAddress(address = "") {
  const parts = address.split(",").map((part) => part.trim()).filter(Boolean);
  return { primary: parts[0] || address || "No address", secondary: parts.slice(1).join(", ") };
}

function creatorLine(job) {
  const creator = userById(job.createdBy);
  if (creator) {
    const role = (creator.position || creator.normalizedPosition || "").trim();
    return role ? `Added by ${displayUserName(creator)} · ${role}` : `Added by ${displayUserName(creator)}`;
  }
  const crew = userById(job.assignedTo);
  return crew ? `Crew: ${displayUserName(crew)}` : "Crew not assigned";
}

function searchSnippet(job, tokens) {
  const candidates = [
    ["Notes", job.notes],
    ["Materials", job.materialsUsed],
    ["Assignments", job.assignments],
    ["NID Footage", job.nidFootage],
    ["CAN Footage", job.canFootage],
  ];
  for (const [title, rawValue] of candidates) {
    const value = String(rawValue || "").trim();
    if (!value) continue;
    if (!tokens.length || tokens.some((token) => value.toLowerCase().includes(token))) return { title, value };
  }
  return null;
}

function searchHaystack(job) {
  const creator = userById(job.createdBy);
  const creatorName = displayUserName(creator);
  return [
    job.address,
    job.jobNumber,
    job.status,
    job.notes,
    job.assignments,
    job.materialsUsed,
    job.nidFootage,
    job.canFootage,
    compactDateLabel(job.date),
    job.date,
    creatorName,
    creator?.position,
    creator?.normalizedPosition,
  ].filter(Boolean).join(" ").toLowerCase();
}

function compareSearchJobs(a, b) {
  const dateOrder = String(b.date || "").localeCompare(String(a.date || ""));
  if (dateOrder !== 0) return dateOrder;
  return String(a.address || "").localeCompare(String(b.address || ""), undefined, { sensitivity: "base" });
}

function buildQuickFilters() {
  const countBy = (valueFor) => {
    const counts = new Map();
    searchSourceJobs().forEach((job) => {
      const value = String(valueFor(job) || "").trim();
      if (!value) return;
      const key = value.toLowerCase();
      const existing = counts.get(key) || { display: value, count: 0 };
      existing.count += 1;
      counts.set(key, existing);
    });
    return [...counts.values()].sort((a, b) => b.count - a.count || a.display.localeCompare(b.display, undefined, { sensitivity: "base" }));
  };
  const statuses = countBy((job) => job.status).slice(0, 4).map((item) => ({ ...item, kind: "status" }));
  const creators = countBy((job) => displayUserName(userById(job.createdBy))).slice(0, 4).map((item) => ({ ...item, kind: "creator" }));
  return [...statuses, ...creators].slice(0, 8);
}

function renderQuickFilters() {
  const container = $("#searchQuickFilters");
  if (!container) return;
  const filters = buildQuickFilters();
  container.innerHTML = "";
  if (!filters.length) return;
  const heading = document.createElement("p");
  heading.className = "quick-filter-title";
  heading.textContent = "Quick filters";
  const row = document.createElement("div");
  row.className = "quick-filter-row";
  filters.forEach((filter) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "quick-filter-pill";
    const label = document.createElement("span");
    label.textContent = `${filter.kind === "creator" ? "👥" : "🏷️"} ${filter.display}`;
    const count = document.createElement("small");
    count.textContent = `${filter.count} job${filter.count === 1 ? "" : "s"}`;
    button.append(label, count);
    button.addEventListener("click", () => {
      $("#jobSearchInput").value = filter.display;
      renderSearch();
    });
    row.append(button);
  });
  container.append(heading, row);
}

function renderSearchResultCard(job, tokens) {
  const item = document.createElement("article");
  item.className = "job-item search-result-card";
  const { primary, secondary } = splitSearchAddress(job.address);
  const snippet = searchSnippet(job, tokens);

  const header = document.createElement("div");
  header.className = "search-result-header";

  const addressBlock = document.createElement("div");
  addressBlock.className = "search-result-address";
  const title = document.createElement("h3");
  title.textContent = primary;
  addressBlock.append(title);
  if (secondary) {
    const line = document.createElement("p");
    line.textContent = secondary;
    addressBlock.append(line);
  }

  const jobNumber = document.createElement("span");
  jobNumber.className = "badge job-number-badge";
  jobNumber.textContent = job.jobNumber ? `#${job.jobNumber}` : "No job #";
  header.append(addressBlock, jobNumber);

  const meta = document.createElement("div");
  meta.className = "job-meta search-result-meta";
  const status = document.createElement("span");
  status.className = `badge ${statusClass(job.status)}`.trim();
  status.textContent = job.status || "No status";
  const date = document.createElement("span");
  date.textContent = compactDateLabel(job.date);
  const creator = document.createElement("span");
  creator.className = "search-result-creator";
  creator.textContent = creatorLine(job);
  meta.append(status, date, creator);

  item.append(header, meta);
  if (snippet) {
    const snippetBlock = document.createElement("div");
    snippetBlock.className = "search-result-snippet";
    const snippetTitle = document.createElement("span");
    snippetTitle.textContent = snippet.title.toUpperCase();
    const snippetValue = document.createElement("p");
    snippetValue.textContent = snippet.value;
    snippetBlock.append(snippetTitle, snippetValue);
    item.append(snippetBlock);
  }
  if ([job.createdBy, job.assignedTo].includes(currentUser.id) || (job.participants || []).includes(currentUser.id)) {
    const owned = document.createElement("span");
    owned.className = "search-owned-label";
    owned.textContent = "✓ In your job list";
    item.append(owned);
  }
  return item;
}

function searchSourceJobs() {
  return appState.searchJobs?.length ? appState.searchJobs : appState.jobs;
}

function renderSearch() {
  const input = $("#jobSearchInput");
  const results = $("#searchResults");
  const query = input.value.trim();
  const tokens = searchTokens(query);
  const sortedJobs = [...searchSourceJobs()].sort(compareSearchJobs);
  const matches = tokens.length ? sortedJobs.filter((job) => {
    const haystack = searchHaystack(job);
    return tokens.every((token) => haystack.includes(token));
  }) : sortedJobs.slice(0, 12);

  renderQuickFilters();
  results.innerHTML = "";

  if (!tokens.length) {
    const idle = document.createElement("article");
    idle.className = "search-idle-card";
    idle.innerHTML = `<div class="search-idle-icon">⌕</div><h3>Search the entire company</h3><p>Type part of an address, job number, status, or teammate to explore every job in Job Tracker.</p>`;
    results.append(idle);
    if (!matches.length) return;
    const heading = document.createElement("div");
    heading.className = "search-list-heading";
    heading.innerHTML = `<h3>Recent activity</h3><p>Jump back into the latest jobs from across your team.</p>`;
    results.append(heading);
  } else if (!matches.length) {
    const empty = document.createElement("article");
    empty.className = "empty-state search-empty-state";
    empty.innerHTML = `<strong>No jobs found for “${query.replace(/[&<>"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;" }[char]))}”</strong><span>Try fewer keywords or search by street, city, job number, status, or teammate name.</span>`;
    results.append(empty);
    return;
  } else {
    const heading = document.createElement("div");
    heading.className = "search-list-heading";
    heading.innerHTML = `<h3>Results</h3><p>${matches.length} match${matches.length === 1 ? "" : "es"}</p>`;
    results.append(heading);
  }

  matches.forEach((job) => results.append(renderSearchResultCard(job, tokens)));
}

function hydrateUserForms() {
  $("#profileFirstName").value = currentUser.firstName || "";
  $("#profileLastName").value = currentUser.lastName || "";
  $("#profilePosition").value = currentUser.position || "Aerial";
  $("#profileEmail").value = currentUser.email || authSession.email || "";
  $("#profilePhone").value = currentUser.phone || "";
  $("#profileYard").value = currentUser.yard || "";
  const settings = currentUser.webSettings || {};
  $("#smartRoutingInput").checked = settings.smartRouting !== false;
  $("#arrivalAlertsInput").checked = Boolean(settings.arrivalAlerts);
  $("#routingOptimizeInput").value = settings.optimizeBy || "Distance";
  $("#addressProviderInput").value = settings.addressProvider || "Apple Maps";
  $("#themeInput").value = settings.theme || "Dark";
  applyTheme(settings.theme || "Dark");
}

async function saveProfile() {
  currentUser = { ...currentUser, firstName: $("#profileFirstName").value.trim(), lastName: $("#profileLastName").value.trim(), position: $("#profilePosition").value, isSupervisor: $("#profilePosition").value === "Supervisor", phone: $("#profilePhone").value.trim(), yard: $("#profileYard").value.trim() };
  await setDoc("users", currentUser.id, currentUser);
  await loadAppData();
  hydrateUserForms();
  renderAll();
  showToast("Profile saved to Firebase.");
}

function applyTheme(theme) { document.body.classList.toggle("high-contrast", theme === "High contrast"); document.body.classList.toggle("ocean", theme === "Ocean"); }

async function saveSettings() {
  currentUser.webSettings = { smartRouting: $("#smartRoutingInput").checked, arrivalAlerts: $("#arrivalAlertsInput").checked, optimizeBy: $("#routingOptimizeInput").value, addressProvider: $("#addressProviderInput").value, theme: $("#themeInput").value };
  await setDoc("users", currentUser.id, currentUser);
  applyTheme(currentUser.webSettings.theme);
  showToast("Settings saved to Firebase.");
}

function setMoreTab(tab) {
  currentMoreTab = tab;
  $$('[data-more-tab]').forEach((button) => {
    const isActive = button.dataset.moreTab === tab;
    button.classList.toggle("active", isActive);
    button.toggleAttribute("aria-current", isActive);
  });
  $$('[data-more-panel]').forEach((panel) => panel.classList.toggle("active", panel.dataset.morePanel === tab));
}
function userName(uid) { const user = appState.users.find((item) => item.id === uid); return user ? `${user.firstName || ""} ${user.lastName || ""}`.trim() || user.email : uid; }
function partnerName(request) { return request.fromUid === currentUser.id ? userName(request.toUid) : userName(request.fromUid); }

function renderPartnerUsers() {
  const select = $("#partnerUserInput");
  select.innerHTML = "";
  appState.users.filter((user) => user.id !== currentUser.id).forEach((user) => { const option = document.createElement("option"); option.value = user.id; option.textContent = `${user.firstName || ""} ${user.lastName || ""}`.trim() || user.email; select.append(option); });
  if (!select.children.length) select.innerHTML = `<option value="">No other users found</option>`;
}

function renderPartnerRequests() {
  renderPartnerUsers();
  const list = $("#partnerRequestsList");
  list.innerHTML = "";
  if (appState.partnerRequests.length === 0) { list.innerHTML = `<p class="empty-state">No incoming or outgoing partner requests.</p>`; return; }
  appState.partnerRequests.sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt))).forEach((request) => {
    const item = document.createElement("article");
    item.className = "compact-item";
    const inbound = request.toUid === currentUser.id;
    const details = document.createElement("div");
    details.innerHTML = `<h3>${inbound ? "From" : "To"} ${partnerName(request)}</h3><span>${request.need || "Partner request"} • ${request.location || "No location"} • ${request.when || "Any time"} • ${request.status || "pending"}</span>`;
    const actions = document.createElement("div");
    actions.className = "job-actions";
    if (inbound && request.status === "pending") {
      const accept = document.createElement("button"); accept.className = "button primary"; accept.type = "button"; accept.textContent = "Accept"; accept.addEventListener("click", () => updatePartnerRequest(request.id, "accepted"));
      const decline = document.createElement("button"); decline.className = "button danger"; decline.type = "button"; decline.textContent = "Decline"; decline.addEventListener("click", () => updatePartnerRequest(request.id, "declined"));
      actions.append(accept, decline);
    }
    item.append(details, actions);
    list.append(item);
  });
}

async function handlePartnerSubmit(event) {
  event.preventDefault();
  const toUid = $("#partnerUserInput").value;
  if (!toUid) { showToast("No partner user is available to request."); return; }
  const request = { id: createId(), fromUid: currentUser.id, toUid, status: "pending", createdAt: new Date().toISOString(), need: $("#partnerNeedInput").value, location: $("#partnerLocationInput").value.trim(), when: $("#partnerWhenInput").value, note: $("#partnerNoteInput").value.trim() };
  await setDoc("partnerRequests", request.id, request);
  event.currentTarget.reset();
  await loadAppData();
  renderAll();
  showToast("Partner request sent.");
}

async function updatePartnerRequest(id, status) {
  const request = appState.partnerRequests.find((item) => item.id === id);
  await setDoc("partnerRequests", id, { ...request, status });
  if (status === "accepted") await setDoc("partnerships", [request.fromUid, request.toUid].sort().join("_"), { members: [request.fromUid, request.toUid], createdAt: new Date().toISOString() });
  await loadAppData();
  renderAll();
  showToast(`Request ${status}.`);
}

function normalizeRoute(route) {
  const aliases = { yellowSheet: "yellowSheets", jobSearch: "search" };
  const requestedRoute = aliases[route] || route;
  return $(`[data-view="${requestedRoute}"]`) ? requestedRoute : "dashboard";
}

function navigate(route, options = {}) {
  const nextRoute = normalizeRoute(route);
  $$('[data-view]').forEach((view) => {
    const isActive = view.dataset.view === nextRoute;
    view.classList.toggle("active", isActive);
    view.hidden = !isActive;
  });
  $$('[data-route]').forEach((button) => {
    const isActive = button.dataset.route === nextRoute;
    button.classList.toggle("active", isActive);
    button.toggleAttribute("aria-current", isActive);
  });
  if (currentUser && nextRoute === "timesheets") renderTimesheet();
  if (currentUser && nextRoute === "yellowSheets") renderYellowSheet();
  if (currentUser && nextRoute === "search") renderSearch();
  if (nextRoute === "more") setMoreTab(currentMoreTab);
  if (!options.skipHash) history.replaceState(null, "", `#${nextRoute}`);
  if (!options.skipScroll) $("#appShell")?.scrollIntoView({ block: "start" });
}

function renderAll() {
  if (!currentUser) return;
  renderWeekdayPicker();
  renderDashboard();
  renderTimesheet();
  renderYellowSheet();
  renderSearch();
  renderPartnerRequests();
}

function bindEvents() {
  $$('[data-auth-mode]').forEach((button) => button.addEventListener("click", () => setAuthMode(button.dataset.authMode)));
  $("#loginForm").addEventListener("submit", handleLogin);
  $("#signupForm").addEventListener("submit", handleSignup);
  $("#resetForm").addEventListener("submit", resetPassword);
  $("#signOutButton").addEventListener("click", logout);
  $$('[data-route]').forEach((button) => button.addEventListener("click", (event) => { event.preventDefault(); navigate(button.dataset.route); }));
  $$('[data-open-create-job]').forEach((button) => button.addEventListener("click", openCreateJobPanel));
  $("#closeCreateJobButton").addEventListener("click", closeCreateJobPanel);
  $("#addCreateAddressButton").addEventListener("click", addCreateAddressField);
  $("#createJobForm").addEventListener("submit", (event) => saveJobFromCreatePanel(event).catch((error) => showToast(error.message)));
  $("#createDateInput").addEventListener("change", updateCreateDateChip);
  $("#createAssignmentsInput").addEventListener("input", (event) => { event.target.value = sanitizeAssignmentValue(event.target.value, { allowTrailingDot: true }); });
  $$("#createJobForm .status-picker input").forEach((input) => input.addEventListener("change", updateCreateStatusPicker));
  $("#createJobModal").addEventListener("click", (event) => { if (event.target.id === "createJobModal") closeCreateJobPanel(); });
  document.addEventListener("keydown", (event) => { if (event.key === "Escape" && !$("#createJobModal").classList.contains("hidden")) closeCreateJobPanel(); });
  $("#refreshJobsButton").addEventListener("click", () => loadAppData().then(renderAll).then(() => showToast("Jobs refreshed from Firebase.")));
  $("#shareDailySummaryButton").addEventListener("click", () => copyText(dailySummaryText(), `job-tracker-${selectedDate}.txt`));
  $("#downloadDailySummaryButton").addEventListener("click", () => downloadText(`job-tracker-${selectedDate}.txt`, dailySummaryText()));
  $("#timesheetWeekInput").addEventListener("change", renderTimesheet);
  $("#saveTimesheetButton").addEventListener("click", () => handleSaveTimesheet().catch((error) => showToast(error.message)));
  $("#exportTimesheetButton").addEventListener("click", () => downloadText(`timesheet-${$("#timesheetWeekInput").value}.txt`, timesheetText()));
  $("#yellowDateInput").addEventListener("change", renderYellowSheet);
  $("#saveYellowSheetButton").addEventListener("click", () => handleSaveYellowSheet().catch((error) => showToast(error.message)));
  $("#exportYellowSheetButton").addEventListener("click", () => downloadText(`yellow-sheet-${$("#yellowDateInput").value}.txt`, yellowSheetText()));
  $("#jobSearchInput").addEventListener("input", renderSearch);
  $$('[data-more-tab]').forEach((button) => button.addEventListener("click", () => setMoreTab(button.dataset.moreTab)));
  $("#saveProfileButton").addEventListener("click", () => saveProfile().catch((error) => showToast(error.message)));
  $("#saveSettingsButton").addEventListener("click", () => saveSettings().catch((error) => showToast(error.message)));
  $("#partnerForm").addEventListener("submit", (event) => handlePartnerSubmit(event).catch((error) => showToast(error.message)));
}

function initializeInputs() {
  updateCreateDateInput(selectedDate);
  updateCreateStatusPicker();
  $("#timesheetWeekInput").value = mondayFor(selectedDate);
  $("#yellowDateInput").value = selectedDate;
}

async function bootstrap() {
  bindEvents();
  initializeInputs();
  navigate((window.location.hash || "#dashboard").slice(1), { skipHash: true, skipScroll: true });
  window.addEventListener("hashchange", () => navigate((window.location.hash || "#dashboard").slice(1), { skipHash: true }));
  if (!config?.apiKey || !config?.projectId) { setMessage("Firebase config is missing. Update website/app/config.js before signing in."); return; }
  if (!authSession?.refreshToken) return;
  try { await refreshTokenIfNeeded(); await loadCurrentUser(); await enterApp(); }
  catch (error) { clearSession(); showAuth(); setMessage(error.message); }
}

bootstrap();
