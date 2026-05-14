/**
 * Oracle EBS — Payables Agentic App
 * Full client-side logic: run, render, drill-down, CSV export, AI send.
 */

'use strict';

// ── State ────────────────────────────────────────────────────────────────────

const payState = {
  running: false,
  data: null,
  daysBack: 30,
  activeTab: 'health',
  selectedHold: null,
  selectedInvoiceId: null,
  selectedVendorId: null,
};

// ── Hold action lookup (mirrors server-side HOLD_ACTIONS) ────────────────────

const HOLD_ACTIONS = {
  'PRICE':          { owner: 'Buyer',      actionTpl: (r) => `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: ${r.hold_reason || 'price mismatch'}. Compare invoice unit price to PO line price in PO > Inquiry > PO ${r.po_header_id ? '#' + r.po_header_id : ''}. Contact buyer to update PO or request credit memo from ${r.vendor_name || 'supplier'}. Hold age: ${r.days_on_hold || '—'} days.` },
  'QTY ORDERED':    { owner: 'Buyer',      actionTpl: (r) => `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: ${r.hold_reason || 'qty exceeds PO qty'}. Buyer must issue a PO amendment or ${r.vendor_name || 'supplier'} must issue a partial invoice. Hold age: ${r.days_on_hold || '—'} days.` },
  'QTY RECEIVED':   { owner: 'Receiving',  actionTpl: (r) => `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: ${r.hold_reason || 'qty exceeds received qty'}. Verify receipt in Inventory > Receiving > Receipts for vendor ${r.vendor_name || '—'} — goods may not have been processed. Hold age: ${r.days_on_hold || '—'} days.` },
  'AMOUNT ORDERED': { owner: 'Buyer',      actionTpl: (r) => `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: ${r.hold_reason || 'amount exceeds PO amount'}. PO amendment required from buyer. Hold age: ${r.days_on_hold || '—'} days.` },
  'VARIANCE':       { owner: 'AP Manager', actionTpl: (r) => `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: ${r.hold_reason || 'amount variance beyond tolerance'}. Review in AP > Invoice Inquiry > ${r.invoice_num || '—'} and approve manually or request corrected invoice from ${r.vendor_name || 'supplier'}. Hold age: ${r.days_on_hold || '—'} days.` },
  'ACCOUNT':        { owner: 'AP Manager', actionTpl: (r) => `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: ${r.hold_reason || 'distribution account invalid or inactive'}. Update account coding in AP > Invoice > Distributions for ${r.invoice_num || '—'} and revalidate. Hold age: ${r.days_on_hold || '—'} days.` },
  'FUNDS':          { owner: 'Budget Mgr', actionTpl: (r) => `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: budget check failed. Request budget override or recharge to funded account. Hold age: ${r.days_on_hold || '—'} days.` },
  'MANUAL':         { owner: 'AP Clerk',   actionTpl: (r) => `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: ${r.hold_reason || 'manual hold applied'}. Release hold in AP > Invoice Actions > Release Hold on ${r.invoice_num || '—'} once issue is resolved. Hold age: ${r.days_on_hold || '—'} days.` },
  'TAX':            { owner: 'Tax Team',   actionTpl: (r) => `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: tax calculation error. Review tax lines in AP > Invoice > Tax Details for ${r.invoice_num || '—'} and correct or contact tax team. Hold age: ${r.days_on_hold || '—'} days.` },
  'DUPLICATE':      { owner: 'AP Clerk',   actionTpl: (r) => `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: ${r.hold_reason || 'potential duplicate invoice'}. Verify against existing invoices in AP > Invoice Inquiry before releasing. Hold age: ${r.days_on_hold || '—'} days.` },
};

function getHoldAction(holdType, row) {
  const key = (holdType || '').toUpperCase().replace(/_/g, ' ');
  for (const [k, v] of Object.entries(HOLD_ACTIONS)) {
    if (k.includes(key) || key.includes(k)) {
      return { owner: v.owner, action: row ? v.actionTpl(row) : v.actionTpl({}) };
    }
  }
  const r = row || {};
  return { owner: 'AP Team', action: `Invoice ${r.invoice_num || '—'} ($${formatNum(r.invoice_amount || 0)}) from ${r.vendor_name || '—'}: ${r.hold_reason || holdType || 'unknown hold'}. Review hold reason and contact appropriate team to resolve. Hold age: ${r.days_on_hold || '—'} days.` };
}

// ── Main run function ────────────────────────────────────────────────────────

async function runPayablesAnalysis() {
  if (payState.running) return;

  const daysInput = document.getElementById('payDaysBack');
  const daysBack = Math.max(1, Math.min(365, parseInt(daysInput.value) || 30));
  payState.daysBack = daysBack;

  // Set loading state
  payState.running = true;
  setRunButtonState(true);
  clearAllPanes();

  try {
    const resp = await fetch('/api/payables/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ days_back: daysBack }),
    });

    if (!resp.ok) {
      const err = await resp.json().catch(() => ({ error: `HTTP ${resp.status}` }));
      throw new Error(err.error || `HTTP ${resp.status}`);
    }

    const data = await resp.json();
    payState.data = data;

    // Demo banner
    const banner = document.getElementById('payDemoBanner');
    if (data.demo_mode) {
      banner.classList.remove('d-none');
    } else {
      banner.classList.add('d-none');
    }

    // Exec time
    const ms = data.execution_time_ms || 0;
    const sec = (ms / 1000).toFixed(1);
    document.getElementById('payExecInfo').textContent =
      `Completed in ${sec}s · Last ${daysBack} days`;

    // Render everything
    updateKPIs(data.kpis, data.demo_mode);
    renderFindings(data.findings);
    renderHealthTab(data.queries.invoice_health, data.demo_mode);
    renderHoldsTab(data.queries.holds, data.demo_mode);
    renderApproversTab(data.queries.approvers, data.demo_mode);
    renderDiscountsTab(data.queries.discounts, data.demo_mode);
    renderCloseIssuesTab(data, data.demo_mode);
    renderUnapprovedTab(data.queries.unapproved_invoices,  data.demo_mode);
    renderDuplicateTab(data.queries.duplicate_risk,        data.demo_mode);
    renderNonPoTab(data.queries.non_po_invoices,           data.demo_mode);
    renderAgingTab(data.queries.supplier_aging,            data.demo_mode);
    renderMatchExcTab(data.queries.match_exceptions,       data.demo_mode);
    renderCycleTimeTab(data.queries.cycle_time,            data.demo_mode);
    renderPrepayTab(data.queries.open_prepayments,         data.demo_mode);
    renderBottleneckTab(data.queries.approval_bottleneck,  data.demo_mode);
    renderAITab(data.kpis, data.findings, data.demo_mode);

    // Update tab counts
    updateTabCounts(data.queries);

    // Persist to sessionStorage so navigation doesn't lose the data
    savePayablesState(data, daysBack);

  } catch (err) {
    console.error('Payables run error:', err);
    document.getElementById('payExecInfo').textContent = '';
    showGlobalError(err.message || 'Analysis failed. Check console for details.');
  } finally {
    payState.running = false;
    setRunButtonState(false);
  }
}

// ── Button state ─────────────────────────────────────────────────────────────

function setRunButtonState(loading) {
  const btn     = document.getElementById('payRunBtn');
  const icon    = document.getElementById('payRunIcon');
  const label   = document.getElementById('payRunLabel');
  const spinner = document.getElementById('payRunSpinner');

  btn.disabled = loading;
  if (loading) {
    icon.className = 'fa-solid fa-play fa-xs d-none';
    label.textContent = 'Analyzing…';
    spinner.classList.remove('d-none');
  } else {
    icon.className = 'fa-solid fa-play fa-xs';
    label.textContent = 'Run Analysis';
    spinner.classList.add('d-none');
  }
}

// ── Clear panes ──────────────────────────────────────────────────────────────

function clearAllPanes() {
  ['health','holds','approvers','discounts','close',
   'unapproved','duplicate','nopo','aging','matchexc','cycletime','prepay','bottleneck'].forEach(tab => {
    const empty   = document.getElementById(tab + 'Empty');
    const content = document.getElementById(tab + 'Content');
    if (empty)   { empty.classList.remove('d-none'); empty.innerHTML = loadingState(); }
    if (content) { content.classList.add('d-none'); content.innerHTML = ''; }
  });
  const aiEmpty   = document.getElementById('aiEmpty');
  const aiContent = document.getElementById('aiContent');
  if (aiEmpty)   aiEmpty.classList.remove('d-none');
  if (aiContent) aiContent.classList.add('d-none');

  document.getElementById('payFindings').innerHTML =
    '<span class="pay-findings-label">Analyzing…</span>';
}

function loadingState() {
  return `<div class="pay-state-box">
    <div class="pay-state-icon"><span class="spinner-border" style="width:28px;height:28px;border-width:3px;color:var(--accent)"></span></div>
    <div class="pay-state-title">Loading…</div>
    <div class="pay-state-sub">Querying Oracle AP tables</div>
  </div>`;
}

// ── KPI updater ──────────────────────────────────────────────────────────────

function updateKPIs(kpis, demoMode) {
  // STP Rate
  const stp = kpis.stp_rate;
  setKpiCard('kpiStp',
    stp !== null ? stp.toFixed(1) + '%' : '—',
    stpClass(stp),
    stp !== null ? `${kpis.total_invoices} total · ${kpis.unposted_count} unposted` : 'No data'
  );

  // Hold Rate
  const hr = kpis.hold_rate;
  setKpiCard('kpiHold',
    hr !== null ? hr.toFixed(1) + '%' : '—',
    holdRateClass(hr),
    `${kpis.hold_count} invoices on hold`
  );

  // Avg Hold Days
  const ahd = kpis.avg_days_on_hold;
  setKpiCard('kpiAvgHold',
    ahd !== null ? ahd.toFixed(1) + 'd' : '—',
    avgHoldClass(ahd),
    ahd !== null ? 'Average days on hold' : 'No holds found'
  );

  // Discount Risk
  const disc = kpis.discount_at_risk;
  setKpiCard('kpiDisc',
    disc > 0 ? '$' + formatNum(disc) : '$0',
    discountClass(disc),
    `${kpis.discount_count} opportunities · 14-day window`
  );

  // Close Status
  const blockers = (kpis.unposted_count || 0) + (kpis.pending_approval || 0);
  setKpiCard('kpiClose',
    blockers === 0 ? 'Clear' : blockers + ' issues',
    blockers === 0 ? 'kpi-ok' : blockers > 20 ? 'kpi-critical' : 'kpi-warn',
    `${kpis.unposted_count} unposted · ${kpis.pending_approval} pending approval`
  );
}

function setKpiCard(cardId, value, cssClass, detail) {
  const card   = document.getElementById(cardId);
  const valEl  = document.getElementById(cardId + 'Val');
  const detEl  = document.getElementById(cardId + 'Detail');
  if (!card) return;
  card.classList.remove('loading', 'kpi-ok', 'kpi-warn', 'kpi-critical', 'kpi-info');
  if (cssClass) card.classList.add(cssClass);
  if (valEl) valEl.textContent = value;
  if (detEl) detEl.textContent = detail || '';
}

function stpClass(v) {
  if (v === null) return '';
  if (v >= 90) return 'kpi-ok';
  if (v >= 70) return 'kpi-warn';
  return 'kpi-critical';
}
function holdRateClass(v) {
  if (v === null) return '';
  if (v <= 2) return 'kpi-ok';
  if (v <= 8) return 'kpi-warn';
  return 'kpi-critical';
}
function avgHoldClass(v) {
  if (v === null) return '';
  if (v <= 3) return 'kpi-ok';
  if (v <= 7) return 'kpi-warn';
  return 'kpi-critical';
}
function discountClass(v) {
  if (!v || v === 0) return 'kpi-ok';
  if (v > 10000) return 'kpi-warn';
  return 'kpi-info';
}

// ── Findings renderer ─────────────────────────────────────────────────────────

function renderFindings(findings) {
  const bar = document.getElementById('payFindings');
  if (!findings || findings.length === 0) {
    bar.innerHTML = '<span class="pay-findings-label" style="color:var(--low)"><i class="fa-solid fa-circle-check me-1"></i>No significant findings</span>';
    return;
  }

  const sevIcon = { CRITICAL: 'fa-circle-exclamation', HIGH: 'fa-triangle-exclamation',
                    MEDIUM: 'fa-circle-info', INFO: 'fa-circle-dot', LOW: 'fa-circle-check' };

  bar.innerHTML = '<span class="pay-findings-label">Findings:</span>' +
    findings.map(f => {
      const icon = sevIcon[f.severity] || 'fa-circle-dot';
      return `<span class="pay-finding-pill sev-${f.severity}" title="${escHtml(f.description)}">
        <i class="fa-solid ${icon} fa-xs"></i>
        ${escHtml(f.category)} <strong>${f.count}</strong>
      </span>`;
    }).join('');
}

// ── Tab counts ────────────────────────────────────────────────────────────────

function updateTabCounts(queries) {
  const map = {
    health:      'invoice_health',
    holds:       'holds',
    approvers:   'approvers',
    discounts:   'discounts',
    unapproved:  'unapproved_invoices',
    duplicate:   'duplicate_risk',
    nopo:        'non_po_invoices',
    aging:       'supplier_aging',
    matchexc:    'match_exceptions',
    cycletime:   'cycle_time',
    prepay:      'open_prepayments',
    bottleneck:  'approval_bottleneck',
  };
  for (const [tab, qid] of Object.entries(map)) {
    const el = document.getElementById('cnt-' + tab);
    if (!el) continue;
    const q = queries[qid];
    if (!q) continue;
    el.textContent = q.row_count !== undefined ? q.row_count : '—';
    el.classList.remove('err');
    if (q.error) el.classList.add('err');
  }
}

// ── Generic table renderer ────────────────────────────────────────────────────

function renderTable(containerId, queryResult, opts = {}) {
  const container = document.getElementById(containerId);
  if (!container) return;

  const { rowColorFn, rowClickFn, badgeCols = {}, filename = 'export.csv', label = '' } = opts;

  if (!queryResult || queryResult.error) {
    container.innerHTML = `<div class="pay-error-badge">
      <i class="fa-solid fa-triangle-exclamation fa-xs"></i>
      Query error: ${escHtml((queryResult && queryResult.error) || 'Unknown error')}
    </div>`;
    return;
  }

  const rows = queryResult.rows || [];
  const cols = queryResult.columns || [];

  if (rows.length === 0) {
    container.innerHTML = `<div class="pay-state-box">
      <div class="pay-state-icon"><i class="fa-solid fa-circle-check"></i></div>
      <div class="pay-state-title">No records found</div>
      <div class="pay-state-sub">No ${label || 'data'} in the selected period.</div>
    </div>`;
    return;
  }

  // CSV button uses a stable data-key — actual export wired via event delegation below
  const toolbar = `<div class="pay-table-toolbar">
    <div class="pay-table-info">
      Showing <strong>${rows.length}</strong> ${label || 'rows'} · ${queryResult.row_count} total
    </div>
    <button class="pay-csv-btn" data-csv-id="${containerId}">
      <i class="fa-solid fa-download fa-xs"></i> CSV
    </button>
  </div>`;

  const thead = `<thead><tr>${cols.map(c => `<th>${escHtml(c.replace(/_/g,' '))}</th>`).join('')}</tr></thead>`;

  // Use data-row-idx for click delegation — avoids serialising functions/JSON in HTML attrs
  const tbody = '<tbody>' + rows.map((row, idx) => {
    const colorClass = rowColorFn ? rowColorFn(row) : '';
    const clickable  = rowClickFn ? 'pay-row-click' : '';
    const idxAttr    = rowClickFn ? `data-row-idx="${idx}"` : '';
    return `<tr class="${colorClass} ${clickable}" ${idxAttr}>${
      cols.map(c => {
        const val = row[c];
        const display = badgeCols[c] ? makeBadge(c, val) : escHtml(val !== null && val !== undefined ? String(val) : '');
        return `<td>${display}</td>`;
      }).join('')
    }</tr>`;
  }).join('') + '</tbody>';

  container.innerHTML = toolbar + `<div class="pay-table-wrap"><table class="pay-table">${thead}${tbody}</table></div>`;

  // Event delegation for row clicks (avoids inline JS / JSON-in-attribute bugs)
  if (rowClickFn) {
    const tbody = container.querySelector('tbody');
    if (tbody) {
      tbody.addEventListener('click', (e) => {
        const tr = e.target.closest('tr[data-row-idx]');
        if (tr) {
          const idx = parseInt(tr.dataset.rowIdx, 10);
          if (!isNaN(idx) && rows[idx]) rowClickFn(rows[idx]);
        }
      });
    }
  }

  // CSV export via event delegation on the toolbar button
  const csvBtn = container.querySelector('.pay-csv-btn[data-csv-id]');
  if (csvBtn) {
    csvBtn.addEventListener('click', () => exportCSV(rows, cols, filename));
  }
}

function makeBadge(colName, val) {
  const v = (val || '').toString().toUpperCase().replace(/ /g,'_');
  if (colName === 'urgency') {
    return `<span class="hold-type-badge urg-${v}">${escHtml(val)}</span>`;
  }
  return `<span class="hold-type-badge">${escHtml(val)}</span>`;
}

// ── Tab renderers ─────────────────────────────────────────────────────────────

function renderHealthTab(result, demoMode) {
  const empty   = document.getElementById('healthEmpty');
  const content = document.getElementById('healthContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  let html = '';
  if (demoMode) {
    html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live data</div>`;
  }

  // Source + approval breakdown pills from demo or live row_count
  if (!demoMode && result && result.rows && result.rows.length > 0) {
    const bySource = {};
    const byApproval = {};
    result.rows.forEach(r => {
      const src = r.source || 'OTHER';
      const apv = r.wfapproval_status || 'UNKNOWN';
      bySource[src]   = (bySource[src]   || 0) + 1;
      byApproval[apv] = (byApproval[apv] || 0) + 1;
    });

    const srcPills = Object.entries(bySource).map(([k,v]) =>
      `<span class="pay-stat-pill"><strong>${v}</strong> ${escHtml(k)}</span>`).join('');
    const apvPills = Object.entries(byApproval).map(([k,v]) =>
      `<span class="pay-stat-pill"><strong>${v}</strong> ${escHtml(k)}</span>`).join('');

    html += `<div style="margin-bottom:12px;">
      <div style="font-size:11px;color:var(--text-muted);font-weight:600;text-transform:uppercase;letter-spacing:.06em;margin-bottom:6px;">By Source</div>
      <div class="pay-pill-group">${srcPills}</div>
      <div style="font-size:11px;color:var(--text-muted);font-weight:600;text-transform:uppercase;letter-spacing:.06em;margin:10px 0 6px;">By Approval Status</div>
      <div class="pay-pill-group">${apvPills}</div>
    </div>`;
  } else if (demoMode) {
    html += `<div style="margin-bottom:12px;">
      <div class="pay-pill-group">
        <span class="pay-stat-pill"><strong>24</strong> EDI</span>
        <span class="pay-stat-pill"><strong>8</strong> MANUAL</span>
      </div>
    </div>`;
  }

  content.innerHTML = html + '<div id="healthTable"></div>';

  if (demoMode) {
    // Show demo placeholder table
    const fakeResult = {
      rows: buildDemoHealthRows(),
      columns: ['invoice_num','invoice_amount','currency_code','source','wfapproval_status','days_open'],
      row_count: 32,
    };
    renderTable('healthTable', fakeResult, { label: 'unposted invoices', filename: 'invoice_health.csv' });
  } else {
    renderTable('healthTable', result, { label: 'unposted invoices', filename: 'invoice_health.csv' });
  }
}

function renderHoldsTab(result, demoMode) {
  const empty   = document.getElementById('holdsEmpty');
  const content = document.getElementById('holdsContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  let html = '';
  if (demoMode) {
    html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live data</div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row to see the recommended action for that hold.</p>';
  content.innerHTML = html + '<div id="holdsTable"></div>';

  const displayResult = demoMode ? { rows: buildDemoHoldRows(), columns: ['invoice_num','hold_lookup_code','hold_reason','days_on_hold','invoice_amount','currency_code','wfapproval_status'], row_count: 12 } : result;

  renderTable('holdsTable', displayResult, {
    label: 'holds',
    filename: 'holds.csv',
    badgeCols: { hold_lookup_code: true },
    rowClickFn: openDrillDown,
    rowColorFn: (row) => parseInt(row.days_on_hold || 0) > 7 ? 'pay-row-warn' : '',
  });
}

function renderApproversTab(result, demoMode) {
  const empty   = document.getElementById('approversEmpty');
  const content = document.getElementById('approversContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  let html = '';
  if (demoMode) {
    html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live data</div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row to see the recommended resolution for that hold type.</p>';
  content.innerHTML = html + '<div id="approversTable"></div>';

  const displayResult = demoMode ? { rows: buildDemoApproversRows(), columns: ['hold_type','approval_status','invoice_count','hold_count','total_amount','min_days','max_days','avg_days'], row_count: 6 } : result;

  renderTable('approversTable', displayResult, {
    label: 'hold types',
    filename: 'by_hold_type.csv',
    badgeCols: { hold_type: true },
    rowClickFn: openApproverDrillDown,
  });
}

function renderDiscountsTab(result, demoMode) {
  const empty   = document.getElementById('discountsEmpty');
  const content = document.getElementById('discountsContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  let html = '';
  if (demoMode) {
    html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live data</div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for discount details and invoice lines.</p>';
  content.innerHTML = html + '<div id="discountsTable"></div>';

  const displayResult = demoMode ? { rows: buildDemoDiscountRows(), columns: ['invoice_num','vendor_name','discount_date','discount_amount','gross_amount','invoice_currency_code','days_to_discount','urgency'], row_count: 18 } : result;

  renderTable('discountsTable', displayResult, {
    label: 'discount opportunities',
    filename: 'cash_opportunities.csv',
    badgeCols: { urgency: true },
    rowClickFn: openDiscountDrillDown,
    rowColorFn: (row) => {
      const u = (row.urgency || '').toUpperCase();
      if (u === 'URGENT')    return 'pay-row-urgent';
      if (u === 'THIS_WEEK') return 'pay-row-warn';
      return '';
    },
  });
}

// ── Unapproved Invoices tab ───────────────────────────────────────────────────

function renderUnapprovedTab(result, demoMode) {
  const empty = document.getElementById('unapprovedEmpty');
  const content = document.getElementById('unapprovedContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  let html = '';
  if (demoMode) html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  const rows = demoMode ? buildDemoUnapprovedRows() : (result && result.rows ? result.rows : []);
  if (rows.length > 0) {
    const total = parseFloat(rows[0].total_amount_at_risk || 0);
    html += `<div class="pay-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> invoices awaiting approval —
        <strong>$${formatNum(total)}</strong> total at risk.
        Avg wait: <strong>${Math.round(rows.reduce((s,r)=>s+parseFloat(r.days_waiting||0),0)/rows.length)} days</strong>
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click a row for invoice lines and vendor payment history.</p>';
  content.innerHTML = html + '<div id="unapprovedTable"></div>';

  const cols = ['invoice_num','vendor_name','invoice_amount','invoice_currency_code','wfapproval_status','current_approver','source','days_waiting'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderTable('unapprovedTable', displayResult, {
    label: 'unapproved invoices', filename: 'unapproved_invoices.csv',
    badgeCols: { wfapproval_status: true },
    rowClickFn: openUnapprovedDrillDown,
    rowColorFn: r => parseInt(r.days_waiting || 0) > 14 ? 'pay-row-warn' : '',
  });
}

// ── Duplicate Risk tab ────────────────────────────────────────────────────────

function renderDuplicateTab(result, demoMode) {
  const empty = document.getElementById('duplicateEmpty');
  const content = document.getElementById('duplicateContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoDupRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    html += `<div class="pay-ai-summary" style="margin-bottom:12px;background:rgba(207,34,46,.05);border-color:rgba(207,34,46,.2);">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong style="color:#cf222e;">${rows.length}</strong> potential duplicate pairs detected.
        Review each pair before payment run to avoid double-payment.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click a row to compare the duplicate pair side by side.</p>';
  content.innerHTML = html + '<div id="duplicateTable"></div>';

  const cols = ['vendor_name','invoice_num','invoice_amount','invoice_currency_code','invoice_date','dup_invoice_num','dup_invoice_date','date_diff_days'];
  const displayResult = demoMode ? { rows, columns: cols, row_count: rows.length } : (result || { rows: [], columns: cols, row_count: 0 });

  renderTable('duplicateTable', displayResult, {
    label: 'duplicate pairs', filename: 'duplicate_risk.csv',
    rowClickFn: openDuplicateDrillDown,
    rowColorFn: () => 'pay-row-urgent',
  });
}

// ── Non-PO Invoices tab ───────────────────────────────────────────────────────

function renderNonPoTab(result, demoMode) {
  const empty = document.getElementById('nopoEmpty');
  const content = document.getElementById('nopoContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoNonPoRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const total = parseFloat(rows[0].total_non_po_amount || 0);
    html += `<div class="pay-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> invoices with no PO reference — <strong>$${formatNum(total)}</strong> total.
        These bypass 3-way match controls and may represent audit risk.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click a row to review invoice lines and coding.</p>';
  content.innerHTML = html + '<div id="nopoTable"></div>';

  const cols = ['invoice_num','vendor_name','invoice_amount','invoice_currency_code','source','wfapproval_status','posting_status','days_old'];
  const displayResult = demoMode ? { rows, columns: cols, row_count: rows.length } : (result || { rows: [], columns: cols, row_count: 0 });

  renderTable('nopoTable', displayResult, {
    label: 'non-PO invoices', filename: 'non_po_invoices.csv',
    badgeCols: { wfapproval_status: true },
    rowClickFn: openNonPoDrillDown,
    rowColorFn: r => parseFloat(r.invoice_amount || 0) > 5000 ? 'pay-row-warn' : '',
  });
}

// ── Supplier Aging tab ────────────────────────────────────────────────────────

function renderAgingTab(result, demoMode) {
  const empty = document.getElementById('agingEmpty');
  const content = document.getElementById('agingContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoAgingRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const totals = rows.reduce((acc, r) => {
      acc.b0  += parseFloat(r.bucket_0_30   || 0);
      acc.b31 += parseFloat(r.bucket_31_60  || 0);
      acc.b61 += parseFloat(r.bucket_61_90  || 0);
      acc.b90 += parseFloat(r.bucket_over_90 || 0);
      return acc;
    }, { b0: 0, b31: 0, b61: 0, b90: 0 });
    const grand = totals.b0 + totals.b31 + totals.b61 + totals.b90;
    html += `<div class="aging-summary">
      <div class="aging-bucket"><div class="aging-bucket-label">0-30 days</div><div class="aging-bucket-val b0">$${formatNum(totals.b0)}</div></div>
      <div class="aging-bucket"><div class="aging-bucket-label">31-60 days</div><div class="aging-bucket-val b31">$${formatNum(totals.b31)}</div></div>
      <div class="aging-bucket"><div class="aging-bucket-label">61-90 days</div><div class="aging-bucket-val b61">$${formatNum(totals.b61)}</div></div>
      <div class="aging-bucket"><div class="aging-bucket-label">90+ days</div><div class="aging-bucket-val b90">$${formatNum(totals.b90)}</div></div>
      <div class="aging-bucket" style="margin-left:auto;"><div class="aging-bucket-label">Total Outstanding</div><div class="aging-bucket-val" style="color:var(--text-bright);">$${formatNum(grand)}</div></div>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click a supplier to see recent payment history.</p>';
  content.innerHTML = html + '<div id="agingTable"></div>';

  const cols = ['vendor_name','invoice_count','bucket_0_30','bucket_31_60','bucket_61_90','bucket_over_90','total_outstanding'];
  const displayResult = demoMode ? { rows, columns: cols, row_count: rows.length } : (result || { rows: [], columns: cols, row_count: 0 });

  renderTable('agingTable', displayResult, {
    label: 'supplier aging', filename: 'supplier_aging.csv',
    rowClickFn: openAgingDrillDown,
    rowColorFn: r => parseFloat(r.bucket_over_90 || 0) > 0 ? 'pay-row-urgent'
                   : parseFloat(r.bucket_61_90 || 0) > 0 ? 'pay-row-warn' : '',
  });
}

// ── Match Exceptions tab ──────────────────────────────────────────────────────

function renderMatchExcTab(result, demoMode) {
  const empty = document.getElementById('matchexcEmpty');
  const content = document.getElementById('matchexcContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoMatchExcRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click a row for hold details, recommended action, and invoice lines.</p>';
  content.innerHTML = html + '<div id="matchexcTable"></div>';

  const cols = ['invoice_num','vendor_name','hold_type','hold_reason','invoice_amount','invoice_currency_code','days_on_hold','by_hold_type'];
  const displayResult = demoMode ? { rows, columns: cols, row_count: rows.length } : (result || { rows: [], columns: cols, row_count: 0 });

  renderTable('matchexcTable', displayResult, {
    label: 'match exceptions', filename: 'match_exceptions.csv',
    badgeCols: { hold_type: true },
    rowClickFn: r => openDrillDown({ ...r, hold_lookup_code: r.hold_type }),
    rowColorFn: r => parseInt(r.days_on_hold || 0) > 7 ? 'pay-row-warn' : '',
  });
}

// ── Cycle Time tab ────────────────────────────────────────────────────────────

function renderCycleTimeTab(result, demoMode) {
  const empty = document.getElementById('cycletimeEmpty');
  const content = document.getElementById('cycletimeContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoCycleTimeRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const avg  = parseFloat(rows[0].avg_cycle_days || 0);
    const max  = Math.max(...rows.map(r => parseFloat(r.cycle_days || 0)));
    const min  = Math.min(...rows.map(r => parseFloat(r.cycle_days || 0)));
    const fast = rows.filter(r => r.cycle_band === 'FAST').length;
    const crit = rows.filter(r => r.cycle_band === 'CRITICAL').length;
    html += `<div class="cycle-summary">
      <div class="cycle-pill"><span style="color:var(--text-muted);">Avg</span><strong>${avg.toFixed(1)} days</strong></div>
      <div class="cycle-pill"><span style="color:var(--text-muted);">Fastest</span><strong>${min} days</strong></div>
      <div class="cycle-pill"><span style="color:var(--text-muted);">Slowest</span><strong>${max} days</strong></div>
      <div class="cycle-pill"><span style="color:#1a7f37;">Fast (&le;3d)</span><strong>${fast}</strong></div>
      <div class="cycle-pill"><span style="color:#cf222e;">Critical (&gt;14d)</span><strong>${crit}</strong></div>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click a row for invoice details.</p>';
  content.innerHTML = html + '<div id="cycletimeTable"></div>';

  const cols = ['invoice_num','vendor_name','invoice_amount','invoice_currency_code','source','received_date','posting_date','cycle_days','cycle_band'];
  const displayResult = demoMode ? { rows, columns: cols, row_count: rows.length } : (result || { rows: [], columns: cols, row_count: 0 });

  renderTable('cycletimeTable', displayResult, {
    label: 'cycle time', filename: 'cycle_time.csv',
    badgeCols: { cycle_band: true },
    rowClickFn: openCycleTimeDrillDown,
    rowColorFn: r => r.cycle_band === 'CRITICAL' ? 'pay-row-urgent' : r.cycle_band === 'SLOW' ? 'pay-row-warn' : '',
  });
}

// ── Open Prepayments tab ──────────────────────────────────────────────────────

function renderPrepayTab(result, demoMode) {
  const empty = document.getElementById('prepayEmpty');
  const content = document.getElementById('prepayContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoPrepayRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const total = parseFloat(rows[0].total_prepay_amount || 0);
    html += `<div class="pay-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> open prepayments totalling <strong>$${formatNum(total)}</strong>.
        These represent tied-up working capital until applied to matching invoices.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click a row for details and invoice lines.</p>';
  content.innerHTML = html + '<div id="prepayTable"></div>';

  const cols = ['invoice_num','vendor_name','prepayment_amount','unapplied_amount','invoice_currency_code','invoice_date','days_outstanding','wfapproval_status'];
  const displayResult = demoMode ? { rows, columns: cols, row_count: rows.length } : (result || { rows: [], columns: cols, row_count: 0 });

  renderTable('prepayTable', displayResult, {
    label: 'open prepayments', filename: 'open_prepayments.csv',
    badgeCols: { wfapproval_status: true },
    rowClickFn: openPrepayDrillDown,
    rowColorFn: r => parseInt(r.days_outstanding || 0) > 60 ? 'pay-row-urgent'
                   : parseInt(r.days_outstanding || 0) > 30 ? 'pay-row-warn' : '',
  });
}

// ── Approval Bottleneck tab ───────────────────────────────────────────────────

function renderBottleneckTab(result, demoMode) {
  const empty = document.getElementById('bottleneckEmpty');
  const content = document.getElementById('bottleneckContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoBottleneckRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const total = rows.reduce((s, r) => s + parseInt(r.pending_count || 0), 0);
    html += `<div class="pay-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> approvers with a combined <strong>${total}</strong> invoices pending.
        Click any row to escalate.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click a row for escalation guidance.</p>';
  content.innerHTML = html + '<div id="bottleneckTable"></div>';

  const cols = ['approver','approver_name','pending_count','avg_days_waiting','max_days_waiting','total_amount_pending'];
  const displayResult = demoMode ? { rows, columns: cols, row_count: rows.length } : (result || { rows: [], columns: cols, row_count: 0 });

  renderTable('bottleneckTable', displayResult, {
    label: 'approval bottleneck', filename: 'approval_bottleneck.csv',
    rowClickFn: openBottleneckDrillDown,
    rowColorFn: r => parseInt(r.max_days_waiting || 0) > 7 ? 'pay-row-urgent'
                   : parseFloat(r.avg_days_waiting || 0) > 3 ? 'pay-row-warn' : '',
  });
}

// ── New drill-down functions ───────────────────────────────────────────────────

function openUnapprovedDrillDown(row) {
  payState.selectedInvoiceId = row.invoice_id || null;
  payState.selectedVendorId  = row.vendor_id  || null;
  _openDrillPanel(`Unapproved: ${row.invoice_num || '—'}`);

  document.getElementById('drillHoldCode').textContent  = row.wfapproval_status || '—';
  document.getElementById('drillDays').textContent      = `${row.days_waiting || '—'} days waiting`;
  document.getElementById('drillInvNum').textContent    = row.invoice_num || '—';
  document.getElementById('drillAmount').textContent    = row.invoice_amount ? '$' + formatNum(row.invoice_amount) : '—';
  document.getElementById('drillCurrency').textContent  = row.invoice_currency_code || '—';
  document.getElementById('drillVendor').textContent    = row.vendor_name || '—';
  document.getElementById('drillSource').textContent    = row.source || '—';
  document.getElementById('drillApproval').textContent  = row.wfapproval_status || '—';

  const invNum = row.invoice_num || '—';
  const vendorNm = row.vendor_name || '—';
  const amt = row.invoice_amount ? '$' + formatNum(row.invoice_amount) : '—';
  const daysW = row.days_waiting || '—';
  const approver = row.current_approver || null;
  const status = (row.wfapproval_status || '').toUpperCase();
  let actionText;
  if (status === 'REJECTED') {
    actionText = `Invoice ${invNum} (${amt}) from ${vendorNm} was rejected. Contact ${vendorNm} for a credit memo or corrected invoice. Cancel invoice ${invNum} once replacement is received.`;
  } else if (approver) {
    actionText = `Invoice ${invNum} (${amt}) from ${vendorNm} has been waiting ${daysW} days (status: ${row.wfapproval_status || '—'}). Current approver: ${approver}. Go to Workflow Admin > Worklist > search ${invNum} to check status with ${approver}. If ${approver} is unavailable or on leave, re-assign via Worklist Admin > Reassign.`;
  } else {
    actionText = `Invoice ${invNum} (${amt}) from ${vendorNm} has been waiting ${daysW} days (status: ${row.wfapproval_status || '—'}). No approver currently assigned. Navigate to AP > Inquiry > Invoice > enter ${invNum} > View Approvers to check workflow routing. If stuck, go to Workflow Admin > Worklist > search ${invNum} to diagnose and re-assign.`;
  }
  document.getElementById('drillOwner').innerHTML = approver
    ? `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(approver)}`
    : '<i class="fa-solid fa-user fa-xs me-1"></i>AP Manager';
  document.getElementById('drillAction').textContent = actionText;

  document.getElementById('drillReasonSection').style.display     = 'none';
  document.getElementById('drillActionSection').style.display     = '';
  document.getElementById('drillVendorHistSection').style.display = '';
  document.getElementById('drillDupSection').style.display        = 'none';
  document.getElementById('drillLinesSection').style.display      = '';

  _resetVendorHistBtn();
}

function openDuplicateDrillDown(row) {
  payState.selectedInvoiceId = null;
  payState.selectedVendorId  = null;
  _openDrillPanel(`Dup Risk: ${row.vendor_name || '—'}`);

  document.getElementById('drillHoldCode').textContent  = 'DUPLICATE';
  document.getElementById('drillDays').textContent      = `${row.date_diff_days || 0} days apart`;
  document.getElementById('drillInvNum').textContent    = row.invoice_num || '—';
  document.getElementById('drillAmount').textContent    = row.invoice_amount ? '$' + formatNum(row.invoice_amount) : '—';
  document.getElementById('drillCurrency').textContent  = row.invoice_currency_code || '—';
  document.getElementById('drillVendor').textContent    = row.vendor_name || '—';
  document.getElementById('drillSource').textContent    = '—';
  document.getElementById('drillApproval').textContent  = '—';

  document.getElementById('drillOwner').innerHTML    = '<i class="fa-solid fa-user fa-xs me-1"></i>AP Clerk';
  document.getElementById('drillAction').textContent = `Compare invoice ${escHtml(row.invoice_num || '—')} and ${escHtml(row.dup_invoice_num || '—')} (both $${formatNum(row.invoice_amount || 0)} ${row.invoice_currency_code || ''}, ${row.date_diff_days || '—'} days apart) in AP > Invoice Inquiry > enter each invoice number. Confirm with ${escHtml(row.vendor_name || 'the supplier')} — if duplicate, cancel ${escHtml(row.dup_invoice_num || 'the later invoice')} (dated ${escHtml(String(row.dup_invoice_date || '—'))}). If legitimate, add a distinguishing note to both.`;

  const dupGrid = document.getElementById('drillDupGrid');
  dupGrid.innerHTML = `
    <div class="pay-drill-item">
      <div class="pay-drill-item-label">Original</div>
      <div class="pay-drill-item-value">${escHtml(row.invoice_num || '—')}</div>
    </div>
    <div class="pay-drill-item">
      <div class="pay-drill-item-label">Candidate</div>
      <div class="pay-drill-item-value">${escHtml(row.dup_invoice_num || '—')}</div>
    </div>
    <div class="pay-drill-item">
      <div class="pay-drill-item-label">Orig Date</div>
      <div class="pay-drill-item-value">${escHtml(String(row.invoice_date || '—'))}</div>
    </div>
    <div class="pay-drill-item">
      <div class="pay-drill-item-label">Cand Date</div>
      <div class="pay-drill-item-value">${escHtml(String(row.dup_invoice_date || '—'))}</div>
    </div>
    <div class="pay-drill-item" style="grid-column:1/-1">
      <div class="pay-drill-item-label">Both Amounts</div>
      <div class="pay-drill-item-value">$${formatNum(row.invoice_amount || 0)} ${escHtml(row.invoice_currency_code || '')}</div>
    </div>`;

  document.getElementById('drillReasonSection').style.display     = 'none';
  document.getElementById('drillActionSection').style.display     = '';
  document.getElementById('drillDupSection').style.display        = '';
  document.getElementById('drillVendorHistSection').style.display = 'none';
  document.getElementById('drillLinesSection').style.display      = 'none';
}

function openNonPoDrillDown(row) {
  payState.selectedInvoiceId = row.invoice_id || null;
  payState.selectedVendorId  = null;
  _openDrillPanel(`Non-PO: ${row.invoice_num || '—'}`);

  document.getElementById('drillHoldCode').textContent  = 'NO PO';
  document.getElementById('drillDays').textContent      = `${row.days_old || '—'} days old`;
  document.getElementById('drillInvNum').textContent    = row.invoice_num || '—';
  document.getElementById('drillAmount').textContent    = row.invoice_amount ? '$' + formatNum(row.invoice_amount) : '—';
  document.getElementById('drillCurrency').textContent  = row.invoice_currency_code || '—';
  document.getElementById('drillVendor').textContent    = row.vendor_name || '—';
  document.getElementById('drillSource').textContent    = row.source || '—';
  document.getElementById('drillApproval').textContent  = row.wfapproval_status || '—';

  document.getElementById('drillOwner').innerHTML    = '<i class="fa-solid fa-user fa-xs me-1"></i>AP Manager';
  document.getElementById('drillAction').textContent = `Invoice ${row.invoice_num || '—'} ($${formatNum(row.invoice_amount || 0)} ${row.invoice_currency_code || ''}) from ${row.vendor_name || '—'} (source: ${row.source || '—'}, ${row.days_old || '—'} days old) has no PO. Verify whether a PO should exist for this spend. If yes, request buyer to raise a PO and match retroactively via AP > Invoice Actions > Match to PO on ${row.invoice_num || '—'}. If no, ensure this is an approved exception category (e.g. utilities, rent) and coding is correct.`;

  document.getElementById('drillReasonSection').style.display     = 'none';
  document.getElementById('drillActionSection').style.display     = '';
  document.getElementById('drillVendorHistSection').style.display = 'none';
  document.getElementById('drillDupSection').style.display        = 'none';
  document.getElementById('drillLinesSection').style.display      = '';
}

function openAgingDrillDown(row) {
  payState.selectedInvoiceId = null;
  payState.selectedVendorId  = row.vendor_id || null;
  _openDrillPanel(`Aging: ${row.vendor_name || '—'}`);

  document.getElementById('drillHoldCode').textContent  = row.invoice_count ? `${row.invoice_count} invoices` : '—';
  document.getElementById('drillDays').textContent      = row.bucket_over_90 > 0 ? `$${formatNum(row.bucket_over_90)} overdue 90+d` : 'No 90+ overdue';
  document.getElementById('drillInvNum').textContent    = `Total: $${formatNum(row.total_outstanding || 0)}`;
  document.getElementById('drillAmount').textContent    = `0-30d: $${formatNum(row.bucket_0_30 || 0)}`;
  document.getElementById('drillCurrency').textContent  = `31-60d: $${formatNum(row.bucket_31_60 || 0)}`;
  document.getElementById('drillVendor').textContent    = row.vendor_name || '—';
  document.getElementById('drillSource').textContent    = `61-90d: $${formatNum(row.bucket_61_90 || 0)}`;
  document.getElementById('drillApproval').textContent  = `90+d: $${formatNum(row.bucket_over_90 || 0)}`;

  const hasOverdue = parseFloat(row.bucket_over_90 || 0) > 0;
  document.getElementById('drillOwner').innerHTML    = '<i class="fa-solid fa-user fa-xs me-1"></i>AP Manager';
  document.getElementById('drillAction').textContent = hasOverdue
    ? `${row.vendor_name || '—'} has $${formatNum(row.bucket_over_90)} overdue 90+ days across ${row.invoice_count || '—'} invoices (total outstanding: $${formatNum(row.total_outstanding || 0)}). Review terms agreement with ${row.vendor_name || '—'}, check AP > Invoice Inquiry for holds on vendor_id ${row.vendor_id || '—'}, and escalate payment run to avoid late fees or supplier relationship damage.`
    : `${row.vendor_name || '—'} balance of $${formatNum(row.total_outstanding || 0)} across ${row.invoice_count || '—'} invoices is within payment terms. Buckets: 0-30d $${formatNum(row.bucket_0_30 || 0)}, 31-60d $${formatNum(row.bucket_31_60 || 0)}, 61-90d $${formatNum(row.bucket_61_90 || 0)}. Schedule in next payment run based on due dates.`;

  document.getElementById('drillReasonSection').style.display     = 'none';
  document.getElementById('drillActionSection').style.display     = '';
  document.getElementById('drillVendorHistSection').style.display = '';
  document.getElementById('drillDupSection').style.display        = 'none';
  document.getElementById('drillLinesSection').style.display      = 'none';

  _resetVendorHistBtn();
}

function openCycleTimeDrillDown(row) {
  payState.selectedInvoiceId = row.invoice_id || null;
  payState.selectedVendorId  = null;
  _openDrillPanel(`Cycle: ${row.invoice_num || '—'}`);

  const band = row.cycle_band || '—';
  document.getElementById('drillHoldCode').textContent  = band;
  document.getElementById('drillDays').textContent      = `${row.cycle_days || '—'} days (avg: ${row.avg_cycle_days || '—'})`;
  document.getElementById('drillInvNum').textContent    = row.invoice_num || '—';
  document.getElementById('drillAmount').textContent    = row.invoice_amount ? '$' + formatNum(row.invoice_amount) : '—';
  document.getElementById('drillCurrency').textContent  = row.invoice_currency_code || '—';
  document.getElementById('drillVendor').textContent    = row.vendor_name || '—';
  document.getElementById('drillSource').textContent    = row.source || '—';
  document.getElementById('drillApproval').textContent  = `Rcvd: ${row.received_date || '—'} → Posted: ${row.posting_date || '—'}`;

  const actionText = band === 'CRITICAL' || band === 'SLOW'
    ? `Invoice ${row.invoice_num || '—'} ($${formatNum(row.invoice_amount || 0)}) from ${row.vendor_name || '—'} took ${row.cycle_days || '—'} days (avg: ${row.avg_cycle_days || '—'} days, band: ${band}). Received: ${row.received_date || '—'}, Posted: ${row.posting_date || '—'}, Source: ${row.source || '—'}. Investigate in AP > Invoice Inquiry > ${row.invoice_num || '—'}: was it on hold? Pending approval? Wrong org? Document root cause to prevent recurrence.`
    : `Invoice ${row.invoice_num || '—'} processed in ${row.cycle_days || '—'} days (avg: ${row.avg_cycle_days || '—'} days). Source: ${row.source || '—'}. Processing within acceptable range.`;
  document.getElementById('drillOwner').innerHTML    = '<i class="fa-solid fa-user fa-xs me-1"></i>AP Manager';
  document.getElementById('drillAction').textContent = actionText;

  document.getElementById('drillReasonSection').style.display     = 'none';
  document.getElementById('drillActionSection').style.display     = '';
  document.getElementById('drillVendorHistSection').style.display = 'none';
  document.getElementById('drillDupSection').style.display        = 'none';
  document.getElementById('drillLinesSection').style.display      = '';
}

function openPrepayDrillDown(row) {
  payState.selectedInvoiceId = row.invoice_id || null;
  payState.selectedVendorId  = null;
  _openDrillPanel(`Prepayment: ${row.invoice_num || '—'}`);

  document.getElementById('drillHoldCode').textContent  = 'PREPAYMENT';
  document.getElementById('drillDays').textContent      = `${row.days_outstanding || '—'} days outstanding`;
  document.getElementById('drillInvNum').textContent    = row.invoice_num || '—';
  document.getElementById('drillAmount').textContent    = row.prepayment_amount ? '$' + formatNum(row.prepayment_amount) : '—';
  document.getElementById('drillCurrency').textContent  = row.invoice_currency_code || '—';
  document.getElementById('drillVendor').textContent    = row.vendor_name || '—';
  document.getElementById('drillSource').textContent    = `Unapplied: $${formatNum(row.unapplied_amount || 0)}`;
  document.getElementById('drillApproval').textContent  = row.wfapproval_status || '—';

  document.getElementById('drillOwner').innerHTML    = '<i class="fa-solid fa-user fa-xs me-1"></i>AP Clerk';
  document.getElementById('drillAction').textContent = `Prepayment ${row.invoice_num || '—'} to ${row.vendor_name || '—'}: $${formatNum(row.prepayment_amount || 0)} paid, $${formatNum(row.unapplied_amount || 0)} unapplied for ${row.days_outstanding || '—'} days. Confirm whether ${row.vendor_name || 'the supplier'} has submitted a matching invoice. If yes, apply via AP > Invoice Actions > select ${row.invoice_num || '—'} > Apply Prepayment. If no, contact ${row.vendor_name || 'the supplier'} to expedite invoice submission.`;

  document.getElementById('drillReasonSection').style.display     = 'none';
  document.getElementById('drillActionSection').style.display     = '';
  document.getElementById('drillVendorHistSection').style.display = 'none';
  document.getElementById('drillDupSection').style.display        = 'none';
  document.getElementById('drillLinesSection').style.display      = '';
}

function openBottleneckDrillDown(row) {
  payState.selectedInvoiceId = null;
  payState.selectedVendorId  = null;
  _openDrillPanel(`Bottleneck: ${row.approver_name || row.approver || '—'}`);

  document.getElementById('drillHoldCode').textContent  = row.approver || '—';
  document.getElementById('drillDays').textContent      = `Max wait: ${row.max_days_waiting || '—'} days`;
  document.getElementById('drillInvNum').textContent    = `${row.pending_count || '—'} invoices pending`;
  document.getElementById('drillAmount').textContent    = row.total_amount_pending ? '$' + formatNum(row.total_amount_pending) : '—';
  document.getElementById('drillCurrency').textContent  = 'Avg wait: ' + (row.avg_days_waiting || '—') + 'd';
  document.getElementById('drillVendor').textContent    = row.approver_name || row.approver || '—';
  document.getElementById('drillSource').textContent    = '—';
  document.getElementById('drillApproval').textContent  = '—';

  document.getElementById('drillOwner').innerHTML    = '<i class="fa-solid fa-user fa-xs me-1"></i>AP Manager';
  document.getElementById('drillAction').textContent = `${row.approver_name || row.approver || '—'} (${row.approver || '—'}) has ${row.pending_count || '—'} invoices pending ($${formatNum(row.total_amount_pending || 0)}), avg wait ${row.avg_days_waiting || '—'} days, max ${row.max_days_waiting || '—'} days. Go to Workflow Admin > Find Notifications > search by approver "${row.approver || '—'}". Re-assign the ${row.pending_count || '—'} outstanding tasks if ${row.approver_name || 'the approver'} is unavailable. Consider temporary delegation. Notify ${row.approver_name || 'the approver'}'s manager if max wait (${row.max_days_waiting || '—'}d) exceeds SLA.`;

  document.getElementById('drillReasonSection').style.display     = 'none';
  document.getElementById('drillActionSection').style.display     = '';
  document.getElementById('drillVendorHistSection').style.display = 'none';
  document.getElementById('drillDupSection').style.display        = 'none';
  document.getElementById('drillLinesSection').style.display      = 'none';
}

function _resetVendorHistBtn() {
  const btn = document.getElementById('drillVendorHistBtn');
  if (btn) { btn.disabled = false; btn.innerHTML = '<i class="fa-solid fa-clock-rotate-left fa-xs me-1"></i>Load History'; }
  const c = document.getElementById('drillVendorHistContent');
  if (c) c.innerHTML = '<p style="font-size:12px;color:var(--text-muted);margin:0;">Click "Load History" to see recent payments to this supplier.</p>';
}

async function loadVendorHistory() {
  const vendorId = payState.selectedVendorId;
  if (!vendorId) return;

  const btn = document.getElementById('drillVendorHistBtn');
  const content = document.getElementById('drillVendorHistContent');
  btn.disabled = true;
  btn.innerHTML = '<span class="spinner-border spinner-border-sm" style="width:12px;height:12px;border-width:2px;"></span> Loading…';
  content.innerHTML = '';

  try {
    const resp = await fetch(`/api/payables/vendor_history/${vendorId}`);
    const data = await resp.json();
    if (data.error) {
      content.innerHTML = `<p style="font-size:12px;color:#cf222e;">${escHtml(data.error)}</p>`;
      btn.innerHTML = '<i class="fa-solid fa-rotate-right fa-xs me-1"></i>Retry'; btn.disabled = false; return;
    }
    const rows = data.rows || [];
    if (rows.length === 0) {
      content.innerHTML = '<p style="font-size:12px;color:var(--text-muted);margin:0;">No payment history found.</p>';
    } else {
      const cols = ['check_date','amount','currency_code','payment_method_lookup_code','status_lookup_code'];
      const hdrs = { check_date: 'Date', amount: 'Amount', currency_code: 'Ccy', payment_method_lookup_code: 'Method', status_lookup_code: 'Status' };
      let html = '<div style="overflow-x:auto"><table class="vendor-hist-table"><thead><tr>';
      cols.forEach(c => { html += `<th>${hdrs[c]}</th>`; });
      html += '</tr></thead><tbody>';
      rows.forEach(row => {
        html += '<tr>';
        cols.forEach(c => {
          let v = row[c] ?? '—';
          if (c === 'amount') v = v !== '—' ? '$' + formatNum(v) : '—';
          html += `<td>${escHtml(String(v))}</td>`;
        });
        html += '</tr>';
      });
      html += '</tbody></table></div>';
      if (data.demo_mode) html += '<p style="font-size:11px;color:var(--text-muted);margin-top:4px;"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo data</p>';
      content.innerHTML = html;
    }
    btn.innerHTML = '<i class="fa-solid fa-check fa-xs me-1"></i>Loaded'; btn.disabled = true;
  } catch (err) {
    content.innerHTML = `<p style="font-size:12px;color:#cf222e;">Error: ${escHtml(err.message)}</p>`;
    btn.innerHTML = '<i class="fa-solid fa-rotate-right fa-xs me-1"></i>Retry'; btn.disabled = false;
  }
}

// ── Close Issues tab ──────────────────────────────────────────────────────────

function buildCloseIssues(data) {
  const kpis    = data.kpis;
  const queries = data.queries;
  const issues  = [];

  const healthRows    = (queries.invoice_health  || {}).rows || [];
  const holdRows      = (queries.holds           || {}).rows || [];
  const discountRows  = (queries.discounts        || {}).rows || [];

  // 1 — Unposted invoices
  if (kpis.unposted_count > 0) {
    const sev = kpis.unposted_count > 50 ? 'CRITICAL' : kpis.unposted_count > 10 ? 'HIGH' : 'MEDIUM';
    issues.push({
      id: 'unposted',
      title: 'Unposted Invoices',
      icon: 'fa-file-invoice',
      severity: sev,
      count: kpis.unposted_count,
      description: `${kpis.unposted_count} invoices have not been posted to the GL. Period close cannot complete until these are cleared.`,
      action: `${kpis.unposted_count} unposted invoices found. Run the AP Accounting process: navigate to Payables > Accounting > Create Accounting > Submit. Review any exceptions in the output log and correct distributions before re-posting.`,
      rows: healthRows,
      columns: ['invoice_num', 'vendor_name', 'invoice_amount', 'invoice_currency_code', 'source', 'wfapproval_status', 'days_open'],
    });
  }

  // 2 — Pending approval
  const pendingRows = healthRows.filter(r =>
    r.wfapproval_status && !['APPROVED','NOT REQUIRED'].includes((r.wfapproval_status || '').toUpperCase())
  );
  if (kpis.pending_approval > 0) {
    const sev = kpis.pending_approval > 20 ? 'HIGH' : kpis.pending_approval > 5 ? 'MEDIUM' : 'MEDIUM';
    issues.push({
      id: 'pending',
      title: 'Pending Approval',
      icon: 'fa-clock',
      severity: sev,
      count: kpis.pending_approval,
      description: `${kpis.pending_approval} invoices are awaiting workflow approval. These cannot be paid or posted until approved.`,
      action: `${kpis.pending_approval} invoices pending approval. Navigate to Workflow Admin > Worklist > Find Notifications to identify approvers with overdue tasks. Re-assign if unavailable, escalate to their managers, or configure approval timeout rules in AME Setup.`,
      rows: pendingRows.length ? pendingRows : healthRows.slice(0, kpis.pending_approval),
      columns: ['invoice_num', 'vendor_name', 'invoice_amount', 'invoice_currency_code', 'wfapproval_status', 'days_open'],
    });
  }

  // 3 — Active holds
  if (kpis.hold_count > 0) {
    const sev = kpis.hold_count > 20 ? 'CRITICAL' : kpis.hold_count > 5 ? 'HIGH' : 'MEDIUM';
    issues.push({
      id: 'holds',
      title: 'Invoices On Hold',
      icon: 'fa-hand',
      severity: sev,
      count: kpis.hold_count,
      description: `${kpis.hold_count} invoices are on hold (avg ${kpis.avg_days_on_hold !== null ? kpis.avg_days_on_hold.toFixed(1) : '?'} days). Held invoices block payment and reduce STP rate.`,
      action: `${kpis.hold_count} invoices on hold (avg ${kpis.avg_days_on_hold !== null ? kpis.avg_days_on_hold.toFixed(1) : '?'} days). Review holds by type in AP > Invoice Inquiry > Holds tab. For PO-matched holds (PRICE, QTY), work with the buyer/receiving team. For manual holds, confirm with the AP clerk who placed them. Release resolved holds via AP > Invoice Actions > Release Hold.`,
      rows: holdRows,
      columns: ['invoice_num', 'vendor_name', 'hold_lookup_code', 'hold_reason', 'invoice_amount', 'invoice_currency_code', 'days_on_hold'],
      rowClickFn: openDrillDown,
    });
  }

  // 4 — Low STP rate
  if (kpis.stp_rate !== null && kpis.stp_rate < 85) {
    const sev = kpis.stp_rate < 70 ? 'HIGH' : 'MEDIUM';
    issues.push({
      id: 'stp',
      title: 'STP Rate Below Target',
      icon: 'fa-gauge',
      severity: sev,
      count: null,
      countLabel: kpis.stp_rate.toFixed(1) + '%',
      description: `STP rate is ${kpis.stp_rate.toFixed(1)}% against an 85% target. ${kpis.unposted_count + kpis.hold_count} invoices are either unposted or on hold.`,
      action: `STP rate ${kpis.stp_rate.toFixed(1)}% (target: 85%). ${kpis.unposted_count} unposted + ${kpis.hold_count} on hold = ${kpis.unposted_count + kpis.hold_count} blocking invoices. Address unposted invoices (Create Accounting) and holds (see above) first. Review EDI/import sources for recurring match failures. Check AME approval rules for tuning opportunities.`,
      rows: [],
      columns: [],
    });
  }

  // 5 — Expiring discounts (urgent)
  const urgentDisc = discountRows.filter(r => (r.urgency || '').toUpperCase() === 'URGENT');
  if (urgentDisc.length > 0) {
    const totalAmt = urgentDisc.reduce((s, r) => s + parseFloat(r.discount_amount || 0), 0);
    issues.push({
      id: 'disc_urgent',
      title: 'Discounts Expiring in 3 Days',
      icon: 'fa-fire',
      severity: 'HIGH',
      count: urgentDisc.length,
      description: `${urgentDisc.length} discount opportunities totalling $${formatNum(totalAmt)} expire within 3 days. Missing these is a direct cash loss.`,
      action: `${urgentDisc.length} discounts ($${formatNum(totalAmt)}) expiring in 3 days. Create manual payment batch now: AP > Payments > Payment Batch > add these ${urgentDisc.length} invoices. Confirm banking details are correct before submission. Escalate to AP Manager if payment run is blocked.`,
      rows: urgentDisc,
      columns: ['invoice_num', 'vendor_name', 'discount_amount', 'gross_amount', 'discount_date', 'days_to_discount'],
      rowClickFn: openDiscountDrillDown,
    });
  }

  // 6 — All clear
  if (issues.length === 0) {
    issues.push({
      id: 'ok',
      title: 'No Close Blockers Found',
      icon: 'fa-circle-check',
      severity: 'OK',
      count: 0,
      description: 'All invoices are posted, no holds, no pending approvals, and STP rate is on target. Period close should proceed without AP blockers.',
      action: '',
      rows: [],
      columns: [],
    });
  }

  return issues;
}

function renderCloseIssuesTab(data, demoMode) {
  const empty   = document.getElementById('closeEmpty');
  const content = document.getElementById('closeContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const issues = buildCloseIssues(data);

  // Update tab count badge
  const blockers = issues.filter(i => i.severity !== 'OK').length;
  const cntEl = document.getElementById('cnt-close');
  if (cntEl) cntEl.textContent = blockers > 0 ? blockers : '✓';

  let html = '';
  if (demoMode) {
    html += `<div class="pay-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live data</div>`;
  }

  if (issues[0].severity === 'OK') {
    html += `<div class="close-ok-banner">
      <i class="fa-solid fa-circle-check"></i>
      <div>
        <div style="font-size:15px;font-weight:700;">No Close Blockers Found</div>
        <div style="font-size:13px;font-weight:400;margin-top:2px;">${escHtml(issues[0].description)}</div>
      </div>
    </div>`;
  } else {
    html += `<div class="close-section-hdr"><i class="fa-solid fa-triangle-exclamation fa-xs"></i>${blockers} issue${blockers !== 1 ? 's' : ''} require attention before period close</div>`;
    html += '<div class="close-issue-list" id="closeIssueList"></div>';
  }

  content.innerHTML = html;

  // Render each issue card with its detail table
  const list = document.getElementById('closeIssueList');
  if (!list) return;

  issues.forEach((issue, idx) => {
    const cardId  = `closeCard_${idx}`;
    const tableId = `closeTable_${idx}`;
    const card = document.createElement('div');
    card.className = `close-issue-card sev-${issue.severity}`;
    card.id = cardId;

    const countDisplay = issue.countLabel || (issue.count !== null ? issue.count : '');

    card.innerHTML = `
      <div class="close-issue-header">
        <div class="close-issue-meta">
          <span class="close-sev-badge sev-${issue.severity}">${escHtml(issue.severity)}</span>
          <div class="close-issue-title"><i class="fa-solid ${issue.icon} fa-xs"></i>${escHtml(issue.title)}</div>
        </div>
        ${countDisplay !== '' ? `<div class="close-issue-count">${escHtml(String(countDisplay))}</div>` : ''}
      </div>
      <div class="close-issue-desc">${escHtml(issue.description)}</div>
      ${issue.action ? `<div class="close-issue-action-text"><strong>Recommended:</strong> ${escHtml(issue.action)}</div>` : ''}
      <div class="close-issue-footer">
        ${issue.rows && issue.rows.length > 0
          ? `<button class="close-detail-btn" data-issue-idx="${idx}" data-table-id="${tableId}">
               <i class="fa-solid fa-table-list fa-xs"></i>View ${issue.rows.length} Invoice${issue.rows.length !== 1 ? 's' : ''}
             </button>`
          : ''}
      </div>
      <div id="${tableId}" style="margin-top:12px;display:none;"></div>
    `;

    list.appendChild(card);

    // Wire up the "View" button to inline-expand the table
    const btn = card.querySelector('.close-detail-btn');
    if (btn) {
      btn.addEventListener('click', () => {
        const tbl = document.getElementById(tableId);
        if (!tbl) return;
        if (tbl.style.display !== 'none') {
          tbl.style.display = 'none';
          btn.innerHTML = `<i class="fa-solid fa-table-list fa-xs"></i>View ${issue.rows.length} Invoice${issue.rows.length !== 1 ? 's' : ''}`;
          return;
        }
        tbl.style.display = '';
        btn.innerHTML = `<i class="fa-solid fa-chevron-up fa-xs"></i>Hide`;

        if (tbl.dataset.rendered) return;
        tbl.dataset.rendered = '1';

        renderTable(tableId, { rows: issue.rows, columns: issue.columns, row_count: issue.rows.length }, {
          label: issue.title,
          filename: `close_${issue.id}.csv`,
          badgeCols: { hold_lookup_code: true, wfapproval_status: true, urgency: true },
          rowClickFn: issue.rowClickFn || null,
          rowColorFn: issue.id === 'holds'
            ? (row) => parseInt(row.days_on_hold || 0) > 7 ? 'pay-row-warn' : ''
            : issue.id === 'disc_urgent'
            ? () => 'pay-row-urgent'
            : null,
        });
      });
    }
  });
}

function renderAITab(kpis, findings, demoMode) {
  const empty   = document.getElementById('aiEmpty');
  const content = document.getElementById('aiContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const stp  = kpis.stp_rate !== null ? kpis.stp_rate.toFixed(1) + '% STP Rate' : 'STP Rate unknown';
  const disc = kpis.discount_at_risk > 0 ? `$${formatNum(kpis.discount_at_risk)} discount risk` : 'No discount risk';

  let summaryText = `<strong>${stp}.</strong> `;
  summaryText += `${kpis.unposted_count} unposted invoices. `;
  summaryText += `${kpis.hold_count} invoices on hold`;
  if (kpis.avg_days_on_hold !== null) summaryText += ` (avg ${kpis.avg_days_on_hold.toFixed(1)} days)`;
  summaryText += `. ${disc}. `;
  summaryText += `${kpis.pending_approval} invoices pending approval. `;
  summaryText += `Total AP volume: $${formatNum(kpis.total_amount || 0)}.`;

  if (findings && findings.length > 0) {
    summaryText += '<br><br><strong>Key findings:</strong><ul style="margin:8px 0 0 18px;padding:0;">';
    findings.forEach(f => {
      summaryText += `<li>${escHtml(f.description)}</li>`;
    });
    summaryText += '</ul>';
  }

  if (demoMode) {
    summaryText += '<br><em style="color:var(--text-muted);font-size:12px;">Note: These are demo figures.</em>';
  }

  document.getElementById('aiSummaryText').innerHTML = summaryText;

  // Reset chat and seed with context-aware welcome
  clearPayChat();
  const msgs = document.getElementById('payChatMessages');
  if (msgs) {
    const welcome = msgs.querySelector('#payChatWelcome .pay-chat-bubble');
    if (welcome) {
      const issues = findings && findings.length > 0
        ? findings.filter(f => f.severity === 'CRITICAL' || f.severity === 'HIGH').map(f => f.category).join(', ')
        : null;
      welcome.textContent = issues
        ? `Analysis complete. I see issues with: ${issues}. Ask me how to resolve them.`
        : `Analysis complete. AP health looks OK. Ask me anything about your payables data.`;
    }
  }
}

// ── Drill-down panel ──────────────────────────────────────────────────────────

function _openDrillPanel(title) {
  document.getElementById('drillHoldType').textContent = title;
  document.getElementById('drillLinesContent').innerHTML =
    '<p style="font-size:12px;color:var(--text-muted);margin:0;">Click "Load Lines" to see line-level detail.</p>';
  const linesBtn = document.getElementById('drillLinesBtn');
  if (linesBtn) { linesBtn.disabled = false; linesBtn.textContent = ''; linesBtn.innerHTML = '<i class="fa-solid fa-list fa-xs me-1"></i>Load Lines'; }
  document.getElementById('drillOverlay').classList.add('open');
  document.getElementById('drillPanel').classList.add('open');
  document.body.style.overflow = 'hidden';
}

function openDrillDown(holdRow) {
  payState.selectedHold = holdRow;
  payState.selectedInvoiceId = holdRow.invoice_id || null;

  const holdCode = holdRow.hold_lookup_code || holdRow.hold_type || '—';
  const action   = getHoldAction(holdCode, holdRow);

  _openDrillPanel(`Hold: ${holdCode}`);

  document.getElementById('drillHoldCode').textContent  = holdCode;
  document.getElementById('drillDays').textContent      = holdRow.days_on_hold !== undefined ? `${holdRow.days_on_hold} days` : '—';
  document.getElementById('drillInvNum').textContent    = holdRow.invoice_num || '—';
  document.getElementById('drillAmount').textContent    = holdRow.invoice_amount ? '$' + formatNum(holdRow.invoice_amount) : '—';
  document.getElementById('drillCurrency').textContent  = holdRow.invoice_currency_code || holdRow.currency_code || '—';
  document.getElementById('drillVendor').textContent    = holdRow.vendor_name || holdRow.vendor_id || '—';
  document.getElementById('drillSource').textContent    = holdRow.source || '—';
  document.getElementById('drillApproval').textContent  = holdRow.wfapproval_status || '—';
  document.getElementById('drillReason').textContent    = holdRow.hold_reason || '—';
  document.getElementById('drillOwner').innerHTML       = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent    = action.action;

  // Show hold-specific sections
  document.getElementById('drillReasonSection').style.display = '';
  document.getElementById('drillActionSection').style.display = '';
}

function openDiscountDrillDown(row) {
  payState.selectedHold = row;
  payState.selectedInvoiceId = row.invoice_id || null;

  const urgency = row.urgency || '—';
  _openDrillPanel(`Discount: ${row.invoice_num || row.invoice_id}`);

  document.getElementById('drillHoldCode').textContent  = urgency;
  const daysVal = row.days_to_discount !== undefined ? `${row.days_to_discount} days` : '—';
  document.getElementById('drillDays').textContent      = daysVal;
  document.getElementById('drillInvNum').textContent    = row.invoice_num || row.invoice_id || '—';
  document.getElementById('drillAmount').textContent    = row.discount_amount ? '$' + formatNum(row.discount_amount) + ' discount' : '—';
  document.getElementById('drillCurrency').textContent  = row.invoice_currency_code || row.currency_code || '—';
  document.getElementById('drillVendor').textContent    = row.vendor_name || '—';
  document.getElementById('drillSource').textContent    = `Gross: $${formatNum(row.gross_amount || 0)}`;
  document.getElementById('drillApproval').textContent  = row.discount_date || '—';

  // Urgency-based recommendation
  const discAmt = row.discount_amount ? '$' + formatNum(row.discount_amount) : '—';
  const grossAmt = row.gross_amount ? '$' + formatNum(row.gross_amount) : '—';
  const rec = urgency === 'URGENT'
    ? `Invoice ${row.invoice_num || '—'} from ${row.vendor_name || '—'}: ${discAmt} discount on ${grossAmt} expires ${row.discount_date || '—'} (${row.days_to_discount || '—'} days). Pay immediately — create manual payment batch via AP > Payments > Payment Batch > select ${row.invoice_num || '—'}. Escalate to AP Manager now.`
    : urgency === 'THIS_WEEK'
    ? `Invoice ${row.invoice_num || '—'} from ${row.vendor_name || '—'}: ${discAmt} discount on ${grossAmt} expires ${row.discount_date || '—'} (${row.days_to_discount || '—'} days). Schedule payment this week via AP > Payments > Payment Batch.`
    : `Invoice ${row.invoice_num || '—'} from ${row.vendor_name || '—'}: ${discAmt} discount on ${grossAmt} available until ${row.discount_date || '—'} (${row.days_to_discount || '—'} days). Include in next payment run.`;
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>AP Manager`;
  document.getElementById('drillAction').textContent = rec;

  // Hide hold-specific sections, show action
  document.getElementById('drillReasonSection').style.display = 'none';
  document.getElementById('drillActionSection').style.display = '';
}

function openApproverDrillDown(row) {
  payState.selectedHold = row;
  payState.selectedInvoiceId = null;  // aggregated row — no single invoice

  const holdType = row.hold_type || row.hold_lookup_code || '—';
  _openDrillPanel(`Hold Type: ${holdType}`);

  const baseAction = getHoldAction(holdType, {});

  document.getElementById('drillHoldCode').textContent  = holdType;
  document.getElementById('drillDays').textContent      = `Avg ${row.avg_days || '—'} days`;
  document.getElementById('drillInvNum').textContent    = `${row.invoice_count || row.hold_count || '—'} invoices`;
  document.getElementById('drillAmount').textContent    = row.total_amount ? '$' + formatNum(row.total_amount) : '—';
  document.getElementById('drillCurrency').textContent  = '(all)';
  document.getElementById('drillVendor').textContent    = `${row.hold_count || '—'} holds`;
  document.getElementById('drillSource').textContent    = `Min ${row.min_days || '—'} / Max ${row.max_days || '—'} days`;
  document.getElementById('drillApproval').textContent  = row.approval_status || '—';
  document.getElementById('drillReason').textContent    = `${row.hold_count || 0} open holds of this type`;
  document.getElementById('drillOwner').innerHTML       = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(baseAction.owner)}`;
  document.getElementById('drillAction').textContent    = `${row.hold_count || '—'} "${holdType}" holds (${row.invoice_count || '—'} invoices, $${formatNum(row.total_amount || 0)}, approval: ${row.approval_status || '—'}). Avg age: ${row.avg_days || '—'} days, min ${row.min_days || '—'} / max ${row.max_days || '—'} days. Owner: ${baseAction.owner}. Resolve by addressing each hold — click individual invoices in the Holds tab for specific guidance.`;

  document.getElementById('drillReasonSection').style.display = '';
  document.getElementById('drillActionSection').style.display = '';

  // No invoice lines for aggregated rows
  document.getElementById('drillLinesSection').style.display = 'none';
}

async function loadInvoiceLines() {
  const invoiceId = payState.selectedInvoiceId;
  if (!invoiceId) return;

  const btn     = document.getElementById('drillLinesBtn');
  const content = document.getElementById('drillLinesContent');
  btn.disabled  = true;
  btn.innerHTML = '<span class="spinner-border spinner-border-sm" style="width:12px;height:12px;border-width:2px;"></span> Loading…';
  content.innerHTML = '';

  try {
    const resp = await fetch(`/api/payables/invoice_lines/${invoiceId}`);
    const data = await resp.json();

    if (data.error) {
      content.innerHTML = `<p style="font-size:12px;color:#cf222e;">${escHtml(data.error)}</p>`;
      btn.innerHTML = '<i class="fa-solid fa-rotate-right fa-xs me-1"></i>Retry';
      btn.disabled = false;
      return;
    }

    const rows = data.rows || [];
    if (rows.length === 0) {
      content.innerHTML = '<p style="font-size:12px;color:var(--text-muted);margin:0;">No lines found for this invoice.</p>';
    } else {
      const cols = ['line_number', 'line_type', 'description', 'amount', 'quantity_invoiced', 'unit_price'];
      let html = '<div style="overflow-x:auto"><table class="drill-lines-table"><thead><tr>';
      const headers = { line_number: '#', line_type: 'Type', description: 'Description', amount: 'Amount', quantity_invoiced: 'Qty', unit_price: 'Unit Price' };
      cols.forEach(c => { html += `<th>${headers[c] || c}</th>`; });
      html += '</tr></thead><tbody>';
      rows.forEach(row => {
        html += '<tr>';
        cols.forEach(c => {
          let val = row[c] ?? '—';
          if (c === 'amount' || c === 'unit_price') val = val !== '—' ? '$' + formatNum(val) : '—';
          html += `<td>${escHtml(String(val))}</td>`;
        });
        html += '</tr>';
      });
      html += '</tbody></table></div>';
      if (data.demo_mode) html += '<p style="font-size:11px;color:var(--text-muted);margin-top:6px;"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo data</p>';
      content.innerHTML = html;
    }
    btn.innerHTML = '<i class="fa-solid fa-check fa-xs me-1"></i>Loaded';
    btn.disabled = true;
  } catch (err) {
    content.innerHTML = `<p style="font-size:12px;color:#cf222e;">Error: ${escHtml(err.message)}</p>`;
    btn.innerHTML = '<i class="fa-solid fa-rotate-right fa-xs me-1"></i>Retry';
    btn.disabled = false;
  }
}

function closeDrillDown() {
  payState.selectedHold = null;
  payState.selectedInvoiceId = null;
  payState.selectedVendorId = null;
  document.getElementById('drillOverlay').classList.remove('open');
  document.getElementById('drillPanel').classList.remove('open');
  document.body.style.overflow = '';
  // Reset section visibility for next open
  document.getElementById('drillLinesSection').style.display = '';
  const vhSec = document.getElementById('drillVendorHistSection');
  if (vhSec) vhSec.style.display = 'none';
  const dupSec = document.getElementById('drillDupSection');
  if (dupSec) dupSec.style.display = 'none';
}

// ── Tab switcher ──────────────────────────────────────────────────────────────

function switchTab(tabId) {
  payState.activeTab = tabId;

  document.querySelectorAll('.pay-tab').forEach(btn => btn.classList.remove('active'));
  document.querySelectorAll('.pay-pane').forEach(pane => pane.classList.remove('active'));

  const tabBtn  = document.getElementById('tab-' + tabId);
  const tabPane = document.getElementById('pane-' + tabId);
  if (tabBtn)  tabBtn.classList.add('active');
  if (tabPane) tabPane.classList.add('active');

  // Persist active tab so it survives navigation
  try {
    const raw = sessionStorage.getItem(PAY_STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      parsed.activeTab = tabId;
      sessionStorage.setItem(PAY_STORAGE_KEY, JSON.stringify(parsed));
    }
  } catch (_) {}
}

// ── CSV export ────────────────────────────────────────────────────────────────

function exportCSV(rows, columns, filename) {
  if (!rows || rows.length === 0) return;

  const escCSV = (v) => {
    const s = (v === null || v === undefined) ? '' : String(v);
    return s.includes(',') || s.includes('"') || s.includes('\n')
      ? '"' + s.replace(/"/g, '""') + '"'
      : s;
  };

  const header = columns.join(',');
  const body   = rows.map(row => columns.map(c => escCSV(row[c])).join(',')).join('\n');
  const csv    = header + '\n' + body;

  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href     = url;
  a.download = filename || 'export.csv';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

// ── Send to AI chat ────────────────────────────────────────────────────────────

function sendToAI() {
  const data = payState.data;
  if (!data) return;

  const k = data.kpis;
  let msg = `I need help analyzing Oracle EBS Payables. Here is the current AP health data (last ${payState.daysBack} days):\n\n`;
  msg += `STP Rate: ${k.stp_rate !== null ? k.stp_rate.toFixed(1) + '%' : 'N/A'}\n`;
  msg += `Hold Rate: ${k.hold_rate !== null ? k.hold_rate.toFixed(1) + '%' : 'N/A'}\n`;
  msg += `Avg Days on Hold: ${k.avg_days_on_hold !== null ? k.avg_days_on_hold.toFixed(1) : 'N/A'}\n`;
  msg += `Total Invoices: ${k.total_invoices}\n`;
  msg += `Unposted Count: ${k.unposted_count}\n`;
  msg += `Hold Count: ${k.hold_count}\n`;
  msg += `Discount at Risk: $${formatNum(k.discount_at_risk || 0)}\n`;
  msg += `Pending Approval: ${k.pending_approval}\n\n`;

  if (data.findings && data.findings.length > 0) {
    msg += 'Key findings:\n';
    data.findings.forEach(f => { msg += `- [${f.severity}] ${f.description}\n`; });
    msg += '\n';
  }

  msg += 'Please provide recommendations to improve AP straight-through processing, resolve the holds, and capture the discount opportunities.';

  window.location.href = '/?chat=' + encodeURIComponent(msg);
}

// ── Inline page chat ──────────────────────────────────────────────────────────

let payChatHistory  = [];   // [{role:'user'|'assistant', content:''}]
let payChatStreaming = false;

function buildPayChatContext() {
  const data = payState.data;
  if (!data) return '';
  const k = data.kpis;
  let ctx = `Oracle EBS AP context (last ${payState.daysBack} days):\n`;
  ctx += `STP Rate: ${k.stp_rate !== null ? k.stp_rate.toFixed(1) + '%' : 'N/A'} | `;
  ctx += `Hold Rate: ${k.hold_rate !== null ? k.hold_rate.toFixed(1) + '%' : 'N/A'} | `;
  ctx += `Unposted: ${k.unposted_count} | Hold Count: ${k.hold_count} | `;
  ctx += `Discount at Risk: $${formatNum(k.discount_at_risk || 0)}\n`;
  if (data.findings && data.findings.length > 0) {
    ctx += 'Findings: ' + data.findings.map(f => `[${f.severity}] ${f.description}`).join('; ');
  }
  return ctx;
}

function addPayChatMsg(role, text, streaming) {
  const msgs = document.getElementById('payChatMessages');
  if (!msgs) return null;

  const div = document.createElement('div');
  div.className = `pay-chat-msg pay-chat-msg-${role === 'user' ? 'user' : 'ai'}`;

  const avatar = document.createElement('div');
  avatar.className = 'pay-chat-avatar';
  avatar.innerHTML = role === 'user'
    ? '<i class="fa-solid fa-user fa-xs"></i>'
    : '<i class="fa-solid fa-robot fa-xs"></i>';

  const bubble = document.createElement('div');
  bubble.className = 'pay-chat-bubble' + (streaming ? ' streaming' : '');
  bubble.innerHTML = text ? (typeof marked !== 'undefined' ? marked.parse(text) : escHtml(text)) : '';

  div.appendChild(avatar);
  div.appendChild(bubble);
  msgs.appendChild(div);
  msgs.scrollTop = msgs.scrollHeight;
  return bubble;
}

async function sendPayChat() {
  if (payChatStreaming) return;

  const input = document.getElementById('payChatInput');
  const sendBtn = document.getElementById('payChatSendBtn');
  const userText = (input.value || '').trim();
  if (!userText) return;

  // On first message, inject AP context
  let messages = [];
  if (payChatHistory.length === 0) {
    const ctx = buildPayChatContext();
    if (ctx) {
      messages.push({ role: 'user', content: ctx + '\n\nPlease confirm you have this AP context.' });
      messages.push({ role: 'assistant', content: 'Understood. I have your AP data context. Ask me anything about holds, STP rate, discounts, or recommendations.' });
    }
  }
  payChatHistory.forEach(h => messages.push(h));
  messages.push({ role: 'user', content: userText });

  // Render user msg
  const welcome = document.getElementById('payChatWelcome');
  if (welcome) welcome.remove();
  addPayChatMsg('user', escHtml(userText));
  input.value = '';

  // Disable input while streaming
  payChatStreaming = true;
  input.disabled = true;
  sendBtn.disabled = true;

  // Add streaming AI bubble
  const aiBubble = addPayChatMsg('assistant', '', true);

  let fullText = '';
  try {
    const resp = await fetch('/api/chat', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message: userText, history: messages.slice(0, -1), stream: true }),
    });

    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);

    const reader  = resp.body.getReader();
    const decoder = new TextDecoder();
    let   buf     = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += decoder.decode(value, { stream: true });

      const lines = buf.split('\n');
      buf = lines.pop();

      for (const line of lines) {
        if (!line.startsWith('data: ')) continue;
        const raw = line.slice(6).trim();
        if (raw === '[DONE]') continue;
        try {
          const ev = JSON.parse(raw);
          if (ev.token) {
            fullText += ev.token;
            if (aiBubble) {
              aiBubble.innerHTML = typeof marked !== 'undefined'
                ? marked.parse(fullText)
                : escHtml(fullText);
              aiBubble.closest('.pay-chat-messages') && (aiBubble.closest('.pay-chat-messages').scrollTop = aiBubble.closest('.pay-chat-messages').scrollHeight);
            }
          } else if (ev.error) {
            fullText += `\n\n*Error: ${ev.error}*`;
          }
        } catch (_) {}
      }
    }
  } catch (err) {
    fullText = `Sorry, I couldn't reach the AI service. (${err.message})`;
    if (aiBubble) aiBubble.innerHTML = escHtml(fullText);
  }

  // Finalize
  if (aiBubble) aiBubble.classList.remove('streaming');
  payChatHistory.push({ role: 'user', content: userText });
  payChatHistory.push({ role: 'assistant', content: fullText });
  saveChatHistory();

  payChatStreaming = false;
  input.disabled  = false;
  sendBtn.disabled = false;
  input.focus();
}

function clearPayChat() {
  payChatHistory = [];
  const msgs = document.getElementById('payChatMessages');
  if (!msgs) return;
  msgs.innerHTML = `
    <div class="pay-chat-msg pay-chat-msg-ai" id="payChatWelcome">
      <div class="pay-chat-avatar"><i class="fa-solid fa-robot fa-xs"></i></div>
      <div class="pay-chat-bubble">Ask me anything about your AP analysis.</div>
    </div>`;
}

// ── Error helper ──────────────────────────────────────────────────────────────

function showGlobalError(msg) {
  const pane = document.getElementById('pane-' + payState.activeTab);
  if (!pane) return;
  const empty = pane.querySelector('[id$="Empty"]');
  if (empty) {
    empty.classList.remove('d-none');
    empty.innerHTML = `<div class="pay-state-box">
      <div class="pay-state-icon"><i class="fa-solid fa-triangle-exclamation" style="color:#cf222e"></i></div>
      <div class="pay-state-title">Analysis failed</div>
      <div class="pay-state-sub">${escHtml(msg)}</div>
    </div>`;
  }
}

// ── Utility ───────────────────────────────────────────────────────────────────

function escHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatNum(n) {
  const num = parseFloat(n);
  if (isNaN(num)) return '0';
  if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
  if (num >= 10000)   return Math.round(num).toLocaleString();
  return num.toFixed(2).replace(/\.?0+$/, '');
}

// ── Demo data builders ────────────────────────────────────────────────────────

function buildDemoHealthRows() {
  const sources   = ['EDI', 'EDI', 'EDI', 'MANUAL', 'MANUAL', 'IMPORT'];
  const approvals = ['REQUIRED', 'REQUIRED', 'NOT REQUIRED', 'APPROVED', 'REQUIRED'];
  const vendors   = ['Acme Corp', 'TechSupply Inc', 'Global Parts Ltd', 'Pinnacle Services', 'DataSystems Co', 'FastLogistics'];
  return Array.from({ length: 10 }, (_, i) => ({
    invoice_id:        5000 + i,
    invoice_num:       `AP-2024-${1000 + i}`,
    invoice_amount:    (Math.random() * 50000 + 500).toFixed(2),
    invoice_currency_code: 'USD',
    vendor_name:       vendors[i % vendors.length],
    source:            sources[i % sources.length],
    wfapproval_status: approvals[i % approvals.length],
    days_open:         Math.floor(Math.random() * 30 + 1),
  }));
}

function buildDemoHoldRows() {
  const types   = ['PRICE', 'QTY RECEIVED', 'ACCOUNT', 'MANUAL', 'VARIANCE', 'DUPLICATE'];
  const reasons = [
    'Invoice price exceeds PO price by 5%',
    'Invoice quantity exceeds receipt quantity',
    'Distribution account invalid',
    'Manual hold applied by AP team',
    'Amount variance exceeds tolerance',
    'Possible duplicate of AP-2024-0891',
  ];
  const vendors = ['Acme Corp', 'TechSupply Inc', 'Global Parts Ltd', 'Pinnacle Services', 'DataSystems Co', 'FastLogistics'];
  return Array.from({ length: 12 }, (_, i) => ({
    invoice_id:        5100 + i,
    invoice_num:       `AP-2024-${800 + i}`,
    hold_lookup_code:  types[i % types.length],
    hold_reason:       reasons[i % reasons.length],
    days_on_hold:      Math.floor(Math.random() * 12 + 1),
    invoice_amount:    (Math.random() * 30000 + 200).toFixed(2),
    invoice_currency_code: 'USD',
    vendor_name:       vendors[i % vendors.length],
    wfapproval_status: i % 3 === 0 ? 'APPROVED' : 'REQUIRED',
    source:            i % 2 === 0 ? 'EDI' : 'MANUAL',
  }));
}

function buildDemoApproversRows() {
  return [
    { hold_type: 'PRICE',       approval_status: 'REQUIRED',     invoice_count: 7, hold_count: 7,  total_amount: 145000, min_days: 1, max_days: 10, avg_days: 4.2 },
    { hold_type: 'QTY RECEIVED',approval_status: 'NOT REQUIRED', invoice_count: 3, hold_count: 3,  total_amount: 62000,  min_days: 2, max_days: 8,  avg_days: 5.0 },
    { hold_type: 'ACCOUNT',     approval_status: 'APPROVED',     invoice_count: 2, hold_count: 2,  total_amount: 34000,  min_days: 3, max_days: 7,  avg_days: 4.8 },
    { hold_type: 'MANUAL',      approval_status: 'REQUIRED',     invoice_count: 1, hold_count: 1,  total_amount: 9800,   min_days: 4, max_days: 4,  avg_days: 4.0 },
    { hold_type: 'VARIANCE',    approval_status: 'REQUIRED',     invoice_count: 1, hold_count: 1,  total_amount: 5200,   min_days: 6, max_days: 6,  avg_days: 6.0 },
    { hold_type: 'DUPLICATE',   approval_status: 'NOT REQUIRED', invoice_count: 1, hold_count: 1,  total_amount: 2400,   min_days: 1, max_days: 1,  avg_days: 1.0 },
  ];
}

function buildDemoDiscountRows() {
  const urgencies = ['URGENT', 'URGENT', 'THIS_WEEK', 'THIS_WEEK', 'UPCOMING'];
  const now = new Date();
  return Array.from({ length: 8 }, (_, i) => {
    const daysOut  = i < 2 ? i + 1 : i < 4 ? i + 3 : i + 8;
    const discDate = new Date(now.getTime() + daysOut * 86400000);
  const vendors = ['Acme Corp', 'TechSupply Inc', 'Global Parts Ltd', 'Pinnacle Services', 'DataSystems Co'];
    return {
      invoice_id:           20000 + i,
      invoice_num:          `AP-2024-${900 + i}`,
      vendor_name:          vendors[i % vendors.length],
      payment_num:          1,
      discount_date:        discDate.toISOString().slice(0, 10),
      discount_amount:      (Math.random() * 3000 + 200).toFixed(2),
      gross_amount:         (Math.random() * 60000 + 5000).toFixed(2),
      invoice_currency_code: 'USD',
      days_to_discount:     daysOut,
      urgency:              urgencies[i % urgencies.length],
    };
  });
}

function buildDemoUnapprovedRows() {
  const statuses  = ['REQUIRED', 'REQUIRED', 'INITIATED', 'REJECTED', 'REQUIRED', 'INITIATED', 'REQUIRED', 'REJECTED'];
  const vendors   = ['Acme Corp', 'TechSupply Inc', 'Global Parts Ltd', 'Pinnacle Services', 'DataSystems Co', 'FastLogistics', 'BuildRight LLC', 'MedEquip Co'];
  const sources   = ['EDI', 'MANUAL', 'IMPORT', 'EDI', 'MANUAL', 'EDI', 'IMPORT', 'MANUAL'];
  const approvers = ['John Smith', 'Mary Jones', 'Robert Lee', null, 'Tina Patel', 'David Chen', 'John Smith', null];
  const totalAmt  = 234750;
  return Array.from({ length: 8 }, (_, i) => ({
    invoice_id:            6000 + i,
    invoice_num:           `AP-2024-${1100 + i}`,
    vendor_id:             200 + i,
    vendor_name:           vendors[i],
    invoice_amount:        (Math.random() * 40000 + 1000).toFixed(2),
    invoice_currency_code: 'USD',
    wfapproval_status:     statuses[i],
    source:                sources[i],
    days_waiting:          Math.floor(Math.random() * 20 + 1),
    current_approver:      approvers[i],
    total_unapproved:      8,
    total_amount_at_risk:  totalAmt,
    by_status:             statuses.filter(s => s === statuses[i]).length,
  }));
}

function buildDemoDupRows() {
  return [
    { vendor_id: 201, vendor_name: 'TechSupply Inc',   invoice_num: 'AP-2024-0550', invoice_amount: 12450,  invoice_currency_code: 'USD', invoice_date: '2024-03-01', dup_invoice_num: 'AP-2024-0551', dup_invoice_date: '2024-03-08', date_diff_days: 7 },
    { vendor_id: 202, vendor_name: 'Global Parts Ltd',  invoice_num: 'AP-2024-0620', invoice_amount: 8900,   invoice_currency_code: 'USD', invoice_date: '2024-03-05', dup_invoice_num: 'AP-2024-0621', dup_invoice_date: '2024-03-10', date_diff_days: 5 },
    { vendor_id: 203, vendor_name: 'Acme Corp',         invoice_num: 'AP-2024-0701', invoice_amount: 32100,  invoice_currency_code: 'USD', invoice_date: '2024-03-12', dup_invoice_num: 'AP-2024-0705', dup_invoice_date: '2024-03-18', date_diff_days: 6 },
    { vendor_id: 204, vendor_name: 'Pinnacle Services', invoice_num: 'AP-2024-0811', invoice_amount: 5500,   invoice_currency_code: 'USD', invoice_date: '2024-03-20', dup_invoice_num: 'AP-2024-0812', dup_invoice_date: '2024-03-25', date_diff_days: 5 },
  ];
}

function buildDemoNonPoRows() {
  const vendors = ['Acme Corp', 'TechSupply Inc', 'Global Parts Ltd', 'Pinnacle Services', 'DataSystems Co', 'FastLogistics', 'BuildRight LLC', 'MedEquip Co', 'Utility Co', 'Office Depot'];
  const sources = ['MANUAL', 'MANUAL', 'IMPORT', 'MANUAL', 'EDI', 'MANUAL', 'MANUAL', 'IMPORT', 'MANUAL', 'MANUAL'];
  const totalAmt = 187600;
  return Array.from({ length: 10 }, (_, i) => ({
    invoice_id:            6100 + i,
    invoice_num:           `AP-2024-${1200 + i}`,
    vendor_id:             210 + i,
    vendor_name:           vendors[i],
    invoice_amount:        (Math.random() * 25000 + 200).toFixed(2),
    invoice_currency_code: 'USD',
    source:                sources[i],
    wfapproval_status:     i % 3 === 0 ? 'APPROVED' : 'REQUIRED',
    posting_status:        i % 4 === 0 ? 'Y' : 'N',
    days_old:              Math.floor(Math.random() * 45 + 1),
    total_non_po_amount:   totalAmt,
  }));
}

function buildDemoAgingRows() {
  return [
    { vendor_id: 201, vendor_name: 'Acme Corp',         invoice_count: 8,  bucket_0_30: 42000,  bucket_31_60: 15000, bucket_61_90: 0,     bucket_over_90: 0,     total_outstanding: 57000  },
    { vendor_id: 202, vendor_name: 'TechSupply Inc',     invoice_count: 5,  bucket_0_30: 18500,  bucket_31_60: 22000, bucket_61_90: 9500,  bucket_over_90: 0,     total_outstanding: 50000  },
    { vendor_id: 203, vendor_name: 'Global Parts Ltd',   invoice_count: 12, bucket_0_30: 61000,  bucket_31_60: 8000,  bucket_61_90: 5500,  bucket_over_90: 12000, total_outstanding: 86500  },
    { vendor_id: 204, vendor_name: 'Pinnacle Services',  invoice_count: 3,  bucket_0_30: 9800,   bucket_31_60: 0,     bucket_61_90: 0,     bucket_over_90: 6200,  total_outstanding: 16000  },
    { vendor_id: 205, vendor_name: 'DataSystems Co',     invoice_count: 6,  bucket_0_30: 31000,  bucket_31_60: 14500, bucket_61_90: 0,     bucket_over_90: 0,     total_outstanding: 45500  },
    { vendor_id: 206, vendor_name: 'FastLogistics',      invoice_count: 4,  bucket_0_30: 7200,   bucket_31_60: 3100,  bucket_61_90: 4800,  bucket_over_90: 0,     total_outstanding: 15100  },
    { vendor_id: 207, vendor_name: 'BuildRight LLC',     invoice_count: 2,  bucket_0_30: 0,      bucket_31_60: 0,     bucket_61_90: 0,     bucket_over_90: 28500, total_outstanding: 28500  },
    { vendor_id: 208, vendor_name: 'MedEquip Co',        invoice_count: 7,  bucket_0_30: 54000,  bucket_31_60: 6500,  bucket_61_90: 2100,  bucket_over_90: 0,     total_outstanding: 62600  },
  ];
}

function buildDemoMatchExcRows() {
  const holdTypes = ['PRICE', 'QTY ORDERED', 'QTY RECEIVED', 'AMOUNT ORDERED', 'VARIANCE', 'PRICE', 'QTY RECEIVED'];
  const reasons   = [
    'Invoice unit price $142 vs PO price $128',
    'Invoice quantity 500 vs PO quantity 450',
    'Invoice quantity 200 vs receipt quantity 185',
    'Invoice amount $24,500 vs PO amount $22,000',
    'Amount variance $1,200 exceeds 5% tolerance',
    'Invoice unit price $89 vs PO price $80',
    'Invoice quantity 90 vs receipt quantity 75',
  ];
  const vendors = ['Acme Corp', 'TechSupply Inc', 'Global Parts Ltd', 'Pinnacle Services', 'DataSystems Co', 'FastLogistics', 'BuildRight LLC'];
  return Array.from({ length: 7 }, (_, i) => ({
    invoice_id:            6200 + i,
    invoice_num:           `AP-2024-${1300 + i}`,
    vendor_id:             220 + i,
    vendor_name:           vendors[i],
    hold_type:             holdTypes[i],
    hold_reason:           reasons[i],
    invoice_amount:        (Math.random() * 30000 + 1000).toFixed(2),
    invoice_currency_code: 'USD',
    days_on_hold:          Math.floor(Math.random() * 15 + 1),
    by_hold_type:          holdTypes.filter(h => h === holdTypes[i]).length,
  }));
}

function buildDemoCycleTimeRows() {
  const bands   = ['FAST', 'NORMAL', 'NORMAL', 'SLOW', 'CRITICAL', 'FAST', 'NORMAL', 'SLOW', 'NORMAL', 'CRITICAL', 'FAST', 'NORMAL', 'SLOW', 'NORMAL', 'FAST'];
  const vendors = ['Acme Corp', 'TechSupply Inc', 'Global Parts Ltd', 'Pinnacle Services', 'DataSystems Co',
                   'FastLogistics', 'BuildRight LLC', 'MedEquip Co', 'Acme Corp', 'TechSupply Inc',
                   'Global Parts Ltd', 'Pinnacle Services', 'DataSystems Co', 'FastLogistics', 'BuildRight LLC'];
  const avgCycle = 6.4;
  return Array.from({ length: 15 }, (_, i) => {
    const cycleDays = bands[i] === 'FAST' ? Math.floor(Math.random() * 3 + 1)
                    : bands[i] === 'NORMAL' ? Math.floor(Math.random() * 7 + 4)
                    : bands[i] === 'SLOW' ? Math.floor(Math.random() * 7 + 8)
                    : Math.floor(Math.random() * 10 + 15);
    const base = new Date('2024-03-01');
    const received = new Date(base.getTime() + i * 2 * 86400000);
    const posted   = new Date(received.getTime() + cycleDays * 86400000);
    return {
      invoice_id:            6300 + i,
      invoice_num:           `AP-2024-${1400 + i}`,
      vendor_id:             230 + i,
      vendor_name:           vendors[i],
      invoice_amount:        (Math.random() * 20000 + 500).toFixed(2),
      invoice_currency_code: 'USD',
      source:                i % 3 === 0 ? 'EDI' : i % 3 === 1 ? 'MANUAL' : 'IMPORT',
      received_date:         received.toISOString().slice(0, 10),
      posting_date:          posted.toISOString().slice(0, 10),
      cycle_days:            cycleDays,
      avg_cycle_days:        avgCycle,
      cycle_band:            bands[i],
    };
  });
}

function buildDemoPrepayRows() {
  return [
    { invoice_id: 6400, invoice_num: 'PP-2024-0001', vendor_id: 240, vendor_name: 'TechSupply Inc',   prepayment_amount: 50000, unapplied_amount: 50000, invoice_currency_code: 'USD', invoice_date: '2024-01-15', days_outstanding: 75, wfapproval_status: 'APPROVED', total_prepay_amount: 92500 },
    { invoice_id: 6401, invoice_num: 'PP-2024-0002', vendor_id: 241, vendor_name: 'BuildRight LLC',    prepayment_amount: 28500, unapplied_amount: 14250, invoice_currency_code: 'USD', invoice_date: '2024-02-10', days_outstanding: 49, wfapproval_status: 'APPROVED', total_prepay_amount: 92500 },
    { invoice_id: 6402, invoice_num: 'PP-2024-0003', vendor_id: 242, vendor_name: 'Global Parts Ltd',  prepayment_amount: 14000, unapplied_amount: 14000, invoice_currency_code: 'USD', invoice_date: '2024-03-01', days_outstanding: 29, wfapproval_status: 'APPROVED', total_prepay_amount: 92500 },
  ];
}

function buildDemoBottleneckRows() {
  return [
    { approver: 'JSMITH',   approver_name: 'John Smith',    pending_count: 12, avg_days_waiting: 8.5, max_days_waiting: 21, total_amount_pending: 185000 },
    { approver: 'MJONES',   approver_name: 'Mary Jones',    pending_count: 8,  avg_days_waiting: 5.2, max_days_waiting: 11, total_amount_pending: 94000  },
    { approver: 'RLEE',     approver_name: 'Robert Lee',    pending_count: 5,  avg_days_waiting: 3.8, max_days_waiting: 9,  total_amount_pending: 67500  },
    { approver: 'TPATEL',   approver_name: 'Tina Patel',    pending_count: 4,  avg_days_waiting: 6.1, max_days_waiting: 14, total_amount_pending: 42000  },
    { approver: 'DCHEN',    approver_name: 'David Chen',    pending_count: 2,  avg_days_waiting: 2.0, max_days_waiting: 3,  total_amount_pending: 18500  },
  ];
}

// ── State persistence (sessionStorage) ───────────────────────────────────────

const PAY_STORAGE_KEY = 'payables_state_v1';

function savePayablesState(data, daysBack) {
  try {
    sessionStorage.setItem(PAY_STORAGE_KEY, JSON.stringify({
      data,
      daysBack,
      activeTab: payState.activeTab,
      savedAt: Date.now(),
    }));
  } catch (_) { /* storage full — silently skip */ }
}

function saveChatHistory() {
  try {
    const stored = sessionStorage.getItem(PAY_STORAGE_KEY);
    if (!stored) return;
    const parsed = JSON.parse(stored);
    parsed.chatHistory = payChatHistory;
    sessionStorage.setItem(PAY_STORAGE_KEY, JSON.stringify(parsed));
  } catch (_) {}
}

function restorePayablesState() {
  try {
    const raw = sessionStorage.getItem(PAY_STORAGE_KEY);
    if (!raw) return false;
    const stored = JSON.parse(raw);
    const data = stored.data;
    if (!data || !data.kpis) return false;

    payState.data    = data;
    payState.daysBack = stored.daysBack || 30;

    // Restore days input
    const inp = document.getElementById('payDaysBack');
    if (inp) inp.value = payState.daysBack;

    // Re-render everything
    const banner = document.getElementById('payDemoBanner');
    if (data.demo_mode) banner.classList.remove('d-none');
    else                banner.classList.add('d-none');

    document.getElementById('payExecInfo').textContent =
      `Last run: ${stored.daysBack} days · restored`;

    updateKPIs(data.kpis, data.demo_mode);
    renderFindings(data.findings);
    renderHealthTab(data.queries.invoice_health, data.demo_mode);
    renderHoldsTab(data.queries.holds, data.demo_mode);
    renderApproversTab(data.queries.approvers, data.demo_mode);
    renderDiscountsTab(data.queries.discounts, data.demo_mode);
    renderCloseIssuesTab(data, data.demo_mode);
    renderUnapprovedTab(data.queries.unapproved_invoices,  data.demo_mode);
    renderDuplicateTab(data.queries.duplicate_risk,        data.demo_mode);
    renderNonPoTab(data.queries.non_po_invoices,           data.demo_mode);
    renderAgingTab(data.queries.supplier_aging,            data.demo_mode);
    renderMatchExcTab(data.queries.match_exceptions,       data.demo_mode);
    renderCycleTimeTab(data.queries.cycle_time,            data.demo_mode);
    renderPrepayTab(data.queries.open_prepayments,         data.demo_mode);
    renderBottleneckTab(data.queries.approval_bottleneck,  data.demo_mode);
    renderAITab(data.kpis, data.findings, data.demo_mode);
    updateTabCounts(data.queries);

    // Restore active tab
    if (stored.activeTab) switchTab(stored.activeTab);

    // Restore chat history
    if (stored.chatHistory && stored.chatHistory.length > 0) {
      payChatHistory = stored.chatHistory;
      const msgs = document.getElementById('payChatMessages');
      if (msgs) {
        msgs.innerHTML = '';
        payChatHistory.forEach(msg => addPayChatMsg(msg.role, msg.role === 'user' ? escHtml(msg.content) : msg.content));
      }
    }

    return true;
  } catch (_) { return false; }
}

// ── Init ──────────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
  // Try to restore previous session data first
  const restored = restorePayablesState();

  // Auto-run if ?autorun in URL (skip if we already have data)
  if (!restored && window.location.search.includes('autorun')) {
    runPayablesAnalysis();
  }

  // Keyboard: Escape closes drill-down
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeDrillDown();
  });

  // Save chat history before user leaves the page
  window.addEventListener('beforeunload', saveChatHistory);
});
