"""
CRM (Customer Relationship Management) EBS Agent.
Specializes in: Field Service, Service Contracts, Incentive Compensation,
Install Base, iSupplier, Quoting, Advanced Pricing, P2P, CLM.
"""

import logging
from typing import Any, Dict, List, Optional

from config.analyzer_registry import ANALYZER_REGISTRY, MODULE_CRM, get_analyzer
from tools.oracle_db import OracleDB
from tools.sql_executor import SQLExecutor
from tools.result_parser import ResultParser, Finding

logger = logging.getLogger(__name__)

CRM_ANALYZERS = [k for k, v in ANALYZER_REGISTRY.items() if v["module"] == MODULE_CRM]

SYSTEM_CONTEXT = """
CRM EBS Agent — Specializes in:
- Incentive Compensation (CN): Commission calculation, payment batches, dispute resolution
- Depot Repair (CSD): Service order processing, repair workflow
- Field Service (CSF): Task scheduling, technician management, debrief
- Install Base (IB/CSI): Product tracking, instance management
- iSupplier Portal (ISP): Supplier setup, registration, access management
- Service Contracts (OKS): Contract billing, renewals, coverage
- Oracle Social Network (OSN): Integration and collaboration setup
- OZF Trade Management: Accrual processing, SLA transactions
- Procure-to-Pay (P2P): End-to-end P2P cycle integrity
- Quoting (QOT): Quote processing, pricing, conversion
- Advanced Pricing (QP): Price lists, modifiers, pricing engine
- CLM: Contract Lifecycle Management
- iRecruitment: Job posting, applicant processing
"""


class CRMAgent:
    """
    CRM module agent for EBS support analysis.
    Handles customer-facing and supplier portal diagnostics.
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
        """Return all CRM analyzer definitions."""
        return [ANALYZER_REGISTRY[k] for k in CRM_ANALYZERS if k in ANALYZER_REGISTRY]

    def run_analyzer(self, analyzer_id: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Execute a single CRM analyzer and return findings."""
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
            module=analyzer.get("module", MODULE_CRM),
            raw_rows=result.rows,
            metadata=result.metadata,
        )

        findings = self._enrich_findings(analyzer_id, findings)

        return {
            "success": result.success,
            "analyzer_id": analyzer_id,
            "analyzer_name": analyzer["name"],
            "module": analyzer.get("module", MODULE_CRM),
            "sub_module": analyzer.get("sub_module", ""),
            "findings": findings,
            "raw_output": result.raw_output,
            "execution_time_ms": result.execution_time_ms,
            "demo_mode": result.demo_mode,
            "error": result.error_message,
        }

    def run_p2p_health_check(self) -> Dict[str, Any]:
        """Run end-to-end P2P cycle health check."""
        p2p_analyzers = ["p2p", "po_doc", "po_approval", "isp_setup"]
        all_findings: List[Finding] = []
        results = {}

        for aid in p2p_analyzers:
            result = self.run_analyzer(aid)
            results[aid] = result
            all_findings.extend(result.get("findings", []))

        return {
            "analyzers_run": p2p_analyzers,
            "total_findings": len(all_findings),
            "critical_count": sum(1 for f in all_findings if isinstance(f, Finding) and f.severity == "CRITICAL"),
            "results": results,
            "all_findings": all_findings,
        }

    def _enrich_findings(self, analyzer_id: str, findings: List[Finding]) -> List[Finding]:
        """Apply CRM-specific enrichment to findings."""
        enriched = []
        for finding in findings:
            # Incentive compensation calculation errors are CRITICAL (payroll impact)
            if analyzer_id == "cn" and "calculation error" in finding.description.lower():
                finding.severity = "CRITICAL"

            # CLM approval stuck — contract delivery impact
            if analyzer_id == "clm" and "stuck" in finding.description.lower():
                finding.severity = "CRITICAL"

            # Service contract billing errors
            if analyzer_id == "oks_billing" and "billing error" in finding.description.lower():
                finding.severity = "HIGH"

            enriched.append(finding)
        return enriched
