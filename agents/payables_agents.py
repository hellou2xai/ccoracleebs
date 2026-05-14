"""
Payables Agents Orchestrator.

Runs a single agent or all 10 in sequence, executing each agent's SQL pack
against Oracle EBS, applying severity rules, and emitting observability
events at every phase so the /observability page can render execution flow.
"""
from __future__ import annotations

import time
from typing import Any, Dict, List, Optional

from config.payables_app import PAYABLES_QUERIES
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


def run_agent(
    agent_id: str,
    days_back: int,
    oracle_db,
    source: str = "ui",
) -> Dict[str, Any]:
    """Run a single agent. Returns a result envelope."""
    agent = AGENT_BY_ID.get(agent_id)
    if not agent:
        return {"error": f"unknown agent: {agent_id}", "agent_id": agent_id}

    days_back = max(1, min(365, int(days_back or 30)))
    demo_mode = (oracle_db is None) or oracle_db.demo_mode

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
            return {
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

        return {
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


def run_all(days_back: int, oracle_db, source: str = "ui_run_all") -> Dict[str, Any]:
    """Run every agent sequentially. Returns aggregate envelope."""
    started = time.time()
    per_agent: Dict[str, Any] = {}
    summary_counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "INFO": 0, "ERROR": 0}
    for agent in PAYABLES_AGENTS:
        try:
            res = run_agent(agent["id"], days_back, oracle_db, source=source)
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
