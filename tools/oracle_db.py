"""
Oracle EBS Database connection and query execution.
Uses python-oracledb (Oracle's modern driver, thin mode — no Instant Client required).
Falls back to demo mode with realistic mock data when Oracle is unreachable.
"""

import os
import logging
from typing import Any, Dict, List, Optional
from datetime import datetime, timedelta
import random

logger = logging.getLogger(__name__)

DEMO_MODE = os.environ.get("DEMO_MODE", "true").lower() == "true"


class OracleDB:
    """
    Manages Oracle EBS database connections and query execution.
    Falls back to demo mode when Oracle is not available or DEMO_MODE=true.
    """

    def __init__(self):
        self.host = os.environ.get("ORACLE_HOST", "apps.example.com")
        self.port = int(os.environ.get("ORACLE_PORT", "1521"))
        self.sid = os.environ.get("ORACLE_SID", "EBSDB")
        self.service_name = os.environ.get("ORACLE_SERVICE_NAME", "EBSDB")
        self.user = os.environ.get("ORACLE_USER", "apps")
        self.password = os.environ.get("ORACLE_PASSWORD", "apps")
        self.client_dir = os.environ.get("ORACLE_CLIENT_DIR", "")
        self.demo_mode = DEMO_MODE
        self._connection = None
        self._pool = None
        self._connected = False

    def connect(self) -> bool:
        """
        Establish oracledb connection. Returns True on success.
        Automatically falls back to demo mode if connection fails.
        """
        if self.demo_mode:
            logger.info("DEMO_MODE enabled — using mock Oracle connection.")
            self._connected = True
            return True

        try:
            import oracledb  # type: ignore

            # Attempt thick mode if client_dir provided (required for NNE)
            if self.client_dir:
                try:
                    oracledb.init_oracle_client(lib_dir=self.client_dir)
                except Exception as init_exc:
                    if "already" not in str(init_exc).lower():
                        logger.warning("Thick mode init failed: %s", init_exc)

            self._connection = oracledb.connect(
                user=self.user,
                password=self.password,
                host=self.host,
                port=self.port,
                service_name=self.service_name,
            )
            self._connected = True
            logger.info("Oracle DB connection established: %s@%s", self.user, self.host)
            return True
        except ImportError:
            logger.warning("oracledb not installed — switching to demo mode.")
            self.demo_mode = True
            self._connected = True
            return True
        except Exception as exc:
            logger.error("Oracle connection failed: %s — switching to demo mode.", exc)
            self.demo_mode = True
            self._connected = True
            return True

    def test_connection(self) -> Dict[str, Any]:
        """Health check. Returns status dict."""
        if self.demo_mode:
            return {
                "status": "demo",
                "connected": True,
                "host": self.host,
                "sid": self.sid,
                "message": "Running in DEMO mode — no live Oracle connection.",
            }
        if not self._connected or self._connection is None:
            ok = self.connect()
            if not ok:
                return {"status": "error", "connected": False, "message": "Could not connect."}
        try:
            cur = self._connection.cursor()
            cur.execute("SELECT 1 FROM DUAL")
            cur.close()
            return {"status": "ok", "connected": True, "host": self.host, "sid": self.sid}
        except Exception as exc:
            return {"status": "error", "connected": False, "message": str(exc)}

    # Maximum seconds any single query may run before being cancelled
    QUERY_TIMEOUT_SECS = 30

    def execute_query(
        self,
        sql: str,
        params: Optional[Dict[str, Any]] = None,
        max_rows: int = 200,
    ) -> List[Dict[str, Any]]:
        """
        Execute a SELECT query and return results as list of dicts.
        Hard 30-second call timeout prevents hung queries.
        Uses connection pool when available. Limits to max_rows rows.
        In demo mode returns empty list (callers should use demo data helpers).
        """
        if self.demo_mode:
            return []
        if not self._connected:
            self.connect()
        try:
            conn = self._get_connection()
            # Hard timeout: cancel query after QUERY_TIMEOUT_SECS seconds
            conn.call_timeout = self.QUERY_TIMEOUT_SECS * 1000  # milliseconds
            cur = conn.cursor()
            cur.arraysize = 100  # fetch in batches of 100
            cur.prefetchrows = 100
            cur.execute(sql, params or {})
            columns = [col[0].lower() for col in cur.description]
            rows = []
            while True:
                batch = cur.fetchmany(100)
                if not batch:
                    break
                for row in batch:
                    rows.append(dict(zip(columns, row)))
                if len(rows) >= max_rows:
                    rows = rows[:max_rows]
                    break
            cur.close()
            return rows
        except Exception as exc:
            logger.error("Query execution error: %s", exc)
            raise  # Re-raise so callers can report specific timeout/error

    def _get_connection(self):
        """Return a connection from pool or the direct connection."""
        if self._pool is not None:
            return self._pool.acquire()
        if self._connection is None:
            self.connect()
        return self._connection

    def create_pool(self, min_connections: int = 2, max_connections: int = 5) -> bool:
        """Create a connection pool for better performance."""
        if self.demo_mode:
            return False
        try:
            import oracledb
            self._pool = oracledb.create_pool(
                user=self.user,
                password=self.password,
                host=self.host,
                port=self.port,
                service_name=self.service_name,
                min=min_connections,
                max=max_connections,
                increment=1,
            )
            logger.info("Oracle connection pool created: min=%d max=%d", min_connections, max_connections)
            return True
        except Exception as exc:
            logger.warning("Could not create connection pool (will use single connection): %s", exc)
            return False

    def execute_sql_file(self, filepath: str) -> List[Dict[str, Any]]:
        """
        Read and execute a SQL file. Returns query results.
        In demo mode, returns empty list (mock data is provided upstream).
        """
        if self.demo_mode:
            return []
        try:
            with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
                sql_content = f.read()
            # Execute meaningful SELECT statements only
            import sqlparse  # type: ignore
            statements = sqlparse.split(sql_content)
            results = []
            for stmt in statements:
                stripped = stmt.strip().upper()
                if stripped.startswith("SELECT"):
                    results.extend(self.execute_query(stmt))
            return results
        except Exception as exc:
            logger.error("SQL file execution error for %s: %s", filepath, exc)
            return []

    def get_ebs_version(self) -> Dict[str, str]:
        """Return EBS release name and database version."""
        if self.demo_mode:
            return {
                "release_name": "12.2.11",
                "db_version": "19.22.0.0.0",
                "db_version_short": "19",
                "instance_name": "EBSDB",
                "host_name": "apps.example.com",
            }
        rows = self.execute_query(
            "SELECT release_name FROM fnd_product_groups WHERE rownum = 1"
        )
        release = rows[0].get("release_name", "Unknown") if rows else "Unknown"
        ver_rows = self.execute_query("SELECT version FROM V$INSTANCE")
        db_ver = ver_rows[0].get("version", "Unknown") if ver_rows else "Unknown"
        return {
            "release_name": release,
            "db_version": db_ver,
            "db_version_short": db_ver.split(".")[0] if "." in db_ver else db_ver,
            "instance_name": self.sid,
            "host_name": self.host,
        }

    def get_installed_products(self) -> List[Dict[str, str]]:
        """Return list of installed EBS products from FND_APPLICATION_VL."""
        if self.demo_mode:
            return [
                {"application_short_name": "SQLGL", "application_name": "General Ledger", "status": "I"},
                {"application_short_name": "AR", "application_name": "Receivables", "status": "I"},
                {"application_short_name": "AP", "application_name": "Payables", "status": "I"},
                {"application_short_name": "FA", "application_name": "Assets", "status": "I"},
                {"application_short_name": "CE", "application_name": "Cash Management", "status": "I"},
                {"application_short_name": "PO", "application_name": "Purchasing", "status": "I"},
                {"application_short_name": "INV", "application_name": "Inventory", "status": "I"},
                {"application_short_name": "BOM", "application_name": "Bills of Material", "status": "I"},
                {"application_short_name": "WIP", "application_name": "Work In Process", "status": "I"},
                {"application_short_name": "CST", "application_name": "Cost Management", "status": "I"},
                {"application_short_name": "OE", "application_name": "Order Management", "status": "I"},
                {"application_short_name": "WSH", "application_name": "Shipping Execution", "status": "I"},
                {"application_short_name": "PAY", "application_name": "Payroll", "status": "I"},
                {"application_short_name": "HR", "application_name": "Human Resources", "status": "I"},
                {"application_short_name": "PA", "application_name": "Projects", "status": "I"},
                {"application_short_name": "QP", "application_name": "Advanced Pricing", "status": "I"},
                {"application_short_name": "WF", "application_name": "Workflow", "status": "I"},
                {"application_short_name": "FND", "application_name": "Application Object Library", "status": "I"},
            ]
        rows = self.execute_query(
            """SELECT application_short_name, application_name,
                      decode(status,'I','Installed','S','Shared','Not Installed') status
               FROM fnd_application_vl
               ORDER BY application_name"""
        )
        return rows

    def get_concurrent_managers(self) -> List[Dict[str, Any]]:
        """Return concurrent manager status (demo data if in demo mode)."""
        if self.demo_mode:
            return [
                {
                    "manager_name": "Internal Concurrent Manager",
                    "target_processes": 1,
                    "actual_processes": 1,
                    "running_requests": 0,
                    "pending_requests": 0,
                    "status": "ACTIVE",
                },
                {
                    "manager_name": "Standard Manager",
                    "target_processes": 5,
                    "actual_processes": 5,
                    "running_requests": 3,
                    "pending_requests": 8,
                    "status": "ACTIVE",
                },
                {
                    "manager_name": "Scheduler",
                    "target_processes": 1,
                    "actual_processes": 1,
                    "running_requests": 0,
                    "pending_requests": 0,
                    "status": "ACTIVE",
                },
                {
                    "manager_name": "Conflict Resolution Manager",
                    "target_processes": 1,
                    "actual_processes": 1,
                    "running_requests": 0,
                    "pending_requests": 0,
                    "status": "ACTIVE",
                },
                {
                    "manager_name": "Output Post Processor",
                    "target_processes": 2,
                    "actual_processes": 2,
                    "running_requests": 1,
                    "pending_requests": 0,
                    "status": "ACTIVE",
                },
            ]
        return self.execute_query(
            """SELECT
               fcq.USER_CONCURRENT_QUEUE_NAME manager_name,
               fcq.MAX_PROCESSES target_processes,
               fcq.RUNNING_PROCESSES actual_processes,
               NVL((SELECT COUNT(*) FROM FND_CONCURRENT_REQUESTS r
                    WHERE r.CONTROLLING_MANAGER = fcq.CONCURRENT_QUEUE_ID
                    AND r.STATUS_CODE = 'R'),0) running_requests,
               NVL((SELECT COUNT(*) FROM FND_CONCURRENT_REQUESTS r
                    WHERE r.PHASE_CODE = 'P' AND r.STATUS_CODE = 'I'),0) pending_requests,
               DECODE(fcq.MANAGER_TYPE,'0','ICM','A','ACTIVE','OTHER') status
               FROM FND_CONCURRENT_QUEUES_VL fcq
               ORDER BY fcq.USER_CONCURRENT_QUEUE_NAME"""
        )

    def connect_live(
        self,
        host: str = None,
        port: int = None,
        service_name: str = None,
        user: str = None,
        password: str = None,
        client_dir: str = None,
    ) -> Dict[str, Any]:
        """
        Attempt a real Oracle connection with the provided (or env-default) credentials.
        Does NOT fall back to demo mode on failure — returns a detailed status dict.
        """
        h  = host         or self.host
        p  = int(port)    if port else self.port
        sn = service_name or self.service_name
        u  = user         or self.user
        pw = password     or self.password
        cd = client_dir   or self.client_dir

        try:
            import oracledb  # type: ignore
        except ImportError:
            return {
                "success": False,
                "mode": "demo",
                "error": "oracledb package not installed.",
                "suggestion": "Run: pip install oracledb",
            }

        # Attempt thick mode if client_dir provided (required for NNE / advanced security)
        thick_mode_ok = False
        if cd:
            try:
                oracledb.init_oracle_client(lib_dir=cd)
                thick_mode_ok = True
            except Exception as init_exc:
                # Already initialised is fine
                if "already" in str(init_exc).lower():
                    thick_mode_ok = True
                else:
                    logger.warning("Thick mode init failed: %s", init_exc)

        # First attempt: connect (thick mode if initialised, thin mode otherwise)
        try:
            conn = oracledb.connect(
                user=u,
                password=pw,
                host=h,
                port=p,
                service_name=sn,
            )
        except Exception as exc:
            err_msg = str(exc)
            # If thin mode failed due to NNE, guide user to provide client_dir
            if "thick mode" in err_msg.lower() or "DPY-3001" in err_msg:
                suggestion = (
                    "Your Oracle database requires Native Network Encryption (NNE), "
                    "which needs thick mode. Provide the Oracle Client Directory "
                    "(e.g. C:\\oracle\\instantclient_23_0) and retry."
                )
                if cd and not thick_mode_ok:
                    suggestion = (
                        f"Thick mode init failed with client dir '{cd}'. "
                        "Verify the path contains a valid Oracle Instant Client."
                    )
                logger.warning("Connection failed (NNE requires thick mode): %s", exc)
                return {
                    "success": False,
                    "mode": "demo",
                    "error": f"Connection failed: {err_msg}",
                    "suggestion": suggestion,
                    "host": h,
                    "service_name": sn,
                }
            raise  # re-raise for the outer handler

        try:
            # Quick smoke-test
            cur = conn.cursor()
            cur.execute("SELECT 1 FROM DUAL")
            cur.close()

            # Commit new state
            if self._connection:
                try:
                    self._connection.close()
                except Exception:
                    pass
            self._connection = conn
            self._connected  = True
            self.demo_mode   = False
            self.host        = h
            self.port        = p
            self.service_name = sn
            self.user        = u
            self.password    = pw
            self.client_dir  = cd or self.client_dir

            logger.info("Live Oracle connection established: %s@%s/%s", u, h, sn)
            return {
                "success": True,
                "mode": "live",
                "host": h,
                "port": p,
                "service_name": sn,
                "user": u,
                "message": f"Connected to {h}/{sn} as {u}",
            }

        except Exception as exc:
            logger.warning("Live Oracle connection failed: %s", exc)
            return {
                "success": False,
                "mode": "demo",
                "error": str(exc),
                "host": h,
                "service_name": sn,
            }

    def set_demo_mode(self, demo: bool = True) -> None:
        """Switch between demo mode and live mode."""
        if demo:
            if self._connection:
                try:
                    self._connection.close()
                except Exception:
                    pass
            self._connection = None
            self._connected  = True
            self.demo_mode   = True
            logger.info("Switched to Demo Mode.")
        else:
            self.demo_mode = False
            logger.info("Demo Mode disabled — next query will attempt live Oracle.")

    def get_credentials_info(self) -> Dict[str, Any]:
        """Return current connection configuration (password excluded)."""
        return {
            "host":         self.host,
            "port":         self.port,
            "service_name": self.service_name,
            "sid":          self.sid,
            "user":         self.user,
            "client_dir":   self.client_dir,
            "demo_mode":    self.demo_mode,
            "connected":    self._connected,
        }

    def close(self):
        """Close Oracle connection and pool."""
        if self._pool:
            try:
                self._pool.close()
            except Exception:
                pass
            self._pool = None
        if self._connection:
            try:
                self._connection.close()
            except Exception:
                pass
        self._connected = False
        self._connection = None


# ─── Demo data factory ───────────────────────────────────────────────────────

def _rand_date(days_ago_min: int = 0, days_ago_max: int = 30) -> str:
    """Return a random date string within a range of days ago."""
    delta = random.randint(days_ago_min, days_ago_max)
    return (datetime.now() - timedelta(days=delta)).strftime("%Y-%m-%d")


DEMO_MOCK_DATA: Dict[str, List[Dict[str, Any]]] = {
    "cp": [
        {
            "section": "CONCURRENT_MANAGER_STATUS",
            "finding": "ACTIVE managers found: 5 of 5",
            "detail": "All concurrent managers are running normally.",
            "severity": "INFO",
            "count": 5,
        },
        {
            "section": "STUCK_REQUESTS",
            "finding": "2 requests stuck in RUNNING state > 4 hours",
            "detail": "Request ID 1234567 (Auto Lockbox) running since 2026-03-31 08:12 — 6 hrs. Request ID 1234568 (GL Journal Import) running since 2026-03-31 07:45 — 7 hrs.",
            "severity": "HIGH",
            "count": 2,
        },
        {
            "section": "PENDING_REQUESTS",
            "finding": "18 requests in PENDING_NORMAL queue",
            "detail": "Standard Manager queue depth is elevated. Consider increasing worker processes.",
            "severity": "MEDIUM",
            "count": 18,
        },
        {
            "section": "INACTIVE_MANAGERS",
            "finding": "No inactive managers detected",
            "detail": "All managers responding normally.",
            "severity": "INFO",
            "count": 0,
        },
    ],
    "ap_period_close": [
        {
            "section": "UNPOSTED_INVOICES",
            "finding": "45 unposted invoices in current period",
            "detail": "Period: MAR-2026. Invoices with status NEVER VALIDATED or NEEDS REVALIDATION: 45. Oldest: 2026-03-01.",
            "severity": "CRITICAL",
            "count": 45,
        },
        {
            "section": "UNCONFIRMED_PAYMENT_BATCHES",
            "finding": "3 payment batches not confirmed",
            "detail": "Batch IDs: 5001 (USD 125,450.00), 5002 (EUR 88,200.00), 5003 (GBP 12,000.00). These must be confirmed before period close.",
            "severity": "HIGH",
            "count": 3,
        },
        {
            "section": "UNPAID_INVOICES_CLOSED_PERIOD",
            "finding": "No invoices in prior closed period",
            "detail": "FEB-2026 is fully closed with no outstanding items.",
            "severity": "INFO",
            "count": 0,
        },
        {
            "section": "ACCOUNTING_HOLDS",
            "finding": "7 invoices on accounting hold",
            "detail": "Invoices held due to missing charge account or invalid account combination.",
            "severity": "MEDIUM",
            "count": 7,
        },
        {
            "section": "AP_SLA_ERRORS",
            "finding": "2 invoices with SLA transfer errors",
            "detail": "SLA CREATE events failed. Run Create Accounting program for AP.",
            "severity": "HIGH",
            "count": 2,
        },
    ],
    "gl_hc": [
        {
            "section": "UNPOSTED_JOURNALS",
            "finding": "2 unposted journals in MAR-2026",
            "detail": "Journal 'MAR-2026 Accruals' (USD 45,000) and 'MAR-2026 Depreciation' (USD 120,000) are unposted.",
            "severity": "CRITICAL",
            "count": 2,
        },
        {
            "section": "PERIOD_STATUS",
            "finding": "1 period open beyond threshold (90 days)",
            "detail": "Period DEC-2025 is still OPEN. It should have been closed. This may allow backdated entries.",
            "severity": "HIGH",
            "count": 1,
        },
        {
            "section": "COA_ISSUES",
            "finding": "No invalid account combinations found",
            "detail": "Chart of Accounts integrity check passed.",
            "severity": "INFO",
            "count": 0,
        },
        {
            "section": "RECON_DIFFERENCES",
            "finding": "GL/SLA out of balance: USD 3,240.50",
            "detail": "Subledger accounting balance does not match GL balance for ledger 'Vision Operations'. Difference: 3,240.50 USD.",
            "severity": "CRITICAL",
            "count": 1,
        },
        {
            "section": "SUSPENSE_ACTIVITY",
            "finding": "Suspense account activity: 14 entries, total USD 87,500",
            "detail": "Suspense account 01-0000-21000-0000 has 14 entries in MAR-2026 requiring review.",
            "severity": "MEDIUM",
            "count": 14,
        },
    ],
    "ar_periodclose": [
        {
            "section": "UNPOSTED_RECEIPTS",
            "finding": "12 unposted cash receipts",
            "detail": "12 receipts in UNCONFIRMED or UNAPPLIED status. Total: USD 234,500.",
            "severity": "CRITICAL",
            "count": 12,
        },
        {
            "section": "INCOMPLETE_INVOICES",
            "finding": "3 incomplete AR invoices",
            "detail": "Transactions in INCOMPLETE status: INV-2026-0042, INV-2026-0043, INV-2026-0044.",
            "severity": "HIGH",
            "count": 3,
        },
        {
            "section": "SLA_ERRORS",
            "finding": "0 SLA transfer errors",
            "detail": "All AR accounting events transferred successfully.",
            "severity": "INFO",
            "count": 0,
        },
    ],
    "workflow": [
        {
            "section": "MAILER_STATUS",
            "finding": "Workflow mailer is RUNNING",
            "detail": "SMTP mailer process active. Last notification sent: 2 minutes ago.",
            "severity": "INFO",
            "count": 1,
        },
        {
            "section": "STUCK_ACTIVITIES",
            "finding": "23 stuck workflow activities",
            "detail": "23 DEFERRED or ERROR activities older than 24 hours across 8 workflow item types. Top offenders: APINVAPR (15), POAPPRV (5), HRASSIGN (3).",
            "severity": "HIGH",
            "count": 23,
        },
        {
            "section": "BACKGROUND_ENGINE",
            "finding": "Background engine last run: 47 minutes ago",
            "detail": "Background engine should run every 15 minutes. Current gap: 47 minutes. Check scheduled concurrent request.",
            "severity": "MEDIUM",
            "count": 1,
        },
        {
            "section": "PURGE_STATUS",
            "finding": "Workflow purge not run in 180+ days",
            "detail": "WF_PURGE tables contain 2.4M obsolete rows. Performance impact likely. Run WF_PURGE.TOTAL program.",
            "severity": "HIGH",
            "count": 2400000,
        },
    ],
    "mon": [
        {
            "section": "TABLESPACE_USAGE",
            "finding": "APPS_TS_TX_DATA tablespace at 92% capacity",
            "detail": "Total: 500 GB, Used: 460 GB, Free: 40 GB. Add datafile or enable autoextend immediately.",
            "severity": "CRITICAL",
            "count": 1,
        },
        {
            "section": "INVALID_OBJECTS",
            "finding": "34 invalid database objects",
            "detail": "34 INVALID objects in APPS schema. Run utlrp.sql to recompile. Review any persistent invalids.",
            "severity": "HIGH",
            "count": 34,
        },
        {
            "section": "LONG_RUNNING_SESSIONS",
            "finding": "2 sessions running > 8 hours",
            "detail": "Session SID 1234 (AP_CLOSE batch) 9.2 hrs. Session SID 5678 (GL_CONSOLIDATION) 8.7 hrs.",
            "severity": "MEDIUM",
            "count": 2,
        },
        {
            "section": "REDO_LOG_SWITCHES",
            "finding": "Redo log switches: 45 in last hour",
            "detail": "High redo generation. Consider increasing redo log size or investigate bulk operations.",
            "severity": "MEDIUM",
            "count": 45,
        },
    ],
    "fa": [
        {
            "section": "DEPRECIATION_STATUS",
            "finding": "Depreciation not run for MAR-2026",
            "detail": "Corporate Book 'OPS CORP' has not had depreciation run for period MAR-2026. Assets: 4,521.",
            "severity": "CRITICAL",
            "count": 1,
        },
        {
            "section": "MASS_ADDITIONS",
            "finding": "67 mass additions pending",
            "detail": "67 assets in QUEUE status awaiting mass additions program. Oldest: 2026-02-15.",
            "severity": "HIGH",
            "count": 67,
        },
        {
            "section": "UNPOSTED_ADJUSTMENTS",
            "finding": "0 unposted adjustments",
            "detail": "All FA adjustments are posted.",
            "severity": "INFO",
            "count": 0,
        },
    ],
    "pay": [
        {
            "section": "PAYROLL_RUN_STATUS",
            "finding": "Payroll run MAR-2026 complete",
            "detail": "Monthly payroll for 1,234 employees processed. Total gross: USD 2,456,789.",
            "severity": "INFO",
            "count": 1234,
        },
        {
            "section": "BALANCE_ERRORS",
            "finding": "3 employees with balance discrepancies",
            "detail": "Employees EMP-00456, EMP-00782, EMP-01123 have YTD balance mismatches requiring manual review.",
            "severity": "HIGH",
            "count": 3,
        },
        {
            "section": "ELEMENT_ERRORS",
            "finding": "0 element processing errors",
            "detail": "All payroll elements processed without errors.",
            "severity": "INFO",
            "count": 0,
        },
    ],
    "wip": [
        {
            "section": "STUCK_JOBS",
            "finding": "5 WIP jobs with no activity > 30 days",
            "detail": "Jobs WIP-2026-001 through WIP-2026-005 are RELEASED with no transactions for 30+ days.",
            "severity": "HIGH",
            "count": 5,
        },
        {
            "section": "COMPONENT_SHORTAGES",
            "finding": "12 jobs with component shortages",
            "detail": "12 discrete jobs have required components with zero on-hand quantity.",
            "severity": "HIGH",
            "count": 12,
        },
        {
            "section": "VARIANCE_ANALYSIS",
            "finding": "Total WIP variance: USD 45,234",
            "detail": "Material variance: USD 32,100. Resource variance: USD 13,134.",
            "severity": "MEDIUM",
            "count": 45234,
        },
    ],
    "om": [
        {
            "section": "STUCK_ORDERS",
            "finding": "8 sales orders stuck in workflow",
            "detail": "Orders stuck in BOOKING, SCHEDULING, or SHIPPING workflow activities. Order IDs: 1000234-1000241.",
            "severity": "CRITICAL",
            "count": 8,
        },
        {
            "section": "PRICING_ERRORS",
            "finding": "15 order lines with pricing errors",
            "detail": "15 lines could not price due to missing price list or expired agreement.",
            "severity": "HIGH",
            "count": 15,
        },
        {
            "section": "HOLDS",
            "finding": "34 orders on hold",
            "detail": "Credit holds: 21, Customer holds: 8, Manual holds: 5.",
            "severity": "MEDIUM",
            "count": 34,
        },
    ],
    "inv_trans": [
        {
            "section": "PENDING_TRANSACTIONS",
            "finding": "3 pending MTL transactions",
            "detail": "3 transactions stuck in MTL_TRANSACTIONS_INTERFACE. Error: 'Invalid locator combination'.",
            "severity": "HIGH",
            "count": 3,
        },
        {
            "section": "NEGATIVE_QUANTITIES",
            "finding": "0 items with negative on-hand",
            "detail": "No negative quantity violations detected.",
            "severity": "INFO",
            "count": 0,
        },
    ],
    "default": [
        {
            "section": "ANALYSIS_COMPLETE",
            "finding": "Analysis completed with no critical findings",
            "detail": "Analyzer ran successfully. No critical issues detected in this module.",
            "severity": "INFO",
            "count": 0,
        },
        {
            "section": "GENERAL_HEALTH",
            "finding": "Module health: GOOD",
            "detail": "All key components are functioning within normal parameters.",
            "severity": "INFO",
            "count": 0,
        },
    ],
}


def get_demo_data(analyzer_id: str) -> List[Dict[str, Any]]:
    """Return demo mock data for a given analyzer ID."""
    return DEMO_MOCK_DATA.get(analyzer_id, DEMO_MOCK_DATA["default"])
