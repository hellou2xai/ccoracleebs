"""
Populate APEX app 107 (created via UI) with pages, nav items, and regions.
"""
import oracledb
import os

INSTANT_CLIENT = os.path.expanduser(
    r"~\Downloads\instantclient-basic-windows.x64-23.26.1.0.0\instantclient_23_0"
)
if os.path.isdir(INSTANT_CLIENT):
    oracledb.init_oracle_client(lib_dir=INSTANT_CLIENT)

conn = oracledb.connect(user="IZU", password="IZU1001u",
                        dsn="140.245.24.128:1521/EBSDB")
cur = conn.cursor()
cur.execute("BEGIN apex_util.set_security_group_id(100101); END;")

APP_ID = 107


def run(sql, label, binds):
    try:
        cur.execute(sql, binds)
        print(f"  [OK] {label}")
        return True
    except oracledb.DatabaseError as e:
        err = str(e)
        if "already exists" in err.lower():
            print(f"  [SKIP] {label}")
            return True
        print(f"  [ERROR] {label}: {err[:250]}")
        return False


# ── Check existing pages ──
cur.execute("SELECT page_id, page_name FROM apex_application_pages WHERE application_id = :a ORDER BY page_id", a=APP_ID)
existing = cur.fetchall()
print("Existing pages:")
for r in existing:
    print(f"  Page {r[0]}: {r[1]}")
existing_ids = {r[0] for r in existing}

# ── Add pages 2-8 ──
print("\n--- Creating pages ---")
pages = [
    (2, "EBS Apps", "EBS-APPS"),
    (3, "Payables", "PAYABLES"),
    (4, "AP Agents", "AP-AGENTS"),
    (5, "Observability", "OBSERVABILITY"),
    (6, "Process Mining", "PROCESS-MINING"),
    (7, "Analyzers", "ANALYZERS"),
    (8, "Sessions", "SESSIONS"),
]
CREATE_PAGE = """
BEGIN
    wwv_flow.g_flow_id := :fid;
    wwv_flow_imp_page.create_page(
        p_id => :pid, p_flow_id => :fid,
        p_name => :name, p_alias => :alias, p_step_title => :name
    );
    commit;
END;
"""
for pg_id, pg_name, pg_alias in pages:
    if pg_id in existing_ids:
        print(f"  [SKIP] Page {pg_id} exists")
        continue
    run(CREATE_PAGE, f"Page {pg_id}: {pg_name}",
        dict(fid=APP_ID, pid=pg_id, name=pg_name, alias=pg_alias))

# ── Nav items ──
print("\n--- Navigation ---")
cur.execute("SELECT list_id, list_name FROM apex_application_lists WHERE application_id = :a", a=APP_ID)
nav = cur.fetchone()
if nav:
    list_id = nav[0]
    print(f"  List: {nav[1]} (id={list_id})")

    cur.execute(
        "SELECT entry_text FROM apex_application_list_entries WHERE application_id = :a AND list_name = :n",
        a=APP_ID, n=nav[1])
    existing_nav = {r[0] for r in cur.fetchall()}

    nav_items = [
        (20, "EBS Apps",       "2", "fa-th"),
        (30, "Payables",       "3", "fa-money-bill"),
        (40, "AP Agents",      "4", "fa-users"),
        (50, "Observability",  "5", "fa-line-chart"),
        (60, "Process Mining", "6", "fa-sitemap"),
        (70, "Analyzers",      "7", "fa-search"),
        (80, "Sessions",       "8", "fa-clock-o"),
    ]
    CREATE_NAV = """
    BEGIN
        wwv_flow.g_flow_id := :fid;
        wwv_flow_imp_shared.create_list_item(
            p_id => :iid, p_list_id => :lid,
            p_list_item_display_sequence => :seq,
            p_list_item_link_text => :name,
            p_list_item_link_target => :target,
            p_list_item_icon => :icon
        );
        commit;
    END;
    """
    for seq, label, pg, icon in nav_items:
        if label in existing_nav:
            print(f"  [SKIP] {label}")
            continue
        run(CREATE_NAV, f"Nav: {label}",
            dict(fid=APP_ID, iid=list_id * 100 + seq, lid=list_id, seq=seq,
                 name=label, target=f"f?p=&APP_ID.:{pg}:&SESSION.::&DEBUG.::::", icon=icon))

# ── Regions ──
print("\n--- Regions ---")
CREATE_REGION = """
BEGIN
    wwv_flow.g_flow_id := :fid;
    wwv_flow_imp_page.create_page_plug(
        p_id => :rid, p_flow_id => :fid, p_page_id => :pid,
        p_plug_name => :name, p_plug_display_sequence => :seq,
        p_plug_source_type => :stype, p_plug_source => :src,
        p_plug_query_num_rows => 200
    );
    commit;
END;
"""

regions = [
    # Page 1: Dashboard
    (11001, 1, "System Health", 10, "NATIVE_SQL_REPORT",
     "SELECT 'EBS Version' label, '12.2.11' value, 'fa-database' icon FROM dual UNION ALL "
     "SELECT 'Database', '19c (19.22)', 'fa-server' FROM dual UNION ALL "
     "SELECT 'Active Agents', TO_CHAR((SELECT COUNT(*) FROM u2x_agent_state)), 'fa-users' FROM dual UNION ALL "
     "SELECT 'Open Findings', TO_CHAR((SELECT COUNT(*) FROM u2x_findings WHERE session_id='DEMO')), 'fa-warning' FROM dual UNION ALL "
     "SELECT 'Critical', TO_CHAR((SELECT COUNT(*) FROM u2x_findings WHERE session_id='DEMO' AND severity='CRITICAL')), 'fa-exclamation-triangle' FROM dual UNION ALL "
     "SELECT 'Fusion Apps', TO_CHAR((SELECT COUNT(*) FROM u2x_fusion_apps)), 'fa-th' FROM dual"),

    (11002, 1, "Findings by Severity", 20, "NATIVE_SQL_REPORT",
     "SELECT severity, COUNT(*) cnt FROM u2x_findings WHERE session_id = 'DEMO' "
     "GROUP BY severity ORDER BY DECODE(severity,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4,'INFO',5)"),

    (11003, 1, "Agent Overview", 30, "NATIVE_SQL_REPORT",
     "SELECT agent_id, agent_label, last_phase, last_severity, total_runs, total_errors, in_flight, "
     "TO_CHAR(last_ts, 'YYYY-MM-DD HH24:MI:SS') last_run FROM u2x_agent_state ORDER BY agent_id"),

    # Page 2: EBS Apps
    (12001, 2, "Agentic App Catalog", 10, "NATIVE_SQL_REPORT",
     "SELECT app_id, app_name, pillar, icon_class, tagline, kpis_json FROM u2x_fusion_apps "
     "WHERE is_active = 'Y' ORDER BY pillar, app_name"),

    # Page 3: Payables
    (13001, 3, "AP Period Close Findings", 10, "NATIVE_IR",
     "SELECT finding_id, section, finding, detail, severity, finding_count, "
     "TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created FROM u2x_findings "
     "WHERE session_id = 'DEMO' AND analyzer_id = 'ap_period_close' "
     "ORDER BY DECODE(severity,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4,'INFO',5)"),

    (13002, 3, "All Payables Findings", 20, "NATIVE_IR",
     "SELECT finding_id, analyzer_id, section, finding, severity, finding_count, "
     "TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created FROM u2x_findings "
     "WHERE session_id = 'DEMO' AND analyzer_id IN ('ap_period_close','workflow') ORDER BY created_at DESC"),

    # Page 4: AP Agents
    (14001, 4, "Agent Status", 10, "NATIVE_SQL_REPORT",
     "SELECT agent_id, agent_label, last_phase, NVL(last_severity, 'INFO') severity, "
     "NVL(last_duration_ms, 0) duration_ms, total_runs, total_errors, in_flight, "
     "TO_CHAR(last_ts, 'YYYY-MM-DD HH24:MI:SS') last_run FROM u2x_agent_state ORDER BY agent_id"),

    # Page 5: Observability
    (15001, 5, "Observability Stats", 10, "NATIVE_SQL_REPORT",
     "SELECT (SELECT COUNT(*) FROM u2x_obs_events) total_events, "
     "(SELECT COUNT(*) FROM u2x_agent_state) agents_registered, "
     "(SELECT NVL(SUM(total_runs),0) FROM u2x_agent_state) total_runs, "
     "(SELECT NVL(SUM(total_errors),0) FROM u2x_agent_state) total_errors, "
     "(SELECT NVL(SUM(in_flight),0) FROM u2x_agent_state) in_flight FROM dual"),

    (15002, 5, "Agent State", 20, "NATIVE_SQL_REPORT",
     "SELECT agent_id, agent_label, last_phase, last_severity, last_duration_ms, "
     "total_runs, total_errors, in_flight, TO_CHAR(last_ts, 'YYYY-MM-DD HH24:MI:SS') last_run "
     "FROM u2x_agent_state ORDER BY agent_id"),

    (15003, 5, "Event Log", 30, "NATIVE_IR",
     "SELECT event_id, run_id, agent_id, agent_label, phase, source, message, severity, "
     "rows_count, duration_ms, TO_CHAR(event_ts, 'YYYY-MM-DD HH24:MI:SS.FF3') event_time "
     "FROM u2x_obs_events ORDER BY event_ts DESC"),

    # Page 6: Process Mining
    (16001, 6, "Process Mining Overview", 10, "NATIVE_STATIC",
     "<div class=\"t-Alert t-Alert--info\"><div class=\"t-Alert-body\">"
     "<h2>AP Invoice Process Mining</h2>"
     "<p>Analyze the invoice lifecycle from receipt through payment.</p>"
     "<ul><li><b>Happy Path Rate:</b> 67%</li>"
     "<li><b>Process Variants:</b> 12 unique paths</li>"
     "<li><b>Avg Cycle Time:</b> 8.3 days (target: 5)</li>"
     "<li><b>Top Bottleneck:</b> PO Matching (avg 2.1 days)</li>"
     "</ul></div></div>"),

    (16002, 6, "Process Flow Summary", 20, "NATIVE_SQL_REPORT",
     "SELECT step_no, step_name, avg_days, pct_on_time, volume FROM ("
     "SELECT 1 step_no, 'Invoice Receipt' step_name, 0.5 avg_days, 95 pct_on_time, 1250 volume FROM dual UNION ALL "
     "SELECT 2, 'Validation', 0.8, 88, 1250 FROM dual UNION ALL "
     "SELECT 3, 'PO Matching', 2.1, 62, 980 FROM dual UNION ALL "
     "SELECT 4, 'Approval', 1.5, 75, 950 FROM dual UNION ALL "
     "SELECT 5, 'Accounting', 0.3, 98, 940 FROM dual UNION ALL "
     "SELECT 6, 'Payment Scheduling', 1.2, 82, 930 FROM dual UNION ALL "
     "SELECT 7, 'Payment Execution', 1.9, 70, 920 FROM dual) ORDER BY step_no"),

    # Page 7: Analyzers
    (17001, 7, "Analyzer Summary", 10, "NATIVE_SQL_REPORT",
     "SELECT analyzer_id, INITCAP(REPLACE(analyzer_id, '_', ' ')) analyzer_name, "
     "COUNT(*) finding_count, "
     "SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) critical_count, "
     "SUM(CASE WHEN severity = 'HIGH' THEN 1 ELSE 0 END) high_count, "
     "SUM(CASE WHEN severity = 'MEDIUM' THEN 1 ELSE 0 END) medium_count "
     "FROM u2x_findings WHERE session_id = 'DEMO' "
     "GROUP BY analyzer_id ORDER BY critical_count DESC, high_count DESC"),

    (17002, 7, "All Findings", 20, "NATIVE_IR",
     "SELECT finding_id, analyzer_id, INITCAP(REPLACE(analyzer_id, '_', ' ')) analyzer_name, "
     "section, finding, detail, severity, finding_count, "
     "TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created "
     "FROM u2x_findings WHERE session_id = 'DEMO' "
     "ORDER BY DECODE(severity,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4,'INFO',5)"),

    # Page 8: Sessions
    (18001, 8, "Analysis Sessions", 10, "NATIVE_IR",
     "SELECT s.session_id, TO_CHAR(s.created_at, 'YYYY-MM-DD HH24:MI:SS') created_at, s.status, "
     "(SELECT COUNT(*) FROM u2x_findings f WHERE f.session_id = s.session_id) finding_count, "
     "(SELECT COUNT(*) FROM u2x_audit_trail a WHERE a.session_id = s.session_id) audit_count "
     "FROM u2x_sessions s ORDER BY s.created_at DESC"),
]

for reg_id, pg_id, reg_name, seq, src_type, source in regions:
    run(CREATE_REGION, f"Page {pg_id}: {reg_name}",
        dict(fid=APP_ID, rid=reg_id, pid=pg_id, name=reg_name,
             seq=seq, stype=src_type, src=source))

conn.commit()

# Cleanup broken app 200
try:
    cur.execute("BEGIN wwv_flow_imp.remove_flow(200); commit; END;")
    print("\n[CLEANUP] Removed app 200")
except:
    pass

# Summary
cur.execute("SELECT COUNT(*) FROM apex_application_pages WHERE application_id = :a", a=APP_ID)
pg_count = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM apex_application_page_regions WHERE application_id = :a", a=APP_ID)
reg_count = cur.fetchone()[0]

print(f"\n{'='*55}")
print(f"Done! App {APP_ID}: {pg_count} pages, {reg_count} regions")
print(f"URL: http://apps.example.com:8080/apex/f?p={APP_ID}")
print(f"Login: W1_ADMIN / Admin15429")
print(f"{'='*55}")

cur.close()
conn.close()
