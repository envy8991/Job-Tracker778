const store = {
  users: "job-tracker-web-users",
  session: "job-tracker-web-session",
  jobs: "job-tracker-web-jobs",
  timesheets: "job-tracker-web-timesheets",
  yellowSheets: "job-tracker-web-yellow-sheets",
  partnerRequests: "job-tracker-web-partner-requests",
  settings: "job-tracker-web-settings",
};

const statuses = ["Pending", "In Progress", "Needs Ariel", "Needs Underground", "Needs Nid", "Needs Can", "Done", "Talk to Rick"];
const weekDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
const shortDays = ["Mon", "Tue", "Wed", "Thu", "Fri"];
let selectedDate = toInputDate(new Date());
let currentUser = null;
let currentMoreTab = "profile";

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];

function createId() {
  return globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function readJson(key, fallback) {
  try {
    const value = localStorage.getItem(key);
    return value ? JSON.parse(value) : fallback;
  } catch {
    return fallback;
  }
}

function writeJson(key, value) {
  localStorage.setItem(key, JSON.stringify(value));
}

function toInputDate(date) {
  const value = new Date(date);
  value.setMinutes(value.getMinutes() - value.getTimezoneOffset());
  return value.toISOString().slice(0, 10);
}

function dateLabel(dateString, options = { weekday: "short", month: "short", day: "numeric" }) {
  return new Intl.DateTimeFormat(undefined, options).format(new Date(`${dateString}T12:00:00`));
}

function workdayForToday() {
  const today = new Date();
  const day = today.getDay();
  if (day === 0) return addDays(mondayFor(today), 4);
  if (day === 6) return mondayFor(today);
  return toInputDate(today);
}

function mondayFor(date = new Date()) {
  const value = new Date(date);
  const day = value.getDay();
  const diff = value.getDate() - day + (day === 0 ? -6 : 1);
  value.setDate(diff);
  return toInputDate(value);
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
  showToast.timer = window.setTimeout(() => toast.classList.remove("show"), 2600);
}

function showSync(message = "All local changes saved.") {
  $("#syncText").textContent = message;
  window.setTimeout(() => {
    if ($("#syncText")) $("#syncText").textContent = "All local changes saved.";
  }, 1400);
}

function seedUsers() {
  const users = readJson(store.users, []);
  if (users.length > 0) return users;
  const seeded = [
    {
      id: createId(),
      firstName: "Quinton",
      lastName: "Thompson",
      position: "Supervisor",
      email: "demo@jobtracker.local",
      password: "password123",
      phone: "(555) 010-7780",
      yard: "North Yard",
    },
  ];
  writeJson(store.users, seeded);
  return seeded;
}

function seedJobs(force = false) {
  const existing = readJson(store.jobs, []);
  if (!force && existing.length > 0) return existing;
  const today = workdayForToday();
  const monday = mondayFor(today);
  const jobs = [
    { id: createId(), jobNumber: "JT-1001", address: "1410 Maple Fiber Ln", scheduledDate: today, type: "Install", status: "Pending", note: "Call customer 30 minutes before arrival.", distance: 2.4 },
    { id: createId(), jobNumber: "JT-1002", address: "88 Ridge Cabinet Rd", scheduledDate: today, type: "Repair", status: "In Progress", note: "Low light after drop replacement.", distance: 4.1 },
    { id: createId(), jobNumber: "JT-1003", address: "702 Splice Loop", scheduledDate: today, type: "Maintenance", status: "Done", note: "Yellow sheet photos attached.", distance: 6.8 },
    { id: createId(), jobNumber: "JT-1004", address: "19 Canal Crossing", scheduledDate: addDays(monday, 1), type: "Splice", status: "Needs Can", note: "Verify CAN assignment and cabinet records.", distance: 3.2 },
    { id: createId(), jobNumber: "JT-1005", address: "400 Aerial Way", scheduledDate: addDays(monday, 2), type: "Survey", status: "Needs Ariel", note: "Partner recommended for ladder work.", distance: 1.7 },
  ];
  writeJson(store.jobs, jobs);
  return jobs;
}

function seedPartnerRequests() {
  const existing = readJson(store.partnerRequests, []);
  if (existing.length > 0) return existing;
  const requests = [
    { id: createId(), author: "Mia Carter", need: "Aerial work", location: "400 Aerial Way", when: "13:30", note: "Need a second tech for pole transfer.", status: "Open" },
    { id: createId(), author: "Luis Hernandez", need: "Splice assist", location: "702 Splice Loop", when: "15:00", note: "288-count enclosure verification.", status: "Open" },
  ];
  writeJson(store.partnerRequests, requests);
  return requests;
}

function seedAll() {
  seedUsers();
  seedJobs();
  seedPartnerRequests();
  if (!localStorage.getItem(store.settings)) {
    writeJson(store.settings, { smartRouting: true, arrivalAlerts: false, optimizeBy: "Distance", addressProvider: "Apple Maps", theme: "Dark" });
  }
}

function login(user) {
  currentUser = user;
  writeJson(store.session, { userId: user.id });
  $("#authScreen").classList.add("hidden");
  $("#appShell").classList.remove("hidden");
  hydrateUserForms();
  renderAll();
}

function logout() {
  currentUser = null;
  localStorage.removeItem(store.session);
  $("#appShell").classList.add("hidden");
  $("#authScreen").classList.remove("hidden");
  showToast("Signed out.");
}

function checkSession() {
  const session = readJson(store.session, null);
  const users = seedUsers();
  const user = users.find((item) => item.id === session?.userId);
  if (user) login(user);
}

function setAuthMode(mode) {
  $("#loginForm").classList.toggle("hidden", mode !== "login");
  $("#signupForm").classList.toggle("hidden", mode !== "signup");
  $("#loginTab").classList.toggle("active", mode === "login");
  $("#signupTab").classList.toggle("active", mode === "signup");
  $("#authMessage").textContent = "";
}

function handleLogin(event) {
  event.preventDefault();
  const email = $("#loginEmail").value.trim().toLowerCase();
  const password = $("#loginPassword").value;
  const user = readJson(store.users, []).find((item) => item.email.toLowerCase() === email && item.password === password);
  if (!user) {
    $("#authMessage").textContent = "Email or password was incorrect. Try demo@jobtracker.local / password123.";
    return;
  }
  login(user);
  showToast(`Welcome back, ${user.firstName}.`);
}

function handleSignup(event) {
  event.preventDefault();
  const users = readJson(store.users, []);
  const email = $("#signupEmail").value.trim().toLowerCase();
  if (users.some((user) => user.email.toLowerCase() === email)) {
    $("#authMessage").textContent = "An account with that email already exists.";
    return;
  }
  const user = {
    id: createId(),
    firstName: $("#signupFirstName").value.trim(),
    lastName: $("#signupLastName").value.trim(),
    position: $("#signupPosition").value,
    email,
    password: $("#signupPassword").value,
    phone: "",
    yard: "",
  };
  users.push(user);
  writeJson(store.users, users);
  login(user);
  showToast("Account created.");
}

function resetPassword() {
  const email = $("#loginEmail").value.trim();
  $("#authMessage").textContent = email
    ? `Password reset instructions were queued for ${email}.`
    : "Enter your email first, then request a reset.";
}

function renderDate() {
  $("#sidebarDate").textContent = dateLabel(toInputDate(new Date()), { weekday: "long", month: "short", day: "numeric" });
}

function selectedJobs() {
  return readJson(store.jobs, []).filter((job) => job.scheduledDate === selectedDate);
}

function isOpen(job) {
  return job.status !== "Done";
}

function statusClass(status) {
  if (status === "Done") return "done";
  if (status.startsWith("Needs") || status === "Talk to Rick") return "warning";
  if (status === "In Progress") return "danger";
  return "";
}

function renderWeekdayPicker() {
  const monday = mondayFor(selectedDate);
  const picker = $("#weekdayPicker");
  picker.innerHTML = "";
  weekDays.forEach((name, index) => {
    const date = addDays(monday, index);
    const jobs = readJson(store.jobs, []).filter((job) => job.scheduledDate === date);
    const button = document.createElement("button");
    button.className = `day-button ${date === selectedDate ? "active" : ""}`.trim();
    button.type = "button";
    button.innerHTML = `<strong>${shortDays[index]}</strong><span>${dateLabel(date, { month: "short", day: "numeric" })}</span><small>${jobs.length} jobs</small>`;
    button.addEventListener("click", () => {
      selectedDate = date;
      $("#scheduledDateInput").value = selectedDate;
      renderAll();
    });
    picker.append(button);
  });
}

function renderDashboard() {
  const jobs = selectedJobs();
  const pending = jobs.filter(isOpen);
  const done = jobs.filter((job) => job.status === "Done");
  const completion = jobs.length === 0 ? 0 : Math.round((done.length / jobs.length) * 100);
  const nextJob = pending.slice().sort((a, b) => (a.distance ?? 99) - (b.distance ?? 99))[0];
  const timesheet = getTimesheet(mondayFor(selectedDate));
  const dayIndex = Math.max(0, Math.min(4, new Date(`${selectedDate}T12:00:00`).getDay() - 1));
  const dayHours = sumDay(timesheet.days[dayIndex]);
  const yellow = getYellowSheet(selectedDate);
  const partner = readJson(store.partnerRequests, []).find((request) => request.status.startsWith("Accepted"));

  $("#dashboardGreeting").textContent = `Hi ${currentUser.firstName}, here is ${dateLabel(selectedDate)}. Use the dashboard to update work, share summaries, and jump into paperwork.`;
  $("#sidebarSummary").textContent = `${jobs.length} jobs on selected day`;
  $("#totalCount").textContent = jobs.length;
  $("#pendingCount").textContent = pending.length;
  $("#doneCount").textContent = done.length;
  $("#completionRate").textContent = `${completion}%`;
  $("#completionBar").style.width = `${completion}%`;
  $("#nextJobAddress").textContent = nextJob ? nextJob.address : "No next job";
  $("#nextJobHint").textContent = nextJob ? `${nextJob.jobNumber} • ${nextJob.status} • ${nextJob.distance ?? "—"} mi away` : "Add jobs to get routing hints.";
  $("#dashboardHours").textContent = `${dayHours.toFixed(1)} hrs`;
  $("#yellowStatus").textContent = yellow.signature ? "Signed" : yellowHasContent(yellow) ? "In progress" : "Not started";
  $("#partnerStatus").textContent = partner ? partner.author : "No partner";

  renderJobList($("#pendingJobList"), pending, true);
  renderJobList($("#completedJobList"), done, true);
}

function renderJobList(container, jobs, withActions = false) {
  container.innerHTML = "";
  if (jobs.length === 0) {
    container.innerHTML = `<p class="empty-state">No jobs match this section.</p>`;
    return;
  }
  jobs.forEach((job) => container.append(jobCard(job, withActions)));
}

function jobCard(job, withActions = false) {
  const item = document.createElement("article");
  item.className = "job-item";

  const details = document.createElement("div");
  const title = document.createElement("h3");
  const meta = document.createElement("div");
  title.textContent = `${job.jobNumber} · ${job.address}`;
  meta.className = "job-meta";
  [job.type, dateLabel(job.scheduledDate), job.status, `${job.distance ?? "—"} mi`, job.note || "No note added"].forEach((value, index) => {
    const span = document.createElement("span");
    span.textContent = value;
    span.className = index === 2 ? `badge ${statusClass(job.status)}`.trim() : index < 4 ? "badge" : "";
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
      option.value = status;
      option.textContent = status;
      option.selected = status === job.status;
      select.append(option);
    });
    select.addEventListener("change", () => updateJob(job.id, { status: select.value }));
    const remove = document.createElement("button");
    remove.className = "button danger";
    remove.type = "button";
    remove.textContent = "Remove";
    remove.addEventListener("click", () => removeJob(job.id));
    actions.append(select, remove);
    item.append(actions);
  }
  return item;
}

function updateJob(id, patch) {
  const jobs = readJson(store.jobs, []).map((job) => (job.id === id ? { ...job, ...patch } : job));
  writeJson(store.jobs, jobs);
  showSync("Job update saved locally.");
  renderAll();
}

function removeJob(id) {
  writeJson(store.jobs, readJson(store.jobs, []).filter((job) => job.id !== id));
  showToast("Job removed.");
  showSync("Job removal saved locally.");
  renderAll();
}

function handleJobSubmit(event) {
  event.preventDefault();
  const formData = new FormData(event.currentTarget);
  const jobs = readJson(store.jobs, []);
  jobs.unshift({
    id: createId(),
    jobNumber: formData.get("jobNumber").trim(),
    address: formData.get("address").trim(),
    scheduledDate: formData.get("scheduledDate"),
    type: formData.get("type"),
    status: formData.get("status"),
    note: formData.get("note").trim(),
    distance: Number((Math.random() * 8 + 0.8).toFixed(1)),
  });
  writeJson(store.jobs, jobs);
  selectedDate = formData.get("scheduledDate");
  event.currentTarget.reset();
  $("#scheduledDateInput").value = selectedDate;
  showToast("Job saved.");
  showSync("Job saved locally.");
  renderAll();
}

function dayTemplate(name) {
  return { name, notes: "", gibson: 0, cableSouth: 0, other: 0 };
}

function getTimesheet(weekStart) {
  const sheets = readJson(store.timesheets, {});
  if (!sheets[weekStart]) {
    sheets[weekStart] = { weekStart, supervisor: "", partner: "", days: weekDays.map(dayTemplate), savedAt: null };
    writeJson(store.timesheets, sheets);
  }
  return sheets[weekStart];
}

function saveTimesheet(sheet) {
  const sheets = readJson(store.timesheets, {});
  sheets[sheet.weekStart] = sheet;
  writeJson(store.timesheets, sheets);
}

function sumDay(day) {
  return Number(day.gibson || 0) + Number(day.cableSouth || 0) + Number(day.other || 0);
}

function renderTimesheet() {
  const weekStart = $("#timesheetWeekInput").value || mondayFor(selectedDate);
  const sheet = getTimesheet(weekStart);
  $("#timesheetWeekInput").value = weekStart;
  $("#timesheetSupervisorInput").value = sheet.supervisor;
  $("#timesheetPartnerInput").value = sheet.partner;
  const tbody = $("#timesheetRows");
  tbody.innerHTML = "";
  sheet.days.forEach((day, index) => {
    const row = document.createElement("tr");
    row.innerHTML = `
      <td><strong>${day.name}</strong><br><small>${dateLabel(addDays(weekStart, index), { month: "short", day: "numeric" })}</small></td>
      <td><textarea rows="2" data-timesheet-field="notes" data-day-index="${index}">${day.notes}</textarea></td>
      <td><input type="number" min="0" step="0.25" value="${day.gibson}" data-timesheet-field="gibson" data-day-index="${index}"></td>
      <td><input type="number" min="0" step="0.25" value="${day.cableSouth}" data-timesheet-field="cableSouth" data-day-index="${index}"></td>
      <td><input type="number" min="0" step="0.25" value="${day.other}" data-timesheet-field="other" data-day-index="${index}"></td>
      <td><strong>${sumDay(day).toFixed(2)}</strong></td>`;
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
  sheet.partner = $("#timesheetPartnerInput").value.trim();
  $$("[data-timesheet-field]").forEach((input) => {
    const day = sheet.days[Number(input.dataset.dayIndex)];
    const field = input.dataset.timesheetField;
    day[field] = field === "notes" ? input.value : Number(input.value || 0);
  });
  return sheet;
}

function handleSaveTimesheet() {
  const sheet = captureTimesheet();
  sheet.savedAt = new Date().toISOString();
  saveTimesheet(sheet);
  showToast("Timesheet saved.");
  renderAll();
}

function renderPastTimesheets() {
  const sheets = Object.values(readJson(store.timesheets, {})).filter((sheet) => sheet.savedAt);
  const list = $("#pastTimesheetsList");
  list.innerHTML = "";
  if (sheets.length === 0) {
    list.innerHTML = `<p class="empty-state">Saved weekly timesheets will appear here.</p>`;
    return;
  }
  sheets.sort((a, b) => b.weekStart.localeCompare(a.weekStart)).forEach((sheet) => {
    const item = document.createElement("article");
    item.className = "compact-item";
    const total = sheet.days.reduce((sum, day) => sum + sumDay(day), 0);
    item.innerHTML = `<div><h3>Week of ${dateLabel(sheet.weekStart)}</h3><span>${total.toFixed(2)} hours • Supervisor: ${sheet.supervisor || "Not set"}</span></div>`;
    list.append(item);
  });
}

function timesheetText() {
  const sheet = captureTimesheet();
  const lines = [`Job Tracker Timesheet`, `Week: ${sheet.weekStart}`, `Technician: ${currentUser.firstName} ${currentUser.lastName}`, `Supervisor: ${sheet.supervisor || "Not set"}`, `Partner: ${sheet.partner || "None"}`, ""];
  sheet.days.forEach((day) => lines.push(`${day.name}: ${sumDay(day).toFixed(2)} hrs - ${day.notes || "No notes"}`));
  lines.push(`Total: ${sheet.days.reduce((sum, day) => sum + sumDay(day), 0).toFixed(2)} hrs`);
  return lines.join("\n");
}

function getYellowSheet(date) {
  const sheets = readJson(store.yellowSheets, {});
  if (!sheets[date]) {
    sheets[date] = { date, jobId: "", checks: {}, materials: "", notes: "", signature: "", savedAt: null };
    writeJson(store.yellowSheets, sheets);
  }
  return sheets[date];
}

function saveYellowSheet(sheet) {
  const sheets = readJson(store.yellowSheets, {});
  sheets[sheet.date] = sheet;
  writeJson(store.yellowSheets, sheets);
}

function yellowHasContent(sheet) {
  return Object.values(sheet.checks || {}).some(Boolean) || sheet.materials || sheet.notes || sheet.signature;
}

function renderYellowSheet() {
  const date = $("#yellowDateInput").value || selectedDate;
  const sheet = getYellowSheet(date);
  $("#yellowDateInput").value = date;
  const select = $("#yellowJobSelect");
  select.innerHTML = `<option value="">General day sheet</option>`;
  readJson(store.jobs, []).filter((job) => job.scheduledDate === date).forEach((job) => {
    const option = document.createElement("option");
    option.value = job.id;
    option.textContent = `${job.jobNumber} · ${job.address}`;
    option.selected = job.id === sheet.jobId;
    select.append(option);
  });
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
  sheet.checks = {};
  $$('[data-yellow-check]').forEach((input) => { sheet.checks[input.dataset.yellowCheck] = input.checked; });
  return sheet;
}

function handleSaveYellowSheet() {
  const sheet = captureYellowSheet();
  sheet.savedAt = new Date().toISOString();
  saveYellowSheet(sheet);
  showToast("Yellow sheet saved.");
  renderAll();
}

function renderPastYellowSheets() {
  const sheets = Object.values(readJson(store.yellowSheets, {})).filter((sheet) => sheet.savedAt);
  const list = $("#pastYellowSheetsList");
  list.innerHTML = "";
  if (sheets.length === 0) {
    list.innerHTML = `<p class="empty-state">Saved yellow sheets will appear here.</p>`;
    return;
  }
  sheets.sort((a, b) => b.date.localeCompare(a.date)).forEach((sheet) => {
    const checks = Object.values(sheet.checks || {}).filter(Boolean).length;
    const item = document.createElement("article");
    item.className = "compact-item";
    item.innerHTML = `<div><h3>${dateLabel(sheet.date)}</h3><span>${checks}/4 checks complete • Signature: ${sheet.signature || "Missing"}</span></div>`;
    list.append(item);
  });
}

function yellowSheetText() {
  const sheet = captureYellowSheet();
  const checks = Object.entries(sheet.checks).map(([key, value]) => `${key}: ${value ? "yes" : "no"}`).join("\n");
  return [`Job Tracker Yellow Sheet`, `Date: ${sheet.date}`, `Technician: ${currentUser.firstName} ${currentUser.lastName}`, `Signature: ${sheet.signature || "Missing"}`, "", checks, "", `Materials: ${sheet.materials || "None"}`, `Notes: ${sheet.notes || "None"}`].join("\n");
}

function downloadText(filename, text) {
  const blob = new Blob([text], { type: "text/plain" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  link.click();
  URL.revokeObjectURL(link.href);
}

async function copyText(text, fallbackName) {
  try {
    await navigator.clipboard.writeText(text);
    showToast("Summary copied to clipboard.");
  } catch {
    downloadText(fallbackName, text);
    showToast("Clipboard unavailable, downloaded a text summary instead.");
  }
}

function dailySummaryText() {
  const jobs = selectedJobs();
  const lines = [`Job Tracker Daily Summary`, `Date: ${dateLabel(selectedDate)}`, `Technician: ${currentUser.firstName} ${currentUser.lastName}`, ""];
  jobs.forEach((job) => lines.push(`${job.jobNumber} • ${job.status} • ${job.address} • ${job.note || "No note"}`));
  if (jobs.length === 0) lines.push("No jobs scheduled.");
  return lines.join("\n");
}

function renderSearch() {
  const query = $("#jobSearchInput").value.trim().toLowerCase();
  const jobs = readJson(store.jobs, []);
  const filtered = query
    ? jobs.filter((job) => [job.jobNumber, job.address, job.type, job.status, job.note, job.scheduledDate].join(" ").toLowerCase().includes(query))
    : jobs;
  renderJobList($("#searchResults"), filtered, true);
}

function hydrateUserForms() {
  $("#signedInRole").textContent = currentUser.position;
  $("#profileFirstName").value = currentUser.firstName;
  $("#profileLastName").value = currentUser.lastName;
  $("#profilePosition").value = currentUser.position;
  $("#profileEmail").value = currentUser.email;
  $("#profilePhone").value = currentUser.phone || "";
  $("#profileYard").value = currentUser.yard || "";
  const settings = readJson(store.settings, {});
  $("#smartRoutingInput").checked = Boolean(settings.smartRouting);
  $("#arrivalAlertsInput").checked = Boolean(settings.arrivalAlerts);
  $("#routingOptimizeInput").value = settings.optimizeBy || "Distance";
  $("#addressProviderInput").value = settings.addressProvider || "Apple Maps";
  $("#themeInput").value = settings.theme || "Dark";
  applyTheme(settings.theme || "Dark");
}

function saveProfile() {
  const users = readJson(store.users, []).map((user) => {
    if (user.id !== currentUser.id) return user;
    return {
      ...user,
      firstName: $("#profileFirstName").value.trim(),
      lastName: $("#profileLastName").value.trim(),
      position: $("#profilePosition").value,
      phone: $("#profilePhone").value.trim(),
      yard: $("#profileYard").value.trim(),
    };
  });
  writeJson(store.users, users);
  currentUser = users.find((user) => user.id === currentUser.id);
  hydrateUserForms();
  renderDashboard();
  showToast("Profile saved.");
}

function applyTheme(theme) {
  document.body.classList.toggle("high-contrast", theme === "High contrast");
  document.body.classList.toggle("ocean", theme === "Ocean");
}

function saveSettings() {
  const settings = {
    smartRouting: $("#smartRoutingInput").checked,
    arrivalAlerts: $("#arrivalAlertsInput").checked,
    optimizeBy: $("#routingOptimizeInput").value,
    addressProvider: $("#addressProviderInput").value,
    theme: $("#themeInput").value,
  };
  writeJson(store.settings, settings);
  applyTheme(settings.theme);
  showToast("Settings saved.");
}

function setMoreTab(tab) {
  currentMoreTab = tab;
  $$('[data-more-tab]').forEach((button) => button.classList.toggle("active", button.dataset.moreTab === tab));
  $$('[data-more-panel]').forEach((panel) => panel.classList.toggle("active", panel.dataset.morePanel === tab));
}

function renderPartnerRequests() {
  const list = $("#partnerRequestsList");
  const requests = readJson(store.partnerRequests, []);
  list.innerHTML = "";
  if (requests.length === 0) {
    list.innerHTML = `<p class="empty-state">No partner requests posted.</p>`;
    return;
  }
  requests.forEach((request) => {
    const item = document.createElement("article");
    item.className = "compact-item";
    const details = document.createElement("div");
    details.innerHTML = `<h3>${request.need} · ${request.location}</h3><span>${request.when} • ${request.author} • ${request.note || "No note"} • ${request.status}</span>`;
    const action = document.createElement("button");
    action.className = "button secondary";
    action.type = "button";
    action.textContent = request.status.startsWith("Accepted") ? "Accepted" : "I can help";
    action.disabled = request.status.startsWith("Accepted");
    action.addEventListener("click", () => acceptPartnerRequest(request.id));
    item.append(details, action);
    list.append(item);
  });
}

function handlePartnerSubmit(event) {
  event.preventDefault();
  const requests = readJson(store.partnerRequests, []);
  requests.unshift({
    id: createId(),
    author: `${currentUser.firstName} ${currentUser.lastName}`,
    need: $("#partnerNeedInput").value,
    location: $("#partnerLocationInput").value.trim(),
    when: $("#partnerWhenInput").value,
    note: $("#partnerNoteInput").value.trim(),
    status: "Open",
  });
  writeJson(store.partnerRequests, requests);
  event.currentTarget.reset();
  showToast("Partner request posted.");
  renderAll();
}

function acceptPartnerRequest(id) {
  const requests = readJson(store.partnerRequests, []).map((request) => request.id === id ? { ...request, status: `Accepted by ${currentUser.firstName}` } : request);
  writeJson(store.partnerRequests, requests);
  showToast("Partner request accepted.");
  renderAll();
}

function navigate(route) {
  $$("[data-view]").forEach((view) => view.classList.toggle("active", view.dataset.view === route));
  $$("[data-route]").forEach((button) => button.classList.toggle("active", button.dataset.route === route));
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
  $("#resetPasswordButton").addEventListener("click", resetPassword);
  $("#demoLoginButton").addEventListener("click", () => {
    const user = seedUsers().find((item) => item.email === "demo@jobtracker.local");
    login(user);
    showToast("Demo account loaded.");
  });
  $("#signOutButton").addEventListener("click", logout);
  $$("[data-route]").forEach((button) => button.addEventListener("click", (event) => {
    event.preventDefault();
    navigate(button.dataset.route);
  }));
  $$("[data-focus-job-form]").forEach((button) => button.addEventListener("click", () => $("#jobNumberInput").focus()));
  $("#jobForm").addEventListener("submit", handleJobSubmit);
  $("#seedJobsButton").addEventListener("click", () => { seedJobs(true); showToast("Demo jobs reloaded."); renderAll(); });
  $("#shareDailySummaryButton").addEventListener("click", () => copyText(dailySummaryText(), `job-tracker-${selectedDate}.txt`));
  $("#downloadDailySummaryButton").addEventListener("click", () => downloadText(`job-tracker-${selectedDate}.txt`, dailySummaryText()));
  $("#timesheetWeekInput").addEventListener("change", renderTimesheet);
  $("#timesheetRows").addEventListener("change", () => { saveTimesheet(captureTimesheet()); renderTimesheet(); renderDashboard(); });
  $("#saveTimesheetButton").addEventListener("click", handleSaveTimesheet);
  $("#exportTimesheetButton").addEventListener("click", () => downloadText(`timesheet-${$("#timesheetWeekInput").value}.txt`, timesheetText()));
  $("#yellowDateInput").addEventListener("change", renderYellowSheet);
  $("#saveYellowSheetButton").addEventListener("click", handleSaveYellowSheet);
  $("#exportYellowSheetButton").addEventListener("click", () => downloadText(`yellow-sheet-${$("#yellowDateInput").value}.txt`, yellowSheetText()));
  $("#jobSearchInput").addEventListener("input", renderSearch);
  $$('[data-more-tab]').forEach((button) => button.addEventListener("click", () => setMoreTab(button.dataset.moreTab)));
  $("#saveProfileButton").addEventListener("click", saveProfile);
  $("#saveSettingsButton").addEventListener("click", saveSettings);
  $("#partnerForm").addEventListener("submit", handlePartnerSubmit);
}

function initializeInputs() {
  selectedDate = workdayForToday();
  $("#scheduledDateInput").value = selectedDate;
  $("#timesheetWeekInput").value = mondayFor(selectedDate);
  $("#yellowDateInput").value = selectedDate;
}

seedAll();
bindEvents();
initializeInputs();
checkSession();
