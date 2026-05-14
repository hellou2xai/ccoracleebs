"""
SQL file executor for Oracle EBS analyzers.
Reads analyze SQL files, substitutes parameters, and executes against Oracle DB.
In demo mode, returns realistic mock data.
"""

import os
import re
import time
import logging
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


@dataclass
class AnalyzerResult:
    """Result from running an EBS analyzer."""
    analyzer_id: str
    success: bool
    rows: List[Dict[str, Any]] = field(default_factory=list)
    raw_output: str = ""
    metadata: Dict[str, Any] = field(default_factory=dict)
    execution_time_ms: int = 0
    error_message: str = ""
    demo_mode: bool = False


class SQLExecutor:
    """
    Executes EBS analyzer SQL files against Oracle DB.
    Handles parameter substitution for &&variable EBS-style parameters.
    """

    # EBS-style SQL parameter patterns
    _PARAM_PATTERN = re.compile(r"&&([A-Za-z0-9_]+)")
    _DEFINE_PATTERN = re.compile(r"^\s*DEFINE\s+([A-Za-z0-9_]+)\s*=\s*(.+)$", re.IGNORECASE | re.MULTILINE)

    # REM comment metadata patterns
    _MENU_TITLE_PATTERN = re.compile(r"REM\s+MENU_TITLE:\s*(.+)", re.IGNORECASE)
    _COMPAT_PATTERN = re.compile(r"REM\s+COMPAT:\s*(.+)", re.IGNORECASE)
    _HELP_START_PATTERN = re.compile(r"REM\s+HELP_START(.*?)REM\s+HELP_END", re.DOTALL | re.IGNORECASE)
    _DOC_ID_PATTERN = re.compile(r"Doc\s+ID[:\s]+(\d+\.\d+)", re.IGNORECASE)

    def __init__(self, oracle_db=None):
        self.oracle_db = oracle_db

    def read_sql_file(self, filepath: str) -> Optional[str]:
        """Read SQL file content, returning None if not found."""
        if not filepath or not os.path.exists(filepath):
            logger.warning("SQL file not found: %s", filepath)
            return None
        try:
            with open(filepath, "r", encoding="utf-8", errors="replace") as f:
                return f.read()
        except Exception as exc:
            logger.error("Error reading SQL file %s: %s", filepath, exc)
            return None

    def parse_sql_metadata(self, sql_content: str) -> Dict[str, Any]:
        """
        Extract metadata from SQL file REM comment header sections.
        Returns dict with menu_title, compat, help_text, doc_ids.
        """
        if not sql_content:
            return {}

        metadata: Dict[str, Any] = {}

        m = self._MENU_TITLE_PATTERN.search(sql_content)
        if m:
            metadata["menu_title"] = m.group(1).strip()

        m = self._COMPAT_PATTERN.search(sql_content)
        if m:
            metadata["compat"] = m.group(1).strip()

        m = self._HELP_START_PATTERN.search(sql_content)
        if m:
            help_text = m.group(1)
            # Clean up REM prefixes from help text
            help_lines = []
            for line in help_text.splitlines():
                line = re.sub(r"^\s*REM\s?", "", line)
                help_lines.append(line)
            metadata["help_text"] = "\n".join(help_lines).strip()

        doc_ids = self._DOC_ID_PATTERN.findall(sql_content)
        if doc_ids:
            metadata["doc_ids"] = list(set(doc_ids))

        return metadata

    def prepare_sql(self, content: str, params: Dict[str, Any]) -> str:
        """
        Substitute &&variable EBS-style parameters in SQL content.
        Also applies DEFINE statements found within the SQL.
        """
        if not content:
            return content

        # First, collect DEFINE statements from the SQL itself
        defines = {}
        for m in self._DEFINE_PATTERN.finditer(content):
            defines[m.group(1).upper()] = m.group(2).strip().strip("'\"")

        # Merge with caller-provided params (caller params take precedence)
        combined = {**defines}
        for k, v in params.items():
            combined[k.upper()] = str(v)

        # Set safe defaults for common EBS parameters
        defaults = {
            "APPS_USER": "APPS",
            "LEDGER_ID": "1",
            "ORG_ID": "204",
            "PERIOD_NAME": "MAR-2026",
            "CATEGORY_SET_ID": "1",
            "ITEM_ID": "NULL",
        }
        for k, v in defaults.items():
            if k not in combined:
                combined[k] = v

        def replace_param(match):
            var_name = match.group(1).upper()
            return combined.get(var_name, f"'{var_name}_VALUE'")

        return self._PARAM_PATTERN.sub(replace_param, content)

    def _extract_select_statements(self, sql_content: str) -> List[str]:
        """
        Extract SELECT statements from a SQL file, skipping DDL/package definitions.
        Returns list of SELECT statement strings.
        """
        # Remove single-line comments
        content = re.sub(r"--.*$", "", sql_content, flags=re.MULTILINE)
        # Remove REM comments
        content = re.sub(r"^\s*REM\b.*$", "", content, flags=re.MULTILINE | re.IGNORECASE)
        # Remove SET commands
        content = re.sub(r"^\s*SET\b.*$", "", content, flags=re.MULTILINE | re.IGNORECASE)
        # Remove WHENEVER commands
        content = re.sub(r"^\s*WHENEVER\b.*$", "", content, flags=re.MULTILINE | re.IGNORECASE)

        statements = []
        # Split on semicolons but not those inside quotes
        parts = re.split(r";\s*\n", content)
        for part in parts:
            stripped = part.strip()
            if re.match(r"^\s*SELECT\b", stripped, re.IGNORECASE):
                statements.append(stripped)

        return statements

    def execute_analyzer(
        self,
        analyzer_id: str,
        analyze_file: str,
        params: Optional[Dict[str, Any]] = None,
    ) -> AnalyzerResult:
        """
        Execute an analyzer SQL file and return structured results.
        In demo mode, returns realistic mock data from oracle_db.get_demo_data().
        """
        from tools.oracle_db import get_demo_data  # lazy import to avoid circular

        start_time = time.time()
        params = params or {}

        # Check demo mode
        demo_mode = False
        if self.oracle_db is None or self.oracle_db.demo_mode:
            demo_mode = True

        # Read SQL file metadata regardless of mode (for context)
        sql_content = self.read_sql_file(analyze_file) if analyze_file else None
        metadata = self.parse_sql_metadata(sql_content) if sql_content else {}
        metadata["analyzer_id"] = analyzer_id
        metadata["file_path"] = analyze_file or ""

        if demo_mode:
            rows = get_demo_data(analyzer_id)
            raw_output = self._format_demo_output(analyzer_id, rows)
            elapsed = int((time.time() - start_time) * 1000)
            return AnalyzerResult(
                analyzer_id=analyzer_id,
                success=True,
                rows=rows,
                raw_output=raw_output,
                metadata=metadata,
                execution_time_ms=elapsed,
                demo_mode=True,
            )

        # Live mode: read and execute SQL file
        if sql_content is None:
            return AnalyzerResult(
                analyzer_id=analyzer_id,
                success=False,
                error_message=f"SQL file not found: {analyze_file}",
                demo_mode=False,
            )

        try:
            prepared_sql = self.prepare_sql(sql_content, params)
            select_stmts = self._extract_select_statements(prepared_sql)

            all_rows = []
            for stmt in select_stmts[:5]:  # limit to first 5 SELECT statements
                rows = self.oracle_db.execute_query(stmt)
                all_rows.extend(rows)

            raw_output = self._format_rows_output(analyzer_id, all_rows)
            elapsed = int((time.time() - start_time) * 1000)

            return AnalyzerResult(
                analyzer_id=analyzer_id,
                success=True,
                rows=all_rows,
                raw_output=raw_output,
                metadata=metadata,
                execution_time_ms=elapsed,
                demo_mode=False,
            )

        except Exception as exc:
            logger.error("execute_analyzer error for %s: %s", analyzer_id, exc)
            elapsed = int((time.time() - start_time) * 1000)
            return AnalyzerResult(
                analyzer_id=analyzer_id,
                success=False,
                error_message=str(exc),
                execution_time_ms=elapsed,
                demo_mode=False,
            )

    def _format_demo_output(self, analyzer_id: str, rows: List[Dict]) -> str:
        """Format demo rows into readable text output."""
        lines = [f"=== {analyzer_id.upper()} ANALYZER OUTPUT (DEMO MODE) ===", ""]
        for row in rows:
            section = row.get("section", "FINDING")
            finding = row.get("finding", "")
            detail = row.get("detail", "")
            severity = row.get("severity", "INFO")
            count = row.get("count", 0)
            lines.append(f"[{severity}] {section}")
            lines.append(f"  Finding : {finding}")
            if detail:
                lines.append(f"  Detail  : {detail}")
            if count:
                lines.append(f"  Count   : {count}")
            lines.append("")
        return "\n".join(lines)

    def _format_rows_output(self, analyzer_id: str, rows: List[Dict]) -> str:
        """Format query result rows into readable text."""
        if not rows:
            return f"=== {analyzer_id.upper()} ANALYZER ===\nNo results returned.\n"

        lines = [f"=== {analyzer_id.upper()} ANALYZER OUTPUT ===", ""]
        if rows:
            headers = list(rows[0].keys())
            header_line = " | ".join(str(h).upper() for h in headers)
            lines.append(header_line)
            lines.append("-" * len(header_line))
            for row in rows[:200]:  # limit to 200 rows in display
                lines.append(" | ".join(str(row.get(h, "")) for h in headers))
        lines.append(f"\nTotal rows: {len(rows)}")
        return "\n".join(lines)
