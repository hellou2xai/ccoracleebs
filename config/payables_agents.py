"""
Payables Agents — 10 critical agentic workers for Oracle EBS AP.
Each agent reuses SQL packs from config.payables_app.PAYABLES_QUERIES,
applies its own severity rules, and emits recommended actions.
"""
from typing import Any, Dict, List, Callable, Optional


PAYABLES_AGENTS: List[Dict[str, Any]] = [
    {
        "id": "hold_resolver",
        "label": "Hold Resolver",
        "icon": "fa-circle-pause",
        "color": "#d12f2f",
        "group": "Invoice Processing",
        "purpose": "Diagnoses every active AP hold, classifies by type, and recommends release / PO correction / supplier dispute.",
        "queries": ["holds", "approvers", "match_exceptions"],
        "tables": ["AP_HOLDS_ALL", "AP_INVOICES_ALL", "AP_SUPPLIERS"],
    },
    {
        "id": "three_way_match",
        "label": "Three-Way Match Auditor",
        "icon": "fa-link",
        "color": "#a04ad6",
        "group": "Invoice Processing",
        "purpose": "Cross-checks invoice vs PO vs receipt. Flags tolerance breaches and identifies the failing leg.",
        "queries": ["match_exceptions", "approvers"],
        "tables": ["AP_HOLDS_ALL", "PO_DISTRIBUTIONS_ALL", "RCV_TRANSACTIONS"],
    },
    {
        "id": "dup_invoice_hunter",
        "label": "Duplicate Invoice Hunter",
        "icon": "fa-clone",
        "color": "#e65100",
        "group": "Invoice Processing",
        "purpose": "Fuzzy-matches vendor + amount + invoice date to catch true and near-duplicate invoices before payment.",
        "queries": ["duplicate_risk"],
        "tables": ["AP_INVOICES_ALL", "AP_SUPPLIERS"],
    },
    {
        "id": "approval_accelerator",
        "label": "Approval Accelerator",
        "icon": "fa-bolt",
        "color": "#0969da",
        "group": "Invoice Processing",
        "purpose": "Finds stuck AME approvals, names who's holding them, and suggests re-route or escalation.",
        "queries": ["unapproved_invoices", "approval_bottleneck"],
        "tables": ["WF_ITEM_ACTIVITY_STATUSES", "FND_USER", "AP_INVOICES_ALL"],
    },
    {
        "id": "payment_run_optimizer",
        "label": "Payment Run Optimizer",
        "icon": "fa-money-bill-trend-up",
        "color": "#1a7f37",
        "group": "Payment & Cash",
        "purpose": "Selects invoices for the next pay batch by due date, discount terms, and supplier priority. Flags cash-flow conflicts.",
        "queries": ["discounts", "supplier_aging"],
        "tables": ["AP_PAYMENT_SCHEDULES_ALL", "AP_INVOICES_ALL"],
    },
    {
        "id": "discount_capture",
        "label": "Discount Capture",
        "icon": "fa-percent",
        "color": "#1a7f37",
        "group": "Payment & Cash",
        "purpose": "Lists invoices with discount terms not yet taken, value of discounts already lost, and acceleration recommendations.",
        "queries": ["discounts"],
        "tables": ["AP_PAYMENT_SCHEDULES_ALL"],
    },
    {
        "id": "prepayment_apply",
        "label": "Prepayment Application",
        "icon": "fa-arrows-spin",
        "color": "#0969da",
        "group": "Payment & Cash",
        "purpose": "Finds unapplied prepayments and recommends standard invoices to apply them against.",
        "queries": ["open_prepayments", "supplier_aging"],
        "tables": ["AP_INVOICES_ALL"],
    },
    {
        "id": "supplier_risk",
        "label": "Supplier Risk",
        "icon": "fa-shield-halved",
        "color": "#d12f2f",
        "group": "Risk & Compliance",
        "purpose": "Watches non-PO spend concentration, aging exposure, and unusual supplier patterns that can indicate fraud or compliance gaps.",
        "queries": ["non_po_invoices", "supplier_aging"],
        "tables": ["AP_SUPPLIERS", "AP_INVOICES_ALL"],
    },
    {
        "id": "period_close",
        "label": "Period Close Coordinator",
        "icon": "fa-clipboard-check",
        "color": "#6f42c1",
        "group": "Risk & Compliance",
        "purpose": "Drives the AP close checklist: unposted invoices, missing accruals, sweep candidates, prepayment gaps, cycle-time outliers.",
        "queries": ["summary", "invoice_health", "cycle_time", "open_prepayments"],
        "tables": ["AP_INVOICES_ALL"],
    },
    {
        "id": "tax_wht_validator",
        "label": "Tax & Withholding Validator",
        "icon": "fa-scale-balanced",
        "color": "#a04ad6",
        "group": "Risk & Compliance",
        "purpose": "Compares invoice tax / withholding against PO and supplier setup. Flags mismatches and recall candidates.",
        "queries": ["match_exceptions", "cycle_time"],
        "tables": ["AP_HOLDS_ALL", "AP_INVOICES_ALL"],
    },
]


AGENT_BY_ID: Dict[str, Dict[str, Any]] = {a["id"]: a for a in PAYABLES_AGENTS}


# ─── Severity rules per agent ────────────────────────────────────────────────

def _rule_hold_resolver(results: Dict[str, Any]) -> Dict[str, Any]:
    holds = results.get("holds", {}).get("rows", [])
    count = len(holds)
    avg_days = float(holds[0].get("avg_days_on_hold") or 0) if holds else 0
    max_days = float(holds[0].get("max_days_on_hold") or 0) if holds else 0
    if count == 0:
        return {"severity": "INFO", "summary": "No active holds in window."}
    sev = "CRITICAL" if (count > 20 or avg_days > 10) else "HIGH" if count > 5 else "MEDIUM"
    return {
        "severity": sev,
        "summary": f"{count} invoices on hold. Avg {avg_days:.1f}d, max {max_days:.0f}d.",
        "actions": [
            "Triage holds by type (price, qty, account) and assign owners.",
            "Release manual holds where root cause is resolved.",
            "Escalate holds older than 14 days to AP manager.",
        ],
    }


def _rule_three_way_match(results: Dict[str, Any]) -> Dict[str, Any]:
    rows = results.get("match_exceptions", {}).get("rows", [])
    count = len(rows)
    if count == 0:
        return {"severity": "INFO", "summary": "No match exceptions in window."}
    sev = "CRITICAL" if count > 25 else "HIGH" if count > 10 else "MEDIUM"
    by_type: Dict[str, int] = {}
    for r in rows:
        by_type[r.get("hold_type", "?")] = by_type.get(r.get("hold_type", "?"), 0) + 1
    top = sorted(by_type.items(), key=lambda x: -x[1])[:3]
    detail = ", ".join(f"{k}: {v}" for k, v in top)
    return {
        "severity": sev,
        "summary": f"{count} match exceptions. Top: {detail}.",
        "actions": [
            "Compare invoice unit price vs PO line price for PRICE holds.",
            "Verify receipt qty before releasing QTY RECEIVED holds.",
            "Request PO amendment from buyer for QTY/AMOUNT ORDERED breaches.",
        ],
    }


def _rule_dup_invoice_hunter(results: Dict[str, Any]) -> Dict[str, Any]:
    rows = results.get("duplicate_risk", {}).get("rows", [])
    count = len(rows)
    if count == 0:
        return {"severity": "INFO", "summary": "No duplicate-risk pairs in window."}
    sev = "CRITICAL" if count > 5 else "HIGH"
    return {
        "severity": sev,
        "summary": f"{count} potential duplicate invoice pairs flagged.",
        "actions": [
            "Place hold on the later-dated invoice in each pair until verified.",
            "Confirm with supplier whether both invoices are genuine.",
            "Cancel duplicate and notify requester before payment release.",
        ],
    }


def _rule_approval_accelerator(results: Dict[str, Any]) -> Dict[str, Any]:
    pending = results.get("unapproved_invoices", {}).get("rows", [])
    bots = results.get("approval_bottleneck", {}).get("rows", [])
    count = len(pending)
    if count == 0:
        return {"severity": "INFO", "summary": "No pending approvals in window."}
    top_approver = bots[0] if bots else {}
    name = top_approver.get("approver_name") or top_approver.get("approver") or "n/a"
    days = top_approver.get("max_days_waiting") or 0
    sev = "CRITICAL" if count > 30 else "HIGH" if count > 10 else "MEDIUM"
    return {
        "severity": sev,
        "summary": f"{count} invoices awaiting approval. Slowest approver: {name} ({days}d).",
        "actions": [
            f"Send escalation to {name} for items aged > 5 days.",
            "Re-route approvals where assignee is on leave (check FND_USER end_date).",
            "Apply auto-approve rule for invoices under tolerance threshold.",
        ],
    }


def _rule_payment_run_optimizer(results: Dict[str, Any]) -> Dict[str, Any]:
    disc = results.get("discounts", {}).get("rows", [])
    aging = results.get("supplier_aging", {}).get("rows", [])
    if not disc and not aging:
        return {"severity": "INFO", "summary": "No payment-run signals in window."}
    discount_total = float(disc[0].get("total_discount_available") or 0) if disc else 0
    over_90 = sum(float(r.get("bucket_over_90") or 0) for r in aging)
    sev = "HIGH" if (discount_total > 10000 or over_90 > 50000) else "MEDIUM"
    return {
        "severity": sev,
        "summary": f"${discount_total:,.0f} discounts in window. ${over_90:,.0f} over 90 days.",
        "actions": [
            "Build pay batch around URGENT discount-window invoices first.",
            "Bring forward over-90 buckets that are blocking supplier credit.",
            "Stagger high-value EFT runs to avoid bank cut-off conflicts.",
        ],
    }


def _rule_discount_capture(results: Dict[str, Any]) -> Dict[str, Any]:
    rows = results.get("discounts", {}).get("rows", [])
    count = len(rows)
    if count == 0:
        return {"severity": "INFO", "summary": "No discount opportunities in window."}
    total = float(rows[0].get("total_discount_available") or 0)
    urgent = sum(1 for r in rows if r.get("urgency") == "URGENT")
    sev = "HIGH" if (total > 10000 or urgent > 0) else "MEDIUM"
    return {
        "severity": sev,
        "summary": f"${total:,.0f} discounts available. {urgent} expire within 3 days.",
        "actions": [
            "Pay urgent (<= 3 days) discount invoices today.",
            "Confirm cash position before triggering early-pay batch.",
            "Capture missed-discount metric for weekly cash report.",
        ],
    }


def _rule_prepayment_apply(results: Dict[str, Any]) -> Dict[str, Any]:
    rows = results.get("open_prepayments", {}).get("rows", [])
    count = len(rows)
    if count == 0:
        return {"severity": "INFO", "summary": "No open prepayments in window."}
    total = float(rows[0].get("total_prepay_amount") or 0)
    sev = "HIGH" if total > 100000 else "MEDIUM"
    return {
        "severity": sev,
        "summary": f"{count} open prepayments totalling ${total:,.0f}.",
        "actions": [
            "Match each prepayment against open standard invoices for the same vendor.",
            "Apply prepayment in AP > Invoices > Apply / Unapply Prepayments.",
            "Follow up on prepayments older than 90 days for refund or write-off.",
        ],
    }


def _rule_supplier_risk(results: Dict[str, Any]) -> Dict[str, Any]:
    non_po = results.get("non_po_invoices", {}).get("rows", [])
    aging = results.get("supplier_aging", {}).get("rows", [])
    np_count = len(non_po)
    np_total = float(non_po[0].get("total_non_po_amount") or 0) if non_po else 0
    over_90 = sum(float(r.get("bucket_over_90") or 0) for r in aging)
    if np_count == 0 and over_90 == 0:
        return {"severity": "INFO", "summary": "Supplier risk indicators within tolerance."}
    sev = "CRITICAL" if (np_total > 250000 or over_90 > 100000) else "HIGH" if np_count > 20 else "MEDIUM"
    return {
        "severity": sev,
        "summary": f"{np_count} non-PO invoices (${np_total:,.0f}). ${over_90:,.0f} aged > 90d.",
        "actions": [
            "Sample 10 highest-value non-PO invoices for control review.",
            "Verify bank-detail change history for top-spend suppliers.",
            "Flag suppliers in >90 bucket to procurement for credit review.",
        ],
    }


def _rule_period_close(results: Dict[str, Any]) -> Dict[str, Any]:
    summary = results.get("summary", {}).get("rows", [{}])
    health = results.get("invoice_health", {}).get("rows", [])
    cycle = results.get("cycle_time", {}).get("rows", [])
    prepay = results.get("open_prepayments", {}).get("rows", [])
    s = summary[0] if summary else {}
    unposted = int(s.get("unposted_count") or 0)
    pending = int(s.get("pending_approval") or 0)
    avg_cycle = float(cycle[0].get("avg_cycle_days") or 0) if cycle else 0
    sev = "CRITICAL" if unposted > 50 else "HIGH" if unposted > 10 else "MEDIUM"
    return {
        "severity": sev,
        "summary": f"{unposted} unposted, {pending} pending approval, avg cycle {avg_cycle:.1f}d, {len(prepay)} open prepayments.",
        "actions": [
            "Sweep unposted invoices and resolve before period close.",
            "Run mass-validate to clear validation holds.",
            "Apply or refund prepayments to clean AP sub-ledger.",
            "Post accruals for received-not-invoiced before final journal.",
        ],
    }


def _rule_tax_wht_validator(results: Dict[str, Any]) -> Dict[str, Any]:
    rows = results.get("match_exceptions", {}).get("rows", [])
    tax_rows = [r for r in rows if "TAX" in str(r.get("hold_type", "")).upper()]
    count = len(tax_rows)
    if count == 0:
        return {"severity": "INFO", "summary": "No tax-related holds in window."}
    sev = "HIGH" if count > 5 else "MEDIUM"
    return {
        "severity": sev,
        "summary": f"{count} tax-related holds.",
        "actions": [
            "Compare invoice tax line to PO expected tax.",
            "Validate supplier tax registration in ZX_PARTY_TAX_PROFILE.",
            "Recall WHT calc for invoices flagged with TAX hold.",
        ],
    }


SEVERITY_RULES: Dict[str, Callable[[Dict[str, Any]], Dict[str, Any]]] = {
    "hold_resolver":          _rule_hold_resolver,
    "three_way_match":        _rule_three_way_match,
    "dup_invoice_hunter":     _rule_dup_invoice_hunter,
    "approval_accelerator":   _rule_approval_accelerator,
    "payment_run_optimizer":  _rule_payment_run_optimizer,
    "discount_capture":       _rule_discount_capture,
    "prepayment_apply":       _rule_prepayment_apply,
    "supplier_risk":          _rule_supplier_risk,
    "period_close":           _rule_period_close,
    "tax_wht_validator":      _rule_tax_wht_validator,
}


# ─── Demo data per agent (used when oracle_db.demo_mode) ─────────────────────

DEMO_AGENT_RESULT: Dict[str, Dict[str, Any]] = {
    "hold_resolver": {
        "severity": "HIGH",
        "summary": "12 invoices on hold. Avg 5.4d, max 18d.",
        "actions": [
            "Triage holds by type (price, qty, account) and assign owners.",
            "Release manual holds where root cause is resolved.",
            "Escalate holds older than 14 days to AP manager.",
        ],
        "row_count": 12,
        "query_rows": {
            "holds": [
                {"invoice_id": 80123, "invoice_num": "INV-44021", "vendor_name": "Acme Industrial Supply", "hold_lookup_code": "PRICE",        "hold_reason": "Invoice price exceeds PO unit price by 7.5%",         "invoice_amount": 18420.00, "invoice_currency_code": "USD", "days_on_hold": 18, "source": "Manual",     "wfapproval_status": "REQUIRED"},
                {"invoice_id": 80155, "invoice_num": "INV-44062", "vendor_name": "Acme Industrial Supply", "hold_lookup_code": "PRICE",        "hold_reason": "Unit price variance vs PO line",                      "invoice_amount":  4280.50, "invoice_currency_code": "USD", "days_on_hold": 11, "source": "Manual",     "wfapproval_status": "REQUIRED"},
                {"invoice_id": 80201, "invoice_num": "INV-44115", "vendor_name": "BlueRiver Logistics",    "hold_lookup_code": "QTY RECEIVED", "hold_reason": "Invoiced qty 100 vs received 80",                     "invoice_amount":  9120.00, "invoice_currency_code": "USD", "days_on_hold":  9, "source": "Import",     "wfapproval_status": "INITIATED"},
                {"invoice_id": 80214, "invoice_num": "INV-44128", "vendor_name": "BlueRiver Logistics",    "hold_lookup_code": "QTY ORDERED", "hold_reason": "Qty exceeds PO line ordered",                          "invoice_amount":  3560.75, "invoice_currency_code": "USD", "days_on_hold":  6, "source": "Import",     "wfapproval_status": "REQUIRED"},
                {"invoice_id": 80239, "invoice_num": "INV-44170", "vendor_name": "Continental Steel Co",   "hold_lookup_code": "AMOUNT ORDERED","hold_reason": "Amount exceeds PO header total",                     "invoice_amount": 26100.00, "invoice_currency_code": "USD", "days_on_hold":  5, "source": "Manual",     "wfapproval_status": "REQUIRED"},
                {"invoice_id": 80268, "invoice_num": "INV-44209", "vendor_name": "Delta Office Solutions", "hold_lookup_code": "DIST ACCT",   "hold_reason": "Account combination invalid",                          "invoice_amount":   612.30, "invoice_currency_code": "USD", "days_on_hold":  4, "source": "Manual",     "wfapproval_status": "NOT REQUIRED"},
                {"invoice_id": 80292, "invoice_num": "INV-44241", "vendor_name": "EcoPack Materials",      "hold_lookup_code": "TAX",         "hold_reason": "Tax variance vs ZX expected",                          "invoice_amount":  1780.00, "invoice_currency_code": "USD", "days_on_hold":  4, "source": "Import",     "wfapproval_status": "REQUIRED"},
                {"invoice_id": 80315, "invoice_num": "INV-44288", "vendor_name": "FrostByte Cooling",      "hold_lookup_code": "VARIANCE",    "hold_reason": "Tolerance exceeded across header",                     "invoice_amount":  7340.00, "invoice_currency_code": "USD", "days_on_hold":  3, "source": "Manual",     "wfapproval_status": "REQUIRED"},
                {"invoice_id": 80344, "invoice_num": "INV-44321", "vendor_name": "Globex Components",      "hold_lookup_code": "PRICE",       "hold_reason": "PO unit price stale (>180d)",                          "invoice_amount": 11020.00, "invoice_currency_code": "USD", "days_on_hold":  2, "source": "Import",     "wfapproval_status": "REQUIRED"},
                {"invoice_id": 80360, "invoice_num": "INV-44340", "vendor_name": "Helios Power & Light",   "hold_lookup_code": "QTY RECEIVED","hold_reason": "Receipt not posted",                                   "invoice_amount":  4480.00, "invoice_currency_code": "USD", "days_on_hold":  2, "source": "Manual",     "wfapproval_status": "REQUIRED"},
                {"invoice_id": 80371, "invoice_num": "INV-44359", "vendor_name": "Indigo IT Services",     "hold_lookup_code": "INSUFFICIENT_FUNDS","hold_reason": "Project budget overrun",                          "invoice_amount":  3210.00, "invoice_currency_code": "USD", "days_on_hold":  1, "source": "Manual",     "wfapproval_status": "REQUIRED"},
                {"invoice_id": 80388, "invoice_num": "INV-44380", "vendor_name": "Jupiter Maintenance",    "hold_lookup_code": "PRICE",       "hold_reason": "Catalogue price update pending",                       "invoice_amount":  1920.00, "invoice_currency_code": "USD", "days_on_hold":  1, "source": "Import",     "wfapproval_status": "INITIATED"},
            ],
            "approvers": [
                {"hold_type": "PRICE",            "approval_status": "REQUIRED",     "invoice_count": 4, "hold_count": 4, "total_amount": 35642.50, "min_days":  1, "max_days": 18, "avg_days": 8.0},
                {"hold_type": "QTY RECEIVED",     "approval_status": "INITIATED",    "invoice_count": 2, "hold_count": 2, "total_amount": 13600.00, "min_days":  2, "max_days":  9, "avg_days": 5.5},
                {"hold_type": "QTY ORDERED",      "approval_status": "REQUIRED",     "invoice_count": 1, "hold_count": 1, "total_amount":  3560.75, "min_days":  6, "max_days":  6, "avg_days": 6.0},
                {"hold_type": "AMOUNT ORDERED",   "approval_status": "REQUIRED",     "invoice_count": 1, "hold_count": 1, "total_amount": 26100.00, "min_days":  5, "max_days":  5, "avg_days": 5.0},
                {"hold_type": "TAX",              "approval_status": "REQUIRED",     "invoice_count": 1, "hold_count": 1, "total_amount":  1780.00, "min_days":  4, "max_days":  4, "avg_days": 4.0},
                {"hold_type": "VARIANCE",         "approval_status": "REQUIRED",     "invoice_count": 1, "hold_count": 1, "total_amount":  7340.00, "min_days":  3, "max_days":  3, "avg_days": 3.0},
                {"hold_type": "DIST ACCT",        "approval_status": "NOT REQUIRED", "invoice_count": 1, "hold_count": 1, "total_amount":   612.30, "min_days":  4, "max_days":  4, "avg_days": 4.0},
                {"hold_type": "INSUFFICIENT_FUNDS","approval_status": "REQUIRED",    "invoice_count": 1, "hold_count": 1, "total_amount":  3210.00, "min_days":  1, "max_days":  1, "avg_days": 1.0},
            ],
            "match_exceptions": [
                {"invoice_id": 80123, "invoice_num": "INV-44021", "vendor_name": "Acme Industrial Supply", "hold_type": "PRICE",         "hold_reason": "Invoice price exceeds PO unit price by 7.5%", "days_on_hold": 18, "invoice_amount": 18420.00, "invoice_currency_code": "USD", "source": "Manual"},
                {"invoice_id": 80155, "invoice_num": "INV-44062", "vendor_name": "Acme Industrial Supply", "hold_type": "PRICE",         "hold_reason": "Unit price variance vs PO line",              "days_on_hold": 11, "invoice_amount":  4280.50, "invoice_currency_code": "USD", "source": "Manual"},
                {"invoice_id": 80201, "invoice_num": "INV-44115", "vendor_name": "BlueRiver Logistics",    "hold_type": "QTY RECEIVED",  "hold_reason": "Invoiced qty 100 vs received 80",             "days_on_hold":  9, "invoice_amount":  9120.00, "invoice_currency_code": "USD", "source": "Import"},
                {"invoice_id": 80214, "invoice_num": "INV-44128", "vendor_name": "BlueRiver Logistics",    "hold_type": "QTY ORDERED",   "hold_reason": "Qty exceeds PO line ordered",                 "days_on_hold":  6, "invoice_amount":  3560.75, "invoice_currency_code": "USD", "source": "Import"},
                {"invoice_id": 80239, "invoice_num": "INV-44170", "vendor_name": "Continental Steel Co",   "hold_type": "AMOUNT ORDERED","hold_reason": "Amount exceeds PO header total",              "days_on_hold":  5, "invoice_amount": 26100.00, "invoice_currency_code": "USD", "source": "Manual"},
                {"invoice_id": 80315, "invoice_num": "INV-44288", "vendor_name": "FrostByte Cooling",      "hold_type": "VARIANCE",      "hold_reason": "Tolerance exceeded across header",            "days_on_hold":  3, "invoice_amount":  7340.00, "invoice_currency_code": "USD", "source": "Manual"},
                {"invoice_id": 80344, "invoice_num": "INV-44321", "vendor_name": "Globex Components",      "hold_type": "PRICE",         "hold_reason": "PO unit price stale (>180d)",                 "days_on_hold":  2, "invoice_amount": 11020.00, "invoice_currency_code": "USD", "source": "Import"},
                {"invoice_id": 80360, "invoice_num": "INV-44340", "vendor_name": "Helios Power & Light",   "hold_type": "QTY RECEIVED",  "hold_reason": "Receipt not posted",                          "days_on_hold":  2, "invoice_amount":  4480.00, "invoice_currency_code": "USD", "source": "Manual"},
                {"invoice_id": 80388, "invoice_num": "INV-44380", "vendor_name": "Jupiter Maintenance",    "hold_type": "PRICE",         "hold_reason": "Catalogue price update pending",              "days_on_hold":  1, "invoice_amount":  1920.00, "invoice_currency_code": "USD", "source": "Import"},
            ],
        },
    },
    "three_way_match": {
        "severity": "HIGH",
        "summary": "9 match exceptions. Top: PRICE: 5, QTY RECEIVED: 3, VARIANCE: 1.",
        "actions": [
            "Compare invoice unit price vs PO line price for PRICE holds.",
            "Verify receipt qty before releasing QTY RECEIVED holds.",
            "Request PO amendment from buyer for QTY/AMOUNT ORDERED breaches.",
        ],
        "row_count": 9,
        "query_rows": {
            "match_exceptions": [
                {"invoice_id": 80123, "invoice_num": "INV-44021", "vendor_name": "Acme Industrial Supply", "hold_type": "PRICE",        "hold_reason": "Invoice price 18.42 vs PO 17.10",         "days_on_hold": 18, "invoice_amount": 18420.00, "invoice_currency_code": "USD", "source": "Manual"},
                {"invoice_id": 80155, "invoice_num": "INV-44062", "vendor_name": "Acme Industrial Supply", "hold_type": "PRICE",        "hold_reason": "Unit price variance 4.2%",                "days_on_hold": 11, "invoice_amount":  4280.50, "invoice_currency_code": "USD", "source": "Manual"},
                {"invoice_id": 80344, "invoice_num": "INV-44321", "vendor_name": "Globex Components",      "hold_type": "PRICE",        "hold_reason": "PO unit price stale (>180d)",             "days_on_hold":  2, "invoice_amount": 11020.00, "invoice_currency_code": "USD", "source": "Import"},
                {"invoice_id": 80388, "invoice_num": "INV-44380", "vendor_name": "Jupiter Maintenance",    "hold_type": "PRICE",        "hold_reason": "Catalogue update pending",                "days_on_hold":  1, "invoice_amount":  1920.00, "invoice_currency_code": "USD", "source": "Import"},
                {"invoice_id": 80401, "invoice_num": "INV-44402", "vendor_name": "Kestrel Plastics",        "hold_type": "PRICE",        "hold_reason": "Quoted price not honoured",               "days_on_hold":  1, "invoice_amount":  6450.00, "invoice_currency_code": "USD", "source": "Manual"},
                {"invoice_id": 80201, "invoice_num": "INV-44115", "vendor_name": "BlueRiver Logistics",    "hold_type": "QTY RECEIVED", "hold_reason": "Invoiced 100 vs received 80",             "days_on_hold":  9, "invoice_amount":  9120.00, "invoice_currency_code": "USD", "source": "Import"},
                {"invoice_id": 80360, "invoice_num": "INV-44340", "vendor_name": "Helios Power & Light",   "hold_type": "QTY RECEIVED", "hold_reason": "Receipt not posted",                      "days_on_hold":  2, "invoice_amount":  4480.00, "invoice_currency_code": "USD", "source": "Manual"},
                {"invoice_id": 80214, "invoice_num": "INV-44128", "vendor_name": "BlueRiver Logistics",    "hold_type": "QTY RECEIVED", "hold_reason": "Invoiced 12 vs received 10",              "days_on_hold":  6, "invoice_amount":  3560.75, "invoice_currency_code": "USD", "source": "Import"},
                {"invoice_id": 80315, "invoice_num": "INV-44288", "vendor_name": "FrostByte Cooling",      "hold_type": "VARIANCE",     "hold_reason": "Tolerance exceeded across header",        "days_on_hold":  3, "invoice_amount":  7340.00, "invoice_currency_code": "USD", "source": "Manual"},
            ],
            "approvers": [
                {"hold_type": "PRICE",        "approval_status": "REQUIRED",  "invoice_count": 5, "hold_count": 5, "total_amount": 42090.50, "min_days":  1, "max_days": 18, "avg_days": 6.6},
                {"hold_type": "QTY RECEIVED", "approval_status": "INITIATED", "invoice_count": 3, "hold_count": 3, "total_amount": 17160.75, "min_days":  2, "max_days":  9, "avg_days": 5.7},
                {"hold_type": "VARIANCE",     "approval_status": "REQUIRED",  "invoice_count": 1, "hold_count": 1, "total_amount":  7340.00, "min_days":  3, "max_days":  3, "avg_days": 3.0},
            ],
        },
    },
    "dup_invoice_hunter": {
        "severity": "CRITICAL",
        "summary": "4 potential duplicate invoice pairs flagged.",
        "actions": [
            "Place hold on the later-dated invoice in each pair until verified.",
            "Confirm with supplier whether both invoices are genuine.",
            "Cancel duplicate and notify requester before payment release.",
        ],
        "row_count": 4,
        "query_rows": {
            "duplicate_risk": [
                {"invoice_id": 80512, "invoice_num": "INV-44510",  "invoice_date": "2026-04-22", "vendor_id": 12001, "vendor_name": "Acme Industrial Supply", "invoice_amount": 14250.00, "invoice_currency_code": "USD", "dup_invoice_id": 80540, "dup_invoice_num": "INV-44510-A", "dup_invoice_date": "2026-04-25", "date_diff_days":  3},
                {"invoice_id": 80608, "invoice_num": "INV-44621",  "invoice_date": "2026-04-15", "vendor_id": 12044, "vendor_name": "Continental Steel Co",   "invoice_amount":  8920.40, "invoice_currency_code": "USD", "dup_invoice_id": 80652, "dup_invoice_num": "INV-44621R", "dup_invoice_date": "2026-04-30", "date_diff_days": 15},
                {"invoice_id": 80714, "invoice_num": "INV-44762",  "invoice_date": "2026-04-09", "vendor_id": 12080, "vendor_name": "Globex Components",      "invoice_amount":  3210.00, "invoice_currency_code": "USD", "dup_invoice_id": 80790, "dup_invoice_num": "INV-44762B", "dup_invoice_date": "2026-04-12", "date_diff_days":  3},
                {"invoice_id": 80832, "invoice_num": "INV-44890",  "invoice_date": "2026-04-02", "vendor_id": 12100, "vendor_name": "Helios Power & Light",   "invoice_amount":  6480.00, "invoice_currency_code": "USD", "dup_invoice_id": 80905, "dup_invoice_num": "INV-44890Z", "dup_invoice_date": "2026-04-22", "date_diff_days": 20},
            ],
        },
    },
    "approval_accelerator": {
        "severity": "HIGH",
        "summary": "8 invoices awaiting approval. Slowest approver: M Patel (12d).",
        "actions": [
            "Send escalation to M Patel for items aged > 5 days.",
            "Re-route approvals where assignee is on leave (check FND_USER end_date).",
            "Apply auto-approve rule for invoices under tolerance threshold.",
        ],
        "row_count": 8,
        "query_rows": {
            "unapproved_invoices": [
                {"invoice_id": 81002, "invoice_num": "INV-45011", "invoice_date": "2026-04-24", "vendor_name": "Acme Industrial Supply", "invoice_amount":  9420.00, "invoice_currency_code": "USD", "wfapproval_status": "INITIATED", "source": "Manual", "days_waiting": 12, "current_approver": "M Patel"},
                {"invoice_id": 81015, "invoice_num": "INV-45033", "invoice_date": "2026-04-25", "vendor_name": "BlueRiver Logistics",    "invoice_amount":  3210.50, "invoice_currency_code": "USD", "wfapproval_status": "INITIATED", "source": "Import", "days_waiting": 11, "current_approver": "M Patel"},
                {"invoice_id": 81044, "invoice_num": "INV-45072", "invoice_date": "2026-04-27", "vendor_name": "Continental Steel Co",   "invoice_amount": 22180.00, "invoice_currency_code": "USD", "wfapproval_status": "INITIATED", "source": "Manual", "days_waiting":  9, "current_approver": "S Nakamura"},
                {"invoice_id": 81071, "invoice_num": "INV-45106", "invoice_date": "2026-04-28", "vendor_name": "Delta Office Solutions", "invoice_amount":  1240.30, "invoice_currency_code": "USD", "wfapproval_status": "REQUIRED",  "source": "Manual", "days_waiting":  8, "current_approver": "S Nakamura"},
                {"invoice_id": 81090, "invoice_num": "INV-45134", "invoice_date": "2026-04-29", "vendor_name": "EcoPack Materials",      "invoice_amount":  4980.00, "invoice_currency_code": "USD", "wfapproval_status": "REQUIRED",  "source": "Import", "days_waiting":  7, "current_approver": "L Okafor"},
                {"invoice_id": 81118, "invoice_num": "INV-45165", "invoice_date": "2026-04-30", "vendor_name": "FrostByte Cooling",      "invoice_amount":  6100.00, "invoice_currency_code": "USD", "wfapproval_status": "INITIATED", "source": "Manual", "days_waiting":  6, "current_approver": "L Okafor"},
                {"invoice_id": 81141, "invoice_num": "INV-45192", "invoice_date": "2026-05-01", "vendor_name": "Globex Components",      "invoice_amount":  8540.00, "invoice_currency_code": "USD", "wfapproval_status": "INITIATED", "source": "Import", "days_waiting":  5, "current_approver": "K Chen"},
                {"invoice_id": 81168, "invoice_num": "INV-45221", "invoice_date": "2026-05-02", "vendor_name": "Helios Power & Light",   "invoice_amount":  3320.00, "invoice_currency_code": "USD", "wfapproval_status": "REQUIRED",  "source": "Manual", "days_waiting":  4, "current_approver": "K Chen"},
            ],
            "approval_bottleneck": [
                {"approver": "MPATEL",    "approver_name": "M Patel",    "pending_count": 2, "avg_days_waiting": 11.5, "max_days_waiting": 12, "total_amount_pending": 12630.50},
                {"approver": "SNAKAMURA", "approver_name": "S Nakamura", "pending_count": 2, "avg_days_waiting":  8.5, "max_days_waiting":  9, "total_amount_pending": 23420.30},
                {"approver": "LOKAFOR",   "approver_name": "L Okafor",   "pending_count": 2, "avg_days_waiting":  6.5, "max_days_waiting":  7, "total_amount_pending": 11080.00},
                {"approver": "KCHEN",     "approver_name": "K Chen",     "pending_count": 2, "avg_days_waiting":  4.5, "max_days_waiting":  5, "total_amount_pending": 11860.00},
            ],
        },
    },
    "payment_run_optimizer": {
        "severity": "HIGH",
        "summary": "$24,300 discounts in window. $87,420 over 90 days.",
        "actions": [
            "Build pay batch around URGENT discount-window invoices first.",
            "Bring forward over-90 buckets that are blocking supplier credit.",
            "Stagger high-value EFT runs to avoid bank cut-off conflicts.",
        ],
        "row_count": 18,
        "query_rows": {
            "discounts": [
                {"invoice_id": 82001, "invoice_num": "INV-46010", "vendor_name": "Acme Industrial Supply", "discount_date": "2026-05-08", "discount_amount":  860.00, "gross_amount": 17200.00, "invoice_currency_code": "USD", "days_to_discount":  2, "urgency": "URGENT",    "total_discount_available": 24300.00},
                {"invoice_id": 82015, "invoice_num": "INV-46035", "vendor_name": "Continental Steel Co",   "discount_date": "2026-05-08", "discount_amount": 1240.00, "gross_amount": 24800.00, "invoice_currency_code": "USD", "days_to_discount":  2, "urgency": "URGENT",    "total_discount_available": 24300.00},
                {"invoice_id": 82029, "invoice_num": "INV-46062", "vendor_name": "Globex Components",      "discount_date": "2026-05-09", "discount_amount":  580.00, "gross_amount": 11600.00, "invoice_currency_code": "USD", "days_to_discount":  3, "urgency": "URGENT",    "total_discount_available": 24300.00},
                {"invoice_id": 82041, "invoice_num": "INV-46088", "vendor_name": "Helios Power & Light",   "discount_date": "2026-05-10", "discount_amount":  470.00, "gross_amount":  9400.00, "invoice_currency_code": "USD", "days_to_discount":  4, "urgency": "URGENT",    "total_discount_available": 24300.00},
                {"invoice_id": 82057, "invoice_num": "INV-46110", "vendor_name": "Jupiter Maintenance",    "discount_date": "2026-05-12", "discount_amount":  320.00, "gross_amount":  6400.00, "invoice_currency_code": "USD", "days_to_discount":  6, "urgency": "URGENT",    "total_discount_available": 24300.00},
                {"invoice_id": 82076, "invoice_num": "INV-46141", "vendor_name": "Kestrel Plastics",       "discount_date": "2026-05-14", "discount_amount":  290.00, "gross_amount":  5800.00, "invoice_currency_code": "USD", "days_to_discount":  8, "urgency": "THIS_WEEK", "total_discount_available": 24300.00},
                {"invoice_id": 82094, "invoice_num": "INV-46172", "vendor_name": "EcoPack Materials",      "discount_date": "2026-05-16", "discount_amount":  610.00, "gross_amount": 12200.00, "invoice_currency_code": "USD", "days_to_discount": 10, "urgency": "UPCOMING",  "total_discount_available": 24300.00},
            ],
            "supplier_aging": [
                {"vendor_id": 12001, "vendor_name": "Acme Industrial Supply", "invoice_count": 14, "bucket_0_30":  18420.00, "bucket_31_60":  6240.00, "bucket_61_90":  4120.00, "bucket_over_90": 22180.00, "total_outstanding": 50960.00},
                {"vendor_id": 12044, "vendor_name": "Continental Steel Co",   "invoice_count":  9, "bucket_0_30":  24300.00, "bucket_31_60":  3210.00, "bucket_61_90":  1180.00, "bucket_over_90": 18900.00, "total_outstanding": 47590.00},
                {"vendor_id": 12080, "vendor_name": "Globex Components",      "invoice_count":  6, "bucket_0_30":  11020.00, "bucket_31_60":  4150.00, "bucket_61_90":     0.00, "bucket_over_90": 14620.00, "total_outstanding": 29790.00},
                {"vendor_id": 12100, "vendor_name": "Helios Power & Light",   "invoice_count":  5, "bucket_0_30":   8200.00, "bucket_31_60":  1980.00, "bucket_61_90":   620.00, "bucket_over_90": 11400.00, "total_outstanding": 22200.00},
                {"vendor_id": 12120, "vendor_name": "Jupiter Maintenance",    "invoice_count":  3, "bucket_0_30":   3140.00, "bucket_31_60":     0.00, "bucket_61_90":     0.00, "bucket_over_90": 12180.00, "total_outstanding": 15320.00},
                {"vendor_id": 12150, "vendor_name": "Kestrel Plastics",       "invoice_count":  2, "bucket_0_30":   2890.00, "bucket_31_60":   980.00, "bucket_61_90":     0.00, "bucket_over_90":  8140.00, "total_outstanding": 12010.00},
            ],
        },
    },
    "discount_capture": {
        "severity": "HIGH",
        "summary": "$24,300 discounts available. 5 expire within 3 days.",
        "actions": [
            "Pay urgent (<= 3 days) discount invoices today.",
            "Confirm cash position before triggering early-pay batch.",
            "Capture missed-discount metric for weekly cash report.",
        ],
        "row_count": 18,
        "query_rows": {
            "discounts": [
                {"invoice_id": 82001, "invoice_num": "INV-46010", "vendor_name": "Acme Industrial Supply", "discount_date": "2026-05-08", "discount_amount":  860.00, "gross_amount": 17200.00, "invoice_currency_code": "USD", "days_to_discount":  2, "urgency": "URGENT",    "total_discount_available": 24300.00},
                {"invoice_id": 82015, "invoice_num": "INV-46035", "vendor_name": "Continental Steel Co",   "discount_date": "2026-05-08", "discount_amount": 1240.00, "gross_amount": 24800.00, "invoice_currency_code": "USD", "days_to_discount":  2, "urgency": "URGENT",    "total_discount_available": 24300.00},
                {"invoice_id": 82029, "invoice_num": "INV-46062", "vendor_name": "Globex Components",      "discount_date": "2026-05-09", "discount_amount":  580.00, "gross_amount": 11600.00, "invoice_currency_code": "USD", "days_to_discount":  3, "urgency": "URGENT",    "total_discount_available": 24300.00},
                {"invoice_id": 82041, "invoice_num": "INV-46088", "vendor_name": "Helios Power & Light",   "discount_date": "2026-05-10", "discount_amount":  470.00, "gross_amount":  9400.00, "invoice_currency_code": "USD", "days_to_discount":  4, "urgency": "URGENT",    "total_discount_available": 24300.00},
                {"invoice_id": 82057, "invoice_num": "INV-46110", "vendor_name": "Jupiter Maintenance",    "discount_date": "2026-05-12", "discount_amount":  320.00, "gross_amount":  6400.00, "invoice_currency_code": "USD", "days_to_discount":  6, "urgency": "URGENT",    "total_discount_available": 24300.00},
                {"invoice_id": 82076, "invoice_num": "INV-46141", "vendor_name": "Kestrel Plastics",       "discount_date": "2026-05-14", "discount_amount":  290.00, "gross_amount":  5800.00, "invoice_currency_code": "USD", "days_to_discount":  8, "urgency": "THIS_WEEK", "total_discount_available": 24300.00},
                {"invoice_id": 82094, "invoice_num": "INV-46172", "vendor_name": "EcoPack Materials",      "discount_date": "2026-05-16", "discount_amount":  610.00, "gross_amount": 12200.00, "invoice_currency_code": "USD", "days_to_discount": 10, "urgency": "UPCOMING",  "total_discount_available": 24300.00},
            ],
        },
    },
    "prepayment_apply": {
        "severity": "MEDIUM",
        "summary": "3 open prepayments totalling $42,000.",
        "actions": [
            "Match each prepayment against open standard invoices for the same vendor.",
            "Apply prepayment in AP > Invoices > Apply / Unapply Prepayments.",
            "Follow up on prepayments older than 90 days for refund or write-off.",
        ],
        "row_count": 3,
        "query_rows": {
            "open_prepayments": [
                {"invoice_id": 83001, "invoice_num": "PREPAY-2120", "invoice_date": "2026-01-20", "vendor_name": "Acme Industrial Supply", "prepayment_amount": 18000.00, "invoice_currency_code": "USD", "unapplied_amount": 18000.00, "days_outstanding": 106, "wfapproval_status": "APPROVED", "total_prepay_amount": 42000.00},
                {"invoice_id": 83042, "invoice_num": "PREPAY-2155", "invoice_date": "2026-02-12", "vendor_name": "Continental Steel Co",   "prepayment_amount": 14000.00, "invoice_currency_code": "USD", "unapplied_amount": 14000.00, "days_outstanding":  83, "wfapproval_status": "APPROVED", "total_prepay_amount": 42000.00},
                {"invoice_id": 83074, "invoice_num": "PREPAY-2188", "invoice_date": "2026-03-04", "vendor_name": "Globex Components",      "prepayment_amount": 10000.00, "invoice_currency_code": "USD", "unapplied_amount": 10000.00, "days_outstanding":  63, "wfapproval_status": "APPROVED", "total_prepay_amount": 42000.00},
            ],
            "supplier_aging": [
                {"vendor_id": 12001, "vendor_name": "Acme Industrial Supply", "invoice_count": 14, "bucket_0_30": 18420.00, "bucket_31_60":  6240.00, "bucket_61_90":  4120.00, "bucket_over_90": 22180.00, "total_outstanding": 50960.00},
                {"vendor_id": 12044, "vendor_name": "Continental Steel Co",   "invoice_count":  9, "bucket_0_30": 24300.00, "bucket_31_60":  3210.00, "bucket_61_90":  1180.00, "bucket_over_90": 18900.00, "total_outstanding": 47590.00},
                {"vendor_id": 12080, "vendor_name": "Globex Components",      "invoice_count":  6, "bucket_0_30": 11020.00, "bucket_31_60":  4150.00, "bucket_61_90":     0.00, "bucket_over_90": 14620.00, "total_outstanding": 29790.00},
            ],
        },
    },
    "supplier_risk": {
        "severity": "HIGH",
        "summary": "22 non-PO invoices ($143,200). $87,420 aged > 90d.",
        "actions": [
            "Sample 10 highest-value non-PO invoices for control review.",
            "Verify bank-detail change history for top-spend suppliers.",
            "Flag suppliers in >90 bucket to procurement for credit review.",
        ],
        "row_count": 22,
        "query_rows": {
            "non_po_invoices": [
                {"invoice_id": 84001, "invoice_num": "NPO-7012", "invoice_date": "2026-04-12", "vendor_name": "Indigo IT Services",     "invoice_amount": 18420.00, "invoice_currency_code": "USD", "wfapproval_status": "APPROVED", "posting_status": "Y", "source": "Manual", "days_old": 24, "total_non_po_amount": 143200.00},
                {"invoice_id": 84015, "invoice_num": "NPO-7035", "invoice_date": "2026-04-15", "vendor_name": "Sigma Consulting LLC",   "invoice_amount": 24300.00, "invoice_currency_code": "USD", "wfapproval_status": "APPROVED", "posting_status": "Y", "source": "Manual", "days_old": 21, "total_non_po_amount": 143200.00},
                {"invoice_id": 84028, "invoice_num": "NPO-7062", "invoice_date": "2026-04-19", "vendor_name": "Helios Power & Light",   "invoice_amount":  6480.00, "invoice_currency_code": "USD", "wfapproval_status": "APPROVED", "posting_status": "Y", "source": "Import", "days_old": 17, "total_non_po_amount": 143200.00},
                {"invoice_id": 84046, "invoice_num": "NPO-7088", "invoice_date": "2026-04-22", "vendor_name": "City Utilities Board",   "invoice_amount":  3210.00, "invoice_currency_code": "USD", "wfapproval_status": "APPROVED", "posting_status": "Y", "source": "Manual", "days_old": 14, "total_non_po_amount": 143200.00},
                {"invoice_id": 84062, "invoice_num": "NPO-7115", "invoice_date": "2026-04-25", "vendor_name": "Sigma Consulting LLC",   "invoice_amount": 12640.00, "invoice_currency_code": "USD", "wfapproval_status": "APPROVED", "posting_status": "N", "source": "Manual", "days_old": 11, "total_non_po_amount": 143200.00},
                {"invoice_id": 84080, "invoice_num": "NPO-7142", "invoice_date": "2026-04-27", "vendor_name": "Lex Legal Services",     "invoice_amount":  9800.00, "invoice_currency_code": "USD", "wfapproval_status": "APPROVED", "posting_status": "Y", "source": "Manual", "days_old":  9, "total_non_po_amount": 143200.00},
                {"invoice_id": 84099, "invoice_num": "NPO-7170", "invoice_date": "2026-04-29", "vendor_name": "Indigo IT Services",     "invoice_amount":  5240.00, "invoice_currency_code": "USD", "wfapproval_status": "APPROVED", "posting_status": "Y", "source": "Import", "days_old":  7, "total_non_po_amount": 143200.00},
            ],
            "supplier_aging": [
                {"vendor_id": 12001, "vendor_name": "Acme Industrial Supply", "invoice_count": 14, "bucket_0_30":  18420.00, "bucket_31_60":  6240.00, "bucket_61_90":  4120.00, "bucket_over_90": 22180.00, "total_outstanding": 50960.00},
                {"vendor_id": 12044, "vendor_name": "Continental Steel Co",   "invoice_count":  9, "bucket_0_30":  24300.00, "bucket_31_60":  3210.00, "bucket_61_90":  1180.00, "bucket_over_90": 18900.00, "total_outstanding": 47590.00},
                {"vendor_id": 12080, "vendor_name": "Globex Components",      "invoice_count":  6, "bucket_0_30":  11020.00, "bucket_31_60":  4150.00, "bucket_61_90":     0.00, "bucket_over_90": 14620.00, "total_outstanding": 29790.00},
                {"vendor_id": 12100, "vendor_name": "Helios Power & Light",   "invoice_count":  5, "bucket_0_30":   8200.00, "bucket_31_60":  1980.00, "bucket_61_90":   620.00, "bucket_over_90": 11400.00, "total_outstanding": 22200.00},
                {"vendor_id": 12120, "vendor_name": "Jupiter Maintenance",    "invoice_count":  3, "bucket_0_30":   3140.00, "bucket_31_60":     0.00, "bucket_61_90":     0.00, "bucket_over_90": 12180.00, "total_outstanding": 15320.00},
                {"vendor_id": 12150, "vendor_name": "Kestrel Plastics",       "invoice_count":  2, "bucket_0_30":   2890.00, "bucket_31_60":   980.00, "bucket_61_90":     0.00, "bucket_over_90":  8140.00, "total_outstanding": 12010.00},
            ],
        },
    },
    "period_close": {
        "severity": "HIGH",
        "summary": "32 unposted, 8 pending approval, avg cycle 6.4d, 3 open prepayments.",
        "actions": [
            "Sweep unposted invoices and resolve before period close.",
            "Run mass-validate to clear validation holds.",
            "Apply or refund prepayments to clean AP sub-ledger.",
            "Post accruals for received-not-invoiced before final journal.",
        ],
        "row_count": 32,
        "query_rows": {
            "summary": [
                {"total_invoices": 248, "posted_count": 216, "unposted_count": 32, "pending_approval": 8, "total_amount": 1240380.00, "avg_invoice_amount": 5001.50, "source_count": 4},
            ],
            "invoice_health": [
                {"invoice_id": 85001, "invoice_num": "INV-47010", "invoice_date": "2026-04-09", "vendor_name": "Acme Industrial Supply", "invoice_amount": 18420.00, "invoice_currency_code": "USD", "wfapproval_status": "REQUIRED", "posting_status": "N", "source": "Manual", "days_open": 27},
                {"invoice_id": 85019, "invoice_num": "INV-47032", "invoice_date": "2026-04-12", "vendor_name": "BlueRiver Logistics",    "invoice_amount":  9120.00, "invoice_currency_code": "USD", "wfapproval_status": "REQUIRED", "posting_status": "N", "source": "Import", "days_open": 24},
                {"invoice_id": 85044, "invoice_num": "INV-47065", "invoice_date": "2026-04-16", "vendor_name": "Continental Steel Co",   "invoice_amount": 22180.00, "invoice_currency_code": "USD", "wfapproval_status": "INITIATED","posting_status": "N", "source": "Manual", "days_open": 20},
                {"invoice_id": 85072, "invoice_num": "INV-47101", "invoice_date": "2026-04-20", "vendor_name": "Delta Office Solutions", "invoice_amount":  1240.30, "invoice_currency_code": "USD", "wfapproval_status": "REQUIRED", "posting_status": "N", "source": "Manual", "days_open": 16},
                {"invoice_id": 85099, "invoice_num": "INV-47138", "invoice_date": "2026-04-24", "vendor_name": "EcoPack Materials",      "invoice_amount":  4980.00, "invoice_currency_code": "USD", "wfapproval_status": "INITIATED","posting_status": "N", "source": "Import", "days_open": 12},
                {"invoice_id": 85120, "invoice_num": "INV-47166", "invoice_date": "2026-04-28", "vendor_name": "FrostByte Cooling",      "invoice_amount":  6100.00, "invoice_currency_code": "USD", "wfapproval_status": "REQUIRED", "posting_status": "N", "source": "Manual", "days_open":  8},
                {"invoice_id": 85148, "invoice_num": "INV-47201", "invoice_date": "2026-05-02", "vendor_name": "Globex Components",      "invoice_amount":  8540.00, "invoice_currency_code": "USD", "wfapproval_status": "REQUIRED", "posting_status": "N", "source": "Import", "days_open":  4},
            ],
            "cycle_time": [
                {"invoice_id": 86010, "invoice_num": "POSTED-50010", "vendor_name": "Acme Industrial Supply", "invoice_amount": 12420.00, "invoice_currency_code": "USD", "source": "Manual", "received_date": "2026-04-10", "posting_date": "2026-04-13", "cycle_days":  3, "cycle_band": "FAST",     "avg_cycle_days": 6.4},
                {"invoice_id": 86022, "invoice_num": "POSTED-50028", "vendor_name": "BlueRiver Logistics",    "invoice_amount":  4280.50, "invoice_currency_code": "USD", "source": "Import", "received_date": "2026-04-12", "posting_date": "2026-04-19", "cycle_days":  7, "cycle_band": "NORMAL",   "avg_cycle_days": 6.4},
                {"invoice_id": 86041, "invoice_num": "POSTED-50051", "vendor_name": "Continental Steel Co",   "invoice_amount": 18900.00, "invoice_currency_code": "USD", "source": "Manual", "received_date": "2026-04-15", "posting_date": "2026-04-25", "cycle_days": 10, "cycle_band": "SLOW",     "avg_cycle_days": 6.4},
                {"invoice_id": 86060, "invoice_num": "POSTED-50080", "vendor_name": "Globex Components",      "invoice_amount":  6320.00, "invoice_currency_code": "USD", "source": "Import", "received_date": "2026-04-18", "posting_date": "2026-05-04", "cycle_days": 16, "cycle_band": "CRITICAL", "avg_cycle_days": 6.4},
            ],
            "open_prepayments": [
                {"invoice_id": 83001, "invoice_num": "PREPAY-2120", "invoice_date": "2026-01-20", "vendor_name": "Acme Industrial Supply", "prepayment_amount": 18000.00, "invoice_currency_code": "USD", "unapplied_amount": 18000.00, "days_outstanding": 106, "wfapproval_status": "APPROVED"},
                {"invoice_id": 83042, "invoice_num": "PREPAY-2155", "invoice_date": "2026-02-12", "vendor_name": "Continental Steel Co",   "prepayment_amount": 14000.00, "invoice_currency_code": "USD", "unapplied_amount": 14000.00, "days_outstanding":  83, "wfapproval_status": "APPROVED"},
                {"invoice_id": 83074, "invoice_num": "PREPAY-2188", "invoice_date": "2026-03-04", "vendor_name": "Globex Components",      "prepayment_amount": 10000.00, "invoice_currency_code": "USD", "unapplied_amount": 10000.00, "days_outstanding":  63, "wfapproval_status": "APPROVED"},
            ],
        },
    },
    "tax_wht_validator": {
        "severity": "MEDIUM",
        "summary": "3 tax-related holds.",
        "actions": [
            "Compare invoice tax line to PO expected tax.",
            "Validate supplier tax registration in ZX_PARTY_TAX_PROFILE.",
            "Recall WHT calc for invoices flagged with TAX hold.",
        ],
        "row_count": 3,
        "query_rows": {
            "match_exceptions": [
                {"invoice_id": 87001, "invoice_num": "INV-48010", "vendor_name": "EcoPack Materials",      "hold_type": "TAX",     "hold_reason": "Invoice tax 18% vs PO expected 12%",        "days_on_hold": 6, "invoice_amount":  4280.00, "invoice_currency_code": "USD", "source": "Import"},
                {"invoice_id": 87018, "invoice_num": "INV-48034", "vendor_name": "Sigma Consulting LLC",   "hold_type": "TAX WHT", "hold_reason": "WHT not deducted at source",                "days_on_hold": 4, "invoice_amount": 11820.00, "invoice_currency_code": "USD", "source": "Manual"},
                {"invoice_id": 87034, "invoice_num": "INV-48060", "vendor_name": "Helios Power & Light",   "hold_type": "TAX",     "hold_reason": "Tax registration expired in ZX profile",   "days_on_hold": 2, "invoice_amount":  3210.00, "invoice_currency_code": "USD", "source": "Manual"},
            ],
            "cycle_time": [
                {"invoice_id": 87001, "invoice_num": "INV-48010", "vendor_name": "EcoPack Materials",     "invoice_amount":  4280.00, "invoice_currency_code": "USD", "source": "Import", "received_date": "2026-04-30", "posting_date": "2026-05-04", "cycle_days":  4, "cycle_band": "NORMAL",   "avg_cycle_days": 5.0},
                {"invoice_id": 87018, "invoice_num": "INV-48034", "vendor_name": "Sigma Consulting LLC",  "invoice_amount": 11820.00, "invoice_currency_code": "USD", "source": "Manual", "received_date": "2026-04-28", "posting_date": "2026-05-05", "cycle_days":  7, "cycle_band": "NORMAL",   "avg_cycle_days": 5.0},
                {"invoice_id": 87034, "invoice_num": "INV-48060", "vendor_name": "Helios Power & Light",  "invoice_amount":  3210.00, "invoice_currency_code": "USD", "source": "Manual", "received_date": "2026-05-02", "posting_date": "2026-05-06", "cycle_days":  4, "cycle_band": "NORMAL",   "avg_cycle_days": 5.0},
            ],
        },
    },
}


SEVERITY_ORDER = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "INFO": 3}
