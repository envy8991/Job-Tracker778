function createId() {
  return globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

const storageKeys = {
  jobs: "job-tracker-web-tabs-jobs",
  timesheets: "job-tracker-web-tabs-timesheets",
  yellowSheets: "job-tracker-web-tabs-yellow-sheets",
};

const today = new Date();
const defaultJobs = [
  {
    id: createId(),
    address: "1410 Maple Fiber Ln",
    date: toDateInputValue(today),
    status: "Pending",
    notes: "Call customer 30 minutes before arrival.",
    jobNumber: "1001",
    assignments: "12.3.2",
    materialsUsed: "NID box, jumper",
    hours: 2,
  },
  {
    id: createId(),
    address: "88 Ridge Cabinet Rd",
    date: toDateInputValue(today),
    status: "Needs Underground",
    notes: "Drop needs bore crew before completion.",
    jobNumber: "1002",
    assignments: "14.1.7",
    materialsUsed: "Conduit, mule tape",
    hours: 1.5,
  },
  {
    id: createId(),
    address: "702 Splice Loop",
    date: toDateInputValue(addDays(today, -1)),
    status: "Done",
    notes: "Footage and materials entered.",
    jobNumber: "1003",
    assignments: "9.4.1",
    materialsUsed: "Preforms, weatherhead",
    hours: 3,
  },
];

const appState = {
  selectedTab: "dashboard",
  selectedDate: toDateInputValue(today),
  jobs: loadStoredArray(storageKeys.jobs, defaultJobs),
  timesheets: loadStoredArray(storageKeys.timesheets, []),
  yellowSheets: loadStoredArray(storageKeys.yellowSheets, []),
};

const formatDay = new Intl.DateTimeFormat(undefined, { weekday: "short", month: "short", day: "numeric" });
const formatLongDay = new Intl.DateTimeFormat(undefined, { weekday: "long", month: "short", day: "numeric" });
const formatWeekday = new Intl.DateTimeFormat(undefined, { weekday: "short" });
const formatShortDate = new Intl.DateTimeFormat(undefined, { month: "numeric", day: "numeric" });

const tabButtons = document.querySelectorAll("[data-tab-target]");
const tabViews = document.querySelectorAll("[data-tab]");
const jobForm = document.querySelector("#jobForm");
const jobList = document.querySelector("#jobList");
const resetJobsButton = document.querySelector("#resetJobsButton");
const focusCreateJobButton = document.querySelector("#focusCreateJobButton");
const weekdayPicker = document.querySelector("#weekdayPicker");
const dailyHoursGrid = document.querySelector("#dailyHoursGrid");
const timesheetForm = document.querySelector("#timesheetForm");
const saveTimesheetButton = document.querySelector("#saveTimesheetButton");
const saveYellowSheetButton = document.querySelector("#saveYellowSheetButton");
const searchInput = document.querySelector("#searchInput");

function loadStoredArray(key, fallback) {
  const storedValue = localStorage.getItem(key);
  if (!storedValue) return fallback;

  try {
    const parsedValue = JSON.parse(storedValue);
    return Array.isArray(parsedValue) ? parsedValue : fallback;
  } catch {
    return fallback;
  }
}

function saveStoredArray(key, value) {
  localStorage.setItem(key, JSON.stringify(value));
}

function addDays(date, days) {
  const nextDate = new Date(date);
  nextDate.setDate(nextDate.getDate() + days);
  return nextDate;
}

function fromDateInputValue(value) {
  return new Date(`${value}T12:00:00`);
}

function toDateInputValue(date) {
  const normalizedDate = new Date(date);
  normalizedDate.setMinutes(normalizedDate.getMinutes() - normalizedDate.getTimezoneOffset());
  return normalizedDate.toISOString().slice(0, 10);
}

function startOfWeek(value) {
  const date = fromDateInputValue(value);
  date.setDate(date.getDate() - date.getDay());
  return toDateInputValue(date);
}

function weekDays(value) {
  const firstDay = fromDateInputValue(startOfWeek(value));
  return Array.from({ length: 7 }, (_, index) => toDateInputValue(addDays(firstDay, index)));
}

function currentWeekJobs() {
  const dates = new Set(weekDays(appState.selectedDate));
  return appState.jobs.filter((job) => dates.has(job.date));
}

function selectedDayJobs() {
  return appState.jobs.filter((job) => job.date === appState.selectedDate);
}

function statusClass(status) {
  if (status === "Done") return "done";
  if (status.startsWith("Needs")) return "warning";
  return "";
}

function navigateTo(tabName) {
  appState.selectedTab = tabName;

  for (const button of tabButtons) {
    const isActive = button.dataset.tabTarget === tabName;
    button.classList.toggle("active", isActive);
    button.toggleAttribute("aria-current", isActive);
  }

  for (const view of tabViews) {
    const isActive = view.dataset.tab === tabName;
    view.classList.toggle("active", isActive);
    view.hidden = !isActive;
  }

  history.replaceState(null, "", `#${tabName}`);
  document.querySelector("#appContent").scrollIntoView({ block: "start" });
}

function renderDate() {
  document.querySelector("#currentDate").textContent = formatLongDay.format(today);
}

function renderWeekdayPicker() {
  weekdayPicker.innerHTML = "";

  for (const dateValue of weekDays(appState.selectedDate)) {
    const date = fromDateInputValue(dateValue);
    const button = document.createElement("button");
    button.className = "day-button";
    button.type = "button";
    button.dataset.date = dateValue;
    button.classList.toggle("active", dateValue === appState.selectedDate);
    button.innerHTML = `<span>${formatWeekday.format(date)}</span><small>${formatShortDate.format(date)}</small>`;
    weekdayPicker.append(button);
  }
}

function renderDashboardSummary() {
  const jobs = selectedDayJobs();
  const pending = jobs.filter((job) => job.status !== "Done").length;
  const done = jobs.filter((job) => job.status === "Done").length;
  const completion = jobs.length === 0 ? 0 : Math.round((done / jobs.length) * 100);

  document.querySelector("#totalCount").textContent = jobs.length;
  document.querySelector("#pendingCount").textContent = pending;
  document.querySelector("#doneCount").textContent = done;
  document.querySelector("#completionRate").textContent = `${completion}%`;
  document.querySelector("#completionBar").style.width = `${completion}%`;
  document.querySelector("#selectedDayLabel").textContent = formatLongDay.format(fromDateInputValue(appState.selectedDate));
}

function makeJobItem(job, options = {}) {
  const item = document.createElement("article");
  const details = document.createElement("div");
  const address = document.createElement("h3");
  const meta = document.createElement("div");
  const jobNumber = document.createElement("span");
  const statusBadge = document.createElement("span");
  const dateBadge = document.createElement("span");
  const note = document.createElement("span");

  item.className = "job-item";
  meta.className = "job-meta";
  jobNumber.className = "badge";
  statusBadge.className = `badge ${statusClass(job.status)}`.trim();
  dateBadge.className = "badge";

  address.textContent = job.address;
  jobNumber.textContent = job.jobNumber ? `Job #${job.jobNumber}` : "No job #";
  statusBadge.textContent = job.status;
  dateBadge.textContent = formatDay.format(fromDateInputValue(job.date));
  note.textContent = job.notes || "No notes";

  meta.append(jobNumber, statusBadge, dateBadge, note);
  details.append(address, meta);
  item.append(details);

  if (!options.readOnly) {
    const controls = document.createElement("div");
    controls.className = "job-meta";

    const statusSelect = document.createElement("select");
    statusSelect.dataset.statusJob = job.id;
    for (const status of ["Pending", "Needs Ariel", "Needs Underground", "Done"]) {
      const option = document.createElement("option");
      option.value = status;
      option.textContent = status;
      option.selected = status === job.status;
      statusSelect.append(option);
    }

    const removeButton = document.createElement("button");
    removeButton.className = "button secondary";
    removeButton.type = "button";
    removeButton.dataset.deleteJob = job.id;
    removeButton.textContent = "Delete";

    controls.append(statusSelect, removeButton);
    item.append(controls);
  }

  return item;
}

function renderJobs() {
  const jobs = selectedDayJobs();
  jobList.innerHTML = "";

  if (jobs.length === 0) {
    jobList.innerHTML = `<p class="empty-state">No jobs for this day. Create one above or choose another weekday.</p>`;
    return;
  }

  for (const job of jobs) {
    jobList.append(makeJobItem(job));
  }
}

function renderTimesheet() {
  const dates = weekDays(appState.selectedDate);
  const firstDate = fromDateInputValue(dates[0]);
  const lastDate = fromDateInputValue(dates[6]);
  document.querySelector("#weekRangeLabel").textContent = `${formatDay.format(firstDate)} – ${formatDay.format(lastDate)}`;

  dailyHoursGrid.innerHTML = "";
  for (const dateValue of dates) {
    const dayJobs = appState.jobs.filter((job) => job.date === dateValue);
    const totalHours = dayJobs.reduce((sum, job) => sum + Number(job.hours || 0), 0);
    const label = document.createElement("label");
    label.innerHTML = `${formatWeekday.format(fromDateInputValue(dateValue))}<input data-daily-hours="${dateValue}" type="number" min="0" step="0.25" value="${totalHours}" />`;
    dailyHoursGrid.append(label);
  }

  renderPastTimesheets();
  updateTimesheetTotal();
}

function updateTimesheetTotal() {
  const gibson = Number(document.querySelector("#gibsonHoursInput").value || 0);
  const cableSouth = Number(document.querySelector("#cableSouthHoursInput").value || 0);
  const dailyTotal = Array.from(document.querySelectorAll("[data-daily-hours]")).reduce((sum, input) => sum + Number(input.value || 0), 0);
  document.querySelector("#totalHoursInput").value = Math.max(gibson + cableSouth, dailyTotal).toFixed(2).replace(/\.00$/, "");
}

function renderPastTimesheets() {
  const list = document.querySelector("#pastTimesheetsList");
  list.innerHTML = "";

  if (appState.timesheets.length === 0) {
    list.innerHTML = `<p class="empty-state">No saved timesheets yet.</p>`;
    return;
  }

  for (const sheet of [...appState.timesheets].reverse()) {
    const item = document.createElement("article");
    item.className = "compact-item";
    item.innerHTML = `<div><strong>Week of ${formatDay.format(fromDateInputValue(sheet.weekStart))}</strong><div class="muted">${sheet.totalHours || 0} total hours • Supervisor: ${sheet.supervisor || "—"}</div></div>`;
    list.append(item);
  }
}

function renderYellowSheet() {
  const weekStart = startOfWeek(appState.selectedDate);
  const jobs = currentWeekJobs();
  document.querySelector("#yellowWeekStartLabel").textContent = formatDay.format(fromDateInputValue(weekStart));
  document.querySelector("#yellowTotalJobs").textContent = jobs.length;

  const list = document.querySelector("#yellowJobList");
  list.innerHTML = "";

  if (jobs.length === 0) {
    list.innerHTML = `<p class="empty-state">No jobs in this week yet.</p>`;
  } else {
    for (const job of jobs) list.append(makeJobItem(job, { readOnly: true }));
  }

  renderPastYellowSheets();
}

function renderPastYellowSheets() {
  const list = document.querySelector("#pastYellowSheetsList");
  list.innerHTML = "";

  if (appState.yellowSheets.length === 0) {
    list.innerHTML = `<p class="empty-state">No saved yellow sheets yet.</p>`;
    return;
  }

  for (const sheet of [...appState.yellowSheets].reverse()) {
    const item = document.createElement("article");
    item.className = "compact-item";
    item.innerHTML = `<div><strong>Week of ${formatDay.format(fromDateInputValue(sheet.weekStart))}</strong><div class="muted">${sheet.totalJobs} jobs saved</div></div>`;
    list.append(item);
  }
}

function renderSearchResults() {
  const query = searchInput.value.trim().toLowerCase();
  const results = query
    ? appState.jobs.filter((job) => [job.address, job.jobNumber, job.status, job.notes, job.assignments, job.materialsUsed].some((value) => String(value || "").toLowerCase().includes(query)))
    : appState.jobs;

  const searchResults = document.querySelector("#searchResults");
  searchResults.innerHTML = "";

  if (results.length === 0) {
    searchResults.innerHTML = `<p class="empty-state">No matching jobs found.</p>`;
    return;
  }

  for (const job of results) searchResults.append(makeJobItem(job, { readOnly: true }));
}

function render() {
  renderWeekdayPicker();
  renderDashboardSummary();
  renderJobs();
  renderTimesheet();
  renderYellowSheet();
  renderSearchResults();
}

for (const button of tabButtons) {
  button.addEventListener("click", () => navigateTo(button.dataset.tabTarget));
}

document.querySelector("[data-tab-link]").addEventListener("click", (event) => {
  event.preventDefault();
  navigateTo("dashboard");
});

weekdayPicker.addEventListener("click", (event) => {
  const button = event.target.closest("[data-date]");
  if (!button) return;
  appState.selectedDate = button.dataset.date;
  render();
});

jobForm.addEventListener("submit", (event) => {
  event.preventDefault();

  const formData = new FormData(jobForm);
  appState.jobs = [
    {
      id: createId(),
      address: formData.get("address").trim(),
      date: appState.selectedDate,
      status: formData.get("status"),
      notes: formData.get("notes").trim(),
      jobNumber: formData.get("jobNumber").trim(),
      assignments: "",
      materialsUsed: "",
      hours: 0,
    },
    ...appState.jobs,
  ];

  saveStoredArray(storageKeys.jobs, appState.jobs);
  jobForm.reset();
  render();
});

jobList.addEventListener("click", (event) => {
  const deleteButton = event.target.closest("[data-delete-job]");
  if (!deleteButton) return;

  appState.jobs = appState.jobs.filter((job) => job.id !== deleteButton.dataset.deleteJob);
  saveStoredArray(storageKeys.jobs, appState.jobs);
  render();
});

jobList.addEventListener("change", (event) => {
  const statusSelect = event.target.closest("[data-status-job]");
  if (!statusSelect) return;

  appState.jobs = appState.jobs.map((job) => job.id === statusSelect.dataset.statusJob ? { ...job, status: statusSelect.value } : job);
  saveStoredArray(storageKeys.jobs, appState.jobs);
  render();
});

resetJobsButton.addEventListener("click", () => {
  appState.jobs = defaultJobs.map((job) => ({ ...job, id: createId() }));
  saveStoredArray(storageKeys.jobs, appState.jobs);
  render();
});

focusCreateJobButton.addEventListener("click", () => document.querySelector("#addressInput").focus());

timesheetForm.addEventListener("input", updateTimesheetTotal);
dailyHoursGrid.addEventListener("input", updateTimesheetTotal);

saveTimesheetButton.addEventListener("click", () => {
  const formData = new FormData(timesheetForm);
  const dailyTotalHours = Object.fromEntries(Array.from(document.querySelectorAll("[data-daily-hours]")).map((input) => [input.dataset.dailyHours, input.value || "0"]));
  const weekStart = startOfWeek(appState.selectedDate);
  const sheet = {
    id: createId(),
    weekStart,
    supervisor: formData.get("supervisor").trim(),
    name1: formData.get("name1").trim(),
    name2: formData.get("name2").trim(),
    gibsonHours: formData.get("gibsonHours"),
    cableSouthHours: formData.get("cableSouthHours"),
    totalHours: formData.get("totalHours"),
    dailyTotalHours,
  };

  appState.timesheets = appState.timesheets.filter((item) => item.weekStart !== weekStart).concat(sheet);
  saveStoredArray(storageKeys.timesheets, appState.timesheets);
  renderPastTimesheets();
});

saveYellowSheetButton.addEventListener("click", () => {
  const weekStart = startOfWeek(appState.selectedDate);
  const sheet = { id: createId(), weekStart, totalJobs: currentWeekJobs().length };
  appState.yellowSheets = appState.yellowSheets.filter((item) => item.weekStart !== weekStart).concat(sheet);
  saveStoredArray(storageKeys.yellowSheets, appState.yellowSheets);
  renderPastYellowSheets();
});

searchInput.addEventListener("input", renderSearchResults);

document.querySelectorAll("[data-search-filter]").forEach((button) => {
  button.addEventListener("click", () => {
    searchInput.value = button.dataset.searchFilter;
    renderSearchResults();
  });
});

const initialHash = window.location.hash.replace("#", "");
if (["dashboard", "timesheets", "yellowSheet", "jobSearch", "more"].includes(initialHash)) {
  navigateTo(initialHash);
}

renderDate();
render();
