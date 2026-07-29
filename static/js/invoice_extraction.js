// Invoice Extraction page — folder scan -> AI structured extraction -> Excel/JSON output.

function ixEscHtml(s) {
  return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function ixFmtMoney(v, ccy) {
  if (v === null || v === undefined || v === '') return '—';
  const n = Number(v);
  if (!isFinite(n)) return ixEscHtml(v);
  return (ccy ? ccy + ' ' : '') + n.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

async function ixRun() {
  const folderInput = document.getElementById('ixFolderPath');
  const folder = folderInput.value.trim();
  const alertEl = document.getElementById('ixAlert');
  alertEl.classList.remove('show');

  if (!folder) {
    alertEl.textContent = 'Enter a folder path first.';
    alertEl.classList.add('show');
    return;
  }

  const btn = document.getElementById('btnIxRun');
  const spin = document.getElementById('ixSpinner');
  if (btn.disabled) return;
  btn.disabled = true;
  spin.classList.remove('d-none');

  try {
    const res = await fetch('/api/invoice_extraction/run', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ folder }),
    });
    const data = await res.json();
    if (!res.ok || data.error) {
      alertEl.textContent = data.error || 'Invoice extraction failed.';
      alertEl.classList.add('show');
      document.getElementById('ixSummaryRow').style.display = 'none';
      return;
    }
    ixRenderResults(data);
  } catch (e) {
    alertEl.textContent = 'Request failed: ' + e;
    alertEl.classList.add('show');
  } finally {
    btn.disabled = false;
    spin.classList.add('d-none');
  }
}

function ixRenderResults(data) {
  const summaryRow = document.getElementById('ixSummaryRow');
  summaryRow.style.display = 'grid';
  document.getElementById('ixSumTotal').textContent = data.total_files ?? 0;
  document.getElementById('ixSumOk').textContent = data.processed ?? 0;
  document.getElementById('ixSumErr').textContent = data.failed ?? 0;
  document.getElementById('ixSumOutput').textContent = data.excel_dir ? 'excel/, json/' : '—';

  const wrap = document.getElementById('ixResultsWrap');
  const rows = data.results || [];
  if (!rows.length) {
    wrap.innerHTML = '<div class="ix-empty">No PDF/PNG/JPG invoice files found in that folder.</div>';
    return;
  }

  let html = '<table class="ix-table"><thead><tr>' +
    '<th>File</th><th>Status</th><th>Invoice #</th><th>Vendor</th><th class="num">Total</th><th>Output</th>' +
    '</tr></thead><tbody>';

  rows.forEach(r => {
    const statusPill = r.status === 'ok'
      ? '<span class="ix-status-pill ix-status-ok">OK</span>'
      : '<span class="ix-status-pill ix-status-error">Error</span>';
    const output = r.status === 'ok'
      ? '<span class="ix-path">' + ixEscHtml(r.excel_path) + '</span><br><span class="ix-path">' + ixEscHtml(r.json_path) + '</span>'
      : '<span class="ix-path">' + ixEscHtml(r.error || '') + '</span>';
    html += '<tr>' +
      '<td>' + ixEscHtml(r.filename) + '</td>' +
      '<td>' + statusPill + '</td>' +
      '<td>' + ixEscHtml(r.invoice_number || '—') + '</td>' +
      '<td>' + ixEscHtml(r.vendor_name || '—') + '</td>' +
      '<td class="num">' + ixFmtMoney(r.total_amount, r.currency) + '</td>' +
      '<td>' + output + '</td>' +
      '</tr>';
  });

  html += '</tbody></table>';
  wrap.innerHTML = html;
}
