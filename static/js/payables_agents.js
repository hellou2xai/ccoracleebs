// Payables Agents page — single-agent runs, run-all fan-out, results drawer.

const apState = {
  daysBack: 30,
  lastResults: {},
};

function getDaysBack() {
  const v = parseInt(document.getElementById('apDaysBack').value, 10);
  apState.daysBack = isFinite(v) && v >= 1 && v <= 365 ? v : 30;
  return apState.daysBack;
}

async function apRunOne(agentId) {
  // Remember results: if we already have this agent's result for the current
  // window, open it instantly instead of re-running from scratch.
  const cached = apState.lastResults[agentId];
  if (cached && !cached.error && cached.days_back === getDaysBack()) {
    apOpenDrawer(cached);
    return;
  }
  const btn = document.getElementById('btn-' + agentId);
  const spin = document.getElementById('spin-' + agentId);
  if (btn.disabled) return;
  btn.disabled = true;
  spin.classList.remove('d-none');

  try {
    const res = await fetch('/api/payables_agents/run/' + agentId, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ days_back: getDaysBack(), source: 'ui' }),
    });
    const data = await res.json();
    apState.lastResults[agentId] = data;
    apRenderCardStatus(agentId, data);
    apOpenDrawer(data);
  } catch (e) {
    apRenderCardStatus(agentId, { severity: 'ERROR', summary: 'Request failed: ' + e });
  } finally {
    btn.disabled = false;
    spin.classList.add('d-none');
  }
}

async function apRunAll() {
  const btn = document.getElementById('btnRunAll');
  const spin = document.getElementById('runAllSpinner');
  btn.disabled = true;
  spin.classList.remove('d-none');

  try {
    const res = await fetch('/api/payables_agents/run_all', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ days_back: getDaysBack(), source: 'ui_run_all' }),
    });
    const data = await res.json();
    Object.entries(data.agents || {}).forEach(([aid, r]) => {
      apState.lastResults[aid] = r;
      apRenderCardStatus(aid, r);
    });
    const c = data.severity_counts || {};
    document.getElementById('sumCritical').textContent = c.CRITICAL || 0;
    document.getElementById('sumHigh').textContent     = c.HIGH || 0;
    document.getElementById('sumMedium').textContent   = c.MEDIUM || 0;
    document.getElementById('sumInfo').textContent     = c.INFO || 0;
    document.getElementById('sumTime').textContent     = (data.execution_time_ms || 0) + ' ms';
  } catch (e) {
    console.error(e);
    alert('Run All failed: ' + e);
  } finally {
    btn.disabled = false;
    spin.classList.add('d-none');
  }
}

function apRenderCardStatus(agentId, data) {
  const el = document.getElementById('status-' + agentId);
  if (!el) return;
  const sev = data.severity || 'INFO';
  el.className = 'ap-status show ap-status-' + sev + ' ap-status-click';
  el.innerHTML =
    '<span class="ap-status-text">' + escHtml(sev + ' — ' + (data.summary || data.error || '')) + '</span>' +
    '<span class="ap-status-view">View details <i class="fa-solid fa-arrow-right-long"></i></span>';
  el.title = 'Click to view full results';
  el.onclick = () => apShowResult(agentId);
}

// Open the drawer from an already-computed result (e.g. after Run All).
// Falls back to running the agent if we have nothing cached.
function apShowResult(agentId) {
  const data = apState.lastResults[agentId];
  if (data) apOpenDrawer(data);
  else apRunOne(agentId);
}

function apOpenDrawer(data) {
  const drawer = document.getElementById('apDrawer');
  document.getElementById('drawerTitle').textContent =
    (data.agent_label || data.agent_id) + ' — ' + (data.severity || '');
  const drawerBody = document.getElementById('drawerBody');
  drawerBody.innerHTML = apRenderDrawerBody(data);
  if (!drawerBody._drillBound) {
    drawerBody.addEventListener('click', apOnDrillClick);
    drawerBody._drillBound = true;
  }
  const filter = document.getElementById('drawerFilter');
  if (filter) { filter.value = ''; filter.oninput = () => apFilterRows(filter.value); }
  drawer.classList.add('open');
  // Tab handlers
  document.querySelectorAll('.ap-tab').forEach(t => {
    t.addEventListener('click', () => {
      document.querySelectorAll('.ap-tab').forEach(x => x.classList.remove('active'));
      t.classList.add('active');
      const tabId = t.dataset.tab;
      document.querySelectorAll('.ap-tab-pane').forEach(p => {
        p.style.display = p.dataset.tab === tabId ? 'block' : 'none';
      });
    });
  });
}

function apCloseDrawer() {
  document.getElementById('apDrawer').classList.remove('open');
}

// Filter the rows of every table in the drawer by a search term (matches any
// cell: vendor, invoice, reason, etc.). Keeps open drill-detail rows in sync.
function apFilterRows(q) {
  const term = (q || '').trim().toLowerCase();
  let shown = 0, total = 0;
  document.querySelectorAll('#drawerBody .ap-tab-pane').forEach(pane => {
    const t = pane.querySelector('table.ap-table');
    if (!t || !t.tBodies[0]) return;
    Array.from(t.tBodies[0].children).forEach(tr => {
      if (tr.classList.contains('ap-drill-detail')) return;
      total++;
      const match = !term || tr.textContent.toLowerCase().includes(term);
      tr.style.display = match ? '' : 'none';
      if (match) shown++;
      const nxt = tr.nextElementSibling;
      if (nxt && nxt.classList.contains('ap-drill-detail')) nxt.style.display = match ? '' : 'none';
    });
  });
  const hint = document.getElementById('drawerFilterHint');
  if (hint) hint.textContent = term ? `${shown} of ${total} rows` : '';
}

function apToggleMaximize() {
  const d = document.getElementById('apDrawer');
  const on = d.classList.toggle('maximized');
  const ic = document.getElementById('drawerMaxIcon');
  if (ic) ic.className = on ? 'fa-solid fa-compress' : 'fa-solid fa-expand';
}

function escHtml(s) {
  if (s === null || s === undefined) return '';
  return String(s).replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

// ── Finance-grade number formatting ─────────────────────────────────────────
function fmtNum(v, dec) {
  const n = Number(v);
  if (v === null || v === undefined || v === '' || !isFinite(n)) return escHtml(v);
  return n.toLocaleString('en-US', { minimumFractionDigits: dec, maximumFractionDigits: dec });
}
function isAmountCol(c) {
  c = c.toLowerCase();
  return c.endsWith('_amount') || c === 'amount' || c === 'amount_remaining' ||
    c.startsWith('bucket_') || c === 'total_outstanding' || c === 'gl_amount' ||
    c === 'discount_amount_remaining' || c === 'unapplied_amount' || c === 'approved_amount' ||
    c === 'base_amount' || c === 'total_discount_available' || c === 'pay_curr_invoice_amount' ||
    c === 'gross_amount' || c === 'cost';
}
function isCountCol(c) {
  c = c.toLowerCase();
  return c.endsWith('_count') || c === 'distinct_accounts' || c === 'dist_lines' ||
    c === 'total_holds' || c === 'total_exceptions' || c === 'total_dup_pairs' ||
    c === 'total_non_po' || c === 'total_unapproved' || c === 'total_open_prepay' ||
    c === 'total_unposted' || c === 'holds_by_type' || c === 'by_hold_type' ||
    c === 'by_source' || c === 'by_approval' || c === 'by_status' ||
    c === 'unposted_journals' || c === 'trx_count' ||
    c === 'failures' || c === 'occurrences';
}
function isNumCol(c) { return isAmountCol(c) || isCountCol(c); }
function fmtCell(col, v) {
  if (v === null || v === undefined) return '';
  if (isAmountCol(col)) return fmtNum(v, 2);
  if (isCountCol(col) && v !== '' && isFinite(Number(v))) return fmtNum(v, 0);
  return escHtml(v);
}

// Aggregate queries whose rows drill down to underlying records (key column).
const GROUP_DRILL = {
  cap_rejections: 'reject_reason', cap_channels: 'source',
  gl_coding_spread: 'vendor_id', supplier_aging: 'vendor_id',
  approvers: 'hold_type', ar_incomplete: 'complete_flag',
  gl_unposted: 'status', cc_failures: 'status_code',
};
const HIDE_COLS = new Set(['invoice_id', 'vendor_id']);
// Internal analytics / window-function columns that repeat on every row — noise.
const NOISE_COLS = new Set([
  'total_exceptions', 'total_holds', 'holds_by_type', 'by_hold_type', 'by_source',
  'by_approval', 'by_status', 'total_unposted', 'total_unapproved', 'total_open_prepay',
  'total_non_po', 'total_dup_pairs', 'total_amount_at_risk', 'avg_days_on_hold',
  'max_days_on_hold', 'avg_cycle_days', 'total_posted', 'total_prepay_amount',
  'total_discount_available', 'total_unpaid',
]);
// Business-first column order; anything not listed follows in its original order.
const COL_ORDER = [
  'invoice_num', 'vendor_name', 'invoice_amount', 'amount', 'invoice_currency_code',
  'hold_lookup_code', 'hold_type', 'hold_reason', 'reason',
  'days_on_hold', 'days_waiting', 'days_outstanding', 'days_old', 'days_to_discount',
  'wfapproval_status', 'current_approver', 'source', 'invoice_date', 'due_date',
  'gl_account', 'amount_remaining', 'discount_amount', 'discount_date', 'urgency',
  'dup_invoice_num', 'dup_invoice_date', 'date_diff_days',
  'trx_number', 'trx_date', 'complete_flag', 'batch_name', 'status', 'created_on',
  'program', 'request_id', 'completion', 'parent_table', 'parent_id', 'rejected_on',
  'capture_mode', 'invoice_count', 'total_amount', 'distinct_accounts', 'dist_lines',
  'line_number', 'line_no', 'line_type', 'description',
];

function prettyCol(c) {
  const O = {
    invoice_num: 'Invoice #', vendor_name: 'Vendor', invoice_amount: 'Amount',
    invoice_currency_code: 'Cur', invoice_date: 'Date', wfapproval_status: 'Approval',
    hold_reason: 'Reason', hold_lookup_code: 'Hold Type', hold_type: 'Hold Type',
    gl_account: 'GL Account', amount_remaining: 'Remaining', due_date: 'Due',
    reject_reason: 'Reject Reason', reject_count: 'Count', invoice_count: 'Invoices',
    total_amount: 'Total Amount', capture_mode: 'Mode', source: 'Source',
    distinct_accounts: 'Accounts Used', dist_lines: 'Lines', days_on_hold: 'Days',
    parent_table: 'Source Table', parent_id: 'Ref', rejected_on: 'Rejected',
    batch_name: 'Batch', created_on: 'Created', program: 'Program', request_id: 'Request',
    status_code: 'Status', completion: 'Completion', trx_number: 'Transaction',
    trx_date: 'Date', complete_flag: 'Complete', line_type: 'Type', line_no: 'Line',
    line_number: 'Line', description: 'Description', amount: 'Amount', gl_date: 'GL Date',
    invoice_type: 'Type', reason: 'Reason',
    receipt_status: 'Receipt Status', receipt_count: 'Receipts', receipt_number: 'Receipt #',
    receipt_date: 'Date', source: 'Sub-Ledger', unposted_journals: 'Unposted', category: 'Category',
    posting_status: 'Status', addition_count: 'Additions', txn_type: 'Transaction Type',
    txn_count: 'Count', trx_count: 'Transactions', journal_name: 'Journal', je_source: 'Source',
    je_category: 'Category', currency_code: 'Cur', cost: 'Cost', queue_name: 'Queue',
    asset_number: 'Asset #', period_name: 'Period', closing_status: 'Status', book_type_code: 'Book',
    program: 'Program', failures: 'Failures', error_signature: 'Error Signature',
    occurrences: 'Occurrences', area: 'Queue', open_count: 'Open Items', owner: 'Route To',
    hold_count: 'Count', completion: 'Completion Text', completed_on: 'Completed',
  };
  if (O[c]) return O[c];
  return c.replace(/_/g, ' ').replace(/\b\w/g, m => m.toUpperCase());
}

function renderRowsAsTable(rows, qid) {
  if (!rows || !rows.length) return '<p class="text-muted small">No rows.</p>';
  const present = Object.keys(rows[0]).filter(c => !HIDE_COLS.has(c) && !NOISE_COLS.has(c));
  const ordered = COL_ORDER.filter(c => present.includes(c));
  const cols = ordered.concat(present.filter(c => !COL_ORDER.includes(c)));
  const drillCol = GROUP_DRILL[qid];
  const hasInvoice = 'invoice_id' in rows[0];
  const head = cols.map(c => `<th class="${isNumCol(c) ? 'num' : ''}">` + escHtml(prettyCol(c)) + '</th>').join('');
  const body = rows.slice(0, 100).map(r => {
    let attrs = '', caret = false;
    if (hasInvoice && r.invoice_id != null) {
      attrs = `class="ap-drill" data-drill="invoice" data-id="${escHtml(r.invoice_id)}"`; caret = true;
    } else if (drillCol && r[drillCol] != null) {
      attrs = `class="ap-drill" data-drill="group" data-qid="${escHtml(qid)}" data-key="${escHtml(r[drillCol])}"`; caret = true;
    }
    const tds = cols.map((c, idx) => {
      const tick = (caret && idx === 0) ? '<span class="ap-caret">▸</span> ' : '';
      return `<td class="${isNumCol(c) ? 'num' : ''}">${tick}${fmtCell(c, r[c])}</td>`;
    }).join('');
    return `<tr ${attrs}>${tds}</tr>`;
  }).join('');
  return `<table class="ap-table"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
}

// Render one invoice's header, lines and GL distributions inside a drill row.
function renderInvoiceDetail(d) {
  if (!d || d.error) return `<div class="text-muted small">Could not load invoice.</div>`;
  const h = (d.header && d.header[0]) || {};
  const kv = [
    ['Invoice #', h.invoice_num], ['Vendor', h.vendor_name],
    ['Amount', (h.invoice_amount != null ? fmtNum(h.invoice_amount, 2) : '') + ' ' + (h.invoice_currency_code || '')],
    ['Type', h.invoice_type], ['Invoice Date', h.invoice_date], ['GL Date', h.gl_date],
    ['Source', h.source], ['Approval', h.wfapproval_status],
  ].filter(x => x[1] != null && String(x[1]).trim() !== '');
  const kvHtml = '<div class="ap-kv">' + kv.map(x => `<span><b>${escHtml(x[0])}:</b> ${escHtml(x[1])}</span>`).join('') + '</div>';
  const lines = (d.lines && d.lines.length) ? '<h6>Lines</h6>' + renderRowsAsTable(d.lines, null) : '';
  const dists = (d.distributions && d.distributions.length) ? '<h6>GL Distributions</h6>' + renderRowsAsTable(d.distributions, null) : '';
  return kvHtml + lines + dists;
}

// Render the underlying records behind an aggregate row.
function renderDrillRows(d) {
  if (!d || d.error) return `<div class="text-muted small">Drill failed.</div>`;
  const n = (d.rows || []).length;
  const title = `<h6>${escHtml(d.title || 'Detail')} · ${n} record${n === 1 ? '' : 's'}${d.demo_mode ? ' · demo' : ''}</h6>`;
  return title + renderRowsAsTable(d.rows || [], '__nested__');
}

async function apOnDrillClick(e) {
  const tr = e.target.closest('tr.ap-drill');
  if (!tr) return;
  const next = tr.nextElementSibling;
  if (next && next.classList.contains('ap-drill-detail')) { next.remove(); tr.classList.remove('open'); return; }
  const span = tr.children.length;
  const detail = document.createElement('tr');
  detail.className = 'ap-drill-detail';
  detail.innerHTML = `<td colspan="${span}"><div class="ap-drill-inner">Loading…</div></td>`;
  tr.after(detail); tr.classList.add('open');
  const inner = detail.querySelector('.ap-drill-inner');
  try {
    let d;
    if (tr.dataset.drill === 'invoice') {
      const res = await fetch('/api/payables_agents/invoice/' + encodeURIComponent(tr.dataset.id));
      d = await res.json(); inner.innerHTML = renderInvoiceDetail(d);
    } else {
      const res = await fetch('/api/payables_agents/drill/' + encodeURIComponent(tr.dataset.qid), {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ key: tr.dataset.key }),
      });
      d = await res.json(); inner.innerHTML = renderDrillRows(d);
    }
  } catch (err) {
    inner.innerHTML = '<div class="text-muted small">Drill failed.</div>';
  }
}

// Pick the friendliest invoice-level query for the Overview snapshot.
// Returns { qid, query } or null if no invoice-level query has rows.
function pickPrimaryInvoiceQuery(queries) {
  const ids = Object.keys(queries);
  // Prefer queries whose first row has both invoice_num and vendor_name.
  for (const qid of ids) {
    const rows = queries[qid].rows || [];
    if (!rows.length) continue;
    const r = rows[0];
    if ('invoice_num' in r && 'vendor_name' in r) return { qid, query: queries[qid] };
  }
  // Fallback: any query with invoice_id rows.
  for (const qid of ids) {
    const rows = queries[qid].rows || [];
    if (rows.length && ('invoice_id' in rows[0] || 'invoice_num' in rows[0])) {
      return { qid, query: queries[qid] };
    }
  }
  return null;
}

// Render a tight invoice-level summary table for the Overview pane.
// Shows business-friendly columns only (no internal IDs).
function renderInvoiceSnapshot(queryRows) {
  if (!queryRows || !queryRows.length) return '';
  const sample = queryRows[0];
  // Choose a curated set of columns based on what's available.
  const order = [
    'invoice_num', 'vendor_name', 'invoice_amount', 'invoice_currency_code',
    'hold_lookup_code', 'hold_type', 'hold_reason',
    'days_on_hold', 'days_waiting', 'days_outstanding', 'days_old',
    'wfapproval_status', 'current_approver',
    'discount_amount', 'discount_date', 'urgency',
    'dup_invoice_num', 'date_diff_days',
    'invoice_date', 'source',
  ];
  const cols = order.filter(c => c in sample);
  if (!cols.length) return '';
  const labels = {
    invoice_num: 'Invoice #', vendor_name: 'Vendor',
    invoice_amount: 'Amount', invoice_currency_code: 'Cur',
    hold_lookup_code: 'Hold Type', hold_type: 'Hold Type', hold_reason: 'Reason',
    days_on_hold: 'Days', days_waiting: 'Days', days_outstanding: 'Days', days_old: 'Days',
    wfapproval_status: 'Approval', current_approver: 'Approver',
    discount_amount: 'Discount', discount_date: 'Discount By', urgency: 'Urgency',
    dup_invoice_num: 'Duplicate Of', date_diff_days: 'Date Δ',
    invoice_date: 'Date', source: 'Source',
  };
  const head = cols.map(c => `<th class="${isNumCol(c) ? 'num' : ''}">` + escHtml(labels[c] || c) + '</th>').join('');
  const body = queryRows.slice(0, 8).map(r =>
    '<tr>' + cols.map(c => `<td class="${isNumCol(c) ? 'num' : ''}">` + fmtCell(c, r[c]) + '</td>').join('') + '</tr>'
  ).join('');
  const more = queryRows.length > 8 ? `<div style="font-size:11px; color: var(--text-muted); margin-top:4px;">Showing 8 of ${queryRows.length}. Open the tab for the full list.</div>` : '';
  return `<table class="ap-table">
    <thead><tr>${head}</tr></thead>
    <tbody>${body}</tbody>
  </table>${more}`;
}

function apRenderDrawerBody(data) {
  const sev = data.severity || 'INFO';
  const queries = data.queries || {};
  const queryIds = Object.keys(queries);

  const summary = `
    <div class="ap-status show ap-status-${sev}" style="margin-bottom: 12px;">
      <strong>${escHtml(sev)}</strong> — ${escHtml(data.summary || data.error || '')}
    </div>
    <div style="font-size:11px; color: var(--text-muted); margin-bottom: 14px;">
      <i class="fa-regular fa-clock"></i> ${escHtml(data.execution_time_ms || 0)} ms
      &nbsp;·&nbsp; <i class="fa-solid fa-table-list"></i> ${escHtml(data.row_count || 0)} rows
      &nbsp;·&nbsp; <i class="fa-regular fa-id-badge"></i> ${escHtml(data.run_id || '')}
      ${data.demo_mode ? '&nbsp;·&nbsp; <span class="badge bg-warning text-dark">demo</span>' : ''}
      ${data.cached ? '&nbsp;·&nbsp; <span class="badge bg-secondary"><i class="fa-solid fa-bolt"></i> cached</span>' : ''}
    </div>
  `;

  const actions = (data.actions && data.actions.length) ? `
    <h6 style="font-size:12px; margin: 16px 0 6px;"><i class="fa-solid fa-list-check me-1"></i>Recommended Actions</h6>
    <ul class="ap-action-list">
      ${data.actions.map(a => '<li>' + escHtml(a) + '</li>').join('')}
    </ul>` : '';

  const tabBar = `
    <div class="ap-tab-bar-wrap">
      <div class="ap-tab-bar">
        <button class="ap-tab active" data-tab="overview">Overview</button>
        ${queryIds.map((qid, i) => {
          const q = queries[qid];
          const lbl = q.label || qid;
          return `<button class="ap-tab" data-tab="q-${qid}">${escHtml(lbl)} (${q.row_count})</button>`;
        }).join('')}
      </div>
      <div class="ap-filter-box">
        <i class="fa-solid fa-magnifying-glass ap-filter-ico"></i>
        <input type="search" class="ap-filter" id="drawerFilter"
               placeholder="Filter by vendor, invoice, reason…" autocomplete="off">
        <span class="ap-filter-hint" id="drawerFilterHint"></span>
      </div>
    </div>
  `;

  // Purpose-aware Overview: lead with THIS agent's primary data. The agent's
  // query list is ordered by relevance, so the first query with rows is its
  // headline signal. Invoice-level data gets the curated snapshot; aggregate
  // data (channels, periods, triage, coding spread) gets a curated table.
  const primaryQid = queryIds.find(q => (queries[q].rows || []).length);
  let primaryData = '';
  if (primaryQid) {
    const pq = queries[primaryQid];
    const rows = pq.rows || [];
    const invoiceLevel = rows.length && ('invoice_num' in rows[0]);
    const noun = invoiceLevel ? 'invoices' : 'records';
    const body = invoiceLevel
      ? renderInvoiceSnapshot(rows)
      : renderRowsAsTable(rows.slice(0, 12), primaryQid);
    primaryData = `
      <h6 style="font-size:12px; margin: 16px 0 6px;">
        <i class="fa-solid fa-table-list me-1"></i>${escHtml(pq.label || primaryQid)}
        <span style="color:var(--text-muted); font-weight:normal;"> · ${escHtml(pq.row_count)} ${noun}</span>
      </h6>
      ${body}`;
  }

  const overviewPane = `
    <div class="ap-tab-pane" data-tab="overview" style="display:block;">
      ${actions}
      ${primaryData}
    </div>
  `;

  const queryPanes = queryIds.map(qid => {
    const q = queries[qid];
    return `
      <div class="ap-tab-pane" data-tab="q-${qid}" style="display:none;">
        <div style="font-size:11px; color: var(--text-muted); margin-bottom:8px;">
          ${escHtml(q.label || qid)} · ${escHtml(q.row_count)} rows · ${escHtml(q.execution_time_ms)} ms
        </div>
        ${renderRowsAsTable(q.rows || [], qid)}
      </div>
    `;
  }).join('');

  return summary + tabBar + overviewPane + queryPanes;
}

function apSendToChat(agentId) {
  const r = apState.lastResults[agentId];
  if (!r) {
    alert('Run the agent first, then send the result to AI.');
    return;
  }
  const msg = `Analyse the result of the ${r.agent_label} agent. Severity ${r.severity}. ${r.summary}`;
  const url = '/?chat=' + encodeURIComponent(msg);
  window.location.href = url;
}
