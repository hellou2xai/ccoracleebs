"""
Payables Agents Orchestrator.

Runs a single agent or all 10 in sequence, executing each agent's SQL pack
against Oracle EBS, applying severity rules, and emitting observability
events at every phase so the /observability page can render execution flow.
"""
from __future__ import annotations

import time
from typing import Any, Dict, List, Optional

from config.payables_app import (
    PAYABLES_QUERIES,
    DRILL_QUERIES,
    INVOICE_HEADER_SQL,
    INVOICE_LINES_SQL,
    INVOICE_DIST_SQL,
)
from config.payables_agents import (
    PAYABLES_AGENTS,
    AGENT_BY_ID,
    SEVERITY_RULES,
    DEMO_AGENT_RESULT,
    SEVERITY_ORDER,
)
from tools.observability import AgentRun


def list_agents() -> List[Dict[str, Any]]:
    """Return the public catalog (without rule callables)."""
    return [
        {k: v for k, v in a.items() if k != "rule"}
        for a in PAYABLES_AGENTS
    ]


# In-memory result cache. The Vision data is frozen, so a result for a given
# (agent, days_back, mode) is stable and safe to reuse. Keeps Run All and repeat
# runs instant instead of re-querying EBS every time. Pass refresh=True to bust.
_RESULT_CACHE: Dict[Any, Dict[str, Any]] = {}


def clear_result_cache() -> None:
    _RESULT_CACHE.clear()


def run_agent(
    agent_id: str,
    days_back: int,
    oracle_db,
    source: str = "ui",
    refresh: bool = False,
) -> Dict[str, Any]:
    """Run a single agent. Returns a result envelope (cached when possible)."""
    agent = AGENT_BY_ID.get(agent_id)
    if not agent:
        return {"error": f"unknown agent: {agent_id}", "agent_id": agent_id}

    days_back = max(1, min(365, int(days_back or 30)))
    demo_mode = (oracle_db is None) or oracle_db.demo_mode

    cache_key = (agent_id, days_back, demo_mode)
    if not refresh and cache_key in _RESULT_CACHE:
        out = dict(_RESULT_CACHE[cache_key])
        out["cached"] = True
        return out

    with AgentRun(agent_id, agent["label"], source, days_back) as run:

        if demo_mode:
            demo = DEMO_AGENT_RESULT.get(agent_id, {
                "severity": "INFO", "summary": "no demo data", "actions": [], "row_count": 0,
            })
            demo_query_rows = demo.get("query_rows", {})
            queries_payload: Dict[str, Any] = {}
            for qid in agent["queries"]:
                rows = demo_query_rows.get(qid, [])
                qmeta = PAYABLES_QUERIES.get(qid, {})
                queries_payload[qid] = {
                    "label": qmeta.get("label", qid),
                    "rows": rows,
                    "columns": list(rows[0].keys()) if rows else [],
                    "row_count": len(rows),
                    "execution_time_ms": 5,
                }
                run.query(qid, queries_payload[qid]["row_count"], 5)
            run.rule(demo["summary"], demo["severity"])
            ms = run.complete(demo["severity"], demo["summary"], demo["row_count"])
            result = {
                "agent_id": agent_id,
                "agent_label": agent["label"],
                "demo_mode": True,
                "days_back": days_back,
                "severity": demo["severity"],
                "summary": demo["summary"],
                "actions": demo["actions"],
                "row_count": demo["row_count"],
                "queries": queries_payload,
                "execution_time_ms": ms,
                "run_id": run.run_id,
            }
            _RESULT_CACHE[cache_key] = result
            return result

        # Live mode
        results: Dict[str, Any] = {}
        total_rows = 0
        for qid in agent["queries"]:
            q = PAYABLES_QUERIES.get(qid)
            if not q:
                results[qid] = {"rows": [], "row_count": 0, "execution_time_ms": 0,
                                "error": f"missing query: {qid}"}
                continue
            q_start = time.time()
            try:
                sql = q["sql"].strip().format(days_back=days_back)
                rows = oracle_db.execute_query(sql, max_rows=200)
                ms = int((time.time() - q_start) * 1000)
                results[qid] = {
                    "label": q.get("label", qid),
                    "rows": rows,
                    "columns": list(rows[0].keys()) if rows else [],
                    "row_count": len(rows),
                    "execution_time_ms": ms,
                }
                total_rows += len(rows)
                run.query(qid, len(rows), ms)
            except Exception as exc:
                ms = int((time.time() - q_start) * 1000)
                results[qid] = {
                    "label": q.get("label", qid), "rows": [], "row_count": 0,
                    "execution_time_ms": ms, "error": str(exc),
                }
                run.query(qid, 0, ms)

        rule_fn = SEVERITY_RULES.get(agent_id)
        verdict = rule_fn(results) if rule_fn else {
            "severity": "INFO", "summary": "no rule defined", "actions": [],
        }
        run.rule(verdict.get("summary", ""), verdict.get("severity", "INFO"))
        ms = run.complete(verdict.get("severity", "INFO"),
                          verdict.get("summary", ""), total_rows)

        result = {
            "agent_id": agent_id,
            "agent_label": agent["label"],
            "demo_mode": False,
            "days_back": days_back,
            "severity": verdict.get("severity", "INFO"),
            "summary": verdict.get("summary", ""),
            "actions": verdict.get("actions", []),
            "row_count": total_rows,
            "queries": results,
            "execution_time_ms": ms,
            "run_id": run.run_id,
        }
        _RESULT_CACHE[cache_key] = result
        return result


# ─── Drilldown: aggregate row → records, and invoice 360 ─────────────────────

_DEMO_DRILL = {
    "cap_rejections": [
        {"parent_table": "AP_INVOICES_INTERFACE", "parent_id": 90142, "reason": "DUPLICATE INVOICE NUMBER", "rejected_on": "2010-10-08"},
        {"parent_table": "AP_INVOICES_INTERFACE", "parent_id": 90148, "reason": "DUPLICATE INVOICE NUMBER", "rejected_on": "2010-10-09"},
    ],
    "cap_channels": [
        {"invoice_num": "ERS-11946-226485", "vendor_name": "Consolidated Supplies", "invoice_amount": 78093.88, "invoice_currency_code": "USD", "invoice_date": "2010-10-05", "wfapproval_status": "NOT REQUIRED", "invoice_id": 382954},
        {"invoice_num": "ERS-6577-226486", "vendor_name": "Consolidated Supplies", "invoice_amount": 1860.38, "invoice_currency_code": "USD", "invoice_date": "2010-10-04", "wfapproval_status": "NOT REQUIRED", "invoice_id": 382955},
    ],
}

_DEMO_INVOICE = {
    "demo_mode": True,
    "header": [{"invoice_num": "ERS-11946-226485", "vendor_name": "Consolidated Supplies",
                "invoice_amount": 78093.88, "invoice_currency_code": "USD", "invoice_date": "2010-10-05",
                "source": "ERS", "wfapproval_status": "NOT REQUIRED", "gl_date": "2010-10-05",
                "invoice_type": "STANDARD"}],
    "lines": [{"line_number": 1, "line_type": "ITEM", "amount": 60000.00, "description": "Freight"},
              {"line_number": 2, "line_type": "ITEM", "amount": 18093.88, "description": "Handling"}],
    "distributions": [{"line_no": 1, "amount": 60000.00, "gl_account": "001.100.62510.0000.610.000.000"},
                      {"line_no": 2, "amount": 18093.88, "gl_account": "001.100.62510.0000.422.000.000"}],
}


def invoice_detail(invoice_id, oracle_db) -> Dict[str, Any]:
    """Return header, lines and GL-coded distributions for one invoice."""
    if (oracle_db is None) or oracle_db.demo_mode:
        return dict(_DEMO_INVOICE, invoice_id=invoice_id)
    try:
        header = oracle_db.execute_query(INVOICE_HEADER_SQL, params={"id": invoice_id}, max_rows=1)
        lines = oracle_db.execute_query(INVOICE_LINES_SQL, params={"id": invoice_id}, max_rows=50)
        dists = oracle_db.execute_query(INVOICE_DIST_SQL, params={"id": invoice_id}, max_rows=50)
        return {"demo_mode": False, "invoice_id": invoice_id,
                "header": header, "lines": lines, "distributions": dists}
    except Exception as exc:
        return {"error": str(exc), "invoice_id": invoice_id}


def drill_query(query_id: str, key: Any, oracle_db) -> Dict[str, Any]:
    """Return the underlying records behind an aggregate row, filtered by key."""
    spec = DRILL_QUERIES.get(query_id)
    if not spec:
        return {"error": f"no drilldown configured for {query_id}"}
    if (oracle_db is None) or oracle_db.demo_mode:
        return {"demo_mode": True, "title": spec["title"], "key": key,
                "rows": _DEMO_DRILL.get(query_id, [])}
    try:
        rows = oracle_db.execute_query(spec["sql"], params={"key": key}, max_rows=100)
        return {"demo_mode": False, "title": spec["title"], "key": key, "rows": rows}
    except Exception as exc:
        return {"error": str(exc), "title": spec.get("title"), "key": key}


AP_TRIO_SEQUENCE = ["invoice_capture", "three_way_match", "gl_auto_coder"]


def run_ap_trio(days_back: int, oracle_db, source: str = "ui_trio",
                refresh: bool = False) -> Dict[str, Any]:
    """Run the AP trio as an ordered pipeline: capture the invoice, match it
    3-way, then auto-code the GL. Each step's result feeds the combined view."""
    started = time.time()
    steps: Dict[str, Any] = {}
    for agent_id in AP_TRIO_SEQUENCE:
        steps[agent_id] = run_agent(agent_id, days_back, oracle_db, source=source, refresh=refresh)

    sevs = [s.get("severity", "INFO") for s in steps.values()]
    worst = sorted(sevs, key=lambda s: SEVERITY_ORDER.get(s, 99))[0] if sevs else "INFO"
    return {
        "pipeline": "ap_trio",
        "sequence": AP_TRIO_SEQUENCE,
        "demo_mode": (oracle_db is None) or oracle_db.demo_mode,
        "days_back": days_back,
        "steps": steps,
        "worst_severity": worst,
        "execution_time_ms": int((time.time() - started) * 1000),
    }


def run_all(days_back: int, oracle_db, source: str = "ui_run_all",
            refresh: bool = False) -> Dict[str, Any]:
    """Run every agent sequentially. Returns aggregate envelope."""
    started = time.time()
    per_agent: Dict[str, Any] = {}
    summary_counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "INFO": 0, "ERROR": 0}
    for agent in PAYABLES_AGENTS:
        try:
            res = run_agent(agent["id"], days_back, oracle_db, source=source, refresh=refresh)
            sev = res.get("severity", "INFO")
            summary_counts[sev] = summary_counts.get(sev, 0) + 1
            per_agent[agent["id"]] = res
        except Exception as exc:
            summary_counts["ERROR"] += 1
            per_agent[agent["id"]] = {
                "agent_id": agent["id"], "error": str(exc), "severity": "ERROR",
            }

    worst = sorted(summary_counts.items(),
                   key=lambda kv: SEVERITY_ORDER.get(kv[0], 99))
    worst_label = next((k for k, v in worst if v > 0), "INFO")

    return {
        "demo_mode": (oracle_db is None) or oracle_db.demo_mode,
        "days_back": days_back,
        "agents": per_agent,
        "severity_counts": summary_counts,
        "worst_severity": worst_label,
        "execution_time_ms": int((time.time() - started) * 1000),
    }
