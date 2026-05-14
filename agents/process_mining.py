"""
Process Mining orchestrator.

Pulls an event log (live SQL or generated demo), runs analytics from
tools.event_log, supports filters, and provides drill-down to a single case
plus its parent objects (PO header, lines, receipts, invoices, holds, payments).
"""
from __future__ import annotations

import logging
import random
import time
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional

from config.process_mining import EVENT_LOG_SQL, ACTIVITY_BY_KEY
from tools import event_log as elog


logger = logging.getLogger(__name__)


# ─── Cache ───────────────────────────────────────────────────────────────────
# A single-process cache keyed by (days_back, demo_mode, supplier, buyer, min_amount).
# Keeps drill-down endpoints fast by avoiding a re-query for each click.

_CACHE: Dict[str, Any] = {"key": None, "events": [], "cases": {}, "ts": 0.0}
_CACHE_TTL_S = 600  # 10 minutes


def _cache_key(filters: Dict[str, Any], demo_mode: bool) -> str:
    return "|".join([
        str(demo_mode),
        str(filters.get("days_back") or 90),
        str(filters.get("vendor") or ""),
        str(filters.get("buyer") or ""),
        str(filters.get("min_amount") or 0),
        str(filters.get("doc_type") or ""),
    ])


def _is_cache_fresh(key: str) -> bool:
    return _CACHE["key"] == key and (time.time() - _CACHE["ts"]) < _CACHE_TTL_S


# ─── Public API ──────────────────────────────────────────────────────────────

def analyze(filters: Dict[str, Any], oracle_db) -> Dict[str, Any]:
    """Fetch event log and compute every analytic surface."""
    started = time.time()
    demo_mode = (oracle_db is None) or oracle_db.demo_mode
    key = _cache_key(filters, demo_mode)

    used_demo_fallback = False
    if _is_cache_fresh(key):
        events = _CACHE["events"]
        cases = _CACHE["cases"]
    else:
        if demo_mode:
            raw = _demo_events(filters)
        else:
            raw = _live_events(filters, oracle_db)
            if not raw:
                # Live event log failed or returned nothing — fall back to demo
                # so the page is still useful (e.g. schema variation, no P2P
                # data in window). Mark mode so the UI can show a banner.
                logger.info("Process mining: live event log empty, using demo fallback.")
                raw = _demo_events(filters)
                used_demo_fallback = True
        events = elog.normalize_events(raw)
        events = _apply_filters(events, filters)
        cases = elog.build_cases(events)
        _CACHE.update({"key": key, "events": events, "cases": cases, "ts": time.time(),
                       "fallback": used_demo_fallback})

    variants = elog.top_variants(cases, top_n=12)
    dfg      = elog.directly_follows(cases)
    bottle   = elog.bottlenecks(dfg, top_n=12)
    rew      = elog.rework(cases)
    ct       = elog.cycle_time(cases)
    conf     = elog.conformance(cases)

    return {
        "demo_mode":         demo_mode or used_demo_fallback,
        "demo_fallback":     used_demo_fallback,
        "filters":           filters,
        "event_count":       len(events),
        "case_count":     len(cases),
        "execution_time_ms": int((time.time() - started) * 1000),
        "variants":       variants,
        "process_map":    dfg,
        "bottlenecks":    bottle,
        "rework":         rew,
        "cycle_time":     ct,
        "conformance":    conf,
        "vendors":        _distinct_vendors(events),
    }


def case_drill(case_id: str, oracle_db) -> Dict[str, Any]:
    """Return timeline + parent objects for one case."""
    cases = _CACHE.get("cases") or {}
    if case_id not in cases:
        # Re-fetch with default filter to repopulate cache.
        analyze({"days_back": 90}, oracle_db)
        cases = _CACHE.get("cases") or {}

    timeline = elog.case_timeline(cases, case_id)
    parents = _fetch_parents(case_id, cases.get(case_id, []), oracle_db)
    return {**timeline, "parents": parents}


def cases_for_variant(sequence: List[str], oracle_db, limit: int = 50) -> Dict[str, Any]:
    cases = _CACHE.get("cases") or {}
    if not cases:
        analyze({"days_back": 90}, oracle_db)
        cases = _CACHE.get("cases") or {}
    return {"cases": elog.cases_for_variant(cases, sequence, limit=limit)}


def cases_for_edge(from_act: str, to_act: str, oracle_db, limit: int = 50) -> Dict[str, Any]:
    cases = _CACHE.get("cases") or {}
    if not cases:
        analyze({"days_back": 90}, oracle_db)
        cases = _CACHE.get("cases") or {}
    return {"cases": elog.cases_for_edge(cases, from_act, to_act, limit=limit)}


# ─── Filtering ───────────────────────────────────────────────────────────────

def _apply_filters(events: List[Dict[str, Any]], f: Dict[str, Any]) -> List[Dict[str, Any]]:
    vendor = (f.get("vendor") or "").strip().lower() or None
    buyer = (f.get("buyer") or "").strip() or None
    try:
        min_amt = float(f.get("min_amount") or 0)
    except (TypeError, ValueError):
        min_amt = 0.0
    doc_type = (f.get("doc_type") or "").strip().lower() or None

    if not (vendor or buyer or min_amt or doc_type):
        return events

    keep_cases = set()
    by_case: Dict[str, List[Dict[str, Any]]] = {}
    for e in events:
        by_case.setdefault(e["case_id"], []).append(e)

    for cid, evs in by_case.items():
        v = next((e.get("vendor_name") for e in evs if e.get("vendor_name")), None)
        amt = next((e.get("amount") for e in evs if e.get("amount") is not None), 0)
        rsc = next((e.get("resource") for e in evs if e.get("resource")), None)
        dt  = (cid.split(":", 1)[0] if ":" in cid else "po").lower()

        if vendor and (not v or vendor not in v.lower()):
            continue
        if buyer and (not rsc or buyer not in str(rsc)):
            continue
        if min_amt and (amt or 0) < min_amt:
            continue
        if doc_type and not dt.startswith(doc_type[:3]):
            continue
        keep_cases.add(cid)

    return [e for e in events if e["case_id"] in keep_cases]


def _distinct_vendors(events: List[Dict[str, Any]]) -> List[str]:
    s = set()
    for e in events:
        v = e.get("vendor_name")
        if v:
            s.add(v)
    return sorted(s)[:50]


# ─── Live event log fetch ────────────────────────────────────────────────────

def _live_events(filters: Dict[str, Any], oracle_db) -> List[Dict[str, Any]]:
    days_back = max(7, min(365, int(filters.get("days_back") or 90)))
    sql = EVENT_LOG_SQL.format(days_back=days_back)
    try:
        rows = oracle_db.execute_query(sql, max_rows=20000)
        return rows
    except Exception as exc:
        logger.warning("Process mining live event log error: %s", exc)
        return []


# ─── Demo event generator ────────────────────────────────────────────────────

_VENDORS = [
    ("AcmeWidget Co", 1001), ("Globex Industries", 1002), ("Initech LLC", 1003),
    ("Soylent Foods", 1004), ("Hooli Cloud", 1005), ("Pied Piper Inc", 1006),
    ("Stark Industries", 1007), ("Wayne Enterprises", 1008),
    ("Dunder Mifflin", 1009), ("Wonka Confectionery", 1010),
    ("Tyrell Robotics", 1011), ("Cyberdyne Systems", 1012),
]
_BUYERS = ["A.Ng", "B.Patel", "C.Liu", "D.Roy", "E.Kim", "F.Singh", "G.Hart", "H.Nakamura"]
_AP_USERS = ["AP1.Costa", "AP2.Ali", "AP3.Diaz", "AP4.Park"]


def _demo_events(filters: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Generate ~280 cases across 6 variant archetypes for realistic mining."""
    days_back = max(7, min(365, int(filters.get("days_back") or 90)))
    rng = random.Random(42)

    now = datetime.utcnow()
    horizon_start = now - timedelta(days=days_back)

    archetypes = [
        ("happy",         0.45, _archetype_happy),
        ("hold_rework",   0.22, _archetype_hold_rework),
        ("po_revised",    0.10, _archetype_po_revised),
        ("late_payment",  0.10, _archetype_late_payment),
        ("non_po",        0.07, _archetype_non_po),
        ("non_conformant", 0.06, _archetype_non_conformant),
    ]

    target_cases = 280
    events: List[Dict[str, Any]] = []
    next_po = 50000
    next_inv = 80000
    next_check = 90000

    for i in range(target_cases):
        roll = rng.random()
        cum = 0.0
        archetype_fn = archetypes[0][2]
        for name, weight, fn in archetypes:
            cum += weight
            if roll <= cum:
                archetype_fn = fn
                break

        case_start = horizon_start + timedelta(
            seconds=rng.randint(0, max(1, int((now - horizon_start).total_seconds() - 3600))))
        vendor_name, vendor_id = rng.choice(_VENDORS)
        amount = round(rng.uniform(500, 75000), 2)
        next_po += 1
        next_inv += 1
        next_check += 1

        ctx = {
            "rng": rng,
            "case_start": case_start,
            "vendor_id": vendor_id,
            "vendor_name": vendor_name,
            "amount": amount,
            "po_id": next_po,
            "po_num": f"PO-{next_po}",
            "invoice_id": next_inv,
            "invoice_num": f"INV-{next_inv}",
            "check_id": next_check,
            "check_num": f"CHK-{next_check}",
            "buyer": rng.choice(_BUYERS),
            "ap_user": rng.choice(_AP_USERS),
        }
        events.extend(archetype_fn(ctx))

    return events


# ─── Helpers ─────────────────────────────────────────────────────────────────

def _ev(case_id: str, activity: str, ts: datetime, ctx: Dict[str, Any],
        attribute1: Optional[str] = None) -> Dict[str, Any]:
    return {
        "case_id":       case_id,
        "activity":      activity,
        "ts":            ts,
        "resource":      ctx.get("buyer") if "PO" in activity or "REQ" in activity or "GOODS" in activity
                          else ctx.get("ap_user"),
        "doc_id":        ctx.get("po_id") if "PO" in activity or "REQ" in activity
                          else ctx.get("invoice_id") if "INVOICE" in activity or "HOLD" in activity
                          else ctx.get("check_id") if "PAYMENT" in activity
                          else None,
        "doc_num":       ctx.get("po_num") if "PO" in activity or "REQ" in activity
                          else ctx.get("invoice_num") if "INVOICE" in activity or "HOLD" in activity
                          else ctx.get("check_num") if "PAYMENT" in activity
                          else None,
        "vendor_id":     ctx.get("vendor_id"),
        "vendor_name":   ctx.get("vendor_name"),
        "amount":        ctx.get("amount"),
        "currency_code": "USD",
        "attribute1":    attribute1,
    }


def _hours(rng: random.Random, lo: float, hi: float) -> timedelta:
    return timedelta(hours=rng.uniform(lo, hi))


def _archetype_happy(ctx: Dict[str, Any]) -> List[Dict[str, Any]]:
    rng = ctx["rng"]; t = ctx["case_start"]
    cid = f"PO:{ctx['po_id']}"
    out = []
    for act, lo, hi in [
        ("REQ_CREATED",       0,    1),
        ("REQ_APPROVED",      4,    24),
        ("PO_CREATED",        2,    8),
        ("PO_APPROVED",       2,    16),
        ("GOODS_RECEIVED",    72,   240),
        ("GOODS_DELIVERED",   1,    8),
        ("INVOICE_RECEIVED",  24,   96),
        ("INVOICE_VALIDATED", 1,    12),
        ("INVOICE_APPROVED",  4,    24),
        ("INVOICE_POSTED",    1,    8),
        ("PAYMENT_ISSUED",    72,   336),
        ("PAYMENT_CLEARED",   24,   72),
    ]:
        t += _hours(rng, lo, hi)
        out.append(_ev(cid, act, t, ctx))
    return out


def _archetype_hold_rework(ctx: Dict[str, Any]) -> List[Dict[str, Any]]:
    rng = ctx["rng"]; t = ctx["case_start"]
    cid = f"PO:{ctx['po_id']}"
    out = []
    base = [
        ("REQ_CREATED",       0,    1),
        ("REQ_APPROVED",      4,    24),
        ("PO_CREATED",        2,    8),
        ("PO_APPROVED",       2,    16),
        ("GOODS_RECEIVED",    72,   240),
        ("GOODS_DELIVERED",   1,    8),
        ("INVOICE_RECEIVED",  24,   96),
        ("INVOICE_VALIDATED", 1,    12),
    ]
    for act, lo, hi in base:
        t += _hours(rng, lo, hi); out.append(_ev(cid, act, t, ctx))

    # 1-3 hold cycles
    hold_types = ["PRICE", "QTY RECEIVED", "TAX", "VARIANCE"]
    for _ in range(rng.randint(1, 3)):
        t += _hours(rng, 1, 12); out.append(_ev(cid, "HOLD_PLACED", t, ctx, rng.choice(hold_types)))
        t += _hours(rng, 24, 168); out.append(_ev(cid, "HOLD_RELEASED", t, ctx))

    for act, lo, hi in [
        ("INVOICE_APPROVED", 4, 24),
        ("INVOICE_POSTED",   1, 8),
        ("PAYMENT_ISSUED",   72, 336),
        ("PAYMENT_CLEARED",  24, 72),
    ]:
        t += _hours(rng, lo, hi); out.append(_ev(cid, act, t, ctx))
    return out


def _archetype_po_revised(ctx: Dict[str, Any]) -> List[Dict[str, Any]]:
    rng = ctx["rng"]; t = ctx["case_start"]
    cid = f"PO:{ctx['po_id']}"
    out = []
    for act, lo, hi in [
        ("REQ_CREATED",  0, 1),
        ("REQ_APPROVED", 4, 24),
        ("PO_CREATED",   2, 8),
        ("PO_APPROVED",  2, 16),
    ]:
        t += _hours(rng, lo, hi); out.append(_ev(cid, act, t, ctx))

    for _ in range(rng.randint(1, 2)):
        t += _hours(rng, 24, 96); out.append(_ev(cid, "PO_REVISED", t, ctx, str(rng.randint(1, 3))))
        t += _hours(rng, 1, 16);  out.append(_ev(cid, "PO_APPROVED", t, ctx))

    for act, lo, hi in [
        ("GOODS_RECEIVED",    72,  240),
        ("GOODS_DELIVERED",   1,   8),
        ("INVOICE_RECEIVED",  24,  96),
        ("INVOICE_VALIDATED", 1,   12),
        ("INVOICE_APPROVED",  4,   24),
        ("INVOICE_POSTED",    1,   8),
        ("PAYMENT_ISSUED",    72,  336),
        ("PAYMENT_CLEARED",   24,  72),
    ]:
        t += _hours(rng, lo, hi); out.append(_ev(cid, act, t, ctx))
    return out


def _archetype_late_payment(ctx: Dict[str, Any]) -> List[Dict[str, Any]]:
    rng = ctx["rng"]; t = ctx["case_start"]
    cid = f"PO:{ctx['po_id']}"
    out = []
    for act, lo, hi in [
        ("REQ_CREATED",       0,    1),
        ("REQ_APPROVED",      4,    24),
        ("PO_CREATED",        2,    8),
        ("PO_APPROVED",       2,    16),
        ("GOODS_RECEIVED",    72,   240),
        ("GOODS_DELIVERED",   1,    8),
        ("INVOICE_RECEIVED",  24,   96),
        ("INVOICE_VALIDATED", 1,    12),
        ("INVOICE_APPROVED",  4,    24),
        ("INVOICE_POSTED",    1,    8),
        ("PAYMENT_ISSUED",    600,  1400),  # late
        ("PAYMENT_CLEARED",   24,   72),
    ]:
        t += _hours(rng, lo, hi); out.append(_ev(cid, act, t, ctx))
    return out


def _archetype_non_po(ctx: Dict[str, Any]) -> List[Dict[str, Any]]:
    rng = ctx["rng"]; t = ctx["case_start"]
    cid = f"INV:{ctx['invoice_id']}"
    out = []
    for act, lo, hi in [
        ("INVOICE_RECEIVED",  0,    1),
        ("INVOICE_VALIDATED", 1,    12),
        ("INVOICE_APPROVED",  8,    72),
        ("INVOICE_POSTED",    1,    8),
        ("PAYMENT_ISSUED",    96,   336),
        ("PAYMENT_CLEARED",   24,   72),
    ]:
        t += _hours(rng, lo, hi); out.append(_ev(cid, act, t, ctx))
    return out


def _archetype_non_conformant(ctx: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Skips required steps to feed conformance checking."""
    rng = ctx["rng"]; t = ctx["case_start"]
    cid = f"PO:{ctx['po_id']}"
    out = []
    skip = rng.choice(["no_receipt", "pay_before_post", "no_validate"])

    for act, lo, hi in [
        ("REQ_CREATED",  0, 1),
        ("REQ_APPROVED", 4, 24),
        ("PO_CREATED",   2, 8),
        ("PO_APPROVED",  2, 16),
    ]:
        t += _hours(rng, lo, hi); out.append(_ev(cid, act, t, ctx))

    if skip != "no_receipt":
        for act, lo, hi in [("GOODS_RECEIVED", 72, 240), ("GOODS_DELIVERED", 1, 8)]:
            t += _hours(rng, lo, hi); out.append(_ev(cid, act, t, ctx))

    t += _hours(rng, 24, 96); out.append(_ev(cid, "INVOICE_RECEIVED", t, ctx))
    if skip != "no_validate":
        t += _hours(rng, 1, 12); out.append(_ev(cid, "INVOICE_VALIDATED", t, ctx))
    t += _hours(rng, 4, 24);  out.append(_ev(cid, "INVOICE_APPROVED", t, ctx))

    if skip == "pay_before_post":
        t += _hours(rng, 24, 72); out.append(_ev(cid, "PAYMENT_ISSUED", t, ctx))
        t += _hours(rng, 1, 12);  out.append(_ev(cid, "INVOICE_POSTED", t, ctx))
    else:
        t += _hours(rng, 1, 8);   out.append(_ev(cid, "INVOICE_POSTED", t, ctx))
        t += _hours(rng, 72, 336); out.append(_ev(cid, "PAYMENT_ISSUED", t, ctx))
    t += _hours(rng, 24, 72); out.append(_ev(cid, "PAYMENT_CLEARED", t, ctx))
    return out


# ─── Parent objects (drill-down) ─────────────────────────────────────────────

def _fetch_parents(case_id: str, events: List[Dict[str, Any]], oracle_db) -> Dict[str, Any]:
    """Build the parent-object panel: PO header + lines, receipts, invoices,
    holds, payments. In demo mode we synthesize plausible rows from the events."""
    demo_mode = (oracle_db is None) or oracle_db.demo_mode
    if demo_mode:
        return _demo_parents(case_id, events)

    parents: Dict[str, Any] = {"po": None, "receipts": [], "invoices": [],
                               "holds": [], "payments": []}
    if case_id.startswith("PO:"):
        try:
            po_id = int(case_id.split(":", 1)[1])
        except ValueError:
            return parents
        parents["po"] = _fetch_po(oracle_db, po_id)
        parents["receipts"] = _fetch_receipts(oracle_db, po_id)
        parents["invoices"] = _fetch_invoices_for_po(oracle_db, po_id)
        for inv in parents["invoices"]:
            parents["holds"].extend(_fetch_holds(oracle_db, inv["invoice_id"]))
            parents["payments"].extend(_fetch_payments(oracle_db, inv["invoice_id"]))
    elif case_id.startswith("INV:"):
        try:
            inv_id = int(case_id.split(":", 1)[1])
        except ValueError:
            return parents
        parents["invoices"] = [_fetch_invoice(oracle_db, inv_id)]
        parents["holds"]    = _fetch_holds(oracle_db, inv_id)
        parents["payments"] = _fetch_payments(oracle_db, inv_id)
    return parents


def _demo_parents(case_id: str, events: List[Dict[str, Any]]) -> Dict[str, Any]:
    if not events:
        return {"po": None, "receipts": [], "invoices": [], "holds": [], "payments": []}

    sample = next((e for e in events if e.get("vendor_name")), events[0])
    po_id = events[0].get("doc_id") if case_id.startswith("PO:") else None
    po_num = next((e.get("doc_num") for e in events if e.get("doc_num", "").startswith("PO-")), None) if po_id else None
    inv_id = next((e.get("doc_id") for e in events if e["activity"] == "INVOICE_RECEIVED"), None)
    inv_num = next((e.get("doc_num") for e in events if e["activity"] == "INVOICE_RECEIVED"), None)
    chk_id = next((e.get("doc_id") for e in events if e["activity"] == "PAYMENT_ISSUED"), None)
    chk_num = next((e.get("doc_num") for e in events if e["activity"] == "PAYMENT_ISSUED"), None)
    pay_ts = next((e["ts"] for e in events if e["activity"] == "PAYMENT_ISSUED"), None)
    rcv_ts = next((e["ts"] for e in events if e["activity"] == "GOODS_RECEIVED"), None)
    inv_ts = next((e["ts"] for e in events if e["activity"] == "INVOICE_RECEIVED"), None)
    posted_ts = next((e["ts"] for e in events if e["activity"] == "INVOICE_POSTED"), None)
    holds = [e for e in events if e["activity"] == "HOLD_PLACED"]

    amount = sample.get("amount") or 0
    qty = max(1, int(amount // 1000)) if amount else 5

    po = None
    if po_id:
        po = {
            "po_header_id": po_id,
            "segment1":    po_num,
            "vendor_id":   sample.get("vendor_id"),
            "vendor_name": sample.get("vendor_name"),
            "creation_date": events[0]["ts"].isoformat(),
            "approved_date": next((e["ts"].isoformat() for e in events if e["activity"] == "PO_APPROVED"), None),
            "currency_code": "USD",
            "amount":      amount,
            "lines": [
                {"line_num": 1, "item_description": "Demo line item",
                 "quantity": qty, "unit_price": round(amount / qty, 2), "amount": amount},
            ],
        }

    receipts = []
    if rcv_ts:
        receipts.append({
            "transaction_id":   100000 + (po_id or 0),
            "transaction_type": "RECEIVE",
            "transaction_date": rcv_ts.isoformat(),
            "quantity":         qty,
            "uom":              "EA",
        })
    deliver_ts = next((e["ts"] for e in events if e["activity"] == "GOODS_DELIVERED"), None)
    if deliver_ts:
        receipts.append({
            "transaction_id":   100001 + (po_id or 0),
            "transaction_type": "DELIVER",
            "transaction_date": deliver_ts.isoformat(),
            "quantity":         qty,
            "uom":              "EA",
        })

    invoices = []
    if inv_id:
        invoices.append({
            "invoice_id":   inv_id,
            "invoice_num":  inv_num,
            "invoice_date": inv_ts.isoformat() if inv_ts else None,
            "amount":       amount,
            "currency":     "USD",
            "posting_status": "Y" if posted_ts else "N",
            "wfapproval_status": "APPROVED",
            "vendor_name":  sample.get("vendor_name"),
        })

    hold_rows = [{
        "invoice_id":      h.get("doc_id"),
        "hold_lookup_code": h.get("attribute1") or "MANUAL",
        "creation_date":   h["ts"].isoformat(),
        "released_date":   next((e["ts"].isoformat() for e in events
                                  if e["activity"] == "HOLD_RELEASED" and e["ts"] > h["ts"]),
                                 None),
    } for h in holds]

    payments = []
    if chk_id:
        cleared_ts = next((e["ts"] for e in events if e["activity"] == "PAYMENT_CLEARED"), None)
        payments.append({
            "check_id":     chk_id,
            "check_number": chk_num,
            "check_date":   pay_ts.isoformat() if pay_ts else None,
            "amount":       amount,
            "currency":     "USD",
            "status":       "CLEARED" if cleared_ts else "NEGOTIATED",
            "cleared_date": cleared_ts.isoformat() if cleared_ts else None,
        })

    return {"po": po, "receipts": receipts, "invoices": invoices,
            "holds": hold_rows, "payments": payments}


# ─── Live parent fetchers ────────────────────────────────────────────────────

def _fetch_po(oracle_db, po_id: int) -> Optional[Dict[str, Any]]:
    sql = """
        SELECT ph.po_header_id, ph.segment1, ph.vendor_id,
               (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = ph.vendor_id) vendor_name,
               ph.creation_date, ph.approved_date, ph.currency_code,
               ph.revision_num
        FROM   po_headers_all ph
        WHERE  ph.po_header_id = :po_id
    """
    rows = oracle_db.execute_query(sql, params={"po_id": po_id}, max_rows=1)
    if not rows:
        return None
    head = rows[0]
    lines = oracle_db.execute_query("""
        SELECT pl.line_num, pl.item_description,
               pl.quantity, pl.unit_price, pl.amount
        FROM   po_lines_all pl
        WHERE  pl.po_header_id = :po_id
        ORDER  BY pl.line_num
        FETCH FIRST 50 ROWS ONLY
    """, params={"po_id": po_id}, max_rows=50)
    head["lines"] = lines
    return head


def _fetch_receipts(oracle_db, po_id: int) -> List[Dict[str, Any]]:
    return oracle_db.execute_query("""
        SELECT rt.transaction_id, rt.transaction_type, rt.transaction_date,
               rt.quantity, rt.unit_of_measure uom
        FROM   rcv_transactions rt
        WHERE  rt.po_header_id = :po_id
        ORDER  BY rt.transaction_date
        FETCH FIRST 50 ROWS ONLY
    """, params={"po_id": po_id}, max_rows=50)


def _fetch_invoices_for_po(oracle_db, po_id: int) -> List[Dict[str, Any]]:
    return oracle_db.execute_query("""
        SELECT DISTINCT i.invoice_id, i.invoice_num, i.invoice_date,
               ROUND(i.invoice_amount, 2) amount, i.invoice_currency_code currency,
               i.posting_status, i.wfapproval_status,
               (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = i.vendor_id) vendor_name
        FROM   ap_invoices_all i
        JOIN   ap_invoice_lines_all il ON il.invoice_id = i.invoice_id
        WHERE  il.po_header_id = :po_id
        ORDER  BY i.invoice_date
        FETCH FIRST 50 ROWS ONLY
    """, params={"po_id": po_id}, max_rows=50)


def _fetch_invoice(oracle_db, inv_id: int) -> Dict[str, Any]:
    rows = oracle_db.execute_query("""
        SELECT i.invoice_id, i.invoice_num, i.invoice_date,
               ROUND(i.invoice_amount, 2) amount, i.invoice_currency_code currency,
               i.posting_status, i.wfapproval_status,
               (SELECT s.vendor_name FROM ap_suppliers s WHERE s.vendor_id = i.vendor_id) vendor_name
        FROM   ap_invoices_all i
        WHERE  i.invoice_id = :inv_id
    """, params={"inv_id": inv_id}, max_rows=1)
    return rows[0] if rows else {}


def _fetch_holds(oracle_db, inv_id: int) -> List[Dict[str, Any]]:
    return oracle_db.execute_query("""
        SELECT h.invoice_id, h.hold_lookup_code,
               h.creation_date, h.release_lookup_date released_date,
               h.hold_reason
        FROM   ap_holds_all h
        WHERE  h.invoice_id = :inv_id
        ORDER  BY h.creation_date
    """, params={"inv_id": inv_id}, max_rows=50)


def _fetch_payments(oracle_db, inv_id: int) -> List[Dict[str, Any]]:
    return oracle_db.execute_query("""
        SELECT c.check_id, c.check_number, c.check_date,
               ROUND(c.amount, 2) amount, c.currency_code currency,
               c.status_lookup_code status, c.cleared_date
        FROM   ap_checks_all c
        JOIN   ap_invoice_payments_all aip ON aip.check_id = c.check_id
        WHERE  aip.invoice_id = :inv_id
        ORDER  BY c.check_date
    """, params={"inv_id": inv_id}, max_rows=50)
