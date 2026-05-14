"""
In-process observability bus for Payables agents.

Holds a ring-buffer of recent agent events and a fan-out queue list so the
SSE endpoint can stream live events to every connected browser tab.

Event schema (dict):
    ts          ISO timestamp (UTC)
    run_id      uuid for the agent invocation
    agent_id    e.g. "hold_resolver"
    agent_label human-readable label
    phase       "start" | "query" | "rule" | "complete" | "error"
    source      "ui" | "ui_run_all" | "chat" | "cron" | "api"
    message     short human description (e.g. "running query holds")
    duration_ms int, optional, set on complete/error/query
    severity    set on complete (CRITICAL/HIGH/MEDIUM/INFO)
    rows        row count, set on query/complete
    error       error string, set on error
"""
from __future__ import annotations

import json
import queue
import threading
import time
import uuid
from collections import deque
from datetime import datetime, timezone
from typing import Any, Deque, Dict, List, Optional


_RING_MAX = 500
_lock = threading.RLock()
_ring: Deque[Dict[str, Any]] = deque(maxlen=_RING_MAX)
_subscribers: List["queue.Queue[Dict[str, Any]]"] = []

# Aggregate counters keyed by agent_id
_agent_state: Dict[str, Dict[str, Any]] = {}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def emit(event: Dict[str, Any]) -> Dict[str, Any]:
    """Emit an event into the ring buffer and to all live subscribers."""
    event = {"ts": _now(), **event}
    with _lock:
        _ring.append(event)
        _update_agent_state(event)
        dead = []
        for q in _subscribers:
            try:
                q.put_nowait(event)
            except queue.Full:
                dead.append(q)
        for q in dead:
            try:
                _subscribers.remove(q)
            except ValueError:
                pass
    return event


def _update_agent_state(event: Dict[str, Any]) -> None:
    aid = event.get("agent_id")
    if not aid:
        return
    state = _agent_state.setdefault(aid, {
        "agent_id": aid,
        "agent_label": event.get("agent_label", aid),
        "last_phase": None,
        "last_run_id": None,
        "last_severity": None,
        "last_duration_ms": None,
        "last_ts": None,
        "total_runs": 0,
        "total_errors": 0,
        "in_flight": 0,
    })
    if event.get("agent_label"):
        state["agent_label"] = event["agent_label"]
    state["last_phase"] = event.get("phase")
    state["last_run_id"] = event.get("run_id")
    state["last_ts"] = event.get("ts")
    if event.get("phase") == "start":
        state["in_flight"] += 1
    elif event.get("phase") == "complete":
        state["total_runs"] += 1
        state["in_flight"] = max(0, state["in_flight"] - 1)
        state["last_severity"] = event.get("severity")
        state["last_duration_ms"] = event.get("duration_ms")
    elif event.get("phase") == "error":
        state["total_errors"] += 1
        state["in_flight"] = max(0, state["in_flight"] - 1)
        state["last_severity"] = "ERROR"
        state["last_duration_ms"] = event.get("duration_ms")


def recent(limit: int = 200, agent_id: Optional[str] = None) -> List[Dict[str, Any]]:
    with _lock:
        items = list(_ring)
    if agent_id:
        items = [e for e in items if e.get("agent_id") == agent_id]
    return items[-limit:]


def agent_states() -> List[Dict[str, Any]]:
    with _lock:
        return list(_agent_state.values())


def stats() -> Dict[str, Any]:
    with _lock:
        items = list(_ring)
    runs = [e for e in items if e.get("phase") == "complete"]
    errors = [e for e in items if e.get("phase") == "error"]
    in_flight = sum(s.get("in_flight", 0) for s in _agent_state.values())
    durations = [e.get("duration_ms") for e in runs if e.get("duration_ms") is not None]
    avg_ms = int(sum(durations) / len(durations)) if durations else 0
    return {
        "events_in_ring": len(items),
        "total_runs": len(runs),
        "total_errors": len(errors),
        "in_flight": in_flight,
        "avg_duration_ms": avg_ms,
        "agents_seen": len(_agent_state),
    }


def subscribe(maxsize: int = 200) -> "queue.Queue[Dict[str, Any]]":
    q: "queue.Queue[Dict[str, Any]]" = queue.Queue(maxsize=maxsize)
    with _lock:
        _subscribers.append(q)
    return q


def unsubscribe(q: "queue.Queue[Dict[str, Any]]") -> None:
    with _lock:
        try:
            _subscribers.remove(q)
        except ValueError:
            pass


def sse_format(event: Dict[str, Any]) -> str:
    return f"data: {json.dumps(event, default=str)}\n\n"


# ─── Run helper ──────────────────────────────────────────────────────────────

class AgentRun:
    """Context manager that emits start / complete / error events."""

    def __init__(self, agent_id: str, agent_label: str, source: str, days_back: int):
        self.run_id = uuid.uuid4().hex[:12]
        self.agent_id = agent_id
        self.agent_label = agent_label
        self.source = source
        self.days_back = days_back
        self.t0 = 0.0
        self.severity: Optional[str] = None
        self.row_count: int = 0

    def __enter__(self) -> "AgentRun":
        self.t0 = time.time()
        emit({
            "run_id": self.run_id,
            "agent_id": self.agent_id,
            "agent_label": self.agent_label,
            "phase": "start",
            "source": self.source,
            "message": f"{self.agent_label} started",
            "days_back": self.days_back,
        })
        return self

    def query(self, qid: str, rows: int, ms: int) -> None:
        emit({
            "run_id": self.run_id,
            "agent_id": self.agent_id,
            "agent_label": self.agent_label,
            "phase": "query",
            "source": self.source,
            "message": f"query {qid} -> {rows} rows",
            "query_id": qid,
            "rows": rows,
            "duration_ms": ms,
        })

    def rule(self, summary: str, severity: str) -> None:
        emit({
            "run_id": self.run_id,
            "agent_id": self.agent_id,
            "agent_label": self.agent_label,
            "phase": "rule",
            "source": self.source,
            "message": f"rule -> {severity}: {summary}",
            "severity": severity,
            "summary": summary,
        })

    def complete(self, severity: str, summary: str, row_count: int) -> int:
        ms = int((time.time() - self.t0) * 1000)
        emit({
            "run_id": self.run_id,
            "agent_id": self.agent_id,
            "agent_label": self.agent_label,
            "phase": "complete",
            "source": self.source,
            "message": f"{self.agent_label} done ({severity}, {row_count} rows, {ms} ms)",
            "severity": severity,
            "summary": summary,
            "rows": row_count,
            "duration_ms": ms,
        })
        return ms

    def error(self, exc: Exception) -> int:
        ms = int((time.time() - self.t0) * 1000)
        emit({
            "run_id": self.run_id,
            "agent_id": self.agent_id,
            "agent_label": self.agent_label,
            "phase": "error",
            "source": self.source,
            "message": f"{self.agent_label} error: {exc}",
            "error": str(exc),
            "duration_ms": ms,
        })
        return ms

    def __exit__(self, exc_type, exc, tb):
        # If the with-block exited with an exception that was not handled
        # explicitly via .error(), record it now.
        if exc is not None:
            self.error(exc)
        return False
