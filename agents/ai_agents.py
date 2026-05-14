"""
AI features for the Payables / Process Mining / Observability surfaces.

Four entry points:
    ai_run_agent(agent_id, days_back, oracle_db)
        True tool-calling loop. Claude picks which queries to run, reads the
        rows, judges severity, and writes grounded recommendations.

    ai_run_all_brief(run_all_result, oracle_db)
        Takes a deterministic run_all output and asks Claude for an executive
        morning brief tying findings together.

    ai_cluster_variants(variants, oracle_db)
        Groups process-mining variants by *intent* (happy, rework, control
        violation, exception) instead of exact sequence.

    ai_anomaly_scan(events, oracle_db)
        Reads recent observability events and flags unusual patterns.

All four use the same anthropic SDK and model the chat orchestrator already uses.
"""
from __future__ import annotations

import json
import logging
import os
import time
import uuid
from typing import Any, Dict, List, Optional

import anthropic

from config.payables_app import PAYABLES_QUERIES
from config.payables_agents import AGENT_BY_ID, DEMO_AGENT_RESULT
from tools.observability import emit


logger = logging.getLogger(__name__)

MODEL = "claude-sonnet-4-6"
MAX_TOOL_ITERATIONS = 6  # bound the loop


def _client() -> anthropic.Anthropic:
    return anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY", ""))


# ─── Tool definitions for the AI Hold Resolver / agent loop ──────────────────

def _agent_tools(agent_id: str) -> List[Dict[str, Any]]:
    """Tools made available to a specific agent's Claude run."""
    agent = AGENT_BY_ID.get(agent_id) or {}
    available_qids = list(agent.get("queries", []))
    # Always allow the agent's own query pack plus a safe set of context queries
    enum_queries = list({*available_qids,
                         "summary", "supplier_aging", "approval_bottleneck"})
    return [
        {
            "name": "run_query",
            "description": "Execute one of the predefined Payables SQL packs against Oracle EBS and return the rows. Use this to gather evidence before judging severity.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "query_id": {
                        "type": "string",
                        "enum": enum_queries,
                        "description": "Which Payables query pack to run.",
                    },
                    "days_back": {
                        "type": "integer",
                        "description": "Window for the query (default 30).",
                    },
                },
                "required": ["query_id"],
            },
        },
        {
            "name": "finish",
            "description": "Emit the final agent verdict. Call this exactly once when you have enough evidence. Severity must be CRITICAL, HIGH, MEDIUM, or INFO. Summary and recommendations must reference actual vendors, amounts or counts from the rows you saw.",
            "input_schema": {
                "type": "object",
                "properties": {
                    "severity": {"type": "string", "enum": ["CRITICAL", "HIGH", "MEDIUM", "INFO"]},
                    "summary": {"type": "string", "description": "1-2 sentence verdict grounded in the data you saw."},
                    "reasoning": {"type": "string", "description": "Short explanation of why this severity, citing the evidence."},
                    "recommended_actions": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "3-5 specific actions that name the affected vendors / invoice numbers / approvers / amounts.",
                    },
                    "watch_signals": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "Optional signals to monitor over the next few days.",
                    },
                },
                "required": ["severity", "summary", "reasoning", "recommended_actions"],
            },
        },
    ]


_AGENT_SYSTEM = """You are an Oracle EBS Payables specialist running as an autonomous agent.

You are given an agent identity (e.g. Hold Resolver, Three-Way Match Auditor)
and a window in days. You have a `run_query` tool that returns rows from the
real Payables tables, and a `finish` tool to emit your final verdict.

Rules:
- Always run at least one query before judging.
- Read the rows. Cite specific vendor names, invoice numbers, amounts, or
  approver names in your summary and recommendations. Vague output is wrong.
- If the first query is empty or thin, run another query that adds context.
- Never run the same query twice with the same params.
- Stop after at most 4 query calls and call `finish` exactly once.
- Severity scale:
    CRITICAL — material risk, period-close blocker, fraud signal, or > $100k exposure
    HIGH     — clear remediation needed within 1 week
    MEDIUM   — visible but routine
    INFO     — no concerning signal
- Recommended actions must be specific. "Triage holds" is wrong. "Release
  PRICE hold on PO-50213 (Cyberdyne, $20,989) once buyer confirms the unit
  price discrepancy" is right.
"""


def _query_runner(oracle_db, days_back: int):
    """Returns (rows, ms, error) for a query_id."""
    def run(query_id: str, qdays: Optional[int] = None) -> Dict[str, Any]:
        days = max(1, min(365, int(qdays or days_back)))
        q = PAYABLES_QUERIES.get(query_id)
        if not q:
            return {"rows": [], "row_count": 0, "error": f"unknown query: {query_id}",
                    "execution_time_ms": 0}
        demo_mode = (oracle_db is None) or oracle_db.demo_mode
        if demo_mode:
            # Synthesize a small set of demo rows so Claude has something to
            # reason over even in demo mode. Use the same data shape as live.
            rows = _demo_rows(query_id)
            return {
                "rows": rows[:30],
                "row_count": len(rows),
                "label": q.get("label", query_id),
                "execution_time_ms": 8,
                "demo_mode": True,
            }
        t0 = time.time()
        try:
            sql = q["sql"].strip().format(days_back=days)
            rows = oracle_db.execute_query(sql, max_rows=200)
            return {
                "rows": rows[:30],   # cap rows shown to LLM
                "row_count": len(rows),
                "label": q.get("label", query_id),
                "execution_time_ms": int((time.time() - t0) * 1000),
            }
        except Exception as exc:
            return {"rows": [], "row_count": 0, "error": str(exc),
                    "execution_time_ms": int((time.time() - t0) * 1000)}
    return run


def _demo_rows(query_id: str) -> List[Dict[str, Any]]:
    """Realistic synthetic rows so Claude can ground its analysis in demo mode."""
    if query_id == "holds":
        return [
            {"invoice_num": "INV-80123", "vendor_name": "Cyberdyne Systems",  "hold_lookup_code": "PRICE",        "invoice_amount": 20989.68, "days_on_hold": 18, "avg_days_on_hold": 5.4, "max_days_on_hold": 18},
            {"invoice_num": "INV-80087", "vendor_name": "Wayne Enterprises",  "hold_lookup_code": "QTY RECEIVED", "invoice_amount": 14250.00, "days_on_hold": 11, "avg_days_on_hold": 5.4, "max_days_on_hold": 18},
            {"invoice_num": "INV-80211", "vendor_name": "Stark Industries",   "hold_lookup_code": "PRICE",        "invoice_amount":  8420.50, "days_on_hold":  7, "avg_days_on_hold": 5.4, "max_days_on_hold": 18},
            {"invoice_num": "INV-80155", "vendor_name": "Hooli Cloud",        "hold_lookup_code": "TAX",          "invoice_amount":  3210.00, "days_on_hold":  6, "avg_days_on_hold": 5.4, "max_days_on_hold": 18},
            {"invoice_num": "INV-80298", "vendor_name": "Acme Widget Co",     "hold_lookup_code": "VARIANCE",     "invoice_amount": 12480.00, "days_on_hold":  4, "avg_days_on_hold": 5.4, "max_days_on_hold": 18},
            {"invoice_num": "INV-80312", "vendor_name": "Cyberdyne Systems",  "hold_lookup_code": "PRICE",        "invoice_amount":  6700.00, "days_on_hold":  3, "avg_days_on_hold": 5.4, "max_days_on_hold": 18},
        ]
    if query_id == "approvers":
        return [
            {"hold_type": "PRICE",        "approval_status": "NEEDS REAPPROVAL", "invoice_count": 3, "hold_count": 4, "total_amount": 36110.18, "max_days": 18, "avg_days": 8.5},
            {"hold_type": "QTY RECEIVED", "approval_status": "REQUIRED",         "invoice_count": 1, "hold_count": 1, "total_amount": 14250.00, "max_days": 11, "avg_days": 11.0},
            {"hold_type": "TAX",          "approval_status": "REQUIRED",         "invoice_count": 1, "hold_count": 1, "total_amount":  3210.00, "max_days":  6, "avg_days":  6.0},
            {"hold_type": "VARIANCE",     "approval_status": "REQUIRED",         "invoice_count": 1, "hold_count": 1, "total_amount": 12480.00, "max_days":  4, "avg_days":  4.0},
        ]
    if query_id == "match_exceptions":
        return [
            {"invoice_num": "INV-80123", "vendor_name": "Cyberdyne Systems", "hold_type": "PRICE",        "hold_reason": "Invoice unit price 12% above PO line price", "days_on_hold": 18, "invoice_amount": 20989.68},
            {"invoice_num": "INV-80087", "vendor_name": "Wayne Enterprises", "hold_type": "QTY RECEIVED", "hold_reason": "Invoice qty 10 vs receipt qty 8",            "days_on_hold": 11, "invoice_amount": 14250.00},
            {"invoice_num": "INV-80211", "vendor_name": "Stark Industries",  "hold_type": "PRICE",        "hold_reason": "Invoice unit 95.50 vs PO unit 90.00",        "days_on_hold":  7, "invoice_amount":  8420.50},
        ]
    if query_id == "supplier_aging":
        return [
            {"vendor_name": "Cyberdyne Systems", "invoice_count": 4, "bucket_0_30": 12500, "bucket_31_60": 8200, "bucket_61_90": 0,    "bucket_over_90": 0,     "total_outstanding": 20700},
            {"vendor_name": "Wayne Enterprises", "invoice_count": 6, "bucket_0_30": 22100, "bucket_31_60": 0,    "bucket_61_90": 5400, "bucket_over_90": 31200, "total_outstanding": 58700},
            {"vendor_name": "Hooli Cloud",       "invoice_count": 3, "bucket_0_30":  8400, "bucket_31_60": 1200, "bucket_61_90": 0,    "bucket_over_90":     0, "total_outstanding": 9600},
        ]
    if query_id == "approval_bottleneck":
        return [
            {"approver": "M.Patel",    "approver_name": "M Patel",    "pending_count": 7, "avg_days_waiting": 8.5, "max_days_waiting": 14, "total_amount_pending": 64200},
            {"approver": "C.Liu",      "approver_name": "C Liu",      "pending_count": 4, "avg_days_waiting": 4.2, "max_days_waiting":  9, "total_amount_pending": 18800},
            {"approver": "B.Roy",      "approver_name": "B Roy",      "pending_count": 2, "avg_days_waiting": 2.1, "max_days_waiting":  5, "total_amount_pending":  9300},
        ]
    if query_id == "duplicate_risk":
        return [
            {"invoice_num": "INV-80140", "vendor_name": "Initech LLC", "invoice_amount": 4250.00, "dup_invoice_num": "INV-80142", "date_diff_days": 2},
            {"invoice_num": "INV-80190", "vendor_name": "Soylent Foods", "invoice_amount": 8900.00, "dup_invoice_num": "INV-80192", "date_diff_days": 1},
        ]
    if query_id == "discounts":
        return [
            {"invoice_num": "INV-80401", "vendor_name": "Globex Industries", "discount_amount": 350.00, "gross_amount": 17500.00, "days_to_discount": 2, "urgency": "URGENT", "total_discount_available": 24300},
            {"invoice_num": "INV-80405", "vendor_name": "Tyrell Robotics",   "discount_amount": 180.00, "gross_amount":  9000.00, "days_to_discount": 5, "urgency": "THIS_WEEK", "total_discount_available": 24300},
        ]
    if query_id == "summary":
        return [{"total_invoices": 145, "posted_count": 113, "unposted_count": 32,
                 "pending_approval": 8, "total_amount": 2345678.90, "avg_invoice_amount": 16170.20,
                 "source_count": 5}]
    if query_id == "unapproved_invoices":
        return [
            {"invoice_num": "INV-80501", "vendor_name": "Hooli Cloud",        "invoice_amount": 12200.00, "days_waiting": 12, "current_approver": "M Patel",   "wfapproval_status": "NEEDS REAPPROVAL"},
            {"invoice_num": "INV-80502", "vendor_name": "Pied Piper Inc",     "invoice_amount":  6420.00, "days_waiting":  9, "current_approver": "M Patel",   "wfapproval_status": "REQUIRED"},
            {"invoice_num": "INV-80503", "vendor_name": "Stark Industries",   "invoice_amount":  4100.00, "days_waiting":  7, "current_approver": "C Liu",     "wfapproval_status": "REQUIRED"},
        ]
    if query_id == "open_prepayments":
        return [
            {"invoice_num": "PRE-90011", "vendor_name": "Wonka Confectionery", "prepayment_amount": 25000, "unapplied_amount": 25000, "days_outstanding": 92},
            {"invoice_num": "PRE-90014", "vendor_name": "Stark Industries",    "prepayment_amount": 12000, "unapplied_amount":  9000, "days_outstanding": 41},
        ]
    return []


# ─── 1. AI run_agent — true tool-calling loop ────────────────────────────────

def ai_run_agent(agent_id: str, days_back: int, oracle_db, source: str = "ai_ui") -> Dict[str, Any]:
    agent = AGENT_BY_ID.get(agent_id)
    if not agent:
        return {"error": f"unknown agent: {agent_id}", "agent_id": agent_id}

    days_back = max(1, min(365, int(days_back or 30)))
    run_id = uuid.uuid4().hex[:12]
    started = time.time()

    emit({
        "run_id": run_id, "agent_id": agent_id, "agent_label": agent["label"],
        "phase": "start", "source": source, "ai": True,
        "message": f"AI {agent['label']} started", "days_back": days_back,
    })

    runner = _query_runner(oracle_db, days_back)
    tools = _agent_tools(agent_id)
    user = (
        f"You are running as the **{agent['label']}** agent. "
        f"Purpose: {agent['purpose']}. "
        f"Window: last {days_back} days. "
        f"Allowed query packs: {', '.join(agent['queries'])} (and supplier_aging, summary, approval_bottleneck for context). "
        "Run as few queries as needed to reach a confident verdict, then call finish."
    )
    messages: List[Dict[str, Any]] = [{"role": "user", "content": user}]
    tool_trace: List[Dict[str, Any]] = []
    final: Optional[Dict[str, Any]] = None
    rows_seen = 0
    queries_run: Dict[str, Any] = {}

    client = _client()
    for step in range(MAX_TOOL_ITERATIONS):
        try:
            resp = client.messages.create(
                model=MODEL,
                max_tokens=2048,
                system=_AGENT_SYSTEM,
                tools=tools,
                messages=messages,
            )
        except Exception as exc:
            emit({"run_id": run_id, "agent_id": agent_id, "agent_label": agent["label"],
                  "phase": "error", "source": source, "ai": True,
                  "message": f"AI call failed: {exc}", "error": str(exc)})
            return {"agent_id": agent_id, "error": str(exc), "ai": True, "run_id": run_id}

        # Append assistant turn (must be before tool_result if any)
        messages.append({"role": "assistant", "content": resp.content})

        if resp.stop_reason != "tool_use":
            # Final text-only response — synthesize a finish from text
            text = ""
            for blk in resp.content:
                if getattr(blk, "type", None) == "text":
                    text += blk.text
            final = {
                "severity": "INFO",
                "summary": text or "No verdict produced.",
                "reasoning": "Model stopped without calling finish.",
                "recommended_actions": [],
            }
            break

        tool_results_blocks = []
        for blk in resp.content:
            if getattr(blk, "type", None) != "tool_use":
                continue
            tname = blk.name
            tinput = blk.input or {}
            if tname == "run_query":
                qid = tinput.get("query_id")
                qdays = tinput.get("days_back") or days_back
                emit({"run_id": run_id, "agent_id": agent_id, "agent_label": agent["label"],
                      "phase": "query", "source": source, "ai": True,
                      "query_id": qid, "message": f"AI ran query {qid}"})
                result = runner(qid, qdays) if qid else {"error": "missing query_id"}
                queries_run[qid or f"step{step}"] = result
                rows_seen += result.get("row_count", 0)
                tool_trace.append({
                    "step": step + 1,
                    "tool": "run_query",
                    "input": {"query_id": qid, "days_back": qdays},
                    "rows": result.get("row_count", 0),
                    "ms": result.get("execution_time_ms", 0),
                })
                tool_results_blocks.append({
                    "type": "tool_result",
                    "tool_use_id": blk.id,
                    "content": json.dumps(result, default=str)[:18000],
                })
            elif tname == "finish":
                final = dict(tinput)
                tool_trace.append({"step": step + 1, "tool": "finish", "input": tinput})
                tool_results_blocks.append({
                    "type": "tool_result",
                    "tool_use_id": blk.id,
                    "content": "ok",
                })
            else:
                tool_results_blocks.append({
                    "type": "tool_result",
                    "tool_use_id": blk.id,
                    "content": f"unknown tool: {tname}",
                    "is_error": True,
                })
        messages.append({"role": "user", "content": tool_results_blocks})

        if final is not None:
            break

    if final is None:
        final = {
            "severity": "INFO",
            "summary": "Reached step cap before reaching a verdict.",
            "reasoning": "MAX_TOOL_ITERATIONS exceeded.",
            "recommended_actions": [],
        }

    duration_ms = int((time.time() - started) * 1000)
    emit({"run_id": run_id, "agent_id": agent_id, "agent_label": agent["label"],
          "phase": "complete", "source": source, "ai": True,
          "severity": final.get("severity", "INFO"),
          "summary": final.get("summary", ""),
          "rows": rows_seen, "duration_ms": duration_ms,
          "message": f"AI {agent['label']} done ({final.get('severity','INFO')}, "
                     f"{rows_seen} rows, {duration_ms} ms)"})

    return {
        "agent_id": agent_id,
        "agent_label": agent["label"],
        "ai": True,
        "run_id": run_id,
        "demo_mode": (oracle_db is None) or oracle_db.demo_mode,
        "days_back": days_back,
        "severity":            final.get("severity", "INFO"),
        "summary":             final.get("summary", ""),
        "reasoning":           final.get("reasoning", ""),
        "recommended_actions": final.get("recommended_actions", []),
        "watch_signals":       final.get("watch_signals", []),
        "tool_trace":          tool_trace,
        "queries":             queries_run,
        "row_count":           rows_seen,
        "execution_time_ms":   duration_ms,
    }


# ─── 2. AI brief over run_all output ─────────────────────────────────────────

_BRIEF_SYSTEM = """You are an AP director writing a 5 a.m. morning brief for the
controller. You receive the deterministic output of all 10 Payables agents.
Produce a tight, executive-grade briefing.

Required structure (JSON, exactly these keys):
  headline           : single sentence, ~15 words
  state_of_payables  : 2-3 sentence narrative referencing actual numbers from the data
  top_priorities     : array of 3-5 specific items, each with {title, why_it_matters, owner}
  cross_signals      : array of 0-3 patterns spanning multiple agents (e.g. holds + approvals point to same vendor)
  cash_implication   : one-sentence cash/discount/penalty assessment

Be specific. Cite actual vendors, dollar amounts, agent names, severity counts.
Do not include prose outside the JSON.
"""


def ai_run_all_brief(run_all_result: Dict[str, Any], oracle_db) -> Dict[str, Any]:
    """Feed run_all output to Claude and return an executive brief."""
    started = time.time()
    payload = _shrink_run_all(run_all_result)

    user = (
        "Here is the morning run of all 10 Payables agents. "
        "Each agent ran its SQL pack and returned severity, summary, and recommended actions. "
        "Write the morning brief as JSON only.\n\n"
        f"{json.dumps(payload, default=str)[:30000]}"
    )

    client = _client()
    try:
        resp = client.messages.create(
            model=MODEL,
            max_tokens=2048,
            system=_BRIEF_SYSTEM,
            messages=[{"role": "user", "content": user}],
        )
    except Exception as exc:
        return {"error": str(exc), "ai": True}

    text = "".join(getattr(b, "text", "") for b in resp.content)
    brief = _safe_parse_json(text)
    return {
        "ai": True,
        "execution_time_ms": int((time.time() - started) * 1000),
        "brief": brief or {"headline": text[:200], "raw": text},
    }


def _shrink_run_all(r: Dict[str, Any]) -> Dict[str, Any]:
    out = {
        "severity_counts": r.get("severity_counts"),
        "worst_severity":  r.get("worst_severity"),
        "days_back":       r.get("days_back"),
        "execution_time_ms": r.get("execution_time_ms"),
        "agents": [],
    }
    for aid, a in (r.get("agents") or {}).items():
        out["agents"].append({
            "agent_id": aid,
            "agent_label": a.get("agent_label"),
            "severity": a.get("severity"),
            "summary":  a.get("summary"),
            "actions":  a.get("actions"),
            "row_count": a.get("row_count"),
        })
    return out


def _safe_parse_json(text: str) -> Optional[Dict[str, Any]]:
    if not text:
        return None
    text = text.strip()
    # Strip code fences if model wrapped them
    if text.startswith("```"):
        text = text.strip("`")
        if text.lower().startswith("json"):
            text = text[4:].lstrip()
    try:
        return json.loads(text)
    except Exception:
        # Try to find first { ... } block
        start = text.find("{"); end = text.rfind("}")
        if start >= 0 and end > start:
            try:
                return json.loads(text[start:end + 1])
            except Exception:
                return None
    return None


# ─── 3. AI variant clustering for Process Mining ─────────────────────────────

_CLUSTER_SYSTEM = """You group Procure-to-Pay process variants by intent.

Input: a list of variants. Each has:
  rank, share_pct, case_count, median_cycle_hours, sequence (list of activity keys),
  is_happy_path, has_rework, missing_required (list of missing required activities)

Group them into 3 to 6 clusters. Each cluster represents a distinct business reality
(e.g. "Happy path", "Hold rework cluster", "PO change cluster", "Maverick / non-PO",
"Control violation: paid before posted").

Output JSON only with this exact shape:
{
  "clusters": [
    {
      "name": "...short label...",
      "intent": "...one sentence about what these variants mean operationally...",
      "share_pct": <sum of share_pct>,
      "case_count": <sum>,
      "variant_ranks": [<rank values>],
      "key_signals": ["short bullet", "..."]
    }
  ]
}
Do not add commentary. Reference variants only by their `rank`.
"""


def ai_cluster_variants(variants: List[Dict[str, Any]], oracle_db) -> Dict[str, Any]:
    if not variants:
        return {"clusters": [], "ai": True}
    payload = json.dumps(variants[:20], default=str)[:18000]
    client = _client()
    started = time.time()
    try:
        resp = client.messages.create(
            model=MODEL,
            max_tokens=1500,
            system=_CLUSTER_SYSTEM,
            messages=[{"role": "user", "content": "Variants:\n" + payload}],
        )
    except Exception as exc:
        return {"error": str(exc), "ai": True}

    text = "".join(getattr(b, "text", "") for b in resp.content)
    parsed = _safe_parse_json(text) or {"clusters": [], "raw": text}
    parsed["ai"] = True
    parsed["execution_time_ms"] = int((time.time() - started) * 1000)
    return parsed


# ─── 4. AI anomaly scan over observability events ────────────────────────────

_ANOMALY_SYSTEM = """You watch the live event stream of 10 Payables agents.
You are given the last N events (mix of start, query, rule, complete, error
phases) and per-agent state.

Spot patterns the on-call analyst should know about. For each pattern, output:
  title       — short
  severity    — CRITICAL | HIGH | MEDIUM | INFO
  agents      — affected agent ids
  description — 1-2 sentences citing concrete values from the events
  suggestion  — one specific action

Output JSON only:
{
  "patterns": [ ... ],
  "stable":   true | false,    # true if no concerning patterns
  "headline": "one sentence summary of system health"
}
If everything looks routine, return an empty patterns list and stable=true.
"""


def ai_anomaly_scan(events: List[Dict[str, Any]],
                    agent_states: List[Dict[str, Any]],
                    stats: Dict[str, Any],
                    oracle_db) -> Dict[str, Any]:
    if not events:
        return {"patterns": [], "stable": True,
                "headline": "No events in the window.", "ai": True}

    payload = {
        "stats": stats,
        "agent_states": agent_states,
        "events": events[-120:],   # cap
    }
    client = _client()
    started = time.time()
    try:
        resp = client.messages.create(
            model=MODEL,
            max_tokens=1500,
            system=_ANOMALY_SYSTEM,
            messages=[{"role": "user", "content": json.dumps(payload, default=str)[:25000]}],
        )
    except Exception as exc:
        return {"error": str(exc), "ai": True}

    text = "".join(getattr(b, "text", "") for b in resp.content)
    parsed = _safe_parse_json(text) or {"patterns": [], "stable": True,
                                         "headline": text[:200], "raw": text}
    parsed["ai"] = True
    parsed["execution_time_ms"] = int((time.time() - started) * 1000)
    return parsed
