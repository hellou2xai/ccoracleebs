// MCP Console — tool browser + invocation form + resource / prompt explorers.

const mcp = {
  filter: '',
  selected: null,
};

function escHtml(s) {
  if (s === null || s === undefined) return '';
  return String(s).replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

function mcpTab(name, btn) {
  document.querySelectorAll('.mcp-tab').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  document.querySelectorAll('.mcp-pane').forEach(p => p.classList.remove('active'));
  document.getElementById('mcp-pane-' + name).classList.add('active');
}

function mcpFilterTools() {
  mcp.filter = (document.getElementById('mcpSearch').value || '').toLowerCase();
  renderToolList();
}

function renderToolList() {
  const groups = {};
  MCP_TOOLS.forEach(t => {
    if (mcp.filter) {
      const hay = (t.name + ' ' + t.description + ' ' + (t.tags || []).join(' ')).toLowerCase();
      if (!hay.includes(mcp.filter)) return;
    }
    (groups[t.group] = groups[t.group] || []).push(t);
  });
  const html = Object.keys(groups).sort().map(g => `
    <div class="mcp-group-header">${escHtml(g)} (${groups[g].length})</div>
    ${groups[g].map(t => `
      <div class="mcp-tool-item ${mcp.selected === t.name ? 'active' : ''}" onclick="mcpSelect('${t.name}')">
        <div class="mcp-tool-name">${escHtml(t.name)}</div>
        <div class="mcp-tool-desc">${escHtml(t.description)}</div>
        <div class="mcp-tool-tags">
          ${(t.tags || []).map(x => `<span class="mcp-tool-tag">${escHtml(x)}</span>`).join('')}
        </div>
      </div>
    `).join('')}
  `).join('');
  document.getElementById('mcpToolsContainer').innerHTML = html ||
    '<div class="text-muted small px-2 py-3">No tools match.</div>';
}

function mcpSelect(name) {
  mcp.selected = name;
  renderToolList();
  const t = MCP_TOOLS.find(x => x.name === name);
  if (!t) return;
  const props = (t.schema && t.schema.properties) || {};
  const required = new Set(t.schema && t.schema.required || []);
  const formRows = Object.keys(props).map(k => {
    const p = props[k] || {};
    const def = p.default != null ? p.default : '';
    const placeholder = p.description ? escHtml(p.description) : '';
    return `
      <div class="mcp-form-row">
        <label>${escHtml(k)}${required.has(k) ? '<span style="color:#d12f2f;"> *</span>' : ''}</label>
        <input id="mcpArg_${escHtml(k)}" data-key="${escHtml(k)}" data-type="${escHtml(p.type || 'string')}"
               placeholder="${placeholder}" value="${escHtml(def)}" />
      </div>
    `;
  }).join('') || '<div class="text-muted small">No parameters.</div>';

  document.getElementById('mcpToolPanel').innerHTML = `
    <div class="mcp-tool-title">${escHtml(t.name)}</div>
    <div class="mcp-tool-desc">${escHtml(t.description)}</div>
    <div class="mcp-tool-tags">
      <span class="mcp-tool-tag">${escHtml(t.group)}</span>
      ${(t.tags || []).map(x => `<span class="mcp-tool-tag">${escHtml(x)}</span>`).join('')}
    </div>

    <div class="mcp-tool-section">Input parameters</div>
    <div>${formRows}</div>

    <div class="mcp-buttons" style="margin-top:8px;">
      <button class="mcp-btn-primary" id="mcpInvokeBtn" onclick="mcpInvoke()">
        <i class="fa-solid fa-play me-1"></i>Invoke
      </button>
      <button class="mcp-btn-ghost" onclick="mcpCopyCurl()">Copy curl</button>
      <span id="mcpInvokeStatus" class="text-muted small" style="margin-left:8px;"></span>
    </div>

    <div class="mcp-tool-section">Result</div>
    <div class="mcp-result-meta" id="mcpResultMeta">—</div>
    <pre class="mcp-result" id="mcpResultBody">(no result yet)</pre>
  `;
}

function mcpCollectArgs() {
  const out = {};
  document.querySelectorAll('#mcpToolPanel input[data-key]').forEach(el => {
    const v = el.value.trim();
    if (v === '') return;
    const t = el.dataset.type || 'string';
    if (t === 'integer') out[el.dataset.key] = parseInt(v, 10);
    else if (t === 'number') out[el.dataset.key] = parseFloat(v);
    else out[el.dataset.key] = v;
  });
  return out;
}

async function mcpInvoke() {
  if (!mcp.selected) return;
  const btn = document.getElementById('mcpInvokeBtn');
  const status = document.getElementById('mcpInvokeStatus');
  btn.disabled = true;
  status.textContent = 'running…';
  const args = mcpCollectArgs();
  const t0 = Date.now();
  try {
    const r = await fetch('/api/mcp/call', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: mcp.selected, arguments: args }),
    });
    const d = await r.json();
    const meta = `name=${d.name} · server=${d.execution_time_ms}ms · client=${Date.now() - t0}ms`;
    document.getElementById('mcpResultMeta').textContent = meta;
    document.getElementById('mcpResultBody').textContent = JSON.stringify(d.result, null, 2);
    status.textContent = 'ok';
  } catch (e) {
    document.getElementById('mcpResultBody').textContent = 'request failed: ' + e;
    status.textContent = 'error';
  } finally {
    btn.disabled = false;
  }
}

function mcpCopyCurl() {
  if (!mcp.selected) return;
  const args = mcpCollectArgs();
  const cmd = `curl -sS -X POST http://localhost:8000/api/mcp/call \\
  -H "Content-Type: application/json" \\
  -d '${JSON.stringify({ name: mcp.selected, arguments: args })}'`;
  navigator.clipboard.writeText(cmd).then(() => {
    document.getElementById('mcpInvokeStatus').textContent = 'curl copied';
  });
}

async function mcpReadResource(template, key, idx) {
  const v = document.getElementById('resInput_' + idx).value.trim();
  if (!v) { alert('Enter an id'); return; }
  const uri = template.replace(`{${key}}`, v);
  const r = await fetch('/api/mcp/resource?uri=' + encodeURIComponent(uri));
  const d = await r.json();
  const out = document.getElementById('resResult_' + idx);
  out.style.display = 'block';
  out.textContent = JSON.stringify(d, null, 2);
}

async function mcpRenderPrompt(prompt) {
  const args = {};
  (prompt.arguments || []).forEach((a, i) => {
    const el = document.getElementById('pa_' + i + '_' + prompt.name);
    if (el && el.value.trim() !== '') args[a.name] = el.value.trim();
  });
  const r = await fetch('/api/mcp/prompt', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: prompt.name, arguments: args }),
  });
  const d = await r.json();
  const out = document.getElementById('pr_' + prompt.name);
  out.style.display = 'block';
  out.textContent = JSON.stringify(d, null, 2);
}

window.addEventListener('DOMContentLoaded', renderToolList);
window.mcpTab = mcpTab;
window.mcpFilterTools = mcpFilterTools;
window.mcpSelect = mcpSelect;
window.mcpInvoke = mcpInvoke;
window.mcpCopyCurl = mcpCopyCurl;
window.mcpReadResource = mcpReadResource;
window.mcpRenderPrompt = mcpRenderPrompt;
