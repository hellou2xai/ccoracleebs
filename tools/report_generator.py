"""
Incident report generator for Oracle EBS Support sessions.
Generates Markdown, HTML, and structured reports from session findings.
"""

import os
from datetime import datetime
from typing import Any, Dict, List, Optional

try:
    import pandas as pd
    PANDAS_AVAILABLE = True
except ImportError:
    PANDAS_AVAILABLE = False

from tools.result_parser import Finding


class ReportGenerator:
    """
    Generates comprehensive incident reports from EBS support session data.
    Supports Markdown, HTML, and DataFrame output formats.
    """

    SEVERITY_EMOJI = {
        "CRITICAL": "🔴",
        "HIGH": "🟠",
        "MEDIUM": "🟡",
        "LOW": "🟢",
        "INFO": "🔵",
    }

    SEVERITY_ORDER = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3, "INFO": 4}

    def severity_counts(self, findings: List[Finding]) -> Dict[str, int]:
        """Return dict of severity → count."""
        counts = {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0, "INFO": 0}
        for f in findings:
            counts[f.severity] = counts.get(f.severity, 0) + 1
        return counts

    def findings_to_dataframe(self, findings: List[Finding]):
        """Convert findings list to pandas DataFrame for display."""
        if not PANDAS_AVAILABLE:
            return None
        if not findings:
            return pd.DataFrame()

        rows = []
        for f in findings:
            rows.append({
                "Severity": f.severity,
                "Module": f.module,
                "Analyzer": f.analyzer_id,
                "Category": f.category,
                "Description": f.description[:120] + "..." if len(f.description) > 120 else f.description,
                "MOS References": "; ".join(f.mos_references) if f.mos_references else "",
                "Auto-Fixable": "Yes" if f.auto_fixable else "No",
            })

        df = pd.DataFrame(rows)
        # Sort by severity
        sev_map = {v: k for k, v in self.SEVERITY_ORDER.items()}
        df["_sev_order"] = df["Severity"].map(self.SEVERITY_ORDER).fillna(5)
        df = df.sort_values("_sev_order").drop(columns=["_sev_order"]).reset_index(drop=True)
        return df

    def generate_markdown_report(
        self,
        session: Dict[str, Any],
        findings: List[Finding],
        include_raw: bool = False,
    ) -> str:
        """
        Generate a full incident report in Markdown format.
        Suitable for display in Streamlit or export as .md file.
        """
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        session_id = session.get("session_id", "UNKNOWN")
        instance_info = session.get("instance_info", {})
        ebs_version = instance_info.get("release_name", "Unknown")
        host = instance_info.get("host_name", "Unknown")
        sid = instance_info.get("instance_name", "Unknown")

        counts = self.severity_counts(findings)
        total = sum(counts.values())

        sorted_findings = sorted(findings, key=lambda f: self.SEVERITY_ORDER.get(f.severity, 5))

        lines = [
            "# Oracle EBS Support Incident Report",
            "",
            f"**Generated:** {now}",
            f"**Session ID:** `{session_id}`",
            f"**EBS Instance:** {host} / {sid}",
            f"**EBS Version:** R{ebs_version}",
            "",
            "---",
            "",
            "## Executive Summary",
            "",
            self.generate_executive_summary(findings),
            "",
            "---",
            "",
            "## Findings Summary",
            "",
            f"| Severity | Count |",
            f"|----------|-------|",
        ]

        for sev in ("CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"):
            icon = self.SEVERITY_EMOJI.get(sev, "")
            lines.append(f"| {icon} {sev} | {counts.get(sev, 0)} |")

        lines.extend([
            f"| **TOTAL** | **{total}** |",
            "",
            "---",
            "",
            "## Detailed Findings",
            "",
        ])

        # Group findings by module
        modules_seen = {}
        for f in sorted_findings:
            modules_seen.setdefault(f.module, []).append(f)

        for module, module_findings in modules_seen.items():
            lines.append(f"### {module}")
            lines.append("")

            for i, finding in enumerate(module_findings, 1):
                icon = self.SEVERITY_EMOJI.get(finding.severity, "")
                lines.append(f"#### {icon} [{finding.severity}] {finding.category}")
                lines.append("")
                lines.append(f"- **Analyzer:** `{finding.analyzer_id}`")
                lines.append(f"- **Description:** {finding.description}")
                if finding.affected_objects:
                    lines.append(f"- **Affected Objects:** {', '.join(finding.affected_objects[:5])}")
                if finding.mos_references:
                    lines.append(f"- **MOS References:** {', '.join(finding.mos_references)}")
                lines.append(f"- **Auto-Fixable:** {'Yes' if finding.auto_fixable else 'No'}")
                lines.append("")
                if finding.recommended_action:
                    lines.append(f"**Recommended Action:**")
                    lines.append("")
                    lines.append(f"> {finding.recommended_action}")
                    lines.append("")
                if include_raw and finding.raw_output:
                    lines.append("<details>")
                    lines.append("<summary>Raw Output</summary>")
                    lines.append("")
                    lines.append("```")
                    lines.append(finding.raw_output[:1000])
                    lines.append("```")
                    lines.append("</details>")
                    lines.append("")
                lines.append("---")
                lines.append("")

        # Remediation plan section
        lines.extend([
            "## Remediation Plan",
            "",
            self.generate_remediation_plan(findings),
            "",
            "---",
            "",
            "## About This Report",
            "",
            "This report was generated by the Oracle EBS Support Agent. "
            "All findings are based on analyzer SQL output and are intended to guide "
            "system administrators in resolving EBS issues. Always test remediation "
            "steps in a non-production environment first.",
            "",
            "*Oracle EBS Support Agent v1.0.0 | Powered by Claude AI*",
        ])

        return "\n".join(lines)

    def generate_executive_summary(self, findings: List[Finding]) -> str:
        """Generate a brief executive summary of findings."""
        if not findings:
            return "No issues were detected during this analysis session. The EBS instance appears healthy."

        counts = self.severity_counts(findings)
        critical = counts.get("CRITICAL", 0)
        high = counts.get("HIGH", 0)
        medium = counts.get("MEDIUM", 0)
        total = sum(counts.values())

        # Identify most critical issues
        critical_findings = [f for f in findings if f.severity == "CRITICAL"]
        high_findings = [f for f in findings if f.severity == "HIGH"]

        paragraphs = []

        if critical > 0:
            categories = list({f.category for f in critical_findings})[:3]
            paragraphs.append(
                f"**CRITICAL:** {critical} critical issue(s) require immediate attention. "
                f"Key areas: {', '.join(categories)}. "
                "These findings may be causing active system failures or data integrity issues."
            )
        if high > 0:
            categories = list({f.category for f in high_findings})[:3]
            paragraphs.append(
                f"**HIGH:** {high} high-priority issue(s) should be addressed within 24 hours. "
                f"Key areas: {', '.join(categories)}."
            )
        if medium > 0:
            paragraphs.append(
                f"**MEDIUM:** {medium} medium-priority finding(s) warrant attention within 1 week."
            )

        # Modules affected
        modules = list({f.module for f in findings if f.severity in ("CRITICAL", "HIGH")})
        if modules:
            paragraphs.append(
                f"**Modules Impacted:** {', '.join(modules)}."
            )

        return "\n\n".join(paragraphs) if paragraphs else f"Analysis complete. {total} finding(s) identified."

    def generate_remediation_plan(self, findings: List[Finding]) -> str:
        """Generate a prioritized step-by-step remediation plan."""
        if not findings:
            return "No remediation required. System is healthy."

        sorted_findings = sorted(
            [f for f in findings if f.severity in ("CRITICAL", "HIGH", "MEDIUM")],
            key=lambda f: self.SEVERITY_ORDER.get(f.severity, 5),
        )

        if not sorted_findings:
            return "No high-priority remediation actions required."

        lines = []
        step = 1

        # Critical actions first
        critical = [f for f in sorted_findings if f.severity == "CRITICAL"]
        if critical:
            lines.append("### Immediate Actions (Complete within 2 hours)")
            lines.append("")
            for f in critical:
                lines.append(f"**Step {step}: {f.category}** ({f.analyzer_id})")
                lines.append("")
                if f.recommended_action:
                    for action_line in f.recommended_action.split(". "):
                        if action_line.strip():
                            lines.append(f"- {action_line.strip()}")
                lines.append("")
                step += 1

        # High priority
        high = [f for f in sorted_findings if f.severity == "HIGH"]
        if high:
            lines.append("### High Priority Actions (Complete within 24 hours)")
            lines.append("")
            for f in high:
                lines.append(f"**Step {step}: {f.category}** ({f.analyzer_id})")
                lines.append("")
                if f.recommended_action:
                    for action_line in f.recommended_action.split(". "):
                        if action_line.strip():
                            lines.append(f"- {action_line.strip()}")
                lines.append("")
                step += 1

        # Medium priority
        medium = [f for f in sorted_findings if f.severity == "MEDIUM"]
        if medium:
            lines.append("### Standard Priority Actions (Complete within 1 week)")
            lines.append("")
            for f in medium:
                lines.append(f"**Step {step}: {f.category}** ({f.analyzer_id})")
                if f.recommended_action:
                    lines.append(f"- {f.recommended_action[:200]}")
                lines.append("")
                step += 1

        return "\n".join(lines)

    def generate_html_report(
        self,
        session: Dict[str, Any],
        findings: List[Finding],
    ) -> str:
        """Generate an HTML version of the incident report."""
        md_report = self.generate_markdown_report(session, findings, include_raw=False)

        severity_colors = {
            "CRITICAL": "#dc3545",
            "HIGH": "#fd7e14",
            "MEDIUM": "#ffc107",
            "LOW": "#28a745",
            "INFO": "#17a2b8",
        }

        html_lines = [
            "<!DOCTYPE html>",
            "<html><head>",
            "<meta charset='UTF-8'>",
            "<title>Oracle EBS Incident Report</title>",
            "<style>",
            "body { font-family: 'Segoe UI', Arial, sans-serif; margin: 40px; color: #333; }",
            "h1 { color: #c0392b; border-bottom: 3px solid #c0392b; }",
            "h2 { color: #2c3e50; border-bottom: 1px solid #bdc3c7; }",
            "h3 { color: #2980b9; }",
            "table { border-collapse: collapse; width: 100%; margin: 10px 0; }",
            "th, td { padding: 8px 12px; text-align: left; border: 1px solid #ddd; }",
            "th { background-color: #2c3e50; color: white; }",
            "tr:nth-child(even) { background-color: #f2f2f2; }",
            "code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }",
            "blockquote { border-left: 4px solid #3498db; padding-left: 15px; color: #555; }",
            ".badge { padding: 3px 8px; border-radius: 12px; color: white; font-size: 0.85em; }",
        ]
        for sev, color in severity_colors.items():
            html_lines.append(f".badge-{sev.lower()} {{ background-color: {color}; }}")
        html_lines.extend(["</style>", "</head><body>"])

        # Simple MD to HTML conversion
        in_table = False
        for line in md_report.splitlines():
            if line.startswith("# "):
                html_lines.append(f"<h1>{line[2:]}</h1>")
            elif line.startswith("## "):
                html_lines.append(f"<h2>{line[3:]}</h2>")
            elif line.startswith("### "):
                html_lines.append(f"<h3>{line[4:]}</h3>")
            elif line.startswith("#### "):
                html_lines.append(f"<h4>{line[5:]}</h4>")
            elif line.startswith("---"):
                html_lines.append("<hr>")
            elif line.startswith("|"):
                if not in_table:
                    html_lines.append("<table>")
                    in_table = True
                if "---" in line:
                    continue
                cells = [c.strip() for c in line.strip("|").split("|")]
                is_header = any(c.startswith("**") for c in cells)
                tag = "th" if is_header else "td"
                html_lines.append("<tr>" + "".join(f"<{tag}>{c}</{tag}>" for c in cells) + "</tr>")
            else:
                if in_table:
                    html_lines.append("</table>")
                    in_table = False
                if line.startswith("> "):
                    html_lines.append(f"<blockquote>{line[2:]}</blockquote>")
                elif line.startswith("- ") or line.startswith("* "):
                    html_lines.append(f"<li>{line[2:]}</li>")
                elif line.startswith("**") and line.endswith("**"):
                    html_lines.append(f"<strong>{line[2:-2]}</strong>")
                elif line.strip():
                    # Replace inline **bold**
                    processed = line.replace("**", "<strong>", 1)
                    count = 0
                    while "**" in processed:
                        processed = processed.replace("**", "</strong>" if count % 2 == 0 else "<strong>", 1)
                        count += 1
                    html_lines.append(f"<p>{processed}</p>")

        if in_table:
            html_lines.append("</table>")

        html_lines.extend(["</body></html>"])
        return "\n".join(html_lines)
