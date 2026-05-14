# Product Requirements Document
# Oracle EBS Support Agent System
**Version**: 1.0
**Date**: 2026-03-31
**Classification**: Internal — Engineering & Product
**Based on**: Oracle EBS Proactive Services Analyzer Bundle v200.170 (Build: 27-Feb-2026)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Goals & Success Metrics](#3-goals--success-metrics)
4. [System Architecture Overview](#4-system-architecture-overview)
5. [User Personas](#5-user-personas)
6. [Module Agent Specifications](#6-module-agent-specifications)
   - 6.1 [Orchestrator / Router Agent](#61-orchestrator--router-agent)
   - 6.2 [ATG Core Agent](#62-atg-core-agent)
   - 6.3 [Financials Agent](#63-financials-agent)
   - 6.4 [Manufacturing Agent](#64-manufacturing-agent)
   - 6.5 [Human Capital Management (HCM) Agent](#65-human-capital-management-hcm-agent)
   - 6.6 [CRM Agent](#66-crm-agent)
7. [Cross-Cutting Capabilities](#7-cross-cutting-capabilities)
8. [Tool & Integration Requirements](#8-tool--integration-requirements)
9. [Data Requirements](#9-data-requirements)
10. [Security & Compliance](#10-security--compliance)
11. [Non-Functional Requirements](#11-non-functional-requirements)
12. [Implementation Phases](#12-implementation-phases)
13. [Acceptance Criteria](#13-acceptance-criteria)
14. [Glossary](#14-glossary)

---

## 1. Executive Summary

The **Oracle EBS Support Agent System** is a multi-agent AI platform designed to automate, accelerate, and enhance Oracle E-Business Suite (EBS) support operations. It replaces the manual, script-by-script execution model of the existing Proactive Services Analyzer Bundle (Doc ID 1939637.1) with an intelligent, conversational, context-aware agent system that can diagnose issues, interpret analyzer output, recommend remediation steps, execute analyzers autonomously, and guide support engineers through complex multi-module workflows.

The system is built as a hierarchy of specialized agents — one per EBS functional module family — coordinated by an Orchestrator agent that routes requests, manages context, and synthesizes cross-module findings into unified incident reports.

The existing bundle covers **378 analyzer scripts** across **5 module families** (ATG/Core, Financials, Manufacturing, HCM, CRM), **46 Hybrid XML Analyzers**, **152 FNDLOAD templates**, and a Perl-based menu execution framework. The agent system wraps and extends all of this capability with natural language interaction, autonomous execution planning, and intelligent result interpretation.

---

## 2. Problem Statement

### Current State

Oracle EBS support engineers and DBAs operate with the Proactive Services Analyzer Bundle by:
1. SSH-ing into the EBS application server
2. Running `perl Menu.pl apps/<password>` interactively
3. Selecting module families from a terminal menu
4. Running individual SQL or Java-based analyzer scripts one-by-one
5. Manually reading raw SQL output or HTML reports
6. Cross-referencing findings against My Oracle Support (MOS) notes manually
7. Repeating across multiple modules when issues span module boundaries

### Pain Points

| Pain Point | Impact |
|---|---|
| No natural language interface — engineers must know which analyzer to run | Slow triage; wrong analyzer chosen frequently |
| 378 analyzers across 5 families — impossible to know all | Critical checks skipped; issues missed |
| Output is raw SQL result-sets — no interpretation | High cognitive load; errors in reading |
| No correlation across modules | Cross-module root cause missed (e.g., AP period close blocking GL) |
| No proactive monitoring — reactive only | Issues found after business impact |
| Password handling via CLI — insecure | Security risk in shared environments |
| No history / audit trail of what was diagnosed | Repeat analysis on same system; no trending |
| Update process is manual (copy bundle.zip to /update) | Stale analyzers deployed in field |

### Desired State

An AI agent system that:
- Accepts natural language support requests ("AP invoices are stuck in validation")
- Determines which analyzers to run and in what order
- Executes analyzers autonomously against the EBS database
- Interprets raw output and maps findings to known issues (MOS notes, patches)
- Produces a structured incident report with prioritized recommendations
- Supports conversational follow-up ("Why is that failing?", "Show me only critical items")
- Proactively monitors key health indicators on schedule
- Maintains full audit trail of all diagnostics performed

---

## 3. Goals & Success Metrics

### Primary Goals

| Goal | Metric | Target |
|---|---|---|
| Reduce mean time to diagnosis (MTTD) | Time from ticket open to root cause identified | < 15 minutes (from ~2 hours) |
| Increase analyzer coverage per incident | Number of relevant analyzers run per ticket | 100% applicable analyzers (from ~30%) |
| Eliminate manual output interpretation | % of findings auto-interpreted with MOS references | > 90% |
| Enable proactive issue detection | Issues found before user-reported impact | > 40% of critical issues |
| Reduce re-work | % of tickets requiring follow-up due to missed checks | < 5% |
| Audit completeness | % of support sessions with full execution log | 100% |

### Secondary Goals

- Enable junior engineers to perform Tier-2/Tier-3 level diagnostics without deep EBS expertise
- Reduce dependency on specific SMEs for module-specific triage
- Build institutional knowledge through historical analysis storage
- Support multi-tenant / multi-instance environments from a single agent interface

---

## 4. System Architecture Overview

### 4.1 Agent Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER INTERFACE LAYER                         │
│         (Chat UI / Slack / MOS Integration / REST API)          │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                   ORCHESTRATOR AGENT                            │
│  - Intent classification & module routing                       │
│  - Multi-module workflow planning                               │
│  - Context & session management                                 │
│  - Cross-module correlation & synthesis                         │
│  - Incident report generation                                   │
└──┬──────────┬────────────┬──────────────┬──────────────┬────────┘
   │          │            │              │              │
   ▼          ▼            ▼              ▼              ▼
┌──────┐ ┌────────┐ ┌───────────┐ ┌─────────┐ ┌──────────────┐
│ ATG  │ │  FIN   │ │    MFG    │ │   HCM   │ │     CRM      │
│AGENT │ │ AGENT  │ │   AGENT   │ │  AGENT  │ │    AGENT     │
└──┬───┘ └───┬────┘ └─────┬─────┘ └────┬────┘ └──────┬───────┘
   │         │            │             │              │
   └────────────────────────────────────────────────────────────┐
                           │                                     │
┌──────────────────────────▼─────────────────────────────────────▼┐
│                     TOOL LAYER                                  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │  SQL Executor│ │ Java/HAF     │ │  FNDLOAD Executor        │ │
│  │  (378 sqls)  │ │  (46 xmls)   │ │  (152 LDT templates)     │ │
│  └──────────────┘ └──────────────┘ └──────────────────────────┘ │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │  MOS Search  │ │ Output Parser│ │  DB Health Monitor       │ │
│  │  (Patches)   │ │  & Formatter │ │  (Proactive Schedules)   │ │
│  └──────────────┘ └──────────────┘ └──────────────────────────┘ │
└────────────────────────────────────────────────────────────────-─┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    DATA LAYER                                   │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │  EBS Oracle  │ │  Session &   │ │  Knowledge Base          │ │
│  │  Database    │ │  Audit Store │ │  (MOS Notes, Patches)    │ │
│  └──────────────┘ └──────────────┘ └──────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Agent Communication Protocol

- All agents communicate via a structured **AgentMessage** schema (JSON)
- Each message includes: `session_id`, `source_agent`, `target_agent`, `intent`, `context`, `payload`, `priority`, `timestamp`
- Orchestrator maintains a **WorkflowPlan** — a directed acyclic graph (DAG) of agent tasks
- Module agents return **AnalysisFinding** objects: `severity`, `category`, `description`, `affected_objects`, `mos_references`, `recommended_action`, `auto_fixable`
- All tool invocations are logged to the **Audit Store** with full input/output

### 4.3 Analyzer Execution Model

The existing bundle supports two execution modes the agent system must replicate and extend:

**Mode 1 — SQL Execution (Direct)**
- Agent submits SQL from `analyzers/*.sql` files to the EBS Oracle DB via JDBC/cx_Oracle
- Captures UTL_FILE output or SQL*Plus spool output
- Parses structured result sets

**Mode 2 — Hybrid Analyzer Framework (Java/XML)**
- Agent invokes `run_analyzer.sh` with APPS credentials and target XML analyzer
- JDK 7+ required; agent validates JDK version before execution
- Captures HTML/JSON report from HA.zip framework
- Parses using JAXB/JSON libraries already bundled

**Mode 3 — Concurrent Program (FNDLOAD)**
- Agent can install analyzer as EBS Concurrent Program using LDT templates
- Submits concurrent request via Oracle API
- Polls for completion and retrieves output file

---

## 5. User Personas

### Persona 1: EBS Support Engineer (Primary)
- **Role**: Oracle Support or customer IT support
- **EBS Knowledge**: Intermediate — knows module workflows, not deep DBA
- **Goal**: Diagnose a reported user issue quickly, produce a remediation plan
- **Interaction**: Conversational — describes the problem in natural language
- **Key Need**: Agent interprets results and explains what they mean

### Persona 2: EBS DBA / System Administrator
- **Role**: Maintains EBS database and application tier
- **EBS Knowledge**: Deep technical — knows schema, concurrent processing, patching
- **Goal**: Proactive health checks, pre-upgrade validation, performance diagnostics
- **Interaction**: Command-oriented — may specify which analyzer to run
- **Key Need**: Full raw output access plus structured summary; autonomous scheduled runs

### Persona 3: Functional Consultant
- **Role**: Implements or configures EBS modules (AP, AR, OM, HR, etc.)
- **EBS Knowledge**: Deep functional — knows setups, not database internals
- **Goal**: Validate module configuration, troubleshoot setup issues
- **Interaction**: Conversational, functional language ("Tax lines aren't calculating")
- **Key Need**: Findings explained in business terms, not technical SQL output

### Persona 4: Audit / Compliance Officer
- **Role**: Reviews EBS security, audit trail, and compliance
- **EBS Knowledge**: Functional, compliance-focused
- **Goal**: Generate compliance reports, review security configurations
- **Interaction**: Report-request oriented
- **Key Need**: Structured compliance reports, exportable evidence

---

## 6. Module Agent Specifications

---

### 6.1 Orchestrator / Router Agent

#### Purpose
The Orchestrator is the system entry point. It receives all user requests, classifies intent, determines which module agent(s) to engage, manages the execution DAG, collects findings, resolves cross-module dependencies, and produces the final incident report.

#### Responsibilities

**Intent Classification**
- Parses natural language to identify:
  - EBS module(s) involved (AP, AR, GL, INV, HR, etc.)
  - Problem type (performance, data integrity, configuration, period close, security, upgrade)
  - Urgency level (critical production down / high / medium / informational)
  - Scope (single transaction, batch, module-wide, system-wide)
- Maintains a classification taxonomy aligned to the 378 analyzer categories

**Workflow Planning**
- Generates a WorkflowPlan DAG specifying:
  - Which module agents to invoke
  - Execution order (parallel where safe, sequential where dependent)
  - Which analyzers within each module to run
  - Dependency chain (e.g., SLA setup must run before AP accounting)
- Plans adapt dynamically — if an upstream finding indicates a root cause, downstream checks may be skipped or reprioritized

**Context Management**
- Maintains full session context across conversation turns
- Tracks: EBS instance details, EBS version (11i / 12.0 / 12.1 / 12.2), installed products, prior findings in session
- Stores context in Session Store with TTL of 8 hours (configurable)

**Cross-Module Correlation**
- After all module agents return, identifies cross-module patterns:
  - Example: GL period closed → AP cannot post → AP trial balance mismatches
  - Example: TCA data corruption → AR autoinvoice failures → revenue recognition gaps
  - Example: Concurrent processing manager down → affects ALL modules
- Produces a single unified finding list, deduplicated, prioritized

**Incident Report Generation**
- Generates structured report with sections:
  - Executive Summary (business impact)
  - Critical Findings (severity: CRITICAL / HIGH / MEDIUM / LOW / INFO)
  - Per-module detail with raw evidence
  - MOS Note references and patch recommendations
  - Remediation Plan (prioritized step-by-step, with auto-fix flags)
  - Audit Trail (what ran, when, duration, raw output links)
- Output formats: Markdown, HTML, PDF, JSON (for MOS/ticketing integration)

#### Tools Available to Orchestrator
- `classify_intent(user_message)` → IntentClassification
- `plan_workflow(intent, ebs_instance)` → WorkflowPlan DAG
- `invoke_module_agent(agent_id, task)` → AnalysisFinding[]
- `correlate_findings(findings[])` → CorrelatedInsight[]
- `generate_report(findings, session)` → IncidentReport
- `search_mos(keywords, error_codes)` → MOSNote[]
- `get_ebs_version(instance)` → EBSVersion
- `get_installed_products(instance)` → ProductList
- `store_session(session)` / `load_session(session_id)`

#### Routing Logic

```
User: "AP invoices are stuck in validation for 2 days"
  → Intent: AP validation failure, high urgency
  → Module agents: ATG (check CP managers), FIN/AP (run ap_accounting_analyzer, ap_inv_tax_analyzer, ap_period_close_analyzer)
  → Dependencies: ATG must complete first (CP manager health gates AP concurrent job analysis)
  → Parallel: ap_accounting + ap_inv_tax can run simultaneously
  → Sequential: ap_period_close after ap_accounting (period status affects posting)

User: "Prepare for month-end close"
  → Intent: Period close validation, medium urgency, multi-module
  → Module agents: FIN/AP, FIN/AR, FIN/GL, FIN/FA, MFG/CST (cost period close), ATG (CP managers)
  → All period-close analyzers run in parallel per module
  → Orchestrator synthesizes cross-ledger period status
```

---

### 6.2 ATG Core Agent

#### Purpose
Diagnoses foundational Oracle EBS infrastructure issues that affect all other modules. ATG issues are system-wide multipliers — a failed concurrent manager or broken SSO affects every user and every process. This agent runs first in most multi-module scenarios.

#### Sub-Domains & Analyzer Mapping

**6.2.1 Concurrent Processing Sub-Agent**

*Analyzer*: `cp_analyzer.sql` / `cp_analyze.sql`, `CPAZ.ldt` / `CPAZ_11i.ldt`

*Features*:
- **Manager Health Check**: Detect all concurrent managers — status (active/inactive/deactivated), last heartbeat, worker count, specialization rules
- **Stuck Request Detection**: Identify requests in PENDING/RUNNING state beyond configurable threshold (default: 2x average runtime for that program)
- **Manager Conflict Detection**: Find scheduling conflicts — programs assigned to wrong managers, managers with conflicting specialization rules
- **Throughput Analysis**: Compare request queue depth vs. worker capacity; flag bottlenecks
- **Failed Request Analysis**: Analyze last N failed requests — error categorization, frequency, affected users
- **ICM (Internal Concurrent Manager) Health**: Verify ICM is active, ping response time within bounds
- **Request Group Validation**: Ensure all analyzer programs are in correct request groups
- **Log Analysis**: Parse concurrent manager logs for ORA- errors, Java exceptions, connection failures
- **Remediation Actions (auto-fixable)**:
  - Restart stuck managers via EBS API
  - Clear orphaned lock rows in FND_CONCURRENT_REQUESTS
  - Requeue failed requests

*Agent Behavior*:
```
On invocation:
1. Run cp_analyzer.sql → parse manager status grid
2. Flag any manager with status != 'A' (Active) as CRITICAL
3. Identify requests where PHASE='R' and ACTUAL_START_DATE < SYSDATE - (avg_runtime * 2)
4. Cross-reference with ICM heartbeat timestamp
5. If ICM down → escalate to CRITICAL, halt further ATG sub-agent analysis (all others are downstream)
6. Return AnalysisFinding[] with severity classifications
```

**6.2.2 BI Publisher (BIP) Sub-Agent**

*Analyzer*: `bip_analyzer.sql` / `bip_analyze.sql`, `bip_enterprise_analyzer.xml`, `BIPAZ.ldt`

*Features*:
- **BIP Server Connectivity**: Validate connection between EBS concurrent tier and BI Publisher server
- **Report Template Validation**: Detect missing or corrupt report templates in XDO_LOBS
- **Data Source Configuration**: Verify JDBC data sources are correctly configured in BIP
- **Output Post-Processing**: Check FND_CONC_PP_ACTIONS for delivery channels (email, FTP, printer) — validate active channels
- **Bursting Definition Validation**: Detect malformed bursting control files
- **License Check**: Ensure BIP is licensed for the installed EBS modules
- **Performance**: Identify long-running BIP reports; recommend template optimization
- **Security**: Validate BIP roles align with EBS responsibility-based security

**6.2.3 Workflow Mailer Sub-Agent**

*Analyzer*: `wf_mailer_analyzer.xml`, `workflow_analyzer.sql`

*Features*:
- **Mailer Service Status**: Confirm WF_MAILER agent is active in the workflow agent framework
- **Email Queue Analysis**: Count MAIL_STATUS='MAIL' messages in WF_NOTIFICATIONS beyond SLA threshold
- **IMAP/SMTP Configuration Validation**: Parse mailer parameters for host, port, SSL settings
- **Bounce Detection**: Identify high bounce rates from outbound notifications
- **Deferred Activity Analysis**: Detect workflow activities stuck in DEFERRED status
- **Purge Recommendations**: Identify WF_ITEMS eligible for purge to improve performance
- **Background Engine Status**: Verify WF_DEFERRED queue is being processed

**6.2.4 Security & Audit Sub-Agent**

*Analyzer*: `fnd_sec_analyzer.xml`, `auditing_analyzer.xml`, `fnd_login_analyzer.xml`

*Features*:
- **User Account Health**: Detect locked accounts, password expiry violations, inactive users with active responsibilities
- **Responsibility Assignment Audit**: Identify overly broad responsibility assignments; flag SYSADMIN-equivalent grants to non-admin users
- **Profile Option Validation**: Validate security-critical profile options (password complexity, session timeout, guest access)
- **Audit Trail Status**: Verify AuditTrail is enabled for configured audit groups; detect gaps
- **Login Anomaly Detection**: Identify failed login patterns, unusual access times, new IP ranges
- **RBAC/UMX Configuration**: Validate User Management Framework (UMX) roles
- **Data-Level Security**: Check row-level security (VPD policies) on sensitive tables
- **Segregation of Duties**: Flag users who hold conflicting responsibilities (e.g., AP invoice entry + AP payment approval)

**6.2.5 Flexfields Sub-Agent**

*Analyzer*: `fnd_flexfields_analyzer.xml`

*Features*:
- **Key Flexfield (KFF) Validation**: Verify structure, segment, value set configurations for: Chart of Accounts (GL), System Items (INV), Asset Key (FA), Account Generator (PO/AP)
- **Descriptive Flexfield (DFF) Audit**: Detect DFFs with invalid context values, orphaned attributes
- **Value Set Integrity**: Find value sets with invalid parent hierarchies, missing independent values
- **Cross-Validation Rules**: Verify CVRs are correctly defined and not blocking valid accounting combinations
- **Freeze Status**: Detect uncompiled/unfrozen flexfield structures blocking transactions
- **Segment Ordering**: Validate segment order hasn't been changed post go-live (causes account mismatches)

**6.2.6 Performance Sub-Agent**

*Analyzer*: `fndperf_analyzer.xml`

*Features*:
- **Top-N Slow SQL**: Identify top SQL statements by elapsed time from V$SQL (EBS-context queries)
- **Connection Pool Analysis**: Monitor JDBC pool saturation, connection leak detection
- **SGA/PGA Utilization**: Validate memory allocation relative to workload
- **Wait Event Classification**: Top wait events categorized as I/O, network, latch, application
- **Object Statistics Staleness**: Identify tables/indexes with stale optimizer statistics
- **Invalid Objects**: Detect invalid PL/SQL packages, views, triggers in APPS schema
- **Index Effectiveness**: Identify full table scans on large FND/AP/AR tables
- **Auto-Remediation**: Submit gather-statistics concurrent request, recompile invalid objects

**6.2.7 OA Framework & Forms Sub-Agent**

*Analyzers*: `oa_fwk_analyzer.xml`, `oa_forms_analyzer.xml`

*Features*:
- **OAF Patch Level**: Validate OAF patch level against certified release for EBS version
- **Personalization Conflicts**: Detect OAF personalizations conflicting with base product
- **Forms Configuration**: Validate Oracle Forms server settings (FORMS_TIMEOUT, MAX_OPEN_CURSORS)
- **JVM Configuration**: Validate JVM heap settings for OAF application server nodes
- **Cache Configuration**: WebLogic cache settings for OAF page rendering performance
- **WebLogic Managed Server Health**: Status of all WLS managed servers (AdminServer, oacore, forms, etc.)

**6.2.8 SSO & TLS Sub-Agent**

*Analyzers*: `sso_ebs_analyzer.xml`, `tls_analyzer.xml`

*Features*:
- **SSO Integration Validation**: Verify Oracle SSO (OAM/OIDDAS) connection from EBS
- **Certificate Expiry Monitoring**: Alert on SSL/TLS certificates expiring within 30/14/7 days
- **TLS Protocol Compliance**: Verify TLS 1.2+ only; flag TLS 1.0/1.1 or SSL 3.0 configurations
- **Cipher Suite Audit**: Verify only approved cipher suites are configured
- **EBS-SSO Trust Store**: Validate trust chain for EBS-to-SSO certificate exchange
- **Login Page Accessibility**: Test EBS login page response with certificate validation

**6.2.9 Clone & Upgrade Sub-Agent**

*Analyzers*: `ebs_clone_analyzer.xml`, `atg_upgrade_analyzer.xml`

*Features*:
- **Post-Clone Validation**: After EBS clone, verify: context file regeneration, autoconfig completion, all services pointing to new hostname, printer definitions updated, workflow mailer reconfigured
- **Pre-Upgrade Readiness**: Check all pre-requisites for target EBS version upgrade
- **ADOP (Online Patching) Status**: For R12.2, validate patch edition status, cleanup completion, cutover readiness
- **Database Compatibility**: Validate Oracle DB version compatibility with target EBS version (e.g., 19c support matrix)
- **Customization Impact**: Identify CUSTOM schema objects that may conflict with upgrade

**6.2.10 NLS & Monitoring Sub-Agents**

*Analyzers*: `ebs_nls_analyzer.sql`, `mon_analyzer.sql`

*NLS Features*:
- Validate NLS_CHARACTERSET vs. data stored in CLOB/VARCHAR2 columns
- Detect character set conversion issues in translation tables
- Verify NLS_LANG settings in concurrent manager environment

*Monitoring Features*:
- Real-time concurrent manager queue depth
- Application server response time trends
- Database alert log monitoring for ORA- errors
- Tablespace utilization (APPS, APPLSYS schemas)
- Alert threshold configuration per metric

**6.2.11 XML Gateway / EDI Sub-Agent**

*Analyzer*: `xml_gateway_analyzer.xml`

*Features*:
- **Trading Partner Setup**: Validate XML Gateway trading partner configurations
- **Document Queue Health**: Monitor inbound/outbound XML document queues for stuck messages
- **ECX Event Subscription**: Verify business event subscriptions for order/invoice XML flows
- **Transformation Maps**: Validate XSLT transformation maps are deployed
- **Connection Testing**: Test connectivity to external trading partner endpoints

---

### 6.3 Financials Agent

#### Purpose
The Financials Agent covers all Oracle Financials modules. It is the most complex agent, managing sub-agents for AP, AR, GL, FA, Cash Management, Projects, Tax, and regional variants. Financial data integrity and period close are primary concerns.

#### Sub-Agents

**6.3.1 Accounts Payable (AP) Sub-Agent**

*Analyzers*: `ap_accounting_analyzer.sql`, `ap_gdf_detect_analyzer.sql`, `ap_inv_tax_analyzer.sql`, `ap_oie_analyzer.sql`, `ap_period_close_analyzer.sql`, `ap_sup_analyzer.sql`, `ap_trial_balance_analyzer.sql`, `ap_xtr_analyzer.sql`

*Features*:

**Invoice Validation Analysis**
- Detect invoices stuck in NEEDS REVALIDATION or VALIDATION ERROR status
- Categorize validation failures: tax errors, hold types (VENDOR HOLD, AMOUNT MISMATCH, PRICE HOLD, QTY HOLD, etc.)
- Identify distribution-level errors vs. header-level errors
- Correlate with PO matching issues (price tolerance violations, quantity mismatches)
- Auto-generate SQL to list all on-hold invoices with hold reasons and aging

**AP Accounting & Subledger (SLA) Validation**
- Detect unaccounted AP transactions (invoices, payments, prepayments)
- Validate AP Accounting Events in XLA_EVENTS have corresponding XLA_AE_HEADERS
- Find orphaned accounting events (event exists, no journal entry)
- Detect invalid accounting combinations used in AP distributions
- Validate AP to GL reconciliation: AP trial balance vs. GL 2000 account balance
- Identify invoices posted to closed GL periods

**Supplier Configuration Analysis**
- Detect duplicate supplier sites (same address, different site codes)
- Identify suppliers with missing required fields (Tax ID, Payment Terms)
- Validate payment method assignments (bank accounts, payment formats)
- Flag inactive suppliers with open invoices
- Detect 1099 reporting setup issues (US-specific)

**Period Close Readiness**
- Run `ap_period_close_analyzer.sql` to identify all blockers:
  - Unposted invoices in the period
  - Unposted payments
  - Payment batches not confirmed
  - Unprocessed clearing transactions
  - Funds check failures preventing posting
- Generate period close checklist with status for each item
- Estimate time to close based on outstanding volume

**Payment Processing Analysis**
- Identify payment batches in intermediate states (SELECTING, BUILDING, FORMATTING, CONFIRMING)
- Detect payments that failed Electronic Fund Transfer (EFT) formatting
- Validate bank account configurations (routing numbers, account formats)
- IBY (Oracle Payments) configuration validation

**AP Tax Analysis**
- Validate EB Tax (E-Business Tax) configuration for AP transactions
- Detect invoices with missing or incorrect tax lines
- Validate tax jurisdiction assignments on supplier sites
- Check for tax recovery rule configuration issues (partially recoverable tax)
- India GST-specific: Validate GSTIN assignments, HSN/SAC codes

**Trial Balance Validation**
- Detect invoices on AP trial balance that are fully paid (outstanding amount should be zero)
- Identify negative invoice amounts causing trial balance anomalies
- Validate AP trial balance against GL AP liability accounts
- Detect multi-currency rounding issues in trial balance

**Treasury Integration (XTR)**
- Validate AP-to-Treasury (Oracle Treasury) integration setup
- Detect intercompany treasury transactions not reconciled

**Agent Behavior for AP Period Close Request**:
```
1. Run ap_period_close_analyzer.sql
2. Parse output sections:
   - Open Invoice Count & Amount
   - Unposted Invoice Count & Amount
   - Unconfirmed Payment Batches
   - Clearing Account Balance
3. For each blocking item, determine if auto-resolvable:
   - Unposted invoices with valid accounting → trigger posting concurrent request
   - Unconfirmed payment batches → flag for manual review (requires human approval)
4. Generate Close Readiness Report: % complete, estimated completion time
5. Alert if any item will miss close deadline based on volume vs. processing rate
```

**6.3.2 Accounts Receivable (AR) Sub-Agent**

*Analyzers*: `ar_adj_analyzer.sql`, `ar_autoinvoice_analyzer.sql`, `ar_docseq_analyzer.sql`, `ar_groupingrules_analyzer.sql`, `ar_lockbox_analyzer.sql`, `ar_net_analyzer.sql`, `ar_periodclose_analyzer.sql`, `ar_rct_analyzer.sql`, `ar_recon_analyzer.sql`, `ar_tca_analyzer.sql`, `ar_trx_analyzer.sql`, `ar_trx_feat_analyzer.sql`

*Features*:

**AutoInvoice Analysis**
- Detect AutoInvoice exceptions in RA_INTERFACE_ERRORS
- Categorize errors: invalid customer, invalid transaction type, invalid revenue account, missing required fields, tax calculation failure
- Validate AutoInvoice grouping rules — detect rule misconfigurations causing transactions to merge incorrectly
- Check AutoInvoice concurrent program parameters (batch_source, transaction_date range)
- Identify transactions stuck in RA_INTERFACE_LINES_ALL for > threshold duration
- Generate corrective SQL for common AutoInvoice rejections

**Receipt & Lockbox Analysis**
- Validate lockbox transmission files — detect format errors, invalid bank account references
- Identify unapplied receipts aging beyond threshold
- Detect receipts applied to wrong invoices (amount mismatch with remittance advice)
- Lockbox processing concurrent job status
- Cash clearing account reconciliation
- Detect receipts in UNCONFIRMED or ON-ACCOUNT status requiring review

**AR Transaction Analysis**
- Detect credit memos with missing corresponding invoices
- Identify transactions with invalid accounting distributions
- Validate revenue recognition schedules (deferred revenue rules)
- Detect transactions with out-of-balance distributions (DR ≠ CR)
- Multi-currency translation validation

**AR Adjustments Analysis**
- Validate adjustment approval limits vs. amounts being adjusted
- Detect unauthorized adjustments (amount > approver limit)
- Identify write-offs exceeding policy thresholds
- Audit adjustment reason codes for completeness

**Period Close Readiness**
- Unposted AR transactions in current period
- Open credit memos not applied
- Unresolved receipt exceptions
- Incomplete revenue recognition schedules
- Intercompany AR not reconciled to AP
- Generate AR close checklist with item-level status

**TCA (Trading Community Architecture) Analysis**
- Detect duplicate customer parties (same name/tax ID, different party IDs)
- Validate customer account site-level addresses
- Identify customers missing required attributes (Tax Registration Number for tax calc)
- Validate party merge completion — detect partial merge states
- Credit profile validation

**Document Sequence Analysis**
- Validate document sequences are assigned to all AR transaction types in all operating units
- Detect gaps in document sequences (skipped sequence numbers)
- Identify transactions with NULL document sequence numbers (compliance risk)

**AR Reconciliation**
- AR subledger-to-GL reconciliation: RA_CUST_TRX_LINE_GL_DIST vs. GL journal entries
- Detect journals imported from AR that have been manually modified in GL
- Identify accounting periods open in AR but closed in GL (blocking AR posting)

**6.3.3 General Ledger (GL) Sub-Agent**

*Analyzer*: `gl_hc_analyzer.sql`

*Features*:

**Journal Entry Analysis**
- Detect unposted journals by source, category, and period
- Identify journals with invalid account combinations (disabled segments, invalid CVR combinations)
- Detect out-of-balance journals (total debits ≠ total credits — though EBS prevents this, detect if manual DB edits occurred)
- Validate intercompany journals are balanced across balancing segments
- Detect journals in error status from subledger import

**Period Management**
- Show period status grid: all ledgers × all periods × status (Open/Closed/Never Opened/Permanently Closed)
- Alert on periods open beyond configured maximum
- Identify periods closed in subledgers but still open in GL (blocking close)
- Validate consolidation ledger period alignment with source ledgers
- Pre-close checklist: all subledger journals transferred and posted

**Account Combination Analysis**
- Detect disabled account combinations still used in transactions
- Identify account combinations with mismatched cost center/natural account assignments
- Validate parent/child hierarchy consistency in summary accounts
- Detect orphaned summary account template definitions

**Financial Reporting**
- Validate FSG (Financial Statement Generator) report sets
- Detect row/column sets with invalid account ranges
- Historical correction analysis for prior-period adjustments

**Intercompany**
- Validate AGIS (Advanced Global Intercompany System) configuration
- Detect intercompany invoices not matched across legal entities
- Validate intercompany elimination journal generation

**6.3.4 Fixed Assets (FA) Sub-Agent**

*Analyzer*: `fa_analyzer.sql`, `FAANALYZERAZ.ldt`

*Features*:

**Asset Book Configuration**
- Validate corporate and tax book setup (fiscal year, calendar, prorate convention)
- Verify depreciation method assignments per asset category
- Detect assets with missing category assignments
- Validate asset addition controls (capitalization threshold, default life)

**Depreciation Analysis**
- Identify assets where depreciation has not run for the current period
- Detect assets with zero accumulated depreciation (possible setup error)
- Find assets fully depreciated but still on the active register
- Validate bonus depreciation rules (US MACRS, ACRS)
- Detect assets with negative depreciation amounts

**Asset Transactions**
- Identify incomplete asset additions (IN PROGRESS status)
- Detect transfers not fully processed
- Identify retirements with pending gain/loss calculations
- Mass additions queue: CIP assets not capitalized within threshold
- Mass changes not completed

**Reconciliation**
- FA Net Book Value vs. GL asset/accumulated depreciation accounts
- Detect manual GL journals posted to FA accounts (bypassing subledger)
- CIP account balance vs. CIP assets in FA (capital project reconciliation)

**EMEA / Global Additions**
- `cle_emea_addon_analyzer.sql` — Legal entity configuration for EMEA
- `fin_emea_analyzer.sql` — EMEA financial setup validation

**6.3.5 Cash Management (CE) Sub-Agent**

*Analyzer*: `ce_transaction_analyzer.sql`, `CETRXNAZ.ldt`

*Features*:

**Bank Statement Reconciliation**
- Detect bank statement lines not reconciled beyond threshold days
- Identify auto-reconciliation failures and failure reasons
- Validate bank account setups (bank, branch, account currency matching)
- Detect duplicate statement imports

**Clearing Account Analysis**
- AP payment clearing: payments cleared in bank but not matched in CE
- AR receipt clearing: receipts deposited but not cleared
- Payroll clearing account reconciliation
- Intercompany clearing

**Cashflow Forecasting**
- Validate cashflow forecast source definitions
- Detect forecast rows with invalid GL accounts

**6.3.6 Projects (PA) Sub-Agent**

*Analyzers*: `pa_pjb_analyzer.sql`, `pa_pjc_capital_analyzer.sql`, `pa_pjc_expend_analyzer.sql`, `pa_pjc_fc_analyzer.sql`, `pa_pjc_p2p_analyzer.sql`, `pa_pjf_foundation_analyzer.sql`, `pa_workplan_analyzer.sql`, `gms_award_analyzer.sql`

*Features*:

**Project Foundation**
- Validate project type, class, status configurations
- Detect projects with invalid/expired task structures
- Verify project organization assignments
- Resource breakdown structure validation

**Project Costing (PJC)**
- Detect expenditure items stuck in DISTRIBUTE status
- Identify cost transactions not transferred to GL
- Validate burden schedule configurations (indirect cost rates)
- Capital project: detect CIP assets not transferred to Fixed Assets
- P2P (Procure-to-Pay for Projects): validate PO commitments flowing to project budget

**Project Billing (PJB)**
- Detect unbilled events past billing cycle date
- Validate billing schedules and milestones
- Identify invoices in DRAFT status not submitted for approval
- Revenue recognition: detect unrecognized revenue for completed milestones
- Contract billing: validate funding amounts vs. revenue recognized

**Grants Management (GMS)**
- Award setup validation: sponsor, budget, period of performance
- Compliance: expenditure category restrictions, allowable cost rules
- Award closeout checklist
- Detect overspent awards (actual > approved budget)

**Forecasting & Fund Control**
- Budget baseline validation
- Fund check configuration (HARD vs. SOFT limits)
- Detect transactions failing funds check (held transactions)

**6.3.7 SLA (Subledger Accounting) Sub-Agent**

*Analyzer*: `sla_setup_analyzer.sql`

*Features*:
- Validate accounting method assignments for all subledgers
- Detect journal entry rule sets with incomplete line definitions
- Validate account derivation rules (ADRs) — source conditions, account derivation logic
- Detect subledger journal entries in ERROR status
- Validate application accounting definitions (AADs) are complete and active
- Detect conflicts between custom and seeded AADs

**6.3.8 Tax Sub-Agents**

*Analyzers*: `o2c_ebtax_analyzer.sql`, `jl_latin_tax_analyzer.sql`, `il_gst_analyzer.sql`, `gst_pc_analyzer.sql`, `ap_inv_tax_analyzer.sql`, `ar_autoinvoice_analyzer.sql`

*EB Tax (Global) Features*:
- Validate tax regime-to-rate configuration completeness
- Detect products/services with missing fiscal classifications
- Validate tax jurisdiction assignments for customer/supplier locations
- Detect tax determination failures and their root causes (missing party classification, regime applicability)
- Tax period close: validate tax returns, reporting codes

*India GST Features*:
- GSTIN validation for all suppliers/customers
- HSN/SAC code assignment completeness
- Input Tax Credit (ITC) eligibility validation
- E-invoice configuration validation (IRN generation)
- GST period close checklist

*Latin America Tax Features*:
- Validate CNPJ/CPF registration for Brazilian entities
- Validate fiscal attributes for NF-e (Nota Fiscal Eletrônica)
- Withholding tax configuration for Argentina/Colombia

**6.3.9 Additional Financials Sub-Agents**

**Collections (IEX)**
*Analyzer*: `iex_analyzer.sql`
- Detect delinquency scoring configuration issues
- Validate dunning plan setup
- Identify customers with broken dunning history

**Lease Management (LNS)**
*Analyzer*: `lns_analyzer.sql`
- Validate loan/lease product setup
- Detect amortization schedule anomalies
- Interest accrual period analysis

**PSA (Public Sector / Budgetary Control)**
*Analyzer*: `psa_data_analyzer.sql`
- Validate encumbrance accounting setup
- Detect budget vs. actual reconciliation issues
- Year-end closing process validation

**BNE (Browser-Based ADI / Web ADI)**
*Analyzer*: `bne_analyzer.xml`
- Validate Web ADI integrator configurations
- Detect data upload template errors
- Validate content/layout/mapping setup

**IBY (Oracle Payments)**
*Analyzer*: `iby_fd_analyzer.sql`
- Payment format template validation
- Payment system connectivity testing
- Positive pay configuration

---

### 6.4 Manufacturing Agent

#### Purpose
Diagnoses Oracle Manufacturing, Supply Chain, Inventory, Order Management, Procurement, and Costing issues. Manufacturing processes are highly interdependent — BOM errors affect costing; inventory inaccuracies affect order promising; PO receipt errors affect accounts payable.

#### Sub-Agents

**6.4.1 Inventory (INV) Sub-Agent**

*Analyzers*: `invitem_analyzer.sql`, `invcount_analyzer.sql`, `invt_az_analyzer.sql`, `inv_ici_analyzer.sql`

*Features*:

**Item Master Analysis**
- Detect items with incomplete attribute assignments for enabled organizations
- Validate item template assignments
- Identify items with conflicting Make/Buy attributes
- Detect items with unit of measure (UOM) conversion errors
- Validate item category assignments (all items must be in all required category sets)
- Serial/lot control attribute validation
- Costing-enabled items without cost records
- Detect duplicate item numbers across operating units (cross-reference validation)

**Inventory Count Analysis**
- Cycle count: Detect counts scheduled but not performed within adjustment period
- Physical inventory: Detect pending adjustments not approved/posted
- Count tags not reconciled
- Adjustment approval workflow stuck
- Negative inventory detection (if not allowed by org parameters)
- Lot/serial number traceability gaps

**Intercompany Inventory (ICI)**
- Detect intercompany shipments not received by receiving organization
- In-transit quantity reconciliation across intercompany organizations
- Validate intercompany transaction flow definitions
- AR/AP intercompany account reconciliation for inventory transfers

**Organization & Subinventory Setup**
- Validate organization parameters completeness
- Subinventory locator controls
- Receiving controls (3-way vs. 2-way match configuration)

**6.4.2 Bill of Materials (BOM) Sub-Agent**

*Analyzer*: `bom_analyzer.sql`

*Features*:
- **BOM Structure Validation**: Detect circular BOM references (item A includes item B which includes item A)
- **Component Effectivity**: Find components with past effectivity dates still marked active
- **Engineering Change Orders (ECO)**: Detect ECOs approved but not implemented; detect partial implementation
- **Routing Analysis**: Validate routing operations — detect operations referencing inactive resources or departments
- **Phantom Assembly Detection**: Validate phantom items are correctly configured in BOM
- **Configuration Rules**: Validate model/option class/option BOM structure for configured items
- **Lead Time Validation**: Detect negative lead times; items with zero lead time receiving planned orders
- **Costed BOM**: Validate all BOM components have current standard costs (for standard cost organizations)

**6.4.3 Order Management (OM) Sub-Agent**

*Analyzers*: `om_analyzer.sql`, `om_flow_factory_analyzer.sql`

*Features*:

**Order Line Status Analysis**
- Detect orders stuck in workflow activity (ENTERED, BOOKED, AWAITING_SHIPPING, etc.)
- Identify orders on hold — categorize hold types (credit check, payment, manual, scheduling)
- Detect orders with past scheduled ship dates not shipped
- ATP (Available-to-Promise) failures — orders that cannot be promised
- Back-order analysis: volume, aging, top items

**Order Booking Analysis**
- Validate order type configurations — workflow assignment, line type mapping
- Detect orders in ENTERED status for > threshold (not booked — possible UI error)
- Price list validation: detect orders with manual overrides outside approval limits
- Detect orders with unresolved pricing holds

**Shipping Analysis**
- Trip/stop not closed — shipments in OPEN status beyond transit time
- Delivery not interfaced to AR after ship-confirm
- Ship confirm errors — detect interface exceptions in WSH_EXCEPTIONS
- Freight cost setup validation

**Returns (RMA) Analysis**
- RMA receipts not processed through receiving
- Credit memo not generated for completed returns
- Return authorization validity (expired RMAs with pending material)

**Flow Manufacturing**
- Flow line balance validation
- Mixed-model production sequence anomalies

**6.4.4 Procurement (PO) Sub-Agent**

*Analyzer*: `po_analyzer.sql`

*Features*:

**Purchase Order Analysis**
- Detect POs with all lines cancelled but header still OPEN (should be FINALLY CLOSED)
- Identify POs where received quantity > ordered quantity (over-receipt)
- PO lines with no receipts past expected receipt date
- Blanket purchase agreements: utilization vs. limit; expiring agreements
- Global blanket: cross-OU release validation

**Receiving Analysis**
- Receiving transactions not processed (interface errors in RCV_TRANSACTIONS_INTERFACE)
- 3-way match failures: PO price vs. invoice price beyond tolerance
- Receiving corrections (returns to vendor) with pending AP debit memos
- Inspection required items not inspected

**Requisition Analysis**
- Requisitions in PENDING APPROVAL > threshold days
- Auto-sourcing rules: detect requisitions not converting to POs due to rule failures
- Internal requisitions: inventory sourcing failures, ISO (Internal Sales Order) not created
- Document approval hierarchy: detect missing approvers

**Supplier Portal**
- Supplier self-service registration completeness
- Pending supplier registration approvals

**6.4.5 Costing (CST) Sub-Agent**

*Analyzers*: `cst_reconciliation_analyzer.sql`, `ocm_analyzer.sql`, `CSTPERIODCLOSEAZ.ldt`

*Features*:

**Cost Period Close Analysis**
- Detect pending cost transactions not processed before period close
- Work-in-process (WIP) jobs not closed before cost period close
- Inventory valuation reconciliation: perpetual inventory value vs. GL inventory account
- Standard cost update impact analysis: variance distribution completeness
- Average cost update: detect transactions in process during cost update (concurrency issues)

**WIP (Work-in-Process) Analysis**
- Detect jobs with no activity for > threshold (potentially abandoned)
- Jobs with negative component quantities
- Resource transactions missing cost information
- Scrap transactions not costed
- OSP (Outside Processing): PO receipts for OSP operations not flowing to WIP

**Cost Reconciliation**
- Inventory to GL reconciliation: COGS account balance vs. actual cost of goods sold
- Material overhead variance analysis
- Resource efficiency variance analysis
- Purchase price variance analysis (PPV)

**6.4.6 Supply Chain Planning (ASCP/MSC) Sub-Agent**

*Analyzers*: `ascp_perf_analyzer.sql`, `msc_caca_sqlaz_analyzer.sql`, `msc_dpa_sqlaz_analyzer.sql`

*Features*:

**Planning Data Collection**
- Detect data collection failures between operational EBS and ASCP planning server
- Validate sourcing rules and bills of distribution
- Detect items excluded from planning (should be planned)
- Supply/demand netting accuracy validation

**Plan Performance Analysis**
- Planning engine performance: elapsed time vs. benchmarks for plan size
- Detect plans with stale data (collection not run before plan launch)
- Exception messages analysis: TOP-N exceptions by volume and severity
- Detect circular sourcing rules

**Demand Planning (MSC)**
- Forecast consumption validation
- Demand history collection errors
- Statistical forecast accuracy metrics

**6.4.7 Enterprise Asset Management (EAM) Sub-Agent**

*Features*:
- Maintenance work order lifecycle analysis
- PM (Preventive Maintenance) schedule compliance
- Asset downtime tracking and mean-time-to-repair analysis
- Maintenance cost accounting setup validation

---

### 6.5 Human Capital Management (HCM) Agent

#### Purpose
Diagnoses Oracle HCM modules — HR, Payroll, Benefits, and related components. HCM issues often have regulatory compliance implications (payroll accuracy, benefits compliance, labor law).

#### Sub-Agents

**6.5.1 Core HR Sub-Agent**

*Analyzer*: `hr_technical_analyzer.sql`

*Features*:

**Employee Record Integrity**
- Detect person records with invalid date tracks (future-dated terminations with active assignments)
- Identify terminated employees with active payroll assignments
- Detect duplicate person records (same name/SSN)
- Assignment grade/step validation
- Position hierarchy integrity check (circular reporting relationships)
- GRE (Government Reporting Entity) assignment completeness

**Organization Structure**
- Validate HR organization hierarchy completeness
- Detect business groups with missing required setup (legislation code, currency)
- Location setup validation (tax authority assignments)
- Job/Position structure completeness

**Security Profile**
- HR Security Profile configuration validation
- Detect users who can access employee records outside their security scope
- Organization security profile hierarchy integrity

**6.5.2 Payroll Sub-Agent**

*Features*:

**Payroll Process Status**
- Detect payrolls in PROCESSING state > threshold (hung payroll runs)
- Validate QuickPay and regular payroll run sequence (locking dates)
- Detect assignments with zero net pay (possible setup error)
- Detect reversal requests pending past payroll processing deadline
- Costing run completion validation
- Pre-payment process status (before EFT/check generation)

**Element Configuration**
- Detect elements with missing input values
- Validate formula associations (FastFormula compilation status)
- Detect balance feeds with incorrect classification (plus/minus)
- Retroactive pay: detect retropay events not processed

**Tax Configuration (US-specific)**
- Validate federal/state/local tax rule assignments
- W-2 reporting setup validation
- New hire reporting configuration

**6.5.3 Benefits (BEN) Sub-Agent**

*Analyzer*: `ben_analyzer.sql`

*Features*:
- **Life Event Processing**: Detect participants with open life events not processed within enrollment deadline
- **Plan Configuration**: Validate plan year, eligibility criteria, coverage formulas
- **ACA (Affordable Care Act) Compliance**: Detect employees who were offered coverage but not enrolled within measurement period
- **Enrollment Confirmation**: Detect elections made but benefit plan coverages not activated
- **COBRA Administration**: Detect qualifying events not triggering COBRA notifications
- **Carrier Interface**: Detect benefits carrier file generation errors

**6.5.4 Time & Labor (OTL) Sub-Agent**

*Features*:
- Time card approval workflow stuck
- Detect time cards not transferred to payroll
- Absence accrual balance calculation errors
- Shift differential rule validation

**6.5.5 Appraisals & Performance Sub-Agent**

*Analyzer*: `ptu_analyzer.sql` (PTU — Personal Time Units)

*Features*:
- Detect performance plans with overdue ratings
- Appraisal period configuration validation
- Competency model completeness

---

### 6.6 CRM Agent

#### Purpose
Diagnoses Oracle CRM Suite — Customer Service, Field Service, Depot Repair, Collections, and Marketing. CRM issues directly impact customer-facing service levels.

#### Sub-Agents

**6.6.1 Customer Service (CS/CSD) Sub-Agent**

*Analyzer*: `csd_analyzer.sql`

*Features*:

**Service Request Analysis**
- Detect SRs (Service Requests) with no activity for > threshold (SLA breach risk)
- Validate SR status transition rules (workflow configuration)
- Detect SRs assigned to deactivated employees/groups
- Queue assignment analysis: unassigned SRs by priority
- Escalation rule configuration validation
- Detect duplicate SRs for same issue (duplicate detection algorithm)

**Depot Repair**
- Repair orders stuck in workflow status
- Detect repair jobs with no BOM/routing defined
- Return material authorization (RMA) linking to depot repair order
- Warranty validation on repair items

**Knowledge Base**
- Published solution validity (expired or outdated articles)
- Search index rebuild status

**6.6.2 Field Service (CSF) Sub-Agent**

*Analyzer*: `csf_analyzer.sql`

*Features*:
- **Scheduling**: Detect field service tasks not scheduled within response time commitment
- **Territory Management**: Validate service territory assignment for technicians
- **Parts Planning**: Detect required parts not reserved on field service tasks
- **Debrief**: Tasks completed but not debriefed (charge lines not generated)
- **Mobile Integration**: Detect sync failures between field agents and EBS
- **SLA Contract Validation**: Validate service contracts cover affected assets

**6.6.3 Collections (IEX) Sub-Agent**

*Analyzer*: `iex_analyzer.sql`

*Features*:
- Delinquency aging bucket configuration
- Collector assignment validation
- Dunning letter template setup
- Bankruptcy/dispute strategy assignment
- Promise-to-pay tracking
- Write-off approval workflow

**6.6.4 Marketing (AMS) Sub-Agent**

*Features*:
- Campaign source code generation
- Budget consumption analysis
- Lead import interface errors

---

## 7. Cross-Cutting Capabilities

These capabilities apply to ALL module agents.

### 7.1 MOS (My Oracle Support) Integration

**Purpose**: Automatically cross-reference diagnostic findings against known Oracle issues and patches.

**Capabilities**:
- For each finding, search MOS Knowledge Base by: error code, program name, EBS version, module
- Return top-3 matching MOS notes with relevance score
- For each applicable patch (one-off, bundle, release update), check if already applied using `fnd_patches.sql`
- Generate patch recommendation report: applicable patches, prerequisites, conflict detection
- Link directly to MOS note URLs in incident report

**Tool**: `search_mos(error_code, module, ebs_version)` → `MOSNote[]`

### 7.2 Proactive Monitoring & Scheduling

**Purpose**: Run health checks on a schedule, before issues impact users.

**Capabilities**:
- Each module agent has a set of "always-on" health checks that run on configurable schedules:
  - Hourly: CP manager health, stuck concurrent requests, disk space
  - Daily: Period close readiness, security audit, certificate expiry, workflow queue depth
  - Weekly: Full module health report per installed module
  - Pre-defined events: Before month-end (period close package), before upgrade
- Alerting: Send findings above configurable severity threshold to email/Slack/PagerDuty/MOS SR
- Trend analysis: Store time-series health scores per metric; alert on degrading trends

**Configuration**:
```json
{
  "schedule": {
    "hourly": ["cp_health", "disk_space"],
    "daily": ["period_close_readiness", "security_audit"],
    "weekly": ["full_module_health"],
    "pre_close": ["ap_period_close", "ar_period_close", "gl_period_close"]
  },
  "alert_threshold": "HIGH",
  "destinations": ["email", "slack_webhook", "mos_sr"]
}
```

### 7.3 Root Cause Analysis Engine

**Purpose**: Distinguish root causes from symptoms across module boundaries.

**Logic**:
- Build a **causal graph** of EBS component dependencies (pre-built, updated with each bundle release)
- When findings arrive from multiple agents, traverse the causal graph to identify the root node
- Example causal chains pre-defined:
  - `ICM_DOWN → ALL_CP_BLOCKED → AP_INVOICES_UNPOSTED → AP_PERIOD_CLOSE_BLOCKED → GL_PERIOD_CLOSE_BLOCKED`
  - `INVALID_ACCOUNT_COMBINATION → SLA_ACCOUNTING_FAILURE → AR_NOT_POSTED → AR_RECON_FAILURE`
  - `TCA_DUPLICATE_PARTY → AUTOINVOICE_CUSTOMER_REJECTION → AR_REVENUE_NOT_RECOGNIZED`
  - `BOM_CIRCULAR_REFERENCE → MRP_PLAN_FAILURE → PLANNED_ORDER_NOT_CREATED → INVENTORY_SHORTAGE`
- Output: Root cause identified with confidence score, full causal chain visualization

### 7.4 Remediation Engine

**Purpose**: Provide and optionally execute remediation actions.

**Remediation Tiers**:
- **Tier 1 — Auto-Fix** (no human approval required): Recompile invalid objects, gather stale statistics, restart non-ICM concurrent managers, clear orphaned temporary data
- **Tier 2 — Guided Fix** (agent provides SQL/steps, human executes): Insert/update configuration data, resolve specific data integrity issues
- **Tier 3 — Manual Process** (agent provides checklist): Period close procedures, patch application, org structure changes
- **Tier 4 — Escalate** (agent creates MOS SR): Confirmed Oracle bugs, data corruption requiring Oracle Support involvement

**Safety Controls**:
- All Tier 1 auto-fixes require explicit user confirmation in agentic session
- All auto-fix SQL is logged before execution
- Rollback SQL is generated and stored before any DML execution
- Auto-fix disabled on production instances unless overridden by authorized role

### 7.5 Multi-Instance Management

**Purpose**: Support diagnosis across multiple EBS instances from a single interface.

**Capabilities**:
- Maintain connection profiles for multiple instances (PROD, UAT, DEV, DR)
- Compare configuration between instances (e.g., "what is different between PROD and UAT?")
- Clone validation: run post-clone analyzer across all ATG and module checks on new instance
- Upgrade path analysis: compare current instance state vs. target version requirements

### 7.6 Audit & Compliance Reporting

**Purpose**: Provide evidence-quality audit trails for all diagnostic sessions.

**Capabilities**:
- Every tool call (SQL execution, Java analyzer run, MOS search) logged with: timestamp, user, instance, inputs, outputs, duration
- Session replay: reconstruct exactly what was run and found in any historical session
- Compliance report templates: SOX IT General Controls, ISO 27001, PCI-DSS for EBS
- User access review automation: periodic reports of active user-responsibility-menu access
- Change detection: compare current configuration vs. last known-good baseline

### 7.7 Version-Aware Execution

**Purpose**: Ensure correct analyzers run for the specific EBS version of the target instance.

**Logic**:
- On connection to each instance, detect EBS version from FND_PRODUCT_GROUPS
- Each analyzer has COMPAT metadata: `11.5`, `12.0`, `12.1`, `12.2`
- Agent only executes analyzers compatible with detected version
- For R12.2 ADOP-aware analyzers: detect current ADOP phase (apply/cutover/cleanup) and adjust recommendations accordingly
- Alert if deprecated analyzers are in use for newer EBS versions

---

## 8. Tool & Integration Requirements

### 8.1 Core Agent Tools (All Agents)

| Tool Name | Description | Input | Output |
|---|---|---|---|
| `execute_sql_analyzer` | Run SQL analyzer against EBS DB | analyzer_path, db_connection, params | AnalyzerResult |
| `execute_java_analyzer` | Run Hybrid Analyzer (XML/Java) | xml_path, ebs_credentials | AnalyzerResult |
| `execute_fndload` | Install analyzer as concurrent program | ldt_path, ebs_credentials, prod_top | LoadResult |
| `submit_concurrent_request` | Submit EBS concurrent program | program_name, params, instance | RequestID |
| `poll_concurrent_request` | Check concurrent request status | request_id, instance | RequestStatus |
| `get_concurrent_output` | Retrieve concurrent request output | request_id, instance | OutputFile |
| `parse_analyzer_output` | Structure raw analyzer output | raw_output, analyzer_type | StructuredFindings |
| `search_mos` | Search My Oracle Support | keywords, version, module | MOSNote[] |
| `check_patch_applied` | Check if patch applied in EBS | patch_number, instance | Boolean |
| `get_ebs_metadata` | Get EBS version, installed products | instance | EBSMetadata |
| `store_finding` | Persist finding to audit store | finding, session_id | FindingID |
| `generate_report` | Create incident report | findings[], format | ReportDocument |
| `send_alert` | Send alert notification | finding, channel, recipients | AlertID |

### 8.2 Database Connectivity

- **Primary**: cx_Oracle (Python) or JDBC thin driver for direct DB connections
- **Credential Storage**: HashiCorp Vault or AWS Secrets Manager — never plaintext
- **Connection Pooling**: Minimum 2 / Maximum 10 connections per instance
- **Timeout**: 30-second query timeout for individual statements; 10-minute timeout for analyzer scripts
- **Read-Only Mode**: Default connection mode for diagnostic queries; separate write-enabled connection for auto-fix (explicit approval required)

### 8.3 EBS Application Server Integration

- SSH access to application tier for Java/HAF analyzer execution
- JDK 7+ required on application server (validated at connection time)
- APPL_TOP, ORACLE_HOME, ADJVAPRG environment variables required
- Secure credential handling — APPS password via environment variable, not CLI argument

### 8.4 External Integrations

| Integration | Purpose | Protocol |
|---|---|---|
| My Oracle Support (MOS) | Patch and note search | REST API |
| Slack | Alert notifications | Webhook |
| PagerDuty | Critical alert escalation | REST API |
| ServiceNow / JIRA | Ticket creation from findings | REST API |
| Email (SMTP) | Report distribution | SMTP/IMAP |
| Oracle Identity Cloud (IDCS) | Authentication for agent UI | OAuth 2.0 |

---

## 9. Data Requirements

### 9.1 Session & Audit Store

**Schema**:
```
sessions(id, user_id, instance_id, start_time, end_time, status, metadata)
tool_calls(id, session_id, tool_name, inputs_json, outputs_json, duration_ms, timestamp)
findings(id, session_id, module, severity, category, description, mos_references, remediation, auto_fixable, timestamp)
alerts(id, finding_id, channel, recipients, sent_at, acknowledged_at)
schedules(id, instance_id, check_type, cron_expression, last_run, next_run, enabled)
baselines(id, instance_id, module, configuration_snapshot, captured_at)
```

### 9.2 Knowledge Base

**Contents**:
- EBS component dependency graph (for root cause analysis)
- Analyzer-to-module mapping with version compatibility matrix
- Known issue patterns (error code → probable cause → resolution)
- Causal chain definitions (pre-built, extensible)
- MOS note cache (TTL: 24 hours)

### 9.3 Data Retention

- Session audit logs: 7 years (SOX compliance)
- Finding history: 3 years
- Configuration baselines: Unlimited (point-in-time history)
- MOS note cache: 24-hour TTL
- Temporary SQL output files: 30-day TTL

---

## 10. Security & Compliance

### 10.1 Authentication & Authorization

- Agent UI requires MFA via IDCS/Oracle Identity
- Role-based access: READ_ONLY, DIAGNOSE, REMEDIATE, ADMIN
- EBS credentials (APPS password) are never stored — injected per session via Vault
- Session tokens expire after 8 hours of inactivity

### 10.2 Credential Security

- All EBS credentials encrypted at rest (AES-256) and in transit (TLS 1.2+)
- Database passwords rotated quarterly via automated Vault policy
- Agent logs NEVER contain plaintext credentials
- Credential audit: all access to APPS-level credentials logged

### 10.3 Data Privacy

- EBS production data accessed only for read diagnostic queries
- PII fields (employee SSN, customer contact info) masked in all agent outputs
- Data classification labels applied to all findings containing sensitive data
- GDPR: right-to-erasure requests honored in session audit store

### 10.4 Network Security

- All agent-to-database connections over private network (no internet-exposed DB)
- Bastion/jump host pattern for application server SSH access
- Network ACLs restrict agent server to EBS DB port (1521) and app server SSH (22)
- All API calls to MOS over TLS 1.2+

---

## 11. Non-Functional Requirements

### 11.1 Performance

| Operation | Target |
|---|---|
| Simple SQL analyzer execution | < 60 seconds |
| Java/HAF analyzer execution | < 5 minutes |
| Full module health check (all analyzers in one module) | < 15 minutes |
| Orchestrator routing (intent classification to first tool call) | < 3 seconds |
| Report generation (after all findings collected) | < 30 seconds |
| Concurrent analyzer execution (parallel agents) | Support up to 5 parallel module agents |

### 11.2 Reliability

- Agent framework: 99.9% uptime (excluding EBS DB downtime)
- Failed analyzer execution retried up to 3 times with exponential backoff
- Circuit breaker: if EBS DB unresponsive for 60s, fail fast and notify user
- All findings persisted before report generation (no data loss on agent failure)

### 11.3 Scalability

- Support up to 50 concurrent diagnostic sessions per agent deployment
- Horizontal scaling via agent pool (stateless agents, shared session store)
- Support up to 20 registered EBS instances

### 11.4 Maintainability

- New analyzer scripts added to bundle are auto-discovered (no code change required)
- Analyzer metadata (COMPAT, MENU_TITLE) parsed at runtime
- Knowledge base (causal chains, issue patterns) updateable via admin UI without redeployment
- All agent prompts and decision logic version-controlled

---

## 12. Implementation Phases

### Phase 1 — Foundation (Weeks 1–8)
**Goal**: Core infrastructure and ATG agent operational

Deliverables:
- Orchestrator agent with intent classification and session management
- ATG Core Agent: CP, Security, Performance, OA Framework sub-agents
- SQL analyzer execution tool (direct DB connection)
- Basic output parser for UTL_FILE SQL analyzers
- Session audit store
- CLI interface (chat-based)

Acceptance: ATG agent can diagnose a concurrent processing issue end-to-end from natural language input.

### Phase 2 — Financials (Weeks 9–16)
**Goal**: Full Financials agent with AP, AR, GL, FA sub-agents

Deliverables:
- AP, AR, GL, FA, CE sub-agents
- Java/HAF analyzer execution tool
- MOS integration (search and patch check)
- Period close workflow support
- HTML/PDF report generation

Acceptance: System guides an engineer through a full AP period close readiness check with remediation recommendations.

### Phase 3 — Manufacturing & HCM (Weeks 17–24)
**Goal**: Manufacturing and HCM agents

Deliverables:
- Manufacturing agent: INV, BOM, OM, PO, CST sub-agents
- HCM agent: Core HR, Payroll, Benefits sub-agents
- Root cause analysis engine
- Cross-module correlation

Acceptance: System identifies that an AP invoice hold is caused by a 3-way PO match failure, tracing the full chain.

### Phase 4 — CRM & Advanced Features (Weeks 25–32)
**Goal**: CRM agent and proactive monitoring

Deliverables:
- CRM agent: CS, Field Service, Collections sub-agents
- Proactive monitoring scheduler
- Alert integrations (Slack, PagerDuty, email)
- Multi-instance support
- Web UI (React/Vue chat interface)

Acceptance: System proactively alerts on a critical finding before user reports issue.

### Phase 5 — Remediation & Compliance (Weeks 33–40)
**Goal**: Automated remediation and compliance reporting

Deliverables:
- Tier 1 & 2 remediation actions per module
- Compliance report templates (SOX, ISO 27001)
- Configuration baseline and drift detection
- ServiceNow / JIRA integration
- Admin UI for schedule and alert configuration

Acceptance: System auto-fixes a stuck concurrent manager with full audit trail; generates SOX IT General Controls report.

---

## 13. Acceptance Criteria

### System-Level
- [ ] All 378 SQL analyzers can be executed via agent without manual CLI interaction
- [ ] All 46 Java/Hybrid analyzers can be executed via agent
- [ ] Agent correctly routes 95%+ of natural language requests to the correct module agent
- [ ] Agent correctly identifies version-incompatible analyzers and skips them
- [ ] All tool calls are logged in audit store within 100ms of completion
- [ ] Concurrent execution of 5 module agents does not degrade individual agent response time by > 20%

### Module-Level (per agent)
- [ ] Each module agent can execute all applicable analyzers for its domain
- [ ] Each module agent produces structured findings (severity, description, MOS reference, remediation)
- [ ] Period close agents produce a go/no-go recommendation with blocking item list
- [ ] Cross-module correlation correctly identifies root cause in 3 pre-defined multi-module test scenarios

### Security
- [ ] No EBS credentials appear in any log file
- [ ] All PII fields masked in agent outputs
- [ ] Unauthorized users cannot execute Tier 1 auto-fix actions
- [ ] All sessions expire after 8 hours inactivity

---

## 14. Glossary

| Term | Definition |
|---|---|
| ADOP | Automatic Deployment Of Patches — Oracle EBS R12.2 online patching mechanism |
| ATG | Application Technology Group — EBS core infrastructure modules |
| BIP | Business Intelligence Publisher — Oracle's report output tool |
| CP | Concurrent Processing — EBS batch job execution framework |
| DFF | Descriptive Flexfield — user-extensible attribute framework |
| EBS | Oracle E-Business Suite — Oracle's ERP system |
| FNDLOAD | Oracle utility for loading EBS object definitions from LDT files |
| HAF | Hybrid Analyzer Framework — Java-based analyzer execution platform |
| ICM | Internal Concurrent Manager — master manager for all concurrent processing |
| KFF | Key Flexfield — structured code combination framework (e.g., Chart of Accounts) |
| LDT | Loader Data Transfer — file format used by FNDLOAD |
| MOS | My Oracle Support — Oracle's customer support portal |
| NLS | National Language Support — multi-language/locale framework |
| SLA | Subledger Accounting — accounting engine connecting subledgers to GL |
| TCA | Trading Community Architecture — master data framework for customers/suppliers |
| UTL_FILE | Oracle PL/SQL package for writing output files |
| VPD | Virtual Private Database — row-level security mechanism |
| XLA | Oracle's SLA engine schema prefix |
| ADZDDB | ADOP diagnostic script for database details |
| ECPUC | Enhanced Concurrent Processing Utility Check |

---

*End of PRD — Oracle EBS Support Agent System v1.0*
*Prepared based on analysis of Oracle EBS Proactive Services Analyzer Bundle v200.170*
*Build Date: 27-Feb-2026 | PRD Date: 2026-03-31*
