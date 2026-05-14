-- ============================================================================
-- U2xAI EBS Agentic Apps — Demo Seed Data
-- ============================================================================

-- Create a permanent DEMO session for mock findings
INSERT INTO u2x_sessions (session_id, status) VALUES ('DEMO', 'demo');

-- ─── Concurrent Processing (cp) ────────────────────────────────────────────
INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','cp','CONCURRENT_MANAGER_STATUS','ACTIVE managers found: 5 of 5','All concurrent managers are running normally.','INFO',5);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','cp','STUCK_REQUESTS','2 requests stuck in RUNNING state > 4 hours','Request ID 1234567 (Auto Lockbox) running since 2026-03-31 08:12. Request ID 1234568 (GL Journal Import) running since 2026-03-31 07:45.','HIGH',2);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','cp','PENDING_REQUESTS','18 requests in PENDING_NORMAL queue','Standard Manager queue depth is elevated. Consider increasing worker processes.','MEDIUM',18);

-- ─── AP Period Close ───────────────────────────────────────────────────────
INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','ap_period_close','UNPOSTED_INVOICES','45 unposted invoices in current period','Period: MAR-2026. Invoices with status NEVER VALIDATED or NEEDS REVALIDATION: 45.','CRITICAL',45);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','ap_period_close','UNCONFIRMED_PAYMENT_BATCHES','3 payment batches not confirmed','Batch IDs: 5001 (USD 125,450.00), 5002 (EUR 88,200.00), 5003 (GBP 12,000.00).','HIGH',3);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','ap_period_close','ACCOUNTING_HOLDS','7 invoices on accounting hold','Invoices held due to missing charge account or invalid account combination.','MEDIUM',7);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','ap_period_close','AP_SLA_ERRORS','2 invoices with SLA transfer errors','SLA CREATE events failed. Run Create Accounting program for AP.','HIGH',2);

-- ─── GL Health Check ───────────────────────────────────────────────────────
INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','gl_hc','UNPOSTED_JOURNALS','2 unposted journals in MAR-2026','Journal MAR-2026 Accruals (USD 45,000) and MAR-2026 Depreciation (USD 120,000) are unposted.','CRITICAL',2);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','gl_hc','PERIOD_STATUS','1 period open beyond threshold (90 days)','Period DEC-2025 is still OPEN. This may allow backdated entries.','HIGH',1);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','gl_hc','RECON_DIFFERENCES','GL/SLA out of balance: USD 3,240.50','Subledger accounting balance does not match GL balance. Difference: 3,240.50 USD.','CRITICAL',1);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','gl_hc','SUSPENSE_ACTIVITY','Suspense account activity: 14 entries, total USD 87,500','Suspense account 01-0000-21000-0000 has 14 entries requiring review.','MEDIUM',14);

-- ─── Workflow ──────────────────────────────────────────────────────────────
INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','workflow','STUCK_ACTIVITIES','23 stuck workflow activities','23 DEFERRED or ERROR activities older than 24 hours. Top offenders: APINVAPR (15), POAPPRV (5), HRASSIGN (3).','HIGH',23);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','workflow','BACKGROUND_ENGINE','Background engine last run: 47 minutes ago','Should run every 15 minutes. Gap: 47 minutes.','MEDIUM',1);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','workflow','PURGE_STATUS','Workflow purge not run in 180+ days','WF_PURGE tables contain 2.4M obsolete rows. Performance impact likely.','HIGH',2400000);

-- ─── DB Monitoring ─────────────────────────────────────────────────────────
INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','mon','TABLESPACE_USAGE','APPS_TS_TX_DATA tablespace at 92% capacity','Total: 500 GB, Used: 460 GB, Free: 40 GB. Add datafile immediately.','CRITICAL',1);

INSERT INTO u2x_findings (session_id, analyzer_id, section, finding, detail, severity, finding_count)
VALUES ('DEMO','mon','INVALID_OBJECTS','34 invalid database objects','34 INVALID objects in APPS schema. Run utlrp.sql to recompile.','HIGH',34);

-- ─── Payables Agents (seed agent state) ────────────────────────────────────
INSERT INTO u2x_agent_state (agent_id, agent_label, last_phase, total_runs, total_errors, in_flight)
VALUES ('hold_resolver',      'Hold Resolver',           'complete', 0, 0, 0);
INSERT INTO u2x_agent_state (agent_id, agent_label, last_phase, total_runs, total_errors, in_flight)
VALUES ('duplicate_detector', 'Duplicate Detector',      'complete', 0, 0, 0);
INSERT INTO u2x_agent_state (agent_id, agent_label, last_phase, total_runs, total_errors, in_flight)
VALUES ('aging_analyst',      'Aging Analyst',           'complete', 0, 0, 0);
INSERT INTO u2x_agent_state (agent_id, agent_label, last_phase, total_runs, total_errors, in_flight)
VALUES ('match_engine',       'PO Match Engine',         'complete', 0, 0, 0);
INSERT INTO u2x_agent_state (agent_id, agent_label, last_phase, total_runs, total_errors, in_flight)
VALUES ('approval_tracker',   'Approval Tracker',        'complete', 0, 0, 0);
INSERT INTO u2x_agent_state (agent_id, agent_label, last_phase, total_runs, total_errors, in_flight)
VALUES ('payment_scheduler',  'Payment Scheduler',       'complete', 0, 0, 0);
INSERT INTO u2x_agent_state (agent_id, agent_label, last_phase, total_runs, total_errors, in_flight)
VALUES ('sla_monitor',        'SLA Monitor',             'complete', 0, 0, 0);
INSERT INTO u2x_agent_state (agent_id, agent_label, last_phase, total_runs, total_errors, in_flight)
VALUES ('tax_validator',      'Tax Validator',           'complete', 0, 0, 0);
INSERT INTO u2x_agent_state (agent_id, agent_label, last_phase, total_runs, total_errors, in_flight)
VALUES ('period_close_checker','Period Close Checker',   'complete', 0, 0, 0);
INSERT INTO u2x_agent_state (agent_id, agent_label, last_phase, total_runs, total_errors, in_flight)
VALUES ('fraud_scanner',      'Fraud Scanner',           'complete', 0, 0, 0);

-- ─── Fusion Apps Catalog ───────────────────────────────────────────────────
INSERT INTO u2x_fusion_apps (app_id, app_name, pillar, icon_class, tagline, kpis_json)
VALUES ('payables',     'Payables Agentic App',     'FINANCE',       'fa-file-invoice-dollar', 'Invoice ingestion, PO matching, fraud detection', '["STP Rate","Invoice Cycle Time","Hold Rate","Match Rate"]');
INSERT INTO u2x_fusion_apps (app_id, app_name, pillar, icon_class, tagline, kpis_json)
VALUES ('receivables',  'Receivables Agentic App',  'FINANCE',       'fa-hand-holding-dollar', 'Cash application, aging analysis, collections',   '["DSO","Collection Rate","Dispute Rate"]');
INSERT INTO u2x_fusion_apps (app_id, app_name, pillar, icon_class, tagline, kpis_json)
VALUES ('gl',           'General Ledger App',       'FINANCE',       'fa-book',                'Journal validation, reconciliation, period close', '["Unposted Journals","Suspense Balance","Recon Variance"]');
INSERT INTO u2x_fusion_apps (app_id, app_name, pillar, icon_class, tagline, kpis_json)
VALUES ('fixed_assets', 'Fixed Assets App',         'FINANCE',       'fa-building',            'Depreciation, mass additions, retirement tracking','["Pending Additions","Depreciation Status"]');
INSERT INTO u2x_fusion_apps (app_id, app_name, pillar, icon_class, tagline, kpis_json)
VALUES ('purchasing',   'Purchasing Agentic App',   'PROCUREMENT',   'fa-cart-shopping',       'Requisition-to-PO, approval workflow, sourcing',  '["PO Cycle Time","Approval Pending","Req-to-PO Rate"]');
INSERT INTO u2x_fusion_apps (app_id, app_name, pillar, icon_class, tagline, kpis_json)
VALUES ('inventory',    'Inventory Agentic App',    'SUPPLY_CHAIN',  'fa-warehouse',           'On-hand analysis, transaction errors, reservations','["Negative Qty Items","Pending Txns","Accuracy Rate"]');
INSERT INTO u2x_fusion_apps (app_id, app_name, pillar, icon_class, tagline, kpis_json)
VALUES ('order_mgmt',   'Order Management App',     'SUPPLY_CHAIN',  'fa-truck-fast',          'Order-to-cash, stuck orders, pricing exceptions', '["Stuck Orders","Orders On Hold","Avg Fulfillment"]');
INSERT INTO u2x_fusion_apps (app_id, app_name, pillar, icon_class, tagline, kpis_json)
VALUES ('manufacturing','Manufacturing App',        'SUPPLY_CHAIN',  'fa-industry',            'WIP jobs, component shortages, variance analysis','["Stuck Jobs","Component Shortages","WIP Variance"]');
INSERT INTO u2x_fusion_apps (app_id, app_name, pillar, icon_class, tagline, kpis_json)
VALUES ('hr',           'Human Resources App',      'HCM',           'fa-users',               'Employee records, assignments, compliance checks','["Missing Records","Compliance Issues"]');
INSERT INTO u2x_fusion_apps (app_id, app_name, pillar, icon_class, tagline, kpis_json)
VALUES ('payroll',      'Payroll App',              'HCM',           'fa-money-check-alt',     'Payroll runs, balance validation, element errors','["Balance Errors","Element Errors","Run Status"]');

COMMIT;

PROMPT Demo data seeded successfully.
