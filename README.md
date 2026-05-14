# Oracle EBS Support Agent

> **Built by [U2xAI](mailto:hello@u2xai.com)** — Specialists in Claude Code + Oracle ERP Integration

---

## About U2xAI

**U2xAI** is a technology consulting firm that specializes in integrating **Anthropic's Claude Code** with enterprise Oracle ERP systems. We bring deep expertise across the full Oracle stack — E-Business Suite, Fusion Cloud, and database technologies — combined with cutting-edge AI to transform how organizations manage, troubleshoot, and operate their mission-critical ERP platforms.

### What We Do

```
+-----------------------------------------------------------------------+
|                           U2xAI Expertise                              |
|-----------------------------------------------------------------------|
|                                                                        |
|   +------------------+    +-------------------+    +-----------------+ |
|   | Claude Code      |    | Oracle ERP        |    | AI-Powered      | |
|   | Integration      |    | Deep Knowledge    |    | Automation      | |
|   |                  |    |                   |    |                 | |
|   | - Claude API     |    | - EBS R12 / 12.2  |    | - Intelligent   | |
|   | - Tool Use       |    | - Fusion Cloud    |    |   diagnostics   | |
|   | - Agent SDK      |    | - Oracle DB 19c+  |    | - Auto triage   | |
|   | - MCP Servers    |    | - PL/SQL & Forms  |    | - Self-healing  | |
|   | - Multi-agent    |    | - OAF & Workflow  |    |   runbooks      | |
|   |   orchestration  |    | - Concurrent Mgr  |    | - Predictive    | |
|   |                  |    | - ADOP & Patching |    |   issue detect  | |
|   +------------------+    +-------------------+    +-----------------+ |
|                                                                        |
+-----------------------------------------------------------------------+
```

### Our Expertise

| Domain | Capabilities |
|--------|-------------|
| **Oracle EBS R12** | Full-stack support — Financials (AP, AR, GL, FA), Manufacturing (INV, BOM, WIP, ASCP), HCM (HR, Payroll), CRM, and Core ATG (Concurrent Processing, Workflow, OAF) |
| **Oracle Fusion Cloud** | Supply Chain Planning, Financials, Procurement, HCM — diagnostics, integration, and migration from EBS |
| **Claude Code / AI** | Custom AI agents using Anthropic's Claude API with tool_use, multi-agent orchestration, MCP server development, and agentic workflows for ERP operations |
| **Database & Infrastructure** | Oracle DB 19c/23ai, RAC, Data Guard, ADOP, patching automation, performance tuning, and cloud migration (OCI, AWS, Render) |
| **Integration** | JIRA, ServiceNow, Slack, and custom ticketing system integration with AI-powered triage and resolution |

### Why U2xAI?

- **20+ years of Oracle ERP experience** combined with AI-first engineering
- **Production-proven** — our agents handle real EBS environments with 370+ diagnostic analyzers
- **End-to-end delivery** — from architecture to deployment on cloud platforms (Render, OCI, AWS)
- **Not just chatbots** — we build agents that *execute*, *diagnose*, and *fix* real ERP issues with live database connectivity
- **Enterprise-ready** — demo mode for safe evaluation, full audit trails, JIRA integration, and PDF reporting

### Get in Touch

| | |
|---|---|
| **Email** | [hello@u2xai.com](mailto:hello@u2xai.com) |
| **Services** | Claude Code + Oracle ERP Integration, AI Agent Development, EBS/Fusion Support Automation, Cloud Migration |

---

## Oracle EBS Support Agent

**AI-powered support agent for Oracle E-Business Suite R12** built with Claude AI, Flask, and 370+ diagnostic SQL analyzers.

This application provides an intelligent conversational interface for diagnosing, analyzing, and resolving Oracle EBS issues across all major modules — Financials, Manufacturing, HCM, CRM, and Core ATG. It is a showcase of what U2xAI delivers — production-grade AI agents that connect directly to your Oracle environment and deliver actionable insights in seconds.

```
+------------------------------------------------------------------+
|                   Oracle EBS Support Agent                        |
|                                                                   |
|   "My AP invoices are stuck"                                      |
|                                                                   |
|   +----------------------------------------------------------+   |
|   |  Claude AI Orchestrator                                   |   |
|   |  - Understands the problem                                |   |
|   |  - Selects the right analyzer                             |   |
|   |  - Runs diagnostic SQL on your EBS database               |   |
|   |  - Returns findings with severity + remediation steps     |   |
|   +----------------------------------------------------------+   |
|                                                                   |
|   Findings:                                                       |
|   [CRITICAL] 47 invoices stuck in NEVER APPROVED status           |
|   [HIGH]     Missing approval hierarchy for 3 orgs                |
|   [MEDIUM]   Invoice tolerance not set for Org 204                |
|                                                                   |
|   Remediation: Navigate to AP > Setup > Invoice Tolerances ...    |
+------------------------------------------------------------------+
```

---

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Modules & Analyzers](#modules--analyzers)
- [Pages & UI](#pages--ui)
- [API Endpoints](#api-endpoints)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Deploying on Render](#deploying-on-render)
- [Project Structure](#project-structure)
- [Tech Stack](#tech-stack)

---

## Features

### AI-Powered Diagnostics
- Conversational chat interface powered by **Claude AI (Sonnet 4.6)**
- Automatic intent classification and module routing
- Runs targeted SQL analyzers against your live Oracle EBS database
- Results parsed and classified by severity: CRITICAL / HIGH / MEDIUM / LOW / INFO
- Actionable remediation steps with exact menu paths and Oracle MOS references

### 370+ Diagnostic Analyzers
- Pre-built SQL scripts covering every major EBS module
- Analyzers sourced from Oracle's official EBS Health Analyzer Framework (HAF)
- Covers: Concurrent Processing, Workflows, BI Publisher, AP, AR, GL, INV, PO, OM, HR, Payroll, and more

### Multi-Module Agent System
```
                         User Query
                             |
                             v
                  +---------------------+
                  |   Orchestrator AI    |
                  |   (Claude Sonnet)    |
                  +---------------------+
                     |    |    |    |
          +----------+    |    |    +----------+
          |               |    |               |
          v               v    v               v
    +-----------+  +------+  +------+  +-----------+
    | Financials|  | Mfg  |  | HCM  |  |    CRM    |
    |   Agent   |  | Agent|  | Agent|  |   Agent   |
    +-----------+  +------+  +------+  +-----------+
    | AP, AR,   |  | INV, |  | HR,  |  | Service,  |
    | GL, FA,   |  | BOM, |  | Pay, |  | Contracts,|
    | CE, PA,   |  | WIP, |  | OTL, |  | Install   |
    | Tax, SLA  |  | ASCP,|  | AME  |  | Base      |
    +-----------+  | WMS  |  +------+  +-----------+
                   +------+
```

### Integrated Tools
- **JIRA Integration** — Search, create, troubleshoot, and comment on tickets directly
- **Process Mining** — Analyze EBS process flows for bottlenecks and deviations
- **Observability** — Real-time event stream and system health monitoring
- **Report Generation** — PDF incident reports with findings and remediation
- **MCP Console** — Model Context Protocol tool/resource browser
- **Fusion Apps** — Oracle Fusion Cloud diagnostics (SCP, Payables, etc.)

### Demo Mode
- Runs without a live Oracle database using realistic mock data
- Perfect for demos, testing, and development

---

## Architecture

```
+-------------------------------------------------------------------+
|                        Client Browser                              |
|   [Chat] [Dashboard] [Payables] [JIRA] [Process Mining] [MCP]    |
+-------------------------------------------------------------------+
          |                    |                    |
          v                    v                    v
+-------------------------------------------------------------------+
|                     Flask Web Server (Gunicorn)                    |
|                          app.py                                    |
|-------------------------------------------------------------------|
|  Page Routes          API Routes           Streaming               |
|  /                    /api/chat             SSE events             |
|  /dashboard           /api/run-analyzer     /api/observability     |
|  /payables            /api/analyzers                               |
|  /jira                /api/sessions                                |
|  /process_mining      /api/jira/*                                  |
|  /mcp                 /api/payables/*                              |
+-------------------------------------------------------------------+
          |                    |                    |
          v                    v                    v
+-------------------+  +---------------+  +------------------+
|   agents/         |  |   tools/      |  |   config/        |
|                   |  |               |  |                  |
| orchestrator.py   |  | oracle_db.py  |  | analyzer_        |
| financials_agent  |  | sql_executor  |  |   registry.py    |
| manufacturing_    |  | result_parser |  | fusion_apps.py   |
|   agent           |  | report_gen    |  | payables_app.py  |
| hcm_agent         |  | pg_store.py   |  | scp_app.py       |
| crm_agent         |  | jira_client   |  | process_mining   |
| atg_agent         |  | observability |  |                  |
| payables_agents   |  | event_log     |  |                  |
| process_mining    |  |               |  |                  |
+-------------------+  +---------------+  +------------------+
                             |
              +--------------+--------------+
              |                             |
              v                             v
   +-------------------+        +-------------------+
   |   Oracle EBS DB   |        |   Anthropic API   |
   |   (R12 / 12.2.x)  |        |   (Claude Sonnet) |
   |                   |        |                   |
   |  370+ SQL         |        |  Intent routing   |
   |  Analyzers        |        |  Result analysis  |
   |  run here         |        |  Remediation gen  |
   +-------------------+        +-------------------+
```

### Data Flow: From Question to Answer

```
User: "Why are my concurrent requests stuck?"
  |
  v
1. Flask /api/chat receives message
  |
  v
2. Orchestrator sends to Claude with EBS system prompt + tool definitions
  |
  v
3. Claude identifies: Module=ATG, Problem=Concurrent Processing
  |
  v
4. Claude calls tool: execute_analyzer("cp_analyzer")
  |
  v
5. SQLExecutor runs cp_analyzer.sql against Oracle EBS DB
  |
  v
6. ResultParser extracts findings:
   - 12 requests stuck in "Running" for >24 hours
   - ICM not responsive since 2026-05-12
  |
  v
7. Claude interprets results and generates remediation:
   - [CRITICAL] Restart ICM: $ADMIN_SCRIPTS_HOME/adcmctl.sh start
   - [HIGH] Kill stuck requests: UPDATE fnd_concurrent_requests SET ...
  |
  v
8. Response streamed back to user via SSE
```

---

## Modules & Analyzers

| Module | Folder | Analyzers | Coverage |
|--------|--------|-----------|----------|
| **EBS Core / ATG** | `01_E-Business_Suite_Core_Analyzers` | CP, Workflow, BI Publisher, NLS, Monitoring, Security, SSO, TLS, Forms, OAF |
| **Financials** | `02_Financials_Analyzers` | AP, AR, GL, FA, CE, PA, Tax (E-Business Tax, GST, Latin Tax), SLA, IBY Payments, OIE, Collections, Grants, Leasing |
| **Manufacturing** | `03_Manufacturing_Analyzers` | Inventory, BOM, WIP, Cost Mgmt, Order Management, Purchasing, ASCP/MRP, Shipping, WMS, EAM, Quality, Service |
| **HCM** | `04_Human_Capital_Management_Analyzers` | HR, Payroll, Benefits, OTL, AME, Self-Service HR, Appraisals |
| **CRM** | `05_Customer_Relationship_Management_Analyzers` | Field Service, Service Contracts, Incentive Compensation, Install Base, iSupplier |

**Total: 359 SQL scripts + 19 XML analyzer definitions**

---

## Pages & UI

| Page | Route | Description |
|------|-------|-------------|
| **Chat** | `/` | Main AI chat interface — ask questions, run analyzers, get remediation |
| **Dashboard** | `/dashboard` | System overview — connection status, recent sessions, module health |
| **Payables** | `/payables` | Dedicated AP invoice analysis — drill into invoices, vendors, holds |
| **Payables Agents** | `/payables` | Multi-agent AP analysis (validation, matching, holds, aging) |
| **JIRA** | `/jira` | Search/create/troubleshoot JIRA tickets linked to EBS issues |
| **Process Mining** | `/process_mining` | Analyze EBS process flows — discover variants, bottlenecks |
| **MCP Console** | `/mcp` | Browse and call MCP tools, resources, and prompts |
| **Fusion** | `/fusion` | Oracle Fusion Cloud app diagnostics |
| **SCP** | `/fusion` | Supply Chain Planning diagnostics |
| **Observability** | `/dashboard` | Real-time event stream, system health |
| **Report** | `/report/<id>` | Generated incident report with findings |
| **Audit** | `/audit/<id>` | Full audit trail of a support session |

---

## API Endpoints

### Chat & Analysis
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/chat` | Send a message, get streamed AI response |
| POST | `/api/run-analyzer` | Run a specific analyzer by ID |
| GET | `/api/analyzers` | List all available analyzers |
| GET | `/api/analyzer/<id>` | Get analyzer details |

### Sessions & Reports
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/sessions` | List recent sessions |
| POST | `/api/sessions/new` | Create a new session |
| GET | `/api/sessions/<id>` | Get session details |
| GET | `/api/sessions/<id>/findings` | Get session findings |
| GET | `/api/sessions/<id>/report` | Generate PDF report |
| GET | `/api/sessions/<id>/audit` | Get audit trail |

### Oracle Database
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/oracle/credentials` | Show current connection config |
| POST | `/api/oracle/connect` | Test/establish Oracle connection |
| POST | `/api/oracle/demo` | Toggle demo mode |

### JIRA
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/jira/status` | JIRA connection status |
| POST | `/api/jira/search` | Search JIRA issues |
| GET | `/api/jira/issue/<key>` | Get issue details |
| POST | `/api/jira/create_ticket` | Create a new ticket |
| POST | `/api/jira/troubleshoot/<key>` | AI-powered troubleshooting |
| POST | `/api/jira/issue/<key>/comment` | Add comment to issue |

### System
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/system/health` | Health check |
| GET | `/api/system/info` | System information |
| GET | `/api/observability/events` | SSE event stream |

---

## Getting Started

### Prerequisites

- Python 3.10+
- An Anthropic API key
- (Optional) Oracle EBS R12 database access
- (Optional) JIRA Cloud account

### 1. Clone the repo

```bash
git clone https://github.com/hellou2xai/ccoracleebs.git
cd ccoracleebs
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Create a `.env` file

```env
# Oracle EBS Database (optional — app falls back to demo mode)
ORACLE_HOST=apps.example.com
ORACLE_PORT=1521
ORACLE_SID=EBSDB
ORACLE_SERVICE_NAME=EBSDB
ORACLE_USER=apps
ORACLE_PASSWORD=your_password

# Anthropic (required)
ANTHROPIC_API_KEY=sk-ant-api03-your-key-here

# Application
DEMO_MODE=true
BUNDLE_PATH=./bundle_2026-Mar-01/MENU/analyzers/SQL
LOG_LEVEL=INFO

# JIRA (optional)
JIRA_BASE_URL=https://your-org.atlassian.net
JIRA_EMAIL=your-email@company.com
JIRA_API_TOKEN=your-jira-token
```

### 4. Run the app

```bash
python app.py
```

The app starts at **http://localhost:8000**

---

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | Yes | — | Claude API key |
| `ORACLE_HOST` | No | `apps.example.com` | Oracle DB hostname |
| `ORACLE_PORT` | No | `1521` | Oracle listener port |
| `ORACLE_SID` | No | `EBSDB` | Oracle SID |
| `ORACLE_SERVICE_NAME` | No | `EBSDB` | Oracle service name |
| `ORACLE_USER` | No | `apps` | DB username |
| `ORACLE_PASSWORD` | No | `apps` | DB password |
| `ORACLE_CLIENT_DIR` | No | — | Path to Oracle Instant Client (thick mode only) |
| `ORACLE_HOST_IP` | No | — | Real IP for hosts-file hostnames (Render deployment) |
| `DEMO_MODE` | No | `true` | `true` = mock data, `false` = live Oracle DB |
| `BUNDLE_PATH` | No | *(auto)* | Path to analyzer SQL folder |
| `PG_HOST` | No | `localhost` | PostgreSQL host (session storage) |
| `PG_PORT` | No | `5432` | PostgreSQL port |
| `PG_DB` | No | `EBS_MFG` | PostgreSQL database name |
| `PG_USER` | No | `postgres` | PostgreSQL username |
| `PG_PASSWORD` | No | — | PostgreSQL password |
| `JIRA_BASE_URL` | No | — | Atlassian Cloud URL |
| `JIRA_EMAIL` | No | — | JIRA account email |
| `JIRA_API_TOKEN` | No | — | JIRA API token |
| `SECRET_KEY` | No | *(random)* | Flask session secret |
| `LOG_LEVEL` | No | `INFO` | Logging level |
| `PORT` | No | `8000` | Server port |

---

## Deploying on Render

This app is containerized and ready for Render deployment.

### Quick Deploy

1. Go to [Render Dashboard](https://dashboard.render.com)
2. **New** > **Web Service** > Connect `hellou2xai/ccoracleebs`
3. Render auto-detects the `Dockerfile`
4. Set environment variables (see below)
5. Deploy

### Render Architecture

```
+-----------------------------------------------+
|              Render Container                  |
|                                                |
|  entrypoint.sh                                 |
|  +------------------------------------------+ |
|  | 1. IF $ORACLE_HOST_IP is set:            | |
|  |    Write "$ORACLE_HOST_IP $ORACLE_HOST"  | |
|  |    to /etc/hosts                         | |
|  |                                          | |
|  | 2. Start gunicorn                        | |
|  |    - 2 workers, 4 threads                | |
|  |    - Binds to 0.0.0.0:$PORT             | |
|  +------------------------------------------+ |
|                    |                           |
|                    v                           |
|  +------------------------------------------+ |
|  |          Flask App (app.py)               | |
|  |  agents/ | tools/ | config/ | templates/ | |
|  +------------------------------------------+ |
+-----------------------------------------------+
         |                        |
         v                        v
  Oracle EBS DB            Anthropic API
  (via /etc/hosts           (Claude Sonnet)
   hostname resolution)
```

### Why `ORACLE_HOST_IP`?

If your Oracle DB hostname resolves via a local hosts file (not public DNS), Render won't know how to resolve it. The `entrypoint.sh` injects the IP-to-hostname mapping into the container's `/etc/hosts` at startup:

```
# Your local hosts file:
192.168.1.100  apps.example.com

# Set in Render env vars:
ORACLE_HOST=apps.example.com
ORACLE_HOST_IP=192.168.1.100

# entrypoint.sh adds to container's /etc/hosts:
192.168.1.100  apps.example.com
```

### Required Render Env Vars

| Variable | Value |
|----------|-------|
| `ORACLE_HOST` | Your EBS DB hostname |
| `ORACLE_HOST_IP` | The actual IP address |
| `ORACLE_PORT` | `1521` |
| `ORACLE_SID` | Your SID |
| `ORACLE_SERVICE_NAME` | Your service name |
| `ORACLE_USER` | DB username |
| `ORACLE_PASSWORD` | DB password |
| `ANTHROPIC_API_KEY` | Your Claude API key |
| `DEMO_MODE` | `false` (or `true` for demo) |

See [render/DEPLOY_INSTRUCTIONS.md](render/DEPLOY_INSTRUCTIONS.md) for detailed step-by-step instructions.

---

## Project Structure

```
ccoracleebs/
|
+-- app.py                      # Flask application (2000+ lines)
+-- requirements.txt            # Python dependencies
+-- Dockerfile                  # Container build
+-- entrypoint.sh               # Startup script (/etc/hosts + gunicorn)
+-- gunicorn.conf.py            # Production WSGI config
+-- render.yaml                 # Render blueprint
|
+-- agents/                     # AI Agent modules
|   +-- orchestrator.py         # Main AI orchestrator (Claude tool_use)
|   +-- financials_agent.py     # AP, AR, GL, FA, CE, Tax
|   +-- manufacturing_agent.py  # INV, BOM, WIP, OM, ASCP
|   +-- hcm_agent.py            # HR, Payroll, Benefits
|   +-- crm_agent.py            # Service, Contracts, Install Base
|   +-- atg_agent.py            # Core EBS (CP, Workflow, Security)
|   +-- payables_agents.py      # Specialized AP agents
|   +-- process_mining.py       # Process flow analysis
|   +-- jira_bridge.py          # JIRA <-> EBS integration
|
+-- tools/                      # Backend utilities
|   +-- oracle_db.py            # Oracle DB connection + demo mode
|   +-- sql_executor.py         # SQL execution engine
|   +-- result_parser.py        # Parse analyzer output into findings
|   +-- report_generator.py     # PDF report generation
|   +-- pg_store.py             # PostgreSQL session storage
|   +-- jira_client.py          # JIRA REST API client
|   +-- observability.py        # Event logging and monitoring
|   +-- event_log.py            # Event stream management
|
+-- config/                     # Configuration & registries
|   +-- analyzer_registry.py    # Maps 100+ analyzer IDs to SQL files
|   +-- fusion_apps.py          # Fusion Cloud app definitions
|   +-- payables_app.py         # Payables module config
|   +-- scp_app.py              # Supply Chain Planning config
|   +-- process_mining.py       # Process Mining config
|
+-- templates/                  # Jinja2 HTML templates
|   +-- base.html               # Base layout
|   +-- index.html              # Chat interface
|   +-- dashboard.html          # System dashboard
|   +-- payables.html           # AP analysis
|   +-- jira.html               # JIRA integration
|   +-- process_mining.html     # Process mining
|   +-- mcp_console.html        # MCP tool browser
|   +-- fusion.html             # Fusion diagnostics
|   +-- report.html             # Incident report
|   +-- audit.html              # Audit trail
|
+-- static/                     # Frontend assets
|   +-- css/style.css           # Application styles
|   +-- js/app.js               # Main chat JS
|   +-- js/payables.js          # Payables UI logic
|   +-- js/jira.js              # JIRA UI logic
|   +-- js/process_mining.js    # Process Mining UI
|   +-- js/mcp_console.js       # MCP Console UI
|   +-- js/observability.js     # Observability UI
|
+-- bundle_2026-Mar-01/         # Oracle EBS Analyzer Bundle
|   +-- MENU/
|       +-- analyzers/
|       |   +-- SQL/            # 359 SQL + 19 XML analyzers
|       |   |   +-- 01_E-Business_Suite_Core_Analyzers/
|       |   |   +-- 02_Financials_Analyzers/
|       |   |   +-- 03_Manufacturing_Analyzers/
|       |   |   +-- 04_Human_Capital_Management_Analyzers/
|       |   |   +-- 05_Customer_Relationship_Management_Analyzers/
|       |   +-- template/       # LDT loader templates
|       +-- javaLib/HAF/        # Health Analyzer Framework (Java)
|       +-- perlLib/            # Perl menu system
|
+-- render/                     # Render deployment docs
|   +-- DEPLOY_INSTRUCTIONS.md
|
+-- tests/                      # Test suite
+-- demo/                       # Demo assets & screenshots
+-- JIRA Analysis/              # JIRA scenario docs
```

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **AI Engine** | Anthropic Claude Sonnet 4.6 (tool_use) |
| **Backend** | Python 3.11, Flask, Gunicorn |
| **Database** | Oracle EBS R12 (python-oracledb thin mode) |
| **Session Store** | PostgreSQL (optional) |
| **Frontend** | Jinja2 templates, vanilla JS, CSS |
| **Containerization** | Docker |
| **Hosting** | Render (render.yaml blueprint) |
| **Issue Tracking** | JIRA Cloud (REST API) |
| **Reports** | ReportLab (PDF generation) |

---

---

## Want This for Your Organization?

U2xAI builds custom AI agents tailored to your Oracle ERP environment. Whether you're running EBS R12, Fusion Cloud, or planning a migration — we can help you:

- **Reduce L1/L2 support costs** by automating diagnostic triage with AI
- **Cut mean-time-to-resolution (MTTR)** from hours to minutes
- **Empower your support team** with an AI copilot that knows your EBS inside out
- **Integrate with your workflow** — JIRA, ServiceNow, Slack, or your custom ticketing system
- **Deploy anywhere** — on-prem, OCI, AWS, Render, or air-gapped environments

```
+-------------------------------------------------------------------+
|                     Ready to get started?                          |
|                                                                    |
|   Email:  hello@u2xai.com                                         |
|                                                                    |
|   We offer:                                                        |
|   - Free demo with your EBS environment (demo mode available)      |
|   - Proof of concept in 2 weeks                                    |
|   - Full production deployment with custom agent development       |
|   - Ongoing support and agent training                             |
+-------------------------------------------------------------------+
```

## License

Proprietary - U2xAI. All rights reserved.

---

Built with Claude Code by [U2xAI](mailto:hello@u2xai.com) | Specialists in AI + Oracle ERP
