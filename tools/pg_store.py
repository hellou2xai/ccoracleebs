"""
PostgreSQL session, findings, and audit log store.
Falls back to in-memory dict storage when PostgreSQL is unavailable.
"""

import os
import json
import logging
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


class PostgreSQLStore:
    """
    Manages EBS support session data including findings and audit trail.
    Uses PostgreSQL when available; falls back to in-memory storage transparently.
    """

    def __init__(self):
        self.host = os.environ.get("PG_HOST", "localhost")
        self.port = int(os.environ.get("PG_PORT", "5432"))
        self.dbname = os.environ.get("PG_DB", "EBS_MFG")
        self.user = os.environ.get("PG_USER", "postgres")
        self.password = os.environ.get("PG_PASSWORD", "")
        self._conn = None
        self._use_memory = False

        # In-memory fallback storage
        self._sessions: Dict[str, Dict] = {}
        self._findings: List[Dict] = []
        self._audit_log: List[Dict] = []
        self._finding_seq: int = 0
        self._audit_seq: int = 0

    # ─── Connection ───────────────────────────────────────────────────────────

    def _get_conn(self):
        """Return active connection, reconnecting if needed."""
        if self._use_memory:
            return None
        if self._conn is None:
            try:
                import psycopg2  # type: ignore
                import psycopg2.extras  # type: ignore

                self._conn = psycopg2.connect(
                    host=self.host,
                    port=self.port,
                    dbname=self.dbname,
                    user=self.user,
                    password=self.password,
                    connect_timeout=5,
                )
                self._conn.autocommit = True
            except Exception as exc:
                logger.warning("PostgreSQL unavailable (%s) — using in-memory store.", exc)
                self._use_memory = True
                return None
        return self._conn

    def init_schema(self) -> bool:
        """
        Create required tables if they do not exist.
        Returns True if PostgreSQL schema created successfully, False if using memory.
        """
        conn = self._get_conn()
        if conn is None:
            logger.info("Using in-memory storage (no PostgreSQL connection).")
            return False

        try:
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS ebs_sessions (
                    session_id VARCHAR(36) PRIMARY KEY,
                    created_at TIMESTAMP DEFAULT NOW(),
                    updated_at TIMESTAMP DEFAULT NOW(),
                    instance_info JSONB,
                    status VARCHAR(20) DEFAULT 'active'
                );
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS ebs_findings (
                    id SERIAL PRIMARY KEY,
                    session_id VARCHAR(36) REFERENCES ebs_sessions(session_id),
                    analyzer_id VARCHAR(100),
                    module VARCHAR(50),
                    severity VARCHAR(20),
                    category VARCHAR(100),
                    description TEXT,
                    affected_objects JSONB,
                    mos_references JSONB,
                    recommended_action TEXT,
                    auto_fixable BOOLEAN DEFAULT FALSE,
                    raw_output TEXT,
                    created_at TIMESTAMP DEFAULT NOW()
                );
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS ebs_audit_log (
                    id SERIAL PRIMARY KEY,
                    session_id VARCHAR(36),
                    action VARCHAR(100),
                    analyzer_id VARCHAR(100),
                    sql_executed TEXT,
                    result_summary TEXT,
                    duration_ms INTEGER,
                    row_count INTEGER,
                    status VARCHAR(20),
                    error_message TEXT,
                    created_at TIMESTAMP DEFAULT NOW()
                );
            """)
            # Indexes for faster lookups
            cur.execute("""
                CREATE INDEX IF NOT EXISTS idx_findings_session
                ON ebs_findings(session_id);
            """)
            cur.execute("""
                CREATE INDEX IF NOT EXISTS idx_audit_session
                ON ebs_audit_log(session_id);
            """)
            cur.close()
            logger.info("PostgreSQL schema initialized.")
            return True
        except Exception as exc:
            logger.error("Schema init error: %s — falling back to memory.", exc)
            self._use_memory = True
            return False

    # ─── Session Operations ───────────────────────────────────────────────────

    def create_session(self, session_id: str, instance_info: Dict[str, Any]) -> bool:
        """Create a new support session record."""
        conn = self._get_conn()
        if conn is None:
            self._sessions[session_id] = {
                "session_id": session_id,
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
                "instance_info": instance_info,
                "status": "active",
            }
            return True
        try:
            cur = conn.cursor()
            cur.execute(
                """INSERT INTO ebs_sessions (session_id, instance_info, status)
                   VALUES (%s, %s, 'active')
                   ON CONFLICT (session_id) DO UPDATE
                   SET updated_at = NOW(), status = 'active'""",
                (session_id, json.dumps(instance_info)),
            )
            cur.close()
            return True
        except Exception as exc:
            logger.error("create_session error: %s", exc)
            # Fallback to memory
            self._sessions[session_id] = {
                "session_id": session_id,
                "created_at": datetime.now().isoformat(),
                "updated_at": datetime.now().isoformat(),
                "instance_info": instance_info,
                "status": "active",
            }
            return True

    def get_session(self, session_id: str) -> Optional[Dict[str, Any]]:
        """Retrieve session by ID."""
        conn = self._get_conn()
        if conn is None:
            return self._sessions.get(session_id)
        try:
            import psycopg2.extras  # type: ignore

            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cur.execute("SELECT * FROM ebs_sessions WHERE session_id = %s", (session_id,))
            row = cur.fetchone()
            cur.close()
            return dict(row) if row else None
        except Exception as exc:
            logger.error("get_session error: %s", exc)
            return self._sessions.get(session_id)

    def update_session_status(self, session_id: str, status: str) -> bool:
        """Update session status (active/completed/error)."""
        conn = self._get_conn()
        if conn is None:
            if session_id in self._sessions:
                self._sessions[session_id]["status"] = status
                self._sessions[session_id]["updated_at"] = datetime.now().isoformat()
            return True
        try:
            cur = conn.cursor()
            cur.execute(
                "UPDATE ebs_sessions SET status=%s, updated_at=NOW() WHERE session_id=%s",
                (status, session_id),
            )
            cur.close()
            return True
        except Exception as exc:
            logger.error("update_session_status error: %s", exc)
            return False

    def list_recent_sessions(self, limit: int = 10) -> List[Dict[str, Any]]:
        """Return most recent sessions ordered by creation time."""
        conn = self._get_conn()
        if conn is None:
            sessions = sorted(
                self._sessions.values(),
                key=lambda s: s.get("created_at", ""),
                reverse=True,
            )
            return sessions[:limit]
        try:
            import psycopg2.extras  # type: ignore

            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cur.execute(
                """SELECT session_id, created_at, updated_at, status,
                          instance_info->>'release_name' as ebs_version
                   FROM ebs_sessions
                   ORDER BY created_at DESC LIMIT %s""",
                (limit,),
            )
            rows = [dict(r) for r in cur.fetchall()]
            cur.close()
            return rows
        except Exception as exc:
            logger.error("list_recent_sessions error: %s", exc)
            return []

    # ─── Findings Operations ──────────────────────────────────────────────────

    def save_finding(self, session_id: str, finding: Dict[str, Any]) -> bool:
        """Persist a single finding record."""
        conn = self._get_conn()
        if conn is None:
            self._finding_seq += 1
            record = dict(finding, id=self._finding_seq, session_id=session_id,
                          created_at=datetime.now().isoformat())
            self._findings.append(record)
            return True
        try:
            cur = conn.cursor()
            cur.execute(
                """INSERT INTO ebs_findings
                   (session_id, analyzer_id, module, severity, category,
                    description, affected_objects, mos_references,
                    recommended_action, auto_fixable, raw_output)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                (
                    session_id,
                    finding.get("analyzer_id", ""),
                    finding.get("module", ""),
                    finding.get("severity", "INFO"),
                    finding.get("category", ""),
                    finding.get("description", ""),
                    json.dumps(finding.get("affected_objects", [])),
                    json.dumps(finding.get("mos_references", [])),
                    finding.get("recommended_action", ""),
                    finding.get("auto_fixable", False),
                    finding.get("raw_output", ""),
                ),
            )
            cur.close()
            return True
        except Exception as exc:
            logger.error("save_finding error: %s", exc)
            self._finding_seq += 1
            record = dict(finding, id=self._finding_seq, session_id=session_id,
                          created_at=datetime.now().isoformat())
            self._findings.append(record)
            return True

    def get_session_findings(self, session_id: str) -> List[Dict[str, Any]]:
        """Return all findings for a session, ordered by severity."""
        severity_order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "INFO": 4}
        conn = self._get_conn()
        if conn is None:
            findings = [f for f in self._findings if f.get("session_id") == session_id]
            return sorted(findings, key=lambda f: severity_order.get(f.get("severity", "INFO"), 5))
        try:
            import psycopg2.extras  # type: ignore

            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cur.execute(
                """SELECT * FROM ebs_findings
                   WHERE session_id = %s
                   ORDER BY
                     CASE severity
                       WHEN 'CRITICAL' THEN 0 WHEN 'HIGH' THEN 1
                       WHEN 'MEDIUM' THEN 2 WHEN 'LOW' THEN 3 ELSE 4 END,
                     created_at""",
                (session_id,),
            )
            rows = [dict(r) for r in cur.fetchall()]
            cur.close()
            return rows
        except Exception as exc:
            logger.error("get_session_findings error: %s", exc)
            findings = [f for f in self._findings if f.get("session_id") == session_id]
            return sorted(findings, key=lambda f: severity_order.get(f.get("severity", "INFO"), 5))

    def get_findings_summary(self, session_id: str) -> Dict[str, int]:
        """Return count of findings by severity for a session."""
        findings = self.get_session_findings(session_id)
        counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0, "INFO": 0}
        for f in findings:
            sev = f.get("severity", "INFO")
            if sev in counts:
                counts[sev] += 1
        return counts

    # ─── Audit Log Operations ─────────────────────────────────────────────────

    def log_audit(
        self,
        session_id: str,
        action: str,
        analyzer_id: str = "",
        sql_executed: str = "",
        result_summary: str = "",
        duration_ms: int = 0,
        row_count: int = 0,
        status: str = "success",
        error_message: str = "",
    ) -> bool:
        """Write an audit log entry."""
        conn = self._get_conn()
        if conn is None:
            self._audit_seq += 1
            self._audit_log.append({
                "id": self._audit_seq,
                "session_id": session_id,
                "action": action,
                "analyzer_id": analyzer_id,
                "sql_executed": sql_executed[:500] if sql_executed else "",
                "result_summary": result_summary,
                "duration_ms": duration_ms,
                "row_count": row_count,
                "status": status,
                "error_message": error_message,
                "created_at": datetime.now().isoformat(),
            })
            return True
        try:
            cur = conn.cursor()
            cur.execute(
                """INSERT INTO ebs_audit_log
                   (session_id, action, analyzer_id, sql_executed, result_summary,
                    duration_ms, row_count, status, error_message)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                (
                    session_id, action, analyzer_id,
                    (sql_executed or "")[:2000],
                    result_summary, duration_ms, row_count,
                    status, error_message,
                ),
            )
            cur.close()
            return True
        except Exception as exc:
            logger.error("log_audit error: %s", exc)
            return False

    def get_audit_trail(self, session_id: str) -> List[Dict[str, Any]]:
        """Return audit trail for a session."""
        conn = self._get_conn()
        if conn is None:
            return [e for e in self._audit_log if e.get("session_id") == session_id]
        try:
            import psycopg2.extras  # type: ignore

            cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
            cur.execute(
                "SELECT * FROM ebs_audit_log WHERE session_id=%s ORDER BY created_at",
                (session_id,),
            )
            rows = [dict(r) for r in cur.fetchall()]
            cur.close()
            return rows
        except Exception as exc:
            logger.error("get_audit_trail error: %s", exc)
            return [e for e in self._audit_log if e.get("session_id") == session_id]

    def is_postgres_available(self) -> bool:
        """Return True if connected to real PostgreSQL, False if using memory fallback."""
        return not self._use_memory and self._get_conn() is not None

    def get_storage_type(self) -> str:
        """Return 'PostgreSQL' or 'In-Memory'."""
        return "PostgreSQL" if self.is_postgres_available() else "In-Memory"
