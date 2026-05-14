# Product Requirements Document
# Oracle Fusion Cloud Support Agent System
**Version**: 1.0
**Date**: 2026-03-31
**Classification**: Internal — Engineering & Product
**Applies To**: Oracle Fusion Cloud Applications (ERP, SCM, HCM, CX)
**Cloud Releases**: 24A, 24B, 24C, 24D, 25A, 25B and later quarterly updates

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Problem Statement](#2-problem-statement)
3. [Goals & Success Metrics](#3-goals--success-metrics)
4. [Fusion Architecture Context](#4-fusion-architecture-context)
5. [System Architecture Overview](#5-system-architecture-overview)
6. [User Personas](#6-user-personas)
7. [Module Agent Specifications](#7-module-agent-specifications)
   - 7.1 [Orchestrator / Router Agent](#71-orchestrator--router-agent)
   - 7.2 [Platform & Infrastructure Agent](#72-platform--infrastructure-agent)
   - 7.3 [Financials Agent](#73-financials-agent)
   - 7.4 [Procurement Agent](#74-procurement-agent)
   - 7.5 [Projects Agent](#75-projects-agent)
   - 7.6 [Supply Chain Management (SCM) Agent](#76-supply-chain-management-scm-agent)
   - 7.7 [Human Capital Management (HCM) Agent](#77-human-capital-management-hcm-agent)
   - 7.8 [Customer Experience (CX) Agent](#78-customer-experience-cx-agent)
   - 7.9 [Integration & Platform Extension Agent](#79-integration--platform-extension-agent)
8. [Cross-Cutting Capabilities](#8-cross-cutting-capabilities)
9. [Tool & Integration Requirements](#9-tool--integration-requirements)
10. [Data Requirements](#10-data-requirements)
11. [Security & Compliance](#11-security--compliance)
12. [Non-Functional Requirements](#12-non-functional-requirements)
13. [Implementation Phases](#13-implementation-phases)
14. [Acceptance Criteria](#14-acceptance-criteria)
15. [Glossary](#15-glossary)

---

## 1. Executive Summary

The **Oracle Fusion Cloud Support Agent System** is a multi-agent AI platform designed to automate, accelerate, and enhance support operations for Oracle Fusion Cloud Applications. Unlike Oracle EBS (which runs on-premise with direct database access), Oracle Fusion is a SaaS platform — all diagnostic operations must be performed through REST APIs, SOAP services, Oracle Diagnostics Tests, OTBI analytics, and ESS (Enterprise Scheduler Service) job submissions. This constraint fundamentally shapes the agent architecture.

The system is a hierarchy of specialized AI agents — one per Fusion pillar (Platform, Financials, Procurement, Projects, SCM, HCM, CX, Integration) — coordinated by an Orchestrator that routes requests, manages cross-pillar workflows, and synthesizes findings into unified incident reports. Each module agent uses Claude LLM reasoning with Fusion REST API tools to:

- Diagnose issues through Oracle Fusion Diagnostic Tests and REST API health checks
- Monitor ESS (Scheduled Process) queues for failures and stuck jobs
- Validate period close readiness across Financials subledgers
- Detect security and role configuration violations via IDCS and Fusion Security REST APIs
- Identify integration failures in OIC (Oracle Integration Cloud) and REST/SOAP endpoints
- Validate data quality from FBDI/HDL imports
- Correlate issues across pillars (e.g., a failed BPM approval blocking AP period close)
- Generate remediation plans with Fusion-appropriate actions (REST API calls, scheduled process submissions, MOS guidance)

Oracle Fusion receives **quarterly cloud updates** (24A/B/C/D, 25A/B, etc.). The agent system maintains awareness of the current cloud release, checks for known issues in release-specific MOS notes, and validates that post-update configurations remain intact.

---

## 2. Problem Statement

### 2.1 Current State

Oracle Fusion Cloud support engineers operate today by:
1. Logging into Oracle Cloud Support or the Fusion UI
2. Navigating to Setup and Maintenance → Manage Diagnostics Tests to run individual diagnostic tests
3. Manually interpreting results from the Diagnostics Test output (HTML/text, no AI interpretation)
4. Running OTBI reports to gather transaction data
5. Checking ESS (Scheduled Processes) monitor one-by-one for job failures
6. Consulting My Oracle Support (MOS) and Oracle Cloud Known Issues pages manually
7. Engaging Oracle Support via SR (Service Request) for complex issues
8. Repeating across multiple pillars when issues are cross-functional

### 2.2 Pain Points

| Pain Point | Impact |
|---|---|
| 200+ Fusion Diagnostic Tests — engineers don't know which ones apply to their issue | Wrong tests run; root cause missed |
| Diagnostic Test results are text/HTML — no structured interpretation | High cognitive load; errors in reading |
| No correlation across Fusion pillars | Cross-pillar root cause missed (e.g., BPM approval failure blocking GL close) |
| Quarterly cloud updates can silently break configurations | Post-update regressions found late |
| ESS job failures require manual monitoring across dozens of scheduled processes | Missed failures; delayed business processes |
| FBDI/HDL import errors require reading raw log files | Slow diagnosis of mass data load failures |
| OIC integration failures require navigating OIC console separately | Siloed visibility; delayed resolution |
| No proactive health checks — reactive support only | Issues found after business impact |
| REST API rate limiting awareness absent from manual workflows | Engineers hit 429 errors without understanding why |
| Security role conflicts (IDCS + Fusion Data Security) require specialized knowledge | Incorrect access grants go undetected |
| Oracle Fusion release notes for each quarterly update must be manually reviewed | New known issues missed |

### 2.3 Desired State

An AI agent system that:
- Accepts natural language Fusion support requests ("Payroll is not processing for pay period ending March")
- Maps the request to the correct Fusion pillar agent(s) and determines which diagnostic tests to run
- Executes Fusion Diagnostic Tests, OTBI queries, and REST API health checks autonomously
- Interprets results in business language with structured findings
- Cross-references findings with Oracle Cloud Known Issues and MOS notes for the current Fusion release
- Identifies cross-pillar root causes (ESS failure → period close blocked → AR receipts unposted)
- Provides a tiered remediation plan (what the customer can do vs. what requires an Oracle SR)
- Proactively monitors Fusion health on schedule and alerts before users are impacted
- Maintains a full audit trail for every diagnostic session

---

## 3. Goals & Success Metrics

### Primary Goals

| Goal | Metric | Target |
|---|---|---|
| Reduce Mean Time to Diagnosis (MTTD) | Time from ticket open to root cause identified | < 20 minutes (from ~3 hours) |
| Increase diagnostic test coverage per incident | % of applicable Fusion Diagnostic Tests run | > 95% (from ~25%) |
| Eliminate manual output interpretation | % of findings auto-interpreted with action | > 90% |
| Enable proactive issue detection | Issues caught before user-reported impact | > 45% of critical issues |
| Post-update regression detection | Hours to detect configuration regression after quarterly update | < 4 hours |
| Audit completeness | % of support sessions with full execution log | 100% |

### Secondary Goals

- Enable Level-1 support engineers to perform Level-3 Fusion diagnostics without deep expertise
- Reduce Oracle SR volume by resolving known, documentable issues autonomously
- Create institutional memory across quarterly Fusion updates (what breaks, what to check)
- Support multi-cloud-tenant environments (multiple Fusion instances: PROD, TEST, UAT)
- Provide functional consultants with configuration validation at implementation time

---

## 4. Fusion Architecture Context

Understanding Oracle Fusion's SaaS architecture is essential for designing the agent system correctly. Key differences from EBS that directly affect agent design:

### 4.1 No Direct Database Access
Fusion is a SaaS platform. There is no direct Oracle DB access for customers. All diagnostic data must be obtained via:
- **Fusion REST APIs** (`/fscmRestApi/resources/`, `/hcmRestApi/resources/`, `/crmRestApi/resources/`)
- **Oracle Diagnostics Tests** (Fusion UI → Setup and Maintenance → Manage Diagnostics Tests)
- **OTBI (Oracle Transactional Business Intelligence)** reports and analyses
- **BI Publisher** reports with SOAP/REST invocation
- **ESS (Enterprise Scheduler Service)** job status APIs

### 4.2 Scheduled Processes (ESS) — Not Concurrent Programs
Oracle Fusion uses the **Enterprise Scheduler Service (ESS)** for background jobs. Equivalent to EBS Concurrent Programs but REST API-accessible:
- Submit: `POST /ess/rest/job/request/`
- Monitor: `GET /ess/rest/job/request/{requestId}`
- Output: Retrieved via UCM (WebCenter Content) attachment links

### 4.3 Quarterly Cloud Updates
Fusion releases quarterly updates (24A = Jan 2024, 24B = Apr 2024, etc.). Each update:
- Can introduce behavioral changes, setup requirement changes, new mandatory configurations
- Has an associated "Known Issues" MOS document
- Has a "What's New" document with opt-in feature list
- The agent must be aware of the current release and check release-specific advisories

### 4.4 Oracle Diagnostics Tests Framework
Fusion's built-in diagnostic tests (200+) are accessible via:
- UI: Setup and Maintenance → Manage Diagnostics Tests
- REST API: `GET /fscmRestApi/resources/latest/diagnosticTests`
- Execution: `POST /fscmRestApi/resources/latest/diagnosticTests/{testCode}/action/run`
- Results: `GET /fscmRestApi/resources/latest/diagnosticTestRuns/{runId}`

### 4.5 Data Loading Mechanisms
| Mechanism | Use Case | Agent Tool |
|---|---|---|
| FBDI (File-Based Data Import) | Mass financial data loads | Upload CSV/ZIP via UCM + submit ESS job |
| HDL (HCM Data Loader) | HCM mass data loads | Upload .dat file via REST + submit ESS job |
| REST API | Individual record operations | Direct REST calls |
| ADFdi (ADF Desktop Integration) | Excel-based uploads | Spreadsheet-to-REST |
| SOAP Web Services | Legacy/complex integrations | SOAP envelope calls |

### 4.6 Security Architecture
- **IDCS (Identity Cloud Service)** / **OCI IAM**: Authentication, user provisioning, MFA
- **Fusion Abstract Roles & Job Roles**: RBAC inside Fusion application
- **Data Security Policies**: Row-level security on business objects
- **Duty Roles**: Fine-grained functional access
- Diagnostics require specific security roles (e.g., `Application Diagnostics Administrator`)

---

## 5. System Architecture Overview

### 5.1 Agent Hierarchy

```
┌────────────────────────────────────────────────────────────────────┐
│                     USER INTERFACE LAYER                          │
│       (Chat UI / Slack / Oracle Support Portal / REST API)        │
└────────────────────────────┬───────────────────────────────────────┘
                             │
┌────────────────────────────▼───────────────────────────────────────┐
│                    ORCHESTRATOR AGENT                             │
│  - Intent classification & pillar routing                         │
│  - Multi-pillar workflow DAG planning                             │
│  - Fusion release version awareness                               │
│  - Cross-pillar correlation & root cause synthesis                │
│  - Incident report & remediation plan generation                  │
└──┬─────────┬────────┬────────┬────────┬────────┬────────┬─────────┘
   │         │        │        │        │        │        │
   ▼         ▼        ▼        ▼        ▼        ▼        ▼
┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────────┐
│ PLT  │ │ FIN  │ │ PRO  │ │ PRJ  │ │ SCM  │ │ HCM  │ │    CX    │
│AGENT │ │AGENT │ │AGENT │ │AGENT │ │AGENT │ │AGENT │ │  AGENT   │
│(Plat)│ │(Fin) │ │(Proc)│ │(Proj)│ │(SCM) │ │(HCM) │ │  (CX)   │
└──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────┘ └──────────┘
                           + Integration Agent (OIC)
                           │
          ┌────────────────┼───────────────────────────────────────┐
          │                                                        │
┌─────────▼──────────────────────────────────────────────────────-─┐
│                        TOOL LAYER                                │
│ ┌──────────────┐ ┌─────────────┐ ┌──────────────────────────┐   │
│ │ Fusion REST  │ │ Diagnostics │ │  ESS Job Submitter        │   │
│ │ API Client   │ │ Test Runner │ │  (Scheduled Processes)    │   │
│ └──────────────┘ └─────────────┘ └──────────────────────────┘   │
│ ┌──────────────┐ ┌─────────────┐ ┌──────────────────────────┐   │
│ │ OTBI Query   │ │ BIP Report  │ │  FBDI/HDL Import Tool     │   │
│ │ Executor     │ │ Executor    │ │  (File Upload + ESS)      │   │
│ └──────────────┘ └─────────────┘ └──────────────────────────┘   │
│ ┌──────────────┐ ┌─────────────┐ ┌──────────────────────────┐   │
│ │ MOS / Cloud  │ │ OIC Monitor │ │  IDCS/OCI IAM API Client │   │
│ │ Known Issues │ │ API Client  │ │  (Security Queries)       │   │
│ └──────────────┘ └─────────────┘ └──────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
                             │
┌────────────────────────────▼───────────────────────────────────────┐
│                       DATA LAYER                                   │
│ ┌──────────────┐ ┌───────────────┐ ┌────────────────────────────┐  │
│ │ Session &    │ │ Knowledge Base│ │ Fusion Release Registry    │  │
│ │ Audit Store  │ │ (Issue Map,   │ │ (Known issues per release, │  │
│ │              │ │ Causal Graph) │ │ opt-in features, patches)  │  │
│ └──────────────┘ └───────────────┘ └────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

### 5.2 Agent Communication Protocol

- All agents communicate via structured **AgentMessage** schema (JSON)
- Schema: `{ session_id, source_agent, target_agent, intent, fusion_instance, cloud_release, context, payload, priority, timestamp }`
- Orchestrator maintains a **WorkflowPlan DAG** — directed acyclic graph of agent tasks
- Module agents return **FusionFinding** objects:
  ```json
  {
    "severity": "CRITICAL|HIGH|MEDIUM|LOW|INFO",
    "pillar": "FIN|SCM|HCM|CX|PRO|PRJ|PLT|OIC",
    "module": "AP|AR|GL|PAYROLL|...",
    "category": "ESS_FAILURE|PERIOD_CLOSE|SECURITY|DATA_INTEGRITY|CONFIGURATION|INTEGRATION",
    "description": "Human-readable finding",
    "diagnostic_test": "TEST_CODE_IF_APPLICABLE",
    "api_evidence": { "endpoint": "...", "response_excerpt": "..." },
    "cloud_known_issue": "MOS_NOTE_OR_CLOUD_KNOWN_ISSUE_ID",
    "remediation": {
      "tier": 1,
      "steps": ["..."],
      "auto_fixable": true,
      "fusion_sr_required": false,
      "rest_api_fix": "POST /fscmRestApi/resources/..."
    }
  }
  ```
- All tool invocations logged to Audit Store (timestamp, agent, endpoint, HTTP status, duration)

### 5.3 Fusion API Execution Model

**Mode 1 — REST API Diagnostics (Primary)**
- Agent calls Fusion Diagnostics Tests REST API to trigger and retrieve diagnostic test results
- Agent calls module-specific REST APIs to query health metrics, transaction counts, error queues
- All calls authenticated via OAuth 2.0 (Client Credentials or Authorization Code flow via IDCS)

**Mode 2 — ESS Job Submission**
- Agent submits Scheduled Processes (ESS jobs) via REST API for operations requiring batch execution
- Agent polls ESS job status until completion
- Agent retrieves job output from UCM (WebCenter Content) via REST

**Mode 3 — OTBI Report Execution**
- Agent submits OTBI analyses or BIP reports via REST or SOAP for data-heavy queries
- Agent retrieves and parses report output (CSV, JSON, XML)

**Mode 4 — FBDI / HDL Data Validation**
- Agent retrieves import log files from UCM after FBDI/HDL jobs complete
- Agent parses error logs and categorizes import rejections

---

## 6. User Personas

### Persona 1: Fusion Support Engineer (Primary)
- **Role**: Oracle Support or implementation/managed services support
- **Fusion Knowledge**: Intermediate — knows module workflows, not deep API/infrastructure
- **Goal**: Diagnose a reported user issue quickly, produce a structured remediation plan
- **Interaction**: Conversational — describes the problem in natural language
- **Key Need**: Agent interprets API responses and test results in business language; auto-identifies if issue requires Oracle SR

### Persona 2: Fusion System Administrator
- **Role**: Manages Fusion cloud instance, integrations, security, scheduled processes
- **Fusion Knowledge**: Deep technical — knows ESS, IDCS, OIC, REST APIs, data loaders
- **Goal**: Proactive health monitoring, post-update validation, integration health management
- **Interaction**: Command-oriented; may specify exact diagnostic test or API endpoint
- **Key Need**: Full raw API response access, structured summaries, autonomous scheduled runs, OIC monitoring

### Persona 3: Functional Implementation Consultant
- **Role**: Configures and implements Fusion modules (AP, AR, Payroll, SCM, etc.)
- **Fusion Knowledge**: Deep functional — knows Setup and Maintenance, business flows, not API internals
- **Goal**: Validate module configuration during implementation, troubleshoot setup issues
- **Interaction**: Conversational, business language ("Period close is blocked for legal entity US1")
- **Key Need**: Findings in business terms; identify which Setup and Maintenance tasks to revisit

### Persona 4: Fusion Security Administrator
- **Role**: Manages IDCS users, Fusion roles, data security policies
- **Fusion Knowledge**: Deep security — RBAC, duty roles, data security conditions, IDCS app roles
- **Goal**: Detect segregation of duties violations, audit over-privileged users, validate post-update role changes
- **Interaction**: Report-request oriented; periodic compliance runs
- **Key Need**: Structured security reports, SoD violation lists, exportable evidence for audit

### Persona 5: Business Process Owner / IT Director
- **Role**: Owns one or more Fusion modules; accountable for business outcomes
- **Fusion Knowledge**: High-level — understands processes, not technical implementation
- **Goal**: Executive health summary, period close status, proactive risk alerts
- **Interaction**: Dashboard-oriented; receives scheduled reports
- **Key Need**: Business-language health scores, risk ratings, go/no-go recommendations for period close

---

## 7. Module Agent Specifications

---

### 7.1 Orchestrator / Router Agent

#### Purpose
System entry point for all user requests. Classifies intent, determines which Fusion pillar agent(s) to invoke, builds the execution workflow, collects and correlates cross-pillar findings, and generates the final unified incident report.

#### Responsibilities

**Intent Classification**
- Parses natural language to identify:
  - Fusion pillar(s) involved (Financials, Procurement, SCM, HCM, CX, OIC, Platform)
  - Module within pillar (AP, Payroll, Inventory, Recruiting, etc.)
  - Problem type (ESS failure, period close, data integrity, configuration, security, integration, post-update regression)
  - Urgency (production-impacting / high / medium / informational)
  - Scope (single transaction, batch process, module-wide, instance-wide)
- Maintains classification taxonomy aligned to all Fusion Diagnostic Test categories

**Fusion Release Awareness**
- On session start, detects current Fusion cloud release via:
  `GET /fscmRestApi/resources/latest/aboutInfo` → extracts `releaseVersion`
- Loads release-specific known issues from Fusion Release Registry
- Adjusts diagnostic test selection based on release-specific advisories
- Flags if current release has known issues matching the reported symptom

**Workflow Planning**
- Generates WorkflowPlan DAG specifying:
  - Which pillar agents to invoke and in what order
  - Parallelism (HCM and Financials diagnostics run simultaneously; Platform must complete first)
  - Dependency chain (ESS health gates all process-dependent checks)
- Plans adapt dynamically — if root cause found early, downstream checks reprioritized

**Cross-Pillar Correlation**
After all pillar agents return findings, identifies cross-pillar patterns:
- Example: `ESS_UNAVAILABLE → ALL_SCHEDULED_PROCESSES_BLOCKED → AP_CLOSE_BLOCKED → GL_CLOSE_BLOCKED`
- Example: `BPM_APPROVAL_STUCK → PO_NOT_APPROVED → RECEIPT_BLOCKED → AP_INVOICE_MATCH_FAILURE`
- Example: `IDCS_USER_LOCKED → SSO_FAILURE → FUSION_LOGIN_BLOCKED → ESCALATE_TO_CRITICAL`
- Example: `OIC_INTEGRATION_FAILURE → SUPPLIER_INVOICE_NOT_IMPORTED → AP_LIABILITY_UNDERSTATED`
- Example: `FBDI_LOAD_FAILURE → GL_JOURNAL_NOT_IMPORTED → PERIOD_BALANCES_INCORRECT`

**Incident Report Generation**
Structured report containing:
- Executive Summary (business impact, go/no-go for period close)
- Critical Findings (severity-ranked: CRITICAL / HIGH / MEDIUM / LOW / INFO)
- Per-pillar detail with API evidence and diagnostic test results
- Cloud Known Issues matched to findings with MOS/release note links
- Remediation Plan (tiered: customer-actionable / Oracle SR required)
- Audit Trail (every API call, endpoint, HTTP status, timestamp, duration)
- Output formats: Markdown, HTML, PDF, JSON (for ServiceNow/JIRA integration)

#### Tools Available to Orchestrator
```
classify_intent(message)                     → IntentClassification
get_fusion_release(instance)                 → FusionRelease
load_release_known_issues(release)           → KnownIssue[]
plan_workflow(intent, instance, release)     → WorkflowPlan DAG
invoke_pillar_agent(agent_id, task)          → FusionFinding[]
correlate_findings(findings[])               → CorrelatedInsight[]
generate_report(findings, session, format)   → IncidentReport
search_mos(keywords, release, module)        → MOSNote[]
search_cloud_known_issues(symptoms, release) → KnownIssue[]
store_session(session)                       → SessionID
load_session(session_id)                     → Session
send_alert(finding, channel, recipients)     → AlertID
```

#### Routing Logic Examples
```
User: "AP period close is blocked for US1 legal entity"
  → Release: 25A detected
  → Release advisories: Check MOS known issue for ESS maintenance window in 25A
  → Pillar agents: PLT (ESS health), FIN/AP (period close blockers), FIN/GL (period status)
  → Order: PLT first (ESS gates all), FIN/AP + FIN/GL in parallel
  → Correlate: ESS health + AP blockers + GL period status → unified close readiness report

User: "Payroll run did not complete for UK legal employer"
  → Pillar agents: PLT (ESS health), HCM/Payroll (run status, error details)
  → Order: PLT first (ESS gates payroll ESS job), then HCM/Payroll
  → Check: UK Payroll legislative update applied for current period?
  → Report: Payroll run failure analysis with legislative compliance check
```

---

### 7.2 Platform & Infrastructure Agent

#### Purpose
Diagnoses foundational Fusion infrastructure: ESS (Scheduled Processes), BPM/Workflow approvals, Security (IDCS/OCI IAM), Diagnostics Framework health, post-update configuration integrity, and system availability. Platform issues are upstream multipliers — ESS failure blocks every business process.

#### Sub-Agents

**7.2.1 Enterprise Scheduler Service (ESS) Sub-Agent**

*Fusion Diagnostic Tests*: `ESS_HEALTH_CHECK`, `ESS_CONFIGURATION_CHECK`
*REST APIs*: `GET /ess/rest/job/request/`, `GET /ess/rest/job/definition/`

*Features*:
- **ESS Service Health**: Query ESS availability and cluster node health; detect ESS in maintenance mode
- **Scheduled Process Failure Detection**: Identify all ESS jobs in ERROR or CANCELLED state in the last 24/48/72 hours; categorize by error type
- **Stuck Job Detection**: Identify jobs in RUNNING state for > configurable threshold (2x average runtime); flag as potentially hung
- **Job Queue Depth Analysis**: Count pending (WAIT) jobs per job definition; flag queues exceeding threshold indicating ESS backpressure
- **Concurrent Job Conflict Detection**: Identify overlapping job schedules that are known to conflict (e.g., period close + data import running simultaneously)
- **ESS Blackout Window Awareness**: Detect if Oracle-managed blackout window is active (Fusion cloud maintenance); advise user to reschedule
- **Job Output Retrieval**: Fetch ESS job log/output from UCM for failed jobs; extract and categorize error messages
- **Auto-Retry Assessment**: Determine if failed job is safe to resubmit; flag jobs where resubmission requires manual intervention first
- **ESS Job History Trending**: Compare job runtimes over last 30 days; alert on regressions (job taking 3x longer than baseline)

*Agent Behavior*:
```
On invocation for ESS health:
1. GET /ess/rest/job/request/?q=status=ERROR,startedAfter=<24h ago>
2. For each failed job: GET /ess/rest/job/request/{id}/output (retrieve log)
3. Parse log for: ORA- errors, Java exceptions, lock timeouts, data validation failures
4. GET /ess/rest/job/request/?q=status=RUNNING → filter by runningDuration > threshold
5. Classify each issue: INFRASTRUCTURE (ESS itself), DATA (input data bad), CONFIGURATION (job params wrong)
6. If ESS itself is unavailable → CRITICAL escalation; all other agents notified
7. Return FusionFinding[] with ESS health score and individual job findings
```

**7.2.2 BPM Workflow / Approval Sub-Agent**

*Fusion Diagnostic Tests*: `BPM_WORKLIST_CHECK`, `APPROVAL_WORKFLOW_CONFIGURATION`
*REST APIs*: `GET /bpm/api/4.0/tasks`, `GET /fscmRestApi/resources/latest/approvalManagement`

*Features*:
- **Stuck Approval Detection**: Identify workflow tasks in worklist aging beyond SLA thresholds (configurable per transaction type)
- **Worklist Queue Analysis**: Count pending approvals by transaction type, department, and approver; identify bottlenecks
- **Approval Rule Validation**: Validate approval rules in AMX (Approval Management Extension) are correctly configured; detect rules with no matching participants
- **Escalation Rule Health**: Verify escalation rules fire correctly; detect tasks that should have escalated but remain with original approver
- **Vacancy Handling**: Detect approval tasks assigned to users who have left/been deactivated in IDCS; flag tasks with no active approver
- **Delegation Configuration**: Validate delegation rules are still valid (delegate user not terminated)
- **BPM SOA Composite Health**: Verify SOA composites underpinning Fusion workflows are deployed and running
- **Workflow Notification**: Validate BPM email notifications are configured and delivering; detect failed notification attempts

**7.2.3 Security & Identity (IDCS / OCI IAM) Sub-Agent**

*Fusion Diagnostic Tests*: `SECURITY_ROLE_CHECK`, `DATA_SECURITY_POLICY_CHECK`, `SSO_CONFIGURATION_CHECK`
*REST APIs*: IDCS REST API `/admin/v1/Users`, `/admin/v1/Groups`, Fusion Security REST APIs

*Features*:
- **User Account Status**: Detect locked/disabled IDCS accounts for active Fusion users; identify users with login failures exceeding threshold
- **Inactive User Detection**: Identify users inactive for > 90 days with active Fusion roles (security risk)
- **Role Assignment Audit**: Enumerate all users with sensitive roles (IT Security Manager, Application Administrator, Superuser equivalents); flag anomalies
- **Segregation of Duties (SoD) Violation Detection**: Cross-reference role assignments against SoD rule library:
  - AP Invoice Entry + AP Payment Approval
  - PO Creation + PO Approval
  - Journal Entry + Journal Posting
  - Payroll Processing + Payroll Costing
  - System Admin + End User roles
- **Data Security Policy Validation**: Verify data security grants align with intended organizational scope; detect grants with ALL_VALUES condition where narrower scope is required
- **SSO Configuration Health**: Validate SAML/OIDC SSO federation between IDCS and Fusion is operational; detect certificate expiry on identity provider
- **API Key / OAuth Client Audit**: List active OAuth 2.0 client credentials; flag expired, unused, or over-scoped clients
- **IDCS Application Role Sync**: Verify Fusion abstract/job roles are correctly mapped to IDCS app roles; detect sync failures post-update
- **Password Policy Compliance**: Validate IDCS password policies meet organizational requirements; detect deviations post-release update

**7.2.4 Post-Update Regression Sub-Agent**

*Triggered*: Automatically after each quarterly Fusion cloud update detection

*Features*:
- **Release Detection**: Compare current release (`aboutInfo.releaseVersion`) with last recorded release in agent memory
- **Update Change Log**: Retrieve Oracle's "What's New" and "Known Issues" for the new release via MOS
- **Opt-In Feature Status**: Identify new opt-in features in the release; flag features the customer may wish to evaluate
- **Critical Setup Validation**: Run targeted diagnostic tests for areas known to regress in the new release (based on Knowledge Base of historical regression patterns)
- **Workflow Configuration Re-Validation**: Re-run all BPM rule validations post-update (Oracle updates sometimes reset AMX rules)
- **Integration Endpoint Validation**: Re-test all registered OIC integration flows for compatibility with updated REST API versions
- **Custom Security Role Impact**: Identify if the update introduced changes to seeded roles that may affect custom role hierarchies
- **Sandbox Activation Check**: Detect active sandboxes that were not completed/published before the update (may be invalidated)

**7.2.5 Fusion Diagnostics Framework Sub-Agent**

*REST APIs*: `GET /fscmRestApi/resources/latest/diagnosticTests`, `POST .../action/run`

*Features*:
- **Diagnostic Test Catalog**: Maintain a current map of all available Fusion Diagnostic Tests with metadata: test code, pillar, module, description, inputs required, expected runtime
- **Test Selection Intelligence**: Given a symptom or module, select the optimal set of diagnostic tests (avoiding redundant or irrelevant tests)
- **Parallel Test Execution**: Submit multiple independent diagnostic tests in parallel; aggregate results
- **Test Result Parsing**: Structured extraction from diagnostic test output: PASS/FAIL/WARNING status, affected objects, error codes
- **Test Coverage Tracking**: Track which diagnostic tests have been run in the session; suggest additional tests based on preliminary findings
- **Prerequisite Validation**: Some diagnostic tests require specific setup (e.g., GL period must be open); validate prerequisites before execution

**7.2.6 Reporting Infrastructure Sub-Agent**

*Fusion Diagnostic Tests*: `BIP_SERVER_CHECK`, `OTBI_HEALTH_CHECK`
*REST APIs*: BI Publisher REST API, OTBI SOAP/REST

*Features*:
- **BIP (BI Publisher) Server Health**: Verify BIP server is reachable from Fusion; test report template rendering
- **OTBI Service Health**: Validate Oracle Business Intelligence (OBIEE/OTBI) service is available; detect session pool exhaustion
- **Report Template Validation**: Identify RTF/XPT templates with broken data model references
- **Data Model Health**: Validate BIP data model SQL/logical SQL queries execute without error in current release
- **Delivery Channel Configuration**: Verify printer, FTP, email delivery channels for BIP output
- **OTBI Usage Quota**: Check OTBI concurrent session usage vs. instance limits
- **Custom Report Compatibility**: Detect custom OTBI/BIP reports affected by data model changes in quarterly update

---

### 7.3 Financials Agent

#### Purpose
Diagnoses all Oracle Fusion Financials modules: AP, AR, GL, FA, Cash Management, Expenses, Intercompany, EB Tax, and regional variants. The Financials agent has the highest usage frequency — period close, subledger reconciliation, and tax compliance are high-stakes and time-sensitive.

#### Sub-Agents

**7.3.1 Accounts Payable (AP) Sub-Agent**

*Fusion Diagnostic Tests*: `AP_CONFIGURATION_CHECK`, `AP_PERIOD_CLOSE_CHECK`, `AP_PAYMENT_PROCESS_CHECK`, `AP_INVOICE_VALIDATION_CHECK`, `AP_ACCOUNTING_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/invoices`, `/payablesInvoices`, `/payablesPayments`

*Features*:

**Invoice Validation Analysis**
- Retrieve invoices in NEEDS_REVALIDATION or REJECTED status via REST API; categorize by rejection reason
- Invoice hold analysis: identify hold names, hold count, aging, business unit, supplier
- Detect invoices on system holds vs. user-applied holds (different resolution paths)
- 2-way and 3-way PO match failure analysis: price tolerance, quantity tolerance breaches
- Duplicate invoice detection: same supplier, same invoice number, same date/amount combinations
- Tax calculation failures: invoices rejected due to EB Tax determination errors

**Invoice Accounting Validation**
- Run diagnostic test `AP_ACCOUNTING_CHECK` to identify invoices not accounted
- Query invoices with ACCOUNTING_DATE in closed GL period (must be resolved before close)
- Subledger accounting (SLA) error detection: invoices where accounting events are in ERROR status
- Intercompany AP: validate intercompany invoices have corresponding AR invoices across legal entities

**Supplier Configuration Analysis**
- Query suppliers with missing payment method, bank account, or tax registration
- Detect inactive suppliers with open invoices or unprocessed payments
- Supplier merge completion validation: detect partially merged supplier records
- 1099/tax reporting setup validation for US suppliers
- iSupplier portal access configuration validation

**Payment Processing Analysis**
- Retrieve payment process requests in PROCESSING or ERROR status via REST API
- Detect payments stuck in Formatting or Transmission stages
- IBY payment format validation: identify transactions rejected by payment format engine
- Bank account transmission errors: EFT/wire transfer file generation failures
- Positive pay file generation errors
- Payment approval workflow stuck: identify payment batches awaiting manager approval beyond SLA

**AP Period Close Readiness**
- Run `AP_PERIOD_CLOSE_CHECK` diagnostic test
- Retrieve count and amount of unaccounted invoices in the period via OTBI query
- Retrieve count and amount of unposted payments
- Identify payment process requests not yet confirmed
- Detect invoices with future-dated accounting dates blocking current period close
- Intercompany payables not yet reconciled
- Generate period close status: percentage complete, blocking items ranked by volume/amount

**Agent Behavior for AP Period Close**:
```
1. Run AP_PERIOD_CLOSE_CHECK diagnostic test → parse PASS/FAIL/WARNING per section
2. Query: GET /payablesInvoices?q=accountingStatus=NOT_ACCOUNTED,period=<current>
3. Query: GET /payablesPayments?q=status=PROCESSED,accountingStatus=NOT_ACCOUNTED
4. For each blocker:
   a. UNACCOUNTED_INVOICES → Submit "Create Accounting" ESS job if auto-fix enabled
   b. UNCONFIRMED_PAYMENTS → Flag for manual review (requires human approval)
   c. FUTURE_DATED_ACCOUNTING → Advise re-date or wait
5. Determine if remaining blockers can complete before close deadline
6. Return: close readiness score, blocker list with amounts, estimated time to resolution
```

**7.3.2 Accounts Receivable (AR) Sub-Agent**

*Fusion Diagnostic Tests*: `AR_CONFIGURATION_CHECK`, `AR_PERIOD_CLOSE_CHECK`, `AR_AUTOINVOICE_CHECK`, `AR_ACCOUNTING_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/receivablesInvoices`, `/receivablesReceipts`, `/customerAccounts`

*Features*:

**AutoInvoice Analysis**
- Query AutoInvoice interface errors via REST: `GET /receivablesInvoices?q=status=REJECTED`
- Categorize rejections: invalid customer, invalid transaction type, invalid revenue account, tax failure, incomplete required attributes
- Identify interface lines aging in error beyond threshold
- Validate AutoInvoice grouping rule configurations match source system data structure
- Detect AutoInvoice ESS job failures and retrieve error log

**Receipt & Application Analysis**
- Identify unapplied receipts aging beyond 30/60/90 days
- Detect on-account receipts not applied to invoices
- Lockbox import error analysis: retrieve lockbox transmission logs from ESS
- Receipt reversal requests pending approval
- Automatic receipt application rule validation
- Detect receipts applied to wrong invoices (amount vs. remittance advice mismatch)

**AR Transaction & Accounting Validation**
- Run `AR_ACCOUNTING_CHECK` to identify unaccounted AR transactions
- Detect credit memos with no matching invoice reference
- Revenue recognition schedule validation: deferred revenue rules executing correctly
- Out-of-balance distribution detection (agent queries distribution totals via OTBI)
- Multi-currency revaluation: validate revaluation has run for open foreign-currency invoices

**Period Close Readiness**
- Run `AR_PERIOD_CLOSE_CHECK` diagnostic test
- Unaccounted invoices, credit memos, receipts, adjustments in current period
- Open debit/credit memos not applied
- Revenue recognition incomplete for earned milestones
- Intercompany AR not reconciled with intercompany AP
- Generate AR close checklist with status per item and blocking amount

**Customer Account (TCA) Analysis**
- Detect duplicate customer accounts (same name/tax ID across different operating units)
- Customers with missing required fields for tax determination (Tax Registration Number, Tax Classification)
- Customer account site address validation (incomplete city/state/postal for US tax)
- Credit management: customers at or over credit limit with open AR

**Document Sequence Compliance**
- Validate all transaction types have document sequences assigned in all relevant business units
- Detect transactions with NULL sequence values (compliance/audit risk)
- Sequence gap detection (skipped sequence numbers — regulatory concern in some countries)

**7.3.3 General Ledger (GL) Sub-Agent**

*Fusion Diagnostic Tests*: `GL_PERIOD_STATUS_CHECK`, `GL_CONFIGURATION_CHECK`, `GL_ACCOUNT_COMBINATION_CHECK`, `GL_SUBLEDGER_TRANSFER_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/generalLedgerJournals`, `/ledgers`, `/accountingPeriods`

*Features*:

**Journal Entry Analysis**
- Retrieve unposted journals by source, category, and period via REST
- Detect journals in ERROR status from subledger accounting import
- Identify journals with invalid account combinations (segments that are end-dated or disabled)
- Intercompany journals: verify balancing segment offset entries generated correctly
- Manual journal approval: detect journals pending approval beyond SLA
- Journal import: validate FBDI journal import completeness and error count

**Period Management**
- Query period status grid for all ledgers across all accounting periods: Open/Close/Never Opened/Permanently Closed
- Detect periods open beyond configured maximum (audit risk)
- Identify subledgers with open periods where parent GL period is closed (prevents subledger posting)
- Pre-close validation: all subledger accounting journals transferred and posted to GL
- Consolidation: validate child ledger period close before consolidation ledger close
- Run `GL_SUBLEDGER_TRANSFER_CHECK` to identify journals not yet transferred from subledgers

**Chart of Accounts & Account Validation**
- Detect disabled account code combinations still referenced in open transactions
- Validate cross-validation rules are not blocking valid combinations
- Parent segment value hierarchy integrity: no circular parent-child relationships
- Natural account type consistency: revenue accounts used for expense, etc.
- Summary account template validation

**Financial Reporting (OTBI / FSG equivalent)**
- Validate OTBI financial reporting subject area queries return balanced results
- Detect custom GL reports broken by quarterly update (field renaming, subject area changes)
- SmartView query performance: identify queries consistently exceeding 60-second runtime

**7.3.4 Fixed Assets (FA) Sub-Agent**

*Fusion Diagnostic Tests*: `FA_CONFIGURATION_CHECK`, `FA_DEPRECIATION_CHECK`, `FA_PERIOD_CLOSE_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/fixedAssets`, `/assetAdditions`, `/depreciationRuns`

*Features*:
- **Asset Book Configuration**: Validate corporate and tax book setup (fiscal year, calendar, prorate convention, current period); detect misconfigured books for the current Fusion release
- **Depreciation Run Status**: Verify depreciation has completed for the current period; detect run in ERROR or INCOMPLETE status; retrieve depreciation error log
- **Mass Additions Queue**: Identify mass additions (from Payables or Projects) pending review/posting; detect stale mass additions (older than configured threshold)
- **Asset Retirement Analysis**: Detect retirement transactions in PENDING state; verify gain/loss calculation completeness
- **CIP (Capital in Progress)**: Identify CIP assets past expected capitalization date not yet capitalized; detect CIP assets with no project linkage
- **Asset Impairment**: Validate impairment assessment completeness for assets flagged for review
- **FA to GL Reconciliation**: Compare asset net book value (from FA REST API) vs. GL asset and accumulated depreciation account balances (via OTBI) — detect out-of-balance condition
- **EMEA/Global Compliance**: Statutory book validation for UK, France, Germany, Italy; detect country-specific depreciation method compliance issues

**7.3.5 Cash Management (CE) Sub-Agent**

*Fusion Diagnostic Tests*: `CE_CONFIGURATION_CHECK`, `CE_RECONCILIATION_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/bankStatements`, `/bankTransactions`

*Features*:
- **Bank Statement Import Health**: Detect bank statement imports pending processing beyond threshold; retrieve BAI2/MT940 import error logs
- **Auto-Reconciliation Status**: Identify bank statement lines not auto-reconciled; categorize by failure reason (amount mismatch, date tolerance, transaction code mapping)
- **Manual Reconciliation Queue**: Count and age unreconciled lines pending manual review
- **Bank Account Configuration**: Validate bank accounts have correct GL account assignments; detect bank accounts with expired access credentials for bank connectivity
- **Cash Forecast**: Validate cash forecast source configurations; detect forecast runs with errors
- **Clearing Account Analysis**: AP payment clearing, AR receipt clearing account reconciliation status

**7.3.6 Expenses Sub-Agent**

*Fusion Diagnostic Tests*: `EXP_CONFIGURATION_CHECK`, `EXP_AUDIT_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/expenseReports`

*Features*:
- **Expense Report Processing**: Detect expense reports in ERROR or PENDING_AUDIT status beyond SLA
- **Audit Queue Analysis**: Count reports awaiting manager and auditor approval; detect reports flagged for audit with no auditor assigned
- **Policy Violation Detection**: Identify reports with policy violations not addressed (auto-rejected vs. requires explanation)
- **Credit Card Statement Import**: Detect credit card transaction imports with errors; identify transactions not matched to expense lines
- **Expense Accounting**: Detect expense reports not accounted after approval; validate expense account distributions
- **Reimbursement Status**: Identify approved reports where payment has not been initiated
- **Receipt Requirement Compliance**: Detect expense lines above receipt threshold with no receipt attached

**7.3.7 Intercompany (AGIS) Sub-Agent**

*Fusion Diagnostic Tests*: `AGIS_CONFIGURATION_CHECK`, `INTERCOMPANY_BALANCE_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/intercompanyTransactions`

*Features*:
- **Intercompany Transaction Status**: Detect intercompany transactions in ERROR or PARTIALLY_PROCESSED status
- **Balance Validation**: Query intercompany receivables vs. intercompany payables across legal entities; detect imbalances
- **Netting Agreement Configuration**: Validate intercompany netting agreements are current and correctly configured
- **Elimination Rules**: Validate intercompany elimination journal rules for consolidation
- **Period Close Dependency**: Flag intercompany transactions not fully processed as period close blockers

**7.3.8 Subledger Accounting (SLA) Sub-Agent**

*Fusion Diagnostic Tests*: `SLA_ACCOUNTING_METHOD_CHECK`, `SLA_JOURNAL_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/subledgerAccountingEvents`

*Features*:
- **Accounting Method Assignment**: Validate all subledgers have accounting method assigned per ledger; detect missing assignments after quarterly update
- **Journal Entry Rule Set Completeness**: Identify JERs with missing line definitions for transaction event classes
- **Account Derivation Rule (ADR) Validation**: Validate ADR conditions reference valid value sets, accounting flexfield segments, and sources
- **Subledger Events in Error**: Query `XLA_ACCOUNTING_ERRORS` equivalent via diagnostic test; categorize error types
- **Accounting Definition Activation**: Verify Application Accounting Definitions (AADs) are complete and active
- **Post-Update AAD Impact**: Detect Oracle-seeded AAD changes in the quarterly update that may override customer customizations

**7.3.9 EB Tax Sub-Agent**

*Fusion Diagnostic Tests*: `EBTAX_CONFIGURATION_CHECK`, `EBTAX_DETERMINATION_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/taxRegimes`, `/taxRates`, `/taxJurisdictions`

*Features*:
- **Tax Configuration Completeness**: Validate tax regime → tax → rate → jurisdiction chain for all operating countries
- **Tax Determination Failure Analysis**: Query transactions with tax determination errors; categorize by missing configuration element
- **Party Tax Profile Validation**: Detect customers and suppliers missing Tax Registration Number or Tax Classification
- **Fiscal Classification**: Identify products/services with missing fiscal classifications causing tax calc failures
- **Tax Period Close**: Validate tax reporting is complete for the period; detect tax transactions not transferred to tax reporting
- **India GST**: GSTIN validation, HSN/SAC code completeness, e-invoice IRN configuration, ITC ledger balance
- **Latin America**: CNPJ/CPF, NF-e attributes, withholding tax configuration
- **US Sales Tax**: Vertex/Avalara third-party tax integration health (if configured)
- **Post-Update Tax Rules**: Detect tax rule changes introduced in quarterly update that may affect existing configurations

---

### 7.4 Procurement Agent

#### Purpose
Diagnoses Oracle Fusion Procurement: Purchasing, Sourcing, Supplier Portal, Procurement Contracts, and Self-Service Procurement. Procurement issues frequently cascade into AP (invoice match failures) and SCM (supply disruption).

#### Sub-Agents

**7.4.1 Purchasing Sub-Agent**

*Fusion Diagnostic Tests*: `PO_CONFIGURATION_CHECK`, `PO_APPROVAL_CHECK`, `PO_PERIOD_CLOSE_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/purchaseOrders`, `/purchaseRequisitions`

*Features*:

**Purchase Order Analysis**
- Detect POs with all lines cancelled but header still OPEN (should be FINALLY_CLOSED)
- Identify POs with no receipts past expected receipt date
- PO approval stuck: workflow tasks aging beyond SLA in BPM worklist
- PO lines with overbilling indicator (received > ordered + tolerance)
- Change order analysis: POs with pending change orders not approved
- Blanket Purchase Agreements (BPAs): utilization vs. limit; agreements expiring within 30 days
- Contract Purchase Agreements: detect releases exceeding contract maximum amount

**Receiving Analysis**
- Receiving transactions in interface error status
- 3-way match failures: price variance beyond tolerance, quantity variance beyond tolerance
- Inspection-required items with pending inspection results
- Consignment stock: consumption recording failures
- Landed cost adjustment: detect receipts with unprocessed landed cost adjustments

**Requisition Analysis**
- Requisitions in pending approval beyond SLA threshold
- Requisitions not auto-sourced (auto-sourcing rule failures or no active agreement)
- Internal requisitions: internal sales order not created from approved requisition
- Requisition approval hierarchy gaps: detect requisitions with no approver configured for amount
- Budget consumption: requisitions that exceed budget and are held pending override

**7.4.2 Sourcing Sub-Agent**

*Fusion Diagnostic Tests*: `SOURCING_CONFIGURATION_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/negotiationHeaders`

*Features*:
- Detect negotiations past award decision date with no award made
- Identify negotiations in DRAFT status older than threshold (abandoned drafts)
- Award approval stuck in BPM workflow
- Negotiation team configuration: detect negotiations with no active owner
- Supplier invitation failures: invited suppliers with IDCS self-registration errors

**7.4.3 Supplier Portal & Lifecycle Sub-Agent**

*Fusion Diagnostic Tests*: `SUPPLIER_CONFIGURATION_CHECK`, `SUPPLIER_REGISTRATION_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/suppliers`, `/supplierRegistrations`

*Features*:
- **Supplier Registration**: Detect supplier self-registration requests pending approval beyond SLA
- **IDCS Provisioning**: Validate supplier portal users have correct IDCS app roles provisioned
- **Supplier Qualification**: Detect qualifications expiring within 30/60 days
- **Bank Account Verification**: Suppliers with unverified bank accounts blocking payment
- **Supplier Merge**: Detect partially completed supplier merges
- **Preferred Supplier List**: Validate preferred supplier list currency and coverage
- **iSupplier Portal Access**: Verify supplier portal login functionality for key suppliers

**7.4.4 Procurement Contracts Sub-Agent**

*Fusion Diagnostic Tests*: `PROCUREMENT_CONTRACTS_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/contractHeaders`

*Features*:
- Contracts expiring within 30/60/90 days with no renewal initiated
- Contracts pending approval beyond SLA
- Contract deliverable milestones past due date with no completion recorded
- Clause library configuration: detect contracts referencing retired clause versions

---

### 7.5 Projects Agent

#### Purpose
Diagnoses Oracle Fusion Project Management: Project Costing, Project Billing, Grants Management, Project Control (budgets, forecasts, fund check), and Resource Management.

#### Sub-Agents

**7.5.1 Project Foundation Sub-Agent**

*Fusion Diagnostic Tests*: `PJF_CONFIGURATION_CHECK`, `PROJECT_STRUCTURE_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/projects`, `/projectTasks`

*Features*:
- **Project Status Validation**: Detect projects in PENDING_CLOSE status with outstanding transactions
- **Task Structure Integrity**: Identify tasks with invalid date ranges (task end before start, task extends beyond project end)
- **Project Organization Assignment**: Detect projects with no owning organization or resource pool
- **Project Template Validity**: Validate project templates are complete and not referencing inactive rate schedules
- **Role-Based Project Security**: Validate project team member assignments align with project access requirements

**7.5.2 Project Costing (PJC) Sub-Agent**

*Fusion Diagnostic Tests*: `PJC_COST_DISTRIBUTION_CHECK`, `PJC_ACCOUNTING_CHECK`, `PJC_IMPORT_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/projectExpenditures`, `/projectCostDistributions`

*Features*:
- **Expenditure Distribution Status**: Detect expenditure items in DISTRIBUTE status for > threshold (cost distribution process stuck)
- **Cost-to-GL Transfer**: Identify project costs not yet transferred to GL journal entries; detect transfer program ESS failures
- **Burden Schedule Validation**: Validate burden cost codes, schedules, and multipliers are current; detect expired burden schedules with active projects
- **Capital (CIP) Processing**: Detect CIP assets not transferred to Fixed Assets; validate FA mass additions queue for project origin items
- **P2P (Procure-to-Pay) Validation**: Validate PO commitments are correctly flowing to project budget; detect PO receipts not linked to project tasks
- **Cost Import Errors**: Retrieve and categorize errors from project cost import ESS jobs (FBDI-based or integration-sourced)
- **Cross-Charge**: Validate cross-charge rules; detect cross-charged costs not creating offsetting entries in borrowing organization

**7.5.3 Project Billing (PJB) Sub-Agent**

*Fusion Diagnostic Tests*: `PJB_BILLING_CHECK`, `PJB_REVENUE_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/projectBillingEvents`, `/projectInvoices`

*Features*:
- **Unbilled Events**: Detect billing events past billing cycle date not yet included in draft invoice
- **Draft Invoice Status**: Identify invoices in DRAFT status not submitted for approval; detect invoices rejected by approver
- **Revenue Recognition**: Detect incomplete revenue recognition for earned milestones; percent-complete method accuracy
- **Contract Funding Validation**: Validate cumulative recognized revenue vs. contract funding limit
- **Credit Memo Processing**: Detect credit memos generated but not transferred to AR
- **Interproject Billing**: Validate internal billing between projects in different legal entities

**7.5.4 Grants Management Sub-Agent**

*Fusion Diagnostic Tests*: `GMS_CONFIGURATION_CHECK`, `GMS_COMPLIANCE_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/grants`, `/awardBudgets`

*Features*:
- **Award Setup Validation**: Validate sponsor, terms and conditions, period of performance, budget structure
- **Cost Allowability**: Detect expenditure items charged to award that violate allowability rules (restricted cost categories)
- **Budget Compliance**: Detect transactions causing budget overrun on hard-limited awards
- **Award Closeout Checklist**: Generate closeout readiness — outstanding costs, pending invoices, budget remaining
- **Reporting Deliverables**: Detect financial and technical reporting deliverables past due date

**7.5.5 Project Control Sub-Agent**

*Fusion Diagnostic Tests*: `PJC_BUDGET_CHECK`, `PJC_FORECAST_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/projectBudgets`, `/projectForecasts`

*Features*:
- **Budget Baseline Validation**: Detect projects with no current baseline budget (fund check cannot operate)
- **Fund Check Configuration**: Validate control budget levels (HARD/SOFT); detect incorrectly configured control levels by expenditure type
- **Transactions Failing Fund Check**: Identify transactions on hold due to fund check failure; categorize by amount and project
- **Forecast Accuracy**: Compare forecast vs. actual at project completion (for active projects near end date)

---

### 7.6 Supply Chain Management (SCM) Agent

#### Purpose
Diagnoses Oracle Fusion SCM: Inventory, Order Management, Manufacturing, Procurement (shared with Procurement Agent for P2P aspects), Logistics, and Product Lifecycle Management (PLM).

#### Sub-Agents

**7.6.1 Inventory (INV) Sub-Agent**

*Fusion Diagnostic Tests*: `INV_CONFIGURATION_CHECK`, `INV_TRANSACTION_CHECK`, `INV_RECONCILIATION_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/inventoryItems`, `/inventoryTransactions`, `/inventoryBalances`

*Features*:

**Item Master Analysis**
- Detect items with incomplete organization-level attribute assignments (Inventory, Purchasing, Receiving, Costing, Planning controls)
- Validate item category assignments across all mandatory category sets
- UOM conversion errors: detect items where primary UOM conversion to secondary/catch-weight UOM is missing
- Duplicate item detection across organizations
- Item structure (BOM) completeness: items configured as Make but no BOM exists
- Serial/lot controlled items without adequate traceability setup

**Transaction Processing**
- Detect inventory transactions in pending interface status (not yet processed into inventory)
- Identify pending transfer orders not shipped or received beyond threshold
- Interorganization transfers: detect shipments not received by destination org beyond transit lead time
- Consignment inventory: detect ownership transfer transactions not processed
- Cycle count adjustments pending approval beyond threshold

**Cost Accounting (Fusion Costing)**
- Detect inventory transactions not yet costed
- Standard cost variance analysis: detect items with > threshold purchase price variance
- Cost adjustment processing: detect adjustment runs in ERROR status
- COGS recognition: detect shipments where COGS event not generated

**Reconciliation**
- Inventory valuation vs. GL inventory account balance (via OTBI cross-subject-area query)
- Detect manual GL journals posted to inventory accounts (bypassing Fusion costing)

**7.6.2 Order Management (OM/OMS) Sub-Agent**

*Fusion Diagnostic Tests*: `OM_CONFIGURATION_CHECK`, `OM_FULFILLMENT_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/salesOrders`, `/orderLines`, `/fulfillmentLines`

*Features*:

**Order Fulfillment Analysis**
- Detect sales order lines stuck in orchestration process steps (AWAITING_SHIPPING, AWAITING_BILLING, AWAITING_RECEIVING)
- Identify fulfillment lines with orchestration errors; retrieve error details from orchestration process log
- Past-due ship date analysis: lines with committed ship date in past and status not shipped
- Backorder volume and aging: count and value of lines on backorder
- ATP (Available to Promise) failure analysis: orders that could not be promised due to insufficient supply

**Order Processing**
- Detect orders in ENTERED status not booked (incomplete order entry — missing required fields)
- Credit check holds: volume and aging of orders on credit check hold
- Payment authorization holds: orders pending payment capture authorization
- Manual hold analysis: orders on custom holds categorized by hold reason code and owner

**Shipping & Logistics**
- Shipment requests not yet interfaced to shipping
- Pick wave creation failures
- Ship confirm errors: identify shipment exceptions in Shipping Execution
- Freight cost setup: validate freight charge calculation rules
- Carrier integration: detect third-party carrier API failures

**Pricing Analysis**
- Orders with manual price overrides exceeding approval limits
- Price list expiry: detect active orders referencing expired price lists
- Discount approval holds: discounts requiring approval not yet actioned

**Returns (RMA)**
- RMA lines past return authorization date with no material received
- Return receipts processed but credit memo not generated in AR
- Exchange orders not fulfilled within SLA

**7.6.3 Manufacturing Sub-Agent**

*Fusion Diagnostic Tests*: `MFG_CONFIGURATION_CHECK`, `WIP_TRANSACTION_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/workOrders`, `/productionExceptions`

*Features*:
- **Work Order Status**: Detect work orders in ERROR or ON_HOLD status; categorize exceptions
- **Material Availability**: Identify work orders with component shortages blocking release to production
- **Resource Availability**: Detect work orders requiring resources that are over-capacity for planned start date
- **WIP Transactions**: Detect component issue transactions in interface error status
- **Scrap Processing**: Identify scrap transactions not yet posted to costing
- **Outsourced Manufacturing (OSP)**: Detect outside processing POs not matched to work order operations
- **Production Schedule**: Detect production schedule deviations (planned vs. actual completion) exceeding threshold
- **Quality Inspections**: Detect work orders with failed quality inspections blocking completion

**7.6.4 Product Lifecycle Management (PLM) Sub-Agent**

*Fusion Diagnostic Tests*: `PLM_CONFIGURATION_CHECK`, `PLM_CHANGE_ORDER_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/changeOrders`, `/itemRevisions`

*Features*:
- Change orders pending approval beyond SLA
- Effectivity date conflicts: two approved change orders with overlapping effectivity for same item attribute
- Item structure changes not yet implemented in target organizations
- PLM-to-SCM synchronization: detect item revisions not yet synchronized to Fusion SCM

**7.6.5 Logistics Sub-Agent**

*Fusion Diagnostic Tests*: `WMS_CONFIGURATION_CHECK`, `RECEIVING_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/receiptHeaders`, `/shipmentLines`

*Features*:
- Receipts pending put-away in warehouse (lot/serial controlled items queued)
- ASN (Advance Shipment Notice) not yet received within expected window
- Warehouse management task execution errors
- Delivery trip and stop status: open trips not closed within transit time
- Carrier freight invoice matching exceptions

---

### 7.7 Human Capital Management (HCM) Agent

#### Purpose
Diagnoses Oracle Fusion HCM: Core HR, Payroll, Benefits, Talent (Recruiting, Performance, Succession, Learning), Compensation, Absence Management, and Time & Labor. HCM issues carry regulatory compliance risk — payroll errors, benefits gaps, and legal reporting failures have direct financial and legal consequences.

#### Sub-Agents

**7.7.1 Core HR Sub-Agent**

*Fusion Diagnostic Tests*: `HR_CONFIGURATION_CHECK`, `WORKER_DATA_INTEGRITY_CHECK`, `HR_SECURITY_CHECK`
*REST APIs*: `/hcmRestApi/resources/latest/workers`, `/workerAssignments`, `/positions`

*Features*:

**Worker Record Integrity**
- Detect workers with future-dated terminations but active assignments (effective dating conflicts)
- Identify terminated workers with active payroll relationships not ended
- Detect workers missing mandatory attributes: legal employer, payroll, business unit, position
- Duplicate person detection: same national identifier (SSN, NI, etc.) across multiple person records
- Hire date conflicts: assignment effective start date before hire date
- Rehire validation: detect rehired workers with incorrect prior period effective dating

**Organization Hierarchy**
- Position hierarchy: detect circular reporting relationships (A reports to B, B reports to A)
- Department hierarchy completeness: detect departments with no parent in the hierarchy
- Legal employer configuration: validate legislative data group assignments
- Grade and step configuration: detect grades with invalid progression rules

**Person-Level Security**
- HR Security Profile validation: validate profile covers intended set of workers
- Detect users who can access HR records outside their intended organization scope
- Area of Responsibility (AOR) setup: validate HR specialist AOR assignments cover all workers they support

**Legislative Data Group (LDG)**
- Validate LDG assignments match the country-specific payroll and HR rules required
- Detect workers assigned to incorrect LDG for their work location

**7.7.2 Payroll Sub-Agent**

*Fusion Diagnostic Tests*: `PAYROLL_PROCESS_CHECK`, `PAYROLL_COSTING_CHECK`, `PAYROLL_PAYMENT_CHECK`, `PAYROLL_CONFIGURATION_CHECK`
*REST APIs*: `/hcmRestApi/resources/latest/payrollFlows`, `/payrollRuns`, `/payrollCalculations`

*Features*:

**Payroll Run Analysis**
- Detect payroll flow tasks in ERROR status; retrieve task error message and assignment details
- Identify payroll flows stuck in SUBMITTED or WAITING status beyond threshold (hung ESS jobs)
- Zero net pay detection: assignments where net pay = 0 that shouldn't be (setup error)
- Negative net pay detection: assignments with negative gross requiring overpayment investigation
- Missing payment: assignments processed but not included in prepayment run
- Retropay events not yet processed: backdated pay changes generating retro events

**Payroll Configuration Validation**
- Validate element setup: elements missing input values, formula associations, or balance feeds
- FastFormula compilation: detect formulas with compile errors in current release
- Payroll calendar validation: detect payroll periods not generated for required dates
- Consolidation set completeness: validate all payrolls are included in consolidation sets
- Statutory deductions: validate PAYE/NIC (UK), FICA (US), etc. elements are correctly linked

**Costing Validation**
- Payroll costing run status: detect costing ESS jobs in ERROR
- Detect uncostable elements (elements flagged for costing but no cost account assigned)
- Cost allocation: detect overrides with expired accounting flexfield combinations
- GL transfer: detect costing results not yet transferred to GL journal entries

**Payment Processing**
- Prepayment run status: detect prepayment not completed before check/EFT generation SLA
- Bank account validation: detect employees with missing or invalid bank accounts for direct deposit
- Third-party payments: detect child support, garnishment payments not processed
- Payment file generation: detect EFT/check file generation failures

**Legislative Compliance**
- Year-end reporting readiness (W-2/W-2c US, P60/P11D UK, T4/T4A Canada, etc.)
- Detect missing year-end setup (tax reporting unit configuration, balance initialization)
- Legislative patch application: detect if required legislative updates for the current tax year are applied

**7.7.3 Benefits (BEN) Sub-Agent**

*Fusion Diagnostic Tests*: `BEN_CONFIGURATION_CHECK`, `BEN_ENROLLMENT_CHECK`, `BEN_ELIGIBILITY_CHECK`
*REST APIs*: `/hcmRestApi/resources/latest/benefitEnrollments`, `/lifeEvents`, `/benefitPlans`

*Features*:
- **Life Event Processing**: Detect participants with open life events not processed within enrollment deadline; categorize by life event type and days overdue
- **Open Enrollment**: Detect participants with no elections made during open enrollment; identify those needing default enrollment applied
- **Plan Configuration**: Validate plan year, coverage start rules, waiting period rules, dependent coverage rules
- **Eligibility Determination**: Detect workers who should be eligible but are not (eligibility rule gaps); and enrolled workers who are no longer eligible
- **ACA (Affordable Care Act) Compliance**: Detect employees who meet measurement period thresholds but haven't been offered coverage; 1095-C/1094-C reporting readiness
- **COBRA Administration**: Detect qualifying events (termination, reduction in hours) not triggering COBRA election notices
- **Coverage Rates**: Detect plan years with missing or expired cost/coverage rates
- **Carrier Interface (EDI 834)**: Detect benefits carrier file generation errors; enrollment delta not correctly included in 834 file
- **Beneficiary Designation**: Detect workers with life insurance or retirement plans but no beneficiary on file

**7.7.4 Recruiting (HCM Talent) Sub-Agent**

*Fusion Diagnostic Tests*: `RECRUITING_CONFIGURATION_CHECK`
*REST APIs*: `/hcmRestApi/resources/latest/jobRequisitions`, `/candidateApplications`

*Features*:
- Requisitions open beyond position target fill time
- Offers pending candidate acceptance beyond SLA
- Background check integration errors (third-party providers)
- Job posting synchronization failures (internal job board + external job sites)
- Onboarding task completion: detect new hires with overdue onboarding tasks

**7.7.5 Performance Management Sub-Agent**

*Fusion Diagnostic Tests*: `PERFORMANCE_CONFIGURATION_CHECK`
*REST APIs*: `/hcmRestApi/resources/latest/performanceDocuments`

*Features*:
- Performance document completion: detect employees with overdue self-evaluations or manager evaluations
- Calibration session setup: detect calibration sessions with no facilitator or no population
- Goal management: detect goal plans not published for the current review period
- Talent review: detect talent profiles with incomplete succession readiness ratings

**7.7.6 Compensation Sub-Agent**

*Fusion Diagnostic Tests*: `COMPENSATION_CONFIGURATION_CHECK`
*REST APIs*: `/hcmRestApi/resources/latest/compensationPlans`

*Features*:
- **Compensation Cycle**: Detect compensation plans in budget-setting phase with no budget submitted; detect cycles past publish date not yet published
- **Grade Rate Configuration**: Detect grades with missing salary ranges for effective date of compensation cycle
- **Worksheet Errors**: Detect manager worksheets with compensation entries exceeding budget threshold (blocked from approval)
- **Incentive Compensation**: Detect incentive calculation plan errors; commission payouts not generated for achieved quotas

**7.7.7 Absence Management Sub-Agent**

*Fusion Diagnostic Tests*: `ABSENCE_CONFIGURATION_CHECK`
*REST APIs*: `/hcmRestApi/resources/latest/absenceRecords`, `/accrualBalances`

*Features*:
- Accrual balance calculation errors: detect plans where accrual ESS jobs failed
- Negative accrual balance: detect workers with more time taken than accrued (policy violation or rule error)
- FMLA/Statutory leave compliance: detect leaves not categorized under required statutory type
- Absence plan enrollment: detect workers eligible for absence plan but not enrolled
- Carry-forward processing: detect year-end carry-forward ESS jobs in error

**7.7.8 Time & Labor Sub-Agent**

*Fusion Diagnostic Tests*: `OTL_CONFIGURATION_CHECK`, `TIME_CARD_CHECK`
*REST APIs*: `/hcmRestApi/resources/latest/timeCards`

*Features*:
- Time cards in SUBMITTED status not approved beyond SLA
- Time card transfer to Payroll: detect approved time cards not transferred within payroll calculation cut-off
- Overtime rule validation: detect time cards where overtime calculation did not apply
- Project time: detect time entered against projects where worker is not a team member
- Time collection device (TCD) integration: detect TCD punch imports in error

---

### 7.8 Customer Experience (CX) Agent

#### Purpose
Diagnoses Oracle Fusion CX: Sales (B2B/B2C), Service, Field Service, Marketing, and CPQ. CX issues directly affect customer-facing service quality and revenue capture.

#### Sub-Agents

**7.8.1 Sales (CX Sales) Sub-Agent**

*Fusion Diagnostic Tests*: `CX_SALES_CONFIGURATION_CHECK`, `CX_TERRITORY_CHECK`
*REST APIs*: `/crmRestApi/resources/latest/opportunities`, `/leads`, `/accounts`, `/salesQuotas`

*Features*:
- **Opportunity Pipeline Integrity**: Detect opportunities stalled in a stage beyond average stage duration; flag at-risk deals
- **Territory Management**: Validate territory assignment rules cover all accounts and geographies; detect accounts with no territory owner
- **Quota Assignment**: Detect sales representatives with no quota assigned for current fiscal period
- **Forecast Accuracy**: Compare forecast commits vs. actual closed amounts for prior periods; identify systematic over/under forecasting
- **Lead Assignment**: Detect leads not assigned within SLA threshold; validate lead routing rules
- **Account Deduplication**: Identify duplicate account records (same D-U-N-S or company name/address)
- **Customer Data Completeness**: Detect accounts missing industry, revenue size, or relationship owner
- **Sales Coach / Guided Selling**: Validate assessment criteria for sales methodology stages

**7.8.2 Service (CX Service / B2B Service) Sub-Agent**

*Fusion Diagnostic Tests*: `SERVICE_REQUEST_CHECK`, `SERVICE_CONFIGURATION_CHECK`, `SLA_RULE_CHECK`
*REST APIs*: `/crmRestApi/resources/latest/serviceRequests`, `/serviceRequestMessages`

*Features*:

**Service Request Analysis**
- Detect SRs with no activity for > SLA threshold (risk of breach)
- SLA milestone analysis: first response SLA, resolution SLA — detect breaches and near-misses
- Queue analysis: unassigned SRs by priority and queue; detect queues with no available agents
- Escalation rule validation: verify escalation rules are firing correctly for aging SRs
- Detect SRs assigned to deactivated agents (no owner to respond)
- Duplicate SR detection: same customer, same issue category, within proximity time window

**Knowledge Management**
- Published article expiry: detect articles past review date with no re-certification
- Search index: validate knowledge search index is current; detect index rebuild failures
- Article quality: detect articles with no solve rate in the last 90 days (low-value content)

**Channel Configuration**
- Email-to-Case: validate inbound email channel is processing correctly; detect mailbox connection failures
- Chat: validate chat routing configuration and agent availability rules
- Web form: detect web SR submission form configuration issues

**7.8.3 Field Service (CX Field Service) Sub-Agent**

*Fusion Diagnostic Tests*: `FSM_CONFIGURATION_CHECK`, `FSM_SCHEDULING_CHECK`
*REST APIs*: `/crmRestApi/resources/latest/workOrders`, `/fieldServiceActivities`

*Features*:
- **Activity Scheduling**: Detect field service activities not scheduled within response time commitment by priority
- **Resource Calendar**: Validate resource working hours and time zones for correct scheduling
- **Parts Logistics**: Detect required parts not reserved on high-priority activities; identify stocked-out parts
- **Debrief Completion**: Detect activities completed but not debriefed (service charges not generated)
- **Travel Time Estimation**: Validate travel time rules for geographic territory
- **Mobile App Sync**: Detect synchronization failures between field agents and server (offline mode conflicts)
- **Service Contract Coverage**: Validate entitlements — detect activities booked outside warranty/contract coverage
- **SLA Compliance**: Activities breaching committed response time / fix time

**7.8.4 Marketing (CX Marketing) Sub-Agent**

*Fusion Diagnostic Tests*: `MARKETING_CONFIGURATION_CHECK`
*REST APIs*: `/crmRestApi/resources/latest/campaigns`, `/marketingLeads`

*Features*:
- Campaign target audience: detect campaigns with empty or invalid segment definitions
- Email deliverability: detect campaigns with high bounce rates or spam filter flags
- Budget tracking: detect campaigns overrun vs. approved budget
- Lead scoring: detect leads with no score assigned (scoring model not executed)
- Campaign response: detect campaign responses not converting to leads within expected rate

**7.8.5 CPQ (Configure, Price, Quote) Sub-Agent**

*Fusion Diagnostic Tests*: `CPQ_CONFIGURATION_CHECK`
*REST APIs*: `/crmRestApi/resources/latest/quotes`

*Features*:
- **Quote Processing**: Detect quotes stuck in pricing or approval state beyond SLA
- **Product Configurator**: Validate configuration rules for complex configured items; detect invalid constraint errors blocking configuration
- **Pricing Engine**: Detect price list synchronization failures between CPQ and Order Management
- **Approval Rules**: Detect quotes requiring approval with no approver configured for discount threshold
- **CRM-to-ERP Handoff**: Detect quotes converted to orders but not successfully created in Fusion Order Management

---

### 7.9 Integration & Platform Extension Agent

#### Purpose
Diagnoses Oracle Integration Cloud (OIC), REST API health, VBCS extensions, and Fusion-to-third-party integration flows. In modern Fusion environments, integration failures are a top-5 cause of business process disruption.

#### Sub-Agents

**7.9.1 Oracle Integration Cloud (OIC) Sub-Agent**

*APIs*: OIC REST Management API (`/ic/api/integration/v1/integrations/`, `/monitoring/`)
*Auth*: OAuth 2.0 via IDCS

*Features*:

**Integration Flow Health**
- Retrieve all active OIC integrations; identify flows in ERROR or SUSPENDED state
- For each failed flow: retrieve last N failed instances with error message and fault details
- Categorize failures: connection failure, business logic error, mapping error, partner system timeout
- Dead message queue analysis: messages in fault state beyond retry limit
- Integration activation status: detect integrations deployed but not activated

**Connection Health**
- Test each registered OIC connection (Fusion REST, REST, SOAP, FTP, SFTP, Email, Database)
- Identify connections with expired credentials (OAuth token, API key, password)
- Validate SSL certificate expiry on connection endpoints
- Detect connections with elevated error rates in last 24 hours

**Message Volume & Performance**
- Message throughput by integration: compare current vs. baseline (detect volume drops indicating upstream failure)
- Latency analysis: integrations with average message latency > SLA
- Quota utilization: OIC message pack consumption vs. licensed volume
- Peak traffic patterns: identify hours with highest error rates

**Post-Update Compatibility**
- Detect Fusion REST API version changes in quarterly update that break existing OIC adapters
- Identify OIC integrations using deprecated API versions scheduled for removal
- Validate REST adapter connection configurations after Fusion URL/version changes

**Agent Behavior for OIC Health**:
```
1. GET /ic/api/integration/v1/integrations?status=ACTIVE → list all active integrations
2. GET /ic/api/integration/v1/monitoring/errors?timeRange=24h → get recent errors per integration
3. For each integration with errors:
   a. GET /ic/api/integration/v1/monitoring/instances/{id}/errors → retrieve error details
   b. Classify: CONNECTION | BUSINESS | MAPPING | TIMEOUT
   c. GET /ic/api/integration/v1/connections/{connId}/test → test connection health
4. Calculate error rate per integration: errors/total_messages in last 24h
5. Flag integrations with error rate > 5% as HIGH, > 20% as CRITICAL
6. Correlate OIC failures with Fusion module findings (e.g., AP invoice import failure ↔ OIC invoice integration error)
```

**7.9.2 REST API Health Sub-Agent**

*Features*:
- **Fusion REST API Availability**: Probe key Fusion REST endpoints across all pillars with lightweight GET requests; detect partial service unavailability
- **Rate Limit Monitoring**: Track 429 Too Many Requests responses per endpoint; advise integration throttling
- **API Version Deprecation**: Identify integrations calling v1/v2 endpoints where newer versions are available and old ones are scheduled for deprecation
- **CORS Configuration**: Validate CORS settings for VBCS/custom apps calling Fusion REST APIs from browser
- **OAuth Token Health**: Validate OAuth client credentials flows are working; detect token endpoint availability issues

**7.9.3 Visual Builder Cloud Service (VBCS) & Extensions Sub-Agent**

*Fusion Diagnostic Tests*: `VBCS_CONFIGURATION_CHECK`
*APIs*: VBCS Management REST API

*Features*:
- **VBCS Application Status**: Detect VBCS applications that are not live/deployed; detect deployment failures
- **Post-Update Extension Compatibility**: Identify VBCS extensions calling Fusion APIs that changed in the quarterly update
- **Sandbox Conflicts**: Detect VBCS extensions in sandbox that conflict with published configurations
- **Page Extension Errors**: Detect VBCS page extensions with JavaScript errors affecting user experience
- **REST Connection Validation**: Validate all REST connections within VBCS applications are functional

**7.9.4 File-Based Data Import (FBDI/HDL) Sub-Agent**

*Fusion Diagnostic Tests*: `FBDI_IMPORT_CHECK`, `HDL_IMPORT_CHECK`
*REST APIs*: `/fscmRestApi/resources/latest/erpintegrations` (FBDI), `/hcmRestApi/resources/latest/dataLoader` (HDL)

*Features*:
- **Import Job Status**: Retrieve all FBDI/HDL ESS jobs run in last 24/48 hours; categorize by status and record count
- **Error Log Analysis**: Fetch import error logs from UCM for failed jobs; parse and categorize errors (validation, duplicate, reference data missing)
- **Success Rate Tracking**: Calculate import success rate per job type; flag types with > threshold failure rate
- **Template Validation**: Validate FBDI/HDL file format against current Fusion release template (post-update template changes are a common regression)
- **Data Volume Analysis**: Detect import jobs with significantly higher than normal error volume (upstream data quality issue)
- **Reconciliation**: Validate record count in import file vs. records successfully created/updated in Fusion

---

## 8. Cross-Cutting Capabilities

### 8.1 Oracle Cloud Known Issues & MOS Integration

**Purpose**: Automatically cross-reference findings with Oracle Cloud Known Issues and MOS documentation for the current Fusion release.

**Data Sources**:
- **My Oracle Support (MOS)**: Traditional patch notes and known issues (`search_mos(keywords, module, release)`)
- **Oracle Cloud Known Issues Registry**: Release-specific known issues page maintained in agent Knowledge Base (refreshed after each quarterly update detection)
- **Oracle Update Release Notes**: What's New documents per module per release (parsed and indexed at agent startup)

**Capabilities**:
- For each finding, search both MOS and Cloud Known Issues by: symptom keywords, error codes, module, release version
- Return top-5 matching known issues with: issue ID, description, workaround, fix release target
- Determine if the finding is a known Oracle bug (→ raise Oracle SR) vs. customer configuration issue (→ provide customer remediation steps)
- Check if a known issue is listed as "Fixed in Release X" where X is already running (→ investigate why fix didn't apply)

**Tool**: `search_cloud_known_issues(symptoms, module, release)` → `KnownIssue[]`

### 8.2 Proactive Health Monitoring & Scheduling

**Purpose**: Scheduled autonomous health checks that detect issues before users report them.

**Monitoring Schedules**:
```json
{
  "schedule": {
    "every_15_minutes": ["ess_job_health", "oic_integration_errors"],
    "hourly": ["bpm_approval_queue_depth", "ess_queue_depth"],
    "daily": {
      "morning": ["full_platform_health", "security_audit", "certificate_expiry"],
      "evening": ["period_close_readiness_all_pillars", "fbdi_import_summary"]
    },
    "weekly": ["full_module_health_all_pillars", "sod_violation_report", "idcs_inactive_user_report"],
    "post_update": ["post_update_regression_full_suite"],
    "pre_close": {
      "5_days_before": ["period_close_readiness_warning"],
      "1_day_before": ["period_close_final_checklist"],
      "day_of": ["period_close_blocker_realtime"]
    }
  },
  "alert_thresholds": {
    "CRITICAL": ["pagerduty", "email", "slack"],
    "HIGH": ["email", "slack"],
    "MEDIUM": ["slack"],
    "LOW": ["weekly_digest_email"]
  }
}
```

**Fusion Release Update Detection**:
- After each scheduled run, compare `aboutInfo.releaseVersion` to stored value
- If changed → automatically trigger `post_update_regression_full_suite`
- Alert: "Fusion instance updated to release 25B. Running post-update validation suite..."

### 8.3 Root Cause Analysis Engine

**Purpose**: Distinguish root causes from symptoms across pillar boundaries using a pre-built causal graph.

**Pre-Defined Causal Chains (Fusion-Specific)**:
```
ESS_UNAVAILABLE
  → ALL_SCHEDULED_PROCESSES_BLOCKED
    → AP_ACCOUNTING_NOT_RUN → AP_CLOSE_BLOCKED
    → PAYROLL_FLOW_STUCK → PAYROLL_PAYMENT_DELAYED
    → INVENTORY_COSTING_NOT_RUN → COGS_NOT_RECOGNIZED

BPM_SOA_UNAVAILABLE
  → ALL_APPROVALS_STUCK
    → PO_NOT_APPROVED → RECEIVING_BLOCKED → AP_INVOICE_MATCH_FAILURE
    → EXPENSE_REPORT_NOT_APPROVED → EXPENSE_PAYMENT_DELAYED
    → JOURNAL_APPROVAL_STUCK → GL_CLOSE_BLOCKED

IDCS_FEDERATION_FAILURE
  → FUSION_SSO_LOGIN_BLOCKED → ALL_USERS_LOCKED_OUT → CRITICAL_ESCALATE

OIC_FUSION_CONNECTION_FAILURE
  → ALL_OIC_INTEGRATIONS_TO_FUSION_FAILED
    → SUPPLIER_INVOICE_IMPORT_STOPPED → AP_LIABILITY_GAP
    → BANK_STATEMENT_IMPORT_STOPPED → CE_RECONCILIATION_STALE

FBDI_TEMPLATE_VERSION_MISMATCH (post-update)
  → GL_JOURNAL_IMPORT_REJECTED
    → PERIOD_BALANCES_INCOMPLETE → FINANCIAL_REPORTING_INACCURATE

SLA_ACCOUNTING_METHOD_INACTIVE (post-update)
  → SUBLEDGER_ACCOUNTING_FAILED
    → AP_INVOICES_NOT_ACCOUNTED → AP_CLOSE_BLOCKED
    → AR_RECEIPTS_NOT_ACCOUNTED → AR_CLOSE_BLOCKED
```

**Engine Logic**:
1. Receive all findings from pillar agents
2. For each finding, look up its node in the causal graph
3. Traverse graph upward to find the root node (node with no incoming edges that has a finding)
4. Calculate confidence score: higher if multiple downstream symptoms are present
5. Output: root cause node, confidence %, full causal chain, which findings are symptoms vs. root cause

### 8.4 Remediation Engine (Fusion-Adapted)

**Purpose**: Provide and optionally execute Fusion-appropriate remediation actions.

**Remediation Tiers**:
- **Tier 1 — Auto-Fix via REST API** (agent executes with user confirmation): Submit ESS job to run Create Accounting, resubmit failed import job, re-trigger OIC integration instance, unlock user account via IDCS API
- **Tier 2 — Guided Action** (agent provides exact UI navigation path or REST API call for human execution): Setup and Maintenance navigation instructions, specific configuration values to change, FBDI template correction guidance
- **Tier 3 — Process Guidance** (agent provides step-by-step manual checklist): Period close procedures, BPM workflow reconfiguration, role provisioning in IDCS
- **Tier 4 — Oracle SR Required** (agent drafts SR with all evidence): Confirmed product bugs, ESS/platform issues, post-update regressions not in known issues list

**Oracle SR Auto-Draft**:
When Tier 4 is indicated, agent automatically composes a pre-filled Oracle Support SR with:
- Problem description (generated from finding)
- Fusion release version
- Steps to reproduce
- Relevant diagnostic test output attached
- API response evidence
- Business impact statement
- Severity recommendation (based on finding severity)

### 8.5 Multi-Tenant Instance Management

**Purpose**: Manage diagnostics across multiple Fusion cloud instances.

**Capabilities**:
- Maintain connection profiles for: PROD, TEST, UAT, DR, Implementation (multiple environments)
- Configuration comparison: diff any two instances (Setup and Maintenance configuration via REST API comparison)
- Post-clone/refresh validation: after TEST instance refresh from PROD, run post-refresh checklist (OIC re-point, IDCS federation re-map, integration endpoint reconfiguration)
- Release delta: identify configuration differences between a UAT instance on the upcoming release vs. PROD on current release

### 8.6 Audit & Compliance Reporting

**Purpose**: Full audit trail for all diagnostic sessions plus formal compliance reports.

**Capabilities**:
- Every API call logged: timestamp, agent, HTTP method, endpoint, response status, duration, response excerpt
- Session replay: reconstruct exactly what was queried and found in any historical session
- Compliance report templates:
  - **SOX IT General Controls**: Access management (IDCS user review), change management (Sandbox tracking), segregation of duties (SoD violation report)
  - **ISO 27001**: Security configuration, access logs, incident response documentation
  - **GDPR Data Processing**: Identify Fusion modules processing personal data; access log for HR/CX data
- Periodic user access review automation: export all active Fusion users + roles + last login date for manager certification workflow
- Role change tracking: compare current IDCS role assignments vs. prior week's baseline; flag new grants to sensitive roles

### 8.7 Fusion Release Lifecycle Management

**Purpose**: Manage the agent system's own awareness of Fusion quarterly updates.

**Capabilities**:
- **Release Registry**: Stores per-release metadata: release code, GA date, known issues, opt-in features, deprecated APIs, changed setup tasks
- **Update Detection**: Automatically detects when Fusion instance is updated to new release
- **Regression Test Library**: Module-by-module test library of configurations known to regress during updates; updated by agent team after each quarterly release analysis
- **Opt-In Feature Tracking**: For each new opt-in feature, record: customer decision (enable/disable), date decided, rationale — supports annual opt-in review
- **API Deprecation Tracker**: Track which deprecated APIs are in use by active OIC integrations; alert N releases before removal

---

## 9. Tool & Integration Requirements

### 9.1 Core Agent Tools (All Pillar Agents)

| Tool Name | Description | Input | Output |
|---|---|---|---|
| `run_fusion_diagnostic_test` | Execute a Fusion Diagnostic Test via REST API | test_code, test_inputs, instance | DiagnosticTestResult |
| `call_fusion_rest_api` | Call any Fusion REST API endpoint | method, endpoint, params, body, instance | APIResponse |
| `call_fusion_soap` | Call Fusion SOAP web service | wsdl_endpoint, operation, soap_body | SOAPResponse |
| `submit_ess_job` | Submit ESS Scheduled Process | job_definition, params, instance | ESS_RequestID |
| `poll_ess_job` | Poll ESS job status until completion | request_id, instance, timeout | ESS_JobStatus |
| `get_ess_output` | Retrieve ESS job output from UCM | request_id, instance | OutputDocument |
| `run_otbi_analysis` | Execute OTBI analysis or report | analysis_path, filters, instance | OTBIResult |
| `run_bip_report` | Execute BI Publisher report | report_path, params, format, instance | BIPReportDocument |
| `upload_fbdi_file` | Upload FBDI zip to UCM + submit import ESS | file_path, job_name, params | ESS_RequestID |
| `upload_hdl_file` | Upload HDL .dat file + submit HCM Data Loader | file_path, params | ESS_RequestID |
| `parse_essjob_log` | Parse and categorize ESS job error log | log_content | ParsedErrors[] |
| `parse_fbdi_error_log` | Parse FBDI/HDL import error log | log_content, job_type | ImportErrors[] |
| `call_idcs_api` | Call IDCS/OCI IAM REST API | method, endpoint, params, idcs_tenant | IDCSResponse |
| `call_oic_api` | Call OIC Management REST API | method, endpoint, oic_instance | OICResponse |
| `test_oic_connection` | Test OIC connection health | connection_id, oic_instance | ConnectionTestResult |
| `search_mos` | Search My Oracle Support | keywords, release, module | MOSNote[] |
| `search_cloud_known_issues` | Search Cloud Known Issues registry | symptoms, release, module | KnownIssue[] |
| `get_fusion_release` | Get current Fusion release from instance | instance | FusionRelease |
| `store_finding` | Persist finding to audit store | finding, session_id | FindingID |
| `generate_report` | Create incident report | findings[], format, template | IncidentReport |
| `draft_oracle_sr` | Compose Oracle Support SR draft | finding, session, evidence | SR_Draft |
| `send_alert` | Send alert to configured channel | finding, channel, recipients | AlertID |
| `compare_instances` | Compare Setup & Maintenance config across instances | instance_a, instance_b, module | ConfigDiff |

### 9.2 Fusion Authentication

- **OAuth 2.0 Client Credentials** flow via IDCS for machine-to-machine API access
- Tokens retrieved at session start; refreshed automatically on 401 response
- Separate OAuth client per environment (PROD, TEST, UAT) with minimal required scopes
- Client credentials stored in HashiCorp Vault / OCI Vault — never in agent code or logs
- Token cache: store access token with TTL matching expiry; refresh before expiry

### 9.3 OIC Authentication

- OIC Management API uses Basic Auth or OAuth 2.0 (IDCS-based)
- Separate OIC service account per instance
- OIC API calls rate-limited: agent enforces max 10 calls/second with exponential backoff on 429

### 9.4 Fusion REST API Rate Limiting

- Fusion enforces API throttling per tenant (typically 1,000 requests/minute for integrations)
- Agent implements: token bucket rate limiter, exponential backoff on 429, request prioritization (diagnostic API calls > reporting queries)
- Agent tracks and reports on API quota utilization per session

### 9.5 External Integrations

| Integration | Purpose | Protocol |
|---|---|---|
| My Oracle Support (MOS) | Patch and note search | REST API |
| Oracle Cloud Known Issues | Release-specific known issues | Web scrape / cached registry |
| Oracle Support Cloud | Auto-draft SR, attach evidence | REST API |
| OIC Management API | Integration health monitoring | REST API (IDCS OAuth) |
| IDCS / OCI IAM REST API | User/role/security diagnostics | REST API (Client Credentials) |
| OTBI SOAP/REST | Financial analytics queries | SOAP / REST |
| BIP Report REST API | Report execution | REST API |
| UCM (WebCenter Content) REST | ESS output retrieval, FBDI upload | REST API |
| Slack | Alert notifications | Webhook |
| PagerDuty | Critical alert escalation | REST API |
| ServiceNow / JIRA | Incident ticket creation | REST API |
| Oracle Analytics Cloud (OAX) | Advanced analytics dashboards | REST API |
| Email (SMTP) | Report distribution, SR notification | SMTP |

---

## 10. Data Requirements

### 10.1 Session & Audit Store

**Schema**:
```sql
sessions (
  id UUID PRIMARY KEY,
  user_id VARCHAR,
  fusion_instance_id VARCHAR,
  cloud_release VARCHAR,
  start_time TIMESTAMP,
  end_time TIMESTAMP,
  status VARCHAR,        -- ACTIVE | COMPLETED | FAILED
  intent_classification JSONB,
  workflow_plan JSONB,
  metadata JSONB
)

api_calls (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES sessions(id),
  agent_id VARCHAR,
  tool_name VARCHAR,
  http_method VARCHAR,
  endpoint TEXT,
  request_body JSONB,
  response_status INTEGER,
  response_excerpt TEXT,    -- First 2000 chars of response
  duration_ms INTEGER,
  timestamp TIMESTAMP
)

findings (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES sessions(id),
  pillar VARCHAR,
  module VARCHAR,
  severity VARCHAR,
  category VARCHAR,
  description TEXT,
  api_evidence JSONB,
  diagnostic_test_code VARCHAR,
  cloud_known_issue_id VARCHAR,
  mos_note_ids TEXT[],
  remediation JSONB,
  oracle_sr_required BOOLEAN,
  auto_fixable BOOLEAN,
  timestamp TIMESTAMP
)

alerts (
  id UUID PRIMARY KEY,
  finding_id UUID REFERENCES findings(id),
  channel VARCHAR,
  recipients TEXT[],
  sent_at TIMESTAMP,
  acknowledged_at TIMESTAMP,
  acknowledged_by VARCHAR
)

schedules (
  id UUID PRIMARY KEY,
  instance_id VARCHAR,
  check_type VARCHAR,
  cron_expression VARCHAR,
  last_run TIMESTAMP,
  next_run TIMESTAMP,
  enabled BOOLEAN,
  alert_threshold VARCHAR
)

fusion_release_registry (
  release_code VARCHAR PRIMARY KEY,  -- '25A', '25B', etc.
  ga_date DATE,
  known_issues JSONB,
  opt_in_features JSONB,
  deprecated_apis JSONB,
  changed_setup_tasks JSONB,
  regression_test_pack JSONB
)

instance_baselines (
  id UUID PRIMARY KEY,
  instance_id VARCHAR,
  pillar VARCHAR,
  configuration_snapshot JSONB,
  captured_at TIMESTAMP,
  cloud_release VARCHAR
)

sod_violations (
  id UUID PRIMARY KEY,
  session_id UUID REFERENCES sessions(id),
  user_id VARCHAR,
  role_a VARCHAR,
  role_b VARCHAR,
  rule_violated VARCHAR,
  detected_at TIMESTAMP,
  remediation_status VARCHAR  -- OPEN | ACKNOWLEDGED | REMEDIATED
)
```

### 10.2 Knowledge Base

- **Fusion Causal Graph**: Pre-built dependency graph of Fusion components (JSON graph format); updated quarterly
- **Diagnostic Test Catalog**: Full metadata for all 200+ Fusion Diagnostic Tests per release
- **Issue Pattern Library**: Known symptom → probable cause → resolution mappings (growing with each session)
- **SoD Rule Library**: Standard segregation of duties rules for Fusion roles (based on industry standards + Oracle recommendations)
- **FBDI Template Registry**: Per-release FBDI/HDL template definitions (for template validation)
- **API Version Map**: Per-release map of Fusion REST API version changes (field additions, renames, deprecations)
- **Cloud Known Issues Cache**: Indexed known issues per release (24-hour refresh)

### 10.3 Data Retention

| Data Type | Retention Period | Rationale |
|---|---|---|
| Session audit logs | 7 years | SOX compliance |
| API call logs | 3 years | IT audit |
| Finding history | 3 years | Trend analysis |
| SoD violation records | 7 years | SOX/compliance |
| Configuration baselines | Unlimited (point-in-time) | Change audit |
| Cloud Known Issues cache | 24-hour TTL | Freshness |
| OTBI report output | 30-day TTL | Storage efficiency |
| ESS job log extracts | 90-day TTL | Debugging reference |
| Fusion release registry | Permanent | Historical reference |

---

## 11. Security & Compliance

### 11.1 Authentication & Authorization

- Agent UI requires MFA via IDCS (federated with customer's identity provider)
- Role-based access: READ_ONLY / DIAGNOSE / REMEDIATE / ADMIN
- All Fusion API credentials (OAuth client ID/secret) stored in OCI Vault or HashiCorp Vault — never in code or environment variables in plaintext
- Session tokens expire after 8 hours of inactivity
- Agent activity tied to specific named user session (no shared/anonymous sessions)

### 11.2 API Credential Security

- OAuth 2.0 client credentials rotated every 90 days via automated Vault policy
- Minimum-scope OAuth clients: each agent has only the scopes required for its pillar
- IDCS client credentials (for IDCS Admin API) are separate, more restricted clients
- All API calls logged with credential ID (not the credential itself)
- Credential access audit: all retrievals from Vault logged

### 11.3 Data Privacy

- Fusion production data accessed only via read-only REST API calls (no data modification for diagnostics)
- PII fields masked in all agent outputs (employee SSN, DOB, salary, customer phone/email)
- Data classification: findings containing HCM data labeled as PII; CX data labeled as customer confidential
- GDPR: right-to-erasure requests honored in session audit store within 30 days
- Data residency: audit store deployed in same OCI region as Fusion instance (data residency compliance)

### 11.4 Network Security

- All Fusion REST API calls over HTTPS (TLS 1.2+)
- Agent server network policy: only allows outbound HTTPS to Fusion instance hostname, IDCS tenant, OIC endpoint
- OCI private endpoint / VCN peering used where available (no internet exposure of diagnostic API traffic)
- Certificate pinning on Fusion and IDCS endpoints (detect MITM)

### 11.5 Fusion-Specific Security Considerations

- Agent never stores APPS-equivalent passwords (no such concept in Fusion SaaS)
- Agent uses dedicated service account user in Fusion + IDCS (not shared with human users)
- Service account has minimum required Fusion roles for diagnostic test execution
- Diagnostic role required: `Application Diagnostics Administrator` (restricted to agent service account)
- IDCS Admin API: Agent uses dedicated IDCS Confidential Application with restricted admin scope

---

## 12. Non-Functional Requirements

### 12.1 Performance

| Operation | Target |
|---|---|
| Fusion Diagnostic Test execution (simple) | < 30 seconds |
| Fusion Diagnostic Test execution (complex) | < 3 minutes |
| Fusion REST API call (single record) | < 5 seconds |
| OTBI report execution | < 60 seconds |
| ESS job submission + result | < configured job SLA (max 15 min for diagnostic jobs) |
| Orchestrator routing (intent classification to first API call) | < 3 seconds |
| Full pillar health check (all diagnostic tests for one pillar) | < 20 minutes |
| Report generation (after all findings collected) | < 30 seconds |
| Parallel pillar agent execution | Support up to 7 parallel pillar agents |
| Post-update regression suite (all pillars) | < 2 hours |

### 12.2 Reliability

- Agent framework: 99.9% uptime (excluding Fusion cloud maintenance windows)
- All API calls: retry up to 3 times with exponential backoff; skip and flag if unavailable
- ESS job submission: handle 503 (Fusion under load) with backoff retry
- Circuit breaker: if Fusion instance returns 503 for > 60 seconds, halt and notify user
- All findings persisted before report generation (no data loss on agent failure)
- Fusion scheduled maintenance window awareness: suppress false-positive ESS/availability alerts during announced windows

### 12.3 Scalability

- Support up to 50 concurrent diagnostic sessions per agent deployment
- Horizontal scaling via stateless agent pool + shared session store (Redis/PostgreSQL)
- Support up to 30 registered Fusion instances (multiple customers or environments)
- API rate limiter is per-instance (respects each Fusion tenant's throttling limits independently)

### 12.4 Maintainability

- New Fusion Diagnostic Tests automatically discoverable via API catalog refresh (no code change)
- Agent prompts and routing logic version-controlled and deployable without restart
- Knowledge base (causal chains, issue patterns, SoD rules) updatable via admin UI
- Fusion release registry updated via structured JSON update file (deployed after each quarterly Fusion release)
- API version changes handled via configurable API version header per instance

---

## 13. Implementation Phases

### Phase 1 — Foundation (Weeks 1–8)
**Goal**: Platform agent and Orchestrator operational for the most common Fusion support scenario (ESS failures)

**Deliverables**:
- Orchestrator agent with intent classification, Fusion release detection, session management
- Platform Agent: ESS Sub-Agent, BPM Approval Sub-Agent, Diagnostics Framework Sub-Agent
- Fusion REST API client with OAuth 2.0 authentication and rate limiting
- Fusion Diagnostic Test execution tool
- OCI Vault / Vault credential management integration
- Session audit store (PostgreSQL schema)
- CLI interface (chat-based, JSON output)

**Acceptance**: Platform agent can identify a stuck ESS job, retrieve the error log, classify the failure type, and recommend remediation — entirely from a natural language prompt.

---

### Phase 2 — Financials (Weeks 9–16)
**Goal**: Full Financials agent covering all period-close-related sub-agents

**Deliverables**:
- Financials Agent: AP, AR, GL, FA, CE, Expenses, SLA, EB Tax sub-agents
- OTBI report execution tool
- BIP report execution tool
- Period close workflow: end-to-end close readiness report for all Financials subledgers
- MOS and Cloud Known Issues search integration
- HTML/PDF report generation
- Slack and email alert integration

**Acceptance**: System produces a complete Financials period close readiness report (AP + AR + GL + FA) from a single natural language request, with blocking items ranked by amount and remediation steps provided.

---

### Phase 3 — Procurement & Projects (Weeks 17–24)
**Goal**: Procurement and Projects agents, plus FBDI/HDL diagnostic tooling

**Deliverables**:
- Procurement Agent: Purchasing, Sourcing, Supplier Portal, Contracts sub-agents
- Projects Agent: PJF, PJC, PJB, Grants, Project Control sub-agents
- FBDI/HDL file upload and import error analysis tool
- Root cause analysis engine (causal graph v1 — Platform + Financials + Procurement chains)
- Cross-pillar correlation (Procurement → AP invoice match chain)
- Post-update regression sub-agent for Platform and Financials

**Acceptance**: System correctly identifies that an AP invoice match failure is caused by a PO approval BPM workflow stuck due to an ESS failure — tracing the full 3-pillar causal chain.

---

### Phase 4 — SCM & HCM (Weeks 25–32)
**Goal**: SCM and HCM agents operational, OIC integration monitoring live

**Deliverables**:
- SCM Agent: Inventory, Order Management, Manufacturing, PLM, Logistics sub-agents
- HCM Agent: Core HR, Payroll, Benefits, Talent, Compensation, Absence, Time & Labor sub-agents
- Integration Agent: OIC health monitoring, REST API health, VBCS compatibility sub-agents
- Proactive monitoring scheduler (all pillars, all schedule tiers)
- IDCS/OCI IAM security diagnostic tooling
- SoD violation detection (SoD rule library v1)
- Multi-instance management (compare, refresh validation)

**Acceptance**: Proactive monitor detects a payroll ESS job stuck and alerts via Slack before payroll engineers notice — 45 minutes before the processing deadline.

---

### Phase 5 — CX, Post-Update Regression & Compliance (Weeks 33–40)
**Goal**: CX agent, full post-update regression suite, compliance reporting, Oracle SR auto-draft

**Deliverables**:
- CX Agent: Sales, Service, Field Service, Marketing, CPQ sub-agents
- Post-update regression suite for all pillars
- Fusion Release Registry with full update lifecycle management
- Oracle SR auto-draft tool (pre-filled SR from finding evidence)
- Compliance report templates (SOX IT GC, GDPR, ISO 27001)
- User access review automation (periodic IDCS + Fusion role certification reports)
- Web UI (React/Vue chat interface with incident report viewer)
- ServiceNow / JIRA integration for ticket creation

**Acceptance**: After a quarterly Fusion update, system automatically runs the post-update regression suite, identifies a SLA accounting method that was deactivated by the update, drafts an Oracle SR with evidence, and alerts the administrator — all within 3 hours of the update completing.

---

## 14. Acceptance Criteria

### System-Level
- [ ] Agent correctly identifies the Fusion cloud release version on session start for 100% of connections
- [ ] Agent routes 95%+ of natural language requests to the correct pillar agent(s)
- [ ] All Fusion Diagnostic Tests available in the catalog can be executed via agent (200+ tests)
- [ ] All REST API calls include OAuth token (no unauthenticated calls ever reach Fusion)
- [ ] API rate limiter prevents 429 responses for 99%+ of API calls
- [ ] All tool calls logged in audit store within 200ms of completion
- [ ] Concurrent execution of 7 pillar agents does not degrade individual pillar response time by > 25%
- [ ] Post-update regression suite completes within 2 hours of update detection

### Module-Level (per pillar agent)
- [ ] Each pillar agent can execute all applicable Fusion Diagnostic Tests for its domain
- [ ] Each pillar agent produces structured FusionFinding objects with severity, evidence, and remediation tier
- [ ] Period close agents produce a go/no-go recommendation with blocking item list for AP, AR, GL, FA
- [ ] Root cause analysis correctly identifies root cause (vs. symptoms) in 5 pre-defined multi-pillar test scenarios
- [ ] OIC integration health agent correctly identifies connection failures and correlates with Fusion module findings
- [ ] FBDI/HDL error log parser correctly categorizes import errors into at least 5 error categories

### Security
- [ ] No OAuth credentials appear in any log file or API response excerpt
- [ ] All PII fields (employee SSN, salary, customer contact) masked in all agent outputs
- [ ] Agent service account in Fusion has only the minimum required roles (verified via IDCS role audit)
- [ ] All sessions expire after 8 hours of inactivity
- [ ] SoD violation detection identifies at least 3 standard conflict pairs in a seeded test environment

### Post-Update Regression
- [ ] Update detection triggers within 1 scheduled run of the Fusion update completing
- [ ] Post-update regression suite covers all 8 pillar agents
- [ ] Agent identifies at least 3 pre-defined regression scenarios seeded in a test instance

---

## 15. Glossary

| Term | Definition |
|---|---|
| AAD | Application Accounting Definition — defines the accounting rules for a Fusion subledger |
| ADR | Account Derivation Rule — rule defining how GL account segments are derived in SLA |
| AIC | Application Implementation Consultant (Oracle internal implementation methodology) |
| AMX | Approval Management Extension — Fusion's approval rule engine |
| AOR | Area of Responsibility — HR security concept limiting access to a subset of workers |
| BIP | BI Publisher — Oracle's report output and delivery tool |
| BPA | Blanket Purchase Agreement — a long-term PO agreement with a supplier |
| BPM | Business Process Management — Oracle's workflow engine used by Fusion for approvals |
| CORS | Cross-Origin Resource Sharing — browser security policy for API calls |
| ESS | Enterprise Scheduler Service — Fusion's job scheduling engine (equivalent to EBS Concurrent Programs) |
| FBDI | File-Based Data Import — bulk data loading mechanism for Fusion (CSV/ZIP files) |
| GCC | Global Campaign Center (CX Marketing) |
| HDL | HCM Data Loader — bulk data loading mechanism for Fusion HCM (.dat files) |
| IDCS | Oracle Identity Cloud Service — Oracle's cloud identity platform for Fusion authentication |
| JER | Journal Entry Rule Set — SLA component defining journal line rules |
| LDG | Legislative Data Group — organizational unit grouping payroll legislative rules by country |
| MCS | Mobile Cloud Service (deprecated but referenced in older Fusion configs) |
| MOS | My Oracle Support — Oracle's customer support and knowledge portal |
| OAX | Oracle Analytics Cloud — Oracle's cloud analytics platform |
| OCI | Oracle Cloud Infrastructure — Oracle's cloud infrastructure platform hosting Fusion |
| OIDC | OpenID Connect — modern identity federation protocol used by IDCS |
| OIC | Oracle Integration Cloud — Oracle's iPaaS platform for Fusion integrations |
| OSP | Outside Processing — manufacturing step performed by an external supplier |
| OTBI | Oracle Transactional Business Intelligence — Fusion's real-time reporting analytics tool |
| PPV | Purchase Price Variance — difference between PO price and standard cost |
| SAML | Security Assertion Markup Language — federation protocol for SSO between IDCS and Fusion |
| SLA | Subledger Accounting — accounting engine connecting Fusion subledgers to GL |
| SOA | Service Oriented Architecture — Oracle's middleware layer underpinning Fusion workflow |
| SoD | Segregation of Duties — control preventing one user from controlling an entire business process end-to-end |
| SR | Service Request — Oracle Support ticket |
| TCA | Trading Community Architecture — Fusion's master data framework for customers and suppliers |
| UCM | Universal Content Management (Oracle WebCenter Content) — Fusion's document repository |
| VBCS | Visual Builder Cloud Service — Fusion's low-code extension platform |
| VCN | Virtual Cloud Network — OCI private network |

---

*End of PRD — Oracle Fusion Cloud Support Agent System v1.0*
*Date: 2026-03-31*
*Fusion Releases Covered: 24A through 25B and subsequent quarterly updates*
