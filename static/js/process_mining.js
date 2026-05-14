// Process Mining frontend — variants, DFG, bottlenecks, rework, cycle, conformance, drill-down.

const pm = {
  data: null,
  activeTab: 'variants',
  drawerCaseId: null,
};

const ACT_BY_KEY = (window.PM_ACTIVITIES || []).reduce((a, x) => (a[x.key] = x, a), {});

function escHtml(s) {
  if (s === null || s === undefined) return '';
  return String(s).replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
function fmtMoney(v, ccy) {
  if (v == null || isNaN(v)) return '';
  return (ccy || 'USD') + ' ' + Number(v).toLocaleString(undefined, {minimumFractionDigits:0, maximumFractionDigits:0});
}
function fmtHours(h) {
  if (h == null) return '';
  if (h < 1) return Math.round(h * 60) + 'm';
  if (h < 48) return h.toFixed(1) + 'h';
  return (h / 24).toFixed(1) + 'd';
}
function actLabel(k) { return (ACT_BY_KEY[k] || {}).label || k; }
function actColor(k) { return (ACT_BY_KEY[k] || {}).color || '#888'; }

function pmTab(name, btn) {
  pm.activeTab = name;
  document.querySelectorAll('.pm-tab').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  document.querySelectorAll('.pm-pane').forEach(p => p.classList.remove('active'));
  document.getElementById('pane-' + name).classList.add('active');
  if (pm.data) renderActivePane();
}

async function pmAnalyze() {
  const body = {
    days_back:  parseInt(document.getElementById('pmDays').value, 10) || 90,
    vendor:     document.getElementById('pmVendor').value,
    buyer:      document.getElementById('pmBuyer').value,
    min_amount: parseFloat(document.getElementById('pmMinAmt').value) || 0,
    doc_type:   document.getElementById('pmDocType').value,
  };
  const btn = document.getElementById('pmRun');
  const sp  = document.getElementById('pmSpin');
  btn.disabled = true; sp.classList.remove('d-none');

  try {
    const r = await fetch('/api/pm/analyze', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    pm.data = await r.json();
    renderStats();
    renderActivePane();
  } catch (e) {
    console.error(e);
    alert('Analyze failed: ' + e);
  } finally {
    btn.disabled = false; sp.classList.add('d-none');
  }
}

function renderStats() {
  const d = pm.data || {};
  const v = d.variants || {};
  const ct = (d.cycle_time || {}).stats || {};
  const rew = d.rework || {};
  const conf = d.conformance || {};
  const total = d.case_count || 0;

  document.getElementById('stCases').textContent     = total.toLocaleString();
  document.getElementById('stEvents').textContent    = (d.event_count || 0).toLocaleString() + ' events';
  document.getElementById('stVariants').textContent  = (v.distinct_variants || 0);
  document.getElementById('stTopShare').textContent  = v.variants && v.variants[0]
      ? 'Top: ' + v.variants[0].share_pct + '%' : '';
  document.getElementById('stMedian').textContent    = fmtHours(ct.median_h);
  document.getElementById('stP95').textContent       = ct.p95_h ? 'p95 ' + fmtHours(ct.p95_h) : '';
  document.getElementById('stRework').textContent    = rew.cases_with_rework || 0;
  document.getElementById('stReworkPct').textContent = total
      ? Math.round((rew.cases_with_rework || 0) * 100 / total) + '% of cases' : '';
  document.getElementById('stConf').textContent      = conf.non_conformant_cases || 0;
  document.getElementById('stConfPct').textContent   = total
      ? Math.round((conf.non_conformant_cases || 0) * 100 / total) + '% non-conformant' : '';
}

function renderActivePane() {
  const fns = {
    variants: renderVariants,
    map:      renderMap,
    bottle:   renderBottle,
    rework:   renderRework,
    cycle:    renderCycle,
    conform:  renderConform,
  };
  fns[pm.activeTab]?.();
}

// ─── Variants tab ───────────────────────────────────────────────────────────
function renderVariants() {
  const v = (pm.data?.variants?.variants) || [];
  if (!v.length) { document.getElementById('pane-variants').innerHTML = '<p class="text-muted">No data.</p>'; return; }

  const html = v.map((row, i) => {
    const tag = row.is_happy_path ? '<span class="var-tag happy">happy</span>'
              : (row.missing_required && row.missing_required.length) ? '<span class="var-tag bad">non-conform</span>'
              : row.has_rework ? '<span class="var-tag rework">rework</span>' : '';
    const seq = row.sequence.map(k => `<span class="var-step" style="border-color:${actColor(k)}33;color:${actColor(k)};">${escHtml(actLabel(k))}</span>`).join('<span style="color:var(--text-muted)">›</span>');
    return `
      <div class="var-row">
        <div class="var-head" onclick="pmExpandVariant(${i})">
          <div class="var-rank">#${i+1}</div>
          <div class="var-share">${row.share_pct}%</div>
          <div class="var-cycle">${row.case_count} cases</div>
          <div class="var-cycle">${fmtHours(row.median_cycle_hours)}</div>
          <div class="var-seq">${seq}</div>
          <div class="var-actions">
            ${tag}
            <button onclick="event.stopPropagation(); pmShowVariantCases(${i})">Cases</button>
          </div>
        </div>
      </div>
    `;
  }).join('');

  document.getElementById('pane-variants').innerHTML = html;
}

async function pmShowVariantCases(idx) {
  const row = pm.data.variants.variants[idx];
  const r = await fetch('/api/pm/cases_for_variant', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ sequence: row.sequence, limit: 50 }),
  });
  const d = await r.json();
  openCaseListDrawer(`Variant #${idx+1} — ${row.case_count} cases`, d.cases || []);
}

function pmExpandVariant(idx) { pmShowVariantCases(idx); }

// ─── Process Map (DFG) ──────────────────────────────────────────────────────
function renderMap() {
  const map = pm.data?.process_map;
  if (!map || !map.nodes.length) {
    document.getElementById('pane-map').innerHTML = '<p class="text-muted">No data.</p>';
    return;
  }

  // Layout: 4 columns (PROCUREMENT, RECEIPT, PAYABLES, PAYMENT)
  const legCols = { PROCUREMENT: 0, RECEIPT: 1, PAYABLES: 2, PAYMENT: 3 };
  const colCount = 4;
  const colW = 240;
  const rowH = 72;
  const padL = 30, padT = 30;

  const nodesByLeg = {};
  map.nodes.forEach(n => {
    nodesByLeg[n.leg] = nodesByLeg[n.leg] || [];
    nodesByLeg[n.leg].push(n);
  });
  Object.values(nodesByLeg).forEach(arr => arr.sort((a, b) => a.order - b.order));

  const positions = {};
  Object.entries(nodesByLeg).forEach(([leg, arr]) => {
    arr.forEach((n, i) => {
      positions[n.key] = {
        cx: padL + legCols[leg] * colW + 90,
        cy: padT + i * rowH + 26,
      };
    });
  });

  const maxRowsAcrossLegs = Math.max(...Object.values(nodesByLeg).map(a => a.length));
  const W = padL + colCount * colW;
  const H = padT + maxRowsAcrossLegs * rowH + 30;

  // Edges: classify by median_hours percentile for highlight
  const sortedDur = [...map.edges.map(e => e.median_hours || 0)].sort((a, b) => a - b);
  const p75 = sortedDur[Math.floor(sortedDur.length * 0.75)] || 0;
  const p90 = sortedDur[Math.floor(sortedDur.length * 0.90)] || 0;
  const maxCount = Math.max(...map.edges.map(e => e.count || 1), 1);

  const edgesSvg = map.edges.map(e => {
    const f = positions[e.from], t = positions[e.to];
    if (!f || !t) return '';
    const cls = (e.median_hours || 0) >= p90 ? 'pm-edge hot'
              : (e.median_hours || 0) >= p75 ? 'pm-edge warm'
              : 'pm-edge';
    const sw = 1 + Math.round((e.count / maxCount) * 4);
    const dx = (t.cx - f.cx);
    const dy = (t.cy - f.cy);
    const midX = f.cx + dx * 0.5;
    const midY = f.cy + dy * 0.5 - 14;
    const path = `M${f.cx+78},${f.cy} C${f.cx+78+50},${f.cy} ${t.cx-78-50},${t.cy} ${t.cx-78},${t.cy}`;
    const lab = `${e.count} · ${fmtHours(e.median_hours)}`;
    return `
      <path class="${cls}" d="${path}" style="stroke-width:${sw}"
            onclick="pmShowEdgeCases('${e.from}','${e.to}')"></path>
      <text class="pm-edge-label" x="${midX}" y="${midY}" text-anchor="middle">${escHtml(lab)}</text>
    `;
  }).join('');

  const nodesSvg = map.nodes.map(n => {
    const p = positions[n.key];
    return `
      <g transform="translate(${p.cx-78},${p.cy-22})">
        <rect class="pm-node-rect" width="156" height="44" rx="8" ry="8"
              style="stroke:${n.color};"></rect>
        <text class="pm-node-text" x="78" y="20" text-anchor="middle"
              style="fill:${n.color};">${escHtml(n.label)}</text>
        <text class="pm-node-count" x="78" y="34" text-anchor="middle"
              style="fill:var(--text-muted);">${n.count} occurrences</text>
      </g>
    `;
  }).join('');

  const legHeaders = Object.keys(legCols).map(leg => {
    const x = padL + legCols[leg] * colW + 90;
    return `<text class="pm-node-text" x="${x}" y="${20}" text-anchor="middle" style="fill:var(--text-muted);">${leg}</text>`;
  }).join('');

  document.getElementById('pane-map').innerHTML = `
    <div class="pm-map-wrap">
      <div style="font-size:11px; color: var(--text-muted); margin-bottom: 6px;">
        Edge thickness = frequency. Red = top 10% slowest; orange = top 25%. Click an edge to see contributing cases.
      </div>
      <div class="pm-map">
        <svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid meet">
          ${legHeaders}
          ${edgesSvg}
          ${nodesSvg}
        </svg>
      </div>
    </div>
  `;
}

async function pmShowEdgeCases(from, to) {
  const r = await fetch('/api/pm/cases_for_edge?from=' + encodeURIComponent(from) + '&to=' + encodeURIComponent(to) + '&limit=50');
  const d = await r.json();
  openCaseListDrawer(`${actLabel(from)} → ${actLabel(to)}`, d.cases || [], 'edge');
}

// ─── Bottlenecks tab ────────────────────────────────────────────────────────
function renderBottle() {
  const list = pm.data?.bottlenecks || [];
  if (!list.length) { document.getElementById('pane-bottle').innerHTML = '<p class="text-muted">No data.</p>'; return; }
  const max = Math.max(...list.map(e => e.median_hours || 0));
  const html = `
    <table class="pm-table">
      <thead>
        <tr><th>#</th><th>From</th><th></th><th>To</th><th>Cases</th><th>Median</th><th>p95</th><th>Heat</th></tr>
      </thead>
      <tbody>
        ${list.map((e, i) => {
          const w = max > 0 ? Math.round((e.median_hours || 0) * 100 / max) : 0;
          return `
            <tr onclick="pmShowEdgeCases('${e.from}','${e.to}')">
              <td>${i + 1}</td>
              <td><span class="var-step" style="color:${actColor(e.from)};">${escHtml(e.from_label)}</span></td>
              <td style="color:var(--text-muted)">›</td>
              <td><span class="var-step" style="color:${actColor(e.to)};">${escHtml(e.to_label)}</span></td>
              <td>${e.count}</td>
              <td>${fmtHours(e.median_hours)}</td>
              <td>${fmtHours(e.p95_hours)}</td>
              <td>
                <div style="background:var(--bg-card-2); border:1px solid var(--border); border-radius:6px; height:8px; width:160px; overflow:hidden;">
                  <div style="background: linear-gradient(90deg, #d4a017, #d12f2f); width:${w}%; height:100%;"></div>
                </div>
              </td>
            </tr>
          `;
        }).join('')}
      </tbody>
    </table>
  `;
  document.getElementById('pane-bottle').innerHTML = html;
}

// ─── Rework tab ─────────────────────────────────────────────────────────────
function renderRework() {
  const r = pm.data?.rework || {};
  const cases = r.cases || [];
  const totals = r.by_activity || {};
  const totRows = Object.entries(totals).map(([k, n]) => `
    <tr>
      <td><span class="var-step" style="color:${actColor(k)};">${escHtml(actLabel(k))}</span></td>
      <td>${n}</td>
    </tr>
  `).join('') || '<tr><td colspan="2" class="text-muted">No rework activities.</td></tr>';

  const caseRows = cases.map(c => `
    <tr onclick="pmOpenCase('${escHtml(c.case_id)}')">
      <td>${escHtml(c.case_id)}</td>
      <td>${escHtml(c.vendor_name || '')}</td>
      <td>${escHtml(fmtMoney(c.amount, c.currency))}</td>
      <td>${Object.entries(c.rework || {}).map(([k, v]) => `<span class="var-tag rework">${escHtml(actLabel(k))}: ${v}</span>`).join(' ')}</td>
      <td>${c.total_steps}</td>
    </tr>
  `).join('') || '<tr><td colspan="5" class="text-muted">No cases with rework.</td></tr>';

  document.getElementById('pane-rework').innerHTML = `
    <div style="display:grid; grid-template-columns: 320px 1fr; gap: 14px;">
      <div>
        <h6 style="font-size:12px; font-weight:700; margin-bottom:6px;">Rework totals</h6>
        <table class="pm-table"><thead><tr><th>Activity</th><th>Excess</th></tr></thead>
          <tbody>${totRows}</tbody></table>
      </div>
      <div>
        <h6 style="font-size:12px; font-weight:700; margin-bottom:6px;">Cases with rework — click to drill</h6>
        <table class="pm-table"><thead><tr><th>Case</th><th>Vendor</th><th>Amount</th><th>Rework</th><th>Steps</th></tr></thead>
          <tbody>${caseRows}</tbody></table>
      </div>
    </div>
  `;
}

// ─── Cycle Time tab ─────────────────────────────────────────────────────────
function renderCycle() {
  const ct = pm.data?.cycle_time || {};
  const buckets = ct.buckets || [];
  const stats = ct.stats || {};
  const slowest = ct.slowest_cases || [];

  const max = Math.max(...buckets.map(b => b.count), 1);
  const bars = buckets.map(b => `
    <div class="ct-bar" style="height: ${Math.max(4, (b.count / max) * 160)}px;">
      <div class="ct-bar-count">${b.count}</div>
      <div class="ct-bar-label">${b.label}</div>
    </div>
  `).join('');

  const slowRows = slowest.map(c => `
    <tr onclick="pmOpenCase('${escHtml(c.case_id)}')">
      <td>${escHtml(c.case_id)}</td>
      <td>${escHtml(c.vendor_name || '')}</td>
      <td>${escHtml(fmtMoney(c.amount, c.currency))}</td>
      <td>${c.days}d</td>
      <td>${c.step_count}</td>
    </tr>
  `).join('') || '<tr><td colspan="5" class="text-muted">No data.</td></tr>';

  document.getElementById('pane-cycle').innerHTML = `
    <div style="display:grid; grid-template-columns: 1.2fr 1fr; gap: 14px;">
      <div>
        <h6 style="font-size:12px; font-weight:700; margin-bottom:6px;">End-to-end cycle distribution</h6>
        <div class="pm-map-wrap" style="min-height:auto;">
          <div class="ct-bars">${bars}</div>
          <div style="margin-top:30px; font-size:11px; color: var(--text-muted); display:flex; gap:14px; flex-wrap:wrap;">
            <div>median <strong style="color:var(--text-primary);">${fmtHours(stats.median_h)}</strong></div>
            <div>mean   <strong style="color:var(--text-primary);">${fmtHours(stats.mean_h)}</strong></div>
            <div>p95    <strong style="color:var(--text-primary);">${fmtHours(stats.p95_h)}</strong></div>
            <div>min    <strong style="color:var(--text-primary);">${fmtHours(stats.min_h)}</strong></div>
            <div>max    <strong style="color:var(--text-primary);">${fmtHours(stats.max_h)}</strong></div>
          </div>
        </div>
      </div>
      <div>
        <h6 style="font-size:12px; font-weight:700; margin-bottom:6px;">Slowest cases</h6>
        <table class="pm-table"><thead><tr><th>Case</th><th>Vendor</th><th>Amount</th><th>Days</th><th>Steps</th></tr></thead>
          <tbody>${slowRows}</tbody></table>
      </div>
    </div>
  `;
}

// ─── Conformance tab ────────────────────────────────────────────────────────
function renderConform() {
  const c = pm.data?.conformance || {};
  const counts = c.issue_counts || [];
  const cases = c.cases || [];

  const issueRows = counts.map(i => `
    <tr>
      <td><span class="issue-chip">${escHtml(i.code)}</span></td>
      <td>${escHtml(i.label)}</td>
      <td>${i.count}</td>
    </tr>
  `).join('') || '<tr><td colspan="3" class="text-muted">All cases conform.</td></tr>';

  const caseRows = cases.map(r => `
    <tr onclick="pmOpenCase('${escHtml(r.case_id)}')">
      <td>${escHtml(r.case_id)}</td>
      <td>${escHtml(r.vendor_name || '')}</td>
      <td>${escHtml(fmtMoney(r.amount, r.currency))}</td>
      <td>${(r.issues || []).map(x => `<span class="issue-chip">${escHtml(x)}</span>`).join('')}</td>
      <td>${r.step_count}</td>
    </tr>
  `).join('') || '<tr><td colspan="5" class="text-muted">No non-conformant cases.</td></tr>';

  document.getElementById('pane-conform').innerHTML = `
    <div style="display:grid; grid-template-columns: 360px 1fr; gap: 14px;">
      <div>
        <h6 style="font-size:12px; font-weight:700; margin-bottom:6px;">Issue summary</h6>
        <table class="pm-table"><thead><tr><th>Code</th><th>Description</th><th>Cases</th></tr></thead>
          <tbody>${issueRows}</tbody></table>
      </div>
      <div>
        <h6 style="font-size:12px; font-weight:700; margin-bottom:6px;">Non-conformant cases — click to drill</h6>
        <table class="pm-table"><thead><tr><th>Case</th><th>Vendor</th><th>Amount</th><th>Issues</th><th>Steps</th></tr></thead>
          <tbody>${caseRows}</tbody></table>
      </div>
    </div>
  `;
}

// ─── Drill-down: case list drawer + case detail drawer ─────────────────────
function openCaseListDrawer(title, cases, kind) {
  const drawer = document.getElementById('pmDrawer');
  document.getElementById('drawerTitle').textContent = title;
  const head = kind === 'edge'
      ? '<tr><th>Case</th><th>Vendor</th><th>Amount</th><th>Edge time</th></tr>'
      : '<tr><th>Case</th><th>Vendor</th><th>Amount</th><th>Cycle</th><th>Steps</th></tr>';
  const body = cases.map(c => kind === 'edge'
      ? `<tr onclick="pmOpenCase('${escHtml(c.case_id)}')"><td>${escHtml(c.case_id)}</td><td>${escHtml(c.vendor_name||'')}</td><td>${escHtml(fmtMoney(c.amount,c.currency))}</td><td>${fmtHours(c.edge_hours)}</td></tr>`
      : `<tr onclick="pmOpenCase('${escHtml(c.case_id)}')"><td>${escHtml(c.case_id)}</td><td>${escHtml(c.vendor_name||'')}</td><td>${escHtml(fmtMoney(c.amount,c.currency))}</td><td>${fmtHours(c.hours)}</td><td>${c.step_count}</td></tr>`
  ).join('') || '<tr><td colspan="5" class="text-muted">No cases.</td></tr>';

  document.getElementById('drawerBody').innerHTML = `
    <div style="font-size:12px; color:var(--text-muted); margin-bottom:8px;">${cases.length} cases. Click any row to see the full timeline and source documents.</div>
    <table class="pm-table"><thead>${head}</thead><tbody>${body}</tbody></table>
  `;
  drawer.classList.add('open');
}

function pmCloseDrawer() {
  document.getElementById('pmDrawer').classList.remove('open');
}

async function pmOpenCase(caseId) {
  pm.drawerCaseId = caseId;
  const r = await fetch('/api/pm/case/' + encodeURIComponent(caseId));
  const d = await r.json();
  renderCaseDrawer(d);
}

function renderCaseDrawer(d) {
  document.getElementById('drawerTitle').textContent =
    d.case_id + ' — ' + (d.vendor_name || '') + ' · ' + fmtMoney(d.amount, d.currency);

  const tl = (d.timeline || []).map(t => `
    <div class="tl-item">
      <span class="tl-dot" style="background:${t.color || '#888'};"></span>
      <div><strong>${escHtml(t.label)}</strong>
        ${t.attribute1 ? '<span class="var-tag rework" style="margin-left:6px;">' + escHtml(t.attribute1) + '</span>' : ''}
      </div>
      <div class="tl-meta">
        ${escHtml((t.ts || '').replace('T',' ').slice(0,19))}
        ${t.since_prev_hours != null ? ' · +' + fmtHours(t.since_prev_hours) : ''}
        ${t.resource ? ' · resource <code>' + escHtml(t.resource) + '</code>' : ''}
        ${t.doc_num ? ' · doc <code>' + escHtml(t.doc_num) + '</code>' : ''}
      </div>
    </div>
  `).join('') || '<p class="text-muted">No events.</p>';

  const p = d.parents || {};
  const poBlk = p.po ? `
    <h6>PO Header</h6>
    <table class="pm-table">
      <tbody>
        <tr><th>PO Number</th><td>${escHtml(p.po.segment1 || p.po.po_header_id)}</td>
            <th>Vendor</th><td>${escHtml(p.po.vendor_name || '')}</td></tr>
        <tr><th>Created</th><td>${escHtml((p.po.creation_date || '').replace('T',' ').slice(0,19))}</td>
            <th>Approved</th><td>${escHtml((p.po.approved_date || '').replace('T',' ').slice(0,19))}</td></tr>
        <tr><th>Currency</th><td>${escHtml(p.po.currency_code || '')}</td>
            <th>Amount</th><td>${escHtml(fmtMoney(p.po.amount, p.po.currency_code))}</td></tr>
      </tbody>
    </table>
    <h6 style="margin-top:10px;">PO Lines</h6>
    <table class="pm-table">
      <thead><tr><th>#</th><th>Description</th><th>Qty</th><th>Unit</th><th>Amount</th></tr></thead>
      <tbody>${(p.po.lines || []).map(l => `
        <tr><td>${escHtml(l.line_num)}</td>
            <td>${escHtml(l.item_description || '')}</td>
            <td>${escHtml(l.quantity)}</td>
            <td>${escHtml(l.unit_price)}</td>
            <td>${escHtml(fmtMoney(l.amount, p.po.currency_code))}</td></tr>
      `).join('') || '<tr><td colspan="5" class="text-muted">No lines.</td></tr>'}</tbody>
    </table>
  ` : '<p class="text-muted">No PO header (non-PO case).</p>';

  const rcvBlk = `
    <table class="pm-table"><thead><tr><th>Type</th><th>Date</th><th>Qty</th><th>UOM</th></tr></thead>
      <tbody>${(p.receipts || []).map(r => `
        <tr><td>${escHtml(r.transaction_type)}</td><td>${escHtml((r.transaction_date||'').replace('T',' ').slice(0,19))}</td>
            <td>${escHtml(r.quantity)}</td><td>${escHtml(r.uom||'')}</td></tr>
      `).join('') || '<tr><td colspan="4" class="text-muted">No receipts.</td></tr>'}</tbody>
    </table>
  `;

  const invBlk = `
    <table class="pm-table"><thead><tr><th>Invoice</th><th>Date</th><th>Amount</th><th>Posted</th><th>Approval</th></tr></thead>
      <tbody>${(p.invoices || []).map(iv => `
        <tr><td>${escHtml(iv.invoice_num || iv.invoice_id)}</td>
            <td>${escHtml((iv.invoice_date||'').replace('T',' ').slice(0,19))}</td>
            <td>${escHtml(fmtMoney(iv.amount, iv.currency))}</td>
            <td>${escHtml(iv.posting_status||'')}</td>
            <td>${escHtml(iv.wfapproval_status||'')}</td></tr>
      `).join('') || '<tr><td colspan="5" class="text-muted">No invoices.</td></tr>'}</tbody>
    </table>
  `;

  const holdBlk = `
    <table class="pm-table"><thead><tr><th>Type</th><th>Placed</th><th>Released</th></tr></thead>
      <tbody>${(p.holds || []).map(h => `
        <tr><td><span class="issue-chip">${escHtml(h.hold_lookup_code)}</span></td>
            <td>${escHtml((h.creation_date||'').replace('T',' ').slice(0,19))}</td>
            <td>${escHtml((h.released_date||'').replace('T',' ').slice(0,19))}</td></tr>
      `).join('') || '<tr><td colspan="3" class="text-muted">No holds.</td></tr>'}</tbody>
    </table>
  `;

  const payBlk = `
    <table class="pm-table"><thead><tr><th>Check</th><th>Date</th><th>Amount</th><th>Status</th><th>Cleared</th></tr></thead>
      <tbody>${(p.payments || []).map(c => `
        <tr><td>${escHtml(c.check_number || c.check_id)}</td>
            <td>${escHtml((c.check_date||'').replace('T',' ').slice(0,19))}</td>
            <td>${escHtml(fmtMoney(c.amount, c.currency))}</td>
            <td>${escHtml(c.status||'')}</td>
            <td>${escHtml((c.cleared_date||'').replace('T',' ').slice(0,19))}</td></tr>
      `).join('') || '<tr><td colspan="5" class="text-muted">No payments.</td></tr>'}</tbody>
    </table>
  `;

  document.getElementById('drawerBody').innerHTML = `
    <div style="display:flex; gap:18px; flex-wrap:wrap; font-size:11px; color: var(--text-muted); margin-bottom:8px;">
      <div>steps <strong style="color:var(--text-primary);">${d.step_count || 0}</strong></div>
      <div>total <strong style="color:var(--text-primary);">${d.total_days || 0}d</strong></div>
      <div>first <strong style="color:var(--text-primary);">${(d.first_ts||'').replace('T',' ').slice(0,19)}</strong></div>
      <div>last  <strong style="color:var(--text-primary);">${(d.last_ts||'').replace('T',' ').slice(0,19)}</strong></div>
    </div>

    <div class="pm-pillar-tabs">
      <button class="pm-pillar-tab active" data-p="tl"   onclick="pmPillar('tl', this)">Timeline</button>
      <button class="pm-pillar-tab" data-p="po"   onclick="pmPillar('po', this)">PO</button>
      <button class="pm-pillar-tab" data-p="rcv"  onclick="pmPillar('rcv', this)">Receipts</button>
      <button class="pm-pillar-tab" data-p="inv"  onclick="pmPillar('inv', this)">Invoices</button>
      <button class="pm-pillar-tab" data-p="hold" onclick="pmPillar('hold', this)">Holds</button>
      <button class="pm-pillar-tab" data-p="pay"  onclick="pmPillar('pay', this)">Payments</button>
    </div>

    <div class="pm-section pm-pillar-pane" id="pp-tl"   style="display:block;"><div class="tl-list">${tl}</div></div>
    <div class="pm-section pm-pillar-pane" id="pp-po"   style="display:none;">${poBlk}</div>
    <div class="pm-section pm-pillar-pane" id="pp-rcv"  style="display:none;">${rcvBlk}</div>
    <div class="pm-section pm-pillar-pane" id="pp-inv"  style="display:none;">${invBlk}</div>
    <div class="pm-section pm-pillar-pane" id="pp-hold" style="display:none;">${holdBlk}</div>
    <div class="pm-section pm-pillar-pane" id="pp-pay"  style="display:none;">${payBlk}</div>
  `;
  document.getElementById('pmDrawer').classList.add('open');
}

function pmPillar(name, btn) {
  document.querySelectorAll('.pm-pillar-tab').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  document.querySelectorAll('.pm-pillar-pane').forEach(p => p.style.display = 'none');
  document.getElementById('pp-' + name).style.display = 'block';
}

window.addEventListener('DOMContentLoaded', pmAnalyze);
window.pmTab = pmTab;
window.pmAnalyze = pmAnalyze;
window.pmExpandVariant = pmExpandVariant;
window.pmShowVariantCases = pmShowVariantCases;
window.pmShowEdgeCases = pmShowEdgeCases;
window.pmOpenCase = pmOpenCase;
window.pmCloseDrawer = pmCloseDrawer;
window.pmPillar = pmPillar;
