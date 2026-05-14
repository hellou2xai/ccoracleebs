"""
Event-log analytics for process mining (P2P).

Pure Python. Input is a list of events:
    {case_id, activity, ts (datetime), resource, doc_id, doc_num,
     vendor_id, vendor_name, amount, currency_code, attribute1}

Outputs:
    build_cases       — group + sort events into cases
    top_variants      — sequence -> {count, share, avg_cycle_h, sample_cases}
    directly_follows  — DFG: nodes + edges with frequency + median duration
    bottlenecks       — slowest A->B transitions
    rework            — activities that repeat in a single case
    cycle_time        — distribution buckets
    conformance       — non-conformant cases vs REQUIRED_ACTIVITIES
"""
from __future__ import annotations

import statistics
from collections import Counter, defaultdict
from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional, Tuple

from config.process_mining import (
    ACTIVITIES, ACTIVITY_BY_KEY,
    REQUIRED_ACTIVITIES, REWORK_ACTIVITIES, HAPPY_PATH,
    CONFORMANCE_ISSUES,
)


def _ts(v: Any) -> Optional[datetime]:
    if isinstance(v, datetime):
        return v
    if isinstance(v, str):
        try:
            return datetime.fromisoformat(v.replace("Z", "+00:00"))
        except Exception:
            try:
                return datetime.strptime(v[:19], "%Y-%m-%dT%H:%M:%S")
            except Exception:
                return None
    return None


def normalize_events(rows: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    for r in rows:
        ts = _ts(r.get("ts"))
        if not ts or not r.get("case_id") or not r.get("activity"):
            continue
        out.append({
            "case_id":       r["case_id"],
            "activity":      r["activity"],
            "ts":            ts,
            "resource":      r.get("resource"),
            "doc_id":        r.get("doc_id"),
            "doc_num":       r.get("doc_num"),
            "vendor_id":     r.get("vendor_id"),
            "vendor_name":   r.get("vendor_name"),
            "amount":        r.get("amount"),
            "currency_code": r.get("currency_code"),
            "attribute1":    r.get("attribute1"),
        })
    return out


def build_cases(events: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    cases: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for e in events:
        cases[e["case_id"]].append(e)
    for cid, ev in cases.items():
        ev.sort(key=lambda x: x["ts"])
    return dict(cases)


# ─── Variant analysis ────────────────────────────────────────────────────────

def top_variants(cases: Dict[str, List[Dict[str, Any]]], top_n: int = 12) -> Dict[str, Any]:
    total = len(cases)
    if total == 0:
        return {"variants": [], "total_cases": 0}

    bucket: Dict[Tuple[str, ...], List[str]] = defaultdict(list)
    durations: Dict[Tuple[str, ...], List[float]] = defaultdict(list)

    for cid, ev in cases.items():
        seq = tuple(e["activity"] for e in ev)
        bucket[seq].append(cid)
        if len(ev) >= 2:
            dur_h = (ev[-1]["ts"] - ev[0]["ts"]).total_seconds() / 3600.0
            durations[seq].append(dur_h)

    rows: List[Dict[str, Any]] = []
    for seq, cids in bucket.items():
        cnt = len(cids)
        durs = durations.get(seq) or []
        avg_h = round(statistics.mean(durs), 1) if durs else 0.0
        med_h = round(statistics.median(durs), 1) if durs else 0.0
        is_happy = list(seq) == HAPPY_PATH
        contains_rework = any(seq.count(a) > 1 for a in REWORK_ACTIVITIES) or "PO_REVISED" in seq
        missing_required = [a for a in REQUIRED_ACTIVITIES if a not in seq]
        rows.append({
            "sequence":          list(seq),
            "step_count":        len(seq),
            "case_count":        cnt,
            "share_pct":         round(cnt * 100 / total, 1),
            "avg_cycle_hours":   avg_h,
            "median_cycle_hours": med_h,
            "is_happy_path":     is_happy,
            "has_rework":        contains_rework,
            "missing_required":  missing_required,
            "sample_cases":      cids[:5],
        })

    rows.sort(key=lambda r: -r["case_count"])
    return {"variants": rows[:top_n], "total_cases": total, "distinct_variants": len(bucket)}


# ─── Directly-follows graph ──────────────────────────────────────────────────

def directly_follows(cases: Dict[str, List[Dict[str, Any]]]) -> Dict[str, Any]:
    edge_counts: Counter = Counter()
    edge_durations: Dict[Tuple[str, str], List[float]] = defaultdict(list)
    activity_counts: Counter = Counter()

    for cid, ev in cases.items():
        for i, e in enumerate(ev):
            activity_counts[e["activity"]] += 1
            if i + 1 < len(ev):
                a = e["activity"]
                b = ev[i + 1]["activity"]
                key = (a, b)
                edge_counts[key] += 1
                hours = (ev[i + 1]["ts"] - e["ts"]).total_seconds() / 3600.0
                if hours >= 0:
                    edge_durations[key].append(hours)

    nodes = []
    for a in ACTIVITIES:
        k = a["key"]
        if activity_counts.get(k, 0) > 0:
            nodes.append({
                "key": k,
                "label": a["label"],
                "leg": a["leg"],
                "color": a["color"],
                "count": activity_counts[k],
                "order": a["order"],
            })

    edges = []
    for (a, b), cnt in edge_counts.most_common():
        durs = edge_durations.get((a, b)) or []
        edges.append({
            "from": a,
            "to": b,
            "from_label": ACTIVITY_BY_KEY.get(a, {}).get("label", a),
            "to_label":   ACTIVITY_BY_KEY.get(b, {}).get("label", b),
            "count":      cnt,
            "median_hours": round(statistics.median(durs), 1) if durs else 0.0,
            "p95_hours":    round(_percentile(durs, 95), 1) if durs else 0.0,
        })

    return {"nodes": nodes, "edges": edges, "case_count": len(cases)}


def _percentile(values: List[float], p: float) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    k = (len(s) - 1) * p / 100.0
    f = int(k)
    c = min(f + 1, len(s) - 1)
    return s[f] + (s[c] - s[f]) * (k - f)


# ─── Bottlenecks ─────────────────────────────────────────────────────────────

def bottlenecks(dfg: Dict[str, Any], top_n: int = 12) -> List[Dict[str, Any]]:
    edges = list(dfg.get("edges", []))
    edges.sort(key=lambda e: -e.get("median_hours", 0))
    return edges[:top_n]


# ─── Rework ──────────────────────────────────────────────────────────────────

def rework(cases: Dict[str, List[Dict[str, Any]]], top_n: int = 30) -> Dict[str, Any]:
    """Per-case rework counts for activities that legitimately repeat."""
    by_activity: Counter = Counter()
    case_rows: List[Dict[str, Any]] = []
    cases_with_rework = 0

    for cid, ev in cases.items():
        seq = [e["activity"] for e in ev]
        rework_counts = {a: seq.count(a) for a in REWORK_ACTIVITIES if seq.count(a) > 1}
        if "PO_REVISED" in seq and seq.count("PO_REVISED") >= 1:
            rework_counts["PO_REVISED"] = seq.count("PO_REVISED")
        if rework_counts:
            cases_with_rework += 1
            for k, v in rework_counts.items():
                by_activity[k] += v - (1 if k != "PO_REVISED" else 0)
            sample_event = next((e for e in ev if e.get("vendor_name")), ev[0])
            case_rows.append({
                "case_id": cid,
                "vendor_name": sample_event.get("vendor_name"),
                "amount":      sample_event.get("amount"),
                "currency":    sample_event.get("currency_code"),
                "rework":      rework_counts,
                "total_steps": len(ev),
                "doc_num":     next((e.get("doc_num") for e in ev if e.get("doc_num")), None),
            })

    case_rows.sort(key=lambda r: -sum(r["rework"].values()))
    return {
        "cases_with_rework": cases_with_rework,
        "total_cases": len(cases),
        "by_activity": dict(by_activity),
        "cases": case_rows[:top_n],
    }


# ─── Cycle time ──────────────────────────────────────────────────────────────

def cycle_time(cases: Dict[str, List[Dict[str, Any]]]) -> Dict[str, Any]:
    durs: List[float] = []
    rows: List[Dict[str, Any]] = []
    for cid, ev in cases.items():
        if len(ev) < 2:
            continue
        h = (ev[-1]["ts"] - ev[0]["ts"]).total_seconds() / 3600.0
        if h < 0:
            continue
        durs.append(h)
        sample = next((e for e in ev if e.get("vendor_name")), ev[0])
        rows.append({
            "case_id": cid,
            "hours": round(h, 1),
            "days":  round(h / 24.0, 1),
            "step_count": len(ev),
            "vendor_name": sample.get("vendor_name"),
            "amount": sample.get("amount"),
            "currency": sample.get("currency_code"),
        })
    if not durs:
        return {"buckets": [], "stats": {}, "slowest_cases": []}

    buckets_def = [
        ("0-1d",   0,    24),
        ("1-3d",   24,   72),
        ("3-7d",   72,   168),
        ("7-14d",  168,  336),
        ("14-30d", 336,  720),
        ("30-60d", 720,  1440),
        (">60d",   1440, 1e12),
    ]
    counts = []
    for label, lo, hi in buckets_def:
        n = sum(1 for h in durs if lo <= h < hi)
        counts.append({"label": label, "count": n})

    stats = {
        "min_h":    round(min(durs), 1),
        "max_h":    round(max(durs), 1),
        "median_h": round(statistics.median(durs), 1),
        "mean_h":   round(statistics.mean(durs), 1),
        "p95_h":    round(_percentile(durs, 95), 1),
        "case_count": len(durs),
    }
    rows.sort(key=lambda r: -r["hours"])
    return {"buckets": counts, "stats": stats, "slowest_cases": rows[:20]}


# ─── Conformance ─────────────────────────────────────────────────────────────

def conformance(cases: Dict[str, List[Dict[str, Any]]]) -> Dict[str, Any]:
    issues_by_case: Dict[str, List[str]] = {}
    issue_counts: Counter = Counter()

    for cid, ev in cases.items():
        seq = [e["activity"] for e in ev]
        idx = {a: seq.index(a) for a in set(seq)}
        case_issues: List[str] = []

        if "GOODS_RECEIVED" in seq and "PO_APPROVED" not in seq:
            case_issues.append("MISSING_PO_APPROVAL")
        if cid.startswith("PO:") and "PAYMENT_ISSUED" in seq and "GOODS_RECEIVED" not in seq:
            case_issues.append("MISSING_RECEIPT")
        if "INVOICE_POSTED" in seq and "INVOICE_VALIDATED" not in seq:
            case_issues.append("MISSING_VALIDATION")
        if "INVOICE_POSTED" in seq and "INVOICE_APPROVED" not in seq:
            case_issues.append("MISSING_APPROVAL")
        if "PAYMENT_ISSUED" in seq and "INVOICE_POSTED" in seq:
            if idx["PAYMENT_ISSUED"] < idx["INVOICE_POSTED"]:
                case_issues.append("PAY_BEFORE_POST")
        if "PAYMENT_ISSUED" in seq and "INVOICE_APPROVED" in seq:
            if idx["PAYMENT_ISSUED"] < idx["INVOICE_APPROVED"]:
                case_issues.append("PAY_BEFORE_APPROVE")
        if seq.count("HOLD_PLACED") > 3 or seq.count("PO_REVISED") > 2:
            case_issues.append("EXCESSIVE_REWORK")
        if cid.startswith("INV:") and "PAYMENT_ISSUED" in seq:
            case_issues.append("MAVERICK")

        if case_issues:
            issues_by_case[cid] = case_issues
            for code in case_issues:
                issue_counts[code] += 1

    rows = []
    for cid, codes in issues_by_case.items():
        ev = cases[cid]
        sample = next((e for e in ev if e.get("vendor_name")), ev[0])
        rows.append({
            "case_id": cid,
            "issues": codes,
            "vendor_name": sample.get("vendor_name"),
            "amount": sample.get("amount"),
            "currency": sample.get("currency_code"),
            "step_count": len(ev),
        })
    rows.sort(key=lambda r: -len(r["issues"]))

    return {
        "total_cases": len(cases),
        "non_conformant_cases": len(issues_by_case),
        "issue_counts": [{"code": c, "label": CONFORMANCE_ISSUES[c], "count": n}
                         for c, n in issue_counts.most_common()],
        "cases": rows[:50],
    }


# ─── Per-case timeline (drill-down) ─────────────────────────────────────────

def case_timeline(cases: Dict[str, List[Dict[str, Any]]], case_id: str) -> Dict[str, Any]:
    ev = cases.get(case_id) or []
    timeline = []
    prev_ts = None
    for e in ev:
        delta_h = None
        if prev_ts:
            delta_h = round((e["ts"] - prev_ts).total_seconds() / 3600.0, 1)
        prev_ts = e["ts"]
        a = ACTIVITY_BY_KEY.get(e["activity"], {})
        timeline.append({
            "activity":   e["activity"],
            "label":      a.get("label", e["activity"]),
            "leg":        a.get("leg"),
            "color":      a.get("color"),
            "ts":         e["ts"].isoformat(),
            "resource":   e.get("resource"),
            "doc_id":     e.get("doc_id"),
            "doc_num":    e.get("doc_num"),
            "amount":     e.get("amount"),
            "currency":   e.get("currency_code"),
            "attribute1": e.get("attribute1"),
            "since_prev_hours": delta_h,
        })
    if not ev:
        return {"case_id": case_id, "timeline": [], "summary": {}}

    first = ev[0]; last = ev[-1]
    total_h = (last["ts"] - first["ts"]).total_seconds() / 3600.0
    return {
        "case_id":     case_id,
        "vendor_id":   next((e.get("vendor_id") for e in ev if e.get("vendor_id")), None),
        "vendor_name": next((e.get("vendor_name") for e in ev if e.get("vendor_name")), None),
        "amount":      next((e.get("amount") for e in ev if e.get("amount")), None),
        "currency":    next((e.get("currency_code") for e in ev if e.get("currency_code")), None),
        "step_count":  len(ev),
        "total_hours": round(total_h, 1),
        "total_days":  round(total_h / 24.0, 1),
        "first_ts":    first["ts"].isoformat(),
        "last_ts":     last["ts"].isoformat(),
        "timeline":    timeline,
    }


# ─── Cases for a variant or edge (drill list) ───────────────────────────────

def cases_for_variant(cases: Dict[str, List[Dict[str, Any]]],
                      sequence: List[str], limit: int = 50) -> List[Dict[str, Any]]:
    target = tuple(sequence)
    out = []
    for cid, ev in cases.items():
        if tuple(e["activity"] for e in ev) == target:
            sample = next((e for e in ev if e.get("vendor_name")), ev[0])
            total_h = (ev[-1]["ts"] - ev[0]["ts"]).total_seconds() / 3600.0
            out.append({
                "case_id": cid,
                "vendor_name": sample.get("vendor_name"),
                "amount": sample.get("amount"),
                "currency": sample.get("currency_code"),
                "step_count": len(ev),
                "hours": round(total_h, 1),
            })
            if len(out) >= limit:
                break
    return out


def cases_for_edge(cases: Dict[str, List[Dict[str, Any]]],
                   from_act: str, to_act: str, limit: int = 50) -> List[Dict[str, Any]]:
    out = []
    for cid, ev in cases.items():
        for i in range(len(ev) - 1):
            if ev[i]["activity"] == from_act and ev[i + 1]["activity"] == to_act:
                hours = (ev[i + 1]["ts"] - ev[i]["ts"]).total_seconds() / 3600.0
                sample = next((e for e in ev if e.get("vendor_name")), ev[0])
                out.append({
                    "case_id": cid,
                    "vendor_name": sample.get("vendor_name"),
                    "amount": sample.get("amount"),
                    "currency": sample.get("currency_code"),
                    "edge_hours": round(hours, 1),
                    "from_ts": ev[i]["ts"].isoformat(),
                    "to_ts":   ev[i + 1]["ts"].isoformat(),
                })
                break
        if len(out) >= limit:
            break
    out.sort(key=lambda r: -r["edge_hours"])
    return out
