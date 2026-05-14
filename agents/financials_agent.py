"""
Financials EBS Agent.
Specializes in: GL, AP, AR, FA, CE, PO, Projects (PA), SLA, IBY, Tax.
"""

import logging
from typing import Any, Dict, List, Optional

from config.analyzer_registry import ANALYZER_REGISTRY, MODULE_FINANCIALS, get_analyzer
from tools.oracle_db import OracleDB
from tools.sql_executor import SQLExecutor
from tools.result_parser import ResultParser, Finding

logger = logging.getLogger(__name__)

FINANCIALS_ANALYZERS = [k for k, v in ANALYZER_REGISTRY.items() if v["module"] == MODULE_FINANCIALS]

# Period close related analyzers — run in this order for month-end checks
PERIOD_CLOSE_SEQUENCE = [
    "ap_period_close",  # AP must be closed first
    "ar_periodclose",   # Then AR
    "fa",               # Fixed Assets depreciation
    "cst_periodclose",  # Cost accounting
    "gl_hc",            # Finally GL
    "sla_setup",        # SLA verification
]

SYSTEM_CONTEXT = """
Financials EBS Agent — Specializes in:
- General Ledger (GL): Journal posting, period management, COA, reconciliation
- Accounts Payable (AP): Invoice processing, period close, payments, accruals
- Accounts Receivable (AR): Receipts, AutoInvoice, TCA, period close
- Fixed Assets (FA): Depreciation, mass additions, asset retirement
- Cash Management (CE): Bank reconciliation, bank statements
- Purchasing (PO): Document integrity, approval workflow, encumbrance
- Projects (PA): Expenditures, billing, capital, financial control
- Subledger Accounting (SLA): Journal entry rules, account derivation
- IBY Payments: Funds capture, funds disbursement
- Tax: AP tax, O2C EB Tax, India GST, Latin America, EMEA
"""


class FinancialsAgent:
    """
    Financials module agent for EBS support analysis.
    Handles period close, accounting, and financial transaction diagnostics.
    """

    def __init__(
        self,
        oracle_db: Optional[OracleDB] = None,
        sql_executor: Optional[SQLExecutor] = None,
        result_parser: Optional[ResultParser] = None,
    ):
        self.oracle_db = oracle_db or OracleDB()
        self.sql_executor = sql_executor or SQLExecutor(oracle_db=self.oracle_db)
        self.result_parser = result_parser or ResultParser()

    def get_module_analyzers(self) -> List[Dict[str, Any]]:
        """Return all Financials analyzer definitions."""
        return [ANALYZER_REGISTRY[k] for k in FINANCIALS_ANALYZERS if k in ANALYZER_REGISTRY]

    def run_analyzer(self, analyzer_id: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Execute a single Financials analyzer and return findings."""
        analyzer = get_analyzer(analyzer_id)
        if not analyzer or analyzer["module"] != MODULE_FINANCIALS:
            # Allow running even if module mismatch (some shared analyzers)
            if not analyzer:
                return {"success": False, "error": f"Analyzer '{analyzer_id}' not found."}

        result = self.sql_executor.execute_analyzer(
            analyzer_id=analyzer["id"],
            analyze_file=analyzer["analyze_file"],
            params=params or {},
        )

        findings = self.result_parser.parse_analyzer_output(
            analyzer_id=analyzer["id"],
            module=analyzer.get("module", MODULE_FINANCIALS),
            raw_rows=result.rows,
            metadata=result.metadata,
        )

        findings = self._enrich_findings(analyzer_id, findings)

        return {
            "success": result.success,
            "analyzer_id": analyzer_id,
            "analyzer_name": analyzer["name"],
            "module": analyzer.get("module", MODULE_FINANCIALS),
            "sub_module": analyzer.get("sub_module", ""),
            "findings": findings,
            "raw_output": result.raw_output,
            "execution_time_ms": result.execution_time_ms,
            "demo_mode": result.demo_mode,
            "error": result.error_message,
        }

    def run_period_close_check(self, period_name: str = "MAR-2026") -> Dict[str, Any]:
        """
        Run the full period close readiness check sequence.
        Returns ordered findings showing what must be resolved before closing.
        """
        params = {"PERIOD_NAME": period_name}
        all_findings: List[Finding] = []
        blockers: List[str] = []
        results = {}

        for analyzer_id in PERIOD_CLOSE_SEQUENCE:
            result = self.run_analyzer(analyzer_id, params=params)
            results[analyzer_id] = result
            findings = result.get("findings", [])
            all_findings.extend(findings)

            # Identify blockers (CRITICAL findings in period close analyzers)
            for f in findings:
                if isinstance(f, Finding) and f.severity == "CRITICAL":
                    blockers.append(f"{analyzer_id}: {f.description[:100]}")

        can_close = len(blockers) == 0
        critical_count = sum(1 for f in all_findings if isinstance(f, Finding) and f.severity == "CRITICAL")
        high_count = sum(1 for f in all_findings if isinstance(f, Finding) and f.severity == "HIGH")

        return {
            "period_name": period_name,
            "can_close_period": can_close,
            "blockers": blockers,
            "total_findings": len(all_findings),
            "critical_count": critical_count,
            "high_count": high_count,
            "sequence_results": results,
            "all_findings": all_findings,
            "recommendation": (
                "Period close is BLOCKED. Resolve critical findings first."
                if not can_close
                else "No critical blockers found. Review HIGH findings before closing."
            ),
        }

    def check_gl_health(self) -> Dict[str, Any]:
        """Quick GL health check."""
        return self.run_analyzer("gl_hc")

    def check_ap_readiness(self) -> Dict[str, Any]:
        """Check AP period close readiness."""
        return self.run_analyzer("ap_period_close")

    def check_ar_readiness(self) -> Dict[str, Any]:
        """Check AR period close readiness."""
        return self.run_analyzer("ar_periodclose")

    def _enrich_findings(self, analyzer_id: str, findings: List[Finding]) -> List[Finding]:
        """Apply Financials-specific enrichment to findings."""
        enriched = []
        for finding in findings:
            # Period close: unposted transactions are always CRITICAL
            if any(kw in finding.description.lower() for kw in ("unposted", "unaccounted")):
                if finding.severity in ("HIGH", "MEDIUM"):
                    finding.severity = "CRITICAL"

            # SLA errors escalation
            if "sla" in analyzer_id and "error" in finding.description.lower():
                finding.severity = "HIGH"

            # Add GL period close context
            if analyzer_id in ("gl_hc", "ap_period_close", "ar_periodclose"):
                if not finding.mos_references:
                    finding.mos_references.append("MOS Doc ID 1581211.1 (Period Close Guide)")

            enriched.append(finding)
        return enriched
