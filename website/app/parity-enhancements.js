const nativeStatusOptions = ["Pending", "Needs Aerial", "Needs Underground", "Needs Nid", "Needs Can", "Done", "Talk to Rick", "Custom"];
statuses.splice(0, statuses.length, ...nativeStatusOptions);

const parityBase = {
  encodeValue,
  hydrateUserForms,
  renderAll,
  jobCard,
  shareJob,
  loadAppData,
  enterApp,
  normalizeJob,
  renderSearch,
  buildQuickFilters,
  logout,
};

encodeValue = function enhancedEncodeValue(value, key = "") {
  if (key === "claimedAt") return { timestampValue: toTimestamp(value) };
  return parityBase.encodeValue(value, key);
};

const appDataCachePrefix = "job-tracker-web-app-data";
appState.searchJobs = appState.searchJobs || [];

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

async function paginatedListDocs(collection, options = {}) {
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
    return await paginatedListDocs(collection, options);
  } catch (error) {
    console.warn(`Could not load ${collection}:`, error.message);
    return [];
  }
}

async function queryDocs(collection, where) {
  const body = { structuredQuery: { from: [{ collectionId: collection }], where } };
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

async function safeQueryDocs(collection, where) {
  try {
    return await queryDocs(collection, where);
  } catch (error) {
    console.warn(`Could not query ${collection}:`, error.message);
    return [];
  }
}

async function loadVisibleJobs() {
  try {
    return await paginatedListDocs("jobs");
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

loadAppData = async function enhancedLoadAppData() {
  showSync("Syncing with Firebase…");
  const [jobs, searchIndex, users, timesheets, yellowSheets, partnerRequests] = await Promise.all([
    loadVisibleJobs(),
    safeListDocs("jobsSearch"),
    paginatedListDocs("users"),
    paginatedListDocs("timesheets"),
    paginatedListDocs("yellowSheets"),
    paginatedListDocs("partnerRequests"),
  ]);
  appState.users = users;
  appState.jobs = jobs.filter((job) => canSeeJob(job));
  appState.searchJobs = mergeSearchEntries(jobs, searchIndex);
  appState.timesheets = Object.fromEntries(timesheets.filter((sheet) => sheet.userId === currentUser.id).map((sheet) => [sheet.weekStart, normalizeTimesheet(sheet)]));
  appState.yellowSheets = Object.fromEntries(yellowSheets.filter((sheet) => sheet.userId === currentUser.id).map((sheet) => [sheet.date || sheet.weekStart, normalizeYellowSheet(sheet)]));
  appState.partnerRequests = partnerRequests.filter((request) => request.fromUid === currentUser.id || request.toUid === currentUser.id);
  cacheAppData();
  showSync();
};

enterApp = async function enhancedEnterApp() {
  showApp();
  hydrateUserForms();
  if (restoreCachedAppData()) renderAll();
  await loadAppData();
  renderAll();
};

logout = function enhancedLogout() {
  clearSession();
  currentUser = null;
  appState = { jobs: [], searchJobs: [], users: [], timesheets: {}, yellowSheets: {}, partnerRequests: [] };
  showAuth();
  showToast("Signed out.");
};

normalizeJob = function enhancedNormalizeJob(job) {
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
};

function searchSourceJobs() {
  return appState.searchJobs?.length ? appState.searchJobs : appState.jobs;
}

buildQuickFilters = function enhancedBuildQuickFilters() {
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
};

renderSearch = function enhancedRenderSearch() {
  const input = $("#jobSearchInput");
  const results = $("#searchResults");
  if (!input || !results) return;
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
    empty.innerHTML = `<strong>No jobs found for “${query.replace(/[&<>\"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;" }[char]))}”</strong><span>Try fewer keywords or search by street, city, job number, status, or teammate name.</span>`;
    results.append(empty);
    return;
  } else {
    const heading = document.createElement("div");
    heading.className = "search-list-heading";
    heading.innerHTML = `<h3>Results</h3><p>${matches.length} match${matches.length === 1 ? "" : "es"}</p>`;
    results.append(heading);
  }

  matches.forEach((job) => results.append(renderSearchResultCard(job, tokens)));
};

function normalizedPosition(user = currentUser) {
  const position = String(user?.normalizedPosition || user?.position || "").trim();
  return position.toLowerCase() === "ariel" ? "Aerial" : position;
}

function isCanUser(user = currentUser) {
  return normalizedPosition(user).toLowerCase() === "can";
}

async function shareNativeLink(url, title = "Job Tracker shared job") {
  if (navigator.share) {
    try {
      await navigator.share({ title, text: url, url });
      return "Shared with your device share sheet.";
    } catch (error) {
      if (error?.name === "AbortError") return "Share cancelled.";
    }
  }
  await copyText(url, `${title.toLowerCase().replace(/[^a-z0-9]+/g, "-")}.txt`);
  return "Share link copied. It expires in 7 days.";
}

shareJob = async function enhancedShareJob(id) {
  const job = appState.jobs.find((item) => item.id === id);
  if (!job) return;
  try {
    const token = randomToken();
    const senderName = `${currentUser.firstName || ""} ${currentUser.lastName || ""}`.trim() || currentUser.email || currentUser.id;
    const senderIsCan = isCanUser();
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
    const message = await shareNativeLink(`jobtracker://importJob?token=${token}`, `Job link ${job.jobNumber || token}`);
    showToast(message);
  } catch (error) { showToast(error.message); }
};

isOpen = function enhancedIsOpen(job) {
  return String(job.status || "Pending").toLowerCase() === "pending";
};

statusClass = function enhancedStatusClass(status) {
  const normalized = String(status || "").toLowerCase();
  if (normalized === "done") return "done";
  if (normalized.startsWith("needs") || normalized === "talk to rick" || normalized === "custom") return "warning";
  if (normalized === "pending") return "pending";
  return "";
};

function hydrateStatusSelect(select, selectedStatus = "Pending") {
  if (!select) return;
  select.innerHTML = "";
  const optionValues = statuses.includes(selectedStatus) ? statuses : [selectedStatus, ...statuses];
  optionValues.forEach((status) => {
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
    if (payload.senderIsCan && payload.assignment && !isCanUser()) {
      const privacy = document.createElement("p");
      privacy.className = "helper-text";
      privacy.textContent = "Assignment is visible in the preview but will only import for CAN users, matching the iOS app privacy rule.";
      details.append(privacy);
    }

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
    assignments: payload.senderIsCan && isCanUser() ? payload.assignment || "" : "",
    type: payload.senderIsCan && isCanUser() ? payload.assignment || "Shared" : "Shared",
    notes: "",
    assignedTo: currentUser.id,
    createdBy: currentUser.id,
    participants: [currentUser.id],
  });

  await setDoc("jobs", job.id, job);
  await setDoc("sharedJobs", token, { ...payload, claimedBy: currentUser.id, claimedAt: new Date().toISOString() });
  selectedDate = job.date;
  updateCreateDateInput(selectedDate);
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
  const input = $("#shareTokenInput");
  if (token && input) {
    input.value = token;
    navigate("more", { skipHash: true, skipScroll: true });
    setMoreTab("sharing");
  }
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
  $("#jobDetailForm")?.addEventListener("submit", (event) => saveJobDetail(event).catch((error) => showToast(error.message)));
  $("#closeJobDetailButton")?.addEventListener("click", closeJobDetail);
  $("#routeJobButton")?.addEventListener("click", () => openRouteForJob(currentDetailJob()));
  $("#shareJobDetailButton")?.addEventListener("click", () => shareDetailJob().catch((error) => showToast(error.message)));
  $("#removeJobDetailButton")?.addEventListener("click", () => removeDetailJob().catch((error) => showToast(error.message)));
  $("#shareImportForm")?.addEventListener("submit", (event) => previewSharedJob(event).catch((error) => showToast(error.message)));
  $("#jobSearchInput")?.addEventListener("input", renderSearch);
}

bindParityEnhancementEvents();
if (currentUser) renderAll();
