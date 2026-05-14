"""
Oracle EBS Support Orchestrator Agent.
Uses Anthropic Claude API with tool_use to classify user intent,
route to module agents, execute analyzers, and generate incident reports.
"""

import os
import json
import logging
import time
from typing import Any, Dict, Generator, List, Optional

import anthropic

from config.analyzer_registry import (
    ANALYZER_REGISTRY,
    PROBLEM_TO_ANALYZERS,
    get_analyzer,
    search_analyzers,
)
from tools.oracle_db import OracleDB
from tools.pg_store import PostgreSQLStore
from tools.sql_executor import SQLExecutor
from tools.result_parser import ResultParser, Finding
from tools.report_generator import ReportGenerator

logger = logging.getLogger(__name__)

MODEL = "claude-sonnet-4-6"

SYSTEM_PROMPT = """You are an Oracle EBS (E-Business Suite) Support Orchestrator — a senior Oracle support specialist with 20+ years of experience across all EBS modules.

## Your Role
You analyze Oracle EBS issues, run diagnostic analyzers, interpret results, and provide actionable remediation steps. You work with a library of 100+ SQL-based analyzers covering:

**Modules:**
- **ATG/Core**: Concurrent Processing (CP), Workflow, BI Publisher, NLS, Monitoring, Profile Options
- **Financials**: GL, AP, AR, FA, CE, PO, OM, Projects (PA), SLA, IBY, Tax
- **Manufacturing**: INV, BOM, WIP, CST, MFG, Shipping (WSH), ASCP, EAM, WMS
- **HCM**: HR, Payroll, Benefits, OTL, AME, Appraisals
- **CRM**: Field Service, Service Contracts, Incentive Compensation, Install Base, iSupplier

## How You Work
1. Understand the user's problem — ask clarifying questions if needed
2. **Always call `get_ebs_system_info` first** to confirm EBS version and connection status
3. Identify which EBS module(s) are affected
4. For deep-dive requests or when users want actual data:
   - Use `get_ebs_table_data` with a pre-built query name for common lookups
   - Use `query_oracle_table` for custom SQL queries against specific EBS tables
   - ALWAYS include `FETCH FIRST N ROWS ONLY` in custom SQL for performance
5. Run diagnostic analyzers using `execute_analyzer` for structured findings
6. Present actual data rows in markdown tables (use | column | column | format)
7. Interpret results and classify findings by severity (CRITICAL/HIGH/MEDIUM/LOW/INFO)
8. Provide clear, actionable remediation steps with exact menu paths or SQL
9. Reference Oracle MOS (My Oracle Support) document IDs when relevant
10. Save significant findings to the session report

## Deep-Dive Data Analysis
When users ask for actual data, records, or "show me", always query the live Oracle tables:
- Stuck concurrent requests → `get_ebs_table_data("stuck_concurrent_requests")`
- AP unposted invoices → `get_ebs_table_data("unposted_ap_invoices")`
- GL open periods → `get_ebs_table_data("gl_open_periods")`
- Workflow errors → `get_ebs_table_data("workflow_stuck_activities")`
- Custom analysis → `query_oracle_table` with optimized SQL

Always format data results as markdown tables for readability.
Present counts, specific record IDs, amounts, and dates — not just summaries.

## Common Problem → Analyzer Mappings
- **AP invoices stuck in validation**: cp, ap_accounting, ap_inv_tax, ap_period_close, workflow
- **GL period close issues**: gl_hc, ap_period_close, ar_periodclose, cst_periodclose, fa
- **Concurrent manager down/slow**: cp, mon, workflow
- **Workflow notifications not sent**: workflow, bip, cp
- **Month-end/period close**: gl_hc, ap_period_close, ar_periodclose, fa, cst_periodclose, ce
- **Payroll problems**: pay, otl, ame, hr
- **Inventory negative balance**: inv_trans, cst_reconciliation, inv_counting
- **Sales orders stuck**: om, om_order, cp, workflow
- **Supplier payment issues**: ap_sup, iby_fd, ap_accounting
- **Tax calculation errors**: ap_inv_tax, o2c_ebtax, sla_setup
- **System performance issues**: mon, cp
- **WIP job problems**: wip, bom, cst_periodclose
- **Shipping/delivery issues**: wsh, wsh_stops, om_order

## Response Style
- Be direct and professional
- Lead with the most critical finding
- Provide specific SQL paths and menu navigation steps
- Reference Doc IDs from Oracle MOS
- Use severity levels consistently: 🔴 CRITICAL | 🟠 HIGH | 🟡 MEDIUM | 🟢 LOW | 🔵 INFO
- When uncertain, run diagnostics first rather than guessing

## Oracle EBS Architecture Context
- EBS runs on Oracle DB (typically 12c/19c) and Oracle Application Server/WebLogic
- All apps run as APPS user in the database
- Concurrent processing (FND_CONCURRENT_*) handles all batch jobs
- Workflow (WF_*) handles approvals and notifications
- SLA/XLA handles subledger-to-GL accounting transfers
- TCA (HZ_*) is the customer master for all AR/CRM data
- IBY handles all payment processing

Always provide context about WHY an issue occurs, not just what to do. Your goal is to help administrators understand and permanently resolve issues, not just apply temporary fixes."""


# ─── Tool Definitions for Claude API ─────────────────────────────────────────

TOOLS = [
    {
        "name": "classify_intent",
        "description": (
            "Analyze a user message to identify the EBS module(s) affected, "
            "the type of problem, urgency level, and which analyzers to run. "
            "Call this first when a new user question arrives."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "user_message": {
                    "type": "string",
                    "description": "The user's support request message",
                },
                "context": {
                    "type": "string",
                    "description": "Additional context about the EBS instance or prior findings",
                },
            },
            "required": ["user_message"],
        },
    },
    {
        "name": "invoke_module_agent",
        "description": (
            "Invoke a module-specific sub-agent (ATG, FINANCIALS, MANUFACTURING, HCM, CRM) "
            "to perform deep analysis on a specific task. Returns module-specific findings."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "agent_name": {
                    "type": "string",
                    "enum": ["ATG", "FINANCIALS", "MANUFACTURING", "HCM", "CRM"],
                    "description": "Which module agent to invoke",
                },
                "task_description": {
                    "type": "string",
                    "description": "Specific task for the module agent",
                },
                "analyzer_ids": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of analyzer IDs to run",
                },
            },
            "required": ["agent_name", "task_description", "analyzer_ids"],
        },
    },
    {
        "name": "execute_analyzer",
        "description": (
            "Execute a specific EBS diagnostic analyzer by ID and return structured findings. "
            "Use this to run individual analyzers like 'cp', 'ap_period_close', 'gl_hc', etc."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "analyzer_id": {
                    "type": "string",
                    "description": "Analyzer ID from the registry (e.g., 'cp', 'gl_hc', 'ap_period_close')",
                },
                "params": {
                    "type": "object",
                    "description": "Optional parameters like period_name, org_id, ledger_id",
                },
            },
            "required": ["analyzer_id"],
        },
    },
    {
        "name": "get_ebs_system_info",
        "description": (
            "Retrieve EBS instance information including version, installed products, "
            "and concurrent manager status. Run at the start of a session."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "include_products": {
                    "type": "boolean",
                    "description": "Whether to include installed products list",
                },
            },
            "required": [],
        },
    },
    {
        "name": "search_knowledge_base",
        "description": (
            "Search the EBS knowledge base for known issues, patches, and MOS notes "
            "related to keywords or error codes."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "keywords": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Keywords to search for (e.g., ['period close', 'AP', 'unposted'])",
                },
                "error_codes": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Specific error codes like ORA-04031, APP-FND-01234",
                },
            },
            "required": ["keywords"],
        },
    },
    {
        "name": "generate_incident_report",
        "description": "Generate a formatted incident report for the current session with all findings.",
        "input_schema": {
            "type": "object",
            "properties": {
                "session_id": {
                    "type": "string",
                    "description": "Session ID to generate report for",
                },
                "format": {
                    "type": "string",
                    "enum": ["markdown", "summary"],
                    "description": "Output format",
                },
            },
            "required": ["session_id"],
        },
    },
    {
        "name": "get_session_findings",
        "description": "Retrieve all findings accumulated in the current session.",
        "input_schema": {
            "type": "object",
            "properties": {
                "session_id": {"type": "string"},
                "severity_filter": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Optional filter: ['CRITICAL', 'HIGH']",
                },
            },
            "required": ["session_id"],
        },
    },
    {
        "name": "save_finding",
        "description": "Save a discovered finding to the session store for reporting.",
        "input_schema": {
            "type": "object",
            "properties": {
                "session_id": {"type": "string"},
                "analyzer_id": {"type": "string"},
                "module": {"type": "string"},
                "severity": {
                    "type": "string",
                    "enum": ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"],
                },
                "category": {"type": "string"},
                "description": {"type": "string"},
                "recommended_action": {"type": "string"},
                "mos_references": {
                    "type": "array",
                    "items": {"type": "string"},
                },
                "affected_objects": {
                    "type": "array",
                    "items": {"type": "string"},
                },
            },
            "required": ["session_id", "analyzer_id", "module", "severity", "description"],
        },
    },
    {
        "name": "query_oracle_table",
        "description": (
            "Execute a direct optimized SQL query against the live Oracle EBS database. "
            "Use this for deep-dive analysis when you need actual data rows from EBS tables. "
            "Always add FETCH FIRST N ROWS ONLY for performance. "
            "Useful tables: FND_CONCURRENT_REQUESTS, AP_INVOICES_ALL, AP_INVOICE_LINES_ALL, "
            "GL_JE_HEADERS, GL_JE_LINES, GL_BALANCES, AR_PAYMENT_SCHEDULES_ALL, "
            "MTL_SYSTEM_ITEMS_B, WIP_DISCRETE_JOBS, HR_ALL_ORGANIZATION_UNITS, "
            "FND_USER, FND_PROFILE_OPTION_VALUES, WF_ITEM_ACTIVITY_STATUSES. "
            "In demo mode this returns realistic sample data."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "sql": {
                    "type": "string",
                    "description": "The SELECT SQL to execute. Must include FETCH FIRST N ROWS ONLY or ROWNUM <= N for safety.",
                },
                "description": {
                    "type": "string",
                    "description": "Human-readable description of what this query is checking",
                },
                "max_rows": {
                    "type": "integer",
                    "description": "Max rows to return (default 50, max 500)",
                },
            },
            "required": ["sql", "description"],
        },
    },
    {
        "name": "get_ebs_table_data",
        "description": (
            "Fetch live data from a specific Oracle EBS table with pre-built optimized queries. "
            "Covers all EBS Agentic Apps: Payables, Collections, Payments, Ledger, GL, AR, "
            "SCM Execution (Fulfillment, Sales Orders, Cycle Count, Resilience, Design-to-Source), "
            "and Planning (Demand, Supply, S&OP, Order Promising). "
            "Use this for deep-dive lookups without writing custom SQL."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "table_name": {
                    "type": "string",
                    "enum": [
                        "stuck_concurrent_requests",
                        "pending_concurrent_requests",
                        "unposted_ap_invoices",
                        "ap_invoices_on_hold",
                        "ap_po_match_exceptions",
                        "ap_payment_batches",
                        "ap_discount_opportunities",
                        "gl_unposted_journals",
                        "gl_open_periods",
                        "gl_current_period_balances",
                        "ar_unapplied_receipts",
                        "ar_aging_buckets",
                        "sla_transfer_errors",
                        "workflow_stuck_activities",
                        "wf_open_notifications",
                        "tablespace_usage",
                        "invalid_db_objects",
                        "long_running_sessions",
                        "concurrent_manager_status",
                        "ebs_operational_health",
                        "wip_jobs_no_activity",
                        "om_stuck_orders",
                        "orders_on_hold",
                        "shipping_exceptions",
                        "pending_ecos",
                        "open_requisitions",
                        "cycle_count_discrepancies",
                        "overdue_po_receipts",
                        "open_order_backlog",
                        "items_below_min_stock",
                    ],
                    "description": "Pre-built query to execute",
                },
                "filters": {
                    "type": "object",
                    "description": "Optional filters: org_id, period_name, ledger_id, days_back",
                },
            },
            "required": ["table_name"],
        },
    },
]


# ─── Knowledge Base ───────────────────────────────────────────────────────────

KNOWLEDGE_BASE = {
    "period close": [
        {
            "title": "EBS Period Close Best Practices",
            "doc_id": "1581211.1",
            "description": "Comprehensive guide to EBS period close across all modules",
            "modules": ["GL", "AP", "AR", "FA", "CST"],
        },
        {
            "title": "GL Period Close Troubleshooting",
            "doc_id": "1483679.1",
            "description": "Diagnose and resolve GL period close issues",
            "modules": ["GL"],
        },
    ],
    "concurrent manager": [
        {
            "title": "Concurrent Processing Analyzer Guide",
            "doc_id": "1411723.1",
            "description": "Diagnose concurrent processing issues with the CP Analyzer",
            "modules": ["ATG", "CP"],
        },
        {
            "title": "How to Troubleshoot Stuck Concurrent Requests",
            "doc_id": "465554.1",
            "description": "Steps to identify and resolve stuck concurrent requests",
            "modules": ["ATG", "CP"],
        },
    ],
    "workflow": [
        {
            "title": "Workflow Analyzer Guide",
            "doc_id": "1378745.1",
            "description": "Diagnose Oracle Workflow issues",
            "modules": ["WF"],
        },
        {
            "title": "Workflow Mailer Troubleshooting",
            "doc_id": "1591551.1",
            "description": "Resolve notification mailer issues",
            "modules": ["WF"],
        },
    ],
    "ap invoice": [
        {
            "title": "AP Invoice Validation Errors",
            "doc_id": "1483658.1",
            "description": "Common AP invoice validation errors and resolutions",
            "modules": ["AP"],
        },
    ],
    "ora-04031": [
        {
            "title": "ORA-04031 Troubleshooting for EBS",
            "doc_id": "396940.1",
            "description": "Resolving ORA-04031 (unable to allocate shared memory) in EBS",
            "modules": ["ATG", "DB"],
        },
    ],
    "payroll": [
        {
            "title": "Payroll Analyzer Guide",
            "doc_id": "1483747.1",
            "description": "Diagnose payroll processing issues",
            "modules": ["PAY"],
        },
    ],
    "sla accounting": [
        {
            "title": "Subledger Accounting (SLA) Troubleshooting",
            "doc_id": "1483700.1",
            "description": "Diagnose SLA journal entry and accounting rules issues",
            "modules": ["SLA", "XLA"],
        },
    ],
    "tablespace": [
        {
            "title": "Managing EBS Tablespace Growth",
            "doc_id": "1501750.1",
            "description": "Best practices for EBS tablespace management",
            "modules": ["DB"],
        },
    ],
}


# ─── OrchestratorAgent ────────────────────────────────────────────────────────

class OrchestratorAgent:
    """
    Main orchestrator that uses Claude API tool_use to analyze EBS issues.
    Implements an agentic loop: receives user message → calls tools → returns response.
    """

    def __init__(
        self,
        oracle_db: Optional[OracleDB] = None,
        pg_store: Optional[PostgreSQLStore] = None,
    ):
        self.client = anthropic.Anthropic(
            api_key=os.environ.get("ANTHROPIC_API_KEY", "")
        )
        self.oracle_db = oracle_db or OracleDB()
        self.pg_store = pg_store or PostgreSQLStore()
        self.sql_executor = SQLExecutor(oracle_db=self.oracle_db)
        self.result_parser = ResultParser()
        self.report_generator = ReportGenerator()

        # Cached session findings (for current session)
        self._session_findings: Dict[str, List[Finding]] = {}

    # ─── Public Interface ─────────────────────────────────────────────────────

    def process_message(
        self,
        user_message: str,
        session_id: str,
        conversation_history: List[Dict[str, Any]],
    ) -> Dict[str, Any]:
        """
        Process a user message through the agentic loop.

        Returns dict with:
          - response_text: str (final text response)
          - findings: list of Finding dicts
          - tools_called: list of tool call names
          - raw_results: dict of analyzer_id → result
        """
        messages = list(conversation_history)
        messages.append({"role": "user", "content": user_message})

        accumulated_findings: List[Finding] = []
        tools_called: List[str] = []
        raw_results: Dict[str, Any] = {}
        response_text = ""

        # Agentic loop: keep calling Claude until no more tool_use blocks
        max_iterations = 10
        iteration = 0

        while iteration < max_iterations:
            iteration += 1

            response = self.client.messages.create(
                model=MODEL,
                max_tokens=4096,
                system=SYSTEM_PROMPT,
                tools=TOOLS,
                messages=messages,
            )

            # Collect text content
            for block in response.content:
                if hasattr(block, "text"):
                    response_text = block.text

            # Check if we need to handle tool calls
            if response.stop_reason != "tool_use":
                # No more tool calls — we're done
                break

            # Process tool calls
            tool_results = []
            for block in response.content:
                if block.type != "tool_use":
                    continue

                tool_name = block.name
                tool_input = block.input
                tools_called.append(tool_name)

                logger.info("Tool call: %s(%s)", tool_name, json.dumps(tool_input, default=str)[:200])

                try:
                    result = self._dispatch_tool(
                        tool_name=tool_name,
                        tool_input=tool_input,
                        session_id=session_id,
                        accumulated_findings=accumulated_findings,
                        raw_results=raw_results,
                    )
                except Exception as exc:
                    logger.error("Tool %s error: %s", tool_name, exc)
                    result = {"error": str(exc), "status": "error"}

                tool_results.append({
                    "type": "tool_result",
                    "tool_use_id": block.id,
                    "content": json.dumps(result, default=str),
                })

            # Add assistant response and tool results to conversation
            messages.append({"role": "assistant", "content": response.content})
            messages.append({"role": "user", "content": tool_results})

        # Save all accumulated findings to pg_store
        for finding in accumulated_findings:
            self.pg_store.save_finding(session_id, finding.to_dict())

        # Cache findings for this session
        if session_id not in self._session_findings:
            self._session_findings[session_id] = []
        self._session_findings[session_id].extend(accumulated_findings)

        # Log audit
        self.pg_store.log_audit(
            session_id=session_id,
            action="process_message",
            analyzer_id=",".join(set(f.analyzer_id for f in accumulated_findings)),
            result_summary=f"{len(accumulated_findings)} findings, tools: {','.join(tools_called)}",
            row_count=len(accumulated_findings),
        )

        return {
            "response_text": response_text,
            "findings": [f.to_dict() for f in accumulated_findings],
            "tools_called": tools_called,
            "raw_results": raw_results,
        }

    # ─── Tool Dispatcher ──────────────────────────────────────────────────────

    def _dispatch_tool(
        self,
        tool_name: str,
        tool_input: Dict[str, Any],
        session_id: str,
        accumulated_findings: List[Finding],
        raw_results: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Route tool calls to appropriate handler methods."""

        if tool_name == "classify_intent":
            return self._tool_classify_intent(**tool_input)

        elif tool_name == "invoke_module_agent":
            return self._tool_invoke_module_agent(
                session_id=session_id,
                accumulated_findings=accumulated_findings,
                raw_results=raw_results,
                **tool_input,
            )

        elif tool_name == "execute_analyzer":
            return self._tool_execute_analyzer(
                session_id=session_id,
                accumulated_findings=accumulated_findings,
                raw_results=raw_results,
                **tool_input,
            )

        elif tool_name == "get_ebs_system_info":
            return self._tool_get_ebs_system_info(**tool_input)

        elif tool_name == "search_knowledge_base":
            return self._tool_search_knowledge_base(**tool_input)

        elif tool_name == "generate_incident_report":
            return self._tool_generate_incident_report(**tool_input)

        elif tool_name == "get_session_findings":
            return self._tool_get_session_findings(**tool_input)

        elif tool_name == "save_finding":
            return self._tool_save_finding(session_id=session_id, **tool_input)

        elif tool_name == "query_oracle_table":
            return self._tool_query_oracle_table(**tool_input)

        elif tool_name == "get_ebs_table_data":
            return self._tool_get_ebs_table_data(**tool_input)

        else:
            return {"error": f"Unknown tool: {tool_name}"}

    # ─── Tool Implementations ─────────────────────────────────────────────────

    def _tool_classify_intent(
        self,
        user_message: str,
        context: str = "",
    ) -> Dict[str, Any]:
        """Classify user message and return recommended analyzers."""
        msg_lower = user_message.lower()

        # Determine urgency
        urgency = "NORMAL"
        if any(w in msg_lower for w in ["urgent", "critical", "down", "failing", "stuck", "not working", "can't close", "cannot close", "emergency"]):
            urgency = "HIGH"
        if any(w in msg_lower for w in ["production down", "all users affected", "payroll failure", "immediate"]):
            urgency = "CRITICAL"

        # Identify modules
        module_keywords = {
            "ATG": ["concurrent", "manager", "workflow", "bip", "bi publisher", "nls", "profile", "monitoring"],
            "FINANCIALS": ["ap", "ar", "gl", "fa", "fixed assets", "payables", "receivables", "ledger", "period close", "invoice", "payment", "receipt", "journal", "sla", "subledger", "po accrual", "encumbrance"],
            "MANUFACTURING": ["wip", "bom", "inventory", "order management", "shipping", "ascp", "mrp", "cost", "costing", "wms", "warehouse", "om", "sales order", "purchasing"],
            "HCM": ["payroll", "hr", "human resources", "benefits", "otl", "time labor", "ame", "appraisal", "employee"],
            "CRM": ["service", "field service", "contracts", "incentive", "compensation", "install base", "isupplier", "quoting"],
        }

        modules = []
        for module, keywords in module_keywords.items():
            if any(kw in msg_lower for kw in keywords):
                modules.append(module)
        if not modules:
            modules = ["ATG"]  # Default to ATG for unknown

        # Find matching analyzers
        keywords_list = [w for w in msg_lower.split() if len(w) > 3]
        matched_analyzers = search_analyzers(keywords_list[:10])
        analyzer_ids = [a["id"] for a in matched_analyzers[:5]]

        # Also check problem-to-analyzer mappings
        for problem_key, analyzer_list in PROBLEM_TO_ANALYZERS.items():
            if any(kw in msg_lower for kw in problem_key.split("_")):
                for aid in analyzer_list:
                    if aid not in analyzer_ids:
                        analyzer_ids.append(aid)
                if len(analyzer_ids) >= 7:
                    break

        # Determine problem type
        problem_type = "GENERAL"
        if "period close" in msg_lower or "month end" in msg_lower:
            problem_type = "PERIOD_CLOSE"
        elif "concurrent" in msg_lower or "manager" in msg_lower:
            problem_type = "CONCURRENT_PROCESSING"
        elif "workflow" in msg_lower or "notification" in msg_lower:
            problem_type = "WORKFLOW"
        elif "invoice" in msg_lower:
            problem_type = "AP_INVOICING"
        elif "payment" in msg_lower:
            problem_type = "PAYMENTS"
        elif "payroll" in msg_lower:
            problem_type = "PAYROLL"
        elif "inventory" in msg_lower or "wip" in msg_lower:
            problem_type = "MANUFACTURING"

        return {
            "modules": modules,
            "problem_type": problem_type,
            "urgency": urgency,
            "recommended_analyzers": analyzer_ids[:6],
            "message": f"Classified as {problem_type} in modules: {', '.join(modules)}. Urgency: {urgency}.",
        }

    def _tool_invoke_module_agent(
        self,
        agent_name: str,
        task_description: str,
        analyzer_ids: List[str],
        session_id: str,
        accumulated_findings: List[Finding],
        raw_results: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Invoke a module-specific agent (ATG, FINANCIALS, etc.)."""
        from agents.atg_agent import ATGAgent
        from agents.financials_agent import FinancialsAgent
        from agents.manufacturing_agent import ManufacturingAgent
        from agents.hcm_agent import HCMAgent
        from agents.crm_agent import CRMAgent

        agent_map = {
            "ATG": ATGAgent,
            "FINANCIALS": FinancialsAgent,
            "MANUFACTURING": ManufacturingAgent,
            "HCM": HCMAgent,
            "CRM": CRMAgent,
        }

        agent_class = agent_map.get(agent_name)
        if not agent_class:
            return {"error": f"Unknown agent: {agent_name}"}

        agent = agent_class(
            oracle_db=self.oracle_db,
            sql_executor=self.sql_executor,
            result_parser=self.result_parser,
        )

        all_findings = []
        all_raw = {}

        for analyzer_id in analyzer_ids[:5]:
            result = agent.run_analyzer(analyzer_id)
            if result.get("success"):
                findings = result.get("findings", [])
                all_findings.extend(findings)
                all_raw[analyzer_id] = result
                for f in findings:
                    if isinstance(f, Finding):
                        accumulated_findings.append(f)
                    elif isinstance(f, dict):
                        try:
                            accumulated_findings.append(Finding(**f))
                        except Exception:
                            pass
                raw_results.update(all_raw)

        # Audit log
        self.pg_store.log_audit(
            session_id=session_id,
            action=f"invoke_{agent_name}_agent",
            analyzer_id=",".join(analyzer_ids),
            result_summary=f"{len(all_findings)} findings from {len(analyzer_ids)} analyzers",
            row_count=len(all_findings),
        )

        return {
            "agent": agent_name,
            "task": task_description,
            "analyzers_run": analyzer_ids,
            "findings_count": len(all_findings),
            "findings": [f.to_dict() if isinstance(f, Finding) else f for f in all_findings[:20]],
            "status": "success",
        }

    def _tool_execute_analyzer(
        self,
        analyzer_id: str,
        params: Optional[Dict[str, Any]] = None,
        session_id: str = "",
        accumulated_findings: List[Finding] = None,
        raw_results: Dict[str, Any] = None,
    ) -> Dict[str, Any]:
        """Execute a single analyzer and return structured findings."""
        if accumulated_findings is None:
            accumulated_findings = []
        if raw_results is None:
            raw_results = {}

        analyzer = get_analyzer(analyzer_id)
        if not analyzer:
            # Try fuzzy match
            candidates = search_analyzers([analyzer_id])
            if candidates:
                analyzer = candidates[0]
            else:
                return {"error": f"Analyzer '{analyzer_id}' not found in registry."}

        start = time.time()
        result = self.sql_executor.execute_analyzer(
            analyzer_id=analyzer["id"],
            analyze_file=analyzer["analyze_file"],
            params=params or {},
        )

        findings = self.result_parser.parse_analyzer_output(
            analyzer_id=analyzer["id"],
            module=analyzer["module"],
            raw_rows=result.rows,
            metadata=result.metadata,
        )

        accumulated_findings.extend(findings)
        raw_results[analyzer_id] = {
            "rows": result.rows,
            "raw_output": result.raw_output,
            "metadata": result.metadata,
            "execution_time_ms": result.execution_time_ms,
        }

        # Audit
        if session_id:
            self.pg_store.log_audit(
                session_id=session_id,
                action="execute_analyzer",
                analyzer_id=analyzer_id,
                result_summary=f"{len(findings)} findings",
                duration_ms=result.execution_time_ms,
                row_count=len(result.rows),
            )

        severity_counts = {}
        for f in findings:
            severity_counts[f.severity] = severity_counts.get(f.severity, 0) + 1

        return {
            "analyzer_id": analyzer["id"],
            "analyzer_name": analyzer["name"],
            "module": analyzer["module"],
            "success": result.success,
            "execution_time_ms": result.execution_time_ms,
            "demo_mode": result.demo_mode,
            "findings_count": len(findings),
            "severity_counts": severity_counts,
            "findings": [f.to_dict() for f in findings],
            "raw_output_preview": result.raw_output[:500] if result.raw_output else "",
        }

    def _tool_get_ebs_system_info(self, include_products: bool = True) -> Dict[str, Any]:
        """Get EBS system information."""
        version_info = self.oracle_db.get_ebs_version()
        managers = self.oracle_db.get_concurrent_managers()

        result = {
            "ebs_version": version_info,
            "concurrent_managers": managers,
            "connection_status": "demo" if self.oracle_db.demo_mode else "live",
        }

        if include_products:
            result["installed_products"] = self.oracle_db.get_installed_products()

        return result

    # ─── Deep-Dive Query Tools ────────────────────────────────────────────────

    # Pre-built deep-dive queries for common EBS tables
    _PREBUILT_QUERIES: Dict[str, str] = {
        "stuck_concurrent_requests": """
            SELECT r.request_id, r.phase_code, r.status_code,
                   p.user_concurrent_program_name program_name,
                   u.user_name requested_by,
                   r.requested_start_date,
                   r.actual_start_date,
                   ROUND((SYSDATE - r.actual_start_date) * 24, 2) hours_running,
                   r.argument_text
            FROM fnd_concurrent_requests r
            JOIN fnd_concurrent_programs_vl p ON r.concurrent_program_id = p.concurrent_program_id
            LEFT JOIN fnd_user u ON r.requested_by = u.user_id
            WHERE r.phase_code = 'R' AND r.status_code = 'R'
              AND r.actual_start_date < SYSDATE - 2/24
            ORDER BY r.actual_start_date
            FETCH FIRST 50 ROWS ONLY""",

        "pending_concurrent_requests": """
            SELECT r.request_id, r.phase_code, r.status_code,
                   p.user_concurrent_program_name program_name,
                   u.user_name requested_by,
                   r.requested_start_date,
                   r.argument_text
            FROM fnd_concurrent_requests r
            JOIN fnd_concurrent_programs_vl p ON r.concurrent_program_id = p.concurrent_program_id
            LEFT JOIN fnd_user u ON r.requested_by = u.user_id
            WHERE r.phase_code = 'P' AND r.status_code = 'I'
            ORDER BY r.requested_start_date
            FETCH FIRST 50 ROWS ONLY""",

        "unposted_ap_invoices": """
            SELECT i.invoice_id, i.invoice_num, i.invoice_date,
                   i.vendor_id, v.vendor_name,
                   i.invoice_amount, i.currency_code,
                   i.wfapproval_status, i.approval_status,
                   i.posting_status, i.validation_request_id
            FROM ap_invoices_all i
            LEFT JOIN ap_suppliers v ON i.vendor_id = v.vendor_id
            WHERE i.posting_status = 'N'
              AND i.cancelled_date IS NULL
              AND i.creation_date > SYSDATE - 90
            ORDER BY i.invoice_date DESC
            FETCH FIRST 100 ROWS ONLY""",

        "ap_invoices_on_hold": """
            SELECT h.invoice_id, i.invoice_num, i.vendor_id,
                   v.vendor_name, h.hold_lookup_code,
                   h.hold_reason, h.creation_date,
                   i.invoice_amount, i.currency_code
            FROM ap_holds_all h
            JOIN ap_invoices_all i ON h.invoice_id = i.invoice_id
            LEFT JOIN ap_suppliers v ON i.vendor_id = v.vendor_id
            WHERE h.release_lookup_code IS NULL
            ORDER BY h.creation_date DESC
            FETCH FIRST 100 ROWS ONLY""",

        "gl_unposted_journals": """
            SELECT h.je_header_id, h.name, h.je_source,
                   h.je_category, h.period_name,
                   h.ledger_id, l.name ledger_name,
                   h.status, h.running_total_dr,
                   h.running_total_cr, h.creation_date,
                   h.created_by
            FROM gl_je_headers h
            JOIN gl_ledgers l ON h.ledger_id = l.ledger_id
            WHERE h.status != 'P'
              AND h.actual_flag = 'A'
            ORDER BY h.creation_date DESC
            FETCH FIRST 50 ROWS ONLY""",

        "gl_open_periods": """
            SELECT p.period_name, p.period_year, p.period_num,
                   p.period_type, p.start_date, p.end_date,
                   ps.closing_status,
                   ps.ledger_id, l.name ledger_name
            FROM gl_periods p
            JOIN gl_period_statuses ps ON p.period_name = ps.period_name
              AND p.period_type = ps.period_type
            JOIN gl_ledgers l ON ps.ledger_id = l.ledger_id
            WHERE ps.closing_status IN ('O', 'F')
            ORDER BY p.period_year DESC, p.period_num DESC
            FETCH FIRST 30 ROWS ONLY""",

        "workflow_stuck_activities": """
            SELECT ia.item_type, ia.item_key,
                   ia.activity_status, ia.activity_result_code,
                   ia.error_name, ia.error_message,
                   ia.begin_date,
                   ROUND((SYSDATE - ia.begin_date) * 24, 2) hours_stuck,
                   a.display_name activity_name
            FROM wf_item_activity_statuses ia
            JOIN wf_process_activities pa ON ia.process_activity = pa.instance_id
            JOIN wf_activities_vl a ON pa.activity_item_type = a.item_type
              AND pa.activity_name = a.name
              AND a.version = (SELECT MAX(a2.version) FROM wf_activities a2
                               WHERE a2.item_type = a.item_type AND a2.name = a.name)
            WHERE ia.activity_status IN ('ERROR', 'DEFERRED')
              AND ia.begin_date < SYSDATE - 1
            ORDER BY ia.begin_date
            FETCH FIRST 50 ROWS ONLY""",

        "tablespace_usage": """
            SELECT df.tablespace_name,
                   ROUND(df.total_mb, 2) total_mb,
                   ROUND(df.total_mb - NVL(fs.free_mb, 0), 2) used_mb,
                   ROUND(NVL(fs.free_mb, 0), 2) free_mb,
                   ROUND((df.total_mb - NVL(fs.free_mb, 0)) / df.total_mb * 100, 1) pct_used
            FROM (SELECT tablespace_name, SUM(bytes)/1048576 total_mb
                  FROM dba_data_files GROUP BY tablespace_name) df
            LEFT JOIN (SELECT tablespace_name, SUM(bytes)/1048576 free_mb
                       FROM dba_free_space GROUP BY tablespace_name) fs
              ON df.tablespace_name = fs.tablespace_name
            ORDER BY pct_used DESC NULLS LAST
            FETCH FIRST 30 ROWS ONLY""",

        "invalid_db_objects": """
            SELECT owner, object_name, object_type,
                   status, last_ddl_time
            FROM dba_objects
            WHERE status = 'INVALID'
              AND owner IN ('APPS', 'SYS', 'SYSTEM')
            ORDER BY owner, object_type, object_name
            FETCH FIRST 100 ROWS ONLY""",

        "long_running_sessions": """
            SELECT s.sid, s.serial#, s.username,
                   s.status, s.machine, s.program,
                   s.sql_id,
                   ROUND((SYSDATE - s.logon_time) * 24, 2) hours_connected,
                   q.sql_text
            FROM v$session s
            LEFT JOIN v$sql q ON s.sql_id = q.sql_id AND ROWNUM <= 1
            WHERE s.status = 'ACTIVE'
              AND s.username IS NOT NULL
              AND s.logon_time < SYSDATE - 2/24
            ORDER BY s.logon_time
            FETCH FIRST 30 ROWS ONLY""",

        "ap_payment_batches": """
            SELECT b.checkrun_id, b.checkrun_name,
                   b.status, b.vendor_pay_group,
                   b.bank_account_id,
                   b.check_date, b.creation_date,
                   COUNT(c.check_id) check_count,
                   SUM(c.amount) total_amount,
                   b.currency_code
            FROM ap_inv_selection_criteria_all b
            LEFT JOIN ap_checks_all c ON b.checkrun_id = c.checkrun_id
            WHERE b.status NOT IN ('CONFIRMED', 'CANCELLED')
            GROUP BY b.checkrun_id, b.checkrun_name, b.status,
                     b.vendor_pay_group, b.bank_account_id,
                     b.check_date, b.creation_date, b.currency_code
            ORDER BY b.creation_date DESC
            FETCH FIRST 30 ROWS ONLY""",

        "ar_unapplied_receipts": """
            SELECT r.cash_receipt_id, r.receipt_number,
                   r.receipt_date, r.amount,
                   r.currency_code, r.status,
                   c.customer_name,
                   ps.amount_due_remaining
            FROM ar_cash_receipts_all r
            JOIN hz_cust_accounts ca ON r.pay_from_customer = ca.cust_account_id
            JOIN hz_parties c ON ca.party_id = c.party_id
            LEFT JOIN ar_payment_schedules_all ps ON r.cash_receipt_id = ps.cash_receipt_id
            WHERE r.status NOT IN ('APP', 'UNID', 'REV')
            ORDER BY r.receipt_date DESC
            FETCH FIRST 50 ROWS ONLY""",

        "wip_jobs_no_activity": """
            SELECT w.wip_entity_id, w.wip_entity_name job_name,
                   w.organization_id, w.status_type,
                   w.scheduled_start_date, w.scheduled_completion_date,
                   w.date_released,
                   ROUND(SYSDATE - NVL(w.date_completed, w.date_released), 0) days_inactive,
                   w.primary_item_id, w.quantity_remaining
            FROM wip_discrete_jobs w
            WHERE w.status_type IN (3, 4)  -- Released or Complete
              AND NOT EXISTS (
                  SELECT 1 FROM wip_transactions t
                  WHERE t.wip_entity_id = w.wip_entity_id
                    AND t.transaction_date > SYSDATE - 30
              )
              AND w.date_released < SYSDATE - 30
            ORDER BY w.date_released
            FETCH FIRST 50 ROWS ONLY""",

        "om_stuck_orders": """
            SELECT h.header_id, h.order_number,
                   h.order_type_id, ot.name order_type,
                   h.booked_date, h.flow_status_code,
                   c.customer_name,
                   COUNT(l.line_id) line_count
            FROM oe_order_headers_all h
            LEFT JOIN oe_transaction_types_tl ot ON h.order_type_id = ot.transaction_type_id
              AND ot.language = USERENV('LANG')
            LEFT JOIN hz_cust_accounts ca ON h.sold_to_org_id = ca.cust_account_id
            LEFT JOIN hz_parties c ON ca.party_id = c.party_id
            LEFT JOIN oe_order_lines_all l ON h.header_id = l.header_id
              AND l.flow_status_code NOT IN ('CLOSED', 'CANCELLED')
            WHERE h.flow_status_code NOT IN ('CLOSED', 'CANCELLED')
              AND EXISTS (
                  SELECT 1 FROM wf_item_activity_statuses wf
                  WHERE wf.item_key = TO_CHAR(h.header_id)
                    AND wf.activity_status IN ('ERROR', 'DEFERRED')
              )
            GROUP BY h.header_id, h.order_number, h.order_type_id, ot.name,
                     h.booked_date, h.flow_status_code, c.customer_name
            ORDER BY h.booked_date
            FETCH FIRST 30 ROWS ONLY""",

        "sla_transfer_errors": """
            SELECT e.event_id, e.event_type_code,
                   e.event_date, e.process_status_code,
                   e.error_message,
                   e.entity_code, e.source_id_int_1,
                   e.application_id, e.creation_date
            FROM xla_events e
            WHERE e.process_status_code IN ('I', 'E')
              AND e.creation_date > SYSDATE - 30
            ORDER BY e.creation_date DESC
            FETCH FIRST 100 ROWS ONLY""",

        "concurrent_manager_status": """
            SELECT q.user_concurrent_queue_name manager_name,
                   q.max_processes target_processes,
                   q.running_processes actual_processes,
                   q.worker_count,
                   q.sleep_seconds,
                   q.manager_type,
                   (SELECT COUNT(*) FROM fnd_concurrent_requests r
                    WHERE r.controlling_manager = q.concurrent_queue_id
                      AND r.status_code = 'R') running_requests,
                   (SELECT COUNT(*) FROM fnd_concurrent_requests r2
                    WHERE r2.phase_code = 'P' AND r2.status_code = 'I') pending_requests
            FROM fnd_concurrent_queues_vl q
            WHERE q.enabled_flag = 'Y'
            ORDER BY q.user_concurrent_queue_name
            FETCH FIRST 30 ROWS ONLY""",

        # ── EBS Agentic App Queries ─────────────────────────────────────────

        # Payables Agentic App
        "ap_po_match_exceptions": """
            SELECT i.invoice_id, i.invoice_num, i.invoice_date,
                   NVL(v.vendor_name,'UNKNOWN') vendor_name,
                   il.po_header_id, il.amount line_amount,
                   il.quantity_invoiced, il.unit_price,
                   il.match_status_flag, i.currency_code,
                   i.creation_date
            FROM ap_invoice_lines_all il
            JOIN ap_invoices_all i ON il.invoice_id = i.invoice_id
            LEFT JOIN ap_suppliers v ON i.vendor_id = v.vendor_id
            WHERE il.match_status_flag IN ('T','D')
              AND NVL(i.cancelled_date, SYSDATE+1) > SYSDATE
              AND i.creation_date > SYSDATE - 60
            ORDER BY i.creation_date DESC
            FETCH FIRST 100 ROWS ONLY""",

        # Collectors Workspace — AR aging
        "ar_aging_buckets": """
            SELECT
                CASE
                    WHEN TRUNC(SYSDATE) - ps.due_date BETWEEN 1 AND 30  THEN '1-30 days'
                    WHEN TRUNC(SYSDATE) - ps.due_date BETWEEN 31 AND 60 THEN '31-60 days'
                    WHEN TRUNC(SYSDATE) - ps.due_date BETWEEN 61 AND 90 THEN '61-90 days'
                    ELSE '90+ days'
                END aging_bucket,
                COUNT(*) invoice_count,
                SUM(ps.amount_due_remaining) amount_overdue,
                ps.invoice_currency_code currency
            FROM ar_payment_schedules_all ps
            WHERE ps.status = 'OP'
              AND ps.due_date < TRUNC(SYSDATE)
              AND ps.amount_due_remaining > 0
            GROUP BY
                CASE
                    WHEN TRUNC(SYSDATE) - ps.due_date BETWEEN 1 AND 30  THEN '1-30 days'
                    WHEN TRUNC(SYSDATE) - ps.due_date BETWEEN 31 AND 60 THEN '31-60 days'
                    WHEN TRUNC(SYSDATE) - ps.due_date BETWEEN 61 AND 90 THEN '61-90 days'
                    ELSE '90+ days'
                END,
                ps.invoice_currency_code
            ORDER BY MIN(ps.due_date)""",

        # Payments Optimization — discount opportunities
        "ap_discount_opportunities": """
            SELECT i.invoice_id, i.invoice_num, i.invoice_date,
                   NVL(v.vendor_name,'UNKNOWN') vendor_name,
                   t.payment_terms_name terms,
                   i.invoice_amount, i.currency_code,
                   ps.discount_date, ps.discount_amount_remaining,
                   ROUND(ps.discount_date - SYSDATE, 0) days_to_discount
            FROM ap_payment_schedules_all ps
            JOIN ap_invoices_all i ON ps.invoice_id = i.invoice_id
            LEFT JOIN ap_suppliers v ON i.vendor_id = v.vendor_id
            LEFT JOIN ap_terms t ON i.terms_id = t.term_id
            WHERE ps.payment_status_flag = 'N'
              AND ps.discount_date > SYSDATE
              AND ps.discount_amount_remaining > 0
            ORDER BY ps.discount_date
            FETCH FIRST 100 ROWS ONLY""",

        # Ledger Monitoring — GL balance check current period
        "gl_current_period_balances": """
            SELECT cc.segment1 company, cc.segment2 cost_center, cc.segment3 account,
                   b.period_name, NVL(b.period_net_dr,0) period_dr,
                   NVL(b.period_net_cr,0) period_cr,
                   NVL(b.period_net_dr,0) - NVL(b.period_net_cr,0) net_activity
            FROM gl_balances b
            JOIN gl_code_combinations cc ON b.code_combination_id = cc.code_combination_id
            WHERE b.actual_flag = 'A'
              AND b.period_year = TO_NUMBER(TO_CHAR(SYSDATE,'YYYY'))
              AND b.period_name = TO_CHAR(SYSDATE,'MON-RRRR')
              AND (NVL(b.period_net_dr,0) + NVL(b.period_net_cr,0)) != 0
            ORDER BY cc.segment1, cc.segment3
            FETCH FIRST 200 ROWS ONLY""",

        # Design-to-Source — pending ECOs
        "pending_ecos": """
            SELECT ech.change_notice, ech.change_name,
                   NVL(ech.description,'') description,
                   ech.status_code, ech.initiation_date,
                   ech.scheduled_date,
                   ROUND(SYSDATE - ech.initiation_date, 0) days_open
            FROM eng_engineering_changes ech
            WHERE ech.status_code NOT IN ('IMPLEMENTED','CANCELLED')
              AND ech.initiation_date > SYSDATE - 180
            ORDER BY ech.initiation_date
            FETCH FIRST 100 ROWS ONLY""",

        # Quote to PR — open requisitions
        "open_requisitions": """
            SELECT r.requisition_header_id, r.segment1 req_number,
                   r.type_lookup_code req_type, r.authorization_status,
                   NVL(u.full_name, TO_CHAR(r.preparer_id)) preparer,
                   r.creation_date,
                   ROUND(SYSDATE - r.creation_date, 0) days_open
            FROM po_requisition_headers_all r
            LEFT JOIN per_all_people_f u ON r.preparer_id = u.person_id
              AND SYSDATE BETWEEN u.effective_start_date AND u.effective_end_date
            WHERE r.authorization_status NOT IN ('APPROVED','CANCELLED','REJECTED')
              AND r.creation_date > SYSDATE - 60
            ORDER BY r.creation_date
            FETCH FIRST 100 ROWS ONLY""",

        # Fulfillment — shipping exceptions
        "shipping_exceptions": """
            SELECT dd.delivery_detail_id, dd.released_status,
                   dd.requested_quantity, dd.picked_quantity,
                   NVL(msi.segment1,'') item_number,
                   dd.item_description,
                   dd.date_scheduled,
                   ROUND(SYSDATE - dd.date_scheduled, 0) days_late
            FROM wsh_delivery_details dd
            LEFT JOIN mtl_system_items_b msi ON dd.inventory_item_id = msi.inventory_item_id
              AND dd.organization_id = msi.organization_id
            WHERE dd.released_status IN ('B','S','Y')
              AND dd.date_scheduled < SYSDATE
              AND dd.source_code = 'OE'
            ORDER BY dd.date_scheduled
            FETCH FIRST 100 ROWS ONLY""",

        # Sales Order — orders on hold
        "orders_on_hold": """
            SELECT h.order_number, hs.name hold_name,
                   oh.creation_date hold_date,
                   NVL(p.party_name,'UNKNOWN') customer_name,
                   h.flow_status_code,
                   ROUND(SYSDATE - oh.creation_date, 0) days_on_hold
            FROM oe_order_holds_all oh
            JOIN oe_order_headers_all h ON oh.header_id = h.header_id
            JOIN oe_hold_sources_all hs ON oh.hold_source_id = hs.hold_source_id
            LEFT JOIN hz_cust_accounts ca ON h.sold_to_org_id = ca.cust_account_id
            LEFT JOIN hz_parties p ON ca.party_id = p.party_id
            WHERE oh.released_flag = 'N'
              AND oh.creation_date > SYSDATE - 30
            ORDER BY oh.creation_date
            FETCH FIRST 100 ROWS ONLY""",

        # Cycle Count — inventory discrepancies
        "cycle_count_discrepancies": """
            SELECT NVL(msi.segment1,'') item_number,
                   NVL(msi.description,'') item_description,
                   e.subinventory,
                   e.count_quantity, e.system_quantity,
                   NVL(e.count_quantity,0) - NVL(e.system_quantity,0) variance_qty,
                   e.entry_status_code, e.count_date
            FROM mtl_cycle_count_entries e
            LEFT JOIN mtl_system_items_b msi ON e.inventory_item_id = msi.inventory_item_id
              AND e.organization_id = msi.organization_id
            WHERE e.entry_status_code IN (2,3,5)
              AND ABS(NVL(e.count_quantity,0) - NVL(e.system_quantity,0)) > 0
              AND e.count_date > SYSDATE - 30
            ORDER BY ABS(NVL(e.count_quantity,0) - NVL(e.system_quantity,0)) DESC
            FETCH FIRST 100 ROWS ONLY""",

        # Resilience — overdue PO receipts
        "overdue_po_receipts": """
            SELECT h.segment1 po_number,
                   NVL(v.vendor_name,'UNKNOWN') vendor_name,
                   NVL(msi.segment1,'') item_number,
                   l.quantity_ordered, NVL(l.quantity_received,0) qty_received,
                   l.quantity_ordered - NVL(l.quantity_received,0) qty_outstanding,
                   NVL(ld.promised_date, ld.need_by_date) due_date,
                   ROUND(SYSDATE - NVL(ld.promised_date, ld.need_by_date), 0) days_overdue
            FROM po_line_locations_all ld
            JOIN po_lines_all l ON ld.po_line_id = l.po_line_id
            JOIN po_headers_all h ON l.po_header_id = h.po_header_id
            LEFT JOIN ap_suppliers v ON h.vendor_id = v.vendor_id
            LEFT JOIN mtl_system_items_b msi ON l.item_id = msi.inventory_item_id
              AND ld.ship_to_organization_id = msi.organization_id
            WHERE ld.closed_code NOT IN ('FINALLY CLOSED','CLOSED')
              AND ld.quantity_received < ld.quantity_ordered
              AND NVL(ld.promised_date, ld.need_by_date) < SYSDATE
              AND NVL(l.cancel_flag,'N') = 'N'
            ORDER BY days_overdue DESC
            FETCH FIRST 100 ROWS ONLY""",

        # Demand Management — open order backlog
        "open_order_backlog": """
            SELECT TO_CHAR(l.schedule_ship_date,'MON-YYYY') ship_period,
                   COUNT(l.line_id) line_count,
                   SUM(l.ordered_quantity) total_qty,
                   SUM(NVL(l.unit_selling_price,0)*NVL(l.ordered_quantity,0)) total_value,
                   l.order_quantity_uom uom
            FROM oe_order_lines_all l
            WHERE l.flow_status_code NOT IN ('CLOSED','CANCELLED','SHIPPED')
              AND l.schedule_ship_date BETWEEN SYSDATE AND SYSDATE + 90
            GROUP BY TO_CHAR(l.schedule_ship_date,'MON-YYYY'),
                     l.schedule_ship_date, l.order_quantity_uom
            ORDER BY l.schedule_ship_date
            FETCH FIRST 50 ROWS ONLY""",

        # Supply Planning — items below min stock
        "items_below_min_stock": """
            SELECT msi.segment1 item_number,
                   NVL(msi.description,'') description,
                   q.organization_id,
                   SUM(q.transaction_quantity) on_hand_qty,
                   msi.primary_uom_code uom,
                   msi.min_minmax_quantity min_qty,
                   CASE WHEN SUM(q.transaction_quantity) = 0 THEN 'ZERO'
                        ELSE 'BELOW_MIN' END stock_status
            FROM mtl_onhand_quantities_detail q
            JOIN mtl_system_items_b msi ON q.inventory_item_id = msi.inventory_item_id
              AND q.organization_id = msi.organization_id
            WHERE msi.planning_make_buy_code = 2
              AND NVL(msi.planning_enabled_flag,'N') = 'Y'
            GROUP BY msi.segment1, msi.description, q.organization_id,
                     msi.primary_uom_code, msi.min_minmax_quantity, msi.inventory_item_id
            HAVING SUM(q.transaction_quantity) < NVL(msi.min_minmax_quantity, 1)
                OR SUM(q.transaction_quantity) = 0
            ORDER BY SUM(q.transaction_quantity)
            FETCH FIRST 100 ROWS ONLY""",

        # S&OP — concurrent manager + workflow health
        "ebs_operational_health": """
            SELECT 'Concurrent Managers' component,
                   COUNT(*) total,
                   SUM(CASE WHEN running_processes > 0 THEN 1 ELSE 0 END) active,
                   SUM(CASE WHEN running_processes = 0 THEN 1 ELSE 0 END) inactive
            FROM fnd_concurrent_queues_vl WHERE enabled_flag = 'Y'
            UNION ALL
            SELECT 'Stuck CP Requests' component,
                   COUNT(*) total, 0 active, COUNT(*) inactive
            FROM fnd_concurrent_requests
            WHERE phase_code = 'R' AND status_code = 'R'
              AND actual_start_date < SYSDATE - 2/24
            UNION ALL
            SELECT 'WF Error Activities' component,
                   COUNT(*) total, 0 active, COUNT(*) inactive
            FROM wf_item_activity_statuses
            WHERE activity_status IN ('ERROR','DEFERRED')
              AND begin_date < SYSDATE - 1""",

        # Order Promising — workflow open notifications
        "wf_open_notifications": """
            SELECT n.notification_id, n.message_type, n.message_name,
                   n.status, n.mail_status,
                   NVL(n.recipient_role,'') recipient,
                   n.begin_date, n.due_date,
                   ROUND(SYSDATE - n.begin_date, 0) days_open,
                   NVL(n.subject,'') subject
            FROM wf_notifications n
            WHERE n.status = 'OPEN'
              AND n.begin_date < SYSDATE - 3
            ORDER BY n.begin_date
            FETCH FIRST 100 ROWS ONLY""",
    }

    def _tool_query_oracle_table(
        self,
        sql: str,
        description: str,
        max_rows: int = 50,
    ) -> Dict[str, Any]:
        """Execute a direct optimized SQL query against Oracle EBS."""
        max_rows = min(max_rows or 50, 500)

        if self.oracle_db.demo_mode:
            # Return sample data for demo mode
            return {
                "success": True,
                "demo_mode": True,
                "description": description,
                "sql": sql,
                "row_count": 0,
                "columns": [],
                "rows": [],
                "message": "Demo mode active — connect to Oracle for live data. Use 'Connect to Oracle' in the sidebar.",
            }

        try:
            start = time.time()
            rows = self.oracle_db.execute_query(sql, max_rows=max_rows)
            elapsed = int((time.time() - start) * 1000)
            columns = list(rows[0].keys()) if rows else []

            return {
                "success": True,
                "demo_mode": False,
                "description": description,
                "row_count": len(rows),
                "columns": columns,
                "rows": rows,
                "execution_time_ms": elapsed,
            }
        except Exception as exc:
            logger.error("query_oracle_table error: %s", exc)
            return {
                "success": False,
                "error": str(exc),
                "description": description,
                "sql": sql,
            }

    def _tool_get_ebs_table_data(
        self,
        table_name: str,
        filters: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """Execute a pre-built optimized EBS query by name."""
        sql = self._PREBUILT_QUERIES.get(table_name)
        if not sql:
            return {"error": f"Unknown table query: {table_name}"}

        # Apply simple filters
        if filters:
            if filters.get("org_id"):
                sql = sql.replace("WHERE ", f"WHERE org_id = {int(filters['org_id'])} AND ", 1)
            if filters.get("days_back"):
                days = int(filters["days_back"])
                sql = sql.replace("SYSDATE - 30", f"SYSDATE - {days}")
                sql = sql.replace("SYSDATE - 90", f"SYSDATE - {days}")

        if self.oracle_db.demo_mode:
            return {
                "success": True,
                "demo_mode": True,
                "table_name": table_name,
                "row_count": 0,
                "columns": [],
                "rows": [],
                "message": "Demo mode active — live Oracle data not available.",
            }

        try:
            start = time.time()
            rows = self.oracle_db.execute_query(sql.strip(), max_rows=500)
            elapsed = int((time.time() - start) * 1000)
            columns = list(rows[0].keys()) if rows else []

            return {
                "success": True,
                "demo_mode": False,
                "table_name": table_name,
                "row_count": len(rows),
                "columns": columns,
                "rows": rows,
                "execution_time_ms": elapsed,
                "sql_used": sql.strip(),
            }
        except Exception as exc:
            logger.error("get_ebs_table_data error for %s: %s", table_name, exc)
            return {
                "success": False,
                "error": str(exc),
                "table_name": table_name,
            }

    def _tool_search_knowledge_base(
        self,
        keywords: List[str],
        error_codes: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Search EBS knowledge base for relevant MOS notes."""
        results = []
        search_terms = [kw.lower() for kw in keywords]
        if error_codes:
            search_terms.extend([ec.lower() for ec in error_codes])

        for kb_key, kb_entries in KNOWLEDGE_BASE.items():
            if any(term in kb_key.lower() or kb_key.lower() in term for term in search_terms):
                results.extend(kb_entries)

        # Deduplicate by doc_id
        seen_docs = set()
        unique_results = []
        for r in results:
            if r["doc_id"] not in seen_docs:
                seen_docs.add(r["doc_id"])
                unique_results.append(r)

        # Also find matching analyzers
        matching_analyzers = search_analyzers(keywords)
        analyzer_suggestions = [
            {"id": a["id"], "name": a["name"], "mos_doc": a.get("mos_doc_id", "")}
            for a in matching_analyzers[:5]
        ]

        return {
            "mos_notes": unique_results[:10],
            "suggested_analyzers": analyzer_suggestions,
            "total_found": len(unique_results),
        }

    def _tool_generate_incident_report(
        self,
        session_id: str,
        format: str = "markdown",
    ) -> Dict[str, Any]:
        """Generate incident report for a session."""
        session = self.pg_store.get_session(session_id)
        if not session:
            session = {
                "session_id": session_id,
                "instance_info": self.oracle_db.get_ebs_version(),
                "status": "active",
            }

        findings_data = self.pg_store.get_session_findings(session_id)
        findings = []
        for fd in findings_data:
            try:
                f = Finding(**{k: v for k, v in fd.items() if k in Finding.model_fields})
                findings.append(f)
            except Exception:
                pass

        # Also include any in-memory findings for this session
        cached = self._session_findings.get(session_id, [])
        known_ids = {f.id for f in findings}
        for f in cached:
            if f.id not in known_ids:
                findings.append(f)

        if format == "summary":
            summary = self.report_generator.generate_executive_summary(findings)
            counts = self.report_generator.severity_counts(findings)
            return {
                "summary": summary,
                "severity_counts": counts,
                "total_findings": len(findings),
            }

        report_md = self.report_generator.generate_markdown_report(session, findings)
        return {
            "report": report_md,
            "findings_count": len(findings),
            "severity_counts": self.report_generator.severity_counts(findings),
        }

    def _tool_get_session_findings(
        self,
        session_id: str,
        severity_filter: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Retrieve session findings."""
        findings_data = self.pg_store.get_session_findings(session_id)

        # Include in-memory cache
        cached = self._session_findings.get(session_id, [])
        all_findings = list(findings_data)
        stored_ids = {fd.get("id") for fd in findings_data if fd.get("id")}

        for f in cached:
            fdict = f.to_dict()
            if fdict.get("id") not in stored_ids:
                all_findings.append(fdict)

        if severity_filter:
            all_findings = [f for f in all_findings if f.get("severity") in severity_filter]

        counts = {}
        for f in all_findings:
            sev = f.get("severity", "INFO")
            counts[sev] = counts.get(sev, 0) + 1

        return {
            "findings": all_findings[:50],
            "total": len(all_findings),
            "severity_counts": counts,
        }

    def _tool_save_finding(
        self,
        session_id: str,
        analyzer_id: str,
        module: str,
        severity: str,
        description: str,
        category: str = "",
        recommended_action: str = "",
        mos_references: Optional[List[str]] = None,
        affected_objects: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """Save a manually identified finding."""
        finding = Finding(
            analyzer_id=analyzer_id,
            module=module,
            severity=severity,  # type: ignore
            category=category or analyzer_id,
            description=description,
            recommended_action=recommended_action,
            mos_references=mos_references or [],
            affected_objects=affected_objects or [],
        )

        success = self.pg_store.save_finding(session_id, finding.to_dict())

        if session_id not in self._session_findings:
            self._session_findings[session_id] = []
        self._session_findings[session_id].append(finding)

        return {
            "status": "saved" if success else "error",
            "finding_id": finding.id,
            "severity": finding.severity,
        }

    # ─── Direct Analyzer Execution (for UI bypass) ────────────────────────────

    def run_analyzer_direct(
        self,
        analyzer_id: str,
        session_id: str,
        params: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Run an analyzer directly (bypassing LLM tool_use).
        Used by the Streamlit UI for manual analyzer execution.
        """
        result = self._tool_execute_analyzer(
            analyzer_id=analyzer_id,
            params=params,
            session_id=session_id,
            accumulated_findings=[],
            raw_results={},
        )

        # Save findings from direct run
        for f_dict in result.get("findings", []):
            self.pg_store.save_finding(session_id, f_dict)
            if session_id not in self._session_findings:
                self._session_findings[session_id] = []
            try:
                self._session_findings[session_id].append(
                    Finding(**{k: v for k, v in f_dict.items() if k in Finding.model_fields})
                )
            except Exception:
                pass

        return result

    def get_cached_findings(self, session_id: str) -> List[Finding]:
        """Return in-memory cached findings for a session."""
        return self._session_findings.get(session_id, [])

    # ─── Streaming Interface for Flask SSE ───────────────────────────────────

    def chat_stream(self, message: str, session_id: str, conversation_history: List[Dict[str, Any]] = None):
        """
        Generator that yields SSE-compatible dicts during analysis.
        Used by the Flask /api/chat endpoint for Server-Sent Events streaming.

        Yields dicts with 'type' key:
          {"type": "status", "text": "..."}
          {"type": "finding", "severity": "...", "analyzer": "...", ...}
          {"type": "response", "text": "..."}
          {"type": "done", "finding_count": N, "session_id": "..."}
          {"type": "error", "text": "..."}
        """
        if conversation_history is None:
            conversation_history = []

        yield {"type": "status", "text": "Classifying intent and routing to appropriate analyzers..."}

        accumulated_findings: List[Finding] = []
        tools_called: List[str] = []
        raw_results: Dict[str, Any] = {}
        response_text = ""

        messages = list(conversation_history)
        messages.append({"role": "user", "content": message})

        max_iterations = 10
        iteration = 0

        try:
            while iteration < max_iterations:
                iteration += 1

                response = self.client.messages.create(
                    model=MODEL,
                    max_tokens=4096,
                    system=SYSTEM_PROMPT,
                    tools=TOOLS,
                    messages=messages,
                )

                # Collect text content
                for block in response.content:
                    if hasattr(block, "text"):
                        response_text = block.text

                # Check if we need to handle tool calls
                if response.stop_reason != "tool_use":
                    break

                # Process tool calls
                tool_results = []
                for block in response.content:
                    if block.type != "tool_use":
                        continue

                    tool_name = block.name
                    tool_input = block.input
                    tools_called.append(tool_name)

                    # Emit status events for tool calls
                    if tool_name == "classify_intent":
                        yield {"type": "status", "text": "Classifying problem type and identifying modules..."}
                    elif tool_name == "execute_analyzer":
                        analyzer_id = tool_input.get("analyzer_id", "unknown")
                        analyzer_info = get_analyzer(analyzer_id)
                        name = analyzer_info.get("name", analyzer_id) if analyzer_info else analyzer_id
                        yield {"type": "status", "text": f"Running {name}..."}
                    elif tool_name == "invoke_module_agent":
                        agent = tool_input.get("agent_name", "")
                        yield {"type": "status", "text": f"Invoking {agent} module agent..."}
                    elif tool_name == "search_knowledge_base":
                        yield {"type": "status", "text": "Searching knowledge base for related MOS notes..."}
                    elif tool_name == "generate_incident_report":
                        yield {"type": "status", "text": "Generating incident report..."}
                    elif tool_name == "get_ebs_system_info":
                        yield {"type": "status", "text": "Retrieving EBS system information..."}
                    elif tool_name == "query_oracle_table":
                        desc = tool_input.get("description", "custom query")
                        yield {"type": "status", "text": f"Querying Oracle: {desc}..."}
                    elif tool_name == "get_ebs_table_data":
                        tbl = tool_input.get("table_name", "")
                        yield {"type": "status", "text": f"Fetching live data: {tbl.replace('_', ' ')}..."}

                    prev_finding_count = len(accumulated_findings)

                    try:
                        result = self._dispatch_tool(
                            tool_name=tool_name,
                            tool_input=tool_input,
                            session_id=session_id,
                            accumulated_findings=accumulated_findings,
                            raw_results=raw_results,
                        )
                    except Exception as exc:
                        logger.error("Tool %s error: %s", tool_name, exc)
                        result = {"error": str(exc), "status": "error"}
                        yield {"type": "status", "text": f"Warning: {tool_name} encountered an error: {str(exc)[:100]}"}

                    # Emit finding events for any new findings discovered
                    new_findings = accumulated_findings[prev_finding_count:]
                    for f in new_findings:
                        f_dict = f.to_dict() if isinstance(f, Finding) else f
                        yield {
                            "type": "finding",
                            "severity": f_dict.get("severity", "INFO"),
                            "analyzer": f_dict.get("analyzer_id", ""),
                            "module": f_dict.get("module", ""),
                            "category": f_dict.get("category", ""),
                            "description": f_dict.get("description", ""),
                            "recommended_action": f_dict.get("recommended_action", ""),
                            "mos_references": f_dict.get("mos_references", []),
                            "affected_objects": f_dict.get("affected_objects", []),
                        }

                    # Emit data_table event for live query results
                    if tool_name in ("query_oracle_table", "get_ebs_table_data"):
                        if result.get("success") and not result.get("demo_mode") and result.get("rows"):
                            yield {
                                "type": "data_table",
                                "table_name": result.get("table_name") or tool_input.get("description", "Query Result"),
                                "columns": result.get("columns", []),
                                "rows": result.get("rows", []),
                                "row_count": result.get("row_count", 0),
                                "execution_time_ms": result.get("execution_time_ms", 0),
                            }

                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result, default=str),
                    })

                messages.append({"role": "assistant", "content": response.content})
                messages.append({"role": "user", "content": tool_results})

        except Exception as exc:
            logger.error("chat_stream error: %s", exc)
            yield {"type": "error", "text": f"Analysis error: {str(exc)}"}
            yield {"type": "done", "finding_count": len(accumulated_findings), "session_id": session_id}
            return

        # Save all accumulated findings
        for finding in accumulated_findings:
            self.pg_store.save_finding(session_id, finding.to_dict())

        if session_id not in self._session_findings:
            self._session_findings[session_id] = []
        self._session_findings[session_id].extend(accumulated_findings)

        self.pg_store.log_audit(
            session_id=session_id,
            action="chat_stream",
            analyzer_id=",".join(set(f.analyzer_id for f in accumulated_findings)),
            result_summary=f"{len(accumulated_findings)} findings, tools: {','.join(tools_called)}",
            row_count=len(accumulated_findings),
        )

        yield {"type": "response", "text": response_text}
        yield {"type": "done", "finding_count": len(accumulated_findings), "session_id": session_id}
