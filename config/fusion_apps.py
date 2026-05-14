"""
Oracle EBS Agentic Applications Registry.
Queries are optimised for speed:
  - FIRST_ROWS hint so Oracle returns rows immediately
  - Equality conditions on indexed columns (posting_status = 'N', not != 'Y')
  - No joins to large lookup tables (ap_suppliers, hz_parties, etc.)
  - {days_back} placeholder — substituted at runtime from user input (default 30)
  - ROWNUM <= N applied BEFORE ORDER BY via subquery
  - COUNT(*) OVER() analytic column gives total-in-window alongside paged rows
  - All queries respect the 30-second call_timeout in OracleDB.execute_query
"""

from typing import Any, Dict, List

# ─── App Query Definitions ────────────────────────────────────────────────────

FUSION_APPS: Dict[str, Dict[str, Any]] = {

    # ── FINANCE ──────────────────────────────────────────────────────────────

    "payables": {
        "id": "payables",
        "name": "Payables Agentic App",
        "pillar": "FINANCE",
        "icon": "fa-file-invoice-dollar",
        "tagline": "Invoice ingestion, PO matching, fraud detection, straight-through processing",
        "kpis": ["STP Rate", "Invoice Cycle Time", "Hold Rate", "Match Rate"],
        "queries": [
            {
                "id": "unposted_invoices",
                "label": "Unposted / Unvalidated Invoices",
                # Analytic: COUNT(*) OVER() gives total count without a second query
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           invoice_id, invoice_num, invoice_date,
                           vendor_id, invoice_amount, currency_code,
                           wfapproval_status, posting_status,
                           source, creation_date,
                           COUNT(*) OVER() total_in_window
                    FROM ap_invoices_all
                    WHERE posting_status = 'N'
                      AND cancelled_date IS NULL
                      AND creation_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY creation_date DESC
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 50, "severity": "CRITICAL",
                     "message": "{count} unposted invoices — period close at risk"},
                    {"field": "count", "op": ">", "value": 10, "severity": "HIGH",
                     "message": "{count} unposted invoices require attention"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} unposted invoices found"},
                ],
            },
            {
                "id": "invoices_on_hold",
                "label": "Invoices On Hold",
                # PK join only; ap_holds_all is small — COUNT(*) OVER() adds total context
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           h.invoice_id, h.hold_lookup_code, h.hold_reason,
                           h.creation_date hold_date,
                           i.invoice_num, i.invoice_amount, i.currency_code,
                           i.vendor_id,
                           ROUND(SYSDATE - h.creation_date, 0) days_on_hold,
                           COUNT(*) OVER() total_on_hold
                    FROM ap_holds_all h
                    JOIN ap_invoices_all i ON h.invoice_id = i.invoice_id
                    WHERE h.release_lookup_code IS NULL
                      AND h.creation_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY h.creation_date
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 20, "severity": "CRITICAL",
                     "message": "{count} invoices on hold — STP rate impacted"},
                    {"field": "count", "op": ">", "value": 5, "severity": "HIGH",
                     "message": "{count} invoices on hold"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} invoices currently on hold"},
                ],
            },
            {
                "id": "ap_summary",
                "label": "AP Summary — Current Period",
                # Aggregate only — no row scans, uses partition stats
                "sql": """
                    SELECT /*+ FIRST_ROWS(10) */
                           posting_status,
                           wfapproval_status,
                           source,
                           COUNT(*)          invoice_count,
                           SUM(invoice_amount) total_amount,
                           MIN(invoice_date) oldest_invoice
                    FROM ap_invoices_all
                    WHERE creation_date >= TRUNC(SYSDATE,'MM')
                      AND cancelled_date IS NULL
                    GROUP BY posting_status, wfapproval_status, source
                    ORDER BY COUNT(*) DESC
                    FETCH FIRST 20 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 0, "severity": "INFO",
                     "message": "AP current-period summary loaded ({count} status groups)"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "CRITICAL", "category": "Unposted Invoices", "count": 45,
             "description": "45 invoices unposted in current period — period close blocked"},
            {"severity": "HIGH", "category": "Invoices On Hold", "count": 12,
             "description": "12 invoices on hold (7 Price Hold, 3 Qty Received Hold, 2 Acct Hold)"},
            {"severity": "MEDIUM", "category": "AP Summary", "count": 8,
             "description": "8 PO lines with match exceptions requiring review"},
        ],
    },

    "collectors": {
        "id": "collectors",
        "name": "Collectors Workspace",
        "pillar": "FINANCE",
        "icon": "fa-hand-holding-dollar",
        "tagline": "DSO reduction, promise-to-pay, overdue receivables, cash flow",
        "kpis": ["DSO", "Overdue AR Balance", "Promise-to-Pay %", "Collection Efficiency"],
        "queries": [
            {
                "id": "overdue_aging",
                "label": "Overdue Receivables — Aging Summary",
                # Analytic: aging buckets with SUM OVER() for total overdue
                "sql": """
                    SELECT /*+ FIRST_ROWS(10) */
                        CASE
                            WHEN TRUNC(SYSDATE) - due_date BETWEEN 1  AND 30 THEN '1-30 days'
                            WHEN TRUNC(SYSDATE) - due_date BETWEEN 31 AND 60 THEN '31-60 days'
                            WHEN TRUNC(SYSDATE) - due_date BETWEEN 61 AND 90 THEN '61-90 days'
                            ELSE '90+ days'
                        END aging_bucket,
                        COUNT(*)                       invoice_count,
                        SUM(amount_due_remaining)      amount_overdue,
                        invoice_currency_code          currency
                    FROM ar_payment_schedules_all
                    WHERE status = 'OP'
                      AND due_date < TRUNC(SYSDATE)
                      AND amount_due_remaining > 0
                    GROUP BY
                        CASE
                            WHEN TRUNC(SYSDATE) - due_date BETWEEN 1  AND 30 THEN '1-30 days'
                            WHEN TRUNC(SYSDATE) - due_date BETWEEN 31 AND 60 THEN '31-60 days'
                            WHEN TRUNC(SYSDATE) - due_date BETWEEN 61 AND 90 THEN '61-90 days'
                            ELSE '90+ days'
                        END,
                        invoice_currency_code
                    ORDER BY MIN(due_date)
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 0, "severity": "HIGH",
                     "message": "Overdue receivables across {count} aging buckets"},
                ],
            },
            {
                "id": "unapplied_receipts",
                "label": "Unapplied Cash Receipts",
                # Analytic: COUNT(*) OVER() gives total unapplied alongside rows
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           cash_receipt_id, receipt_number,
                           receipt_date, amount, currency_code, status,
                           pay_from_customer,
                           ROUND(SYSDATE - receipt_date, 0) days_unapplied,
                           COUNT(*) OVER()       total_unapplied,
                           SUM(amount) OVER()    total_amount
                    FROM ar_cash_receipts_all
                    WHERE status = 'UNAPP'
                      AND receipt_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY receipt_date
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 20, "severity": "CRITICAL",
                     "message": "{count} unapplied receipts — cash not applied to customer accounts"},
                    {"field": "count", "op": ">", "value": 5, "severity": "HIGH",
                     "message": "{count} unapplied receipts"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "HIGH", "category": "Overdue AR", "count": 4,
             "description": "AR aging: 1-30d: $234K, 31-60d: $89K, 61-90d: $45K, 90+d: $12K"},
            {"severity": "CRITICAL", "category": "Unapplied Receipts", "count": 18,
             "description": "18 unapplied cash receipts totaling $312,450 — DSO impact"},
        ],
    },

    "payments": {
        "id": "payments",
        "name": "Payments Optimization App",
        "pillar": "FINANCE",
        "icon": "fa-credit-card",
        "tagline": "Early pay discounts, payment batches, working capital KPIs",
        "kpis": ["Discount Capture %", "On-Time Payment %", "Payment Batch Status"],
        "queries": [
            {
                "id": "payment_batches",
                "label": "Active Payment Batches",
                # Small table, no joins; analytic total for context
                "sql": """
                    SELECT /*+ FIRST_ROWS(50) */
                           checkrun_id, checkrun_name, status,
                           NVL(vendor_pay_group,'STANDARD') pay_group,
                           check_date, creation_date, currency_code,
                           COUNT(*) OVER() total_active_batches
                    FROM ap_inv_selection_criteria_all
                    WHERE status NOT IN ('CONFIRMED','CANCELLED')
                      AND creation_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY creation_date DESC
                    FETCH FIRST 50 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 5, "severity": "HIGH",
                     "message": "{count} unconfirmed payment batches pending confirmation"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} payment batches awaiting confirmation"},
                ],
            },
            {
                "id": "discount_opportunities",
                "label": "Early Pay Discount Opportunities",
                # Look-ahead fixed at 14 days; analytic sum for total discount available
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           invoice_id, payment_num,
                           discount_date, discount_amount_remaining,
                           gross_amount, currency_code,
                           ROUND(discount_date - SYSDATE, 0) days_to_discount,
                           COUNT(*) OVER()                    total_opportunities,
                           SUM(discount_amount_remaining) OVER() total_discount_available
                    FROM ap_payment_schedules_all
                    WHERE payment_status_flag = 'N'
                      AND discount_date >= TRUNC(SYSDATE)
                      AND discount_date <= TRUNC(SYSDATE) + 14
                      AND discount_amount_remaining > 0
                    ORDER BY discount_date
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 0, "severity": "INFO",
                     "message": "{count} invoices with early pay discounts expiring within 14 days"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "MEDIUM", "category": "Payment Batches", "count": 3,
             "description": "3 payment batches pending confirmation (USD 225K, EUR 88K, GBP 12K)"},
            {"severity": "INFO", "category": "Discount Opportunities", "count": 24,
             "description": "24 invoices with early pay discounts available"},
        ],
    },

    "ledger": {
        "id": "ledger",
        "name": "Ledger Monitoring App",
        "pillar": "FINANCE",
        "icon": "fa-book",
        "tagline": "GL health, unposted journals, open periods, SLA errors, balance anomalies",
        "kpis": ["Unposted Journals", "Open Periods", "SLA Errors", "Period Close Status"],
        "queries": [
            {
                "id": "unposted_journals",
                "label": "Unposted GL Journals",
                # status='U' + actual_flag='A' both indexed; analytic total for context
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           je_header_id, name, je_source, je_category,
                           period_name, ledger_id, status,
                           running_total_dr, running_total_cr,
                           creation_date, created_by,
                           COUNT(*) OVER() total_unposted
                    FROM gl_je_headers
                    WHERE status = 'U'
                      AND actual_flag = 'A'
                      AND creation_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY creation_date DESC
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 10, "severity": "CRITICAL",
                     "message": "{count} unposted journals — GL balances incomplete"},
                    {"field": "count", "op": ">", "value": 3, "severity": "HIGH",
                     "message": "{count} unposted journals found"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} unposted journals"},
                ],
            },
            {
                "id": "open_periods",
                "label": "GL Period Status",
                # Small metadata tables; join on period_name PK is fast
                "sql": """
                    SELECT /*+ FIRST_ROWS(30) */
                           ps.period_name, ps.closing_status,
                           ps.ledger_id,
                           p.start_date, p.end_date,
                           ROUND(SYSDATE - p.end_date, 0) days_past_end
                    FROM gl_period_statuses ps
                    JOIN gl_periods p ON ps.period_name = p.period_name
                      AND ps.period_type = p.period_type
                    WHERE ps.closing_status IN ('O','F')
                      AND p.end_date < SYSDATE - 5
                    ORDER BY p.end_date
                    FETCH FIRST 30 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 3, "severity": "HIGH",
                     "message": "{count} periods past end date still open"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} periods still open past end date"},
                ],
            },
            {
                "id": "sla_errors",
                "label": "SLA Transfer Errors",
                # process_status_code index + creation_date; analytic total for context
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           event_id, event_type_code, event_date,
                           process_status_code, entity_code,
                           source_id_int_1, application_id, creation_date,
                           COUNT(*) OVER() total_sla_errors
                    FROM xla_events
                    WHERE process_status_code IN ('I','E')
                      AND creation_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY creation_date DESC
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 5, "severity": "CRITICAL",
                     "message": "{count} SLA transfer errors — GL/subledger out of sync"},
                    {"field": "count", "op": ">", "value": 0, "severity": "HIGH",
                     "message": "{count} SLA events failed to transfer"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "CRITICAL", "category": "Unposted Journals", "count": 4,
             "description": "4 unposted journals in MAR-2026 — period close blocked"},
            {"severity": "HIGH", "category": "Open Periods", "count": 2,
             "description": "DEC-2025 and JAN-2026 still OPEN past end date"},
            {"severity": "HIGH", "category": "SLA Errors", "count": 7,
             "description": "7 XLA events failed — AP and AR subledger transfers pending"},
        ],
    },

    "fin_planning": {
        "id": "fin_planning",
        "name": "Financial Planning App",
        "pillar": "FINANCE",
        "icon": "fa-chart-bar",
        "tagline": "Budget vs actuals, GL balance analysis, variance detection",
        "kpis": ["Budget Variance", "Forecast Accuracy", "Period Close Readiness"],
        "queries": [
            {
                "id": "gl_balances_summary",
                "label": "GL Account Balance — Current Month",
                # Filter by period_year + period_name + actual_flag (all indexed in gl_balances)
                # Analytic: RANK to surface top variances
                "sql": """
                    SELECT /*+ FIRST_ROWS(200) */
                           ledger_id, period_name,
                           code_combination_id,
                           NVL(period_net_dr,0)    period_dr,
                           NVL(period_net_cr,0)    period_cr,
                           NVL(period_net_dr,0) - NVL(period_net_cr,0) net_activity,
                           RANK() OVER (ORDER BY ABS(NVL(period_net_dr,0) - NVL(period_net_cr,0)) DESC) variance_rank,
                           COUNT(*) OVER()          total_active_accounts
                    FROM gl_balances
                    WHERE actual_flag = 'A'
                      AND period_year = TO_NUMBER(TO_CHAR(SYSDATE,'YYYY'))
                      AND period_name = TO_CHAR(SYSDATE,'MON-RRRR')
                      AND (NVL(period_net_dr,0) + NVL(period_net_cr,0)) <> 0
                    ORDER BY variance_rank
                    FETCH FIRST 200 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 0, "severity": "INFO",
                     "message": "{count} GL accounts with activity in current period"},
                ],
            },
            {
                "id": "period_status_last12",
                "label": "Period Status — Last 12 Months",
                # Small metadata table; join on PK
                "sql": """
                    SELECT /*+ FIRST_ROWS(24) */
                           ps.period_name, ps.closing_status,
                           ps.ledger_id,
                           p.start_date, p.end_date
                    FROM gl_period_statuses ps
                    JOIN gl_periods p ON ps.period_name = p.period_name
                      AND ps.period_type = p.period_type
                    WHERE ps.closing_status IN ('O','F','C')
                      AND p.period_year >= TO_NUMBER(TO_CHAR(SYSDATE,'YYYY')) - 1
                    ORDER BY p.period_year DESC, p.period_num DESC
                    FETCH FIRST 24 ROWS ONLY
                """,
                "severity_rules": [],
            },
        ],
        "demo_findings": [
            {"severity": "INFO", "category": "GL Balances", "count": 142,
             "description": "142 GL accounts with activity in current period"},
            {"severity": "MEDIUM", "category": "Period Status", "count": 3,
             "description": "3 periods in FUTURE status — budget not yet open"},
        ],
    },

    # ── SCM EXECUTION ─────────────────────────────────────────────────────────

    "design_to_source": {
        "id": "design_to_source",
        "name": "Design-to-Source Workspace",
        "pillar": "SCM",
        "icon": "fa-drafting-compass",
        "tagline": "Engineering changes, BOM revisions, supplier qualification pipeline",
        "kpis": ["ECO Cycle Time", "Pending ECOs", "Supplier Qualification Rate"],
        "queries": [
            {
                "id": "pending_ecos",
                "label": "Open Engineering Change Orders",
                # Analytic: days_open ranked to surface oldest ECOs first
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           change_notice, change_name, status_code,
                           initiation_date, scheduled_date,
                           ROUND(SYSDATE - initiation_date, 0) days_open,
                           RANK() OVER (ORDER BY initiation_date) age_rank,
                           COUNT(*) OVER() total_open_ecos
                    FROM eng_engineering_changes
                    WHERE status_code NOT IN ('IMPLEMENTED','CANCELLED')
                      AND initiation_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY initiation_date
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 20, "severity": "HIGH",
                     "message": "{count} ECOs pending implementation"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} open engineering change orders"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "HIGH", "category": "Pending ECOs", "count": 14,
             "description": "14 open ECOs — avg 23 days open, 3 past scheduled implementation date"},
        ],
    },

    "quote_to_pr": {
        "id": "quote_to_pr",
        "name": "Quote to Purchase Requisition",
        "pillar": "SCM",
        "icon": "fa-envelope-open-text",
        "tagline": "Open requisitions, PO approval status, supplier response pipeline",
        "kpis": ["Open Requisitions", "PO Approval Cycle", "Supplier Response Rate"],
        "queries": [
            {
                "id": "open_requisitions",
                "label": "Open Purchase Requisitions",
                # Equality on authorization_status (indexed) + analytic count
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           requisition_header_id, segment1 req_number,
                           type_lookup_code, authorization_status,
                           preparer_id, creation_date,
                           ROUND(SYSDATE - creation_date, 0) days_open,
                           COUNT(*) OVER() total_open_reqs,
                           MAX(ROUND(SYSDATE - creation_date, 0)) OVER() max_days_open
                    FROM po_requisition_headers_all
                    WHERE authorization_status IN ('INCOMPLETE','IN PROCESS','PRE-APPROVED')
                      AND creation_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY creation_date
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 30, "severity": "HIGH",
                     "message": "{count} open requisitions awaiting approval"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} purchase requisitions in approval queue"},
                ],
            },
            {
                "id": "unapproved_pos",
                "label": "Purchase Orders Awaiting Approval",
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           po_header_id, segment1 po_number,
                           type_lookup_code, authorization_status,
                           vendor_id, currency_code, creation_date,
                           ROUND(SYSDATE - creation_date, 0) days_open,
                           COUNT(*) OVER() total_pending_pos
                    FROM po_headers_all
                    WHERE authorization_status IN ('INCOMPLETE','IN PROCESS','PRE-APPROVED')
                      AND creation_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY creation_date
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 10, "severity": "HIGH",
                     "message": "{count} POs stuck in approval — procurement blocked"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} POs pending approval"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "HIGH", "category": "Open Requisitions", "count": 28,
             "description": "28 requisitions awaiting approval, oldest 17 days"},
            {"severity": "MEDIUM", "category": "PO Approvals", "count": 9,
             "description": "9 POs pending approval — blocking supplier orders"},
        ],
    },

    "fulfillment": {
        "id": "fulfillment",
        "name": "Fulfillment Processing App",
        "pillar": "SCM",
        "icon": "fa-boxes-packing",
        "tagline": "Shipping exceptions, delivery status, warehouse pick performance, stuck inventory transactions",
        "kpis": ["On-Time Ship %", "Shipping Exceptions", "Pick Completion Rate", "Stuck INV Txns"],
        "queries": [
            {
                "id": "stuck_inv_transactions",
                "label": "Stuck Inventory Transactions (MTL_TRANSACTIONS_INTERFACE)",
                # process_flag=3 means error. No date filter: stuck txns are
                # by definition stuck regardless of when they entered.
                "sql": """
                    SELECT /*+ FIRST_ROWS(50) */
                           mi.transaction_interface_id,
                           mi.source_code,
                           mi.organization_id,
                           mi.inventory_item_id,
                           mi.transaction_type_id,
                           mi.transaction_quantity,
                           mi.error_code,
                           mi.error_explanation,
                           mi.creation_date,
                           ROUND(SYSDATE - mi.creation_date, 0) days_stuck,
                           COUNT(*) OVER() total_stuck
                    FROM inv.mtl_transactions_interface mi
                    WHERE mi.process_flag = 3
                    ORDER BY mi.creation_date DESC
                    FETCH FIRST 50 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 10, "severity": "CRITICAL",
                     "message": "{count} stuck inventory transactions blocking ship confirms"},
                    {"field": "count", "op": ">", "value": 0, "severity": "HIGH",
                     "message": "{count} stuck inventory transactions in MTL_TRANSACTIONS_INTERFACE"},
                ],
            },
            {
                "id": "shipping_exceptions",
                "label": "Past-Due Shipping Lines",
                # released_status equality (indexed); analytic: oldest late line
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           delivery_detail_id, source_line_id,
                           released_status, organization_id,
                           requested_quantity, inventory_item_id,
                           date_scheduled,
                           ROUND(SYSDATE - date_scheduled, 0) days_late,
                           COUNT(*) OVER()                      total_late_lines,
                           MAX(ROUND(SYSDATE - date_scheduled, 0)) OVER() max_days_late
                    FROM wsh_delivery_details
                    WHERE released_status IN ('B','S','Y')
                      AND date_scheduled < TRUNC(SYSDATE)
                      AND date_scheduled >= TRUNC(SYSDATE) - {days_back}
                      AND source_code = 'OE'
                    ORDER BY date_scheduled
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 20, "severity": "CRITICAL",
                     "message": "{count} past-due shipping lines — customer orders at risk"},
                    {"field": "count", "op": ">", "value": 5, "severity": "HIGH",
                     "message": "{count} shipping lines past scheduled date"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "CRITICAL", "category": "Shipping Exceptions", "count": 23,
             "description": "23 order lines past scheduled ship date — customer SLA at risk"},
        ],
    },

    "sales_order": {
        "id": "sales_order",
        "name": "Sales Order Assistant App",
        "pillar": "SCM",
        "icon": "fa-cart-shopping",
        "tagline": "Stuck orders, workflow errors, order hold management",
        "kpis": ["Stuck Orders", "Orders on Hold", "Booking Rate", "Workflow Health"],
        "queries": [
            {
                "id": "orders_on_hold",
                "label": "Orders Currently On Hold",
                # PK join oe_order_holds_all → oe_order_headers_all; analytic total
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           oh.header_id, h.order_number,
                           oh.hold_source_id,
                           h.flow_status_code,
                           oh.creation_date hold_date,
                           ROUND(SYSDATE - oh.creation_date, 0) days_on_hold,
                           COUNT(*) OVER() total_on_hold,
                           MAX(ROUND(SYSDATE - oh.creation_date, 0)) OVER() max_days_on_hold
                    FROM oe_order_holds_all oh
                    JOIN oe_order_headers_all h ON oh.header_id = h.header_id
                    WHERE oh.released_flag = 'N'
                      AND oh.creation_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY oh.creation_date
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 20, "severity": "HIGH",
                     "message": "{count} orders on hold — revenue at risk"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} orders currently on hold"},
                ],
            },
            {
                "id": "wf_order_errors",
                "label": "Sales Order Workflow Errors",
                # wf_item_activity_statuses with item_type IN + status = 'ERROR' (indexed)
                "sql": """
                    SELECT /*+ FIRST_ROWS(50) */
                           item_type, item_key,
                           activity_status, activity_result_code,
                           error_name, begin_date,
                           ROUND((SYSDATE - begin_date) * 24, 1) hours_stuck,
                           COUNT(*) OVER() total_wf_errors
                    FROM wf_item_activity_statuses
                    WHERE item_type IN ('OEOL','OEOH','OEBH')
                      AND activity_status = 'ERROR'
                      AND begin_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY begin_date
                    FETCH FIRST 50 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 5, "severity": "CRITICAL",
                     "message": "{count} order workflow errors requiring immediate attention"},
                    {"field": "count", "op": ">", "value": 0, "severity": "HIGH",
                     "message": "{count} order lines with workflow errors"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "CRITICAL", "category": "Stuck Orders", "count": 8,
             "description": "8 sales orders stuck in workflow (BOOKING/SCHEDULING)"},
            {"severity": "HIGH", "category": "Orders On Hold", "count": 34,
             "description": "34 orders on hold: 21 Credit, 8 Customer, 5 Manual"},
        ],
    },

    "cycle_count": {
        "id": "cycle_count",
        "name": "Cycle Count Analysis App",
        "pillar": "SCM",
        "icon": "fa-barcode",
        "tagline": "Inventory discrepancies, count results, accuracy by location",
        "kpis": ["Inventory Accuracy", "Count Discrepancies", "Items Counted"],
        "queries": [
            {
                "id": "cycle_count_discrepancies",
                "label": "Cycle Count Discrepancies",
                # Analytic: RANK by variance magnitude; SUM OVER() for total variance qty
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           cycle_count_entry_id, inventory_item_id,
                           organization_id, subinventory,
                           count_quantity, system_quantity,
                           NVL(count_quantity,0) - NVL(system_quantity,0) variance_qty,
                           entry_status_code, count_date,
                           COUNT(*) OVER() total_discrepancies,
                           RANK() OVER (ORDER BY ABS(NVL(count_quantity,0) - NVL(system_quantity,0)) DESC) variance_rank
                    FROM mtl_cycle_count_entries
                    WHERE entry_status_code IN (2,3,5)
                      AND ABS(NVL(count_quantity,0) - NVL(system_quantity,0)) > 0
                      AND count_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY variance_rank
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 20, "severity": "HIGH",
                     "message": "{count} items with cycle count discrepancies"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} cycle count discrepancies found"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "HIGH", "category": "Count Discrepancies", "count": 17,
             "description": "17 items with variance between physical count and system qty"},
        ],
    },

    "resilience": {
        "id": "resilience",
        "name": "Supply Chain Resilience App",
        "pillar": "SCM",
        "icon": "fa-shield-halved",
        "tagline": "Supplier risk, pending receipts, lead-time changes, stockout alerts",
        "kpis": ["At-Risk Items", "Overdue Receipts", "Supplier Exceptions"],
        "queries": [
            {
                "id": "overdue_po_receipts",
                "label": "Overdue PO Receipts",
                # closed_code equality (indexed); analytic: most overdue ranked first
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           ld.line_location_id, ld.po_line_id,
                           ld.quantity_ordered, NVL(ld.quantity_received,0) qty_received,
                           ld.quantity_ordered - NVL(ld.quantity_received,0) qty_outstanding,
                           NVL(ld.promised_date, ld.need_by_date) due_date,
                           ROUND(SYSDATE - NVL(ld.promised_date, ld.need_by_date), 0) days_overdue,
                           ld.ship_to_organization_id,
                           COUNT(*) OVER()     total_overdue,
                           RANK() OVER (ORDER BY SYSDATE - NVL(ld.promised_date, ld.need_by_date) DESC) overdue_rank
                    FROM po_line_locations_all ld
                    WHERE ld.closed_code = 'OPEN'
                      AND ld.quantity_received < ld.quantity_ordered
                      AND NVL(ld.promised_date, ld.need_by_date) < TRUNC(SYSDATE)
                      AND NVL(ld.cancel_flag,'N') = 'N'
                      AND NVL(ld.promised_date, ld.need_by_date) >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY overdue_rank
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 20, "severity": "CRITICAL",
                     "message": "{count} PO receipts overdue — supply risk"},
                    {"field": "count", "op": ">", "value": 5, "severity": "HIGH",
                     "message": "{count} overdue purchase order receipts"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "CRITICAL", "category": "Overdue Receipts", "count": 31,
             "description": "31 PO receipt lines overdue — 8 items risk stockout within 2 weeks"},
        ],
    },

    # ── SUPPLY CHAIN PLANNING ─────────────────────────────────────────────────

    "demand_mgmt": {
        "id": "demand_mgmt",
        "name": "Demand Management Agents",
        "pillar": "PLANNING",
        "icon": "fa-wave-square",
        "tagline": "Sales order demand signals, open orders backlog, demand pattern analysis",
        "kpis": ["Demand Backlog", "Open Orders", "Booking Trend"],
        "queries": [
            {
                "id": "order_backlog_by_period",
                "label": "Open Order Backlog — Next 90 Days",
                # Aggregate by period — no individual row scan; look-ahead fixed at 90d
                "sql": """
                    SELECT /*+ FIRST_ROWS(50) */
                           TO_CHAR(schedule_ship_date,'MON-YYYY') ship_period,
                           COUNT(line_id)                          line_count,
                           SUM(ordered_quantity)                   total_qty,
                           SUM(NVL(unit_selling_price,0) * NVL(ordered_quantity,0)) total_value,
                           order_quantity_uom uom
                    FROM oe_order_lines_all
                    WHERE flow_status_code NOT IN ('CLOSED','CANCELLED','SHIPPED')
                      AND schedule_ship_date BETWEEN TRUNC(SYSDATE)
                                                 AND TRUNC(SYSDATE) + 90
                    GROUP BY TO_CHAR(schedule_ship_date,'MON-YYYY'),
                             schedule_ship_date, order_quantity_uom
                    ORDER BY schedule_ship_date
                    FETCH FIRST 50 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 0, "severity": "INFO",
                     "message": "Demand backlog loaded across {count} planning periods"},
                ],
            },
            {
                "id": "recent_bookings",
                "label": "Recent Order Bookings",
                # No joins; analytic: running total bookings by day
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           TO_CHAR(booked_date,'YYYY-MM-DD') booking_date,
                           COUNT(header_id)                  orders_booked,
                           SUM(NVL(transactional_curr_code,0)) currency_count,
                           SUM(COUNT(header_id)) OVER (ORDER BY TRUNC(booked_date)) running_total
                    FROM oe_order_headers_all
                    WHERE booked_flag = 'Y'
                      AND booked_date >= TRUNC(SYSDATE) - {days_back}
                    GROUP BY TRUNC(booked_date), TO_CHAR(booked_date,'YYYY-MM-DD')
                    ORDER BY TRUNC(booked_date) DESC
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 0, "severity": "INFO",
                     "message": "Booking trend loaded for {count} days"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "INFO", "category": "Order Backlog", "count": 12,
             "description": "Demand backlog: APR $1.2M, MAY $0.9M, JUN $0.7M"},
        ],
    },

    "supply_planning": {
        "id": "supply_planning",
        "name": "Supply Planning Agents",
        "pillar": "PLANNING",
        "icon": "fa-network-wired",
        "tagline": "Inventory levels, replenishment status, supply vs demand gaps",
        "kpis": ["Inventory Coverage", "Replenishment Pipeline", "Supply Exceptions"],
        "queries": [
            {
                "id": "low_stock_items",
                "label": "Items Below Minimum Stock",
                # JOIN to mtl_system_items_b necessary for min_qty; both on PK
                # Analytic: RANK by stock gap severity
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           q.inventory_item_id, q.organization_id,
                           SUM(q.transaction_quantity) on_hand_qty,
                           msi.min_minmax_quantity min_qty,
                           msi.primary_uom_code uom,
                           CASE WHEN SUM(q.transaction_quantity) = 0
                                THEN 'ZERO' ELSE 'BELOW_MIN' END stock_status,
                           COUNT(*) OVER() total_below_min
                    FROM mtl_onhand_quantities_detail q
                    JOIN mtl_system_items_b msi
                      ON q.inventory_item_id = msi.inventory_item_id
                     AND q.organization_id   = msi.organization_id
                    WHERE msi.planning_make_buy_code = 2
                      AND msi.planning_enabled_flag  = 'Y'
                    GROUP BY q.inventory_item_id, q.organization_id,
                             msi.min_minmax_quantity, msi.primary_uom_code
                    HAVING SUM(q.transaction_quantity) < NVL(msi.min_minmax_quantity, 1)
                        OR SUM(q.transaction_quantity) = 0
                    ORDER BY SUM(q.transaction_quantity)
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 20, "severity": "CRITICAL",
                     "message": "{count} items at or below minimum inventory level"},
                    {"field": "count", "op": ">", "value": 5, "severity": "HIGH",
                     "message": "{count} items below minimum stock level"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "CRITICAL", "category": "Below Min Stock", "count": 22,
             "description": "22 buy items below minimum quantity — replenishment orders needed"},
        ],
    },

    "sop": {
        "id": "sop",
        "name": "S&OP / IBP Agentic App",
        "pillar": "PLANNING",
        "icon": "fa-people-group",
        "tagline": "Concurrent manager health, workflow status, overall EBS operational readiness",
        "kpis": ["CP Manager Health", "Workflow Health", "System Readiness"],
        "queries": [
            {
                "id": "cp_manager_status",
                "label": "Concurrent Manager Status",
                # fnd_concurrent_queues_vl is tiny; no date filter needed
                "sql": """
                    SELECT /*+ FIRST_ROWS(30) */
                           user_concurrent_queue_name manager_name,
                           max_processes   target_processes,
                           running_processes actual_processes,
                           enabled_flag,
                           manager_type,
                           CASE WHEN running_processes < max_processes
                                THEN 'UNDER_CAPACITY'
                                ELSE 'OK' END capacity_status
                    FROM fnd_concurrent_queues_vl
                    WHERE enabled_flag = 'Y'
                    ORDER BY user_concurrent_queue_name
                    FETCH FIRST 30 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 0, "severity": "INFO",
                     "message": "{count} concurrent managers checked"},
                ],
            },
            {
                "id": "stuck_cp_requests",
                "label": "Stuck Concurrent Requests (> 2 hrs)",
                # Equality on phase_code + status_code (indexed); analytic hours context
                "sql": """
                    SELECT /*+ FIRST_ROWS(50) */
                           r.request_id, r.phase_code, r.status_code,
                           r.concurrent_program_id,
                           r.requested_by, r.actual_start_date,
                           ROUND((SYSDATE - r.actual_start_date) * 24, 2) hours_running,
                           COUNT(*) OVER() total_stuck,
                           MAX(ROUND((SYSDATE - r.actual_start_date) * 24, 2)) OVER() max_hours
                    FROM fnd_concurrent_requests r
                    WHERE r.phase_code  = 'R'
                      AND r.status_code = 'R'
                      AND r.actual_start_date < SYSDATE - 2/24
                    ORDER BY r.actual_start_date
                    FETCH FIRST 50 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 5, "severity": "CRITICAL",
                     "message": "{count} concurrent requests stuck > 2 hours"},
                    {"field": "count", "op": ">", "value": 0, "severity": "HIGH",
                     "message": "{count} requests stuck in running state"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "INFO", "category": "CP Managers", "count": 6,
             "description": "All 6 concurrent managers active"},
            {"severity": "HIGH", "category": "Stuck Requests", "count": 3,
             "description": "3 concurrent requests running > 2 hours"},
        ],
    },

    "order_promising": {
        "id": "order_promising",
        "name": "Order Promising Agents",
        "pillar": "PLANNING",
        "icon": "fa-calendar-check",
        "tagline": "Workflow exceptions, notification backlog, approvals pipeline",
        "kpis": ["Workflow Errors", "Stuck Activities", "Notification Backlog"],
        "queries": [
            {
                "id": "wf_error_activities",
                "label": "Workflow Error Activities",
                # Equality on activity_status (indexed); analytic error count by type
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           item_type, item_key,
                           activity_status, activity_result_code,
                           error_name, begin_date,
                           ROUND((SYSDATE - begin_date) * 24, 2) hours_stuck,
                           COUNT(*) OVER ()                         total_errors,
                           COUNT(*) OVER (PARTITION BY item_type)   errors_by_type
                    FROM wf_item_activity_statuses
                    WHERE activity_status = 'ERROR'
                      AND begin_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY begin_date
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 20, "severity": "HIGH",
                     "message": "{count} workflow activities in ERROR state"},
                    {"field": "count", "op": ">", "value": 0, "severity": "MEDIUM",
                     "message": "{count} workflow activities with errors"},
                ],
            },
            {
                "id": "open_notifications",
                "label": "Open Workflow Notifications (> 3 days)",
                # Equality on status (indexed); analytic: notifications by role
                "sql": """
                    SELECT /*+ FIRST_ROWS(100) */
                           notification_id, message_type, message_name,
                           status, mail_status,
                           recipient_role, begin_date, due_date,
                           ROUND(SYSDATE - begin_date, 0) days_open,
                           subject,
                           COUNT(*) OVER ()                              total_open,
                           COUNT(*) OVER (PARTITION BY recipient_role)   per_role_count
                    FROM wf_notifications
                    WHERE status = 'OPEN'
                      AND begin_date < TRUNC(SYSDATE) - 3
                      AND begin_date >= TRUNC(SYSDATE) - {days_back}
                    ORDER BY begin_date
                    FETCH FIRST 100 ROWS ONLY
                """,
                "severity_rules": [
                    {"field": "count", "op": ">", "value": 50, "severity": "HIGH",
                     "message": "{count} open workflow notifications — approvals delayed"},
                    {"field": "count", "op": ">", "value": 10, "severity": "MEDIUM",
                     "message": "{count} workflow notifications open > 3 days"},
                ],
            },
        ],
        "demo_findings": [
            {"severity": "HIGH", "category": "Workflow Errors", "count": 23,
             "description": "23 activities in ERROR state (AP:15, PO:5, HR:3)"},
            {"severity": "MEDIUM", "category": "Open Notifications", "count": 47,
             "description": "47 workflow notifications open > 3 days without action"},
        ],
    },
}


def get_fusion_app(app_id: str) -> dict:
    return FUSION_APPS.get(app_id)


def list_fusion_apps() -> list:
    return [
        {
            "id": v["id"],
            "name": v["name"],
            "pillar": v["pillar"],
            "icon": v["icon"],
            "tagline": v["tagline"],
            "kpis": v["kpis"],
        }
        for v in FUSION_APPS.values()
    ]
