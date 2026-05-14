/* ═══════════════════════════════════════════════════════════════════════════
   JIRA Tickets — filter UI, search, drill-down
   ═══════════════════════════════════════════════════════════════════════════ */

const jiraState = {
  metadata: null,
  pageSize: 50,
  approximateTotal: null,
  lastFilters: null,
  tokenStack: [],      // stack of page tokens visited (for Prev navigation)
  currentToken: null,  // token used to load the current page
  nextToken: null,     // token to use for the next page (null if isLast)
  pageNumber: 1,
  currentDraftItem: null,
  currentDrawerKey: null,
  lastTroubleshootReport: null,
};

document.addEventListener("DOMContentLoaded", () => {
  if (!window.JIRA_CONFIGURED) {
    document.getElementById("resultsBody").innerHTML =
      `<div class="empty-state">
         <i class="fa-solid fa-triangle-exclamation" style="color:#d29922"></i>
         <div>JIRA credentials are not set. Add JIRA_BASE_URL, JIRA_EMAIL, and JIRA_API_TOKEN to your .env file.</div>
       </div>`;
    document.getElementById("btnRunSearch").disabled = true;
    return;
  }
  loadMetadata();
  bindEvents();
});

function bindEvents() {
  document.getElementById("btnRunSearch").addEventListener("click", () => runSearch("first"));
  document.getElementById("btnResetFilters").addEventListener("click", resetFilters);
  document.getElementById("pagePrev").addEventListener("click", () => runSearch("prev"));
  document.getElementById("pageNext").addEventListener("click", () => runSearch("next"));
  document.getElementById("btnCloseDrawer").addEventListener("click", closeDrawer);
  document.getElementById("ticketDrawerBackdrop").addEventListener("click", closeDrawer);

  // EBS scan + ticket creation
  document.getElementById("btnScanEbs").addEventListener("click", openScanModal);
  document.getElementById("btnRunScan").addEventListener("click", runScan);
  document.getElementById("btnCreateTicket").addEventListener("click", submitTicketCreation);

  // Live JQL preview
  const ids = [
    "filterKeys", "filterText", "filterAssignee", "filterReporter", "filterLabels",
    "filterComponents", "filterFixVersions", "filterSprint", "filterEpic",
    "filterRawJql", "filterOrder",
    "dateCreatedFrom", "dateCreatedTo",
    "dateUpdatedFrom", "dateUpdatedTo",
    "dateResolvedFrom", "dateResolvedTo",
    "dateDueFrom", "dateDueTo",
    "filterProjects", "filterIssueTypes", "filterStatuses",
    "filterPriorities", "filterResolutions",
  ];
  ids.forEach(id => {
    const el = document.getElementById(id);
    if (el) {
      el.addEventListener("change", updateJqlPreview);
      el.addEventListener("input", updateJqlPreview);
    }
  });
  updateJqlPreview();

  // Enter key in text search runs the search
  document.getElementById("filterText").addEventListener("keydown", e => {
    if (e.key === "Enter") { e.preventDefault(); runSearch("first"); }
  });
}

async function loadMetadata() {
  try {
    const r = await fetch("/api/jira/metadata");
    const meta = await r.json();
    jiraState.metadata = meta;
    populateSelect("filterProjects", meta.projects || [],
                   p => p.key, p => `${p.key} — ${p.name}`);
    populateSelect("filterIssueTypes", uniqByName(meta.issue_types || []),
                   t => t.name, t => t.name);
    populateSelect("filterStatuses", uniqByName(meta.statuses || []),
                   s => s.name, s => s.name);
    populateSelect("filterPriorities", uniqByName(meta.priorities || []),
                   p => p.name, p => p.name);
    populateSelect("filterResolutions", uniqByName(meta.resolutions || []),
                   r => r.name, r => r.name);
  } catch (e) {
    console.error("Failed to load JIRA metadata", e);
  }
}

function uniqByName(arr) {
  const seen = new Set();
  return arr.filter(o => {
    if (seen.has(o.name)) return false;
    seen.add(o.name);
    return true;
  });
}

function populateSelect(id, items, valFn, labelFn) {
  const el = document.getElementById(id);
  if (!el) return;
  el.innerHTML = items.map(i =>
    `<option value="${escapeAttr(valFn(i))}">${escapeHtml(labelFn(i))}</option>`
  ).join("");
}

function collectFilters() {
  const multi = id => Array.from(document.getElementById(id).selectedOptions)
                        .map(o => o.value).filter(Boolean);
  const csv = id => {
    const v = document.getElementById(id).value || "";
    return v.split(",").map(s => s.trim()).filter(Boolean);
  };
  return {
    issue_keys:    csv("filterKeys").map(k => k.toUpperCase()),
    text:          document.getElementById("filterText").value.trim(),
    projects:      multi("filterProjects"),
    issue_types:   multi("filterIssueTypes"),
    statuses:      multi("filterStatuses"),
    priorities:    multi("filterPriorities"),
    resolutions:   multi("filterResolutions"),
    assignee:      document.getElementById("filterAssignee").value,
    reporter:      document.getElementById("filterReporter").value,
    labels:        csv("filterLabels"),
    components:    csv("filterComponents"),
    fix_versions:  csv("filterFixVersions"),
    sprint:        document.getElementById("filterSprint").value.trim(),
    epic:          document.getElementById("filterEpic").value.trim(),
    raw_jql:       document.getElementById("filterRawJql").value.trim(),
    order_by:      document.getElementById("filterOrder").value,
    created_from:  document.getElementById("dateCreatedFrom").value,
    created_to:    document.getElementById("dateCreatedTo").value,
    updated_from:  document.getElementById("dateUpdatedFrom").value,
    updated_to:    document.getElementById("dateUpdatedTo").value,
    resolved_from: document.getElementById("dateResolvedFrom").value,
    resolved_to:   document.getElementById("dateResolvedTo").value,
    due_from:      document.getElementById("dateDueFrom").value,
    due_to:        document.getElementById("dateDueTo").value,
  };
}

function buildLocalJqlPreview(f) {
  const parts = [];
  const quote = v => `"${String(v).replace(/"/g, '\\"')}"`;
  const inOrEq = (field, values) => {
    if (!values || !values.length) return;
    if (values.length === 1) parts.push(`${field} = ${quote(values[0])}`);
    else parts.push(`${field} in (${values.map(quote).join(", ")})`);
  };
  inOrEq("issuekey", f.issue_keys);
  inOrEq("project", f.projects);
  inOrEq("issuetype", f.issue_types);
  inOrEq("status", f.statuses);
  inOrEq("priority", f.priorities);
  inOrEq("resolution", f.resolutions);
  inOrEq("labels", f.labels);
  inOrEq("component", f.components);
  inOrEq("fixVersion", f.fix_versions);
  if (f.assignee === "currentUser") parts.push("assignee = currentUser()");
  else if (f.assignee === "unassigned") parts.push("assignee is EMPTY");
  else if (f.assignee) parts.push(`assignee = ${quote(f.assignee)}`);
  if (f.reporter === "currentUser") parts.push("reporter = currentUser()");
  else if (f.reporter) parts.push(`reporter = ${quote(f.reporter)}`);
  if (f.created_from)  parts.push(`created >= "${f.created_from}"`);
  if (f.created_to)    parts.push(`created <= "${f.created_to}"`);
  if (f.updated_from)  parts.push(`updated >= "${f.updated_from}"`);
  if (f.updated_to)    parts.push(`updated <= "${f.updated_to}"`);
  if (f.resolved_from) parts.push(`resolutiondate >= "${f.resolved_from}"`);
  if (f.resolved_to)   parts.push(`resolutiondate <= "${f.resolved_to}"`);
  if (f.due_from)      parts.push(`duedate >= "${f.due_from}"`);
  if (f.due_to)        parts.push(`duedate <= "${f.due_to}"`);
  if (f.text)    parts.push(`text ~ ${quote(f.text)}`);
  if (f.sprint)  parts.push(`sprint = ${quote(f.sprint)}`);
  if (f.epic)    parts.push(`parent = ${quote(f.epic)}`);
  if (f.raw_jql) parts.push(`(${f.raw_jql})`);
  if (!parts.length) parts.push("updated >= -52w");
  const order = `ORDER BY ${f.order_by || "updated DESC"}`;
  return `${parts.join(" AND ")} ${order}`;
}

function updateJqlPreview() {
  const f = collectFilters();
  document.getElementById("jqlPreview").textContent = buildLocalJqlPreview(f);
}

async function runSearch(direction /* "first" | "next" | "prev" */) {
  const btn = document.getElementById("btnRunSearch");
  const spinner = document.getElementById("searchSpinner");
  btn.disabled = true;
  spinner.classList.remove("d-none");

  let token = null;
  let includeCount = false;
  let filters = jiraState.lastFilters;

  if (direction === "first" || !filters) {
    filters = collectFilters();
    jiraState.lastFilters = filters;
    jiraState.tokenStack = [];
    jiraState.currentToken = null;
    jiraState.pageNumber = 1;
    includeCount = true;
    token = null;
  } else if (direction === "next") {
    if (!jiraState.nextToken) { btn.disabled = false; spinner.classList.add("d-none"); return; }
    if (jiraState.currentToken !== null) jiraState.tokenStack.push(jiraState.currentToken);
    else jiraState.tokenStack.push(null);
    jiraState.currentToken = jiraState.nextToken;
    jiraState.pageNumber += 1;
    token = jiraState.currentToken;
  } else if (direction === "prev") {
    if (!jiraState.tokenStack.length) { btn.disabled = false; spinner.classList.add("d-none"); return; }
    token = jiraState.tokenStack.pop();
    jiraState.currentToken = token;
    jiraState.pageNumber = Math.max(1, jiraState.pageNumber - 1);
  }

  try {
    const r = await fetch("/api/jira/search", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        filters,
        next_page_token: token,
        max_results: jiraState.pageSize,
        include_count: includeCount,
      }),
    });
    const data = await r.json();
    if (!r.ok) {
      renderError(data.error || "Search failed", data.jql);
      return;
    }
    if (data.approximate_total !== null && data.approximate_total !== undefined) {
      jiraState.approximateTotal = data.approximate_total;
    }
    jiraState.nextToken = data.next_page_token || null;
    document.getElementById("jqlPreview").textContent = data.jql;
    renderResults(data);
  } catch (e) {
    renderError(`Network error: ${e.message}`);
  } finally {
    btn.disabled = false;
    spinner.classList.add("d-none");
  }
}

function renderResults(data) {
  const body = document.getElementById("resultsBody");
  const summary = document.getElementById("resultsSummary");
  const issues = data.issues || [];

  if (!issues.length) {
    body.innerHTML = `
      <div class="empty-state">
        <i class="fa-regular fa-folder-open"></i>
        <div>No tickets matched your filters.</div>
      </div>`;
    summary.innerHTML = `<span class="muted">No matches</span>`;
    updatePagination();
    return;
  }

  const total = jiraState.approximateTotal;
  const pageNum = jiraState.pageNumber;
  const from = (pageNum - 1) * jiraState.pageSize + 1;
  const to   = from + issues.length - 1;
  const totalStr = (total !== null && total !== undefined && total >= 0)
    ? ` of ~${total.toLocaleString()} ticket${total === 1 ? "" : "s"}`
    : "";
  summary.innerHTML = `
    <span>Showing <b>${from}–${to}</b></span>
    <span class="muted">${totalStr}</span>`;

  const rows = issues.map(renderRow).join("");
  body.innerHTML = `
    <div style="max-height: 65vh; overflow-y: auto;">
      <table class="jira-table">
        <thead>
          <tr>
            <th style="width:90px">Key</th>
            <th style="width:80px">Type</th>
            <th>Summary</th>
            <th style="width:120px">Status</th>
            <th style="width:90px">Priority</th>
            <th style="width:160px">Assignee</th>
            <th style="width:120px">Updated</th>
            <th style="width:200px">Labels</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    </div>`;

  // Row click handlers
  body.querySelectorAll("tr[data-key]").forEach(row => {
    row.addEventListener("click", e => {
      if (e.target.closest("a")) return;
      openTicket(row.dataset.key);
    });
  });

  updatePagination();
}

function renderRow(i) {
  const catSlug = (i.status_category || "").toLowerCase().replace(/\s+/g, "-");
  const typeIcon = i.issuetype_icon
    ? `<img src="${escapeAttr(i.issuetype_icon)}" alt="" style="width:16px;height:16px;vertical-align:middle"> `
    : "";
  const assigneeAvatar = i.assignee_avatar
    ? `<img src="${escapeAttr(i.assignee_avatar)}" alt="">`
    : `<i class="fa-regular fa-circle-user text-muted"></i>`;
  const labels = (i.labels || []).slice(0, 4).map(l =>
    `<span class="label-pill">${escapeHtml(l)}</span>`).join("");
  const moreLabels = (i.labels || []).length > 4
    ? `<span class="label-pill">+${i.labels.length - 4}</span>` : "";

  return `
    <tr data-key="${escapeAttr(i.key)}">
      <td class="key-cell">
        <a href="${escapeAttr(i.url || "#")}" target="_blank" rel="noopener"
           onclick="event.stopPropagation()">${escapeHtml(i.key)}</a>
      </td>
      <td>${typeIcon}<span class="text-muted small">${escapeHtml(i.issuetype || "")}</span></td>
      <td>${escapeHtml(i.summary || "")}</td>
      <td><span class="status-chip cat-${catSlug || "todo"}">${escapeHtml(i.status || "")}</span></td>
      <td>
        <span class="priority-chip priority-${escapeAttr(i.priority || "Medium")}">
          ${i.priority_icon ? `<img src="${escapeAttr(i.priority_icon)}" alt="" style="width:14px;height:14px">` : ""}
          ${escapeHtml(i.priority || "—")}
        </span>
      </td>
      <td>
        <div class="assignee-cell">
          ${assigneeAvatar}
          <span>${escapeHtml(i.assignee || "Unassigned")}</span>
        </div>
      </td>
      <td><span class="text-muted small">${formatDate(i.updated)}</span></td>
      <td><div class="labels-cell">${labels}${moreLabels}</div></td>
    </tr>`;
}

function updatePagination() {
  const prev = document.getElementById("pagePrev");
  const next = document.getElementById("pageNext");
  const info = document.getElementById("pageInfo");
  info.textContent = `Page ${jiraState.pageNumber}`;
  prev.disabled = jiraState.tokenStack.length === 0;
  next.disabled = !jiraState.nextToken;
}

function renderError(msg, jql) {
  document.getElementById("resultsBody").innerHTML = `
    <div class="empty-state">
      <i class="fa-solid fa-circle-exclamation" style="color:var(--critical)"></i>
      <div><b>Search failed.</b></div>
      <div class="mt-2 small" style="max-width:600px;margin:0 auto">${escapeHtml(msg)}</div>
      ${jql ? `<div class="mt-2 small text-muted" style="font-family:monospace">JQL: ${escapeHtml(jql)}</div>` : ""}
    </div>`;
  document.getElementById("resultsSummary").innerHTML =
    `<span class="muted" style="color:var(--critical)">Error</span>`;
}

function resetFilters() {
  document.querySelectorAll(".filter-input").forEach(i => i.value = "");
  document.querySelectorAll(".filter-select").forEach(s => {
    if (s.multiple) Array.from(s.options).forEach(o => o.selected = false);
    else s.selectedIndex = 0;
  });
  document.getElementById("filterOrder").value = "updated DESC";
  updateJqlPreview();
  document.getElementById("resultsBody").innerHTML = `
    <div class="empty-state">
      <i class="fa-brands fa-jira"></i>
      <div>Filters cleared. Apply filters and click Search.</div>
    </div>`;
  document.getElementById("resultsSummary").innerHTML =
    `<span class="muted">No search yet.</span>`;
  jiraState.lastFilters = null;
  jiraState.tokenStack = [];
  jiraState.currentToken = null;
  jiraState.nextToken = null;
  jiraState.pageNumber = 1;
  jiraState.approximateTotal = null;
  updatePagination();
}

/* ─── Drill drawer ───────────────────────────────────────────────────── */

async function openTicket(key) {
  jiraState.currentDrawerKey = key;
  jiraState.lastTroubleshootReport = null;
  document.getElementById("ticketDrawerBackdrop").style.display = "block";
  const drawer = document.getElementById("ticketDrawer");
  drawer.classList.add("open");
  document.getElementById("drawerKey").textContent = key;
  document.getElementById("drawerKey").href = `${window.JIRA_BASE_URL}/browse/${key}`;
  document.getElementById("drawerSummary").textContent = "Loading…";
  document.getElementById("drawerBody").innerHTML = `
    <div class="text-center text-muted py-5">
      <div class="spinner-border" role="status"></div>
      <div class="mt-2 small">Loading ${escapeHtml(key)}…</div>
    </div>`;

  try {
    const r = await fetch(`/api/jira/issue/${encodeURIComponent(key)}`);
    const data = await r.json();
    if (!r.ok) {
      document.getElementById("drawerBody").innerHTML =
        `<div class="alert alert-danger m-3">${escapeHtml(data.error || "Failed to load ticket")}</div>`;
      return;
    }
    document.getElementById("drawerSummary").textContent = data.summary || "(no summary)";
    document.getElementById("drawerBody").innerHTML = renderTicketDetail(data);
    const tsBtn = document.getElementById("btnTroubleshoot");
    if (tsBtn) tsBtn.addEventListener("click", () => runTroubleshoot(data.key));
  } catch (e) {
    document.getElementById("drawerBody").innerHTML =
      `<div class="alert alert-danger m-3">Network error: ${escapeHtml(e.message)}</div>`;
  }
}

function closeDrawer() {
  document.getElementById("ticketDrawer").classList.remove("open");
  document.getElementById("ticketDrawerBackdrop").style.display = "none";
}

function renderTicketDetail(t) {
  const catSlug = (t.status_category || "").toLowerCase().replace(/\s+/g, "-");
  let html = `
    <div class="troubleshoot-actions">
      <button class="btn-troubleshoot" id="btnTroubleshoot">
        <i class="fa-solid fa-stethoscope"></i>
        Troubleshoot in EBS
        <span class="spinner-border spinner-border-sm ms-1 d-none" id="tsSpinner"></span>
      </button>
      <span class="small text-muted ms-2">Claude will pick the right Agentic Apps and run them live.</span>
      <div id="tsResult"></div>
    </div>
    <div class="drawer-meta-row">
      <div><b>Status:</b> <span class="status-chip cat-${catSlug || "todo"}">${escapeHtml(t.status || "—")}</span></div>
      <div><b>Type:</b> ${escapeHtml(t.issuetype || "—")}</div>
      <div><b>Priority:</b> <span class="priority-chip priority-${escapeAttr(t.priority || "Medium")}">${escapeHtml(t.priority || "—")}</span></div>
      <div><b>Project:</b> ${escapeHtml(t.project_key || "")} — ${escapeHtml(t.project_name || "")}</div>
      <div><b>Resolution:</b> ${escapeHtml(t.resolution || "Unresolved")}</div>
      <div><b>Assignee:</b> ${escapeHtml(t.assignee || "Unassigned")}</div>
      <div><b>Reporter:</b> ${escapeHtml(t.reporter || "—")}</div>
      <div><b>Created:</b> ${formatDate(t.created)}</div>
      <div><b>Updated:</b> ${formatDate(t.updated)}</div>
      <div><b>Resolved:</b> ${formatDate(t.resolved) || "—"}</div>
      <div><b>Due:</b> ${formatDate(t.due) || "—"}</div>
    </div>`;

  if ((t.labels || []).length) {
    html += `<div class="drawer-section"><h6>Labels</h6>
      <div class="labels-cell">${t.labels.map(l => `<span class="label-pill">${escapeHtml(l)}</span>`).join("")}</div>
    </div>`;
  }
  if ((t.components || []).length) {
    html += `<div class="drawer-section"><h6>Components</h6>
      <div class="labels-cell">${t.components.map(l => `<span class="label-pill">${escapeHtml(l)}</span>`).join("")}</div>
    </div>`;
  }
  if ((t.fix_versions || []).length) {
    html += `<div class="drawer-section"><h6>Fix Versions</h6>
      <div class="labels-cell">${t.fix_versions.map(l => `<span class="label-pill">${escapeHtml(l)}</span>`).join("")}</div>
    </div>`;
  }

  html += `<div class="drawer-section">
    <h6>Description</h6>
    <div class="drawer-description">${escapeHtml(t.description || "(no description)")}</div>
  </div>`;

  if (t.environment) {
    html += `<div class="drawer-section">
      <h6>Environment</h6>
      <div class="drawer-description">${escapeHtml(t.environment)}</div>
    </div>`;
  }

  if ((t.subtasks || []).length) {
    html += `<div class="drawer-section"><h6>Subtasks (${t.subtasks.length})</h6><ul class="small mb-0">
      ${t.subtasks.map(s => `<li>
        <a href="${window.JIRA_BASE_URL}/browse/${escapeAttr(s.key)}" target="_blank" rel="noopener">${escapeHtml(s.key)}</a>
        — ${escapeHtml(s.summary || "")}
        <span class="text-muted">(${escapeHtml(s.status || "")})</span>
      </li>`).join("")}
    </ul></div>`;
  }

  if ((t.issuelinks || []).length) {
    html += `<div class="drawer-section"><h6>Links</h6><ul class="small mb-0">
      ${t.issuelinks.filter(l => l.key).map(l => `<li>
        <span class="text-muted">${escapeHtml(l.type || "")} →</span>
        <a href="${window.JIRA_BASE_URL}/browse/${escapeAttr(l.key)}" target="_blank" rel="noopener">${escapeHtml(l.key)}</a>
        ${l.summary ? "— " + escapeHtml(l.summary) : ""}
      </li>`).join("")}
    </ul></div>`;
  }

  if ((t.attachments || []).length) {
    html += `<div class="drawer-section"><h6>Attachments (${t.attachments.length})</h6><ul class="small mb-0">
      ${t.attachments.map(a => `<li>
        <a href="${escapeAttr(a.url || "#")}" target="_blank" rel="noopener">${escapeHtml(a.filename || "file")}</a>
        <span class="text-muted">(${formatSize(a.size)})</span>
      </li>`).join("")}
    </ul></div>`;
  }

  if ((t.comments || []).length) {
    html += `<div class="drawer-section"><h6>Comments (${t.comments.length})</h6>
      ${t.comments.map(c => `
        <div class="comment-block">
          <div class="comment-meta"><b>${escapeHtml(c.author || "Unknown")}</b> · ${formatDate(c.created)}</div>
          <div class="comment-body">${escapeHtml(c.body || "")}</div>
        </div>`).join("")}
    </div>`;
  }

  return html;
}

/* ─── helpers ────────────────────────────────────────────────────────── */

function escapeHtml(s) {
  if (s === null || s === undefined) return "";
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}
function escapeAttr(s) { return escapeHtml(s); }

function formatDate(iso) {
  if (!iso) return "";
  try {
    const d = new Date(iso);
    if (isNaN(d.getTime())) return iso;
    return d.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" })
         + " " + d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
  } catch { return iso; }
}

function renderMarkdown(md) {
  if (!md) return "";
  // Strip em-dashes belt-and-braces in case the model slipped any in
  md = md.replace(/\s—\s/g, ". ").replace(/\s–\s/g, ". ")
         .replace(/—/g, ". ").replace(/–/g, ". ");
  try {
    if (window.marked) {
      return marked.parse(md, { breaks: true, gfm: true });
    }
  } catch (e) {
    console.warn("marked failed", e);
  }
  return escapeHtml(md);
}

function formatSize(bytes) {
  if (!bytes && bytes !== 0) return "";
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

/* ═════════════════════════════════════════════════════════════════════════
   EBS -> JIRA: scan errors, generate ticket drafts, create tickets
   ═════════════════════════════════════════════════════════════════════════ */

function openScanModal() {
  const m = bootstrap.Modal.getOrCreateInstance(document.getElementById("scanModal"));
  m.show();
}

async function runScan() {
  const btn = document.getElementById("btnRunScan");
  const spin = document.getElementById("scanSpinner");
  const out = document.getElementById("scanResults");
  const daysBack = Math.max(1, Math.min(365,
    parseInt(document.getElementById("scanDaysBack").value || "30", 10)));
  btn.disabled = true; spin.classList.remove("d-none");
  out.innerHTML = `<div class="text-center py-4 text-muted"><div class="spinner-border"></div><div class="small mt-2">Scanning ${15} EBS Agentic Apps…</div></div>`;

  try {
    const r = await fetch("/api/jira/scan_errors", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ days_back: daysBack }),
    });
    const data = await r.json();
    if (!r.ok) {
      out.innerHTML = `<div class="alert alert-danger">${escapeHtml(data.error || "Scan failed")}</div>`;
      return;
    }
    renderScanResults(data);
  } catch (e) {
    out.innerHTML = `<div class="alert alert-danger">Network error: ${escapeHtml(e.message)}</div>`;
  } finally {
    btn.disabled = false;
    spin.classList.add("d-none");
  }
}

function renderScanResults(data) {
  const out = document.getElementById("scanResults");
  const meta = document.getElementById("scanMeta");
  const items = data.items || [];
  meta.textContent = `${data.total_items} finding${data.total_items === 1 ? "" : "s"}`
    + ` · ${data.elapsed_ms}ms`
    + (data.demo_mode ? " · DEMO" : "");

  if (!items.length) {
    out.innerHTML = `
      <div class="empty-state">
        <i class="fa-regular fa-circle-check" style="color:#1a7f37"></i>
        <div>No CRITICAL/HIGH/MEDIUM findings detected.</div>
      </div>`;
    return;
  }

  const rows = items.map(it => `
    <tr>
      <td><span class="sev-chip sev-${escapeAttr(it.severity)}">${escapeHtml(it.severity)}</span></td>
      <td><b>${escapeHtml(it.app_name)}</b><br>
          <span class="small text-muted">${escapeHtml(it.pillar)}</span></td>
      <td><b>${escapeHtml(it.category || "")}</b><br>
          <span class="small">${escapeHtml(it.description || "")}</span></td>
      <td class="text-end"><b>${(it.count || 0).toLocaleString()}</b></td>
      <td>
        <button class="btn-gen-ticket" data-item-id="${escapeAttr(it.id)}">
          <i class="fa-solid fa-wand-magic-sparkles"></i>
          Generate &amp; Create
        </button>
      </td>
    </tr>
  `).join("");

  out.innerHTML = `
    <table class="scan-table">
      <thead><tr>
        <th style="width:90px">Severity</th>
        <th>App / Pillar</th>
        <th>Finding</th>
        <th style="width:80px;text-align:right">Count</th>
        <th style="width:200px"></th>
      </tr></thead>
      <tbody>${rows}</tbody>
    </table>`;

  // Bind generate buttons
  out.querySelectorAll(".btn-gen-ticket").forEach(btn => {
    btn.addEventListener("click", () => {
      const id = btn.dataset.itemId;
      const item = items.find(x => x.id === id);
      if (item) openDraftModal(item);
    });
  });
}

async function openDraftModal(item) {
  jiraState.currentDraftItem = item;
  // Populate project dropdown from metadata
  const projSel = document.getElementById("draftProject");
  if (projSel && (jiraState.metadata?.projects || []).length) {
    projSel.innerHTML = jiraState.metadata.projects
      .map(p => `<option value="${escapeAttr(p.key)}">${escapeHtml(p.key)} — ${escapeHtml(p.name)}</option>`)
      .join("");
  }
  document.getElementById("draftPriority").value = item.suggested_priority || "Medium";
  document.getElementById("draftError").classList.add("d-none");
  document.getElementById("draftError").textContent = "";

  // Show modal with loading state
  document.getElementById("draftLoading").classList.remove("d-none");
  document.getElementById("draftForm").classList.add("d-none");
  document.getElementById("btnCreateTicket").disabled = true;
  const m = bootstrap.Modal.getOrCreateInstance(document.getElementById("draftModal"));
  m.show();

  try {
    const r = await fetch("/api/jira/generate_ticket", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ item }),
    });
    const draft = await r.json();
    if (!r.ok) {
      showDraftError(draft.error || "Draft generation failed");
      return;
    }
    document.getElementById("draftSummary").value = draft.summary || "";
    document.getElementById("draftDescription").value = draft.description || "";
    document.getElementById("draftLabels").value = (draft.labels || []).join(", ");
    document.getElementById("draftIssueType").value = draft.issue_type || "Task";
    if (draft.priority) document.getElementById("draftPriority").value = draft.priority;
    document.getElementById("draftLoading").classList.add("d-none");
    document.getElementById("draftForm").classList.remove("d-none");
    document.getElementById("btnCreateTicket").disabled = false;
  } catch (e) {
    showDraftError(`Network error: ${e.message}`);
  }
}

function showDraftError(msg) {
  document.getElementById("draftLoading").classList.add("d-none");
  document.getElementById("draftForm").classList.remove("d-none");
  const err = document.getElementById("draftError");
  err.textContent = msg;
  err.classList.remove("d-none");
}

async function submitTicketCreation() {
  const btn = document.getElementById("btnCreateTicket");
  const spin = document.getElementById("createSpinner");
  btn.disabled = true; spin.classList.remove("d-none");

  const labels = document.getElementById("draftLabels").value
    .split(",").map(s => s.trim()).filter(Boolean);

  try {
    const r = await fetch("/api/jira/create_ticket", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        project: document.getElementById("draftProject").value,
        summary: document.getElementById("draftSummary").value,
        description: document.getElementById("draftDescription").value,
        issue_type: document.getElementById("draftIssueType").value,
        priority: document.getElementById("draftPriority").value,
        labels,
      }),
    });
    const data = await r.json();
    if (!r.ok) {
      showDraftError(data.error || "Ticket creation failed");
      return;
    }
    // Success
    const m = bootstrap.Modal.getOrCreateInstance(document.getElementById("draftModal"));
    m.hide();
    showToast(`Created ${data.key}`, data.url);
  } catch (e) {
    showDraftError(`Network error: ${e.message}`);
  } finally {
    btn.disabled = false;
    spin.classList.add("d-none");
  }
}

function showToast(msg, url) {
  const t = document.createElement("div");
  t.style.cssText = `
    position:fixed;bottom:20px;right:20px;z-index:2000;
    background:#1a7f37;color:#fff;padding:12px 18px;border-radius:8px;
    box-shadow:0 4px 12px rgba(0,0,0,.2);font-size:13px;font-weight:600;
    display:flex;gap:10px;align-items:center;`;
  t.innerHTML = `<i class="fa-solid fa-check-circle"></i>
    <span>${escapeHtml(msg)}</span>
    ${url ? `<a href="${escapeAttr(url)}" target="_blank" style="color:#fff;text-decoration:underline">Open</a>` : ""}`;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 6000);
}

/* ═════════════════════════════════════════════════════════════════════════
   JIRA -> EBS troubleshooting
   ═════════════════════════════════════════════════════════════════════════ */

async function runTroubleshoot(key) {
  const btn = document.getElementById("btnTroubleshoot");
  const spin = document.getElementById("tsSpinner");
  const out = document.getElementById("tsResult");
  btn.disabled = true; spin.classList.remove("d-none");
  out.innerHTML = `<div class="ts-report text-muted">Claude is classifying the ticket and running live EBS queries…</div>`;

  try {
    const r = await fetch(`/api/jira/troubleshoot/${encodeURIComponent(key)}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ days_back: 30 }),
    });
    const data = await r.json();
    if (!r.ok) {
      out.innerHTML = `<div class="alert alert-danger mt-2">${escapeHtml(data.error || "Troubleshoot failed")}</div>`;
      return;
    }
    jiraState.lastTroubleshootReport = data;
    out.innerHTML = renderTroubleshootResult(data);
    const postBtn = out.querySelector("#btnPostComment");
    if (postBtn) postBtn.addEventListener("click", () => postReportAsComment(key));
  } catch (e) {
    out.innerHTML = `<div class="alert alert-danger mt-2">Network error: ${escapeHtml(e.message)}</div>`;
  } finally {
    btn.disabled = false;
    spin.classList.add("d-none");
  }
}

function renderTroubleshootResult(data) {
  const cls = data.classification || {};
  const apps = (cls.apps || []).map(a =>
    `<span class="ts-tag">${escapeHtml(a)}</span>`).join("");
  const kws = (cls.keywords || []).map(k =>
    `<span class="ts-tag">${escapeHtml(k)}</span>`).join("");
  let runsHtml = "";
  for (const run of (data.app_runs || [])) {
    const findings = (run.findings || []).map(f => `
      <li><span class="sev-chip sev-${escapeAttr(f.severity)}">${escapeHtml(f.severity)}</span>
        <b>${escapeHtml(f.category)}</b> — ${escapeHtml(f.description)}</li>`).join("");
    runsHtml += `
      <div class="mt-2 small">
        <b>${escapeHtml(run.app_name)}</b>
        ${run.demo_mode ? `<span class="text-muted">(demo)</span>` : ""}
        ${findings ? `<ul class="mb-0 mt-1">${findings}</ul>` :
          `<span class="text-muted"> · no rule triggered</span>`}
      </div>`;
  }
  return `
    <div class="ts-classification">
      <b>Apps chosen:</b> ${apps || "<span class='text-muted'>none</span>"}<br>
      ${kws ? `<b>Keywords:</b> ${kws}<br>` : ""}
      <span class="text-muted">${escapeHtml(cls.rationale || "")}</span>
    </div>
    ${runsHtml}
    <div class="ts-report mt-2">${renderMarkdown(data.report || "")}</div>
    <div class="mt-2 d-flex gap-2">
      <button class="btn-jira-search" id="btnPostComment">
        <i class="fa-regular fa-comment"></i>
        Post Report as JIRA Comment
        <span class="spinner-border spinner-border-sm ms-1 d-none" id="postCommentSpinner"></span>
      </button>
      <span class="text-muted small align-self-center">~${data.elapsed_ms}ms</span>
    </div>
    <div id="postCommentResult"></div>`;
}

async function postReportAsComment(key) {
  const btn = document.getElementById("btnPostComment");
  const spin = document.getElementById("postCommentSpinner");
  const out = document.getElementById("postCommentResult");
  const report = jiraState.lastTroubleshootReport?.report;
  if (!report) return;
  btn.disabled = true; spin.classList.remove("d-none");
  try {
    const r = await fetch(`/api/jira/issue/${encodeURIComponent(key)}/comment`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ body: report }),
    });
    const data = await r.json();
    if (!r.ok) {
      out.innerHTML = `<div class="alert alert-danger mt-2">${escapeHtml(data.error || "Comment failed")}</div>`;
      return;
    }
    out.innerHTML = `<div class="alert alert-success mt-2 small">Comment posted to ${escapeHtml(key)}.
      <a href="${escapeAttr(data.url || "#")}" target="_blank">Open in JIRA</a></div>`;
    btn.disabled = true;
  } catch (e) {
    out.innerHTML = `<div class="alert alert-danger mt-2">Network error: ${escapeHtml(e.message)}</div>`;
    btn.disabled = false;
  } finally {
    spin.classList.add("d-none");
  }
}
