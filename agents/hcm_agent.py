"""
HCM (Human Capital Management) EBS Agent.
Specializes in: HR Core, Payroll, Benefits, OTL, AME, Performance Appraisal.
"""

import logging
from typing import Any, Dict, List, Optional

from config.analyzer_registry import ANALYZER_REGISTRY, MODULE_HCM, get_analyzer
from tools.oracle_db import OracleDB
from tools.sql_executor import SQLExecutor
from tools.result_parser import ResultParser, Finding

logger = logging.getLogger(__name__)

HCM_ANALYZERS = [k for k, v in ANALYZER_REGISTRY.items() if v["module"] == MODULE_HCM]

SYSTEM_CONTEXT = """
HCM EBS Agent — Specializes in:
- HR Core (HR): Organization structure, positions, grades, business groups
- Payroll (PAY): Payroll runs, element processing, balances, tax withholding
- Benefits (BEN): Plan setup, eligibility rules, enrollment processing, life events
- Oracle Time & Labor (OTL): Timecard processing, approval workflow, HXC
- Approval Management Engine (AME): Rules, conditions, actions, approval routing
- Performance Appraisal: Templates, review cycles, appraisal workflow
- HCM Person: Person records, employee data integrity
"""


class HCMAgent:
    """
    HCM module agent for EBS support analysis.
    Handles payroll, HR, and workforce management diagnostics.
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
        """Return all HCM analyzer definitions."""
        return [ANALYZER_REGISTRY[k] for k in HCM_ANALYZERS if k in ANALYZER_REGISTRY]

    def run_analyzer(self, analyzer_id: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Execute a single HCM analyzer and return findings."""
        analyzer = get_analyzer(analyzer_id)
        if not analyzer:
            return {"success": False, "error": f"Analyzer '{analyzer_id}' not found."}

        result = self.sql_executor.execute_analyzer(
            analyzer_id=analyzer["id"],
            analyze_file=analyzer["analyze_file"],
            params=params or {},
        )

        findings = self.result_parser.parse_analyzer_output(
            analyzer_id=analyzer["id"],
            module=MODULE_HCM,
            raw_rows=result.rows,
            metadata=result.metadata,
        )

        findings = self._enrich_findings(analyzer_id, findings)

        return {
            "success": result.success,
            "analyzer_id": analyzer_id,
            "analyzer_name": analyzer["name"],
            "module": MODULE_HCM,
            "sub_module": analyzer.get("sub_module", ""),
            "findings": findings,
            "raw_output": result.raw_output,
            "execution_time_ms": result.execution_time_ms,
            "demo_mode": result.demo_mode,
            "error": result.error_message,
        }

    def run_payroll_health_check(self) -> Dict[str, Any]:
        """Run payroll-focused health checks."""
        payroll_analyzers = ["pay", "otl", "ame"]
        all_findings: List[Finding] = []
        results = {}

        for aid in payroll_analyzers:
            result = self.run_analyzer(aid)
            results[aid] = result
            all_findings.extend(result.get("findings", []))

        return {
            "analyzers_run": payroll_analyzers,
            "total_findings": len(all_findings),
            "critical_count": sum(1 for f in all_findings if isinstance(f, Finding) and f.severity == "CRITICAL"),
            "results": results,
            "all_findings": all_findings,
        }

    def _enrich_findings(self, analyzer_id: str, findings: List[Finding]) -> List[Finding]:
        """Apply HCM-specific enrichment to findings."""
        enriched = []
        for finding in findings:
            # Payroll run errors and balance errors are always CRITICAL
            if analyzer_id == "pay":
                if any(kw in finding.description.lower() for kw in ("run error", "balance error", "failed")):
                    finding.severity = "CRITICAL"

            # OTL approval stuck impacts payroll processing
            if analyzer_id == "otl" and "stuck" in finding.description.lower():
                if finding.severity != "CRITICAL":
                    finding.severity = "HIGH"

            # AME infinite loop or missing approver is CRITICAL
            if analyzer_id == "ame" and any(kw in finding.description.lower()
                                            for kw in ("infinite loop", "no approver", "missing approver")):
                finding.severity = "CRITICAL"

            enriched.append(finding)
        return enriched
