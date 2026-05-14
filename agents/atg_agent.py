"""
ATG / Core EBS Agent.
Specializes in: Concurrent Processing, Workflow, BI Publisher,
NLS, Monitoring, Reports & Printing, and Profile Options.
"""

import logging
from typing import Any, Dict, List, Optional

from config.analyzer_registry import ANALYZER_REGISTRY, MODULE_ATG, get_analyzer
from tools.oracle_db import OracleDB
from tools.sql_executor import SQLExecutor
from tools.result_parser import ResultParser, Finding

logger = logging.getLogger(__name__)

ATG_ANALYZERS = [k for k, v in ANALYZER_REGISTRY.items() if v["module"] == MODULE_ATG]

SYSTEM_CONTEXT = """
ATG/Core EBS Agent — Specializes in:
- Concurrent Processing (FND_CONCURRENT_*): Manager status, stuck requests, queue depth
- Oracle Workflow (WF_*): Stuck activities, mailer status, background engine
- BI Publisher (XDO_*): Template issues, data sources, delivery channels
- NLS/Globalization: Character sets, language packs, locale settings
- System Monitoring: Tablespace, invalid objects, performance
- Reports & Printing: Report server, printer config, output formats
- Profile Options (FND_PROFILE_*): Critical system and user profiles
"""


class ATGAgent:
    """
    ATG/Core module agent for EBS support analysis.
    Handles infrastructure-level diagnostics.
    """

    # Analyzer-specific post-processing hints
    CRITICAL_SECTION_MAP = {
        "cp": {
            "sections": ["STUCK_REQUESTS", "INACTIVE_MANAGERS"],
            "critical_keywords": ["stuck", "down", "inactive", "error"],
        },
        "workflow": {
            "sections": ["STUCK_ACTIVITIES", "MAILER_STATUS", "BACKGROUND_ENGINE"],
            "critical_keywords": ["stuck", "down", "error", "timeout"],
        },
        "mon": {
            "sections": ["TABLESPACE_USAGE", "INVALID_OBJECTS"],
            "critical_keywords": ["full", "invalid", "corrupt", "error"],
        },
    }

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
        """Return all ATG analyzer definitions."""
        return [ANALYZER_REGISTRY[k] for k in ATG_ANALYZERS if k in ANALYZER_REGISTRY]

    def run_analyzer(self, analyzer_id: str, params: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Execute a single ATG analyzer and return findings."""
        analyzer = get_analyzer(analyzer_id)
        if not analyzer or analyzer["module"] != MODULE_ATG:
            return {"success": False, "error": f"Analyzer '{analyzer_id}' is not an ATG analyzer."}

        result = self.sql_executor.execute_analyzer(
            analyzer_id=analyzer["id"],
            analyze_file=analyzer["analyze_file"],
            params=params or {},
        )

        findings = self.result_parser.parse_analyzer_output(
            analyzer_id=analyzer["id"],
            module=MODULE_ATG,
            raw_rows=result.rows,
            metadata=result.metadata,
        )

        # ATG-specific enrichment
        findings = self._enrich_findings(analyzer_id, findings)

        return {
            "success": result.success,
            "analyzer_id": analyzer_id,
            "analyzer_name": analyzer["name"],
            "module": MODULE_ATG,
            "findings": findings,
            "raw_output": result.raw_output,
            "execution_time_ms": result.execution_time_ms,
            "demo_mode": result.demo_mode,
            "error": result.error_message,
        }

    def run_health_check(self) -> Dict[str, Any]:
        """Run all ATG health check analyzers (cp, mon, workflow)."""
        priority_analyzers = ["cp", "mon", "workflow"]
        all_findings = []
        results = {}

        for aid in priority_analyzers:
            result = self.run_analyzer(aid)
            results[aid] = result
            all_findings.extend(result.get("findings", []))

        critical_count = sum(1 for f in all_findings if isinstance(f, Finding) and f.severity == "CRITICAL")
        high_count = sum(1 for f in all_findings if isinstance(f, Finding) and f.severity == "HIGH")

        overall_health = "HEALTHY"
        if critical_count > 0:
            overall_health = "CRITICAL"
        elif high_count > 0:
            overall_health = "WARNING"

        return {
            "overall_health": overall_health,
            "analyzers_run": priority_analyzers,
            "total_findings": len(all_findings),
            "critical_count": critical_count,
            "high_count": high_count,
            "results": results,
            "all_findings": all_findings,
        }

    def check_concurrent_managers(self) -> Dict[str, Any]:
        """Check concurrent manager status using live DB or demo data."""
        managers = self.oracle_db.get_concurrent_managers()

        down_managers = [m for m in managers if m.get("status", "").upper() not in ("ACTIVE", "ICM")]
        stuck_threshold = 2  # hours
        high_queue_threshold = 20

        issues = []
        for m in managers:
            if m.get("running_requests", 0) > 20:
                issues.append({
                    "severity": "HIGH",
                    "manager": m["manager_name"],
                    "issue": f"High running request count: {m['running_requests']}",
                })
            if m.get("pending_requests", 0) > high_queue_threshold:
                issues.append({
                    "severity": "MEDIUM",
                    "manager": m["manager_name"],
                    "issue": f"Elevated queue depth: {m['pending_requests']} pending requests",
                })

        return {
            "managers": managers,
            "down_managers": down_managers,
            "issues": issues,
            "total_managers": len(managers),
            "healthy_managers": len(managers) - len(down_managers),
        }

    def _enrich_findings(self, analyzer_id: str, findings: List[Finding]) -> List[Finding]:
        """Apply ATG-specific enrichment to findings."""
        enriched = []
        for finding in findings:
            # Escalate severity for CP issues during business hours
            if analyzer_id == "cp" and "stuck" in finding.description.lower():
                if finding.severity not in ("CRITICAL",):
                    finding.severity = "CRITICAL"

            # Add module-specific context
            if not finding.mos_references and analyzer_id in ("cp", "workflow", "mon"):
                analyzer_def = get_analyzer(analyzer_id)
                if analyzer_def and analyzer_def.get("mos_doc_id"):
                    finding.mos_references.append(f"MOS Doc ID {analyzer_def['mos_doc_id']}")

            enriched.append(finding)
        return enriched
