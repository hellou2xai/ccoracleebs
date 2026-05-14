/**
 * Oracle EBS — Supply Chain Planning Agentic App
 * Full client-side logic: run, render, drill-down, CSV export, AI send.
 */

'use strict';

// ── State ────────────────────────────────────────────────────────────────────

const scpState = {
  running: false,
  data: null,
  daysBack: 10000,
  activeTab: 'overview',
  selectedItem: null,
  selectedItemId: null,
  selectedPlanId: null,
};

// ── Exception action lookup (mirrors server-side EXCEPTION_ACTIONS) ─────────

const EXCEPTION_ACTIONS = {
  'SHORTAGE':          { owner: 'Planner',            actionTpl: (r) => `Item ${r.item_name || '—'}: short ${r.quantity || '—'} units, need date ${r.exception_date || '—'}. ${r.make_buy === 'BUY' ? 'BUY item — create requisition via ASCP > Planner Workbench > Release > Purchase Req.' : 'MAKE item — release planned WO via ASCP > Planner Workbench > Release > Discrete Job.'} Check alternate suppliers or substitutes if lead time is a concern. Planner: ${r.planner_code || '—'}.` },
  'EXCESS':            { owner: 'Planner',            actionTpl: (r) => `Item ${r.item_name || '—'}: ${r.quantity || '—'} excess units. Defer or cancel incoming supply via ASCP > Planner Workbench > ${r.item_name || '—'} > Supply tab > select excess order > Reschedule Out or Cancel. Planner: ${r.planner_code || '—'}.` },
  'RESCHEDULE IN':     { owner: 'Buyer/Planner',      actionTpl: (r) => `Item ${r.item_name || '—'}: expedite supply from ${r.exception_date || '—'} to ${r.suggested_date || '—'} (${r.days_delta || '—'} days earlier). Contact supplier or expedite WO. Update in PO > Change Order or WIP > Update Job. Planner: ${r.planner_code || '—'}.` },
  'RESCHEDULE OUT':    { owner: 'Planner',            actionTpl: (r) => `Item ${r.item_name || '—'}: defer supply from ${r.exception_date || '—'} to ${r.suggested_date || '—'} (${r.days_delta || '—'} days later). Reschedule via ASCP > Planner Workbench > Implement > Reschedule. Planner: ${r.planner_code || '—'}.` },
  'LATE SUPPLY':       { owner: 'Buyer',              actionTpl: (r) => `Item ${r.item_name || '—'}: supply arrives ${r.days_late || '—'} days after need date. Supply date: ${r.supply_date || '—'}, Need date: ${r.need_date || '—'}, Qty: ${r.supply_qty || '—'}. Expedite with supplier or find alternate source. Planner: ${r.planner_code || '—'}, Make/Buy: ${r.make_buy || '—'}.` },
  'CAPACITY OVERLOAD': { owner: 'Production Planner', actionTpl: (r) => `Supplier ${r.supplier_name || '—'} for ${r.item_name || '—'}: ${r.utilization_pct || '—'}% utilized (capacity: ${r.max_capacity || '—'}, allocated: ${r.allocated_qty || '—'}). Shift load to alternate resource, authorize overtime, or subcontract. Navigate to ASCP > Planner Workbench > Resource tab.` },
  'FORECAST DEVIATION':{ owner: 'Demand Planner',     actionTpl: (r) => `Item ${r.item_name || '—'}: forecast MAPE ${r.mape_pct || '—'}% (forecast: ${r.forecast_qty || '—'}, consumed: ${r.consumed_qty || '—'}). Band: ${r.accuracy_band || '—'}. Review demand history in Demantra or ASCP > Demand tab. Planner: ${r.planner_code || '—'}.` },
  'BELOW SAFETY STOCK':{ owner: 'Planner',            actionTpl: (r) => `Item ${r.item_name || '—'}: on-hand ${r.on_hand_qty || '—'} vs safety stock ${r.safety_stock_qty || '—'} (gap: ${r.gap || '—'} units, lead time: ${r.full_lead_time || '—'} days). ${r.make_buy === 'BUY' ? 'BUY item — create requisition via ASCP > Planner Workbench > Release > Purchase Req.' : 'MAKE item — release planned WO via ASCP > Planner Workbench > Release > Discrete Job.'} Severity: ${r.violation_severity || '—'}.` },
  'SOURCING DEVIATION':{ owner: 'Buyer',              actionTpl: (r) => `Item ${r.item_name || '—'}: sourcing rule says ${r.target_pct || '—'}% from ${r.preferred_supplier || '—'} but actual is ${r.actual_pct || '—'}% (deviation: ${r.deviation_pct || '—'}%). Review in ASCP > Sourcing > Sourcing Rules. Re-balance if needed. Planner: ${r.planner_code || '—'}.` },
  'SS_TOO_LOW':        { owner: 'Planner',            actionTpl: (r) => `Item ${r.item_name || '—'}: safety stock covers only ${r.ss_days_cover || '—'} days vs lead time ${r.full_lead_time || '—'} days. Demand CoV: ${r.demand_cov_pct || '—'}%. Increase SS quantity or switch to MRP-planned SS. Navigate to Item Master > Planning tab. Planner: ${r.planner_code || '—'}.` },
  'SS_TOO_HIGH':       { owner: 'Planner',            actionTpl: (r) => `Item ${r.item_name || '—'}: safety stock covers ${r.ss_days_cover || '—'} days (lead time only ${r.full_lead_time || '—'} days). Reduce SS quantity or set upper bound. Navigate to Item Master > Planning tab. Planner: ${r.planner_code || '—'}.` },
  'NO_SS_POLICY':      { owner: 'Planner',            actionTpl: (r) => `Item ${r.item_name || '—'} has no safety stock policy defined. Avg daily demand: ${r.avg_daily_demand || '—'}, lead time: ${r.full_lead_time || '—'} days. Set up MRP-planned safety stock in ASCP > Planning > Safety Stock Rules or fixed SS in Item Master. Planner: ${r.planner_code || '—'}.` },
  'PEGGING_LATE':      { owner: 'Planner/Buyer',      actionTpl: (r) => `Supply for ${r.item_name || '—'} (${r.supply_type || '—'}, qty ${r.pegged_qty || '—'}) arrives ${r.supply_date || '—'} but demand needs it by ${r.demand_date || '—'} (${r.days_gap || '—'} days late). Demand: ${r.demand_source || '—'} order ${r.demand_order || '—'}. End item: ${r.end_item_name || '—'}. Expedite or find alternate source. Planner: ${r.planner_code || '—'}.` },
  'SPARE_STOCKOUT':    { owner: 'MRO Planner',        actionTpl: (r) => `Spare part ${r.item_name || '—'}: ZERO stock, avg monthly usage ${r.avg_monthly_usage || '—'} units, lead time ${r.full_lead_time || '—'} days. Production line at risk. Create emergency requisition: PO > Requisitions > New > enter ${r.item_name || '—'}. Planner: ${r.planner_code || '—'}.` },
  'SPARE_OVERSTOCKED': { owner: 'MRO Planner',        actionTpl: (r) => `Spare part ${r.item_name || '—'}: on-hand ${r.on_hand_qty || '—'} vs max ${r.max_qty || '—'} (${r.months_of_supply || '—'} months of supply, value $${formatNum(r.inventory_value || 0)}). Cancel open POs or transfer to other locations. Planner: ${r.planner_code || '—'}.` },
  'SPARE_SLOW_MOVING': { owner: 'MRO Planner',        actionTpl: (r) => `Spare part ${r.item_name || '—'}: on-hand ${r.on_hand_qty || '—'} units ($${formatNum(r.inventory_value || 0)}) but zero usage in last 12 months. Candidate for disposition or return to supplier. Planner: ${r.planner_code || '—'}.` },
};

function getExceptionAction(exceptionType, row) {
  const key = (exceptionType || '').toUpperCase().replace(/_/g, ' ');
  for (const [k, v] of Object.entries(EXCEPTION_ACTIONS)) {
    if (k.includes(key) || key.includes(k)) {
      return { owner: v.owner, action: row ? v.actionTpl(row) : v.actionTpl({}) };
    }
  }
  const r = row || {};
  return { owner: 'Planning Team', action: `Item ${r.item_name || '—'}: review exception and contact appropriate team to resolve. Planner: ${r.planner_code || '—'}.` };
}

// ── Plan selector ────────────────────────────────────────────────────────────

async function loadPlanList() {
  const select = document.getElementById('scpPlanSelect');
  if (!select) return;
  select.innerHTML = '<option value="">Loading...</option>';
  try {
    const resp = await fetch('/api/scp/plans');
    const data = await resp.json();
    const plans = data.plans || [];
    select.innerHTML = '';
    if (plans.length === 0) {
      select.innerHTML = '<option value="">No plans found</option>';
      return;
    }
    // First plan is auto-selected (most recent)
    plans.forEach((p, i) => {
      const opt = document.createElement('option');
      opt.value = p.plan_id;
      const age = p.days_since_run !== null ? ` (${p.days_since_run}d ago)` : '';
      const exc = p.exception_count ? ` — ${p.exception_count} exc` : '';
      opt.textContent = `${p.plan_name} [${p.plan_type}]${age}${exc}`;
      if (i === 0) opt.selected = true;
      select.appendChild(opt);
    });
    if (data.demo_mode) {
      const demoOpt = document.createElement('option');
      demoOpt.disabled = true;
      demoOpt.textContent = '── Demo data ──';
      select.insertBefore(demoOpt, select.options[0]);
    }
  } catch (err) {
    console.error('Failed to load plan list:', err);
    select.innerHTML = '<option value="">Error loading plans</option>';
  }
}

// ── Main run function ────────────────────────────────────────────────────────

async function runScpAnalysis() {
  if (scpState.running) return;

  const daysInput = document.getElementById('scpDaysBack');
  const daysBack = Math.max(1, Math.min(10000, parseInt(daysInput.value) || 10000));
  scpState.daysBack = daysBack;

  const planSelect = document.getElementById('scpPlanSelect');
  const planId = planSelect ? planSelect.value : '';
  scpState.selectedPlanId = planId || null;

  // Refresh plan list (in case Oracle was just connected)
  loadPlanList();

  // Set loading state
  scpState.running = true;
  setScpRunButtonState(true);
  clearAllScpPanes();

  try {
    const body = { days_back: daysBack };
    if (planId) body.plan_id = parseInt(planId);
    const resp = await fetch('/api/scp/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (!resp.ok) {
      const err = await resp.json().catch(() => ({ error: `HTTP ${resp.status}` }));
      throw new Error(err.error || `HTTP ${resp.status}`);
    }

    const data = await resp.json();
    scpState.data = data;

    // Demo banner
    const banner = document.getElementById('scpDemoBanner');
    if (data.demo_mode) {
      banner.classList.remove('d-none');
    } else {
      banner.classList.add('d-none');
    }

    // Exec time
    const ms = data.execution_time_ms || 0;
    const sec = (ms / 1000).toFixed(1);
    document.getElementById('scpExecInfo').textContent =
      `Completed in ${sec}s · Last ${daysBack} days`;

    // Render everything
    updateScpKPIs(data.kpis, data.demo_mode);
    renderScpFindings(data.findings);
    renderOverviewTab(data.queries.plan_summary, data.demo_mode);
    renderExceptionsTab(data.queries.plan_exceptions, data.demo_mode);
    renderByTypeTab(data.queries.plan_exceptions, data.demo_mode);
    renderBalanceTab(data.queries.demand_supply_balance, data.demo_mode);
    renderActionsTab(data, data.demo_mode);
    renderForecastTab(data.queries.forecast_accuracy, data.demo_mode);
    renderSafetyStockTab(data.queries.safety_stock_violations, data.demo_mode);
    renderSSAnalysisTab(data.queries.safety_stock_analysis, data.demo_mode);
    renderLateSupplyTab(data.queries.late_supply, data.demo_mode);
    renderExcessTab(data.queries.excess_inventory, data.demo_mode);
    renderPeggingTab(data.queries.pegging_analysis, data.demo_mode);
    renderSparePartsTab(data.queries.spare_parts, data.demo_mode);
    renderCapacityTab(data.queries.supplier_capacity, data.demo_mode);
    renderSourcingTab(data.queries.sourcing_compliance, data.demo_mode);
    renderVariabilityTab(data.queries.demand_variability, data.demo_mode);
    renderCoverageTab(data.queries.item_coverage, data.demo_mode);
    renderGraphTab(data, data.demo_mode);
    renderScpAITab(data.kpis, data.findings, data.demo_mode);

    // Update tab counts
    updateScpTabCounts(data.queries);

    // Persist to sessionStorage so navigation doesn't lose the data
    saveScpState(data, daysBack);

  } catch (err) {
    console.error('SCP run error:', err);
    document.getElementById('scpExecInfo').textContent = '';
    showScpGlobalError(err.message || 'Analysis failed. Check console for details.');
  } finally {
    scpState.running = false;
    setScpRunButtonState(false);
  }
}

// ── Button state ─────────────────────────────────────────────────────────────

function setScpRunButtonState(loading) {
  const btn     = document.getElementById('scpRunBtn');
  const icon    = document.getElementById('scpRunIcon');
  const label   = document.getElementById('scpRunLabel');
  const spinner = document.getElementById('scpRunSpinner');

  btn.disabled = loading;
  if (loading) {
    icon.className = 'fa-solid fa-play fa-xs d-none';
    label.textContent = 'Analyzing\u2026';
    spinner.classList.remove('d-none');
  } else {
    icon.className = 'fa-solid fa-play fa-xs';
    label.textContent = 'Run Analysis';
    spinner.classList.add('d-none');
  }
}

// ── Clear panes ──────────────────────────────────────────────────────────────

function clearAllScpPanes() {
  ['overview','exceptions','bytype','balance','actions',
   'forecast','safetystock','ssanalysis','latesupply','excess',
   'pegging','spareparts','capacity','sourcing','variability','coverage'].forEach(tab => {
    const empty   = document.getElementById(tab + 'Empty');
    const content = document.getElementById(tab + 'Content');
    if (empty)   { empty.classList.remove('d-none'); empty.innerHTML = scpLoadingState(); }
    if (content) { content.classList.add('d-none'); content.innerHTML = ''; }
  });
  // Reset graph pane
  const graphEmpty   = document.getElementById('graphEmpty');
  const graphContent = document.getElementById('graphContent');
  if (graphEmpty)   graphEmpty.classList.remove('d-none');
  if (graphContent) graphContent.classList.add('d-none');
  if (scpGraphNetwork) { scpGraphNetwork.destroy(); scpGraphNetwork = null; }
  const graphBtn = document.getElementById('graphLoadBtn');
  if (graphBtn) { graphBtn.disabled = false; graphBtn.innerHTML = '<i class="fa-solid fa-diagram-project fa-xs me-1"></i>Load Graph'; }

  const aiEmpty   = document.getElementById('aiEmpty');
  const aiContent = document.getElementById('aiContent');
  if (aiEmpty)   aiEmpty.classList.remove('d-none');
  if (aiContent) aiContent.classList.add('d-none');

  document.getElementById('scpFindings').innerHTML =
    '<span class="scp-findings-label">Analyzing\u2026</span>';
}

function scpLoadingState() {
  return `<div class="scp-state-box">
    <div class="scp-state-icon"><span class="spinner-border" style="width:28px;height:28px;border-width:3px;color:var(--accent)"></span></div>
    <div class="scp-state-title">Loading\u2026</div>
    <div class="scp-state-sub">Querying Oracle ASCP tables</div>
  </div>`;
}

// ── KPI updater ──────────────────────────────────────────────────────────────

function updateScpKPIs(kpis, demoMode) {
  // Plan Freshness
  const freshness = kpis.plan_freshness_days;
  setScpKpiCard('kpiPlanAge',
    freshness !== null ? freshness.toFixed(1) + 'd' : '—',
    planAgeClass(freshness),
    freshness !== null ? `Last run ${freshness.toFixed(1)} days ago` : 'No plan data'
  );

  // Supply Gaps
  const gap = kpis.demand_supply_gap;
  setScpKpiCard('kpiGap',
    gap !== null ? gap : '—',
    gapClass(gap),
    `${gap} items where demand > supply`
  );

  // Exceptions
  const exc = kpis.exception_count;
  setScpKpiCard('kpiExceptions',
    exc !== null ? exc : '—',
    excClass(exc),
    `${exc} planning exceptions`
  );

  // Forecast MAPE
  const mape = kpis.forecast_mape;
  setScpKpiCard('kpiMape',
    mape !== null ? mape.toFixed(1) + '%' : '—',
    mapeClass(mape),
    mape !== null ? 'Mean absolute percentage error' : 'No forecast data'
  );

  // SS Compliance
  const ss = kpis.ss_compliance_pct;
  setScpKpiCard('kpiSS',
    ss !== null ? ss.toFixed(1) + '%' : '—',
    ssClass(ss),
    ss !== null ? 'Items meeting safety stock target' : 'No SS data'
  );

  // Days of Supply
  const dos = kpis.avg_days_of_supply;
  setScpKpiCard('kpiDoS',
    dos !== null ? dos.toFixed(1) + 'd' : '—',
    dosClass(dos, kpis),
    dos !== null ? 'Average across all items' : 'No coverage data'
  );
}

function setScpKpiCard(cardId, value, cssClass, detail) {
  const card   = document.getElementById(cardId);
  const valEl  = document.getElementById(cardId + 'Val');
  const detEl  = document.getElementById(cardId + 'Detail');
  if (!card) return;
  card.classList.remove('loading', 'kpi-ok', 'kpi-warn', 'kpi-critical', 'kpi-info');
  if (cssClass) card.classList.add(cssClass);
  if (valEl) valEl.textContent = value;
  if (detEl) detEl.textContent = detail || '';
}

function planAgeClass(v) {
  if (v === null || v === undefined) return '';
  if (v <= 1) return 'kpi-ok';
  if (v <= 3) return 'kpi-warn';
  return 'kpi-critical';
}
function gapClass(v) {
  if (v === null || v === undefined) return '';
  if (v === 0) return 'kpi-ok';
  if (v <= 10) return 'kpi-warn';
  return 'kpi-critical';
}
function excClass(v) {
  if (v === null || v === undefined) return '';
  if (v <= 20) return 'kpi-ok';
  if (v <= 100) return 'kpi-warn';
  return 'kpi-critical';
}
function mapeClass(v) {
  if (v === null || v === undefined) return '';
  if (v <= 15) return 'kpi-ok';
  if (v <= 30) return 'kpi-warn';
  return 'kpi-critical';
}
function ssClass(v) {
  if (v === null || v === undefined) return '';
  if (v >= 95) return 'kpi-ok';
  if (v >= 80) return 'kpi-warn';
  return 'kpi-critical';
}
function dosClass(v, kpis) {
  if (v === null || v === undefined) return '';
  // Simple heuristic: 14+ days is ok, 7-14 warn, <7 critical
  if (v >= 14) return 'kpi-ok';
  if (v >= 7) return 'kpi-warn';
  return 'kpi-critical';
}

// ── Findings renderer ─────────────────────────────────────────────────────────

function renderScpFindings(findings) {
  const bar = document.getElementById('scpFindings');
  if (!findings || findings.length === 0) {
    bar.innerHTML = '<span class="scp-findings-label" style="color:var(--low)"><i class="fa-solid fa-circle-check me-1"></i>No significant findings</span>';
    return;
  }

  const sevIcon = { CRITICAL: 'fa-circle-exclamation', HIGH: 'fa-triangle-exclamation',
                    MEDIUM: 'fa-circle-info', INFO: 'fa-circle-dot', LOW: 'fa-circle-check' };

  bar.innerHTML = '<span class="scp-findings-label">Findings:</span>' +
    findings.map(f => {
      const icon = sevIcon[f.severity] || 'fa-circle-dot';
      return `<span class="scp-finding-pill sev-${f.severity}" title="${escHtml(f.description)}">
        <i class="fa-solid ${icon} fa-xs"></i>
        ${escHtml(f.category)} <strong>${f.count}</strong>
      </span>`;
    }).join('');
}

// ── Tab counts ────────────────────────────────────────────────────────────────

function updateScpTabCounts(queries) {
  const map = {
    overview:     'plan_summary',
    exceptions:   'plan_exceptions',
    balance:      'demand_supply_balance',
    forecast:     'forecast_accuracy',
    safetystock:  'safety_stock_violations',
    ssanalysis:   'safety_stock_analysis',
    latesupply:   'late_supply',
    excess:       'excess_inventory',
    pegging:      'pegging_analysis',
    spareparts:   'spare_parts',
    capacity:     'supplier_capacity',
    sourcing:     'sourcing_compliance',
    variability:  'demand_variability',
    coverage:     'item_coverage',
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
  // bytype tab — count distinct types
  const excRows = (queries.plan_exceptions || {}).rows || [];
  const byTypeEl = document.getElementById('cnt-bytype');
  if (byTypeEl) {
    const types = new Set(excRows.map(r => r.exception_name || r.exception_type));
    byTypeEl.textContent = types.size || '—';
  }
}

// ── Generic table renderer ────────────────────────────────────────────────────

function renderScpTable(containerId, queryResult, opts = {}) {
  const container = document.getElementById(containerId);
  if (!container) return;

  const { rowColorFn, rowClickFn, badgeCols = {}, filename = 'export.csv', label = '' } = opts;

  if (!queryResult || queryResult.error) {
    container.innerHTML = `<div class="scp-error-badge">
      <i class="fa-solid fa-triangle-exclamation fa-xs"></i>
      Query error: ${escHtml((queryResult && queryResult.error) || 'Unknown error')}
    </div>`;
    return;
  }

  const rows = queryResult.rows || [];
  const cols = queryResult.columns || [];

  if (rows.length === 0) {
    container.innerHTML = `<div class="scp-state-box">
      <div class="scp-state-icon"><i class="fa-solid fa-circle-check"></i></div>
      <div class="scp-state-title">No records found</div>
      <div class="scp-state-sub">No ${label || 'data'} in the selected period.</div>
    </div>`;
    return;
  }

  // CSV button uses a stable data-key
  const toolbar = `<div class="scp-table-toolbar">
    <div class="scp-table-info">
      Showing <strong>${rows.length}</strong> ${label || 'rows'} \u00b7 ${queryResult.row_count} total
    </div>
    <button class="scp-csv-btn" data-csv-id="${containerId}">
      <i class="fa-solid fa-download fa-xs"></i> CSV
    </button>
  </div>`;

  const thead = `<thead><tr>${cols.map(c => `<th>${escHtml(c.replace(/_/g,' '))}</th>`).join('')}</tr></thead>`;

  const tbody = '<tbody>' + rows.map((row, idx) => {
    const colorClass = rowColorFn ? rowColorFn(row) : '';
    const clickable  = rowClickFn ? 'scp-row-click' : '';
    const idxAttr    = rowClickFn ? `data-row-idx="${idx}"` : '';
    return `<tr class="${colorClass} ${clickable}" ${idxAttr}>${
      cols.map(c => {
        const val = row[c];
        const display = badgeCols[c] ? makeScpBadge(c, val) : escHtml(val !== null && val !== undefined ? String(val) : '');
        return `<td>${display}</td>`;
      }).join('')
    }</tr>`;
  }).join('') + '</tbody>';

  container.innerHTML = toolbar + `<div class="scp-table-wrap"><table class="scp-table">${thead}${tbody}</table></div>`;

  // Event delegation for row clicks
  if (rowClickFn) {
    const tbodyEl = container.querySelector('tbody');
    if (tbodyEl) {
      tbodyEl.addEventListener('click', (e) => {
        const tr = e.target.closest('tr[data-row-idx]');
        if (tr) {
          const idx = parseInt(tr.dataset.rowIdx, 10);
          if (!isNaN(idx) && rows[idx]) rowClickFn(rows[idx]);
        }
      });
    }
  }

  // CSV export
  const csvBtn = container.querySelector('.scp-csv-btn[data-csv-id]');
  if (csvBtn) {
    csvBtn.addEventListener('click', () => exportScpCSV(rows, cols, filename));
  }
}

function makeScpBadge(colName, val) {
  const v = (val || '').toString().toUpperCase().replace(/ /g, '_');
  if (colName === 'balance_status' || colName === 'violation_severity' || colName === 'capacity_risk'
      || colName === 'pegging_status' || colName === 'spare_status' || colName === 'coverage_band'
      || colName === 'accuracy_band' || colName === 'demand_pattern' || colName === 'compliance_status'
      || colName === 'ss_assessment' || colName === 'urgency') {
    return `<span class="scp-type-badge urg-${v}">${escHtml(val)}</span>`;
  }
  return `<span class="scp-type-badge">${escHtml(val)}</span>`;
}

// ── Tab renderers ─────────────────────────────────────────────────────────────

// 1. Overview — Plan Summary
function renderOverviewTab(result, demoMode) {
  const empty   = document.getElementById('overviewEmpty');
  const content = document.getElementById('overviewContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  let html = '';
  if (demoMode) {
    html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live data</div>`;
  }

  const rows = demoMode ? buildDemoPlanRows() : (result && result.rows ? result.rows : []);
  if (rows.length > 0) {
    const latest = rows[0];
    html += `<div style="margin-bottom:12px;">
      <div class="scp-pill-group">
        <span class="scp-stat-pill"><strong>${latest.plan_type_name || '—'}</strong> Plan</span>
        <span class="scp-stat-pill"><strong>${latest.org_count || '—'}</strong> Orgs</span>
        <span class="scp-stat-pill"><strong>${latest.exception_count || '—'}</strong> Exceptions</span>
        <span class="scp-stat-pill"><strong>${latest.items_with_exceptions || '—'}</strong> Items w/ Exceptions</span>
      </div>
    </div>`;
  }

  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any plan row to see its exceptions and details.</p>';
  content.innerHTML = html + '<div id="overviewTable"></div>';

  const cols = ['plan_name','plan_type_name','plan_completion_date','plan_start_date','cutoff_date','days_since_run','exception_count','items_with_exceptions','org_count'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('overviewTable', displayResult, {
    label: 'plans',
    filename: 'plan_summary.csv',
    badgeCols: { plan_type_name: true },
    rowClickFn: openPlanDrillDown,
    rowColorFn: (row) => parseFloat(row.days_since_run || 0) > 3 ? 'scp-row-warn' : '',
  });
}

// 2. Exceptions
function renderExceptionsTab(result, demoMode) {
  const empty   = document.getElementById('exceptionsEmpty');
  const content = document.getElementById('exceptionsContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  let html = '';
  if (demoMode) {
    html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live data</div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row to see the recommended action for that exception.</p>';
  content.innerHTML = html + '<div id="exceptionsTable"></div>';

  const rows = demoMode ? buildDemoExceptionRows() : (result && result.rows ? result.rows : []);
  const cols = ['exception_name','item_name','planner_code','make_buy','quantity','exception_date','suggested_date','days_delta'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('exceptionsTable', displayResult, {
    label: 'exceptions',
    filename: 'plan_exceptions.csv',
    badgeCols: { exception_name: true },
    rowClickFn: openExceptionDrillDown,
    rowColorFn: (row) => {
      const t = (row.exception_name || '').toUpperCase();
      if (t.includes('SHORTAGE') || t.includes('LATE')) return 'scp-row-urgent';
      if (t.includes('EXCESS') || t.includes('RESCHEDULE')) return 'scp-row-warn';
      return '';
    },
  });
}

// 3. By Type (grouped exceptions)
function renderByTypeTab(result, demoMode) {
  const empty   = document.getElementById('bytypeEmpty');
  const content = document.getElementById('bytypeContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  let html = '';
  if (demoMode) {
    html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live data</div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any exception type for resolution guidance.</p>';
  content.innerHTML = html + '<div id="bytypeTable"></div>';

  const excRows = demoMode ? buildDemoExceptionRows() : (result && result.rows ? result.rows : []);
  // Group by exception type
  const grouped = {};
  excRows.forEach(r => {
    const t = r.exception_name || r.exception_type || 'UNKNOWN';
    if (!grouped[t]) grouped[t] = { exception_name: t, count: 0, total_qty: 0, items: new Set(), planners: new Set() };
    grouped[t].count++;
    grouped[t].total_qty += parseFloat(r.quantity || 0);
    if (r.item_name) grouped[t].items.add(r.item_name);
    if (r.planner_code) grouped[t].planners.add(r.planner_code);
  });
  const typeRows = Object.values(grouped).map(g => ({
    exception_name: g.exception_name,
    exception_count: g.count,
    total_quantity: Math.round(g.total_qty),
    distinct_items: g.items.size,
    planners: Array.from(g.planners).join(', '),
  })).sort((a, b) => b.exception_count - a.exception_count);

  const cols = ['exception_name','exception_count','total_quantity','distinct_items','planners'];
  const displayResult = { rows: typeRows, columns: cols, row_count: typeRows.length };

  renderScpTable('bytypeTable', displayResult, {
    label: 'exception types',
    filename: 'exceptions_by_type.csv',
    badgeCols: { exception_name: true },
    rowClickFn: openExceptionTypeDrillDown,
  });
}

// 4. Balance — Demand vs Supply
function renderBalanceTab(result, demoMode) {
  const empty   = document.getElementById('balanceEmpty');
  const content = document.getElementById('balanceContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoBalanceRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live data</div>`;

  if (rows.length > 0) {
    const shorts = rows.filter(r => r.balance_status === 'SHORT').length;
    const belowSS = rows.filter(r => r.balance_status === 'BELOW_SS').length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> items with supply gaps —
        <strong style="color:#cf222e;">${shorts}</strong> shortages,
        <strong style="color:#bf8700;">${belowSS}</strong> below safety stock.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for item details and supply/demand timeline.</p>';
  content.innerHTML = html + '<div id="balanceTable"></div>';

  const cols = ['item_name','planner_code','make_buy','total_demand_qty','total_supply_qty','net_position','safety_stock','balance_status'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('balanceTable', displayResult, {
    label: 'supply gaps',
    filename: 'demand_supply_balance.csv',
    badgeCols: { balance_status: true },
    rowClickFn: openItemDrillDown,
    rowColorFn: (row) => row.balance_status === 'SHORT' ? 'scp-row-urgent' : row.balance_status === 'BELOW_SS' ? 'scp-row-warn' : '',
  });
}

// 6. Forecast Accuracy
function renderForecastTab(result, demoMode) {
  const empty   = document.getElementById('forecastEmpty');
  const content = document.getElementById('forecastContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoForecastRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const avgMape = rows.reduce((s, r) => s + parseFloat(r.mape_pct || 0), 0) / rows.length;
    const overFc = rows.filter(r => r.accuracy_band === 'OVER_FORECAST').length;
    const underFc = rows.filter(r => r.accuracy_band === 'UNDER_FORECAST').length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        Avg MAPE: <strong>${avgMape.toFixed(1)}%</strong> across <strong>${rows.length}</strong> items.
        <strong>${overFc}</strong> over-forecast, <strong>${underFc}</strong> under-forecast.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for forecast details.</p>';
  content.innerHTML = html + '<div id="forecastTable"></div>';

  const cols = ['item_name','planner_code','forecast_designator','forecast_qty','consumed_qty','mape_pct','accuracy_band'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('forecastTable', displayResult, {
    label: 'forecast items',
    filename: 'forecast_accuracy.csv',
    badgeCols: { accuracy_band: true },
    rowClickFn: openForecastDrillDown,
    rowColorFn: (row) => parseFloat(row.mape_pct || 0) > 30 ? 'scp-row-urgent' : parseFloat(row.mape_pct || 0) > 15 ? 'scp-row-warn' : '',
  });
}

// 7. Safety Stock Violations
function renderSafetyStockTab(result, demoMode) {
  const empty   = document.getElementById('safetystockEmpty');
  const content = document.getElementById('safetystockContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoSSViolationRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const critCount = rows.filter(r => r.violation_severity === 'CRITICAL' || r.violation_severity === 'ZERO_STOCK').length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;${critCount > 0 ? 'background:rgba(207,34,46,.05);border-color:rgba(207,34,46,.2);' : ''}">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> items below safety stock —
        <strong style="color:#cf222e;">${critCount}</strong> critical/zero stock.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for replenishment guidance.</p>';
  content.innerHTML = html + '<div id="safetystockTable"></div>';

  const cols = ['item_name','planner_code','make_buy','on_hand_qty','safety_stock_qty','gap','violation_severity','full_lead_time'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('safetystockTable', displayResult, {
    label: 'SS violations',
    filename: 'safety_stock_violations.csv',
    badgeCols: { violation_severity: true },
    rowClickFn: openSSViolationDrillDown,
    rowColorFn: (row) => {
      const sev = (row.violation_severity || '').toUpperCase();
      if (sev === 'ZERO_STOCK' || sev === 'CRITICAL') return 'scp-row-urgent';
      return 'scp-row-warn';
    },
  });
}

// 8. Safety Stock Analysis
function renderSSAnalysisTab(result, demoMode) {
  const empty   = document.getElementById('ssanalysisEmpty');
  const content = document.getElementById('ssanalysisContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoSSAnalysisRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const noPolicy = rows.filter(r => r.ss_assessment === 'NO_POLICY').length;
    const tooLow = rows.filter(r => r.ss_assessment === 'SS_TOO_LOW' || r.ss_assessment === 'ZERO_SS').length;
    const tooHigh = rows.filter(r => r.ss_assessment === 'SS_TOO_HIGH').length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> items need SS policy review:
        <strong>${noPolicy}</strong> no policy,
        <strong>${tooLow}</strong> too low/zero,
        <strong>${tooHigh}</strong> too high.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for policy recommendations.</p>';
  content.innerHTML = html + '<div id="ssanalysisTable"></div>';

  const cols = ['item_name','planner_code','make_buy','ss_method','current_ss','avg_daily_demand','ss_days_cover','full_lead_time','ss_assessment','demand_cov_pct'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('ssanalysisTable', displayResult, {
    label: 'SS policy items',
    filename: 'safety_stock_analysis.csv',
    badgeCols: { ss_assessment: true, ss_method: true },
    rowClickFn: openSSAnalysisDrillDown,
    rowColorFn: (row) => {
      const a = (row.ss_assessment || '').toUpperCase();
      if (a === 'NO_POLICY' || a === 'ZERO_SS') return 'scp-row-urgent';
      if (a === 'SS_TOO_LOW') return 'scp-row-warn';
      return '';
    },
  });
}

// 9. Late Supply
function renderLateSupplyTab(result, demoMode) {
  const empty   = document.getElementById('latesupplyEmpty');
  const content = document.getElementById('latesupplyContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoLateSupplyRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const avgLate = rows.reduce((s, r) => s + parseInt(r.days_late || 0), 0) / rows.length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;background:rgba(207,34,46,.05);border-color:rgba(207,34,46,.2);">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> late supplies — avg <strong>${avgLate.toFixed(1)} days</strong> late.
        Customer orders at risk.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for expediting guidance.</p>';
  content.innerHTML = html + '<div id="latesupplyTable"></div>';

  const cols = ['item_name','planner_code','make_buy','supply_type','supply_qty','supply_date','need_date','days_late','demand_qty'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('latesupplyTable', displayResult, {
    label: 'late supplies',
    filename: 'late_supply.csv',
    badgeCols: { supply_type: true },
    rowClickFn: openLateSupplyDrillDown,
    rowColorFn: (row) => parseInt(row.days_late || 0) > 7 ? 'scp-row-urgent' : 'scp-row-warn',
  });
}

// 10. Excess Inventory
function renderExcessTab(result, demoMode) {
  const empty   = document.getElementById('excessEmpty');
  const content = document.getElementById('excessContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoExcessRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const totalVal = rows.reduce((s, r) => s + parseFloat(r.excess_value || 0), 0);
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> items with excess inventory —
        <strong>$${formatNum(totalVal)}</strong> tied-up capital.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for disposition guidance.</p>';
  content.innerHTML = html + '<div id="excessTable"></div>';

  const cols = ['item_name','planner_code','make_buy','on_hand_qty','max_qty','excess_qty','excess_value','full_lead_time'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('excessTable', displayResult, {
    label: 'excess items',
    filename: 'excess_inventory.csv',
    rowClickFn: openExcessDrillDown,
    rowColorFn: (row) => parseFloat(row.excess_value || 0) > 50000 ? 'scp-row-urgent' : 'scp-row-warn',
  });
}

// 11. Pegging Analysis
function renderPeggingTab(result, demoMode) {
  const empty   = document.getElementById('peggingEmpty');
  const content = document.getElementById('peggingContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoPeggingRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const lateCount = rows.filter(r => r.pegging_status === 'LATE').length;
    const tightCount = rows.filter(r => r.pegging_status === 'TIGHT').length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> pegged supply-demand pairs at risk:
        <strong style="color:#cf222e;">${lateCount}</strong> late,
        <strong style="color:#bf8700;">${tightCount}</strong> tight.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for pegging details.</p>';
  content.innerHTML = html + '<div id="peggingTable"></div>';

  const cols = ['item_name','planner_code','supply_type','pegged_qty','supply_date','demand_date','days_gap','pegging_status','demand_source','end_item_name'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('peggingTable', displayResult, {
    label: 'pegging pairs',
    filename: 'pegging_analysis.csv',
    badgeCols: { pegging_status: true, supply_type: true },
    rowClickFn: openPeggingDrillDown,
    rowColorFn: (row) => row.pegging_status === 'LATE' ? 'scp-row-urgent' : row.pegging_status === 'TIGHT' ? 'scp-row-warn' : '',
  });
}

// 12. Spare Parts
function renderSparePartsTab(result, demoMode) {
  const empty   = document.getElementById('sparepartsEmpty');
  const content = document.getElementById('sparepartsContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoSpareRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const stockout = rows.filter(r => r.spare_status === 'STOCKOUT_RISK').length;
    const slow = rows.filter(r => r.spare_status === 'SLOW_MOVING').length;
    const over = rows.filter(r => r.spare_status === 'OVERSTOCKED').length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> spare parts need attention:
        <strong style="color:#cf222e;">${stockout}</strong> stockout risk,
        <strong>${over}</strong> overstocked,
        <strong>${slow}</strong> slow-moving.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for MRO planning guidance.</p>';
  content.innerHTML = html + '<div id="sparepartsTable"></div>';

  const cols = ['item_name','planner_code','on_hand_qty','reorder_point','max_qty','avg_monthly_usage','months_of_supply','inventory_value','spare_status'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('sparepartsTable', displayResult, {
    label: 'spare parts',
    filename: 'spare_parts.csv',
    badgeCols: { spare_status: true },
    rowClickFn: openSparePartsDrillDown,
    rowColorFn: (row) => {
      const s = (row.spare_status || '').toUpperCase();
      if (s === 'STOCKOUT_RISK') return 'scp-row-urgent';
      if (s === 'BELOW_ROP' || s === 'OVERSTOCKED') return 'scp-row-warn';
      return '';
    },
  });
}

// 13. Capacity
function renderCapacityTab(result, demoMode) {
  const empty   = document.getElementById('capacityEmpty');
  const content = document.getElementById('capacityContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoCapacityRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const critCount = rows.filter(r => r.capacity_risk === 'CRITICAL').length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> supplier-item combos above 80% capacity —
        <strong style="color:#cf222e;">${critCount}</strong> critical (&gt;95%).
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for capacity management guidance.</p>';
  content.innerHTML = html + '<div id="capacityTable"></div>';

  const cols = ['supplier_name','item_name','max_capacity','allocated_qty','utilization_pct','capacity_risk','from_date','to_date'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('capacityTable', displayResult, {
    label: 'capacity constraints',
    filename: 'supplier_capacity.csv',
    badgeCols: { capacity_risk: true },
    rowClickFn: openCapacityDrillDown,
    rowColorFn: (row) => row.capacity_risk === 'CRITICAL' ? 'scp-row-urgent' : 'scp-row-warn',
  });
}

// 14. Sourcing Compliance
function renderSourcingTab(result, demoMode) {
  const empty   = document.getElementById('sourcingEmpty');
  const content = document.getElementById('sourcingContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoSourcingRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const highDev = rows.filter(r => r.compliance_status === 'HIGH_DEVIATION').length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> sourcing rules checked —
        <strong style="color:#cf222e;">${highDev}</strong> with high deviation from target.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for sourcing rule details.</p>';
  content.innerHTML = html + '<div id="sourcingTable"></div>';

  const cols = ['item_name','planner_code','preferred_supplier','target_pct','actual_pct','deviation_pct','compliance_status'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('sourcingTable', displayResult, {
    label: 'sourcing rules',
    filename: 'sourcing_compliance.csv',
    badgeCols: { compliance_status: true },
    rowClickFn: openSourcingDrillDown,
    rowColorFn: (row) => row.compliance_status === 'HIGH_DEVIATION' ? 'scp-row-urgent' : row.compliance_status === 'MEDIUM_DEVIATION' ? 'scp-row-warn' : '',
  });
}

// 15. Demand Variability
function renderVariabilityTab(result, demoMode) {
  const empty   = document.getElementById('variabilityEmpty');
  const content = document.getElementById('variabilityContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoVariabilityRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const lumpy = rows.filter(r => r.demand_pattern === 'LUMPY').length;
    const variable = rows.filter(r => r.demand_pattern === 'VARIABLE').length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> items analyzed:
        <strong>${lumpy}</strong> lumpy,
        <strong>${variable}</strong> variable demand.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for variability details.</p>';
  content.innerHTML = html + '<div id="variabilityTable"></div>';

  const cols = ['item_name','planner_code','make_buy','demand_count','avg_demand','stddev_demand','cov_pct','demand_pattern'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('variabilityTable', displayResult, {
    label: 'variable items',
    filename: 'demand_variability.csv',
    badgeCols: { demand_pattern: true },
    rowClickFn: openVariabilityDrillDown,
    rowColorFn: (row) => row.demand_pattern === 'LUMPY' ? 'scp-row-urgent' : row.demand_pattern === 'VARIABLE' ? 'scp-row-warn' : '',
  });
}

// 16. Coverage (Days of Supply)
function renderCoverageTab(result, demoMode) {
  const empty   = document.getElementById('coverageEmpty');
  const content = document.getElementById('coverageContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const rows = demoMode ? buildDemoCoverageRows() : (result && result.rows ? result.rows : []);
  let html = '';
  if (demoMode) html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode</div>`;

  if (rows.length > 0) {
    const critCount = rows.filter(r => r.coverage_band === 'CRITICAL').length;
    const lowCount = rows.filter(r => r.coverage_band === 'LOW').length;
    const excessCount = rows.filter(r => r.coverage_band === 'EXCESS').length;
    html += `<div class="scp-ai-summary" style="margin-bottom:12px;">
      <span style="font-size:13px;color:var(--text-primary);">
        <strong>${rows.length}</strong> items:
        <strong style="color:#cf222e;">${critCount}</strong> critical coverage,
        <strong style="color:#bf8700;">${lowCount}</strong> low,
        <strong>${excessCount}</strong> excess.
      </span>
    </div>`;
  }
  html += '<p style="font-size:12px;color:var(--text-muted);margin-bottom:10px;"><i class="fa-solid fa-hand-pointer fa-xs me-1"></i>Click any row for coverage details.</p>';
  content.innerHTML = html + '<div id="coverageTable"></div>';

  const cols = ['item_name','planner_code','make_buy','on_hand_qty','avg_daily_demand','days_of_supply','full_lead_time','coverage_band'];
  const displayResult = demoMode
    ? { rows, columns: cols, row_count: rows.length }
    : (result || { rows: [], columns: cols, row_count: 0 });

  renderScpTable('coverageTable', displayResult, {
    label: 'coverage items',
    filename: 'item_coverage.csv',
    badgeCols: { coverage_band: true },
    rowClickFn: openCoverageDrillDown,
    rowColorFn: (row) => row.coverage_band === 'CRITICAL' ? 'scp-row-urgent' : row.coverage_band === 'LOW' ? 'scp-row-warn' : '',
  });
}

// 17. AI Tab
function renderScpAITab(kpis, findings, demoMode) {
  const empty   = document.getElementById('aiEmpty');
  const content = document.getElementById('aiContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const freshStr = kpis.plan_freshness_days !== null ? kpis.plan_freshness_days.toFixed(1) + 'd plan age' : 'Plan age unknown';
  const mapeStr  = kpis.forecast_mape !== null ? `${kpis.forecast_mape.toFixed(1)}% MAPE` : 'No MAPE data';

  let summaryText = `<strong>${freshStr}.</strong> `;
  summaryText += `${kpis.demand_supply_gap} supply gaps. `;
  summaryText += `${kpis.exception_count} exceptions. `;
  summaryText += `${mapeStr}. `;
  summaryText += `SS compliance: ${kpis.ss_compliance_pct !== null ? kpis.ss_compliance_pct.toFixed(1) + '%' : 'N/A'}. `;
  summaryText += `${kpis.late_supply_count} late supplies. `;
  summaryText += `Excess: $${formatNum(kpis.excess_value || 0)}. `;
  summaryText += `${kpis.capacity_at_risk} capacity constraints.`;

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
  clearScpChat();
  const msgs = document.getElementById('scpChatMessages');
  if (msgs) {
    const welcome = msgs.querySelector('#scpChatWelcome .scp-chat-bubble');
    if (welcome) {
      const issues = findings && findings.length > 0
        ? findings.filter(f => f.severity === 'CRITICAL' || f.severity === 'HIGH').map(f => f.category).join(', ')
        : null;
      welcome.textContent = issues
        ? `Analysis complete. I see issues with: ${issues}. Ask me how to resolve them.`
        : `Analysis complete. Supply chain planning looks OK. Ask me anything about your SCP data.`;
    }
  }
}

// ── Planning Actions Tab (Close Issues equivalent) ───────────────────────────

function buildPlanningActions(data) {
  const kpis    = data.kpis;
  const queries = data.queries;
  const issues  = [];

  const planRows     = (queries.plan_summary         || {}).rows || [];
  const balanceRows  = (queries.demand_supply_balance || {}).rows || [];
  const lateRows     = (queries.late_supply           || {}).rows || [];
  const peggingRows  = (queries.pegging_analysis      || {}).rows || [];
  const ssRows       = (queries.safety_stock_violations || {}).rows || [];
  const ssaRows      = (queries.safety_stock_analysis || {}).rows || [];
  const spareRows    = (queries.spare_parts           || {}).rows || [];
  const forecastRows = (queries.forecast_accuracy     || {}).rows || [];
  const excessRows   = (queries.excess_inventory      || {}).rows || [];
  const capRows      = (queries.supplier_capacity     || {}).rows || [];

  // 1 — Stale Plan
  if (kpis.plan_freshness_days !== null && kpis.plan_freshness_days > 2) {
    issues.push({
      id: 'stale_plan',
      title: 'Stale Planning Data',
      icon: 'fa-clock',
      severity: 'CRITICAL',
      count: 1,
      description: `Plan last run ${kpis.plan_freshness_days.toFixed(1)} days ago. Supply/demand signals may be outdated.`,
      action: `Plan is ${kpis.plan_freshness_days.toFixed(1)} days old. Re-run the planning engine: navigate to ASCP > Plan > Launch Plan > select active plan > Submit. If plan run is blocked, check ASCP > Plan Output for errors.`,
      rows: planRows,
      columns: ['plan_name','plan_type_name','plan_completion_date','days_since_run','exception_count'],
    });
  }

  // 2 — Item Shortages
  const shortItems = balanceRows.filter(r => r.balance_status === 'SHORT');
  if (shortItems.length > 0) {
    const sev = shortItems.length > 20 ? 'CRITICAL' : shortItems.length > 5 ? 'HIGH' : 'HIGH';
    const itemNames = shortItems.slice(0, 3).map(r => r.item_name).join(', ');
    issues.push({
      id: 'shortages',
      title: 'Item Shortages',
      icon: 'fa-triangle-exclamation',
      severity: sev,
      count: shortItems.length,
      description: `${shortItems.length} items where demand exceeds available supply (${itemNames}${shortItems.length > 3 ? '...' : ''}).`,
      action: `${shortItems.length} shortage items. For BUY items, create requisitions via ASCP > Planner Workbench > Release > Purchase Req. For MAKE items, release planned WOs. Top shortages: ${shortItems.slice(0, 3).map(r => `${r.item_name} (net: ${r.net_position}, planner: ${r.planner_code})`).join('; ')}.`,
      rows: shortItems,
      columns: ['item_name','planner_code','make_buy','total_demand_qty','total_supply_qty','net_position','balance_status'],
      rowClickFn: openItemDrillDown,
    });
  }

  // 3 — Late Supplies
  if (lateRows.length > 0) {
    const avgLate = lateRows.reduce((s, r) => s + parseInt(r.days_late || 0), 0) / lateRows.length;
    issues.push({
      id: 'late_supply',
      title: 'Late Supplies',
      icon: 'fa-truck-clock',
      severity: 'HIGH',
      count: lateRows.length,
      description: `${lateRows.length} supplies arriving after demand date (avg ${avgLate.toFixed(1)} days late).`,
      action: `${lateRows.length} late supplies. Expedite top items: ${lateRows.slice(0, 3).map(r => `${r.item_name} (${r.days_late}d late, ${r.supply_type}, planner: ${r.planner_code})`).join('; ')}. Contact suppliers or find alternate sources via ASCP > Item > Substitutes.`,
      rows: lateRows,
      columns: ['item_name','planner_code','supply_type','supply_qty','supply_date','need_date','days_late'],
      rowClickFn: openLateSupplyDrillDown,
    });
  }

  // 4 — Pegging At Risk
  const latePegs = peggingRows.filter(r => r.pegging_status === 'LATE');
  if (latePegs.length > 0) {
    issues.push({
      id: 'pegging_late',
      title: 'Pegging At Risk',
      icon: 'fa-link-slash',
      severity: 'CRITICAL',
      count: latePegs.length,
      description: `${latePegs.length} pegged supply-demand pairs where supply arrives after demand date.`,
      action: `${latePegs.length} late pegging pairs. Top items: ${latePegs.slice(0, 3).map(r => `${r.item_name} (${r.supply_type}, ${r.days_gap}d gap, demand: ${r.demand_source} ${r.demand_order || ''})`).join('; ')}. Expedite or find alternate source.`,
      rows: latePegs,
      columns: ['item_name','supply_type','pegged_qty','supply_date','demand_date','days_gap','demand_source'],
      rowClickFn: openPeggingDrillDown,
    });
  }

  // 5 — Safety Stock Breaches
  const critSS = ssRows.filter(r => r.violation_severity === 'CRITICAL' || r.violation_severity === 'ZERO_STOCK');
  if (critSS.length > 0) {
    issues.push({
      id: 'ss_breach',
      title: 'Safety Stock Breaches',
      icon: 'fa-shield-halved',
      severity: 'HIGH',
      count: critSS.length,
      description: `${critSS.length} items critically below safety stock.`,
      action: `${critSS.length} critical SS breaches. Items: ${critSS.slice(0, 3).map(r => `${r.item_name} (on-hand: ${r.on_hand_qty}, SS: ${r.safety_stock_qty}, gap: ${r.gap}, LT: ${r.full_lead_time}d)`).join('; ')}. Create replenishment orders immediately.`,
      rows: critSS,
      columns: ['item_name','planner_code','make_buy','on_hand_qty','safety_stock_qty','gap','violation_severity'],
      rowClickFn: openSSViolationDrillDown,
    });
  }

  // 6 — SS Policy Gaps
  const noPolicyItems = ssaRows.filter(r => r.ss_assessment === 'NO_POLICY' || r.ss_assessment === 'ZERO_SS');
  if (noPolicyItems.length > 0) {
    issues.push({
      id: 'ss_policy',
      title: 'SS Policy Gaps',
      icon: 'fa-file-circle-question',
      severity: 'MEDIUM',
      count: noPolicyItems.length,
      description: `${noPolicyItems.length} items have no safety stock policy or zero SS.`,
      action: `${noPolicyItems.length} items without SS policy. Items: ${noPolicyItems.slice(0, 3).map(r => `${r.item_name} (avg daily demand: ${r.avg_daily_demand}, LT: ${r.full_lead_time}d, planner: ${r.planner_code})`).join('; ')}. Set up MRP-planned SS in ASCP > Planning > Safety Stock Rules.`,
      rows: noPolicyItems,
      columns: ['item_name','planner_code','ss_method','avg_daily_demand','full_lead_time','ss_assessment'],
      rowClickFn: openSSAnalysisDrillDown,
    });
  }

  // 7 — Spare Parts Stockout Risk
  const stockoutSpares = spareRows.filter(r => r.spare_status === 'STOCKOUT_RISK');
  if (stockoutSpares.length > 0) {
    issues.push({
      id: 'spare_stockout',
      title: 'Spare Parts Stockout Risk',
      icon: 'fa-wrench',
      severity: 'CRITICAL',
      count: stockoutSpares.length,
      description: `${stockoutSpares.length} spare parts at zero stock with active demand.`,
      action: `${stockoutSpares.length} spare parts at stockout risk. Items: ${stockoutSpares.slice(0, 3).map(r => `${r.item_name} (avg usage: ${r.avg_monthly_usage}/mo, LT: ${r.full_lead_time}d)`).join('; ')}. Create emergency requisitions: PO > Requisitions > New.`,
      rows: stockoutSpares,
      columns: ['item_name','planner_code','on_hand_qty','avg_monthly_usage','full_lead_time','spare_status'],
      rowClickFn: openSparePartsDrillDown,
    });
  }

  // 8 — Forecast Drift
  const highMapeItems = forecastRows.filter(r => parseFloat(r.mape_pct || 0) > 30);
  if (highMapeItems.length > 0) {
    issues.push({
      id: 'forecast_drift',
      title: 'Forecast Drift (>30%)',
      icon: 'fa-chart-line',
      severity: 'MEDIUM',
      count: highMapeItems.length,
      description: `${highMapeItems.length} items with MAPE > 30% — demand planning inaccuracy.`,
      action: `${highMapeItems.length} items with high MAPE. Items: ${highMapeItems.slice(0, 3).map(r => `${r.item_name} (MAPE: ${r.mape_pct}%, forecast: ${r.forecast_qty}, actual: ${r.consumed_qty})`).join('; ')}. Review in Demantra or ASCP > Demand tab and adjust forecast parameters.`,
      rows: highMapeItems,
      columns: ['item_name','planner_code','forecast_qty','consumed_qty','mape_pct','accuracy_band'],
      rowClickFn: openForecastDrillDown,
    });
  }

  // 9 — Excess Capital
  if (excessRows.length > 0) {
    const totalExcess = excessRows.reduce((s, r) => s + parseFloat(r.excess_value || 0), 0);
    issues.push({
      id: 'excess',
      title: 'Excess Capital Tied Up',
      icon: 'fa-warehouse',
      severity: 'MEDIUM',
      count: excessRows.length,
      countLabel: '$' + formatNum(totalExcess),
      description: `$${formatNum(totalExcess)} in excess inventory across ${excessRows.length} items.`,
      action: `$${formatNum(totalExcess)} excess inventory. Top items: ${excessRows.slice(0, 3).map(r => `${r.item_name} (excess: ${r.excess_qty}, value: $${formatNum(r.excess_value)}, planner: ${r.planner_code})`).join('; ')}. Defer or cancel incoming supply via ASCP > Planner Workbench.`,
      rows: excessRows,
      columns: ['item_name','planner_code','on_hand_qty','max_qty','excess_qty','excess_value'],
      rowClickFn: openExcessDrillDown,
    });
  }

  // 10 — Capacity Bottleneck
  const critCap = capRows.filter(r => r.capacity_risk === 'CRITICAL');
  if (critCap.length > 0) {
    issues.push({
      id: 'capacity',
      title: 'Capacity Bottleneck',
      icon: 'fa-gauge-high',
      severity: 'HIGH',
      count: critCap.length,
      description: `${critCap.length} supplier-item combos above 95% capacity utilization.`,
      action: `${critCap.length} critical capacity constraints. Suppliers: ${critCap.slice(0, 3).map(r => `${r.supplier_name} for ${r.item_name} (${r.utilization_pct}% utilized, max: ${r.max_capacity})`).join('; ')}. Shift load to alternate resource, authorize overtime, or subcontract.`,
      rows: critCap,
      columns: ['supplier_name','item_name','max_capacity','allocated_qty','utilization_pct','capacity_risk'],
      rowClickFn: openCapacityDrillDown,
    });
  }

  // 11 — Slow-Moving Spares
  const slowSpares = spareRows.filter(r => r.spare_status === 'SLOW_MOVING');
  if (slowSpares.length > 0) {
    const totalVal = slowSpares.reduce((s, r) => s + parseFloat(r.inventory_value || 0), 0);
    issues.push({
      id: 'slow_spares',
      title: 'Slow-Moving Spares',
      icon: 'fa-hourglass-half',
      severity: 'INFO',
      count: slowSpares.length,
      countLabel: '$' + formatNum(totalVal),
      description: `${slowSpares.length} spare parts with zero usage — $${formatNum(totalVal)} candidate for disposition.`,
      action: `${slowSpares.length} slow-moving spares ($${formatNum(totalVal)}). Items: ${slowSpares.slice(0, 3).map(r => `${r.item_name} (on-hand: ${r.on_hand_qty}, value: $${formatNum(r.inventory_value)})`).join('; ')}. Candidate for disposition or return to supplier.`,
      rows: slowSpares,
      columns: ['item_name','planner_code','on_hand_qty','inventory_value','months_of_history','spare_status'],
      rowClickFn: openSparePartsDrillDown,
    });
  }

  // 12 — Unreleased Planned Orders (past-due)
  const plannedRows = (queries.planned_orders || {}).rows || [];
  const pastDue = plannedRows.filter(r => (r.urgency || '').toUpperCase() === 'PAST_DUE');
  if (pastDue.length > 0) {
    issues.push({
      id: 'past_due_orders',
      title: 'Unreleased Planned Orders (Past-Due)',
      icon: 'fa-calendar-xmark',
      severity: 'HIGH',
      count: pastDue.length,
      description: `${pastDue.length} planned orders past their schedule date and still unreleased.`,
      action: `${pastDue.length} past-due planned orders. Items: ${pastDue.slice(0, 3).map(r => `${r.item_name} (qty: ${r.quantity}, date: ${r.schedule_date}, ${r.order_type_name}, planner: ${r.planner_code})`).join('; ')}. Release immediately via ASCP > Planner Workbench > Release.`,
      rows: pastDue,
      columns: ['item_name','planner_code','make_buy','order_type_name','quantity','schedule_date','days_out','urgency'],
    });
  }

  // All clear
  if (issues.length === 0) {
    issues.push({
      id: 'ok',
      title: 'No Planning Issues Found',
      icon: 'fa-circle-check',
      severity: 'OK',
      count: 0,
      description: 'All supply chain planning metrics look healthy. No shortages, late supplies, or capacity constraints detected.',
      action: '',
      rows: [],
      columns: [],
    });
  }

  return issues;
}

function renderActionsTab(data, demoMode) {
  const empty   = document.getElementById('actionsEmpty');
  const content = document.getElementById('actionsContent');
  empty.classList.add('d-none');
  content.classList.remove('d-none');

  const issues = buildPlanningActions(data);

  // Update tab count badge
  const blockers = issues.filter(i => i.severity !== 'OK').length;
  const cntEl = document.getElementById('cnt-actions');
  if (cntEl) cntEl.textContent = blockers > 0 ? blockers : '\u2713';

  let html = '';
  if (demoMode) {
    html += `<div class="scp-demo-notice"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live data</div>`;
  }

  if (issues[0].severity === 'OK') {
    html += `<div class="close-ok-banner">
      <i class="fa-solid fa-circle-check"></i>
      <div>
        <div style="font-size:15px;font-weight:700;">No Planning Issues Found</div>
        <div style="font-size:13px;font-weight:400;margin-top:2px;">${escHtml(issues[0].description)}</div>
      </div>
    </div>`;
  } else {
    html += `<div class="close-section-hdr"><i class="fa-solid fa-triangle-exclamation fa-xs"></i>${blockers} issue${blockers !== 1 ? 's' : ''} require attention</div>`;
    html += '<div class="close-issue-list" id="actionsIssueList"></div>';
  }

  content.innerHTML = html;

  // Render each issue card with its detail table
  const list = document.getElementById('actionsIssueList');
  if (!list) return;

  issues.forEach((issue, idx) => {
    const cardId  = `actionCard_${idx}`;
    const tableId = `actionTable_${idx}`;
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
               <i class="fa-solid fa-table-list fa-xs"></i>View ${issue.rows.length} Item${issue.rows.length !== 1 ? 's' : ''}
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
          btn.innerHTML = `<i class="fa-solid fa-table-list fa-xs"></i>View ${issue.rows.length} Item${issue.rows.length !== 1 ? 's' : ''}`;
          return;
        }
        tbl.style.display = '';
        btn.innerHTML = `<i class="fa-solid fa-chevron-up fa-xs"></i>Hide`;

        if (tbl.dataset.rendered) return;
        tbl.dataset.rendered = '1';

        renderScpTable(tableId, { rows: issue.rows, columns: issue.columns, row_count: issue.rows.length }, {
          label: issue.title,
          filename: `scp_action_${issue.id}.csv`,
          badgeCols: { balance_status: true, violation_severity: true, capacity_risk: true, pegging_status: true, spare_status: true, accuracy_band: true, ss_assessment: true, urgency: true, exception_name: true, supply_type: true },
          rowClickFn: issue.rowClickFn || null,
        });
      });
    }
  });
}

// ── Drill-down panel ──────────────────────────────────────────────────────────

function _openScpDrillPanel(title) {
  document.getElementById('drillItemName').textContent = title;
  // Reset all drill-down fields to '—'
  ['drillMakeBuy','drillPlanner','drillLeadTime','drillOnHand','drillSafetyStock',
   'drillNetPosition','drillExceptionType','drillQuantity','drillDates'].forEach(id => {
    const el = document.getElementById(id);
    if (el) el.textContent = '—';
  });
  document.getElementById('scpDrillDetailContent').innerHTML =
    '<p style="font-size:12px;color:var(--text-muted);margin:0;">Click "Load Detail" to see additional data.</p>';
  const detailBtn = document.getElementById('scpDrillDetailBtn');
  if (detailBtn) { detailBtn.disabled = false; detailBtn.innerHTML = '<i class="fa-solid fa-list fa-xs me-1"></i>Load Detail'; }
  document.getElementById('drillOverlay').classList.add('open');
  document.getElementById('drillPanel').classList.add('open');
  document.body.style.overflow = 'hidden';
}

function _setScpDrillFields(fields) {
  for (const [id, val] of Object.entries(fields)) {
    const el = document.getElementById(id);
    if (el) {
      if (typeof val === 'object' && val.html) el.innerHTML = val.html;
      else el.textContent = val || '—';
    }
  }
}

// Drill-down: Plan
function openPlanDrillDown(row) {
  scpState.selectedPlanId = row.plan_id || null;
  scpState.selectedItemId = null;
  _openScpDrillPanel(`Plan: ${row.plan_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.plan_type_name || '—',
    drillDates:     `${row.days_since_run || '—'} days since run`,
    drillOnHand:     row.plan_name || '—',
    drillQuantity:      `${row.exception_count || 0} exceptions`,
    drillPlanner:  `${row.org_count || '—'} orgs`,
    drillMakeBuy:  `${row.items_with_exceptions || '—'} items w/ exceptions`,
    drillLeadTime:     row.plan_completion_date || '—',
    drillNetPosition:   `Start: ${row.plan_start_date || '—'} / Cutoff: ${row.cutoff_date || '—'}`,
  });

  const freshness = parseFloat(row.days_since_run || 0);
  const actionText = freshness > 3
    ? `Plan "${row.plan_name || '—'}" is ${row.days_since_run} days old with ${row.exception_count || 0} exceptions across ${row.items_with_exceptions || 0} items. CRITICAL: Re-run immediately via ASCP > Plan > Launch Plan > select "${row.plan_name || '—'}" > Submit. Plan covers ${row.org_count || '—'} orgs, period ${row.plan_start_date || '—'} to ${row.cutoff_date || '—'}.`
    : `Plan "${row.plan_name || '—'}" last run ${row.days_since_run || '—'} days ago. ${row.exception_count || 0} exceptions across ${row.items_with_exceptions || 0} items. Review exceptions in ASCP > Planner Workbench > Exceptions tab. Plan covers ${row.org_count || '—'} orgs.`;
  document.getElementById('drillOwner').innerHTML = '<i class="fa-solid fa-user fa-xs me-1"></i>Planning Manager';
  document.getElementById('drillAction').textContent = actionText;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Exception
function openExceptionDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  const excType = row.exception_name || row.exception_type || '—';
  _openScpDrillPanel(`Exception: ${excType}`);

  _setScpDrillFields({
    drillExceptionType:     excType,
    drillDates:     row.days_delta ? `${row.days_delta} days delta` : '—',
    drillOnHand:     row.item_name || '—',
    drillQuantity:      row.quantity ? `Qty: ${row.quantity}` : '—',
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.make_buy || '—',
    drillLeadTime:     row.exception_date || '—',
    drillNetPosition:   row.suggested_date ? `Suggested: ${row.suggested_date}` : '—',
  });

  const action = getExceptionAction(excType, row);
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent = action.action;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Exception Type (aggregated)
function openExceptionTypeDrillDown(row) {
  scpState.selectedItemId = null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Type: ${row.exception_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.exception_name || '—',
    drillDates:     `${row.exception_count || '—'} exceptions`,
    drillOnHand:     `${row.distinct_items || '—'} items affected`,
    drillQuantity:      `Total qty: ${row.total_quantity || '—'}`,
    drillPlanner:  row.planners || '—',
    drillMakeBuy:  '—',
    drillLeadTime:     '—',
    drillNetPosition:   '—',
  });

  const action = getExceptionAction(row.exception_name, {});
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent = `${row.exception_count || '—'} "${row.exception_name || '—'}" exceptions affecting ${row.distinct_items || '—'} items (total qty: ${row.total_quantity || '—'}). Planners: ${row.planners || '—'}. Owner: ${action.owner}. Resolve by addressing each exception — click individual rows in the Exceptions tab for specific guidance.`;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = 'none';
}

// Drill-down: Item (balance)
function openItemDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Item: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.balance_status || '—',
    drillDates:     `Demand: ${row.total_demand_qty || '—'} / Supply: ${row.total_supply_qty || '—'}`,
    drillOnHand:     row.total_supply_qty != null ? String(row.total_supply_qty) : '—',
    drillSafetyStock: row.safety_stock != null ? String(row.safety_stock) : '—',
    drillQuantity:      `Demand: ${row.total_demand_qty || '—'}`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.make_buy || '—',
    drillLeadTime:     '—',
    drillNetPosition:   row.net_position != null ? String(row.net_position) : '—',
  });

  const isBuy = (row.make_buy || '').toUpperCase() === 'BUY';
  const isShort = row.balance_status === 'SHORT';
  const actionText = isShort
    ? `${row.item_name || '—'} (${row.make_buy || '—'}, planner: ${row.planner_code || '—'}): demand ${row.total_demand_qty || '—'} exceeds supply ${row.total_supply_qty || '—'} (net: ${row.net_position || '—'}, SS: ${row.safety_stock || '—'}). ${isBuy ? 'Create purchase requisition via ASCP > Planner Workbench > Release > Purchase Req.' : 'Release planned work order via ASCP > Planner Workbench > Release > Discrete Job.'} Expedite if lead time allows.`
    : `${row.item_name || '—'} (${row.make_buy || '—'}, planner: ${row.planner_code || '—'}): supply ${row.total_supply_qty || '—'} covers demand ${row.total_demand_qty || '—'} but net position ${row.net_position || '—'} is below safety stock ${row.safety_stock || '—'}. Monitor closely and consider increasing supply buffer.`;
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${isBuy ? 'Buyer' : 'Production Planner'}`;
  document.getElementById('drillAction').textContent = actionText;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Forecast
function openForecastDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Forecast: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.accuracy_band || '—',
    drillDates:     `MAPE: ${row.mape_pct || '—'}%`,
    drillOnHand:     row.item_name || '—',
    drillQuantity:      `Forecast: ${row.forecast_qty || '—'} / Consumed: ${row.consumed_qty || '—'}`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.forecast_designator || '—',
    drillLeadTime:     '—',
    drillNetPosition:   '—',
  });

  const mape = parseFloat(row.mape_pct || 0);
  const actionText = mape > 30
    ? `${row.item_name || '—'} (planner: ${row.planner_code || '—'}): forecast MAPE ${row.mape_pct || '—'}% (${row.accuracy_band || '—'}). Forecast: ${row.forecast_qty || '—'}, Consumed: ${row.consumed_qty || '—'}. CRITICAL deviation — review demand sensing signals in Demantra or ASCP > Demand tab. Check for one-time events, seasonality changes, or lost customers affecting this item.`
    : `${row.item_name || '—'} (planner: ${row.planner_code || '—'}): forecast MAPE ${row.mape_pct || '—'}% (${row.accuracy_band || '—'}). Forecast: ${row.forecast_qty || '—'}, Consumed: ${row.consumed_qty || '—'}. Review forecast parameters in ASCP > Demand tab for tuning opportunities.`;
  document.getElementById('drillOwner').innerHTML = '<i class="fa-solid fa-user fa-xs me-1"></i>Demand Planner';
  document.getElementById('drillAction').textContent = actionText;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Safety Stock Violation
function openSSViolationDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`SS Violation: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.violation_severity || '—',
    drillDates:     `Gap: ${row.gap || '—'} units`,
    drillOnHand:     row.on_hand_qty != null ? String(row.on_hand_qty) : '—',
    drillSafetyStock: row.safety_stock_qty != null ? String(row.safety_stock_qty) : '—',
    drillQuantity:      `Gap: ${row.gap || '—'} units`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.make_buy || '—',
    drillLeadTime:     row.full_lead_time ? `${row.full_lead_time} days` : '—',
    drillNetPosition:   row.gap != null ? String(row.gap) : '—',
  });

  const action = getExceptionAction('BELOW SAFETY STOCK', row);
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent = action.action;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: SS Analysis
function openSSAnalysisDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`SS Policy: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.ss_assessment || '—',
    drillDates:     row.ss_days_cover ? `${row.ss_days_cover} days cover` : '—',
    drillOnHand:     row.on_hand_qty != null ? String(row.on_hand_qty) : '—',
    drillSafetyStock: row.current_ss != null ? String(row.current_ss) : '—',
    drillQuantity:      `Avg daily demand: ${row.avg_daily_demand || '—'}`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.make_buy || '—',
    drillLeadTime:     row.full_lead_time ? `${row.full_lead_time} days` : '—',
    drillNetPosition:   `Method: ${row.ss_method || '—'} / Demand CoV: ${row.demand_cov_pct || '—'}%`,
  });

  const assessment = (row.ss_assessment || '').toUpperCase();
  const action = getExceptionAction(assessment, row);
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent = action.action;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Late Supply
function openLateSupplyDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Late Supply: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.supply_type || '—',
    drillDates:     `${row.days_late || '—'} days late`,
    drillOnHand:     row.item_name || '—',
    drillQuantity:      `Supply: ${row.supply_qty || '—'} / Demand: ${row.demand_qty || '—'}`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.make_buy || '—',
    drillLeadTime:     `Supply: ${row.supply_date || '—'} / Need: ${row.need_date || '—'}`,
    drillNetPosition:   '—',
  });

  const action = getExceptionAction('LATE SUPPLY', row);
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent = action.action;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Excess
function openExcessDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Excess: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     'EXCESS',
    drillDates:     `$${formatNum(row.excess_value || 0)} tied up`,
    drillOnHand:     row.item_name || '—',
    drillQuantity:      `On-hand: ${row.on_hand_qty || '—'} / Max: ${row.max_qty || '—'} / Excess: ${row.excess_qty || '—'}`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.make_buy || '—',
    drillLeadTime:     `Lead time: ${row.full_lead_time || '—'} days`,
    drillNetPosition:   '—',
  });

  const action = getExceptionAction('EXCESS', row);
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent = `${row.item_name || '—'} (planner: ${row.planner_code || '—'}, ${row.make_buy || '—'}): on-hand ${row.on_hand_qty || '—'} exceeds max ${row.max_qty || '—'} by ${row.excess_qty || '—'} units ($${formatNum(row.excess_value || 0)}). Defer or cancel incoming supply via ASCP > Planner Workbench > ${row.item_name || '—'} > Supply tab. Consider transferring excess to other locations or negotiating returns with supplier. Lead time: ${row.full_lead_time || '—'} days.`;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Pegging
function openPeggingDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Pegging: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.pegging_status || '—',
    drillDates:     row.days_gap ? `${row.days_gap} days gap` : '—',
    drillOnHand:     row.item_name || '—',
    drillQuantity:      `Pegged qty: ${row.pegged_qty || '—'}`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.make_buy || row.supply_type || '—',
    drillLeadTime:     `Supply: ${row.supply_date || '—'} / Demand: ${row.demand_date || '—'}`,
    drillNetPosition:   `Demand: ${row.demand_source || '—'} ${row.demand_order || ''} / End item: ${row.end_item_name || '—'}`,
  });

  const action = getExceptionAction('PEGGING_LATE', row);
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent = action.action;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Spare Parts
function openSparePartsDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Spare: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.spare_status || '—',
    drillDates:     row.months_of_supply ? `${row.months_of_supply} months supply` : '—',
    drillOnHand:     row.item_name || '—',
    drillQuantity:      `On-hand: ${row.on_hand_qty || '—'} / ROP: ${row.reorder_point || '—'} / Max: ${row.max_qty || '—'}`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  'BUY',
    drillLeadTime:     `Lead time: ${row.full_lead_time || '—'} days`,
    drillNetPosition:   `Avg usage: ${row.avg_monthly_usage || '—'}/mo / Value: $${formatNum(row.inventory_value || 0)}`,
  });

  const status = (row.spare_status || '').toUpperCase();
  let actionKey = status.includes('STOCKOUT') ? 'SPARE_STOCKOUT' : status.includes('OVER') ? 'SPARE_OVERSTOCKED' : status.includes('SLOW') ? 'SPARE_SLOW_MOVING' : 'SPARE_STOCKOUT';
  const action = getExceptionAction(actionKey, row);
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent = action.action;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Capacity
function openCapacityDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Capacity: ${row.supplier_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.capacity_risk || '—',
    drillDates:     `${row.utilization_pct || '—'}% utilized`,
    drillOnHand:     row.item_name || '—',
    drillQuantity:      `Allocated: ${row.allocated_qty || '—'} / Max: ${row.max_capacity || '—'}`,
    drillPlanner:  row.supplier_name || '—',
    drillMakeBuy:  'BUY',
    drillLeadTime:     `Period: ${row.from_date || '—'} to ${row.to_date || '—'}`,
    drillNetPosition:   '—',
  });

  const action = getExceptionAction('CAPACITY OVERLOAD', row);
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent = action.action;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Sourcing
function openSourcingDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Sourcing: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.compliance_status || '—',
    drillDates:     `Deviation: ${row.deviation_pct || '—'}%`,
    drillOnHand:     row.item_name || '—',
    drillQuantity:      `Target: ${row.target_pct || '—'}% / Actual: ${row.actual_pct || '—'}%`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.preferred_supplier || '—',
    drillLeadTime:     '—',
    drillNetPosition:   '—',
  });

  const action = getExceptionAction('SOURCING DEVIATION', row);
  document.getElementById('drillOwner').innerHTML = `<i class="fa-solid fa-user fa-xs me-1"></i>${escHtml(action.owner)}`;
  document.getElementById('drillAction').textContent = action.action;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Variability
function openVariabilityDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Variability: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.demand_pattern || '—',
    drillDates:     `CoV: ${row.cov_pct || '—'}%`,
    drillOnHand:     row.item_name || '—',
    drillQuantity:      `Avg demand: ${row.avg_demand || '—'} / StdDev: ${row.stddev_demand || '—'}`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.make_buy || '—',
    drillLeadTime:     `${row.demand_count || '—'} demand records`,
    drillNetPosition:   '—',
  });

  const cov = parseFloat(row.cov_pct || 0);
  const actionText = cov > 100
    ? `${row.item_name || '—'} (planner: ${row.planner_code || '—'}, ${row.make_buy || '—'}): LUMPY demand pattern (CoV: ${row.cov_pct || '—'}%, avg: ${row.avg_demand || '—'}, stddev: ${row.stddev_demand || '—'}, ${row.demand_count || '—'} orders). Standard MRP planning is unreliable for lumpy items. Consider switching to safety time instead of safety stock, or use ASCP intermittent demand planning. Increase SS buffer significantly.`
    : `${row.item_name || '—'} (planner: ${row.planner_code || '—'}, ${row.make_buy || '—'}): ${row.demand_pattern || '—'} demand (CoV: ${row.cov_pct || '—'}%, avg: ${row.avg_demand || '—'}, stddev: ${row.stddev_demand || '—'}, ${row.demand_count || '—'} orders). Review safety stock levels — current SS may not adequately buffer this variability.`;
  document.getElementById('drillOwner').innerHTML = '<i class="fa-solid fa-user fa-xs me-1"></i>Planner';
  document.getElementById('drillAction').textContent = actionText;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

// Drill-down: Coverage
function openCoverageDrillDown(row) {
  scpState.selectedItemId = row.inventory_item_id || null;
  scpState.selectedItem = row;
  _openScpDrillPanel(`Coverage: ${row.item_name || '—'}`);

  _setScpDrillFields({
    drillExceptionType:     row.coverage_band || '—',
    drillDates:     `${row.days_of_supply || '—'} days of supply`,
    drillOnHand:     row.on_hand_qty != null ? String(row.on_hand_qty) : '—',
    drillSafetyStock: '—',
    drillQuantity:      `Daily demand: ${row.avg_daily_demand || '—'}`,
    drillPlanner:  row.planner_code || '—',
    drillMakeBuy:  row.make_buy || '—',
    drillLeadTime:     row.full_lead_time ? `${row.full_lead_time} days` : '—',
    drillNetPosition:   row.days_of_supply != null ? `${row.days_of_supply} DoS` : '—',
  });

  const dos = parseFloat(row.days_of_supply || 0);
  const lt  = parseFloat(row.full_lead_time || 0);
  const band = (row.coverage_band || '').toUpperCase();
  const actionText = band === 'CRITICAL'
    ? `${row.item_name || '—'} (planner: ${row.planner_code || '—'}, ${row.make_buy || '—'}): only ${row.days_of_supply || '—'} days of supply vs ${row.full_lead_time || '—'} day lead time. On-hand: ${row.on_hand_qty || '—'}, daily demand: ${row.avg_daily_demand || '—'}. CRITICAL — will stockout before replenishment arrives. ${(row.make_buy || '').toUpperCase() === 'BUY' ? 'Create emergency PO or expedite existing orders.' : 'Expedite WO or increase production priority.'}`
    : band === 'EXCESS'
    ? `${row.item_name || '—'} (planner: ${row.planner_code || '—'}, ${row.make_buy || '—'}): ${row.days_of_supply || '—'} days of supply vs ${row.full_lead_time || '—'} day lead time. Excess coverage — consider deferring incoming supply to free working capital.`
    : `${row.item_name || '—'} (planner: ${row.planner_code || '—'}, ${row.make_buy || '—'}): ${row.days_of_supply || '—'} days of supply vs ${row.full_lead_time || '—'} day lead time. On-hand: ${row.on_hand_qty || '—'}, daily demand: ${row.avg_daily_demand || '—'}. Monitor closely and ensure replenishment orders are on track.`;
  document.getElementById('drillOwner').innerHTML = '<i class="fa-solid fa-user fa-xs me-1"></i>Planner';
  document.getElementById('drillAction').textContent = actionText;

  document.getElementById('drillActionSection').style.display = '';
  document.getElementById('scpDrillDetailSection').style.display = '';
}

function closeScpDrillDown() {
  scpState.selectedItem = null;
  scpState.selectedItemId = null;
  scpState.selectedPlanId = null;
  document.getElementById('drillOverlay').classList.remove('open');
  document.getElementById('drillPanel').classList.remove('open');
  document.body.style.overflow = '';
}

// ── Lazy-load detail functions ───────────────────────────────────────────────

async function loadItemDetail() {
  const itemId = scpState.selectedItemId;
  if (!itemId) return;

  const btn     = document.getElementById('scpDrillDetailBtn');
  const content = document.getElementById('scpDrillDetailContent');
  btn.disabled = true;
  btn.innerHTML = '<span class="spinner-border spinner-border-sm" style="width:12px;height:12px;border-width:2px;"></span> Loading\u2026';
  content.innerHTML = '';

  try {
    const resp = await fetch(`/api/scp/item_detail/${itemId}`);
    const data = await resp.json();

    if (data.error) {
      content.innerHTML = `<p style="font-size:12px;color:#cf222e;">${escHtml(data.error)}</p>`;
      btn.innerHTML = '<i class="fa-solid fa-rotate-right fa-xs me-1"></i>Retry';
      btn.disabled = false;
      return;
    }

    let html = '';

    // Demand timeline
    const demandRows = (data.demands || {}).rows || [];
    if (demandRows.length > 0) {
      html += '<div style="font-size:11px;font-weight:600;color:var(--text-muted);text-transform:uppercase;letter-spacing:.06em;margin-bottom:6px;">Demand Timeline</div>';
      html += '<div style="overflow-x:auto"><table class="drill-lines-table"><thead><tr>';
      const dCols = ['demand_date','demand_type','quantity','order_number'];
      const dHdrs = { demand_date: 'Date', demand_type: 'Type', quantity: 'Qty', order_number: 'Order' };
      dCols.forEach(c => { html += `<th>${dHdrs[c] || c}</th>`; });
      html += '</tr></thead><tbody>';
      demandRows.forEach(row => {
        html += '<tr>';
        dCols.forEach(c => { html += `<td>${escHtml(String(row[c] ?? '—'))}</td>`; });
        html += '</tr>';
      });
      html += '</tbody></table></div>';
    }

    // Supply timeline
    const supplyRows = (data.supplies || {}).rows || [];
    if (supplyRows.length > 0) {
      html += '<div style="font-size:11px;font-weight:600;color:var(--text-muted);text-transform:uppercase;letter-spacing:.06em;margin:12px 0 6px;">Supply Timeline</div>';
      html += '<div style="overflow-x:auto"><table class="drill-lines-table"><thead><tr>';
      const sCols = ['schedule_date','supply_type','quantity','order_number','firm_status'];
      const sHdrs = { schedule_date: 'Date', supply_type: 'Type', quantity: 'Qty', order_number: 'Order', firm_status: 'Firm' };
      sCols.forEach(c => { html += `<th>${sHdrs[c] || c}</th>`; });
      html += '</tr></thead><tbody>';
      supplyRows.forEach(row => {
        html += '<tr>';
        sCols.forEach(c => { html += `<td>${escHtml(String(row[c] ?? '—'))}</td>`; });
        html += '</tr>';
      });
      html += '</tbody></table></div>';
    }

    if (!html) html = '<p style="font-size:12px;color:var(--text-muted);margin:0;">No supply/demand detail found for this item.</p>';
    if (data.demo_mode) html += '<p style="font-size:11px;color:var(--text-muted);margin-top:6px;"><i class="fa-solid fa-flask fa-xs me-1"></i>Demo data</p>';
    content.innerHTML = html;
    btn.innerHTML = '<i class="fa-solid fa-check fa-xs me-1"></i>Loaded';
    btn.disabled = true;
  } catch (err) {
    content.innerHTML = `<p style="font-size:12px;color:#cf222e;">Error: ${escHtml(err.message)}</p>`;
    btn.innerHTML = '<i class="fa-solid fa-rotate-right fa-xs me-1"></i>Retry';
    btn.disabled = false;
  }
}

async function loadPlanExceptions() {
  const planId = scpState.selectedPlanId;
  if (!planId) {
    // Fall back to item detail if no plan
    loadItemDetail();
    return;
  }

  const btn     = document.getElementById('scpDrillDetailBtn');
  const content = document.getElementById('scpDrillDetailContent');
  btn.disabled = true;
  btn.innerHTML = '<span class="spinner-border spinner-border-sm" style="width:12px;height:12px;border-width:2px;"></span> Loading\u2026';
  content.innerHTML = '';

  try {
    const resp = await fetch(`/api/scp/plan_exceptions/${planId}`);
    const data = await resp.json();

    if (data.error) {
      content.innerHTML = `<p style="font-size:12px;color:#cf222e;">${escHtml(data.error)}</p>`;
      btn.innerHTML = '<i class="fa-solid fa-rotate-right fa-xs me-1"></i>Retry';
      btn.disabled = false;
      return;
    }

    const rows = data.rows || [];
    if (rows.length === 0) {
      content.innerHTML = '<p style="font-size:12px;color:var(--text-muted);margin:0;">No exceptions found for this plan.</p>';
    } else {
      let html = '<div style="overflow-x:auto"><table class="drill-lines-table"><thead><tr>';
      const cols = ['exception_name','item_name','quantity','exception_date','suggested_date'];
      const hdrs = { exception_name: 'Type', item_name: 'Item', quantity: 'Qty', exception_date: 'Date', suggested_date: 'Suggested' };
      cols.forEach(c => { html += `<th>${hdrs[c] || c}</th>`; });
      html += '</tr></thead><tbody>';
      rows.forEach(row => {
        html += '<tr>';
        cols.forEach(c => { html += `<td>${escHtml(String(row[c] ?? '—'))}</td>`; });
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

// ── Tab switcher ──────────────────────────────────────────────────────────────

function switchScpTab(tabId) {
  scpState.activeTab = tabId;

  document.querySelectorAll('.scp-tab').forEach(btn => btn.classList.remove('active'));
  document.querySelectorAll('.scp-pane').forEach(pane => pane.classList.remove('active'));

  const tabBtn  = document.getElementById('tab-' + tabId);
  const tabPane = document.getElementById('pane-' + tabId);
  if (tabBtn)  tabBtn.classList.add('active');
  if (tabPane) tabPane.classList.add('active');

  // Persist active tab
  try {
    const raw = sessionStorage.getItem(SCP_STORAGE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      parsed.activeTab = tabId;
      sessionStorage.setItem(SCP_STORAGE_KEY, JSON.stringify(parsed));
    }
  } catch (_) {}
}

// ── CSV export ────────────────────────────────────────────────────────────────

function exportScpCSV(rows, columns, filename) {
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
  const data = scpState.data;
  if (!data) return;

  const k = data.kpis;
  let msg = `I need help analyzing Oracle EBS Supply Chain Planning. Here is the current SCP data (last ${scpState.daysBack} days):\n\n`;
  msg += `Plan Freshness: ${k.plan_freshness_days !== null ? k.plan_freshness_days.toFixed(1) + ' days' : 'N/A'}\n`;
  msg += `Supply Gaps: ${k.demand_supply_gap}\n`;
  msg += `Exceptions: ${k.exception_count}\n`;
  msg += `Forecast MAPE: ${k.forecast_mape !== null ? k.forecast_mape.toFixed(1) + '%' : 'N/A'}\n`;
  msg += `SS Compliance: ${k.ss_compliance_pct !== null ? k.ss_compliance_pct.toFixed(1) + '%' : 'N/A'}\n`;
  msg += `Avg Days of Supply: ${k.avg_days_of_supply !== null ? k.avg_days_of_supply.toFixed(1) : 'N/A'}\n`;
  msg += `Late Supplies: ${k.late_supply_count}\n`;
  msg += `Excess Value: $${formatNum(k.excess_value || 0)}\n`;
  msg += `Capacity At Risk: ${k.capacity_at_risk}\n\n`;

  if (data.findings && data.findings.length > 0) {
    msg += 'Key findings:\n';
    data.findings.forEach(f => { msg += `- [${f.severity}] ${f.description}\n`; });
    msg += '\n';
  }

  msg += 'Please provide recommendations to resolve supply shortages, late supplies, forecast accuracy issues, and safety stock gaps.';

  window.location.href = '/?chat=' + encodeURIComponent(msg);
}

// ── Inline page chat ──────────────────────────────────────────────────────────

let scpChatHistory  = [];
let scpChatStreaming = false;

function buildScpChatContext() {
  const data = scpState.data;
  if (!data) return '';
  const k = data.kpis;
  let ctx = `Oracle EBS SCP context (last ${scpState.daysBack} days):\n`;
  ctx += `Plan Age: ${k.plan_freshness_days !== null ? k.plan_freshness_days.toFixed(1) + 'd' : 'N/A'} | `;
  ctx += `Gaps: ${k.demand_supply_gap} | Exceptions: ${k.exception_count} | `;
  ctx += `MAPE: ${k.forecast_mape !== null ? k.forecast_mape.toFixed(1) + '%' : 'N/A'} | `;
  ctx += `SS Compliance: ${k.ss_compliance_pct !== null ? k.ss_compliance_pct.toFixed(1) + '%' : 'N/A'} | `;
  ctx += `Late: ${k.late_supply_count} | Excess: $${formatNum(k.excess_value || 0)}\n`;
  if (data.findings && data.findings.length > 0) {
    ctx += 'Findings: ' + data.findings.map(f => `[${f.severity}] ${f.description}`).join('; ');
  }
  return ctx;
}

function addScpChatMsg(role, text, streaming) {
  const msgs = document.getElementById('scpChatMessages');
  if (!msgs) return null;

  const div = document.createElement('div');
  div.className = `scp-chat-msg scp-chat-msg-${role === 'user' ? 'user' : 'ai'}`;

  const avatar = document.createElement('div');
  avatar.className = 'scp-chat-avatar';
  avatar.innerHTML = role === 'user'
    ? '<i class="fa-solid fa-user fa-xs"></i>'
    : '<i class="fa-solid fa-robot fa-xs"></i>';

  const bubble = document.createElement('div');
  bubble.className = 'scp-chat-bubble' + (streaming ? ' streaming' : '');
  bubble.innerHTML = text ? (typeof marked !== 'undefined' ? marked.parse(text) : escHtml(text)) : '';

  div.appendChild(avatar);
  div.appendChild(bubble);
  msgs.appendChild(div);
  msgs.scrollTop = msgs.scrollHeight;
  return bubble;
}

async function sendScpChat() {
  if (scpChatStreaming) return;

  const input = document.getElementById('scpChatInput');
  const sendBtn = document.getElementById('scpChatSendBtn');
  const userText = (input.value || '').trim();
  if (!userText) return;

  // On first message, inject SCP context
  let messages = [];
  if (scpChatHistory.length === 0) {
    const ctx = buildScpChatContext();
    if (ctx) {
      messages.push({ role: 'user', content: ctx + '\n\nPlease confirm you have this SCP context.' });
      messages.push({ role: 'assistant', content: 'Understood. I have your Supply Chain Planning data context. Ask me anything about exceptions, shortages, forecast accuracy, safety stock, or recommendations.' });
    }
  }
  scpChatHistory.forEach(h => messages.push(h));
  messages.push({ role: 'user', content: userText });

  // Render user msg
  const welcome = document.getElementById('scpChatWelcome');
  if (welcome) welcome.remove();
  addScpChatMsg('user', escHtml(userText));
  input.value = '';

  // Disable input while streaming
  scpChatStreaming = true;
  input.disabled = true;
  sendBtn.disabled = true;

  // Add streaming AI bubble
  const aiBubble = addScpChatMsg('assistant', '', true);

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
              aiBubble.closest('.scp-chat-messages') && (aiBubble.closest('.scp-chat-messages').scrollTop = aiBubble.closest('.scp-chat-messages').scrollHeight);
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
  scpChatHistory.push({ role: 'user', content: userText });
  scpChatHistory.push({ role: 'assistant', content: fullText });
  saveScpChatHistory();

  scpChatStreaming = false;
  input.disabled  = false;
  sendBtn.disabled = false;
  input.focus();
}

function clearScpChat() {
  scpChatHistory = [];
  const msgs = document.getElementById('scpChatMessages');
  if (!msgs) return;
  msgs.innerHTML = `
    <div class="scp-chat-msg scp-chat-msg-ai" id="scpChatWelcome">
      <div class="scp-chat-avatar"><i class="fa-solid fa-robot fa-xs"></i></div>
      <div class="scp-chat-bubble">Ask me anything about your supply chain planning analysis.</div>
    </div>`;
}

// ── Error helper ──────────────────────────────────────────────────────────────

function showScpGlobalError(msg) {
  const pane = document.getElementById('pane-' + scpState.activeTab);
  if (!pane) return;
  const empty = pane.querySelector('[id$="Empty"]');
  if (empty) {
    empty.classList.remove('d-none');
    empty.innerHTML = `<div class="scp-state-box">
      <div class="scp-state-icon"><i class="fa-solid fa-triangle-exclamation" style="color:#cf222e"></i></div>
      <div class="scp-state-title">Analysis failed</div>
      <div class="scp-state-sub">${escHtml(msg)}</div>
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

// ── Demo data constants ──────────────────────────────────────────────────────

const DEMO_ITEMS = [
  { id: 10001, name: 'Bearing Assembly BA-2040', planner: 'JSMITH', make_buy: 'BUY', lead_time: 14 },
  { id: 10002, name: 'PCB Board PCB-X100',       planner: 'MLEE',   make_buy: 'BUY', lead_time: 21 },
  { id: 10003, name: 'Motor Housing MH-500',     planner: 'RPATEL', make_buy: 'MAKE', lead_time: 7 },
  { id: 10004, name: 'Hydraulic Pump HP-300',    planner: 'JSMITH', make_buy: 'MAKE', lead_time: 10 },
  { id: 10005, name: 'Control Valve CV-200',     planner: 'MLEE',   make_buy: 'BUY', lead_time: 28 },
  { id: 10006, name: 'Gear Box GB-150',          planner: 'RPATEL', make_buy: 'MAKE', lead_time: 12 },
  { id: 10007, name: 'Sensor Module SM-400',     planner: 'JSMITH', make_buy: 'BUY', lead_time: 35 },
  { id: 10008, name: 'Steel Plate SP-1000',      planner: 'MLEE',   make_buy: 'BUY', lead_time: 18 },
];

const DEMO_SUPPLIERS = [
  'Precision Parts Inc', 'TechComp Ltd', 'GlobalSupply Co',
  'FastTrack Components', 'QualityFirst Mfg'
];

// ── Demo data builders ────────────────────────────────────────────────────────

function buildDemoPlanRows() {
  const now = new Date();
  return [
    { plan_id: 101, plan_name: 'MRP-DAILY', plan_type_name: 'MRP', plan_completion_date: new Date(now.getTime() - 0.8 * 86400000).toISOString().slice(0, 10), plan_start_date: '2025-01-01', cutoff_date: '2025-06-30', days_since_run: 0.8, exception_count: 87, items_with_exceptions: 42, org_count: 3, total_plans: 3 },
    { plan_id: 102, plan_name: 'MPS-WEEKLY', plan_type_name: 'MPS', plan_completion_date: new Date(now.getTime() - 3.2 * 86400000).toISOString().slice(0, 10), plan_start_date: '2025-01-01', cutoff_date: '2025-12-31', days_since_run: 3.2, exception_count: 24, items_with_exceptions: 15, org_count: 3, total_plans: 3 },
    { plan_id: 103, plan_name: 'DRP-REGIONAL', plan_type_name: 'DRP', plan_completion_date: new Date(now.getTime() - 1.5 * 86400000).toISOString().slice(0, 10), plan_start_date: '2025-01-01', cutoff_date: '2025-09-30', days_since_run: 1.5, exception_count: 12, items_with_exceptions: 8, org_count: 5, total_plans: 3 },
  ];
}

function buildDemoExceptionRows() {
  const types = [
    { name: 'Shortage', type: 1 },
    { name: 'Excess', type: 2 },
    { name: 'Reschedule In', type: 3 },
    { name: 'Reschedule Out', type: 4 },
    { name: 'Late Supply', type: 5 },
    { name: 'Shortage', type: 1 },
    { name: 'Excess', type: 2 },
    { name: 'Shortage', type: 1 },
    { name: 'Reschedule In', type: 3 },
    { name: 'Late Supply', type: 5 },
    { name: 'Shortage', type: 1 },
    { name: 'Excess', type: 2 },
  ];
  const now = new Date();
  return types.map((t, i) => {
    const item = DEMO_ITEMS[i % DEMO_ITEMS.length];
    const excDate = new Date(now.getTime() + (i * 3 + 5) * 86400000);
    const sugDate = new Date(excDate.getTime() + (t.type <= 2 ? 0 : (Math.random() > 0.5 ? -5 : 7)) * 86400000);
    return {
      exception_type: t.type,
      exception_name: t.name,
      inventory_item_id: item.id,
      item_name: item.name,
      planner_code: item.planner,
      make_buy: item.make_buy,
      quantity: Math.floor(Math.random() * 500 + 50),
      exception_date: excDate.toISOString().slice(0, 10),
      suggested_date: sugDate.toISOString().slice(0, 10),
      days_delta: Math.floor((sugDate - excDate) / 86400000),
      total_exceptions: 87,
      count_by_type: types.filter(x => x.type === t.type).length,
    };
  });
}

function buildDemoBalanceRows() {
  return DEMO_ITEMS.slice(0, 6).map((item, i) => {
    const demand = Math.floor(Math.random() * 1000 + 200);
    const supply = Math.floor(demand * (0.5 + Math.random() * 0.4));
    const ss = Math.floor(Math.random() * 200 + 50);
    const net = supply - demand;
    return {
      inventory_item_id: item.id,
      item_name: item.name,
      planner_code: item.planner,
      make_buy: item.make_buy,
      total_demand_qty: demand,
      total_supply_qty: supply,
      net_position: net,
      safety_stock: ss,
      balance_status: net < 0 ? 'SHORT' : net < ss ? 'BELOW_SS' : 'OK',
      total_items: 6,
    };
  });
}

function buildDemoForecastRows() {
  const bands = ['OVER_FORECAST', 'UNDER_FORECAST', 'ON_TRACK', 'OVER_FORECAST', 'UNDER_FORECAST', 'UNDER_FORECAST', 'ON_TRACK', 'OVER_FORECAST'];
  return DEMO_ITEMS.map((item, i) => {
    const forecast = Math.floor(Math.random() * 800 + 100);
    const mape = bands[i] === 'ON_TRACK' ? Math.floor(Math.random() * 12 + 2) : Math.floor(Math.random() * 30 + 15);
    const consumed = bands[i] === 'OVER_FORECAST' ? Math.floor(forecast * (1 + mape / 100)) : bands[i] === 'UNDER_FORECAST' ? Math.floor(forecast * (1 - mape / 100)) : Math.floor(forecast * (1 + (Math.random() * 0.1 - 0.05)));
    return {
      forecast_designator: 'FC-2025-Q2',
      inventory_item_id: item.id,
      item_name: item.name,
      planner_code: item.planner,
      forecast_qty: forecast,
      consumed_qty: consumed,
      mape_pct: mape,
      accuracy_band: bands[i],
      total_items: 8,
    };
  });
}

function buildDemoSSViolationRows() {
  const severities = ['ZERO_STOCK', 'CRITICAL', 'BELOW_SS', 'CRITICAL', 'BELOW_SS', 'BELOW_SS'];
  return DEMO_ITEMS.slice(0, 6).map((item, i) => {
    const ss = Math.floor(Math.random() * 200 + 50);
    const oh = severities[i] === 'ZERO_STOCK' ? 0 : Math.floor(ss * (0.1 + Math.random() * 0.4));
    return {
      inventory_item_id: item.id,
      item_name: item.name,
      organization_id: 101,
      planner_code: item.planner,
      make_buy: item.make_buy,
      on_hand_qty: oh,
      safety_stock_qty: ss,
      gap: oh - ss,
      violation_severity: severities[i],
      full_lead_time: item.lead_time,
      total_violations: 6,
    };
  });
}

function buildDemoSSAnalysisRows() {
  const assessments = ['NO_POLICY', 'ZERO_SS', 'SS_TOO_LOW', 'SS_TOO_HIGH', 'NO_POLICY', 'SS_TOO_LOW', 'SS_TOO_HIGH', 'ADEQUATE'];
  const methods = ['NOT_SET', 'FIXED', 'FIXED', 'MRP_PLANNED', 'NOT_SET', 'FIXED', 'MRP_PLANNED', 'MRP_PLANNED'];
  return DEMO_ITEMS.map((item, i) => {
    const dailyDemand = Math.floor(Math.random() * 20 + 5);
    const currentSS = assessments[i] === 'NO_POLICY' || assessments[i] === 'ZERO_SS' ? 0 : Math.floor(dailyDemand * (assessments[i] === 'SS_TOO_LOW' ? 1 : assessments[i] === 'SS_TOO_HIGH' ? item.lead_time * 5 : item.lead_time * 1.2));
    const ssDaysCover = dailyDemand > 0 ? (currentSS / dailyDemand).toFixed(1) : null;
    return {
      inventory_item_id: item.id,
      item_name: item.name,
      planner_code: item.planner,
      make_buy: item.make_buy,
      ss_method: methods[i],
      current_ss: currentSS,
      target_ss: Math.floor(dailyDemand * item.lead_time * 0.5),
      on_hand_qty: Math.floor(Math.random() * 300 + 10),
      avg_daily_demand: dailyDemand,
      ss_days_cover: ssDaysCover,
      full_lead_time: item.lead_time,
      ss_assessment: assessments[i],
      demand_cov_pct: Math.floor(Math.random() * 80 + 10),
      policy_flag: 'OK',
      total_items: 8,
    };
  });
}

function buildDemoLateSupplyRows() {
  const supplyTypes = ['PO', 'WO', 'PLANNED', 'PO', 'INTRANSIT', 'WO', 'PO', 'PLANNED'];
  const now = new Date();
  return DEMO_ITEMS.map((item, i) => {
    const needDate = new Date(now.getTime() + (i + 1) * 86400000);
    const daysLate = Math.floor(Math.random() * 14 + 2);
    const supplyDate = new Date(needDate.getTime() + daysLate * 86400000);
    return {
      transaction_id: 50001 + i,
      inventory_item_id: item.id,
      item_name: item.name,
      planner_code: item.planner,
      make_buy: item.make_buy,
      supply_type: supplyTypes[i],
      supply_qty: Math.floor(Math.random() * 300 + 50),
      supply_date: supplyDate.toISOString().slice(0, 10),
      need_date: needDate.toISOString().slice(0, 10),
      days_late: daysLate,
      demand_qty: Math.floor(Math.random() * 400 + 100),
      total_late: 8,
    };
  });
}

function buildDemoExcessRows() {
  return DEMO_ITEMS.slice(0, 5).map((item, i) => {
    const max = Math.floor(Math.random() * 500 + 200);
    const oh = Math.floor(max * (1.5 + Math.random()));
    const excess = oh - max;
    return {
      inventory_item_id: item.id,
      item_name: item.name,
      planner_code: item.planner,
      make_buy: item.make_buy,
      on_hand_qty: oh,
      max_qty: max,
      excess_qty: excess,
      excess_value: Math.floor(excess * (Math.random() * 50 + 10)),
      full_lead_time: item.lead_time,
      total_excess: 5,
    };
  });
}

function buildDemoPeggingRows() {
  const statuses = ['LATE', 'LATE', 'TIGHT', 'LATE', 'TIGHT', 'TIGHT', 'LATE', 'TIGHT'];
  const supplyTypes = ['PO', 'WO', 'PLANNED', 'INTRANSIT', 'PO', 'WO', 'PO', 'PLANNED'];
  const demandSources = ['SALES_ORDER', 'MRP', 'FORECAST', 'SALES_ORDER', 'INTERORG', 'MPS', 'SALES_ORDER', 'MRP'];
  const now = new Date();
  return DEMO_ITEMS.map((item, i) => {
    const demandDate = new Date(now.getTime() + (i + 3) * 86400000);
    const gap = statuses[i] === 'LATE' ? Math.floor(Math.random() * 10 + 2) : Math.floor(Math.random() * 2 + 1);
    const supplyDate = new Date(demandDate.getTime() + gap * 86400000);
    return {
      pegging_id: 60001 + i,
      inventory_item_id: item.id,
      item_name: item.name,
      planner_code: item.planner,
      make_buy: item.make_buy,
      supply_type: supplyTypes[i],
      pegged_qty: Math.floor(Math.random() * 200 + 30),
      supply_date: supplyDate.toISOString().slice(0, 10),
      demand_date: demandDate.toISOString().slice(0, 10),
      demand_source: demandSources[i],
      demand_order: `SO-${10000 + i}`,
      days_gap: gap,
      pegging_status: statuses[i],
      end_item_name: DEMO_ITEMS[(i + 2) % DEMO_ITEMS.length].name,
      end_item_factor: 1,
      total_pegs: 8,
      count_by_status: statuses.filter(s => s === statuses[i]).length,
    };
  });
}

function buildDemoSpareRows() {
  const statuses = ['STOCKOUT_RISK', 'BELOW_ROP', 'OVERSTOCKED', 'SLOW_MOVING', 'STOCKOUT_RISK', 'BELOW_ROP'];
  const items = [
    { name: 'O-Ring Kit OR-100', planner: 'JSMITH' },
    { name: 'Filter Element FE-220', planner: 'MLEE' },
    { name: 'Gasket Set GS-440', planner: 'RPATEL' },
    { name: 'Relay Module RM-55', planner: 'JSMITH' },
    { name: 'Drive Belt DB-300', planner: 'MLEE' },
    { name: 'Fuse Pack FP-12', planner: 'RPATEL' },
  ];
  return items.map((item, i) => {
    const rop = Math.floor(Math.random() * 50 + 10);
    const max = rop * 3;
    const oh = statuses[i] === 'STOCKOUT_RISK' ? 0
             : statuses[i] === 'BELOW_ROP' ? Math.floor(rop * 0.5)
             : statuses[i] === 'OVERSTOCKED' ? Math.floor(max * 2.5)
             : Math.floor(Math.random() * 100 + 20);
    const usage = statuses[i] === 'SLOW_MOVING' ? 0 : Math.floor(Math.random() * 30 + 5);
    return {
      inventory_item_id: 20001 + i,
      item_name: item.name,
      planner_code: item.planner,
      organization_id: 101,
      make_buy: 'BUY',
      on_hand_qty: oh,
      reorder_point: rop,
      max_qty: max,
      order_qty: Math.floor(rop * 2),
      full_lead_time: Math.floor(Math.random() * 21 + 7),
      avg_monthly_usage: usage,
      months_of_history: 12,
      spare_status: statuses[i],
      months_of_supply: usage > 0 ? (oh / usage).toFixed(1) : null,
      inventory_value: Math.floor(oh * (Math.random() * 40 + 5)),
      total_spares: 6,
    };
  });
}

function buildDemoCapacityRows() {
  return [
    { supplier_id: 301, supplier_name: 'Precision Parts Inc', inventory_item_id: 10001, item_name: 'Bearing Assembly BA-2040', max_capacity: 5000, allocated_qty: 4850, utilization_pct: 97.0, capacity_risk: 'CRITICAL', from_date: '2025-04-01', to_date: '2025-06-30', total_constraints: 4 },
    { supplier_id: 302, supplier_name: 'TechComp Ltd',        inventory_item_id: 10002, item_name: 'PCB Board PCB-X100',       max_capacity: 3000, allocated_qty: 2700, utilization_pct: 90.0, capacity_risk: 'HIGH',     from_date: '2025-04-01', to_date: '2025-06-30', total_constraints: 4 },
    { supplier_id: 303, supplier_name: 'GlobalSupply Co',     inventory_item_id: 10005, item_name: 'Control Valve CV-200',     max_capacity: 2000, allocated_qty: 1920, utilization_pct: 96.0, capacity_risk: 'CRITICAL', from_date: '2025-04-01', to_date: '2025-06-30', total_constraints: 4 },
    { supplier_id: 304, supplier_name: 'FastTrack Components', inventory_item_id: 10008, item_name: 'Steel Plate SP-1000',     max_capacity: 8000, allocated_qty: 6800, utilization_pct: 85.0, capacity_risk: 'HIGH',     from_date: '2025-04-01', to_date: '2025-06-30', total_constraints: 4 },
  ];
}

function buildDemoSourcingRows() {
  return [
    { sourcing_rule_name: 'SR-BA2040', inventory_item_id: 10001, item_name: 'Bearing Assembly BA-2040', planner_code: 'JSMITH', vendor_id: 301, preferred_supplier: 'Precision Parts Inc', target_pct: 70, actual_pct: 45, deviation_pct: -25, compliance_status: 'HIGH_DEVIATION', total_rules: 5 },
    { sourcing_rule_name: 'SR-PCBX100', inventory_item_id: 10002, item_name: 'PCB Board PCB-X100', planner_code: 'MLEE', vendor_id: 302, preferred_supplier: 'TechComp Ltd', target_pct: 60, actual_pct: 48, deviation_pct: -12, compliance_status: 'MEDIUM_DEVIATION', total_rules: 5 },
    { sourcing_rule_name: 'SR-CV200', inventory_item_id: 10005, item_name: 'Control Valve CV-200', planner_code: 'MLEE', vendor_id: 303, preferred_supplier: 'GlobalSupply Co', target_pct: 80, actual_pct: 78, deviation_pct: -2, compliance_status: 'ON_TARGET', total_rules: 5 },
    { sourcing_rule_name: 'SR-SM400', inventory_item_id: 10007, item_name: 'Sensor Module SM-400', planner_code: 'JSMITH', vendor_id: 304, preferred_supplier: 'FastTrack Components', target_pct: 50, actual_pct: 72, deviation_pct: 22, compliance_status: 'HIGH_DEVIATION', total_rules: 5 },
    { sourcing_rule_name: 'SR-SP1000', inventory_item_id: 10008, item_name: 'Steel Plate SP-1000', planner_code: 'MLEE', vendor_id: 305, preferred_supplier: 'QualityFirst Mfg', target_pct: 90, actual_pct: 76, deviation_pct: -14, compliance_status: 'MEDIUM_DEVIATION', total_rules: 5 },
  ];
}

function buildDemoVariabilityRows() {
  const patterns = ['LUMPY', 'VARIABLE', 'STABLE', 'LUMPY', 'VARIABLE', 'STABLE', 'VARIABLE', 'LUMPY'];
  return DEMO_ITEMS.map((item, i) => {
    const avg = Math.floor(Math.random() * 200 + 20);
    const cov = patterns[i] === 'LUMPY' ? Math.floor(Math.random() * 80 + 100)
              : patterns[i] === 'VARIABLE' ? Math.floor(Math.random() * 40 + 51)
              : Math.floor(Math.random() * 30 + 5);
    const stddev = (avg * cov / 100).toFixed(2);
    return {
      inventory_item_id: item.id,
      item_name: item.name,
      planner_code: item.planner,
      make_buy: item.make_buy,
      demand_count: Math.floor(Math.random() * 50 + 5),
      avg_demand: avg,
      stddev_demand: stddev,
      cov_pct: cov,
      demand_pattern: patterns[i],
      total_items: 8,
    };
  });
}

function buildDemoCoverageRows() {
  const bands = ['CRITICAL', 'LOW', 'OK', 'CRITICAL', 'LOW', 'EXCESS', 'OK', 'CRITICAL'];
  return DEMO_ITEMS.map((item, i) => {
    const dailyDemand = Math.floor(Math.random() * 30 + 5);
    const dos = bands[i] === 'CRITICAL' ? Math.floor(item.lead_time * 0.3)
              : bands[i] === 'LOW' ? Math.floor(item.lead_time * 1.2)
              : bands[i] === 'EXCESS' ? Math.floor(item.lead_time * 5)
              : Math.floor(item.lead_time * 2);
    return {
      inventory_item_id: item.id,
      item_name: item.name,
      planner_code: item.planner,
      make_buy: item.make_buy,
      on_hand_qty: Math.floor(dailyDemand * dos),
      avg_daily_demand: dailyDemand,
      days_of_supply: dos,
      full_lead_time: item.lead_time,
      coverage_band: bands[i],
      total_items: 8,
    };
  });
}

// ── State persistence (sessionStorage) ───────────────────────────────────────

// ── Supply Chain Graph ──────────────────────────────────────────────────────

let scpGraphNetwork = null;

function renderGraphTab(data, demoMode) {
  const empty = document.getElementById('graphEmpty');
  const content = document.getElementById('graphContent');
  if (!empty || !content) return;
  empty.classList.add('d-none');
  content.classList.remove('d-none');
  // Remove any previous demo notice
  const prev = content.querySelector('.scp-demo-notice');
  if (prev) prev.remove();
  if (demoMode) {
    const notice = document.createElement('div');
    notice.className = 'scp-demo-notice';
    notice.innerHTML = '<i class="fa-solid fa-flask fa-xs me-1"></i>Demo mode — connect to Oracle for live supply chain graph';
    content.insertBefore(notice, content.firstChild);
  }
}

async function loadSupplyChainGraph() {
  const planId = scpState.selectedPlanId || '';
  const btn = document.getElementById('graphLoadBtn');
  const container = document.getElementById('graphContainer');
  const statsEl = document.getElementById('graphStats');

  btn.disabled = true;
  btn.innerHTML = '<span class="spinner-border spinner-border-sm" style="width:12px;height:12px;border-width:2px;"></span> Loading graph...';
  container.innerHTML = '<div style="display:flex;align-items:center;justify-content:center;height:100%;color:var(--text-muted);font-size:13px;">Loading supply chain network...</div>';

  try {
    const resp = await fetch(`/api/scp/graph/${planId || 0}`);
    const data = await resp.json();

    if (data.error) {
      container.innerHTML = `<div style="padding:20px;color:#cf222e;font-size:13px;">${escHtml(data.error)}</div>`;
      btn.innerHTML = '<i class="fa-solid fa-rotate-right fa-xs me-1"></i>Retry';
      btn.disabled = false;
      return;
    }

    const nodes = data.nodes || [];
    const edges = data.edges || [];
    const stats = data.stats || {};

    statsEl.textContent = `${nodes.length} nodes \u00b7 ${edges.length} edges \u00b7 ${stats.late_count || 0} late \u00b7 ${stats.tight_count || 0} tight`;

    // Color scheme
    const groupColors = {
      item:         { background: '#0969da', border: '#0550ae', font: { color: '#fff' } },
      supplier:     { background: '#8250df', border: '#6639ba', font: { color: '#fff' } },
      demand:       { background: '#bf3989', border: '#99306f', font: { color: '#fff' } },
      supply_ok:    { background: '#1a7f37', border: '#116329', font: { color: '#fff' } },
      supply_tight: { background: '#bf8700', border: '#9a6700', font: { color: '#fff' } },
      supply_late:  { background: '#cf222e', border: '#a40e26', font: { color: '#fff' } },
    };

    // Build vis.js datasets
    const visNodes = new vis.DataSet(nodes.map(n => {
      const group = n.group === 'supply' ? `supply_${(n.status || 'ok').toLowerCase()}` : n.group;
      const shape = n.group === 'item' ? 'box' : n.group === 'supplier' ? 'diamond' : n.group === 'demand' ? 'triangle' : 'dot';
      const size = n.group === 'item' ? 25 : 18;
      return {
        id: n.id,
        label: n.label,
        group: group,
        shape: shape,
        size: size,
        color: groupColors[group] || groupColors.item,
        title: `${n.label}\n${n.group}${n.status ? ' (' + n.status + ')' : ''}${n.make_buy ? '\n' + n.make_buy : ''}`,
      };
    }));

    const visEdges = new vis.DataSet(edges.map((e, i) => ({
      id: i,
      from: e.from,
      to: e.to,
      label: e.label || '',
      arrows: 'to',
      color: { color: e.status === 'LATE' ? '#cf222e' : e.status === 'TIGHT' ? '#bf8700' : '#57606a', opacity: 0.7 },
      font: { size: 9, color: '#656d76', strokeWidth: 0 },
      width: e.status === 'LATE' ? 2.5 : 1.5,
      smooth: { type: 'cubicBezier', roundness: 0.4 },
    })));

    const options = {
      layout: {
        improvedLayout: true,
        hierarchical: false,
      },
      physics: {
        enabled: true,
        solver: 'forceAtlas2Based',
        forceAtlas2Based: {
          gravitationalConstant: -40,
          centralGravity: 0.01,
          springLength: 150,
          springConstant: 0.08,
          damping: 0.4,
        },
        stabilization: { iterations: 200, fit: true },
      },
      interaction: {
        hover: true,
        tooltipDelay: 100,
        zoomView: true,
        dragView: true,
      },
      nodes: {
        font: { size: 11, face: 'Inter, system-ui, sans-serif' },
        borderWidth: 2,
      },
      edges: {
        font: { size: 9 },
      },
    };

    // Destroy previous graph if exists
    if (scpGraphNetwork) {
      scpGraphNetwork.destroy();
      scpGraphNetwork = null;
    }

    scpGraphNetwork = new vis.Network(container, { nodes: visNodes, edges: visEdges }, options);

    // Click handler — show item info
    scpGraphNetwork.on('click', function(params) {
      if (params.nodes.length > 0) {
        const nodeId = params.nodes[0];
        const node = visNodes.get(nodeId);
        if (node && node.title) {
          statsEl.textContent = node.title.replace(/\n/g, ' \u00b7 ');
        }
      }
    });

    btn.innerHTML = '<i class="fa-solid fa-check fa-xs me-1"></i>Loaded';
    btn.disabled = true;

    if (data.demo_mode) {
      statsEl.textContent += ' (demo data)';
    }

    // Update tab count
    const cntEl = document.getElementById('cnt-graph');
    if (cntEl) cntEl.textContent = nodes.length;

  } catch (err) {
    container.innerHTML = `<div style="padding:20px;color:#cf222e;font-size:13px;">Error: ${escHtml(err.message)}</div>`;
    btn.innerHTML = '<i class="fa-solid fa-rotate-right fa-xs me-1"></i>Retry';
    btn.disabled = false;
  }
}

// ── State persistence (sessionStorage) ───────────────────────────────────────

const SCP_STORAGE_KEY = 'scp_state_v1';

function saveScpState(data, daysBack) {
  try {
    sessionStorage.setItem(SCP_STORAGE_KEY, JSON.stringify({
      data,
      daysBack,
      activeTab: scpState.activeTab,
      savedAt: Date.now(),
    }));
  } catch (_) { /* storage full — silently skip */ }
}

function saveScpChatHistory() {
  try {
    const stored = sessionStorage.getItem(SCP_STORAGE_KEY);
    if (!stored) return;
    const parsed = JSON.parse(stored);
    parsed.chatHistory = scpChatHistory;
    sessionStorage.setItem(SCP_STORAGE_KEY, JSON.stringify(parsed));
  } catch (_) {}
}

function restoreScpState() {
  try {
    const raw = sessionStorage.getItem(SCP_STORAGE_KEY);
    if (!raw) return false;
    const stored = JSON.parse(raw);
    const data = stored.data;
    if (!data || !data.kpis) return false;

    scpState.data    = data;
    scpState.daysBack = stored.daysBack || 10000;

    // Restore days input
    const inp = document.getElementById('scpDaysBack');
    if (inp) inp.value = scpState.daysBack;

    // Re-render everything
    const banner = document.getElementById('scpDemoBanner');
    if (data.demo_mode) banner.classList.remove('d-none');
    else                banner.classList.add('d-none');

    document.getElementById('scpExecInfo').textContent =
      `Last run: ${stored.daysBack} days \u00b7 restored`;

    updateScpKPIs(data.kpis, data.demo_mode);
    renderScpFindings(data.findings);
    renderOverviewTab(data.queries.plan_summary, data.demo_mode);
    renderExceptionsTab(data.queries.plan_exceptions, data.demo_mode);
    renderByTypeTab(data.queries.plan_exceptions, data.demo_mode);
    renderBalanceTab(data.queries.demand_supply_balance, data.demo_mode);
    renderActionsTab(data, data.demo_mode);
    renderForecastTab(data.queries.forecast_accuracy, data.demo_mode);
    renderSafetyStockTab(data.queries.safety_stock_violations, data.demo_mode);
    renderSSAnalysisTab(data.queries.safety_stock_analysis, data.demo_mode);
    renderLateSupplyTab(data.queries.late_supply, data.demo_mode);
    renderExcessTab(data.queries.excess_inventory, data.demo_mode);
    renderPeggingTab(data.queries.pegging_analysis, data.demo_mode);
    renderSparePartsTab(data.queries.spare_parts, data.demo_mode);
    renderCapacityTab(data.queries.supplier_capacity, data.demo_mode);
    renderSourcingTab(data.queries.sourcing_compliance, data.demo_mode);
    renderVariabilityTab(data.queries.demand_variability, data.demo_mode);
    renderCoverageTab(data.queries.item_coverage, data.demo_mode);
    renderGraphTab(data, data.demo_mode);
    renderScpAITab(data.kpis, data.findings, data.demo_mode);
    updateScpTabCounts(data.queries);

    // Restore active tab
    if (stored.activeTab) switchScpTab(stored.activeTab);

    // Restore chat history
    if (stored.chatHistory && stored.chatHistory.length > 0) {
      scpChatHistory = stored.chatHistory;
      const msgs = document.getElementById('scpChatMessages');
      if (msgs) {
        msgs.innerHTML = '';
        scpChatHistory.forEach(msg => addScpChatMsg(msg.role, msg.role === 'user' ? escHtml(msg.content) : msg.content));
      }
    }

    return true;
  } catch (_) { return false; }
}

// ── Init ──────────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
  // Load plan list for dropdown
  loadPlanList();

  // Try to restore previous session data first
  const restored = restoreScpState();

  // Auto-run if ?autorun in URL (skip if we already have data)
  if (!restored && window.location.search.includes('autorun')) {
    runScpAnalysis();
  }

  // Keyboard: Escape closes drill-down
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeScpDrillDown();
  });

  // Refresh plan list when Oracle connects
  window.addEventListener('oracle-connected', () => loadPlanList());

  // Save chat history before user leaves the page
  window.addEventListener('beforeunload', saveScpChatHistory);
});
