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

const nativeStatusOptions = ["Pending", "Needs Aerial", "Needs Underground", "Needs Nid", "Needs Can", "Done", "Talk to Rick"];

function hydrateStatusSelect(select, selectedStatus = "Pending", includeCustom = false) {
  select.innerHTML = "";
  const options = includeCustom ? nativeStatusOptions : statuses;
  const normalizedSelected = selectedStatus === "Needs Ariel" ? "Needs Aerial" : selectedStatus;
  const needsCustom = includeCustom && normalizedSelected && !options.includes(normalizedSelected);
  [...options, ...(includeCustom ? ["Custom"] : [])].forEach((status) => {
    const option = document.createElement("option");
    option.value = status;
    option.textContent = status;
    option.selected = needsCustom ? status === "Custom" : status === normalizedSelected;
    select.append(option);
  });
}

function currentUserRole() {
  const raw = currentUser?.position || "";
  if (["Ariel", "Aerial"].includes(raw)) return "Aerial";
  if (raw === "Nid") return "Nid";
  if (raw === "Can") return "Can";
  if (raw === "Underground") return "Underground";
  return "Default";
}

function intAfter(label, text) {
  const match = String(text || "").match(new RegExp(`${label}\\s*:\\s*(\\d+)`, "i"));
  return match ? match[1] : "0";
}

function materialHas(token, text) {
  return String(text || "").toLowerCase().includes(token.toLowerCase());
}

function parseFiberType(materials = "") {
  const match = String(materials).match(/fiber\s*:\s*(flat|round|mainline)/i);
  return match ? match[1][0].toUpperCase() + match[1].slice(1).toLowerCase() : "";
}

function materialsWithoutManagedTokens(materials = "") {
  const managed = [/^fiber\s*:/i, /^u-guard\s*:/i, /^preforms\s*:/i, /^j hooks\s*:/i, /^jumpers\s*:/i, /^1 nid box$/i, /^storage bracket$/i, /^weatherhead$/i, /^rams head$/i];
  return String(materials)
    .split(",")
    .map((token) => token.trim())
    .filter((token) => token && !managed.some((pattern) => pattern.test(token)))
    .join(", ");
}

function appendMaterial(parts, token) {
  const trimmed = String(token || "").trim();
  if (!trimmed) return;
  if (!parts.some((part) => part.toLowerCase() === trimmed.toLowerCase())) parts.push(trimmed);
}

function setFiberType(value) {
  $("#detailFiberValue").value = value || "";
  $$('[data-fiber-type]').forEach((button) => {
    const active = button.dataset.fiberType === value;
    button.classList.toggle("active", active);
    button.setAttribute("aria-checked", String(active));
  });
}

function renderDetailDateChip() {
  const date = $("#detailDate").value;
  $("#detailDateChip").textContent = date ? dateLabel(date) : "No date";
}

function renderExistingPhotos(job) {
  const container = $("#detailExistingPhotos");
  container.innerHTML = "";
  if (!job.photos?.length) {
    container.innerHTML = `<p class="empty-state">No existing photos</p>`;
    return;
  }
  job.photos.forEach((url) => {
    const link = document.createElement("a");
    link.href = url;
    link.target = "_blank";
    link.rel = "noopener";
    link.className = "photo-thumb";
    const image = document.createElement("img");
    image.src = url;
    image.alt = "Job photo";
    image.loading = "lazy";
    link.append(image);
    container.append(link);
  });
}

function showRoleMaterials(role) {
  const display = role === "Default" ? currentUser?.position || "Technician" : role;
  $("#detailMaterialsHeading").textContent = `MATERIALS — ${display.toUpperCase()}`;
  $$('[data-materials-role]').forEach((section) => section.classList.toggle("hidden", section.dataset.materialsRole !== role));
  $("#detailAssignmentsSection").classList.toggle("hidden", role !== "Can");
}

function openJobDetail(id) {
  const job = appState.jobs.find((item) => item.id === id);
  if (!job) return;

  const role = currentUserRole();
  const materials = job.materialsUsed || "";
  hydrateStatusSelect($("#detailStatus"), job.status, true);
  $("#detailJobId").value = job.id;
  $("#detailJobNumber").value = job.jobNumber || "";
  $("#detailDate").value = job.date || selectedDate;
  $("#detailAddress").value = job.address || "";
  $("#detailAssignments").value = job.assignments || job.type || "";
  $("#detailNotes").value = job.notes || "";
  const normalizedStatus = job.status === "Needs Ariel" ? "Needs Aerial" : job.status;
  const customStatus = normalizedStatus && !nativeStatusOptions.includes(normalizedStatus) ? normalizedStatus : "";
  $("#detailCustomStatus").value = customStatus;
  $("#detailCustomStatusLabel").classList.toggle("hidden", $("#detailStatus").value !== "Custom");
  $("#detailParticipants").value = (job.participants || []).join(", ");
  $("#detailNewPhotos").value = "";
  $("#jobDetailTitle").textContent = "Job Detail";
  renderDetailDateChip();
  renderExistingPhotos(job);
  setFiberType(parseFiberType(materials));
  showRoleMaterials(role);

  $("#detailAerialHead").value = materialHas("Weatherhead", materials) ? "Weatherhead" : materialHas("Rams Head", materials) ? "Rams Head" : "None";
  $("#detailPreforms").value = intAfter("Preforms", materials);
  $("#detailJHooks").value = intAfter("J Hooks", materials);
  $("#detailAerialUGuard").value = intAfter("U-Guard", materials);
  $("#detailStorageBracket").checked = materialHas("Storage Bracket", materials);
  $("#detailAerialCanFootage").value = job.canFootage || "";
  $("#detailAerialNidFootage").value = job.nidFootage || "";

  $("#detailNidBox").checked = materialHas("1 NID Box", materials);
  $("#detailJumpers").value = intAfter("Jumpers", materials);

  $("#detailCanUGuard").value = intAfter("U-Guard", materials);
  $("#detailCanFootage").value = job.canFootage || "";
  $("#detailNidFootage").value = job.nidFootage || "";
  $("#detailCanMaterialsText").value = materialsWithoutManagedTokens(materials);

  $("#detailUndergroundCanFootage").value = job.canFootage || "";
  $("#detailUndergroundNidFootage").value = job.nidFootage || "";
  $("#detailUndergroundMaterialsText").value = materialsWithoutManagedTokens(materials);

  $("#jobDetailScreen").classList.remove("hidden");
  document.body.classList.add("detail-open");
}

function closeJobDetail() {
  $("#jobDetailScreen").classList.add("hidden");
  document.body.classList.remove("detail-open");
}

function buildMaterialsForRole(role) {
  const parts = [];
  const fiberType = $("#detailFiberValue").value;
  appendMaterial(parts, fiberType ? `Fiber: ${fiberType}` : "");

  if (role === "Aerial") {
    appendMaterial(parts, $("#detailAerialHead").value === "None" ? "" : $("#detailAerialHead").value);
    if (Number($("#detailPreforms").value || 0) > 0) appendMaterial(parts, `Preforms: ${$("#detailPreforms").value}`);
    if (Number($("#detailJHooks").value || 0) > 0) appendMaterial(parts, `J Hooks: ${$("#detailJHooks").value}`);
    if (Number($("#detailAerialUGuard").value || 0) > 0) appendMaterial(parts, `U-Guard: ${$("#detailAerialUGuard").value}`);
    if ($("#detailStorageBracket").checked) appendMaterial(parts, "Storage Bracket");
  } else if (role === "Nid") {
    if ($("#detailNidBox").checked) appendMaterial(parts, "1 NID Box");
    if (Number($("#detailJumpers").value || 0) > 0) appendMaterial(parts, `Jumpers: ${$("#detailJumpers").value}`);
  } else if (role === "Can") {
    $("#detailCanMaterialsText").value.split(",").forEach((token) => appendMaterial(parts, token));
    if (Number($("#detailCanUGuard").value || 0) > 0) appendMaterial(parts, `U-Guard: ${$("#detailCanUGuard").value}`);
  } else if (role === "Underground") {
    $("#detailUndergroundMaterialsText").value.split(",").forEach((token) => appendMaterial(parts, token));
  }
  return parts.join(", ");
}

function detailFootageForRole(role) {
  if (role === "Aerial") return { canFootage: $("#detailAerialCanFootage").value.trim(), nidFootage: $("#detailAerialNidFootage").value.trim() };
  if (role === "Can") return { canFootage: $("#detailCanFootage").value.trim(), nidFootage: $("#detailNidFootage").value.trim() };
  if (role === "Underground") return { canFootage: $("#detailUndergroundCanFootage").value.trim(), nidFootage: $("#detailUndergroundNidFootage").value.trim() };
  return { canFootage: "", nidFootage: "" };
}

async function saveJobDetail(event) {
  event.preventDefault();
  const id = $("#detailJobId").value;
  const role = currentUserRole();
  const participants = $("#detailParticipants").value
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
  const existing = currentDetailJob();
  const newPhotos = $("#detailNewPhotos").value
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  await updateJob(id, {
    jobNumber: $("#detailJobNumber").value.trim(),
    date: $("#detailDate").value,
    address: $("#detailAddress").value.trim(),
    status: $("#detailStatus").value === "Custom" ? $("#detailCustomStatus").value.trim() : $("#detailStatus").value,
    assignments: role === "Can" ? $("#detailAssignments").value.trim() : existing?.assignments || "",
    type: role === "Can" ? $("#detailAssignments").value.trim() : existing?.type || existing?.assignments || "",
    materialsUsed: buildMaterialsForRole(role),
    ...detailFootageForRole(role),
    notes: $("#detailNotes").value.trim(),
    participants,
    photos: [...(existing?.photos || []), ...newPhotos],
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
  item.tabIndex = 0;
  item.addEventListener("click", (event) => {
    if (event.target.closest("button, select, input, a, textarea")) return;
    openJobDetail(job.id);
  });
  item.addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      openJobDetail(job.id);
    }
  });

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
  $("#scheduledDateInput").value = selectedDate;
  $("#shareImportPreview").innerHTML = "";
  $("#shareTokenInput").value = "";
  await loadAppData();
  renderAll();
  navigate("dashboard");
  showToast("Shared job imported.");
}

function hydrateShareTokenFromUrl() {
  const params = new URLSearchParams(window.location?.search || "");
  const hashParams = new URLSearchParams((window.location?.hash || "").replace(/^#?\??/, ""));
  const token = params.get("token") || hashParams.get("token");
  if (token) $("#shareTokenInput").value = token;
}

function renderProfileShortcuts() {
  const container = $("#profileShortcuts");
  if (!container) return;

  const timesheets = Object.values(appState.timesheets).filter((sheet) => sheet.savedAt);
  const yellowSheets = Object.values(appState.yellowSheets).filter((sheet) => sheet.savedAt);
  const latestTimesheet = [...timesheets].sort((a, b) => b.weekStart.localeCompare(a.weekStart))[0];
  const latestYellow = [...yellowSheets].sort((a, b) => b.date.localeCompare(a.date))[0];

  container.innerHTML = "";
  [
    { label: "Past Timesheets", count: timesheets.length, detail: latestTimesheet ? `Latest week of ${dateLabel(latestTimesheet.weekStart)}` : "No saved weeks yet", route: "timesheets" },
    { label: "Past Yellow Sheets", count: yellowSheets.length, detail: latestYellow ? `Latest ${dateLabel(latestYellow.date)}` : "No saved sheets yet", route: "yellowSheets" },
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
  $("#jobDetailForm").addEventListener("submit", (event) => saveJobDetail(event).catch((error) => showToast(error.message)));
  $("#closeJobDetailButton").addEventListener("click", closeJobDetail);
  $("#detailDate").addEventListener("change", renderDetailDateChip);
  $("#detailStatus").addEventListener("change", () => $("#detailCustomStatusLabel").classList.toggle("hidden", $("#detailStatus").value !== "Custom"));
  $("#detailDateChip").addEventListener("click", () => $("#detailDate").showPicker?.() || $("#detailDate").focus());
  $$('[data-fiber-type]').forEach((button) => button.addEventListener("click", () => setFiberType(button.dataset.fiberType)));
  $("#routeJobButton").addEventListener("click", () => openRouteForJob(currentDetailJob()));
  $("#shareJobDetailButton").addEventListener("click", () => shareDetailJob().catch((error) => showToast(error.message)));
  $("#removeJobDetailButton").addEventListener("click", () => removeDetailJob().catch((error) => showToast(error.message)));
  $("#shareImportForm").addEventListener("submit", (event) => previewSharedJob(event).catch((error) => showToast(error.message)));
}

bindParityEnhancementEvents();
if (currentUser) renderAll();
