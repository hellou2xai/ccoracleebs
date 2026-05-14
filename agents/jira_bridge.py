"""
JIRA <-> EBS bridge agent.

Two flows:

1. EBS errors -> JIRA tickets
   scan_fusion_errors() runs every fusion app and returns a flat list of
   ticketable findings (severity + the offending rows).
   generate_ticket_draft() takes one finding plus its sample rows and asks
   Claude to draft a JIRA ticket: title, description (problem statement,
   evidence, root cause, recommended fix), priority, labels.

2. JIRA ticket -> EBS troubleshooting
   classify_ticket() asks Claude to pick the most relevant fusion apps for
   a ticket's text.
   troubleshoot_ticket() then runs those apps live, collects findings, and
   asks Claude to synthesize a troubleshooting report that can be posted
   back to JIRA as a comment.
"""

import os
import json
import logging
import time
from typing import Any, Dict, List, Optional

import anthropic

from config.fusion_apps import FUSION_APPS, get_fusion_app

logger = logging.getLogger(__name__)

MODEL = "claude-sonnet-4-6"

# Severity (from fusion app rules) -> JIRA priority
SEVERITY_TO_PRIORITY = {
    "CRITICAL": "Highest",
    "HIGH":     "High",
    "MEDIUM":   "Medium",
    "LOW":      "Low",
    "INFO":     "Lowest",
}


def _client() -> anthropic.Anthropic:
    return anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY", ""))


def _strip_text(blocks) -> str:
    """Extract plain text from Claude's response content blocks."""
    out = []
    for b in blocks:
        if getattr(b, "type", None) == "text":
            out.append(b.text)
    return _sanitize_prose("".join(out).strip())


def _sanitize_prose(text: str) -> str:
    """Strip em-dashes and en-dashes per project writing rules."""
    if not text:
        return text
    # em-dash / en-dash -> period + space (start new sentence)
    # When the dash sits between two short words or inside a label,
    # a comma reads better. We default to ". " which is always safe.
    text = text.replace(" — ", ". ")
    text = text.replace(" – ", ". ")
    text = text.replace("—", ". ")
    text = text.replace("–", ". ")
    return text


# ═══════════════════════════════════════════════════════════════════════════
# Flow 1: EBS errors -> JIRA tickets
# ═══════════════════════════════════════════════════════════════════════════

def scan_fusion_errors(oracle_db, days_back: int = 30,
                       max_rows_per_query: int = 25) -> Dict[str, Any]:
    """
    Run every fusion app and collect every CRITICAL/HIGH/MEDIUM finding.
    Returns a flat list of ticketable items with the offending rows attached
    so the user can preview before opening tickets.
    """
    demo_mode = (oracle_db is None) or getattr(oracle_db, "demo_mode", False)
    items: List[Dict[str, Any]] = []
    app_stats: List[Dict[str, Any]] = []
    started = time.time()

    for app_id, app_def in FUSION_APPS.items():
        app_t0 = time.time()
        app_findings: List[Dict[str, Any]] = []

        if demo_mode:
            for f in app_def.get("demo_findings", []):
                items.append(_make_item(app_def, f, demo_rows=[]))
                app_findings.append(f)
        else:
            for q in app_def.get("queries", []):
                try:
                    sql = q["sql"].strip().format(days_back=days_back)
                    rows = oracle_db.execute_query(sql, max_rows=200)
                    count = len(rows)
                except Exception as exc:
                    logger.warning("scan: app %s query %s failed: %s",
                                   app_id, q["id"], exc)
                    continue
                for rule in q.get("severity_rules", []):
                    op = rule.get("op", ">")
                    thr = rule.get("value", 0)
                    meets = (op == ">"  and count > thr) or \
                            (op == ">=" and count >= thr) or \
                            (op == "==" and count == thr)
                    if not meets:
                        continue
                    sev = rule.get("severity", "INFO")
                    if sev in ("INFO", "LOW"):
                        break  # skip non-actionable
                    msg = rule["message"].format(count=count)
                    finding = {
                        "severity": sev,
                        "category": q["label"],
                        "count": count,
                        "description": msg,
                        "query_id": q["id"],
                    }
                    items.append(_make_item(app_def, finding,
                                            demo_rows=rows[:max_rows_per_query],
                                            sql=sql))
                    app_findings.append(finding)
                    break  # first matching rule wins

        app_stats.append({
            "app_id": app_id,
            "app_name": app_def["name"],
            "pillar": app_def["pillar"],
            "finding_count": len(app_findings),
            "elapsed_ms": int((time.time() - app_t0) * 1000),
        })

    items.sort(key=lambda x: ("CRITICAL HIGH MEDIUM"
                              .split().index(x["severity"])
                              if x["severity"] in ("CRITICAL", "HIGH", "MEDIUM")
                              else 99))

    return {
        "demo_mode": demo_mode,
        "days_back": days_back,
        "items": items,
        "app_stats": app_stats,
        "total_items": len(items),
        "elapsed_ms": int((time.time() - started) * 1000),
    }


def _make_item(app_def: Dict[str, Any], finding: Dict[str, Any],
               demo_rows: List[Dict[str, Any]],
               sql: Optional[str] = None) -> Dict[str, Any]:
    return {
        "id": f"{app_def['id']}::{finding.get('query_id') or finding.get('category', 'finding')}",
        "app_id": app_def["id"],
        "app_name": app_def["name"],
        "pillar": app_def["pillar"],
        "severity": finding.get("severity", "MEDIUM"),
        "category": finding.get("category", ""),
        "description": finding.get("description", ""),
        "count": finding.get("count", 0),
        "query_id": finding.get("query_id"),
        "sample_rows": demo_rows or [],
        "sql": sql,
        "suggested_priority": SEVERITY_TO_PRIORITY.get(
            finding.get("severity", "MEDIUM"), "Medium"),
    }


_TICKET_DRAFT_SYSTEM = """You are an Oracle EBS Support analyst preparing a JIRA ticket
from a live finding in an EBS Agentic Application. Plain professional English.

## Output rules (strict)
- NEVER use em-dashes or en-dashes. Use a period and start a new sentence,
  a comma, or a colon before a list. Banned characters: U+2014 and U+2013.
- Plain professional voice. No marketing words (leverage, unlock,
  comprehensive, robust, seamless, holistic). No rhetorical questions.
- No literal markdown tables (pipes and dashes).
- No horizontal rules (no `---` lines).
- No inline backticks for code. Name the table or column in normal text.
- Headings: use `## ` for major sections only. Do not use `# ` or `### `.
- Lists: use `- ` for bullets, or `1. ` `2. ` `3. ` for numbered lists.
- Bold for emphasis on EBS object names is fine: **AP_INVOICES_ALL**.
- Be specific. Use real EBS table names, column names, counts, and sample
  values from the data shown. Do not invent invoice numbers, vendor IDs,
  or row values.

## Required description structure (in this order)
## Problem
Two or three sentences. What is broken. Who is affected. The business impact.

## Evidence
Three to six lines covering the app, severity, category, count, the EBS
tables involved, and one or two concrete observations from the sample rows.

## Likely root cause
Three to five sentences. Name the actual tables, columns, profile options,
or setup screens.

## Recommended fix
Numbered list of three to six steps. Each step is one or two sentences.
Name the responsibility, navigation path, concurrent program, or SQL.

## Related MOS docs
Bullet list of Oracle Metalink document IDs that apply. If none apply,
write "None identified".

Use the submit_ticket_draft tool to return the ticket.
"""

_TICKET_DRAFT_TOOL = {
    "name": "submit_ticket_draft",
    "description": "Submit the drafted JIRA ticket for the EBS finding.",
    "input_schema": {
        "type": "object",
        "properties": {
            "summary": {
                "type": "string",
                "description": "Short, specific title under 240 chars."
            },
            "description": {
                "type": "string",
                "description": "Markdown description with sections: Problem, Evidence, Likely Root Cause, Recommended Fix, Related MOS Docs."
            },
            "labels": {
                "type": "array",
                "items": {"type": "string"},
                "description": "2-5 lowercase hyphenated labels."
            },
            "issue_type": {
                "type": "string",
                "enum": ["Bug", "Task", "Story", "Incident"],
                "description": "JIRA issue type."
            },
        },
        "required": ["summary", "description", "labels", "issue_type"],
    },
}


def generate_ticket_draft(item: Dict[str, Any]) -> Dict[str, Any]:
    """Ask Claude to draft a JIRA ticket from a single ticketable item."""
    sample = item.get("sample_rows") or []
    sample_text = json.dumps(sample[:10], indent=2, default=str)
    user_msg = f"""# EBS Agentic App Finding

**App:** {item.get('app_name')} ({item.get('app_id')})
**Pillar:** {item.get('pillar')}
**Severity:** {item.get('severity')}
**Category:** {item.get('category')}
**Finding:** {item.get('description')}
**Row count:** {item.get('count', 0)}

## SQL used
```
{(item.get('sql') or '(demo data)').strip()[:1200]}
```

## Sample rows (up to 10)
```json
{sample_text[:3500]}
```

Now draft the JIRA ticket using the submit_ticket_draft tool.
"""
    draft: Dict[str, Any] = {}
    try:
        client = _client()
        resp = client.messages.create(
            model=MODEL,
            max_tokens=2000,
            system=_TICKET_DRAFT_SYSTEM,
            tools=[_TICKET_DRAFT_TOOL],
            tool_choice={"type": "tool", "name": "submit_ticket_draft"},
            messages=[{"role": "user", "content": user_msg}],
        )
        for block in resp.content:
            if getattr(block, "type", None) == "tool_use" and block.name == "submit_ticket_draft":
                draft = block.input or {}
                break
    except Exception as e:
        logger.error("ticket draft generation failed: %s", e)

    if not draft:
        draft = {
            "summary": f"{item.get('app_name')} - {item.get('category')}",
            "description": (f"## Problem\n{item.get('description')}\n\n"
                            f"## Evidence\nRow count: {item.get('count')}\n\n"
                            f"## Likely Root Cause\n(AI generation failed; "
                            f"investigate manually)\n\n"
                            f"## Recommended Fix\nRun the {item.get('app_id')} "
                            f"app in EBS Apps and inspect the rows."),
            "labels": ["ebs", item.get("pillar", "").lower(), item.get("app_id")],
            "issue_type": "Bug" if item.get("severity") == "CRITICAL" else "Task",
        }

    return {
        "summary": (draft.get("summary") or "")[:240],
        "description": draft.get("description") or "",
        "labels": draft.get("labels") or [],
        "issue_type": draft.get("issue_type") or "Task",
        "priority": item.get("suggested_priority", "Medium"),
    }


def _extract_json(text: str) -> str:
    """Pull JSON out of a Claude response that may include ```json fences."""
    t = text.strip()
    if t.startswith("```"):
        t = t.lstrip("`")
        if t.lower().startswith("json"):
            t = t[4:]
        t = t.lstrip("\n")
        if t.endswith("```"):
            t = t[:-3]
        t = t.strip()
    return t


# ═══════════════════════════════════════════════════════════════════════════
# Flow 2: JIRA ticket -> EBS troubleshooting
# ═══════════════════════════════════════════════════════════════════════════

def _app_catalog_for_prompt() -> str:
    rows = []
    for a in FUSION_APPS.values():
        kpis = ", ".join(a.get("kpis", [])[:3])
        rows.append(f"- **{a['id']}** ({a['pillar']}): {a['name']}. "
                    f"{a.get('tagline', '')}. KPIs: {kpis}.")
    return "\n".join(rows)


_CLASSIFY_SYSTEM = """You are an Oracle EBS Support triage analyst.

You will be given a JIRA ticket (summary + description) describing a real
or suspected EBS issue. You must pick which EBS Agentic Apps from the
catalog below are most likely to surface live evidence for this ticket.

Use the `submit_classification` tool to return your answer. Pick 1-3 apps.
Use ONLY ids from the catalog. If nothing applies, return apps: [] and say so.
"""

_CLASSIFY_TOOL = {
    "name": "submit_classification",
    "description": "Submit your classification of the JIRA ticket.",
    "input_schema": {
        "type": "object",
        "properties": {
            "rationale": {
                "type": "string",
                "description": "1-3 sentences explaining your choice."
            },
            "apps": {
                "type": "array",
                "items": {"type": "string"},
                "description": "1-3 fusion app ids from the catalog. Empty list if none apply."
            },
            "keywords": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Short tags like module:AP, topic:hold."
            },
        },
        "required": ["rationale", "apps", "keywords"],
    },
}


def classify_ticket(summary: str, description: str) -> Dict[str, Any]:
    user_msg = f"""## JIRA Ticket
**Summary:** {summary}

**Description:**
{description[:4000]}

## EBS Agentic App Catalog
{_app_catalog_for_prompt()}

Now use submit_classification to pick the right apps."""
    data: Dict[str, Any] = {}
    try:
        resp = _client().messages.create(
            model=MODEL,
            max_tokens=1000,
            system=_CLASSIFY_SYSTEM,
            tools=[_CLASSIFY_TOOL],
            tool_choice={"type": "tool", "name": "submit_classification"},
            messages=[{"role": "user", "content": user_msg}],
        )
        for block in resp.content:
            if getattr(block, "type", None) == "tool_use" and block.name == "submit_classification":
                data = block.input or {}
                break
    except Exception as e:
        logger.error("classify_ticket failed: %s", e)
        data = {"rationale": f"AI classification failed: {e}",
                "apps": [], "keywords": []}
    data["apps"] = [a for a in (data.get("apps") or []) if a in FUSION_APPS][:3]
    data.setdefault("rationale", "")
    data.setdefault("keywords", [])
    return data


_SYNTHESIS_SYSTEM = """You are an Oracle EBS Support specialist writing a
troubleshooting report that will be posted as a comment on a JIRA ticket.
The audience is a working EBS support team. Plain professional English.

## Output rules (strict)
- NEVER use em-dashes or en-dashes. Use a period and start a new sentence,
  a comma if the thought continues, or a colon before a list. Banned
  characters: U+2014 and U+2013.
- Plain professional voice. No marketing words (leverage, unlock,
  comprehensive, robust, seamless, holistic). No rhetorical questions.
- No literal markdown tables (pipes and dashes).
- No horizontal rules (no `---` lines).
- No inline backticks for code. Just name the table or column in normal text.
- Headings: use `## ` for major sections only. Do not use `# ` or `### `.
- Lists: use `- ` for bullets, or `1. ` `2. ` `3. ` for numbered lists.
- Bold for emphasis on EBS object names is fine: `**AP_INVOICES_ALL**`.
- Do not invent invoice numbers, PO numbers, or row values. If you reference
  a specific example, it must come from the sample rows provided.

## Required structure

## Summary
Two or three sentences. What we ran. What we found. The headline impact.

## Evidence from live EBS
For each app that was run, write one short paragraph naming the app, the
finding category, the row count, and one or two concrete observations.

## Likely root cause
Three to five sentences. Name the actual EBS tables, columns, profile
options, or setup screens involved. Be specific to this evidence.

## Recommended next steps
Numbered list of three to six steps. Each step is one or two sentences.
Name the responsibility, navigation path, concurrent program, or SQL
needed. Reference Oracle MOS document numbers where they help.

## Confidence
One line: LOW, MEDIUM, or HIGH followed by a brief reason.

Write the report now. Do not wrap it in JSON or code fences.
"""


def troubleshoot_ticket(summary: str, description: str, oracle_db,
                        days_back: int = 30,
                        forced_apps: Optional[List[str]] = None) -> Dict[str, Any]:
    started = time.time()
    if forced_apps:
        classification = {
            "rationale": "App selection overridden by caller.",
            "apps": [a for a in forced_apps if a in FUSION_APPS][:3],
            "keywords": [],
        }
    else:
        classification = classify_ticket(summary or "", description or "")

    chosen = classification.get("apps", [])
    demo_mode = (oracle_db is None) or getattr(oracle_db, "demo_mode", False)
    app_runs: List[Dict[str, Any]] = []

    for app_id in chosen:
        app_def = get_fusion_app(app_id)
        if not app_def:
            continue
        run = {"app_id": app_id, "app_name": app_def["name"],
               "pillar": app_def["pillar"], "findings": [],
               "query_summaries": [], "demo_mode": demo_mode}
        if demo_mode:
            run["findings"] = app_def.get("demo_findings", [])[:5]
        else:
            for q in app_def.get("queries", []):
                try:
                    sql = q["sql"].strip().format(days_back=days_back)
                    rows = oracle_db.execute_query(sql, max_rows=200)
                except Exception as exc:
                    logger.warning("troubleshoot: %s %s failed: %s",
                                   app_id, q["id"], exc)
                    continue
                count = len(rows)
                run["query_summaries"].append({
                    "query_id": q["id"], "label": q["label"],
                    "row_count": count,
                    "sample_rows": rows[:5],
                })
                for rule in q.get("severity_rules", []):
                    op = rule.get("op", ">")
                    thr = rule.get("value", 0)
                    if ((op == ">"  and count > thr) or
                        (op == ">=" and count >= thr) or
                        (op == "==" and count == thr)):
                        run["findings"].append({
                            "severity": rule.get("severity", "INFO"),
                            "category": q["label"],
                            "count": count,
                            "description": rule["message"].format(count=count),
                            "query_id": q["id"],
                        })
                        break
        app_runs.append(run)

    # Ask Claude to synthesize a troubleshooting report
    if app_runs:
        synthesis_input = {
            "ticket": {"summary": summary, "description": description[:2500]},
            "classification": classification,
            "app_runs": app_runs,
        }
        try:
            resp = _client().messages.create(
                model=MODEL,
                max_tokens=2500,
                system=_SYNTHESIS_SYSTEM,
                messages=[{
                    "role": "user",
                    "content": "Here is the data to write the report from:\n\n"
                    + json.dumps(synthesis_input, indent=2, default=str)[:14000]
                }],
            )
            report = _strip_text(resp.content)
        except Exception as e:
            logger.error("troubleshoot synthesis failed: %s", e)
            report = (f"# Troubleshooting Report\n\n"
                      f"## Summary\nAutomated report generation failed: {e}\n\n"
                      f"## Apps Run\n"
                      + "\n".join(f"- {r['app_name']} "
                                  f"({len(r['findings'])} findings)"
                                  for r in app_runs))
    else:
        report = ("# Troubleshooting Report\n\n## Summary\nNo EBS Agentic App "
                  "in the catalog matched this ticket; please run a manual "
                  "analyzer from the Agents page.")

    return {
        "classification": classification,
        "app_runs": app_runs,
        "report": report,
        "elapsed_ms": int((time.time() - started) * 1000),
        "demo_mode": demo_mode,
    }
