// Observability page — SSE live stream + agent flow strip + event list.

const obs = {
  filter: 'all',
  source: null,
  events: [],
  maxRender: 200,
};

function fmtTs(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
}
function escHtml(s) {
  if (s === null || s === undefined) return '';
  return String(s).replace(/[&<>"']/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

function renderEvent(ev) {
  const phase = ev.phase || 'event';
  const dur = ev.duration_ms != null ? ev.duration_ms + 'ms' : '';
  return `
    <div class="ev-row" data-phase="${escHtml(phase)}">
      <span class="ev-ts">${fmtTs(ev.ts)}</span>
      <span class="ev-phase ${escHtml(phase)}">${escHtml(phase)}</span>
      <span class="ev-agent">${escHtml(ev.agent_label || ev.agent_id || '')}</span>
      <span class="ev-msg">${escHtml(ev.message || '')}</span>
      <span class="ev-dur">${escHtml(dur)}</span>
    </div>
  `;
}

function applyFilter() {
  const list = document.getElementById('evList').querySelector('.ev-list');
  document.getElementById('evEmpty')?.remove();
  list.innerHTML = obs.events
    .filter(ev => obs.filter === 'all' || ev.phase === obs.filter)
    .slice(-obs.maxRender)
    .map(renderEvent)
    .join('');
  list.scrollTop = list.scrollHeight;
  document.getElementById('evList').scrollTop = document.getElementById('evList').scrollHeight;
}

function obsFilter(name, btn) {
  obs.filter = name;
  document.querySelectorAll('.obs-btn[data-filter]').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  applyFilter();
}

function obsClear() {
  obs.events = [];
  applyFilter();
}

function updateFlow(ev) {
  const step = document.getElementById('flow-' + (ev.agent_id || ''));
  if (!step) return;
  if (ev.phase === 'start') {
    step.classList.add('active');
    step.classList.remove('done-CRITICAL', 'done-HIGH', 'done-MEDIUM', 'done-INFO', 'done-ERROR');
  } else if (ev.phase === 'complete') {
    step.classList.remove('active');
    const sev = ev.severity || 'INFO';
    step.classList.add('done-' + sev);
  } else if (ev.phase === 'error') {
    step.classList.remove('active');
    step.classList.add('done-ERROR');
  }
}

function updateTile(ev) {
  const tile = document.getElementById('tile-' + (ev.agent_id || ''));
  if (!tile) return;
  const sev = tile.querySelector('[data-role="sev"]');
  const info = tile.querySelector('[data-role="info"]');

  if (ev.phase === 'start') {
    tile.classList.add('flashing');
    sev.className = 'badge badge-running';
    sev.textContent = 'running';
    info.textContent = ev.message || '';
  } else if (ev.phase === 'query') {
    info.textContent = ev.message || '';
  } else if (ev.phase === 'complete') {
    tile.classList.remove('flashing');
    const s = ev.severity || 'INFO';
    sev.className = 'badge badge-' + s;
    sev.textContent = s;
    info.textContent = (ev.summary || '') + ' · ' + (ev.duration_ms || 0) + 'ms';
  } else if (ev.phase === 'error') {
    tile.classList.remove('flashing');
    sev.className = 'badge badge-ERROR';
    sev.textContent = 'error';
    info.textContent = ev.error || ev.message || '';
  }
}

function refreshStats() {
  fetch('/api/observability/recent?limit=1')
    .then(r => r.json())
    .then(d => {
      const s = d.stats || {};
      document.getElementById('statFlight').textContent = s.in_flight || 0;
      document.getElementById('statRuns').textContent   = s.total_runs || 0;
      document.getElementById('statErr').textContent    = s.total_errors || 0;
      document.getElementById('statAvg').textContent    = s.avg_duration_ms || 0;
    })
    .catch(() => {});
}

function applySnapshot(d) {
  // Hydrate flow + tiles from the most recent state per agent
  const seen = new Set();
  // Reverse so latest event for each agent wins
  (d.events || []).slice().reverse().forEach(ev => {
    if (!ev.agent_id || seen.has(ev.agent_id)) return;
    seen.add(ev.agent_id);
    updateFlow(ev);
    updateTile(ev);
  });

  // Seed event list with last 50
  obs.events = (d.events || []).slice(-50);
  applyFilter();
  refreshStats();
}

function pushEvent(ev) {
  obs.events.push(ev);
  if (obs.events.length > 1000) obs.events = obs.events.slice(-500);

  if (obs.filter === 'all' || ev.phase === obs.filter) {
    const list = document.getElementById('evList').querySelector('.ev-list');
    document.getElementById('evEmpty')?.remove();
    list.insertAdjacentHTML('beforeend', renderEvent(ev));
    while (list.children.length > obs.maxRender) list.removeChild(list.firstChild);
    document.getElementById('evList').scrollTop = document.getElementById('evList').scrollHeight;
  }

  updateFlow(ev);
  updateTile(ev);

  if (ev.phase === 'complete' || ev.phase === 'error' || ev.phase === 'start') {
    refreshStats();
  }
}

function startSse() {
  if (obs.source) try { obs.source.close(); } catch (_) {}
  const src = new EventSource('/api/observability/events');
  obs.source = src;
  src.onmessage = e => {
    try {
      const ev = JSON.parse(e.data);
      pushEvent(ev);
    } catch (_) {}
  };
  src.onerror = () => {
    try { src.close(); } catch (_) {}
    setTimeout(startSse, 3000); // reconnect
  };
}

window.addEventListener('DOMContentLoaded', () => {
  fetch('/api/observability/recent?limit=200')
    .then(r => r.json())
    .then(applySnapshot)
    .catch(() => {});
  startSse();
  setInterval(refreshStats, 5000);
});

window.obsFilter = obsFilter;
window.obsClear = obsClear;
