"""
Manufacturing EBS Agent.
Specializes in: INV, BOM, WIP, CST, OM, WSH, ASCP, EAM, WMS, Receiving.
"""

import logging
from typing import Any, Dict, List, Optional

from config.analyzer_registry import ANALYZER_REGISTRY, MODULE_MANUFACTURING, get_analyzer
from tools.oracle_db import OracleDB
from tools.sql_executor import SQLExecutor
from tools.result_parser import ResultParser, Finding

logger = logging.getLogger(__name__)

MANUFACTURING_ANALYZERS = [k for k, v in ANALYZER_REGISTRY.items() if v["module"] == MODULE_MANUFACTURING]

# Quick health check set for manufacturing
MFG_HEALTH_ANALYZERS = ["inv_trans", "wip", "om", "cst_periodclose", "bom"]

SYSTEM_CONTEXT = """
Manufacturing EBS Agent — Specializes in:
- Inventory (INV): Transactions, item master, cycle count, consignment, intercompany
- BOM/WIP: Bill of Materials integrity, WIP jobs, routings
- Cost Management (CST): COGS, period close, reconciliation, PAC, SLA
- Order Management (OM): Sales orders, credit, agreements, performance
- Shipping (WSH): Deliveries, trip stops, freight
- Supply Chain (ASCP): Collections, plan output, Demantra
- Receiving (RCV): PO receipts, receiving transactions
- Warehouse Management (WMS): Putaway, inbound transactions
- EAM: Enterprise Asset Management configuration
- LCM: Landed Cost Management
"""


class ManufacturingAgent:
    """
    Manufacturing module agent for EBS support analysis.
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
        """Return all Manufacturing analyzer definitions."""
        return [ANALYZER_REGISTRY[k] for k in MANUFACTURING_ANALYZERS if k in ANALYZER_REGISTRY]

    def run_analyzer(self, analyzer_id: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Execute a single Manufacturing analyzer and return findings."""
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
            module=analyzer.get("module", MODULE_MANUFACTURING),
            raw_rows=result.rows,
            metadata=result.metadata,
        )

        findings = self._enrich_findings(analyzer_id, findings)

        return {
            "success": result.success,
            "analyzer_id": analyzer_id,
            "analyzer_name": analyzer["name"],
            "module": analyzer.get("module", MODULE_MANUFACTURING),
            "sub_module": analyzer.get("sub_module", ""),
            "findings": findings,
            "raw_output": result.raw_output,
            "execution_time_ms": result.execution_time_ms,
            "demo_mode": result.demo_mode,
            "error": result.error_message,
        }

    def run_mfg_health_check(self) -> Dict[str, Any]:
        """Run manufacturing health check across key analyzers."""
        all_findings: List[Finding] = []
        results = {}

        for aid in MFG_HEALTH_ANALYZERS:
            result = self.run_analyzer(aid)
            results[aid] = result
            all_findings.extend(result.get("findings", []))

        critical_count = sum(1 for f in all_findings if isinstance(f, Finding) and f.severity == "CRITICAL")
        high_count = sum(1 for f in all_findings if isinstance(f, Finding) and f.severity == "HIGH")

        return {
            "overall_health": "CRITICAL" if critical_count > 0 else ("WARNING" if high_count > 0 else "HEALTHY"),
            "analyzers_run": MFG_HEALTH_ANALYZERS,
            "total_findings": len(all_findings),
            "critical_count": critical_count,
            "high_count": high_count,
            "results": results,
            "all_findings": all_findings,
        }

    def run_cost_period_close_check(self, period_name: str = "MAR-2026") -> Dict[str, Any]:
        """Run cost accounting period close check sequence."""
        params = {"PERIOD_NAME": period_name}
        cost_analyzers = ["cst_periodclose", "cst_reconciliation", "cst_sla", "cst_cogs_trx"]
        all_findings: List[Finding] = []
        results = {}

        for aid in cost_analyzers:
            result = self.run_analyzer(aid, params=params)
            results[aid] = result
            all_findings.extend(result.get("findings", []))

        blockers = [
            f.description for f in all_findings
            if isinstance(f, Finding) and f.severity == "CRITICAL"
        ]

        return {
            "period_name": period_name,
            "can_close": len(blockers) == 0,
            "blockers": blockers,
            "analyzers_run": cost_analyzers,
            "total_findings": len(all_findings),
            "results": results,
        }

    def _enrich_findings(self, analyzer_id: str, findings: List[Finding]) -> List[Finding]:
        """Apply Manufacturing-specific enrichment to findings."""
        enriched = []
        for finding in findings:
            # Negative inventory is always CRITICAL
            if "negative" in finding.description.lower() and analyzer_id in ("inv_trans", "cst_reconciliation"):
                finding.severity = "CRITICAL"

            # BOM circular reference is always CRITICAL
            if "circular" in finding.description.lower() and analyzer_id == "bom":
                finding.severity = "CRITICAL"

            # Stuck sales orders are CRITICAL
            if "stuck" in finding.description.lower() and analyzer_id in ("om", "om_order"):
                finding.severity = "CRITICAL"

            enriched.append(finding)
        return enriched
