"""
Process Mining configuration for Procure-to-Pay on Oracle EBS.

Defines:
  - canonical activity catalog (15 P2P activities)
  - event-log SQL pack (UNION ALL across PO/AP/RCV)
  - expected variant + conformance baseline
"""
from typing import Any, Dict, List


# ─── Canonical P2P activity catalog ──────────────────────────────────────────

ACTIVITIES: List[Dict[str, Any]] = [
    {"key": "REQ_CREATED",        "label": "Requisition Created",   "leg": "PROCUREMENT", "color": "#0969da", "order": 1},
    {"key": "REQ_APPROVED",       "label": "Requisition Approved",  "leg": "PROCUREMENT", "color": "#0969da", "order": 2},
    {"key": "PO_CREATED",         "label": "PO Created",            "leg": "PROCUREMENT", "color": "#0969da", "order": 3},
    {"key": "PO_APPROVED",        "label": "PO Approved",           "leg": "PROCUREMENT", "color": "#0969da", "order": 4},
    {"key": "PO_REVISED",         "label": "PO Revised",            "leg": "PROCUREMENT", "color": "#a04ad6", "order": 5},
    {"key": "GOODS_RECEIVED",     "label": "Goods Received",        "leg": "RECEIPT",     "color": "#1a7f37", "order": 6},
    {"key": "GOODS_DELIVERED",    "label": "Goods Delivered",       "leg": "RECEIPT",     "color": "#1a7f37", "order": 7},
    {"key": "INVOICE_RECEIVED",   "label": "Invoice Received",      "leg": "PAYABLES",    "color": "#e65100", "order": 8},
    {"key": "INVOICE_VALIDATED",  "label": "Invoice Validated",     "leg": "PAYABLES",    "color": "#e65100", "order": 9},
    {"key": "HOLD_PLACED",        "label": "Hold Placed",           "leg": "PAYABLES",    "color": "#d12f2f", "order": 10},
    {"key": "HOLD_RELEASED",      "label": "Hold Released",         "leg": "PAYABLES",    "color": "#d12f2f", "order": 11},
    {"key": "INVOICE_APPROVED",   "label": "Invoice Approved",      "leg": "PAYABLES",    "color": "#e65100", "order": 12},
    {"key": "INVOICE_POSTED",     "label": "Invoice Posted",        "leg": "PAYABLES",    "color": "#e65100", "order": 13},
    {"key": "PAYMENT_ISSUED",     "label": "Payment Issued",        "leg": "PAYMENT",     "color": "#6f42c1", "order": 14},
    {"key": "PAYMENT_CLEARED",    "label": "Payment Cleared",       "leg": "PAYMENT",     "color": "#6f42c1", "order": 15},
]

ACTIVITY_BY_KEY = {a["key"]: a for a in ACTIVITIES}


# ─── Conformance baseline ────────────────────────────────────────────────────

# Required activities for a fully-conformant P2P case.
REQUIRED_ACTIVITIES = [
    "PO_CREATED", "PO_APPROVED",
    "GOODS_RECEIVED",
    "INVOICE_RECEIVED", "INVOICE_VALIDATED", "INVOICE_APPROVED",
    "INVOICE_POSTED",
    "PAYMENT_ISSUED",
]

# Activities that legitimately mean rework (>1 occurrence is normal).
REWORK_ACTIVITIES = ["PO_REVISED", "HOLD_PLACED", "HOLD_RELEASED"]

# Happy-path variant.
HAPPY_PATH = [
    "REQ_CREATED", "REQ_APPROVED",
    "PO_CREATED", "PO_APPROVED",
    "GOODS_RECEIVED", "GOODS_DELIVERED",
    "INVOICE_RECEIVED", "INVOICE_VALIDATED", "INVOICE_APPROVED",
    "INVOICE_POSTED",
    "PAYMENT_ISSUED", "PAYMENT_CLEARED",
]


# ─── Event log SQL ────────────────────────────────────────────────────────────
#
# Case ID = 'PO:' || po_header_id  for everything that has a PO link
# Case ID = 'INV:' || invoice_id   for non-PO invoices
#
# Each branch returns the same shape: case_id, activity, ts, resource, attrs (NVL'd).
# The orchestrator builds the events list, sorts per case, and runs analytics.

EVENT_LOG_SQL = """
SELECT case_id, activity, ts, resource, doc_id, doc_num, vendor_id, vendor_name, amount, currency_code, attribute1
FROM (

    -- 1. Requisition Created
    SELECT 'PO:' || prl.po_header_id      case_id,
           'REQ_CREATED'                  activity,
           rh.creation_date               ts,
           NVL(rh.preparer_id || '', '?') resource,
           rh.requisition_header_id       doc_id,
           rh.segment1                    doc_num,
           NULL                           vendor_id,
           NULL                           vendor_name,
           NULL                           amount,
           NULL                           currency_code,
           rh.type_lookup_code            attribute1
    FROM   po_requisition_headers_all rh
    JOIN   po_requisition_lines_all   prl ON prl.requisition_header_id = rh.requisition_header_id
    WHERE  prl.po_header_id IS NOT NULL
      AND  rh.creation_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 2. Requisition Approved
    SELECT 'PO:' || prl.po_header_id, 'REQ_APPROVED', rh.approved_date,
           NVL(rh.last_updated_by || '', '?'),
           rh.requisition_header_id, rh.segment1, NULL, NULL, NULL, NULL, NULL
    FROM   po_requisition_headers_all rh
    JOIN   po_requisition_lines_all   prl ON prl.requisition_header_id = rh.requisition_header_id
    WHERE  prl.po_header_id IS NOT NULL
      AND  rh.approved_date IS NOT NULL
      AND  rh.approved_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 3. PO Created
    SELECT 'PO:' || ph.po_header_id, 'PO_CREATED', ph.creation_date,
           NVL(ph.agent_id || '', '?'),
           ph.po_header_id, ph.segment1, ph.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = ph.vendor_id),
           NULL, ph.currency_code, ph.type_lookup_code
    FROM   po_headers_all ph
    WHERE  ph.creation_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 4. PO Approved
    SELECT 'PO:' || ph.po_header_id, 'PO_APPROVED', ph.approved_date,
           NVL(ph.last_updated_by || '', '?'),
           ph.po_header_id, ph.segment1, ph.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = ph.vendor_id),
           NULL, ph.currency_code, ph.approved_flag
    FROM   po_headers_all ph
    WHERE  ph.approved_date IS NOT NULL
      AND  ph.approved_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 5. PO Revised (revision_num > 0)
    SELECT 'PO:' || ph.po_header_id, 'PO_REVISED', ph.revised_date,
           NVL(ph.last_updated_by || '', '?'),
           ph.po_header_id, ph.segment1, ph.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = ph.vendor_id),
           NULL, ph.currency_code, TO_CHAR(ph.revision_num)
    FROM   po_headers_all ph
    WHERE  ph.revision_num > 0
      AND  ph.revised_date IS NOT NULL
      AND  ph.revised_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 6. Goods Received
    SELECT 'PO:' || rt.po_header_id, 'GOODS_RECEIVED', rt.transaction_date,
           NVL(rt.created_by || '', '?'),
           rt.transaction_id, NULL, rt.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = rt.vendor_id),
           rt.quantity, NULL, rt.transaction_type
    FROM   rcv_transactions rt
    WHERE  rt.transaction_type = 'RECEIVE'
      AND  rt.po_header_id IS NOT NULL
      AND  rt.transaction_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 7. Goods Delivered
    SELECT 'PO:' || rt.po_header_id, 'GOODS_DELIVERED', rt.transaction_date,
           NVL(rt.created_by || '', '?'),
           rt.transaction_id, NULL, rt.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = rt.vendor_id),
           rt.quantity, NULL, rt.transaction_type
    FROM   rcv_transactions rt
    WHERE  rt.transaction_type = 'DELIVER'
      AND  rt.po_header_id IS NOT NULL
      AND  rt.transaction_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 8. Invoice Received
    SELECT NVL2(il.po_header_id, 'PO:' || il.po_header_id, 'INV:' || i.invoice_id),
           'INVOICE_RECEIVED', i.creation_date,
           NVL(i.created_by || '', '?'),
           i.invoice_id, i.invoice_num, i.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = i.vendor_id),
           i.invoice_amount, i.invoice_currency_code, i.source
    FROM   ap_invoices_all i
    LEFT   JOIN ap_invoice_lines_all il
             ON il.invoice_id = i.invoice_id AND il.line_number = 1
    WHERE  i.cancelled_date IS NULL
      AND  i.creation_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 9. Invoice Validated (approximation: validation_request_id present + last update)
    SELECT NVL2(il.po_header_id, 'PO:' || il.po_header_id, 'INV:' || i.invoice_id),
           'INVOICE_VALIDATED', i.last_update_date,
           NVL(i.last_updated_by || '', '?'),
           i.invoice_id, i.invoice_num, i.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = i.vendor_id),
           i.invoice_amount, i.invoice_currency_code, i.invoice_type_lookup_code
    FROM   ap_invoices_all i
    LEFT   JOIN ap_invoice_lines_all il
             ON il.invoice_id = i.invoice_id AND il.line_number = 1
    WHERE  i.validation_request_id IS NOT NULL
      AND  i.cancelled_date IS NULL
      AND  i.last_update_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 10. Hold Placed
    SELECT NVL2(il.po_header_id, 'PO:' || il.po_header_id, 'INV:' || h.invoice_id),
           'HOLD_PLACED', h.creation_date,
           NVL(h.held_by || '', '?'),
           h.invoice_id, NULL, i.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = i.vendor_id),
           NULL, NULL, h.hold_lookup_code
    FROM   ap_holds_all h
    JOIN   ap_invoices_all i ON i.invoice_id = h.invoice_id
    LEFT   JOIN ap_invoice_lines_all il
             ON il.invoice_id = h.invoice_id AND il.line_number = 1
    WHERE  h.creation_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 11. Hold Released
    SELECT NVL2(il.po_header_id, 'PO:' || il.po_header_id, 'INV:' || h.invoice_id),
           'HOLD_RELEASED', h.release_lookup_date,
           NVL(h.released_by || '', '?'),
           h.invoice_id, NULL, i.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = i.vendor_id),
           NULL, NULL, h.release_lookup_code
    FROM   ap_holds_all h
    JOIN   ap_invoices_all i ON i.invoice_id = h.invoice_id
    LEFT   JOIN ap_invoice_lines_all il
             ON il.invoice_id = h.invoice_id AND il.line_number = 1
    WHERE  h.release_lookup_date IS NOT NULL
      AND  h.release_lookup_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 12. Invoice Approved (wfapproval_status flip)
    SELECT NVL2(il.po_header_id, 'PO:' || il.po_header_id, 'INV:' || i.invoice_id),
           'INVOICE_APPROVED', i.last_update_date,
           NVL(i.last_updated_by || '', '?'),
           i.invoice_id, i.invoice_num, i.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = i.vendor_id),
           i.invoice_amount, i.invoice_currency_code, i.wfapproval_status
    FROM   ap_invoices_all i
    LEFT   JOIN ap_invoice_lines_all il
             ON il.invoice_id = i.invoice_id AND il.line_number = 1
    WHERE  i.wfapproval_status IN ('APPROVED', 'NOT REQUIRED')
      AND  i.cancelled_date IS NULL
      AND  i.last_update_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 13. Invoice Posted (gl_date as proxy; posting_status='Y')
    SELECT NVL2(il.po_header_id, 'PO:' || il.po_header_id, 'INV:' || i.invoice_id),
           'INVOICE_POSTED', i.gl_date,
           NVL(i.last_updated_by || '', '?'),
           i.invoice_id, i.invoice_num, i.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = i.vendor_id),
           i.invoice_amount, i.invoice_currency_code, i.posting_status
    FROM   ap_invoices_all i
    LEFT   JOIN ap_invoice_lines_all il
             ON il.invoice_id = i.invoice_id AND il.line_number = 1
    WHERE  i.posting_status = 'Y'
      AND  i.cancelled_date IS NULL
      AND  i.gl_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 14. Payment Issued
    SELECT NVL2(il.po_header_id, 'PO:' || il.po_header_id, 'INV:' || aip.invoice_id),
           'PAYMENT_ISSUED', c.check_date,
           NVL(c.created_by || '', '?'),
           c.check_id, c.check_number, c.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = c.vendor_id),
           c.amount, c.currency_code, c.payment_method_lookup_code
    FROM   ap_checks_all c
    JOIN   ap_invoice_payments_all aip ON aip.check_id = c.check_id
    LEFT   JOIN ap_invoice_lines_all il
             ON il.invoice_id = aip.invoice_id AND il.line_number = 1
    WHERE  c.status_lookup_code NOT IN ('VOIDED','STOP INITIATED')
      AND  c.check_date >= TRUNC(SYSDATE) - {days_back}

    UNION ALL

    -- 15. Payment Cleared
    SELECT NVL2(il.po_header_id, 'PO:' || il.po_header_id, 'INV:' || aip.invoice_id),
           'PAYMENT_CLEARED', c.cleared_date,
           NVL(c.last_updated_by || '', '?'),
           c.check_id, c.check_number, c.vendor_id,
           (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = c.vendor_id),
           c.amount, c.currency_code, c.payment_method_lookup_code
    FROM   ap_checks_all c
    JOIN   ap_invoice_payments_all aip ON aip.check_id = c.check_id
    LEFT   JOIN ap_invoice_lines_all il
             ON il.invoice_id = aip.invoice_id AND il.line_number = 1
    WHERE  c.cleared_date IS NOT NULL
      AND  c.cleared_date >= TRUNC(SYSDATE) - {days_back}
)
ORDER BY case_id, ts
"""


# Conformance issue catalog
CONFORMANCE_ISSUES = {
    "MISSING_PO_APPROVAL":      "Goods received without PO approval",
    "MISSING_RECEIPT":          "Invoice paid without goods receipt",
    "MISSING_VALIDATION":       "Invoice posted without validation event",
    "MISSING_APPROVAL":         "Invoice posted without approval event",
    "PAY_BEFORE_POST":          "Payment issued before invoice posted",
    "PAY_BEFORE_APPROVE":       "Payment issued before invoice approved",
    "EXCESSIVE_REWORK":         "More than 3 holds or 2 PO revisions",
    "MAVERICK":                 "Invoice paid with no PO at all",
}
