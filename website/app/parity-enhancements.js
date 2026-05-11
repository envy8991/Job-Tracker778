const parityBase = {
  encodeValue,
  hydrateUserForms,
  renderAll,
  jobCard,
};

encodeValue = function enhancedEncodeValue(value, key = "") {
  if (key === "claimedAt") return { timestampValue: toTimestamp(value) };
  return parityBase.encodeValue(value, key);
};

function hydrateStatusSelect(select, selectedStatus = "Pending") {
  select.innerHTML = "";
  statuses.forEach((status) => {
    const option = document.createElement("option");
    option.value = status;
    option.textContent = status;
    option.selected = status === selectedStatus;
    select.append(option);
  });
}

function openJobDetail(id) {
  const job = appState.jobs.find((item) => item.id === id);
  if (!job) return;

  hydrateStatusSelect($("#detailStatus"), job.status);
  $("#detailJobId").value = job.id;
  $("#detailJobNumber").value = job.jobNumber || "";
  $("#detailDate").value = job.date || selectedDate;
  $("#detailAddress").value = job.address || "";
  $("#detailAssignments").value = job.assignments || job.type || "";
  $("#detailMaterials").value = job.materialsUsed || "";
  $("#detailNidFootage").value = job.nidFootage || "";
  $("#detailCanFootage").value = job.canFootage || "";
  $("#detailNotes").value = job.notes || "";
  $("#detailParticipants").value = (job.participants || []).join(", ");
  $("#jobDetailTitle").textContent = `${job.jobNumber || "No job #"} · ${job.address || "Job detail"}`;

  const dialog = $("#jobDetailDialog");
  if (dialog.showModal) dialog.showModal();
  else dialog.setAttribute("open", "");
}

function closeJobDetail() {
  const dialog = $("#jobDetailDialog");
  if (dialog.close) dialog.close();
  else dialog.removeAttribute("open");
}

async function saveJobDetail(event) {
  event.preventDefault();
  const id = $("#detailJobId").value;
  const participants = $("#detailParticipants").value
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  await updateJob(id, {
    jobNumber: $("#detailJobNumber").value.trim(),
    date: $("#detailDate").value,
    address: $("#detailAddress").value.trim(),
    status: $("#detailStatus").value,
    assignments: $("#detailAssignments").value.trim(),
    type: $("#detailAssignments").value.trim(),
    materialsUsed: $("#detailMaterials").value.trim(),
    nidFootage: $("#detailNidFootage").value.trim(),
    canFootage: $("#detailCanFootage").value.trim(),
    notes: $("#detailNotes").value.trim(),
    participants,
  });
  closeJobDetail();
}

function currentDetailJob() {
  return appState.jobs.find((job) => job.id === $("#detailJobId").value);
}

function openRouteForJob(job) {
  if (!job?.address) return;
  window.open(`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(job.address)}`, "_blank", "noopener");
}

async function removeDetailJob() {
  const job = currentDetailJob();
  if (!job) return;
  await removeJob(job.id);
  closeJobDetail();
}

async function shareDetailJob() {
  const job = currentDetailJob();
  if (job) await shareJob(job.id);
}

jobCard = function enhancedJobCard(job, withActions = false) {
  const item = document.createElement("article");
  item.className = "job-item";

  const details = document.createElement("div");
  const title = document.createElement("h3");
  const titleButton = document.createElement("button");
  const meta = document.createElement("div");

  titleButton.type = "button";
  titleButton.textContent = `${job.jobNumber || "No job #"} · ${job.address}`;
  titleButton.addEventListener("click", () => openJobDetail(job.id));
  title.append(titleButton);

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
    hydrateStatusSelect(select, job.status);
    select.addEventListener("change", () => updateJob(job.id, { status: select.value }));

    const share = document.createElement("button");
    share.className = "button secondary";
    share.type = "button";
    share.textContent = "Share";
    share.addEventListener("click", () => shareJob(job.id));

    const remove = document.createElement("button");
    remove.className = "button danger";
    remove.type = "button";
    remove.textContent = "Remove";
    remove.addEventListener("click", () => removeJob(job.id));

    actions.append(select, share, remove);
    item.append(actions);
  }

  return item;
};

function extractShareToken(value) {
  const raw = value.trim();
  if (!raw) return "";
  try {
    const url = new URL(raw);
    return url.searchParams.get("token") || raw;
  } catch {
    const match = raw.match(/[?&]token=([^&]+)/);
    return match ? decodeURIComponent(match[1]) : raw;
  }
}

function sharedPayloadDate(payload) {
  return payload.date || selectedDate;
}

async function previewSharedJob(event) {
  event?.preventDefault();
  const token = extractShareToken($("#shareTokenInput").value);
  const preview = $("#shareImportPreview");
  if (!preview) return;
  preview.innerHTML = "";

  if (!token) {
    preview.innerHTML = `<p class="empty-state">Paste a shared job token or deep link first.</p>`;
    return;
  }

  try {
    const payload = await getDoc("sharedJobs", token);
    if (!payload) {
      preview.innerHTML = `<p class="empty-state">Shared job link not found or expired.</p>`;
      return;
    }
    if (payload.claimedBy) {
      preview.innerHTML = `<p class="empty-state">This shared job link has already been used.</p>`;
      return;
    }
    if (payload.expiresAt && payload.expiresAt < toInputDate(new Date())) {
      preview.innerHTML = `<p class="empty-state">This shared job link has expired.</p>`;
      return;
    }

    const item = document.createElement("article");
    item.className = "compact-item";

    const details = document.createElement("div");
    const title = document.createElement("h3");
    const meta = document.createElement("span");
    title.textContent = `${payload.jobNumber || "No job #"} · ${payload.address}`;
    meta.textContent = `${payload.status || "Pending"} • ${dateLabel(sharedPayloadDate(payload))} • From ${payload.fromUserName || payload.fromUserId || "Unknown"}`;
    details.append(title, meta);

    const actions = document.createElement("div");
    actions.className = "job-actions";
    const importButton = document.createElement("button");
    importButton.className = "button primary";
    importButton.type = "button";
    importButton.textContent = "Import job";
    importButton.addEventListener("click", () => importSharedJob(token, payload));
    actions.append(importButton);

    item.append(details, actions);
    preview.append(item);
  } catch (error) {
    preview.innerHTML = `<p class="empty-state">${error.message}</p>`;
  }
}

async function importSharedJob(token, payload) {
  const job = normalizeJob({
    id: createId(),
    jobNumber: payload.jobNumber || "",
    address: payload.address,
    date: sharedPayloadDate(payload),
    status: payload.status || "Pending",
    assignments: payload.senderIsCan ? payload.assignment || "" : "",
    type: payload.senderIsCan ? payload.assignment || "Shared" : "Shared",
    notes: `Imported shared job${payload.fromUserName ? ` from ${payload.fromUserName}` : ""}.`,
    participants: [currentUser.id, payload.fromUserId].filter(Boolean),
  });

  await setDoc("jobs", job.id, job);
  await setDoc("sharedJobs", token, { ...payload, claimedBy: currentUser.id, claimedAt: new Date().toISOString() });
  selectedDate = job.date;
  updateCreateDateInput(selectedDate);
  if ($("#shareImportPreview")) $("#shareImportPreview").innerHTML = "";
  if ($("#shareTokenInput")) $("#shareTokenInput").value = "";
  await loadAppData();
  renderAll();
  navigate("dashboard");
  showToast("Shared job imported.");
}

function hydrateShareTokenFromUrl() {
  const params = new URLSearchParams(window.location?.search || "");
  const hashParams = new URLSearchParams((window.location?.hash || "").replace(/^#?\??/, ""));
  const token = params.get("token") || hashParams.get("token");
  if (token && $("#shareTokenInput")) $("#shareTokenInput").value = token;
}

function renderProfileShortcuts() {
  const container = $("#profileShortcuts");
  if (!container) return;

  const timesheets = Object.values(appState.timesheets).filter((sheet) => sheet.savedAt);
  const yellowSheets = Object.values(appState.yellowSheets).filter((sheet) => sheet.savedAt);
  const latestTimesheet = [...timesheets].sort((a, b) => b.weekStart.localeCompare(a.weekStart))[0];
  const latestYellow = [...yellowSheets].sort((a, b) => b.weekStart.localeCompare(a.weekStart))[0];

  container.innerHTML = "";
  [
    { label: "Past Timesheets", count: timesheets.length, detail: latestTimesheet ? `Latest week of ${dateLabel(latestTimesheet.weekStart)}` : "No saved weeks yet", route: "timesheets" },
    { label: "Past Yellow Sheets", count: yellowSheets.length, detail: latestYellow ? `Latest week of ${dateLabel(latestYellow.weekStart)}` : "No saved sheets yet", route: "yellowSheets" },
  ].forEach((shortcut) => {
    const button = document.createElement("button");
    const label = document.createElement("span");
    const count = document.createElement("strong");
    const detail = document.createElement("small");

    button.className = "shortcut-card";
    button.type = "button";
    label.textContent = shortcut.label;
    count.textContent = shortcut.count;
    detail.textContent = shortcut.detail;
    button.append(label, count, detail);
    button.addEventListener("click", () => navigate(shortcut.route));
    container.append(button);
  });
}

hydrateUserForms = function enhancedHydrateUserForms() {
  parityBase.hydrateUserForms();
  renderProfileShortcuts();
};

renderAll = function enhancedRenderAll() {
  parityBase.renderAll();
  renderProfileShortcuts();
};

function bindParityEnhancementEvents() {
  hydrateStatusSelect($("#detailStatus"));
  hydrateShareTokenFromUrl();
  $("#jobDetailForm")?.addEventListener("submit", (event) => saveJobDetail(event).catch((error) => showToast(error.message)));
  $("#closeJobDetailButton")?.addEventListener("click", closeJobDetail);
  $("#routeJobButton")?.addEventListener("click", () => openRouteForJob(currentDetailJob()));
  $("#shareJobDetailButton")?.addEventListener("click", () => shareDetailJob().catch((error) => showToast(error.message)));
  $("#removeJobDetailButton")?.addEventListener("click", () => removeDetailJob().catch((error) => showToast(error.message)));
  $("#shareImportForm")?.addEventListener("submit", (event) => previewSharedJob(event).catch((error) => showToast(error.message)));
}

bindParityEnhancementEvents();
if (currentUser) renderAll();
