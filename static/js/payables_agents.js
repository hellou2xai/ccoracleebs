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
  el.className = 'ap-status show ap-status-' + sev;
  el.textContent = sev + ' — ' + (data.summary || data.error || '');
}

function apOpenDrawer(data) {
  const drawer = document.getElementById('apDrawer');
  document.getElementById('drawerTitle').textContent =
    (data.agent_label || data.agent_id) + ' — ' + (data.severity || '');
  document.getElementById('drawerBody').innerHTML = apRenderDrawerBody(data);
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

function escHtml(s) {
  if (s === null || s === undefined) return '';
  return String(s).replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

function renderRowsAsTable(rows) {
  if (!rows || !rows.length) return '<p class="text-muted small">No rows.</p>';
  const cols = Object.keys(rows[0]);
  const head = cols.map(c => '<th>' + escHtml(c) + '</th>').join('');
  const body = rows.slice(0, 100).map(r => {
    return '<tr>' + cols.map(c => '<td>' + escHtml(r[c]) + '</td>').join('') + '</tr>';
  }).join('');
  return `<table class="ap-table"><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`;
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
  const head = cols.map(c => '<th>' + escHtml(labels[c] || c) + '</th>').join('');
  const body = queryRows.slice(0, 8).map(r =>
    '<tr>' + cols.map(c => '<td>' + escHtml(r[c]) + '</td>').join('') + '</tr>'
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
    </div>
  `;

  const actions = (data.actions && data.actions.length) ? `
    <h6 style="font-size:12px; margin: 16px 0 6px;"><i class="fa-solid fa-list-check me-1"></i>Recommended Actions</h6>
    <ul class="ap-action-list">
      ${data.actions.map(a => '<li>' + escHtml(a) + '</li>').join('')}
    </ul>` : '';

  const tabBar = `
    <div class="ap-tab-bar">
      <button class="ap-tab active" data-tab="overview">Overview</button>
      ${queryIds.map((qid, i) => {
        const q = queries[qid];
        const lbl = q.label || qid;
        return `<button class="ap-tab" data-tab="q-${qid}">${escHtml(lbl)} (${q.row_count})</button>`;
      }).join('')}
    </div>
  `;

  const primary = pickPrimaryInvoiceQuery(queries);
  const invoiceSnapshot = primary ? `
    <h6 style="font-size:12px; margin: 16px 0 6px;">
      <i class="fa-solid fa-file-invoice me-1"></i>${escHtml(primary.query.label || primary.qid)}
      <span style="color:var(--text-muted); font-weight:normal;"> · ${escHtml(primary.query.row_count)} invoices</span>
    </h6>
    ${renderInvoiceSnapshot(primary.query.rows)}
  ` : '';

  const overviewPane = `
    <div class="ap-tab-pane" data-tab="overview" style="display:block;">
      ${actions}
      ${invoiceSnapshot}
    </div>
  `;

  const queryPanes = queryIds.map(qid => {
    const q = queries[qid];
    return `
      <div class="ap-tab-pane" data-tab="q-${qid}" style="display:none;">
        <div style="font-size:11px; color: var(--text-muted); margin-bottom:8px;">
          ${escHtml(q.label || qid)} · ${escHtml(q.row_count)} rows · ${escHtml(q.execution_time_ms)} ms
        </div>
        ${renderRowsAsTable(q.rows || [])}
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
