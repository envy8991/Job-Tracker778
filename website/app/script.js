const config = window.JOB_TRACKER_FIREBASE_CONFIG || {};
const authBase = "https://identitytoolkit.googleapis.com/v1";
const tokenBase = "https://securetoken.googleapis.com/v1/token";
const firestoreBase = config.projectId ? `https://firestore.googleapis.com/v1/projects/${config.projectId}/databases/(default)/documents` : "";
const sessionKey = "job-tracker-web-firebase-session";
const statuses = ["Pending", "In Progress", "Needs Ariel", "Needs Underground", "Needs Nid", "Needs Can", "Done", "Talk to Rick"];
const weekDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
const shortDays = ["Mon", "Tue", "Wed", "Thu", "Fri"];
const timesheetDays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const shareTokenAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";

let currentUser = null;
let authSession = readSession();
let selectedDate = workdayForToday();
let appState = { jobs: [], users: [], timesheets: {}, yellowSheets: {}, partnerRequests: [] };
let currentMoreTab = "profile";

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

function sundayFor(date = new Date()) {
  const value = new Date(date);
  value.setDate(value.getDate() - value.getDay());
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

async function listDocs(collection) {
  const body = await apiFetch(`${firestoreBase}/${collection}`);
  return (body.documents || []).map(decodeDoc);
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
  const [jobs, users, timesheets, yellowSheets, partnerRequests] = await Promise.all([
    listDocs("jobs"),
    listDocs("users"),
    listDocs("timesheets"),
    listDocs("yellowSheets"),
    listDocs("partnerRequests"),
  ]);
  appState.users = users;
  appState.jobs = jobs.filter((job) => canSeeJob(job));
  appState.timesheets = Object.fromEntries(timesheets.filter((sheet) => sheet.userId === currentUser.id).map((sheet) => [sheet.weekStart, normalizeTimesheet(sheet)]));
  appState.yellowSheets = Object.fromEntries(yellowSheets.filter((sheet) => sheet.userId === currentUser.id).map((sheet) => [sheet.date || sheet.weekStart, normalizeYellowSheet(sheet)]));
  appState.partnerRequests = partnerRequests.filter((request) => request.fromUid === currentUser.id || request.toUid === currentUser.id);
  showSync();
}

function canSeeJob(job) {
  if (currentUser.isAdmin || currentUser.isSupervisor) return true;
  return [job.createdBy, job.assignedTo].includes(currentUser.id) || (job.participants || []).includes(currentUser.id);
}

function normalizeJob(job) {
  return {
    id: job.id || createId(),
    address: job.address,
    date: job.date,
    status: job.status,
    assignedTo: job.assignedTo || currentUser.id,
    createdBy: job.createdBy || currentUser.id,
    notes: job.notes || "",
    jobNumber: job.jobNumber || "",
    assignments: job.assignments || "",
    materialsUsed: job.materialsUsed || "",
    photos: job.photos || [],
    participants: Array.from(new Set([...(job.participants || []), currentUser.id, job.assignedTo || currentUser.id].filter(Boolean))),
    latitude: job.latitude || null,
    longitude: job.longitude || null,
    hours: Number(job.hours || 0),
    nidFootage: job.nidFootage || "",
    canFootage: job.canFootage || "",
  };
}

function normalizeTimesheet(sheet) {
  const sourceDays = sheet.days || [];
  const days = timesheetDays.map((name, index) => ({ notes: "", gibson: 0, cableSouth: 0, other: 0, ...(sourceDays[index] || {}), name }));
  return { id: sheet.id || sheet.weekStart, userId: currentUser.id, partnerId: sheet.partnerId || "", weekStart: sheet.weekStart, supervisor: sheet.supervisor || "", name1: sheet.name1 || `${currentUser.firstName} ${currentUser.lastName}`.trim(), name2: sheet.name2 || "", gibsonHours: sheet.gibsonHours || "0", cableSouthHours: sheet.cableSouthHours || "0", totalHours: sheet.totalHours || "0", gibsonHours2: sheet.gibsonHours2 || "0", cableSouthHours2: sheet.cableSouthHours2 || "0", totalHours2: sheet.totalHours2 || "0", dailyTotalHours: sheet.dailyTotalHours || {}, days, savedAt: sheet.savedAt || null, pdfURL: sheet.pdfURL || "" };
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
  appState = { jobs: [], users: [], timesheets: {}, yellowSheets: {}, partnerRequests: [] };
  showAuth();
  showToast("Signed out.");
}

function renderDate() {
  $("#sidebarDate").textContent = dateLabel(toInputDate(new Date()), { weekday: "long", month: "short", day: "numeric" });
}

function selectedJobs() {
  return appState.jobs.filter((job) => job.date === selectedDate);
}

function isOpen(job) { return job.status !== "Done"; }
function statusClass(status) { return status === "Done" ? "done" : status?.startsWith("Needs") || status === "Talk to Rick" ? "warning" : status === "In Progress" ? "danger" : ""; }

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
    button.addEventListener("click", () => { selectedDate = date; $("#scheduledDateInput").value = selectedDate; renderAll(); });
    picker.append(button);
  });
}

function renderDashboard() {
  const jobs = selectedJobs();
  const pending = jobs.filter(isOpen);
  const done = jobs.filter((job) => job.status === "Done");
  const completion = jobs.length === 0 ? 0 : Math.round((done.length / jobs.length) * 100);
  const nextJob = pending[0];
  const timesheet = getTimesheet(sundayFor(selectedDate));
  const dayIndex = new Date(`${selectedDate}T12:00:00`).getDay();
  const yellow = getYellowSheet(selectedDate);
  const partner = appState.partnerRequests.find((request) => request.status === "accepted");

  $("#dashboardGreeting").textContent = `Hi ${currentUser.firstName}, here is ${dateLabel(selectedDate)}. Updates save to Firebase and stay aligned with the native app collections.`;
  $("#sidebarSummary").textContent = `${jobs.length} jobs on selected day`;
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
  showToast("Job saved to Firebase.");
}

async function removeJob(id) {
  const job = appState.jobs.find((item) => item.id === id);
  if (!job) return;
  if (job.createdBy === currentUser.id || currentUser.isAdmin || currentUser.isSupervisor) await deleteDoc("jobs", id);
  else await setDoc("jobs", id, normalizeJob({ ...job, participants: (job.participants || []).filter((uid) => uid !== currentUser.id) }));
  await loadAppData();
  renderAll();
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

async function handleJobSubmit(event) {
  event.preventDefault();
  const formData = new FormData(event.currentTarget);
  const job = normalizeJob({
    id: createId(),
    jobNumber: formData.get("jobNumber").trim(),
    address: formData.get("address").trim(),
    date: formData.get("scheduledDate"),
    type: formData.get("type"),
    assignments: formData.get("type"),
    status: formData.get("status"),
    notes: formData.get("note").trim(),
  });
  await setDoc("jobs", job.id, job);
  selectedDate = job.date;
  event.currentTarget.reset();
  $("#scheduledDateInput").value = selectedDate;
  await loadAppData();
  renderAll();
  showToast("Job created in Firebase.");
}

function getTimesheet(weekStart) {
  if (!appState.timesheets[weekStart]) appState.timesheets[weekStart] = normalizeTimesheet({ id: `${currentUser.id}_${weekStart}`, userId: currentUser.id, weekStart });
  return appState.timesheets[weekStart];
}

function sumDay(day) { return Number(day?.gibson || 0) + Number(day?.cableSouth || 0) + Number(day?.other || 0); }

function workerRows(sheet) {
  const fallbackName = `${currentUser.firstName || ""} ${currentUser.lastName || ""}`.trim();
  const rows = [
    { name: sheet.name1 || fallbackName, gibson: sheet.gibsonHours || "", cs: sheet.cableSouthHours || "" },
    { name: sheet.name2 || "", gibson: sheet.gibsonHours2 || "", cs: sheet.cableSouthHours2 || "" },
  ];
  return rows.filter((row, index) => index === 0 || sheet.showSecondWorker || row.name || row.gibson || row.cs);
}

function renderWorkerRows(sheet) {
  const container = $("#timesheetWorkerRows");
  container.innerHTML = "";
  const rows = workerRows(sheet).slice(0, 2);
  rows.forEach((worker, index) => {
    const row = document.createElement("div");
    row.className = "worker-grid worker-row";
    const name = document.createElement("input");
    name.placeholder = "Name";
    name.value = worker.name;
    name.dataset.workerField = "name";
    name.dataset.workerIndex = String(index);
    const gibson = document.createElement("input");
    gibson.type = "number";
    gibson.min = "0";
    gibson.step = "0.25";
    gibson.placeholder = "0";
    gibson.value = worker.gibson;
    gibson.dataset.workerField = "gibson";
    gibson.dataset.workerIndex = String(index);
    const cs = document.createElement("input");
    cs.type = "number";
    cs.min = "0";
    cs.step = "0.25";
    cs.placeholder = "0";
    cs.value = worker.cs;
    cs.dataset.workerField = "cs";
    cs.dataset.workerIndex = String(index);
    const total = document.createElement("strong");
    total.textContent = (Number(worker.gibson || 0) + Number(worker.cs || 0)).toFixed(1);
    const remove = document.createElement("button");
    remove.className = "remove-name-button";
    remove.type = "button";
    remove.textContent = "−";
    remove.ariaLabel = "Remove name";
    remove.disabled = rows.length <= 1;
    remove.addEventListener("click", () => {
      captureTimesheet();
      if (index === 0) {
        sheet.name1 = sheet.name2;
        sheet.gibsonHours = sheet.gibsonHours2;
        sheet.cableSouthHours = sheet.cableSouthHours2;
      }
      sheet.name2 = "";
      sheet.gibsonHours2 = "";
      sheet.cableSouthHours2 = "";
      renderTimesheet();
    });
    [name, gibson, cs].forEach((input) => input.addEventListener("input", () => { total.textContent = (Number(gibson.value || 0) + Number(cs.value || 0)).toFixed(1); }));
    row.append(name, gibson, cs, total, remove);
    container.append(row);
  });
  $("#addTimesheetNameButton").disabled = rows.length >= 2;
}

function jobsForTimesheetDay(date) {
  return appState.jobs
    .filter((job) => job.date === date && (job.status || "").toLowerCase() !== "pending")
    .sort((a, b) => (a.jobNumber || "").localeCompare(b.jobNumber || "") || (a.address || "").localeCompare(b.address || ""));
}

function dayTotalValue(sheet, date, jobs, day) {
  if (sheet.dailyTotalHours?.[date] !== undefined) return String(sheet.dailyTotalHours[date]);
  const jobHours = jobs.reduce((sum, job) => sum + Number(job.hours || 0), 0);
  if (jobHours) return jobHours.toFixed(1);
  return sumDay(day).toFixed(1);
}

function renderTimesheet() {
  const weekStart = $("#timesheetWeekInput").value || sundayFor(selectedDate);
  const sheet = getTimesheet(weekStart);
  $("#timesheetWeekInput").value = weekStart;
  $("#timesheetWeekLabel").textContent = `Week of ${dateLabel(weekStart, { month: "long", day: "numeric", year: "numeric" })}`;
  $("#timesheetSupervisorInput").value = sheet.supervisor;
  renderWorkerRows(sheet);

  const list = $("#timesheetDailyCards");
  list.innerHTML = "";
  sheet.days.forEach((day, index) => {
    const date = addDays(weekStart, index);
    const jobs = jobsForTimesheetDay(date);
    const card = document.createElement("article");
    card.className = "day-timesheet-card";

    const title = document.createElement("h3");
    title.textContent = dateLabel(date, { weekday: "long", month: "short", day: "numeric" });
    card.append(title);

    if (jobs.length === 0) {
      const empty = document.createElement("p");
      empty.className = "day-empty";
      empty.textContent = "No jobs";
      card.append(empty);
    } else {
      const heading = document.createElement("div");
      heading.className = "job-summary-heading";
      heading.innerHTML = "<span>Job #</span><span>Hours</span><span>Address</span>";
      card.append(heading);
      jobs.forEach((job) => {
        const row = document.createElement("div");
        row.className = "job-summary-row";
        const number = document.createElement("span");
        number.textContent = job.jobNumber || "—";
        const hours = document.createElement("span");
        hours.textContent = Number(job.hours || 0).toFixed(1);
        const address = document.createElement("span");
        address.textContent = job.address || "No address";
        row.append(number, hours, address);
        card.append(row);
      });
    }

    const totalRow = document.createElement("label");
    totalRow.className = "daily-total-row";
    const totalLabel = document.createElement("span");
    totalLabel.textContent = "Total Hours:";
    const totalInput = document.createElement("input");
    totalInput.type = "number";
    totalInput.min = "0";
    totalInput.step = "0.25";
    totalInput.value = dayTotalValue(sheet, date, jobs, day);
    totalInput.dataset.timesheetField = "dailyTotal";
    totalInput.dataset.dayIndex = String(index);
    totalInput.dataset.date = date;
    totalInput.addEventListener("input", updateTimesheetTotalStrip);
    totalRow.append(totalLabel, totalInput);
    card.append(totalRow);
    list.append(card);
  });
  updateTimesheetTotalStrip();
}

function updateTimesheetTotalStrip() {
  const total = $$('[data-timesheet-field="dailyTotal"]').reduce((sum, input) => sum + Number(input.value || 0), 0);
  $("#timesheetTotal").textContent = `Total: ${total.toFixed(1)} hrs`;
}

function captureTimesheet() {
  const weekStart = $("#timesheetWeekInput").value;
  const sheet = getTimesheet(weekStart);
  sheet.supervisor = $("#timesheetSupervisorInput").value.trim();
  const workers = [{ name: "", gibson: "", cs: "" }, { name: "", gibson: "", cs: "" }];
  $$('[data-worker-field]').forEach((input) => {
    const worker = workers[Number(input.dataset.workerIndex)];
    if (worker) worker[input.dataset.workerField] = input.value.trim();
  });
  sheet.name1 = workers[0].name;
  sheet.gibsonHours = workers[0].gibson;
  sheet.cableSouthHours = workers[0].cs;
  sheet.totalHours = String(Number(workers[0].gibson || 0) + Number(workers[0].cs || 0));
  sheet.name2 = workers[1].name;
  sheet.gibsonHours2 = workers[1].gibson;
  sheet.cableSouthHours2 = workers[1].cs;
  sheet.totalHours2 = String(Number(workers[1].gibson || 0) + Number(workers[1].cs || 0));
  $$('[data-timesheet-field="dailyTotal"]').forEach((input) => {
    const index = Number(input.dataset.dayIndex);
    const value = Number(input.value || 0);
    sheet.days[index].other = value;
    sheet.days[index].gibson = 0;
    sheet.days[index].cableSouth = 0;
    sheet.dailyTotalHours[input.dataset.date] = String(value);
  });
  const total = $$('[data-timesheet-field="dailyTotal"]').reduce((sum, input) => sum + Number(input.value || 0), 0);
  sheet.weeklyTotalHours = String(total);
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
  if (!list) return;
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

function renderSearch() {
  const query = $("#jobSearchInput").value.trim().toLowerCase();
  const filtered = query ? appState.jobs.filter((job) => [job.jobNumber, job.address, job.type, job.status, job.notes, job.date, job.assignments, job.materialsUsed].join(" ").toLowerCase().includes(query)) : appState.jobs;
  renderJobList($("#searchResults"), filtered, true);
}

function hydrateUserForms() {
  $("#signedInRole").textContent = currentUser.position || "Technician";
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

function setMoreTab(tab) { currentMoreTab = tab; $$('[data-more-tab]').forEach((button) => button.classList.toggle("active", button.dataset.moreTab === tab)); $$('[data-more-panel]').forEach((panel) => panel.classList.toggle("active", panel.dataset.morePanel === tab)); }
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

function navigate(route) {
  $$('[data-view]').forEach((view) => view.classList.toggle("active", view.dataset.view === route));
  $$('[data-route]').forEach((button) => button.classList.toggle("active", button.dataset.route === route));
  if (route === "timesheets") renderTimesheet();
  if (route === "yellowSheets") renderYellowSheet();
  if (route === "search") renderSearch();
  if (route === "more") setMoreTab(currentMoreTab);
}

function renderAll() {
  if (!currentUser) return;
  renderDate();
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
  $$('[data-focus-job-form]').forEach((button) => button.addEventListener("click", () => $("#jobNumberInput").focus()));
  $("#jobForm").addEventListener("submit", (event) => handleJobSubmit(event).catch((error) => showToast(error.message)));
  $("#refreshJobsButton").addEventListener("click", () => loadAppData().then(renderAll).then(() => showToast("Jobs refreshed from Firebase.")));
  $("#shareDailySummaryButton").addEventListener("click", () => copyText(dailySummaryText(), `job-tracker-${selectedDate}.txt`));
  $("#downloadDailySummaryButton").addEventListener("click", () => downloadText(`job-tracker-${selectedDate}.txt`, dailySummaryText()));
  $("#timesheetWeekInput").addEventListener("change", renderTimesheet);
  $("#timesheetWeekLabel").addEventListener("click", () => {
    const input = $("#timesheetWeekInput");
    if (input.showPicker) input.showPicker();
    else input.focus();
  });
  $("#previousTimesheetWeekButton").addEventListener("click", () => { $("#timesheetWeekInput").value = addDays($("#timesheetWeekInput").value || sundayFor(selectedDate), -7); renderTimesheet(); });
  $("#nextTimesheetWeekButton").addEventListener("click", () => { $("#timesheetWeekInput").value = addDays($("#timesheetWeekInput").value || sundayFor(selectedDate), 7); renderTimesheet(); });
  $("#addTimesheetNameButton").addEventListener("click", () => { const sheet = captureTimesheet(); sheet.showSecondWorker = true; renderTimesheet(); });
  $("#saveTimesheetButton").addEventListener("click", () => handleSaveTimesheet().catch((error) => showToast(error.message)));
  $("#previewTimesheetButton").addEventListener("click", () => showToast("PDF preview is generated by the native app."));
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
  $("#scheduledDateInput").value = selectedDate;
  $("#timesheetWeekInput").value = sundayFor(selectedDate);
  $("#yellowDateInput").value = selectedDate;
}

async function bootstrap() {
  bindEvents();
  initializeInputs();
  if (!config?.apiKey || !config?.projectId) { setMessage("Firebase config is missing. Update website/app/config.js before signing in."); return; }
  if (!authSession?.refreshToken) return;
  try { await refreshTokenIfNeeded(); await loadCurrentUser(); await enterApp(); }
  catch (error) { clearSession(); showAuth(); setMessage(error.message); }
}

bootstrap();
