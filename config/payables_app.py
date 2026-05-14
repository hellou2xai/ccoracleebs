"""
Oracle EBS Payables Agentic App — dedicated query config.
All queries use {days_back} placeholder (substituted at runtime).
Analytic functions used throughout — no heavy lookup joins.
"""
from typing import Any, Dict, List

PAYABLES_QUERIES = {

    "summary": {
        "label": "AP Summary",
        "sql": """
            SELECT
                COUNT(*)                                                        total_invoices,
                SUM(CASE WHEN posting_status = 'Y' THEN 1 ELSE 0 END)         posted_count,
                SUM(CASE WHEN posting_status = 'N'
                          AND cancelled_date IS NULL THEN 1 ELSE 0 END)         unposted_count,
                SUM(CASE WHEN wfapproval_status NOT IN ('APPROVED','NOT REQUIRED')
                          AND cancelled_date IS NULL THEN 1 ELSE 0 END)         pending_approval,
                ROUND(SUM(invoice_amount), 2)                                   total_amount,
                ROUND(AVG(invoice_amount), 2)                                   avg_invoice_amount,
                COUNT(DISTINCT source)                                           source_count
            FROM ap_invoices_all
            WHERE creation_date >= TRUNC(SYSDATE) - {days_back}
              AND cancelled_date IS NULL
        """,
    },

    "invoice_health": {
        "label": "Invoice Health",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   i.invoice_id, i.invoice_num, i.invoice_date,
                   i.vendor_id, s.vendor_name,
                   i.invoice_amount, i.invoice_currency_code,
                   i.wfapproval_status, i.posting_status, i.source,
                   i.creation_date,
                   ROUND(SYSDATE - i.creation_date, 0)               days_open,
                   COUNT(*) OVER()                                    total_unposted,
                   COUNT(*) OVER (PARTITION BY i.source)              by_source,
                   COUNT(*) OVER (PARTITION BY i.wfapproval_status)   by_approval
            FROM ap_invoices_all i
            JOIN ap_suppliers s ON s.vendor_id = i.vendor_id
            WHERE i.posting_status = 'N'
              AND i.cancelled_date IS NULL
              AND i.creation_date >= TRUNC(SYSDATE) - {days_back}
            ORDER BY i.creation_date DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "holds": {
        "label": "Hold Details",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   h.invoice_id, h.hold_lookup_code, h.hold_reason,
                   h.creation_date                                    hold_date,
                   i.invoice_num, i.invoice_amount, i.invoice_currency_code,
                   i.vendor_id, s.vendor_name, i.source, i.wfapproval_status,
                   ROUND(SYSDATE - h.creation_date, 0)               days_on_hold,
                   COUNT(*) OVER()                                    total_holds,
                   COUNT(*) OVER (PARTITION BY h.hold_lookup_code)   holds_by_type,
                   ROUND(AVG(SYSDATE - h.creation_date) OVER(), 1)   avg_days_on_hold,
                   MAX(ROUND(SYSDATE - h.creation_date, 0)) OVER()   max_days_on_hold
            FROM ap_holds_all h
            JOIN ap_invoices_all i ON h.invoice_id = i.invoice_id
            JOIN ap_suppliers s ON s.vendor_id = i.vendor_id
            WHERE h.release_lookup_code IS NULL
              AND h.creation_date >= TRUNC(SYSDATE) - {days_back}
            ORDER BY h.creation_date
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "approvers": {
        "label": "By Hold Type",
        "sql": """
            SELECT /*+ FIRST_ROWS(30) */
                   h.hold_lookup_code                        hold_type,
                   i.wfapproval_status                       approval_status,
                   COUNT(DISTINCT h.invoice_id)              invoice_count,
                   COUNT(*)                                  hold_count,
                   ROUND(SUM(i.invoice_amount), 2)           total_amount,
                   MIN(ROUND(SYSDATE - h.creation_date, 0))  min_days,
                   MAX(ROUND(SYSDATE - h.creation_date, 0))  max_days,
                   ROUND(AVG(SYSDATE - h.creation_date), 1)  avg_days
            FROM ap_holds_all h
            JOIN ap_invoices_all i ON h.invoice_id = i.invoice_id
            WHERE h.release_lookup_code IS NULL
              AND h.creation_date >= TRUNC(SYSDATE) - {days_back}
            GROUP BY h.hold_lookup_code, i.wfapproval_status
            ORDER BY COUNT(*) DESC
            FETCH FIRST 30 ROWS ONLY
        """,
    },

    "discounts": {
        "label": "Cash Opportunities",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   ps.invoice_id, ps.payment_num,
                   i.invoice_num, s.vendor_name,
                   ps.discount_date,
                   ROUND(ps.discount_amount_remaining, 2)          discount_amount,
                   ROUND(ps.gross_amount, 2)                       gross_amount,
                   i.invoice_currency_code,
                   ROUND(ps.discount_date - SYSDATE, 0)            days_to_discount,
                   CASE
                       WHEN ROUND(ps.discount_date - SYSDATE, 0) <= 3  THEN 'URGENT'
                       WHEN ROUND(ps.discount_date - SYSDATE, 0) <= 7  THEN 'THIS_WEEK'
                       ELSE 'UPCOMING'
                   END                                             urgency,
                   COUNT(*) OVER()                                 total_opportunities,
                   ROUND(SUM(ps.discount_amount_remaining) OVER(), 2) total_discount_available
            FROM ap_payment_schedules_all ps
            JOIN ap_invoices_all i ON i.invoice_id = ps.invoice_id
            JOIN ap_suppliers s ON s.vendor_id = i.vendor_id
            WHERE ps.payment_status_flag = 'N'
              AND ps.discount_date >= TRUNC(SYSDATE)
              AND ps.discount_date <= TRUNC(SYSDATE) + 14
              AND ps.discount_amount_remaining > 0
            ORDER BY ps.discount_date
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    # ── New feature queries ────────────────────────────────────────────────────

    "unapproved_invoices": {
        "label": "Unapproved Invoices",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   i.invoice_id,
                   i.invoice_num,
                   i.invoice_date,
                   i.vendor_id,
                   s.vendor_name,
                   ROUND(i.invoice_amount, 2)                  invoice_amount,
                   i.invoice_currency_code,
                   i.wfapproval_status,
                   i.source,
                   ROUND(SYSDATE - i.creation_date, 0)         days_waiting,
                   (SELECT fu.description
                    FROM   wf_item_activity_statuses wias
                    JOIN   fnd_user fu ON fu.user_name = wias.assigned_user
                    WHERE  wias.item_type       = 'APINV'
                      AND  wias.item_key        = TO_CHAR(i.invoice_id)
                      AND  wias.activity_status = 'NOTIFIED'
                      AND  ROWNUM = 1)                         current_approver,
                   COUNT(*) OVER()                             total_unapproved,
                   ROUND(SUM(i.invoice_amount) OVER(), 2)      total_amount_at_risk,
                   COUNT(*) OVER (PARTITION BY i.wfapproval_status) by_status
            FROM   ap_invoices_all i
            JOIN   ap_suppliers s ON s.vendor_id = i.vendor_id
            WHERE  i.wfapproval_status NOT IN ('APPROVED', 'NOT REQUIRED')
              AND  i.cancelled_date IS NULL
              AND  i.creation_date >= TRUNC(SYSDATE) - {days_back}
            ORDER  BY i.creation_date
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "duplicate_risk": {
        "label": "Duplicate Risk",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   a.invoice_id,
                   a.invoice_num,
                   a.invoice_date,
                   a.vendor_id,
                   s.vendor_name,
                   ROUND(a.invoice_amount, 2)                  invoice_amount,
                   a.invoice_currency_code,
                   b.invoice_id                                dup_invoice_id,
                   b.invoice_num                               dup_invoice_num,
                   b.invoice_date                              dup_invoice_date,
                   ABS(ROUND(a.invoice_date - b.invoice_date, 0)) date_diff_days,
                   COUNT(*) OVER()                             total_dup_pairs
            FROM   ap_invoices_all a
            JOIN   ap_invoices_all b
                     ON  b.vendor_id      = a.vendor_id
                     AND b.invoice_amount = a.invoice_amount
                     AND b.invoice_id     > a.invoice_id
                     AND b.cancelled_date IS NULL
                     AND ABS(a.invoice_date - b.invoice_date) <= 30
            JOIN   ap_suppliers s ON s.vendor_id = a.vendor_id
            WHERE  a.cancelled_date IS NULL
              AND  a.creation_date >= TRUNC(SYSDATE) - {days_back}
            ORDER  BY a.vendor_id, a.invoice_amount DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "non_po_invoices": {
        "label": "Non-PO Invoices",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   i.invoice_id,
                   i.invoice_num,
                   i.invoice_date,
                   i.vendor_id,
                   s.vendor_name,
                   ROUND(i.invoice_amount, 2)                  invoice_amount,
                   i.invoice_currency_code,
                   i.wfapproval_status,
                   i.posting_status,
                   i.source,
                   ROUND(SYSDATE - i.creation_date, 0)         days_old,
                   COUNT(*) OVER()                             total_non_po,
                   ROUND(SUM(i.invoice_amount) OVER(), 2)      total_non_po_amount
            FROM   ap_invoices_all i
            JOIN   ap_suppliers s ON s.vendor_id = i.vendor_id
            WHERE  i.cancelled_date IS NULL
              AND  i.invoice_type_lookup_code NOT IN ('PREPAYMENT', 'CREDIT')
              AND  i.creation_date >= TRUNC(SYSDATE) - {days_back}
              AND  NOT EXISTS (
                       SELECT 1 FROM ap_invoice_lines_all l
                       WHERE  l.invoice_id    = i.invoice_id
                         AND  l.po_header_id  IS NOT NULL
                         AND  l.cancelled_flag = 'N'
                   )
            ORDER  BY i.invoice_amount DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "supplier_aging": {
        "label": "Supplier Aging",
        "sql": """
            SELECT /*+ FIRST_ROWS(50) */
                   s.vendor_id,
                   s.vendor_name,
                   COUNT(DISTINCT ps.invoice_id)                               invoice_count,
                   ROUND(SUM(CASE WHEN SYSDATE - ps.due_date <= 30
                                  THEN ps.amount_remaining ELSE 0 END), 2)     bucket_0_30,
                   ROUND(SUM(CASE WHEN SYSDATE - ps.due_date BETWEEN 31 AND 60
                                  THEN ps.amount_remaining ELSE 0 END), 2)     bucket_31_60,
                   ROUND(SUM(CASE WHEN SYSDATE - ps.due_date BETWEEN 61 AND 90
                                  THEN ps.amount_remaining ELSE 0 END), 2)     bucket_61_90,
                   ROUND(SUM(CASE WHEN SYSDATE - ps.due_date > 90
                                  THEN ps.amount_remaining ELSE 0 END), 2)     bucket_over_90,
                   ROUND(SUM(ps.amount_remaining), 2)                          total_outstanding
            FROM   ap_payment_schedules_all ps
            JOIN   ap_invoices_all i ON i.invoice_id = ps.invoice_id
            JOIN   ap_suppliers s   ON s.vendor_id   = i.vendor_id
            WHERE  ps.payment_status_flag = 'N'
              AND  i.cancelled_date IS NULL
            GROUP  BY s.vendor_id, s.vendor_name
            ORDER  BY total_outstanding DESC
            FETCH FIRST 50 ROWS ONLY
        """,
    },

    "match_exceptions": {
        "label": "Match Exceptions",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   h.invoice_id,
                   h.hold_lookup_code                               hold_type,
                   h.hold_reason,
                   ROUND(SYSDATE - h.creation_date, 0)             days_on_hold,
                   i.invoice_num,
                   i.invoice_date,
                   i.vendor_id,
                   s.vendor_name,
                   ROUND(i.invoice_amount, 2)                      invoice_amount,
                   i.invoice_currency_code,
                   i.source,
                   COUNT(*) OVER()                                 total_exceptions,
                   COUNT(*) OVER (PARTITION BY h.hold_lookup_code) by_hold_type
            FROM   ap_holds_all h
            JOIN   ap_invoices_all i ON i.invoice_id = h.invoice_id
            JOIN   ap_suppliers s   ON s.vendor_id   = i.vendor_id
            WHERE  h.release_lookup_code IS NULL
              AND  h.hold_lookup_code IN (
                       'PRICE','QTY ORDERED','QTY RECEIVED',
                       'AMOUNT ORDERED','VARIANCE',
                       'MAX QTY ORD','MAX QTY REC','MAX AMOUNT'
                   )
              AND  h.creation_date >= TRUNC(SYSDATE) - {days_back}
            ORDER  BY days_on_hold DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "cycle_time": {
        "label": "Cycle Time",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   i.invoice_id,
                   i.invoice_num,
                   i.invoice_date,
                   s.vendor_name,
                   ROUND(i.invoice_amount, 2)                          invoice_amount,
                   i.invoice_currency_code,
                   i.source,
                   TRUNC(i.creation_date)                              received_date,
                   i.gl_date                                           posting_date,
                   ROUND(i.gl_date - i.creation_date, 0)              cycle_days,
                   CASE
                       WHEN ROUND(i.gl_date - i.creation_date, 0) <= 3  THEN 'FAST'
                       WHEN ROUND(i.gl_date - i.creation_date, 0) <= 7  THEN 'NORMAL'
                       WHEN ROUND(i.gl_date - i.creation_date, 0) <= 14 THEN 'SLOW'
                       ELSE 'CRITICAL'
                   END                                                 cycle_band,
                   ROUND(AVG(i.gl_date - i.creation_date) OVER(), 1)  avg_cycle_days,
                   COUNT(*) OVER()                                     total_posted
            FROM   ap_invoices_all i
            JOIN   ap_suppliers s ON s.vendor_id = i.vendor_id
            WHERE  i.posting_status  = 'Y'
              AND  i.cancelled_date  IS NULL
              AND  i.gl_date         IS NOT NULL
              AND  i.creation_date   >= TRUNC(SYSDATE) - {days_back}
            ORDER  BY cycle_days DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "open_prepayments": {
        "label": "Open Prepayments",
        "sql": """
            SELECT /*+ FIRST_ROWS(100) */
                   i.invoice_id,
                   i.invoice_num,
                   i.invoice_date,
                   i.vendor_id,
                   s.vendor_name,
                   ROUND(i.invoice_amount, 2)                              prepayment_amount,
                   i.invoice_currency_code,
                   ROUND(NVL(i.amount_applicable_to_discount, i.invoice_amount), 2) unapplied_amount,
                   ROUND(SYSDATE - i.invoice_date, 0)                      days_outstanding,
                   i.wfapproval_status,
                   COUNT(*) OVER()                                         total_open_prepay,
                   ROUND(SUM(i.invoice_amount) OVER(), 2)                  total_prepay_amount
            FROM   ap_invoices_all i
            JOIN   ap_suppliers s ON s.vendor_id = i.vendor_id
            WHERE  i.invoice_type_lookup_code = 'PREPAYMENT'
              AND  i.cancelled_date IS NULL
              AND  NVL(i.amount_applicable_to_discount, i.invoice_amount) > 0
              AND  i.creation_date >= TRUNC(SYSDATE) - {days_back}
            ORDER  BY days_outstanding DESC
            FETCH FIRST 100 ROWS ONLY
        """,
    },

    "approval_bottleneck": {
        "label": "Approval Bottleneck",
        "sql": """
            SELECT /*+ FIRST_ROWS(30) */
                   fu.user_name                                       approver,
                   fu.description                                     approver_name,
                   COUNT(DISTINCT wias.item_key)                      pending_count,
                   ROUND(AVG(SYSDATE - NVL(wias.begin_date, SYSDATE - 1)), 1) avg_days_waiting,
                   MAX(ROUND(SYSDATE - NVL(wias.begin_date, SYSDATE - 1), 0)) max_days_waiting,
                   ROUND(SUM(i.invoice_amount), 2)                    total_amount_pending
            FROM   wf_item_activity_statuses wias
            JOIN   fnd_user fu
                     ON  fu.user_name  = wias.assigned_user
                     AND fu.end_date   IS NULL
            JOIN   ap_invoices_all i
                     ON  i.invoice_num    = wias.item_key
                     AND i.cancelled_date IS NULL
            WHERE  wias.activity_status = 'NOTIFIED'
              AND  wias.item_type       = 'APINV'
              AND  wias.begin_date     >= TRUNC(SYSDATE) - {days_back}
            GROUP  BY fu.user_name, fu.description
            ORDER  BY pending_count DESC
            FETCH FIRST 30 ROWS ONLY
        """,
    },

}

# ─── Hold type → action recommendation mapping ────────────────────────────────

HOLD_ACTIONS = {
    'PRICE':            {'owner': 'Buyer',       'action': 'Compare invoice unit price to PO line price. Contact buyer to update PO or request credit memo.'},
    'QTY ORDERED':      {'owner': 'Buyer',       'action': 'Invoice qty exceeds PO qty. Buyer must issue a PO amendment or supplier must issue partial invoice.'},
    'QTY RECEIVED':     {'owner': 'Receiving',   'action': 'Invoice qty exceeds received qty. Verify receipt in Inventory — goods may not have been processed.'},
    'AMOUNT ORDERED':   {'owner': 'Buyer',       'action': 'Invoice amount exceeds PO amount. PO amendment required from buyer.'},
    'VARIANCE':         {'owner': 'AP Manager',  'action': 'Amount variance beyond tolerance. Review and approve manually or request corrected invoice.'},
    'ACCOUNT':          {'owner': 'AP Manager',  'action': 'Distribution account is invalid or inactive. Update account coding and revalidate.'},
    'FUNDS':            {'owner': 'Budget Mgr',  'action': 'Budget check failed. Request budget override or recharge to funded account.'},
    'MANUAL':           {'owner': 'AP Clerk',    'action': 'Manual hold. Release hold in AP once issue is resolved.'},
    'TAX':              {'owner': 'Tax Team',     'action': 'Tax calculation error. Review tax lines and correct or contact tax team.'},
    'DUPLICATE':        {'owner': 'AP Clerk',    'action': 'Potential duplicate invoice. Verify against existing invoices before releasing.'},
}

def get_hold_action(hold_type: str) -> dict:
    """Return action recommendation for a hold type."""
    key = (hold_type or '').upper().replace('_', ' ')
    for k, v in HOLD_ACTIONS.items():
        if k in key or key in k:
            return v
    return {'owner': 'AP Team', 'action': 'Review hold reason and contact appropriate team to resolve.'}


# ─── KPI computation ──────────────────────────────────────────────────────────

def compute_kpis(results: dict) -> dict:
    kpis = {
        "stp_rate": None,
        "hold_rate": None,
        "avg_days_on_hold": None,
        "discount_at_risk": 0.0,
        "total_invoices": 0,
        "unposted_count": 0,
        "hold_count": 0,
        "discount_count": 0,
        "total_amount": 0.0,
        "pending_approval": 0,
    }

    # From summary (aggregate row)
    summary_rows = results.get("summary", {}).get("rows", [])
    if summary_rows:
        row = summary_rows[0]
        total    = int(row.get("total_invoices") or 0)
        unposted = int(row.get("unposted_count") or 0)
        pending  = int(row.get("pending_approval") or 0)
        kpis["total_invoices"]   = total
        kpis["unposted_count"]   = unposted
        kpis["pending_approval"] = pending
        kpis["total_amount"]     = float(row.get("total_amount") or 0)
        if total > 0:
            kpis["stp_rate"] = round((total - unposted) / total * 100, 1)

    # From holds (detail rows with analytics)
    hold_rows = results.get("holds", {}).get("rows", [])
    hold_count = len(hold_rows)
    kpis["hold_count"] = hold_count
    if hold_count > 0:
        first = hold_rows[0]
        avg = first.get("avg_days_on_hold")
        if avg is not None:
            kpis["avg_days_on_hold"] = round(float(avg), 1)
    total = kpis["total_invoices"]
    if total > 0 and hold_count > 0:
        kpis["hold_rate"] = round(hold_count / total * 100, 1)

    # From discounts
    disc_rows = results.get("discounts", {}).get("rows", [])
    kpis["discount_count"] = len(disc_rows)
    if disc_rows:
        first = disc_rows[0]
        total_disc = first.get("total_discount_available")
        if total_disc is not None:
            kpis["discount_at_risk"] = float(total_disc)

    return kpis


# ─── Findings computation ─────────────────────────────────────────────────────

def compute_findings(kpis: dict, results: dict) -> list:
    findings = []

    unposted = kpis["unposted_count"]
    hold_count = kpis["hold_count"]
    stp_rate = kpis["stp_rate"]
    discount = kpis["discount_at_risk"]
    disc_count = kpis["discount_count"]

    if unposted > 50:
        findings.append({"severity": "CRITICAL", "category": "Unposted Invoices",
                          "count": unposted, "description": f"{unposted} invoices unposted — period close at risk"})
    elif unposted > 10:
        findings.append({"severity": "HIGH", "category": "Unposted Invoices",
                          "count": unposted, "description": f"{unposted} unposted invoices require attention"})
    elif unposted > 0:
        findings.append({"severity": "MEDIUM", "category": "Unposted Invoices",
                          "count": unposted, "description": f"{unposted} unposted invoices found"})

    if stp_rate is not None:
        if stp_rate < 70:
            findings.append({"severity": "HIGH", "category": "STP Rate",
                              "count": kpis["total_invoices"],
                              "description": f"STP rate {stp_rate}% — below 70% critical threshold"})
        elif stp_rate < 85:
            findings.append({"severity": "MEDIUM", "category": "STP Rate",
                              "count": kpis["total_invoices"],
                              "description": f"STP rate {stp_rate}% — below 85% target"})

    if hold_count > 20:
        findings.append({"severity": "CRITICAL", "category": "Invoices On Hold",
                          "count": hold_count, "description": f"{hold_count} invoices on hold — STP rate impacted"})
    elif hold_count > 5:
        findings.append({"severity": "HIGH", "category": "Invoices On Hold",
                          "count": hold_count, "description": f"{hold_count} invoices on hold"})
    elif hold_count > 0:
        findings.append({"severity": "MEDIUM", "category": "Invoices On Hold",
                          "count": hold_count, "description": f"{hold_count} invoices currently on hold"})

    if discount > 10000:
        findings.append({"severity": "HIGH", "category": "Discount Opportunity",
                          "count": disc_count,
                          "description": f"${discount:,.0f} early pay discounts expiring within 14 days"})
    elif discount > 0:
        findings.append({"severity": "INFO", "category": "Discount Opportunity",
                          "count": disc_count,
                          "description": f"${discount:,.2f} in early pay discounts available"})

    return findings


# ─── Demo data ────────────────────────────────────────────────────────────────

DEMO_KPIS = {
    "stp_rate": 78.3,
    "hold_rate": 8.2,
    "avg_days_on_hold": 5.4,
    "discount_at_risk": 24300.00,
    "total_invoices": 145,
    "unposted_count": 32,
    "hold_count": 12,
    "discount_count": 18,
    "total_amount": 2345678.90,
    "pending_approval": 8,
}

DEMO_FINDINGS = [
    {"severity": "HIGH", "category": "Unposted Invoices", "count": 32,
     "description": "32 invoices unposted — 24 EDI, 8 manual entry"},
    {"severity": "HIGH", "category": "STP Rate", "count": 145,
     "description": "STP rate 78.3% — below 85% target"},
    {"severity": "MEDIUM", "category": "Invoices On Hold", "count": 12,
     "description": "12 invoices on hold (7 Price Hold, 3 Qty Hold, 2 Account Hold)"},
    {"severity": "HIGH", "category": "Discount Opportunity", "count": 18,
     "description": "$24,300 early pay discounts expiring this week"},
]
