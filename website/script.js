function createId() {
  return globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

const defaultJobs = [
  {
    id: createId(),
    address: "1410 Maple Fiber Ln",
    type: "Install",
    status: "Pending",
    note: "Call customer 30 minutes before arrival.",
  },
  {
    id: createId(),
    address: "88 Ridge Cabinet Rd",
    type: "Repair",
    status: "In Progress",
    note: "Low light after drop replacement.",
  },
  {
    id: createId(),
    address: "702 Splice Loop",
    type: "Maintenance",
    status: "Done",
    note: "Yellow sheet photos attached.",
  },
];

const storageKey = "job-tracker-web-jobs";
const jobForm = document.querySelector("#jobForm");
const resetJobsButton = document.querySelector("#resetJobsButton");
const jobList = document.querySelector("#jobList");
const assistForm = document.querySelector("#assistForm");
const assistInput = document.querySelector("#assistInput");
const assistOutput = document.querySelector("#assistOutput");

let jobs = loadJobs();

function loadJobs() {
  const savedJobs = localStorage.getItem(storageKey);

  if (!savedJobs) {
    return defaultJobs;
  }

  try {
    const parsedJobs = JSON.parse(savedJobs);
    return Array.isArray(parsedJobs) ? parsedJobs : defaultJobs;
  } catch {
    return defaultJobs;
  }
}

function saveJobs() {
  localStorage.setItem(storageKey, JSON.stringify(jobs));
}

function renderDate() {
  const formatter = new Intl.DateTimeFormat(undefined, {
    weekday: "long",
    month: "short",
    day: "numeric",
  });

  document.querySelector("#sidebarDate").textContent = formatter.format(new Date());
}

function renderSummary() {
  const pending = jobs.filter((job) => job.status === "Pending").length;
  const active = jobs.filter((job) => job.status === "In Progress").length;
  const done = jobs.filter((job) => job.status === "Done").length;
  const completion = jobs.length === 0 ? 0 : Math.round((done / jobs.length) * 100);

  document.querySelector("#pendingCount").textContent = pending;
  document.querySelector("#activeCount").textContent = active;
  document.querySelector("#doneCount").textContent = done;
  document.querySelector("#completionRate").textContent = `${completion}%`;
  document.querySelector("#completionBar").style.width = `${completion}%`;
  document.querySelector("#sidebarSummary").textContent = `${jobs.length} jobs scheduled`;
}

function statusClass(status) {
  if (status === "Done") {
    return "done";
  }

  if (status.startsWith("Needs")) {
    return "warning";
  }

  return "";
}

function renderJobs() {
  jobList.innerHTML = "";

  if (jobs.length === 0) {
    jobList.innerHTML = `<p class="empty-state">No jobs yet. Add the first address above.</p>`;
    return;
  }

  for (const job of jobs) {
    const item = document.createElement("article");
    const details = document.createElement("div");
    const address = document.createElement("h3");
    const meta = document.createElement("div");
    const typeBadge = document.createElement("span");
    const statusBadge = document.createElement("span");
    const note = document.createElement("span");
    const removeButton = document.createElement("button");

    item.className = "job-item";
    meta.className = "job-meta";
    typeBadge.className = "badge";
    statusBadge.className = `badge ${statusClass(job.status)}`.trim();
    removeButton.className = "button secondary";
    removeButton.type = "button";
    removeButton.dataset.deleteJob = job.id;

    address.textContent = job.address;
    typeBadge.textContent = job.type;
    statusBadge.textContent = job.status;
    note.textContent = job.note || "No note added";
    removeButton.textContent = "Remove";

    meta.append(typeBadge, statusBadge, note);
    details.append(address, meta);
    item.append(details, removeButton);
    jobList.append(item);
  }
}

function render() {
  renderSummary();
  renderJobs();
}

jobForm.addEventListener("submit", (event) => {
  event.preventDefault();

  const formData = new FormData(jobForm);
  jobs = [
    {
      id: createId(),
      address: formData.get("address").trim(),
      type: formData.get("type"),
      status: formData.get("status"),
      note: formData.get("note").trim(),
    },
    ...jobs,
  ];

  saveJobs();
  render();
  jobForm.reset();
});

jobList.addEventListener("click", (event) => {
  const deleteButton = event.target.closest("[data-delete-job]");

  if (!deleteButton) {
    return;
  }

  jobs = jobs.filter((job) => job.id !== deleteButton.dataset.deleteJob);
  saveJobs();
  render();
});

resetJobsButton.addEventListener("click", () => {
  jobs = defaultJobs.map((job) => ({ ...job, id: createId() }));
  saveJobs();
  render();
});

assistForm.addEventListener("submit", (event) => {
  event.preventDefault();

  const issue = assistInput.value.trim();
  const prefix = issue ? `For “${issue}”: ` : "";
  assistOutput.value = `${prefix}verify light levels, inspect connectors, compare splice records, capture photos, and escalate with cabinet or CAN details.`;
});

renderDate();
render();
