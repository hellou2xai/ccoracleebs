# Claude Design Prompt — U2xAI Oracle EBS Support Agent Presentation

Copy and paste the prompt below into Claude (claude.ai) to generate a professional sales presentation.

---

## Prompt

Create a professional, visually compelling sales presentation for **U2xAI's Oracle EBS Support Agent** — an AI-native product that integrates Anthropic's Claude Code with Oracle E-Business Suite R12. The presentation should be designed to pitch to **CIOs, VPs of IT, Oracle DBAs, and ERP Operations leads** at mid-to-large enterprises running Oracle EBS.

### Company Background

- **Company:** U2xAI
- **Positioning:** AI-native ERP startup specializing in Claude Code + Oracle ERP integration
- **Contact:** hello@u2xai.com
- **Tagline:** "AI Agents That Actually Fix Your Oracle ERP"

### Slide Structure (15-18 slides)

**Slide 1 — Title Slide**
- "Oracle EBS Support Agent"
- "AI-Powered Diagnostics & Resolution for Oracle E-Business Suite"
- U2xAI logo area, contact: hello@u2xai.com

**Slide 2 — The Problem**
- Oracle EBS support is painful: long resolution times, L1/L2 ticket queues, tribal knowledge dependency
- Key stats to highlight:
  - Average EBS support ticket takes 4-8 hours to resolve
  - 60% of issues are repetitive and follow known patterns
  - Senior DBA time wasted on routine diagnostics
  - Knowledge loss when experienced staff leave

**Slide 3 — The Solution**
- U2xAI's Oracle EBS Support Agent
- AI agent that connects to your live EBS database
- Understands natural language: "Why are my AP invoices stuck?"
- Runs the right diagnostic analyzer automatically
- Returns findings with severity classification and step-by-step remediation
- Powered by Anthropic's Claude AI (most capable reasoning model)

**Slide 4 — How It Works (Architecture Diagram)**
- User asks a question in the chat interface
- Claude AI Orchestrator classifies intent and selects the right module agent
- Agent runs targeted SQL analyzers against the live Oracle EBS database
- Results parsed into findings: CRITICAL / HIGH / MEDIUM / LOW / INFO
- Remediation steps provided with exact menu paths and Oracle MOS references
- Show the flow: User -> Flask App -> Claude AI -> Oracle DB -> Findings -> User

**Slide 5 — Live Demo Screenshot Concept**
- Chat interface showing a real conversation:
  - User: "My concurrent requests are stuck in running status"
  - Agent: Runs CP Analyzer, finds 12 stuck requests, ICM not responsive
  - Agent: Provides remediation: restart ICM, kill specific requests with SQL

**Slide 6 — Module Coverage**
- 370+ diagnostic SQL analyzers across 5 major modules:
  - **EBS Core / ATG**: Concurrent Processing, Workflow, BI Publisher, Security, SSO, TLS, Forms, OAF
  - **Financials**: AP, AR, GL, FA, CE, PA, Tax, SLA, IBY Payments, Collections
  - **Manufacturing**: Inventory, BOM, WIP, Order Management, Purchasing, ASCP/MRP, Shipping, WMS
  - **HCM**: HR, Payroll, Benefits, OTL, AME, Self-Service HR
  - **CRM**: Field Service, Service Contracts, Install Base, iSupplier

**Slide 7 — Multi-Agent Architecture**
- Orchestrator AI routes to specialized module agents
- Each agent has deep domain knowledge for its EBS module
- Agents can run multiple analyzers in sequence for complex issues
- Show diagram: Orchestrator -> Financials Agent / Manufacturing Agent / HCM Agent / CRM Agent / ATG Agent

**Slide 8 — Key Features**
- Conversational AI chat (not just a dashboard)
- Live Oracle DB connectivity (python-oracledb thin mode — no Instant Client needed)
- 370+ pre-built SQL analyzers from Oracle's Health Analyzer Framework
- Severity-classified findings with actionable remediation
- PDF incident report generation
- Full audit trail of every session
- Demo mode for safe evaluation

**Slide 9 — JIRA Integration**
- Search and view JIRA tickets directly in the app
- AI-powered troubleshooting: paste a JIRA ticket, agent analyzes the issue
- Auto-generate new tickets from findings
- Add comments with remediation steps back to JIRA
- Bi-directional: EBS findings flow into your existing ticketing workflow

**Slide 10 — Process Mining**
- Analyze EBS process flows for bottlenecks
- Discover process variants and deviations
- Identify cases that deviate from the happy path
- Visual process flow diagrams

**Slide 11 — Observability & Monitoring**
- Real-time event stream
- System health dashboard
- Oracle connection status monitoring
- Session history and analytics

**Slide 12 — Deployment Options**
- **Cloud (Render)**: One-click deploy via Docker, auto-scaling, HTTPS
- **On-Premise**: Docker container behind your firewall
- **OCI / AWS**: Deploy on Oracle Cloud or AWS
- **Air-gapped**: Works in restricted environments with demo mode
- Highlight: No Oracle Instant Client required (thin mode driver)
- /etc/hosts injection for Oracle DBs with custom hostname resolution

**Slide 13 — Security & Compliance**
- No data leaves your environment (except Anthropic API calls for AI reasoning)
- All Oracle credentials stored as environment variables, never in code
- Full audit trail of every query and finding
- Read-only database access — agent never modifies your EBS data
- Demo mode for risk-free evaluation

**Slide 14 — ROI / Business Value**
- Reduce L1/L2 support costs by 40-60%
- Cut mean-time-to-resolution (MTTR) from hours to minutes
- Eliminate knowledge silos — AI retains expertise of your best DBAs
- 24/7 availability — AI agent doesn't take PTO
- Faster onboarding for new support staff
- Proactive issue detection before users report problems

**Slide 15 — Competitive Advantage**
- Not a chatbot — this agent EXECUTES real diagnostics on live databases
- Not generic AI — trained specifically for Oracle EBS with 370+ analyzers
- Not SaaS-only — deploy anywhere, including on-prem
- Built on Claude (Anthropic) — the most capable reasoning AI, not GPT
- Multi-agent architecture — specialized agents per module, not one-size-fits-all

**Slide 16 — Customer Engagement Model**
- **Phase 1 — Free Demo** (1 day): Demo mode walkthrough, no DB connection needed
- **Phase 2 — Proof of Concept** (2 weeks): Connect to your EBS environment, run real analyzers, show value
- **Phase 3 — Production Deployment**: Full deployment, custom agent training, integration with your ticketing system
- **Phase 4 — Ongoing Support**: Agent updates, new analyzer bundles, custom development

**Slide 17 — Technology Stack**
- AI: Anthropic Claude Sonnet 4.6 (tool_use, multi-agent orchestration)
- Backend: Python 3.11, Flask, Gunicorn
- Database: Oracle EBS R12 (python-oracledb), PostgreSQL (sessions)
- Frontend: Jinja2, JavaScript, CSS
- Container: Docker
- Hosting: Render / OCI / AWS
- Integration: JIRA Cloud REST API
- Reports: ReportLab PDF

**Slide 18 — Call to Action**
- "Let's run it on YOUR Oracle EBS"
- Contact: hello@u2xai.com
- Free demo available — no database connection required
- POC in 2 weeks — see real results on your environment
- GitHub: https://github.com/hellou2xai/ccoracleebs

### Design Guidelines

- Use a modern, clean design — dark navy/charcoal background with white text and orange/amber accents
- Avoid clip art or stock photos — use diagrams, architecture flows, and code snippets
- Keep text minimal per slide — use bullet points, not paragraphs
- Use monospace font for any code or technical content
- Include the U2xAI brand name and "hello@u2xai.com" on every slide footer
- Make it look like a product from a serious AI startup, not a consulting deck
