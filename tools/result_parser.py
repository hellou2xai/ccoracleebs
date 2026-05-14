"""
Result parser and formatter for Oracle EBS analyzer output.
Converts raw SQL rows into structured Finding objects with severity classification.
"""

import re
import uuid
import logging
from typing import Any, Dict, List, Literal, Optional
from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)

SeverityType = Literal["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"]

# Keywords that indicate each severity level
CRITICAL_PATTERNS = [
    "stuck", "down", "failed", "failure", "error", "unposted", "invalid",
    "out of balance", "negative quantity", "circular reference", "critical",
    "unaccounted", "corrupt", "locked", "deadlock", "tablespace full",
    "depreciation not run", "payroll run error", "budget violation",
    "gstin invalid", "gst filing error", "collection error",
    "plan error", "unprocessed", "mismatch",
]

HIGH_PATTERNS = [
    "pending", "missing", "incomplete", "unconfirmed", "reconciliation",
    "discrepancy", "high", "warning", "unauthorized", "unapproved",
    "duplicate", "exceeds", "overdue", "backlog", "gap", "stuck",
    "invalid", "broken", "not found", "blocked", "hold",
]

MEDIUM_PATTERNS = [
    "review", "investigate", "monitor", "elevated", "unusual",
    "performance", "slow", "medium", "check", "attention",
    "deprecated", "cleanup", "purge", "optimize",
]

LOW_PATTERNS = [
    "minor", "low", "cosmetic", "informational", "note",
    "recommendation", "suggestion", "best practice",
]

# MOS Doc ID extraction pattern
MOS_DOC_PATTERN = re.compile(r"(?:Doc\s+ID|Note|MOS)[:\s#]+(\d+\.\d+)", re.IGNORECASE)

# Common EBS error code patterns
ERROR_CODE_PATTERN = re.compile(r"ORA-\d{4,5}|APP-[A-Z]+-\d{5}|FRM-\d{5}", re.IGNORECASE)


class Finding(BaseModel):
    """Structured EBS analyzer finding."""

    id: str = Field(default_factory=lambda: str(uuid.uuid4())[:8])
    analyzer_id: str
    module: str
    severity: SeverityType = "INFO"
    category: str = ""
    description: str
    affected_objects: List[str] = Field(default_factory=list)
    mos_references: List[str] = Field(default_factory=list)
    recommended_action: str = ""
    auto_fixable: bool = False
    raw_output: str = ""
    count: int = 0

    def to_dict(self) -> Dict[str, Any]:
        return self.model_dump()


class ResultParser:
    """
    Parses raw analyzer output rows into structured Finding objects.
    Applies severity classification and MOS reference extraction.
    """

    # Recommended actions database keyed by (analyzer_id, section)
    RECOMMENDED_ACTIONS: Dict[str, str] = {
        # CP
        "cp:STUCK_REQUESTS": (
            "Navigate to: System Administrator > Concurrent > Requests. "
            "Select the stuck request and click 'Cancel'. If cancel is not effective, "
            "use: SELECT fcp.os_process_id FROM fnd_concurrent_processes fcp, "
            "fnd_concurrent_requests fcr WHERE fcr.controlling_manager = fcp.concurrent_process_id "
            "AND fcr.request_id = <request_id>. Then kill OS process. "
            "See MOS Doc 1411723.1."
        ),
        "cp:PENDING_REQUESTS": (
            "Increase Standard Manager max processes via: System Administrator > "
            "Concurrent > Manager > Work Shifts. Consider adding dedicated managers "
            "for high-volume programs. See MOS Doc 1411723.1."
        ),
        # AP Period Close
        "ap_period_close:UNPOSTED_INVOICES": (
            "Run 'Payables Transfer to General Ledger' program for all unposted invoices. "
            "Navigate to: Payables > Reports > Run. Then validate any invoices in "
            "NEEDS REVALIDATION status. See MOS Doc 1483660.1."
        ),
        "ap_period_close:UNCONFIRMED_PAYMENT_BATCHES": (
            "Navigate to: Payables > Payments > Payment Batches. "
            "Confirm each pending payment batch. See MOS Doc 1483660.1."
        ),
        "ap_period_close:ACCOUNTING_HOLDS": (
            "Navigate to: Payables > Invoices > Query invoices on hold. "
            "Resolve missing charge accounts or invalid account combinations. "
            "Run GL Account Validation program."
        ),
        # GL
        "gl_hc:UNPOSTED_JOURNALS": (
            "Navigate to: General Ledger > Journals > Enter. Post all unposted journal batches. "
            "Use Mass Post program for bulk posting. See MOS Doc 1483679.1."
        ),
        "gl_hc:PERIOD_STATUS": (
            "Close stale open periods via: General Ledger > Setup > Open/Close Periods. "
            "Ensure all sub-ledgers are closed before closing GL period."
        ),
        "gl_hc:RECON_DIFFERENCES": (
            "Run 'Journal Import' and 'Transfer Journal Entries to GL' programs. "
            "Investigate SLA discrepancies using XLA diagnostics. "
            "See MOS Doc 1483679.1."
        ),
        # Workflow
        "workflow:STUCK_ACTIVITIES": (
            "Run Workflow Background Process for the affected item types. "
            "Navigate to: Workflow Administrator > Administration > Notification Mailer. "
            "Also run: BEGIN wf_engine.background('APINVAPR'); END; "
            "See MOS Doc 1378745.1."
        ),
        "workflow:PURGE_STATUS": (
            "Run Workflow Purge program: WF_PURGE.TOTAL('sysdate-180'). "
            "Navigate to: Workflow Administrator > Administration > Purge Obsolete Workflow Runtime Data."
        ),
        # Monitoring
        "mon:TABLESPACE_USAGE": (
            "Add a datafile to the tablespace: "
            "ALTER TABLESPACE APPS_TS_TX_DATA ADD DATAFILE '/path/to/file.dbf' SIZE 10G AUTOEXTEND ON; "
            "Or enable autoextend on existing files."
        ),
        "mon:INVALID_OBJECTS": (
            "Run: @$ORACLE_HOME/rdbms/admin/utlrp.sql to recompile invalid objects. "
            "If objects remain invalid after recompile, investigate dependencies."
        ),
        # Fixed Assets
        "fa:DEPRECIATION_STATUS": (
            "Navigate to: Fixed Assets > Depreciation > Run Depreciation. "
            "Select the corporate book and run for the current period. "
            "See MOS Doc 1483677.1."
        ),
        "fa:MASS_ADDITIONS": (
            "Navigate to: Fixed Assets > Mass Additions > Post Mass Additions. "
            "Review and process pending mass addition lines. "
            "See MOS Doc 1483677.1."
        ),
        # AR Period Close
        "ar_periodclose:UNPOSTED_RECEIPTS": (
            "Post all cash receipts: Navigate to Receivables > Receipts > Post QuickCash. "
            "Run 'Receivables Transfer to General Ledger' program."
        ),
        # WIP
        "wip:STUCK_JOBS": (
            "Review WIP job status: Navigate to Manufacturing > Work in Process > Jobs > Discrete Jobs. "
            "Investigate jobs with no activity. Consider closing stale jobs."
        ),
        # OM
        "om:STUCK_ORDERS": (
            "Navigate to: Order Management > Orders > Order Organizer. "
            "Review workflow activities for stuck orders. "
            "Run Workflow Background Process for OE_ORDER_WF item type."
        ),
    }

    # Analyzer-specific parsing hints
    SECTION_TO_CATEGORY: Dict[str, str] = {
        "STUCK_REQUESTS": "Concurrent Processing",
        "PENDING_REQUESTS": "Concurrent Processing",
        "INACTIVE_MANAGERS": "Concurrent Manager",
        "UNPOSTED_INVOICES": "AP Period Close",
        "UNCONFIRMED_PAYMENT_BATCHES": "AP Payments",
        "ACCOUNTING_HOLDS": "AP Invoice Holds",
        "AP_SLA_ERRORS": "Subledger Accounting",
        "UNPOSTED_JOURNALS": "GL Posting",
        "PERIOD_STATUS": "Period Management",
        "RECON_DIFFERENCES": "GL Reconciliation",
        "SUSPENSE_ACTIVITY": "GL Suspense",
        "MAILER_STATUS": "Workflow Mailer",
        "STUCK_ACTIVITIES": "Workflow Activities",
        "BACKGROUND_ENGINE": "Workflow Engine",
        "PURGE_STATUS": "Workflow Maintenance",
        "TABLESPACE_USAGE": "Database Storage",
        "INVALID_OBJECTS": "Database Objects",
        "LONG_RUNNING_SESSIONS": "Database Sessions",
        "REDO_LOG_SWITCHES": "Database Performance",
        "DEPRECIATION_STATUS": "Fixed Assets Depreciation",
        "MASS_ADDITIONS": "Fixed Assets",
        "PAYROLL_RUN_STATUS": "Payroll Processing",
        "BALANCE_ERRORS": "Payroll Balances",
        "STUCK_JOBS": "WIP Jobs",
        "COMPONENT_SHORTAGES": "WIP Components",
        "STUCK_ORDERS": "Order Management",
        "PRICING_ERRORS": "Pricing",
        "HOLDS": "Order Holds",
        "PENDING_TRANSACTIONS": "Inventory Transactions",
        "UNPOSTED_RECEIPTS": "AR Receipts",
        "INCOMPLETE_INVOICES": "AR Transactions",
    }

    def parse_analyzer_output(
        self,
        analyzer_id: str,
        module: str,
        raw_rows: List[Dict[str, Any]],
        metadata: Optional[Dict[str, Any]] = None,
    ) -> List[Finding]:
        """
        Convert raw SQL rows / demo data rows into structured Finding objects.
        Returns list of Finding instances.
        """
        metadata = metadata or {}
        findings: List[Finding] = []

        for row in raw_rows:
            # Demo/mock data format
            if "finding" in row and "severity" in row:
                finding = self._parse_demo_row(analyzer_id, module, row, metadata)
            else:
                # Live query result format
                finding = self._parse_live_row(analyzer_id, module, row, metadata)

            if finding:
                findings.append(finding)

        return findings

    def _parse_demo_row(
        self,
        analyzer_id: str,
        module: str,
        row: Dict[str, Any],
        metadata: Dict[str, Any],
    ) -> Optional[Finding]:
        """Parse a demo/mock data row into a Finding."""
        section = row.get("section", "GENERAL")
        finding_text = row.get("finding", "")
        detail = row.get("detail", "")
        raw_severity = row.get("severity", "INFO")
        count = row.get("count", 0)

        if not finding_text:
            return None

        severity = self._validate_severity(raw_severity)
        description = f"{finding_text}. {detail}".strip(". ") if detail else finding_text
        category = self.SECTION_TO_CATEGORY.get(section, section.replace("_", " ").title())
        action_key = f"{analyzer_id}:{section}"
        recommended_action = self.RECOMMENDED_ACTIONS.get(
            action_key,
            self._generate_generic_action(analyzer_id, section, severity),
        )
        mos_refs = self.extract_mos_references(f"{finding_text} {detail} {metadata.get('help_text', '')}")
        # Add MOS doc from metadata
        for doc_id in metadata.get("doc_ids", []):
            ref = f"MOS Doc ID {doc_id}"
            if ref not in mos_refs:
                mos_refs.append(ref)

        affected = self._extract_affected_objects(detail, section)
        auto_fixable = severity in ("MEDIUM", "LOW") and section in (
            "PURGE_STATUS", "BACKGROUND_ENGINE"
        )

        return Finding(
            analyzer_id=analyzer_id,
            module=module,
            severity=severity,
            category=category,
            description=description,
            affected_objects=affected,
            mos_references=mos_refs,
            recommended_action=recommended_action,
            auto_fixable=auto_fixable,
            raw_output=str(row),
            count=count,
        )

    def _parse_live_row(
        self,
        analyzer_id: str,
        module: str,
        row: Dict[str, Any],
        metadata: Dict[str, Any],
    ) -> Optional[Finding]:
        """Parse a live database query result row into a Finding."""
        # Try to identify meaningful columns
        row_text = " ".join(str(v) for v in row.values() if v is not None)
        if not row_text.strip():
            return None

        severity = self.classify_severity(row_text, analyzer_id)
        mos_refs = self.extract_mos_references(row_text)
        error_codes = self.extract_error_codes(row_text)
        if error_codes:
            mos_refs.extend([f"Error: {code}" for code in error_codes])

        # Best-effort description from column values
        description_cols = ["message", "description", "finding", "status", "error_text", "detail"]
        description = ""
        for col in description_cols:
            if col in row and row[col]:
                description = str(row[col])
                break
        if not description:
            description = row_text[:300]

        return Finding(
            analyzer_id=analyzer_id,
            module=module,
            severity=severity,
            category=analyzer_id.replace("_", " ").title(),
            description=description,
            affected_objects=[],
            mos_references=mos_refs,
            recommended_action=self._generate_generic_action(analyzer_id, "", severity),
            auto_fixable=False,
            raw_output=str(row),
        )

    def classify_severity(self, finding_text: str, analyzer_id: str = "") -> SeverityType:
        """
        Determine CRITICAL/HIGH/MEDIUM/LOW/INFO severity from finding text.
        Uses keyword matching with weights.
        """
        text_lower = finding_text.lower()

        # Check for explicit severity markers first
        for level in ("CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"):
            if level.lower() in text_lower and "severity" not in text_lower:
                pass  # fall through to pattern matching

        # Count pattern matches
        critical_count = sum(1 for p in CRITICAL_PATTERNS if p in text_lower)
        high_count = sum(1 for p in HIGH_PATTERNS if p in text_lower)
        medium_count = sum(1 for p in MEDIUM_PATTERNS if p in text_lower)
        low_count = sum(1 for p in LOW_PATTERNS if p in text_lower)

        # Explicit zero-count findings are INFO
        zero_patterns = ["no ", "0 ", "none ", "not found", "not detected", "passed", "complete", "good"]
        is_zero = any(text_lower.startswith(p) or f" {p}" in text_lower for p in zero_patterns)
        if is_zero and critical_count == 0 and high_count == 0:
            return "INFO"

        if critical_count >= 1:
            return "CRITICAL"
        if high_count >= 2 or (high_count >= 1 and critical_count == 0):
            return "HIGH"
        if medium_count >= 1:
            return "MEDIUM"
        if low_count >= 1:
            return "LOW"
        return "INFO"

    def _validate_severity(self, severity: str) -> SeverityType:
        """Ensure severity is a valid value."""
        valid = {"CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"}
        upper = severity.upper()
        return upper if upper in valid else "INFO"  # type: ignore[return-value]

    def extract_mos_references(self, text: str) -> List[str]:
        """Extract Oracle MOS document ID references from text."""
        matches = MOS_DOC_PATTERN.findall(text)
        refs = []
        for match in matches:
            ref = f"MOS Doc ID {match}"
            if ref not in refs:
                refs.append(ref)
        return refs

    def extract_error_codes(self, text: str) -> List[str]:
        """Extract Oracle error codes (ORA-, APP-, FRM-) from text."""
        return list(set(ERROR_CODE_PATTERN.findall(text)))

    def format_for_display(self, findings: List[Finding]) -> str:
        """Format findings list as human-readable text."""
        if not findings:
            return "No findings to display."

        lines = ["=" * 60, "EBS ANALYZER FINDINGS", "=" * 60, ""]
        severity_order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "INFO": 4}
        sorted_findings = sorted(findings, key=lambda f: severity_order.get(f.severity, 5))

        for i, finding in enumerate(sorted_findings, 1):
            icon = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "LOW": "🟢", "INFO": "🔵"}.get(
                finding.severity, "⚪"
            )
            lines.append(f"{icon} [{finding.severity}] Finding #{i}: {finding.category}")
            lines.append(f"   Analyzer  : {finding.analyzer_id}")
            lines.append(f"   Module    : {finding.module}")
            lines.append(f"   Issue     : {finding.description}")
            if finding.affected_objects:
                lines.append(f"   Affected  : {', '.join(finding.affected_objects[:5])}")
            if finding.mos_references:
                lines.append(f"   MOS Refs  : {', '.join(finding.mos_references)}")
            if finding.recommended_action:
                lines.append(f"   Action    : {finding.recommended_action[:200]}")
            lines.append("")

        lines.append("=" * 60)
        counts = {}
        for f in findings:
            counts[f.severity] = counts.get(f.severity, 0) + 1
        summary = " | ".join(f"{k}: {v}" for k, v in sorted(counts.items(),
                                                               key=lambda x: severity_order.get(x[0], 5)))
        lines.append(f"Summary: {summary}")
        return "\n".join(lines)

    def _extract_affected_objects(self, detail: str, section: str) -> List[str]:
        """
        Attempt to extract specific affected object names/IDs from detail text.
        """
        objects = []
        # Match patterns like: Request ID 1234567, Order ID 10001, Batch ID 5001
        id_pattern = re.compile(
            r"(?:Request|Order|Invoice|Batch|Job|Session|Employee|Tablespace)\s+(?:ID[s]?|#)?\s*[\w,\-]+",
            re.IGNORECASE,
        )
        matches = id_pattern.findall(detail)
        objects.extend(matches[:10])

        # Match things in quotes
        quoted = re.findall(r"'([^']+)'", detail)
        objects.extend(quoted[:5])

        # Deduplicate and clean
        seen = set()
        result = []
        for obj in objects:
            cleaned = obj.strip()
            if cleaned and cleaned not in seen:
                seen.add(cleaned)
                result.append(cleaned)
        return result[:10]

    def _generate_generic_action(self, analyzer_id: str, section: str, severity: SeverityType) -> str:
        """Generate a generic recommended action when no specific action is mapped."""
        if severity == "CRITICAL":
            return (
                f"Investigate immediately. Run {analyzer_id.upper()} analyzer with verbose output. "
                f"Contact Oracle Support if issue persists. Check MOS for known issues."
            )
        if severity == "HIGH":
            return (
                f"Review {section.replace('_', ' ').title()} findings. "
                f"Run {analyzer_id.upper()} analyzer for detailed diagnostics. "
                f"Search MOS for '{analyzer_id} {section.lower()}' for patches."
            )
        if severity == "MEDIUM":
            return (
                f"Schedule review of {section.replace('_', ' ').title()}. "
                f"Monitor trend over next 2-3 days."
            )
        return f"Review {analyzer_id.upper()} output for informational findings. No immediate action required."
