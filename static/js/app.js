/**
 * Oracle EBS Support Agent — Frontend JavaScript
 * Handles chat streaming, agent dashboard, session management, and charts.
 */

'use strict';

// ─── Theme Toggle ─────────────────────────────────────────────────────────────

function applyTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  const icon = document.getElementById('themeIcon');
  if (icon) {
    icon.className = theme === 'dark' ? 'fa-solid fa-moon' : 'fa-solid fa-sun';
  }
  localStorage.setItem('ebs_theme', theme);
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme') || 'light';
  applyTheme(current === 'dark' ? 'light' : 'dark');
}

// Apply saved theme immediately on load
(function () {
  const saved = localStorage.getItem('ebs_theme') || 'light';
  applyTheme(saved);
})();

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('btnThemeToggle')?.addEventListener('click', toggleTheme);
});

// ─── Oracle Connection ────────────────────────────────────────────────────────

async function submitOracleConnect() {
  const btn     = document.getElementById('btnSubmitConnect');
  const spinner = document.getElementById('connSpinner');
  const alert   = document.getElementById('connAlert');

  const payload = {
    host:         document.getElementById('connHost')?.value.trim(),
    port:         parseInt(document.getElementById('connPort')?.value) || 1521,
    service_name: document.getElementById('connServiceName')?.value.trim(),
    user:         document.getElementById('connUser')?.value.trim(),
    password:     document.getElementById('connPassword')?.value,
    client_dir:   document.getElementById('connClientDir')?.value.trim(),
  };

  // Show spinner
  btn.disabled = true;
  spinner.classList.remove('d-none');
  alert.classList.add('d-none');

  try {
    const res  = await fetch('/api/oracle/connect', {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(payload),
    });
    const data = await res.json();

    if (data.success) {
      alert.className = 'conn-alert conn-alert-success mb-3';
      alert.innerHTML = `<i class="fa-solid fa-circle-check me-2"></i>
        <strong>Connected!</strong> ${data.message}`;
      alert.classList.remove('d-none');
      updateConnectionStatus('live', data.host);

      // Notify other components (e.g. SCP plan list) that Oracle is now connected
      window.dispatchEvent(new CustomEvent('oracle-connected', { detail: data }));

      // Auto-close modal after 1.5 s
      setTimeout(() => {
        bootstrap.Modal.getInstance(document.getElementById('oracleConnectModal'))?.hide();
      }, 1500);
    } else {
      alert.className = 'conn-alert conn-alert-error mb-3';
      alert.innerHTML = `<i class="fa-solid fa-circle-xmark me-2"></i>
        <strong>Connection failed:</strong> ${data.error || 'Unknown error'}
        ${data.suggestion ? `<br><small class="text-muted">${data.suggestion}</small>` : ''}`;
      alert.classList.remove('d-none');
    }
  } catch (err) {
    alert.className = 'conn-alert conn-alert-error mb-3';
    alert.innerHTML = `<i class="fa-solid fa-circle-xmark me-2"></i>Network error: ${err.message}`;
    alert.classList.remove('d-none');
  } finally {
    btn.disabled = false;
    spinner.classList.add('d-none');
  }
}

async function switchDemoMode() {
  try {
    await fetch('/api/oracle/demo', { method: 'POST' });
    updateConnectionStatus('demo', '');
  } catch (_) {}
}

function updateConnectionStatus(mode, host) {
  const modeEl = document.getElementById('connModeDisplay');
  const hostEl = document.getElementById('connHostDisplay');

  if (modeEl) {
    if (mode === 'live') {
      modeEl.innerHTML = '<span class="dot dot-ok"></span> Live';
    } else {
      modeEl.innerHTML = '<span class="dot dot-warn"></span> Demo';
    }
  }
  if (hostEl && host) hostEl.textContent = host;

  // Update navbar badge
  const badge = document.querySelector('.status-badge.status-demo, .status-badge.status-live');
  if (badge) {
    if (mode === 'live') {
      badge.className = 'status-badge status-live';
      badge.innerHTML = '<i class="fa-solid fa-circle fa-xs me-1"></i>Oracle: Connected';
    } else {
      badge.className = 'status-badge status-demo';
      badge.innerHTML = '<i class="fa-solid fa-circle-dot fa-xs me-1"></i>Oracle: Demo Mode';
    }
  }
}

function togglePasswordVisibility() {
  const input = document.getElementById('connPassword');
  const icon  = document.getElementById('connPasswordEyeIcon');
  if (!input) return;
  if (input.type === 'password') {
    input.type  = 'text';
    icon.className = 'fa-solid fa-eye-slash';
  } else {
    input.type  = 'password';
    icon.className = 'fa-solid fa-eye';
  }
}

// ─── Constants ───────────────────────────────────────────────────────────────

// Built-in quick actions (id → {label, icon, message})
const BUILTIN_QUICK_ACTIONS = [
  { id: 'ap-period-close', label: 'AP Period Close',       icon: 'fa-file-invoice-dollar',
    message: 'Run AP period close analysis and identify all blockers preventing the period from closing' },
  { id: 'gl-period-close', label: 'GL Period Close',       icon: 'fa-book',
    message: 'Check GL period close readiness across all ledgers and identify unposted journals' },
  { id: 'month-end',       label: 'Month-End Readiness',   icon: 'fa-calendar-check',
    message: 'Run complete month-end close readiness check for all modules including AP, AR, GL, FA, and CST' },
  { id: 'cp-status',       label: 'CP Manager Status',     icon: 'fa-microchip',
    message: 'Check concurrent manager status and identify any stuck or long-running requests' },
  { id: 'system-health',   label: 'System Health Check',   icon: 'fa-heart-pulse',
    message: 'Run full EBS system health check including database, workflow, and concurrent processing' },
  { id: 'workflow',        label: 'Workflow Notifications', icon: 'fa-diagram-project',
    message: 'Analyze workflow mailer and notification queue status and identify any stuck items' },
];

// Legacy lookup kept for any external references
const QUICK_ACTIONS = Object.fromEntries(BUILTIN_QUICK_ACTIONS.map(a => [a.id, a.message]));

// ─── Quick Actions Manager ────────────────────────────────────────────────────

const QA_STORAGE_KEY = 'ebs_quick_actions_v2';
let _qaAllAgents = null;   // cached agent list for modal

function getQuickActionsConfig() {
  try {
    const saved = localStorage.getItem(QA_STORAGE_KEY);
    if (saved) return JSON.parse(saved);
  } catch (_) {}
  // Default: all built-ins enabled, no agents
  return {
    builtins: BUILTIN_QUICK_ACTIONS.map(a => a.id),
    agents: [],
  };
}

function saveQuickActionsConfig(cfg) {
  localStorage.setItem(QA_STORAGE_KEY, JSON.stringify(cfg));
}

function triggerQuickAction(message) {
  const input = document.getElementById('chatInput');
  if (input) {
    // On chat page — fill and send
    input.value = message;
    if (typeof triggerSend === 'function') triggerSend();
  } else {
    // On other pages — redirect to chat with pre-filled message
    window.location.href = '/?chat=' + encodeURIComponent(message);
  }
}

function renderQuickActions() {
  const container = document.getElementById('quickActionsList');
  if (!container) return;

  const cfg = getQuickActionsConfig();
  const buttons = [];

  // Built-in actions in configured order
  for (const id of cfg.builtins) {
    const action = BUILTIN_QUICK_ACTIONS.find(a => a.id === id);
    if (action) buttons.push({ label: action.label, icon: action.icon, message: action.message });
  }

  // Pinned agents
  for (const agentPin of cfg.agents) {
    buttons.push({
      label:   agentPin.name,
      icon:    'fa-robot',
      message: `Run ${agentPin.name} analysis and show me the findings with diagnostic details`,
    });
  }

  if (!buttons.length) {
    container.innerHTML = '<span class="text-muted small px-1">No quick actions — click ✏️ to add some</span>';
    return;
  }

  container.innerHTML = buttons.map(b => `
    <button class="btn-quick" data-message="${b.message.replace(/"/g, '&quot;')}">
      <i class="fa-solid ${b.icon} fa-sm me-2"></i>${b.label}
    </button>`).join('');

  // Attach listeners
  container.querySelectorAll('.btn-quick').forEach(btn => {
    btn.addEventListener('click', () => triggerQuickAction(btn.dataset.message));
  });
}

// ─── Quick Actions Modal Logic ────────────────────────────────────────────────

async function loadQAAgents() {
  if (_qaAllAgents) return _qaAllAgents;
  try {
    const res = await fetch('/api/agents');
    _qaAllAgents = await res.json();
  } catch (_) {
    _qaAllAgents = [];
  }
  return _qaAllAgents;
}

let _qaPendingConfig = null;  // staging for modal edits

async function openQuickActionsModal() {
  const cfg = getQuickActionsConfig();
  _qaPendingConfig = JSON.parse(JSON.stringify(cfg));

  // Render built-ins
  const builtinList = document.getElementById('qaBuiltinList');
  if (builtinList) {
    builtinList.innerHTML = BUILTIN_QUICK_ACTIONS.map(a => {
      const active = _qaPendingConfig.builtins.includes(a.id);
      return `<label class="qa-toggle-chip ${active ? 'active' : ''}" data-builtin="${a.id}">
        <i class="fa-solid ${a.icon} fa-xs me-1"></i>${a.label}
        <i class="fa-solid fa-${active ? 'check' : 'plus'} fa-xs ms-1 qa-chip-icon"></i>
      </label>`;
    }).join('');

    builtinList.querySelectorAll('.qa-toggle-chip[data-builtin]').forEach(chip => {
      chip.addEventListener('click', () => {
        const id = chip.dataset.builtin;
        const idx = _qaPendingConfig.builtins.indexOf(id);
        if (idx >= 0) {
          _qaPendingConfig.builtins.splice(idx, 1);
          chip.classList.remove('active');
          chip.querySelector('.qa-chip-icon').className = 'fa-solid fa-plus fa-xs ms-1 qa-chip-icon';
        } else {
          _qaPendingConfig.builtins.push(id);
          chip.classList.add('active');
          chip.querySelector('.qa-chip-icon').className = 'fa-solid fa-check fa-xs ms-1 qa-chip-icon';
        }
      });
    });
  }

  // Load and render agents
  const agents = await loadQAAgents();
  renderQAAgentList(agents, '');

  // Search binding
  const searchInput = document.getElementById('qaAgentSearch');
  if (searchInput) {
    searchInput.value = '';
    searchInput.addEventListener('input', () => renderQAAgentList(agents, searchInput.value));
  }
}

function renderQAAgentList(agents, query) {
  const container = document.getElementById('qaAgentList');
  if (!container) return;

  const lq = query.trim().toLowerCase();
  const filtered = lq
    ? agents.filter(a =>
        (a.name || '').toLowerCase().includes(lq) ||
        (a.module || '').toLowerCase().includes(lq) ||
        (a.description || '').toLowerCase().includes(lq))
    : agents;

  if (!filtered.length) {
    container.innerHTML = '<div class="text-muted small text-center py-2">No agents found</div>';
    return;
  }

  container.innerHTML = filtered.slice(0, 100).map(a => {
    const pinned = _qaPendingConfig && _qaPendingConfig.agents.some(p => p.id === a.id);
    return `<div class="qa-agent-row ${pinned ? 'pinned' : ''}" data-agent-id="${a.id}">
      <div class="qa-agent-info">
        <span class="qa-agent-name">${a.name}</span>
        <span class="qa-agent-module">${a.module || ''}</span>
      </div>
      <button class="qa-pin-btn" data-agent-id="${a.id}" data-agent-name="${(a.name||'').replace(/"/g,'&quot;')}">
        <i class="fa-solid fa-${pinned ? 'check' : 'thumbtack'} fa-xs"></i>
      </button>
    </div>`;
  }).join('');

  container.querySelectorAll('.qa-pin-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const id   = btn.dataset.agentId;
      const name = btn.dataset.agentName;
      const idx  = _qaPendingConfig.agents.findIndex(p => p.id === id);
      if (idx >= 0) {
        _qaPendingConfig.agents.splice(idx, 1);
        btn.innerHTML = '<i class="fa-solid fa-thumbtack fa-xs"></i>';
        btn.closest('.qa-agent-row').classList.remove('pinned');
      } else {
        _qaPendingConfig.agents.push({ id, name });
        btn.innerHTML = '<i class="fa-solid fa-check fa-xs"></i>';
        btn.closest('.qa-agent-row').classList.add('pinned');
      }
    });
  });
}

function saveQuickActions() {
  if (_qaPendingConfig) {
    saveQuickActionsConfig(_qaPendingConfig);
    renderQuickActions();
  }
}

function resetQuickActions() {
  _qaPendingConfig = {
    builtins: BUILTIN_QUICK_ACTIONS.map(a => a.id),
    agents: [],
  };
  // Re-render modal chips
  const builtinList = document.getElementById('qaBuiltinList');
  if (builtinList) {
    builtinList.querySelectorAll('.qa-toggle-chip').forEach(chip => {
      chip.classList.add('active');
      chip.querySelector('.qa-chip-icon').className = 'fa-solid fa-check fa-xs ms-1 qa-chip-icon';
    });
  }
  const agents = _qaAllAgents || [];
  renderQAAgentList(agents, document.getElementById('qaAgentSearch')?.value || '');
}

const SEV_ORDER = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO'];
const SEV_COLORS = {
  CRITICAL: '#D64550',
  HIGH:     '#E0A138',
  MEDIUM:   '#4C8DD6',
  LOW:      '#4FA678',
  INFO:     '#98A2B3',
};

// ─── State ────────────────────────────────────────────────────────────────────

const state = {
  sessionId: null,
  findings: [],
  severityCounts: { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 },
  chatHistory: [],     // [{role, content}]
  isLoading: false,
  findingsChart: null,
};

// ─── DOM Helpers ──────────────────────────────────────────────────────────────

const $ = (sel, ctx = document) => ctx.querySelector(sel);
const $$ = (sel, ctx = document) => Array.from(ctx.querySelectorAll(sel));

function el(tag, attrs = {}, ...children) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') e.className = v;
    else if (k === 'html') e.innerHTML = v;
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
    else e.setAttribute(k, v);
  }
  children.forEach(c => c && e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c));
  return e;
}

// ─── Session Management ───────────────────────────────────────────────────────

async function initSession() {
  // Restore from localStorage or create new
  let saved = localStorage.getItem('ebs_session_id');
  if (saved) {
    // Validate session exists server-side
    try {
      const r = await fetch(`/api/sessions/${saved}`);
      if (r.ok) {
        state.sessionId = saved;
        await loadSessionFindings(saved);
        updateSessionUI();
        return;
      }
    } catch (_) {}
  }
  await createNewSession();
}

async function createNewSession() {
  try {
    const r = await fetch('/api/sessions/new', { method: 'POST' });
    const d = await r.json();
    state.sessionId = d.session_id;
    state.findings = [];
    state.severityCounts = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 };
    state.chatHistory = [];
    localStorage.setItem('ebs_session_id', state.sessionId);
    updateSessionUI();
    clearResultsPanel();
  } catch (e) {
    // Fallback: generate client-side UUID
    state.sessionId = crypto.randomUUID ? crypto.randomUUID() : generateUUID();
    localStorage.setItem('ebs_session_id', state.sessionId);
    updateSessionUI();
  }
}

function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.random() * 16 | 0;
    return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
  });
}

async function loadSessionFindings(sessionId) {
  try {
    const r = await fetch(`/api/sessions/${sessionId}/findings`);
    if (!r.ok) return;
    const d = await r.json();
    state.findings = d.findings || [];
    state.severityCounts = d.severity_counts || { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 };
    renderFindingsTable();
    renderFindingsChart();
    updateSeverityPills();
    toggleResultsPanelSections();
  } catch (_) {}
}

function updateSessionUI() {
  const short = state.sessionId ? state.sessionId.substring(0, 12) + '…' : '—';
  const display = $('#sessionIdDisplay');
  if (display) display.textContent = short;

  const tag = $('#currentSessionTag');
  if (tag) tag.textContent = state.sessionId ? state.sessionId.substring(0, 16) + '…' : 'No session';

  const resultSid = $('#resultSessionId');
  if (resultSid) resultSid.textContent = state.sessionId ? state.sessionId.substring(0, 18) + '…' : '—';

  const viewBtn = $('#viewReportBtn');
  if (viewBtn && state.sessionId) {
    viewBtn.href = `/report/${state.sessionId}`;
    viewBtn.style.display = '';
  }
}

function clearResultsPanel() {
  state.findings = [];
  state.severityCounts = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 };
  const tbody = $('#findingsTableBody');
  if (tbody) tbody.innerHTML = '';
  updateSeverityPills();
  renderFindingsChart();
  toggleResultsPanelSections();
}

// ─── Chat Interface ───────────────────────────────────────────────────────────

function initChat() {
  const input   = $('#chatInput');
  const sendBtn = $('#sendBtn');
  const newBtn  = $('#newSessionBtn');
  const diagBtn = $('#fullDiagnosticsBtn');

  input?.addEventListener('input', () => {
    const count = $('#charCount');
    if (count) count.textContent = `${input.value.length} / 4000`;
    autoResizeTextarea(input);
  });

  input?.addEventListener('keydown', e => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      e.preventDefault();
      triggerSend();
    }
  });

  sendBtn?.addEventListener('click', triggerSend);
  newBtn?.addEventListener('click', handleNewSession);
  diagBtn?.addEventListener('click', () => {
    if (input) input.value = 'Run a complete system health and diagnostics check across all EBS modules';
    triggerSend();
  });

}

function triggerSend() {
  const input = $('#chatInput');
  const msg = (input?.value || '').trim();
  if (!msg || state.isLoading) return;
  if (input) input.value = '';
  const cc = $('#charCount');
  if (cc) cc.textContent = '0 / 4000';
  sendMessage(msg);
}

async function handleNewSession() {
  if (state.isLoading) return;
  if (!confirm('Start a new session? Current chat will be cleared.')) return;
  const msgArea = $('#chatMessages');
  if (msgArea) {
    // Keep only welcome message
    const welcome = msgArea.querySelector('.msg-row');
    msgArea.innerHTML = '';
    if (welcome) msgArea.appendChild(welcome);
  }
  await createNewSession();
}

async function sendMessage(message) {
  if (!state.sessionId) await initSession();
  if (state.isLoading) return;

  state.isLoading = true;
  setInputEnabled(false);
  appendUserMessage(message);
  showTypingIndicator();

  // Keep history for context (last 10 turns)
  state.chatHistory.push({ role: 'user', content: message });
  if (state.chatHistory.length > 20) state.chatHistory = state.chatHistory.slice(-20);

  // Track findings and data tables from this exchange
  const exchangeFindings = [];
  const exchangeDataTables = [];
  let responseText = '';
  let finalDone = false;

  try {
    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message,
        session_id: state.sessionId,
        history: state.chatHistory.slice(0, -1),  // exclude the one just added
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop(); // keep incomplete line

      for (const line of lines) {
        if (!line.startsWith('data: ')) continue;
        const raw = line.slice(6).trim();
        if (!raw) continue;

        let data;
        try { data = JSON.parse(raw); }
        catch (_) { continue; }

        handleSSEEvent(data, exchangeFindings, exchangeDataTables);
        if (data.type === 'response') responseText = data.text || '';
        if (data.type === 'done') finalDone = true;
      }
    }

    // Process any remaining buffer
    if (buffer.startsWith('data: ')) {
      try {
        const data = JSON.parse(buffer.slice(6));
        handleSSEEvent(data, exchangeFindings, exchangeDataTables);
        if (data.type === 'response') responseText = data.text || '';
      } catch (_) {}
    }

  } catch (err) {
    console.error('Chat error:', err);
    appendAssistantMessage(`**Connection Error**\n\nFailed to connect to the analysis backend: ${err.message}\n\nPlease check the server and try again.`, []);
  } finally {
    hideTypingIndicator();
    state.isLoading = false;
    setInputEnabled(true);
    $('#chatInput')?.focus();

    // Render any data tables discovered before the response text
    exchangeDataTables.forEach(dt => appendDataTable(dt));

    if (responseText) {
      appendAssistantMessage(responseText, exchangeFindings);
      state.chatHistory.push({ role: 'assistant', content: responseText });
    }

    if (exchangeFindings.length > 0 || finalDone) {
      renderFindingsTable();
      renderFindingsChart();
      updateSeverityPills();
      toggleResultsPanelSections();
      refreshRecentSessions();
    }
  }
}

function handleSSEEvent(data, exchangeFindings, exchangeDataTables) {
  switch (data.type) {
    case 'status':
      updateStatusText(data.text || '');
      break;
    case 'finding':
      exchangeFindings.push(data);
      addFindingToState(data);
      break;
    case 'data_table':
      if (exchangeDataTables) exchangeDataTables.push(data);
      break;
    case 'error':
      updateStatusText(`Error: ${data.text}`);
      break;
    case 'done':
      updateStatusText('Analysis complete');
      break;
  }
}

function appendDataTable(dt) {
  const container = $('#chatMessages');
  if (!container) return;

  const cols = dt.columns || [];
  const rows = dt.rows || [];
  const title = dt.table_name || 'Query Result';
  const rowCount = dt.row_count || rows.length;
  const execMs = dt.execution_time_ms || 0;

  // Build table header
  const thead = el('thead', {},
    el('tr', {}, ...cols.map(c => el('th', {}, c.toUpperCase().replace(/_/g, ' '))))
  );

  // Build table body (limit display to 100 rows)
  const displayRows = rows.slice(0, 100);
  const tbodyRows = displayRows.map(row =>
    el('tr', {}, ...cols.map(c => {
      const val = row[c];
      const strVal = val == null ? '' : String(val);
      return el('td', { title: strVal }, strVal.length > 60 ? strVal.slice(0, 60) + '…' : strVal);
    }))
  );
  const tbody = el('tbody', {}, ...tbodyRows);

  const table = el('table', { class: 'data-result-table' }, thead, tbody);

  const meta = el('div', { class: 'data-table-meta' },
    el('span', {}, `${rowCount} row${rowCount !== 1 ? 's' : ''}`),
    execMs ? el('span', {}, ` · ${execMs}ms`) : null,
    rows.length > 100 ? el('span', { class: 'text-muted' }, ` · showing first 100`) : null
  );

  const wrapper = el('div', { class: 'msg-row msg-assistant' },
    el('div', { class: 'msg-avatar assistant-avatar' }, el('i', { class: 'fa-solid fa-database' })),
    el('div', { class: 'msg-body' },
      el('div', { class: 'data-table-header' },
        el('i', { class: 'fa-solid fa-table fa-xs me-1' }),
        el('span', {}, title.replace(/_/g, ' '))
      ),
      el('div', { class: 'data-table-scroll' }, table),
      meta
    )
  );

  container.appendChild(wrapper);
  scrollToBottom(container);
}

function addFindingToState(finding) {
  state.findings.push(finding);
  const sev = finding.severity || 'INFO';
  if (sev in state.severityCounts) state.severityCounts[sev]++;
}

// ─── Chat DOM Rendering ───────────────────────────────────────────────────────

function appendUserMessage(text) {
  const container = $('#chatMessages');
  if (!container) return;

  const row = el('div', { class: 'msg-row msg-user' },
    el('div', { class: 'msg-avatar' }, el('i', { class: 'fa-solid fa-user' })),
    el('div', { class: 'msg-body' },
      el('div', { class: 'msg-bubble', html: escapeHtml(text).replace(/\n/g, '<br>') }),
      el('div', { class: 'msg-time' }, formatTime(new Date()))
    )
  );
  container.appendChild(row);
  scrollToBottom(container);
}

function appendAssistantMessage(markdownText, findings = []) {
  const container = $('#chatMessages');
  if (!container) return;

  const rendered = typeof marked !== 'undefined'
    ? marked.parse(markdownText || '', { breaks: true, gfm: true })
    : escapeHtml(markdownText || '').replace(/\n/g, '<br>');

  const body = el('div', { class: 'msg-body' },
    el('div', { class: 'msg-bubble', html: rendered }),
    el('div', { class: 'msg-time' }, formatTime(new Date()))
  );

  // Findings attached to this message
  if (findings.length > 0) {
    const findingsDiv = el('div', { class: 'msg-findings' });
    findings.slice(0, 6).forEach(f => {
      findingsDiv.appendChild(buildFindingItem(f));
    });
    if (findings.length > 6) {
      findingsDiv.appendChild(el('div', { class: 'text-muted small px-1' },
        `+${findings.length - 6} more findings — see full report`
      ));
    }
    body.appendChild(findingsDiv);
  }

  const row = el('div', { class: 'msg-row msg-assistant' },
    el('div', { class: 'msg-avatar' }, el('i', { class: 'fa-solid fa-robot' })),
    body
  );
  container.appendChild(row);
  scrollToBottom(container);
}

function buildFindingItem(f) {
  const sev = (f.severity || 'INFO').toLowerCase();
  const item = el('div', { class: `msg-finding-item finding-${sev}` });

  const header = el('div', { class: 'finding-item-header' },
    el('span', { class: `severity-badge severity-${sev}` }, f.severity || 'INFO'),
    el('code', { class: 'small' }, f.analyzer || ''),
    f.module ? el('span', { class: 'text-muted small' }, f.module) : null
  );

  const desc = el('div', { class: 'finding-item-desc' },
    (f.description || '').substring(0, 100) + ((f.description || '').length > 100 ? '…' : '')
  );

  const detail = el('div', { class: 'finding-item-detail' });
  if (f.recommended_action) {
    detail.appendChild(el('p', { class: 'mb-1 small' },
      el('strong', {}, 'Action: '),
      f.recommended_action
    ));
  }
  if (f.mos_references && f.mos_references.length) {
    const refs = f.mos_references.map(r =>
      `<a href="https://support.oracle.com/rs?type=doc&id=${r}" target="_blank" class="mos-ref-link me-1">${r}</a>`
    ).join('');
    detail.insertAdjacentHTML('beforeend', `<div class="small mt-1">MOS: ${refs}</div>`);
  }

  item.appendChild(header);
  item.appendChild(desc);
  item.appendChild(detail);

  // Toggle expand
  item.addEventListener('click', () => {
    detail.classList.toggle('open');
  });

  return item;
}

function showTypingIndicator() {
  const ind = $('#typingIndicator');
  if (ind) ind.classList.remove('d-none');
  scrollToBottom($('#chatMessages'));
}

function hideTypingIndicator() {
  const ind = $('#typingIndicator');
  if (ind) ind.classList.add('d-none');
}

function updateStatusText(text) {
  const el = $('#statusText');
  if (el) el.textContent = text;
  const chatStatus = $('#chatStatusText');
  if (chatStatus) chatStatus.textContent = text;
}

function setInputEnabled(enabled) {
  const input  = $('#chatInput');
  const sendBtn = $('#sendBtn');
  if (input)   input.disabled = !enabled;
  if (sendBtn) sendBtn.disabled = !enabled;
}

function scrollToBottom(container) {
  if (!container) return;
  requestAnimationFrame(() => { container.scrollTop = container.scrollHeight; });
}

function autoResizeTextarea(ta) {
  ta.style.height = 'auto';
  ta.style.height = Math.min(ta.scrollHeight, 120) + 'px';
}

// ─── Results Panel ────────────────────────────────────────────────────────────

function updateSeverityPills() {
  const sc = state.severityCounts;
  const update = (id, label, key) => {
    const pill = $(`#${id}`);
    if (pill) {
      pill.textContent = `${label}: ${sc[key] || 0}`;
      pill.style.display = (sc[key] || 0) === 0 ? 'none' : '';
    }
  };
  update('pillCritical', 'Critical', 'CRITICAL');
  update('pillHigh',     'High',     'HIGH');
  update('pillMedium',   'Medium',   'MEDIUM');
  update('pillLow',      'Low',      'LOW');
  update('pillInfo',     'Info',     'INFO');

  const countEl = $('#resultFindingCount');
  if (countEl) countEl.textContent = state.findings.length;
}

function toggleResultsPanelSections() {
  const hasFindings = state.findings.length > 0;
  const sections = ['sessionInfoSection', 'severitySection', 'findingsTableSection', 'resultsActions'];
  sections.forEach(id => {
    const el = $(`#${id}`);
    if (el) el.style.display = hasFindings ? '' : 'none';
  });
  const emptyEl = $('#emptyResults');
  if (emptyEl) emptyEl.style.display = hasFindings ? 'none' : '';

  const chartContainer = $('#chartContainer');
  if (chartContainer) chartContainer.style.display = hasFindings ? '' : 'none';
}

function renderFindingsTable() {
  const tbody = $('#findingsTableBody');
  if (!tbody) return;
  tbody.innerHTML = '';

  const recent = [...state.findings].reverse().slice(0, 50);
  recent.forEach(f => {
    const sev = (f.severity || 'INFO').toLowerCase();
    const tr = el('tr', {},
      el('td', {},
        el('span', { class: `severity-badge severity-${sev}` }, f.severity || 'INFO')
      ),
      el('td', { class: 'font-mono small' }, f.analyzer || f.analyzer_id || '—'),
      el('td', { class: 'small', html: escapeHtml((f.description || '').substring(0, 90)) +
        ((f.description || '').length > 90 ? '…' : '') })
    );
    tbody.appendChild(tr);
  });
}

function renderFindingsChart() {
  const canvas = $('#findingsChart');
  if (!canvas) return;

  const labels = SEV_ORDER.filter(s => (state.severityCounts[s] || 0) > 0);
  const data   = labels.map(s => state.severityCounts[s] || 0);
  const colors = labels.map(s => SEV_COLORS[s]);

  if (labels.length === 0) {
    if (state.findingsChart) { state.findingsChart.destroy(); state.findingsChart = null; }
    return;
  }

  if (state.findingsChart) {
    state.findingsChart.data.labels = labels;
    state.findingsChart.data.datasets[0].data = data;
    state.findingsChart.data.datasets[0].backgroundColor = colors;
    state.findingsChart.update();
    return;
  }

  state.findingsChart = new Chart(canvas, {
    type: 'doughnut',
    data: {
      labels,
      datasets: [{
        data,
        backgroundColor: colors,
        borderColor: '#ffffff',
        borderWidth: 3,
        borderRadius: 4,
        hoverOffset: 6,
        spacing: 1,
      }],
    },
    options: {
      cutout: '72%',
      layout: { padding: 6 },
      plugins: {
        legend: {
          position: 'bottom',
          labels: {
            color: '#475467',
            font: { size: 11, weight: '600' },
            padding: 14,
            usePointStyle: true,
            pointStyle: 'circle',
            boxWidth: 8,
            boxHeight: 8,
          },
        },
        tooltip: {
          backgroundColor: '#101828',
          titleColor: '#ffffff',
          bodyColor: '#D0D5DD',
          padding: 10,
          cornerRadius: 6,
          displayColors: true,
          boxPadding: 4,
        },
      },
      animation: { animateRotate: true, duration: 500, easing: 'easeOutQuart' },
    },
    plugins: [{
      id: 'severityCenterText',
      afterDraw(chart) {
        const total = chart.data.datasets[0].data.reduce((a, b) => a + b, 0);
        if (!total) return;
        const { ctx, chartArea: { left, right, top, bottom } } = chart;
        const cx = (left + right) / 2;
        const cy = (top + bottom) / 2;
        ctx.save();
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillStyle = '#101828';
        ctx.font = '700 26px Arial, sans-serif';
        ctx.fillText(String(total), cx, cy - 7);
        ctx.fillStyle = '#667085';
        ctx.font = '600 10px Arial, sans-serif';
        ctx.fillText('FINDINGS', cx, cy + 15);
        ctx.restore();
      },
    }],
  });
}

// ─── Export Functions ─────────────────────────────────────────────────────────

async function downloadMarkdown(sessionId) {
  const sid = sessionId || state.sessionId;
  if (!sid) { alert('No session selected.'); return; }
  try {
    const r = await fetch(`/api/sessions/${sid}/report`);
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    const d = await r.json();
    const md = d.report_markdown || '# No report available';
    triggerDownload(md, `ebs-report-${sid.substring(0, 8)}.md`, 'text/markdown');
  } catch (e) {
    alert(`Failed to download report: ${e.message}`);
  }
}

function triggerDownload(content, filename, mimeType) {
  const blob = new Blob([content], { type: mimeType });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 1000);
}

function copyToClipboard(text) {
  if (navigator.clipboard) {
    return navigator.clipboard.writeText(text);
  }
  // Fallback
  const ta = document.createElement('textarea');
  ta.value = text;
  ta.style.position = 'fixed';
  ta.style.opacity = '0';
  document.body.appendChild(ta);
  ta.focus();
  ta.select();
  document.execCommand('copy');
  ta.remove();
  return Promise.resolve();
}

// ─── Sidebar: Recent Sessions ─────────────────────────────────────────────────

async function refreshRecentSessions() {
  try {
    const r = await fetch('/api/sessions?limit=5');
    if (!r.ok) return;
    const d = await r.json();
    const list = $('#recentSessionsList');
    if (!list) return;

    list.innerHTML = '';
    (d.sessions || []).forEach(s => {
      const link = el('a',
        { href: `/report/${s.session_id}`, class: 'session-link' },
        el('span', { class: 'session-id-short' }, (s.session_id || '').substring(0, 8) + '…'),
        el('span', { class: 'session-time' }, (s.created_at || '').substring(0, 10))
      );
      list.appendChild(link);
    });
    if (!d.sessions || d.sessions.length === 0) {
      list.innerHTML = '<p class="text-muted small px-1">No sessions yet.</p>';
    }
  } catch (_) {}
}

// ─── Dashboard: Agent Browser ────────────────────────────────────────────────

function initDashboard() {
  const searchInput = $('#analyzerSearch');
  const searchClear = $('#searchClear');
  const cards = $$('.analyzer-card');

  // Search
  searchInput?.addEventListener('input', () => {
    const val = (searchInput.value || '').trim();
    if (searchClear) searchClear.classList.toggle('d-none', !val);
    applyDashboardFilters();
  });

  searchClear?.addEventListener('click', () => {
    if (searchInput) searchInput.value = '';
    if (searchClear) searchClear.classList.add('d-none');
    applyDashboardFilters();
  });

  // Module tabs
  $$('.module-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      $$('.module-tab').forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      applyDashboardFilters();
    });
  });

  // Run Now buttons
  $$('.btn-run-now').forEach(btn => {
    btn.addEventListener('click', () => {
      const analyzerId   = btn.dataset.analyzerId;
      const analyzerName = btn.dataset.analyzerName;
      openRunModal(analyzerId, analyzerName);
    });
  });

  // Export markdown from dashboard
  const exportBtn = $('#exportMarkdownBtn');
  if (exportBtn) {
    exportBtn.addEventListener('click', () => downloadMarkdown(state.sessionId));
  }
}

function applyDashboardFilters() {
  const query  = ($('#analyzerSearch')?.value || '').toLowerCase().trim();
  const module = ($('.module-tab.active')?.dataset.module || 'ALL').toUpperCase();
  const cards  = $$('.analyzer-card');
  let visible  = 0;

  cards.forEach(card => {
    const cardModule = (card.dataset.module || '').toUpperCase();
    const matchMod   = module === 'ALL' || cardModule === module;
    const matchQuery = !query ||
      (card.dataset.name || '').includes(query) ||
      (card.dataset.keywords || '').includes(query) ||
      (card.dataset.description || '').includes(query) ||
      (card.dataset.id || '').includes(query);

    const show = matchMod && matchQuery;
    card.style.display = show ? '' : 'none';
    if (show) visible++;
  });

  const countEl = $('#filteredCount');
  if (countEl) countEl.textContent = `${visible} shown`;

  const noResults = $('#noResults');
  if (noResults) noResults.classList.toggle('d-none', visible > 0);
}

// ─── Run Agent Modal ──────────────────────────────────────────────────────────

let _runModalInstance = null;

async function openRunModal(analyzerId, analyzerName) {
  if (!state.sessionId) await initSession();

  const nameEl  = $('#modalAnalyzerName');
  if (nameEl) nameEl.textContent = analyzerName || analyzerId;

  // Reset modal state
  $('#runModalLoading')?.classList.remove('d-none');
  $('#runModalResults')?.classList.add('d-none');
  $('#runModalError')?.classList.add('d-none');
  $('#execTimeBadge')?.classList.add('d-none');
  $('#modalViewReportBtn')?.classList.add('d-none');

  const modalEl = document.getElementById('runModal');
  if (!modalEl) return;
  _runModalInstance = bootstrap.Modal.getOrCreateInstance(modalEl);
  _runModalInstance.show();

  try {
    const r = await fetch('/api/run-analyzer', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ analyzer_id: analyzerId, session_id: state.sessionId }),
    });
    const d = await r.json();

    if (!r.ok || d.error) throw new Error(d.error || `HTTP ${r.status}`);

    // Show execution time
    const timeBadge = $('#execTimeBadge');
    if (timeBadge) {
      timeBadge.classList.remove('d-none');
      const tv = $('#execTimeVal');
      if (tv) tv.textContent = d.execution_time_ms || 0;
    }

    // Populate findings
    const findings = d.findings || [];
    const findingCount = $('#modalFindingCount');
    if (findingCount) findingCount.textContent = findings.length;

    const content = $('#modalFindingsContent');
    if (content) {
      content.innerHTML = '';
      if (findings.length === 0) {
        content.innerHTML = '<p class="text-muted small">No findings — analyzer completed successfully.</p>';
      } else {
        findings.forEach(f => {
          const sev = (f.severity || 'INFO').toLowerCase();
          const card = el('div', { class: `finding-card finding-${sev} mb-2` },
            el('div', { class: 'finding-card-header mb-1' },
              el('span', { class: `severity-badge severity-${sev} me-2` }, f.severity || 'INFO'),
              el('span', { class: 'finding-analyzer-badge me-2' }, f.analyzer_id || ''),
              f.module ? el('span', { class: 'finding-module-badge' }, f.module) : null
            ),
            el('p', { class: 'finding-description mb-1' }, f.description || ''),
            f.recommended_action
              ? el('div', { class: 'finding-action', html:
                  `<span class="finding-action-label">Recommended Action</span>${escapeHtml(f.recommended_action)}`
                })
              : null
          );
          content.appendChild(card);

          // Also add to state
          addFindingToState(f);
        });

        // Refresh results panel
        renderFindingsTable();
        renderFindingsChart();
        updateSeverityPills();
        toggleResultsPanelSections();
      }
    }

    // Raw output
    const rawCode = $('#rawOutputCode');
    if (rawCode) rawCode.textContent = d.raw_output || '(no output)';

    // View report button
    const viewBtn = $('#modalViewReportBtn');
    if (viewBtn) {
      viewBtn.classList.remove('d-none');
      viewBtn.onclick = () => { window.location.href = `/report/${state.sessionId}`; };
    }

    $('#runModalLoading')?.classList.add('d-none');
    $('#runModalResults')?.classList.remove('d-none');

  } catch (err) {
    $('#runModalLoading')?.classList.add('d-none');
    $('#runModalError')?.classList.remove('d-none');
    const errText = $('#runModalErrorText');
    if (errText) errText.textContent = err.message || 'Unknown error';
  }

  // Raw output toggle
  const toggleRaw = $('#toggleRawBtn');
  if (toggleRaw) {
    toggleRaw.onclick = () => {
      const pre = $('#rawOutputPre');
      if (pre) {
        pre.classList.toggle('d-none');
        toggleRaw.textContent = pre.classList.contains('d-none') ? 'Show' : 'Hide';
      }
    };
  }
}

// ─── Utility Functions ────────────────────────────────────────────────────────

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatTime(date) {
  return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function severityBadge(severity) {
  const sev = (severity || 'INFO').toLowerCase();
  return `<span class="severity-badge severity-${sev}">${severity || 'INFO'}</span>`;
}

function formatFinding(finding) {
  const sev = (finding.severity || 'INFO').toLowerCase();
  return `<div class="finding-card finding-${sev}">
    <div class="finding-card-header">
      ${severityBadge(finding.severity)}
      <code class="finding-analyzer-badge ms-2">${escapeHtml(finding.analyzer_id || '')}</code>
    </div>
    <p class="finding-description">${escapeHtml(finding.description || '')}</p>
  </div>`;
}

// ─── Export buttons on report page ───────────────────────────────────────────

function initReportPage() {
  const dlBtn = $('#downloadMdBtn');
  if (dlBtn && window.EBS_SESSION_ID) {
    dlBtn.addEventListener('click', () => downloadMarkdown(window.EBS_SESSION_ID));
  }
  const copyBtn = $('#copyReportBtn');
  if (copyBtn && window.EBS_REPORT_MD) {
    copyBtn.addEventListener('click', function() {
      copyToClipboard(window.EBS_REPORT_MD).then(() => {
        this.innerHTML = '<i class="fa-solid fa-check me-1"></i>Copied!';
        setTimeout(() => { this.innerHTML = '<i class="fa-solid fa-clipboard me-1"></i>Copy'; }, 2000);
      });
    });
  }
}

// Export markdown button on chat results panel
function initExportBtn() {
  const btn = $('#exportMarkdownBtn');
  if (btn) btn.addEventListener('click', () => downloadMarkdown(state.sessionId));
}

// ─── Agents Panel (Chat Page) ─────────────────────────────────────────────────

let _allAgents = [];  // loaded once from /api/analyzers

async function loadAgentsPanel() {
  try {
    const res  = await fetch('/api/analyzers');
    _allAgents = await res.json();
    if (!Array.isArray(_allAgents)) _allAgents = _allAgents.analyzers || [];
    // Update tab count
    const countEl = document.getElementById('agentsTabCount');
    if (countEl) countEl.textContent = _allAgents.length;
    renderAgentsList(_allAgents);
  } catch (e) {
    const list = document.getElementById('agentsList');
    if (list) list.innerHTML = '<p class="agents-no-results">Failed to load agents.</p>';
  }
}

function renderAgentsList(agents) {
  const list = document.getElementById('agentsList');
  if (!list) return;

  if (!agents.length) {
    list.innerHTML = '<p class="agents-no-results"><i class="fa-solid fa-search fa-sm me-1"></i>No agents match.</p>';
    return;
  }

  const MODULE_LABEL = { ATG: 'ATG', FINANCIALS: 'Financials', MANUFACTURING: 'Mfg', HCM: 'HCM', CRM: 'CRM' };

  list.innerHTML = agents.map(a => {
    const modClass = 'module-pill-' + (a.module || '').toLowerCase();
    const modLabel = MODULE_LABEL[a.module] || a.module || '';
    const subMod   = a.sub_module ? `<span class="agent-item-sub">${a.sub_module}</span>` : '';
    return `
      <div class="agent-item" data-id="${a.id}" data-module="${a.module}">
        <div class="agent-item-info">
          <div class="agent-item-name" title="${a.name}">${a.name}</div>
          ${subMod}
        </div>
        <div class="agent-item-actions">
          <span class="agent-module-pill ${modClass}">${modLabel}</span>
          <button class="btn-agent-run" onclick="runAgentFromPanel('${a.id}', '${a.name.replace(/'/g, "\\'")}')">
            Run
          </button>
        </div>
      </div>`;
  }).join('');
}

function filterAgentsList() {
  const query  = (document.getElementById('agentSearchInput')?.value || '').toLowerCase().trim();
  const module = document.querySelector('.agent-module-btn.active')?.dataset.module || 'ALL';

  const filtered = _allAgents.filter(a => {
    const matchMod = module === 'ALL' || a.module === module;
    const matchQ   = !query ||
      (a.name || '').toLowerCase().includes(query) ||
      (a.sub_module || '').toLowerCase().includes(query) ||
      (a.keywords || []).some(k => k.toLowerCase().includes(query));
    return matchMod && matchQ;
  });
  renderAgentsList(filtered);
}

async function runAgentFromPanel(agentId, agentName) {
  // Send as a chat message so it goes through the orchestrator
  const input = document.getElementById('chatInput');
  if (input) {
    // Switch to Analysis tab
    switchResultsTab('analysis');
    // Populate input and send
    const msg = `Run ${agentName} agent and show me the results`;
    input.value = msg;
    const cc = document.getElementById('charCount');
    if (cc) cc.textContent = `${msg.length} / 4000`;
    triggerSend();
  }
}

function switchResultsTab(tab) {
  $$('.results-tab').forEach(t => t.classList.toggle('active', t.dataset.tab === tab));
  $$('.tab-pane').forEach(p => {
    const isActive = p.id === 'pane' + tab.charAt(0).toUpperCase() + tab.slice(1);
    p.classList.toggle('d-none', !isActive);
    p.classList.toggle('active', isActive);
  });
}

function initAgentsPanel() {
  // Tab switching
  $$('.results-tab').forEach(tab => {
    tab.addEventListener('click', () => {
      switchResultsTab(tab.dataset.tab);
      if (tab.dataset.tab === 'agents' && !_allAgents.length) loadAgentsPanel();
    });
  });

  // Module filter buttons
  $$('.agent-module-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      $$('.agent-module-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      filterAgentsList();
    });
  });

  // Search input
  document.getElementById('agentSearchInput')?.addEventListener('input', filterAgentsList);

  // Pre-load agents in background
  loadAgentsPanel();
}

// ─── Entry Point ──────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', async () => {
  const page = window.EBS_PAGE || 'chat';

  // ── Quick Actions — runs on every page ──────────────────────────────────
  renderQuickActions();

  // Wire the edit modal open event
  const qaModal = document.getElementById('quickActionsModal');
  if (qaModal) {
    qaModal.addEventListener('show.bs.modal', openQuickActionsModal);
  }

  // Common: init session from localStorage/server
  await initSession();

  if (page === 'chat') {
    initChat();
    initAgentsPanel();
    initExportBtn();
  } else if (page === 'dashboard') {
    initDashboard();
  } else if (page === 'report') {
    initReportPage();
  }

  // Load EBS version into sidebar
  fetch('/api/system/health').then(r => r.json()).then(d => {
    const v = document.getElementById('ebsVersionSidebar');
    if (v) v.textContent = d.ebs_version || '12.2.x';
  }).catch(() => {});

  // Refresh recent sessions list
  await refreshRecentSessions();
});

// Expose for use in templates
window.downloadMarkdown = downloadMarkdown;
window.copyToClipboard  = copyToClipboard;
