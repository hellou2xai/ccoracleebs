"""
U2xAI EBS Agentic Apps — APEX 24.1 Application Deployment.
Uses wwv_flow_wizard_api.create_app for proper Universal Theme + APEX Accounts auth,
then adds pages and regions via wwv_flow_imp_page.
"""
import oracledb
import sys
import os

INSTANT_CLIENT = os.path.expanduser(
    r"~\Downloads\instantclient-basic-windows.x64-23.26.1.0.0\instantclient_23_0"
)
if os.path.isdir(INSTANT_CLIENT):
    oracledb.init_oracle_client(lib_dir=INSTANT_CLIENT)

DB_HOST = "140.245.24.128"
DB_PORT = 1521
DB_SERVICE = "EBSDB"
DB_USER = "IZU"
DB_PASS = "IZU1001u"
WORKSPACE = "WORKSPACE1"
APP_ALIAS = "U2XEBS"
APP_NAME = "U2xAI EBS Agentic Apps"


def run(cur, sql, label="", binds=None, fatal=False):
    try:
        if binds:
            cur.execute(sql, binds)
        else:
            cur.execute(sql)
        if label:
            print(f"  [OK] {label}")
        return True
    except oracledb.DatabaseError as e:
        err = str(e)
        if "already exists" in err.lower() or "ORA-20001" in err:
            print(f"  [SKIP] {label}")
            return True
        print(f"  [ERROR] {label}: {err[:300]}")
        if fatal:
            raise
        return False


def main():
    print("=" * 55)
    print("U2xAI EBS Agentic Apps - APEX 24.1 Deployment")
    print(f"Workspace: {WORKSPACE}  |  Schema: {DB_USER}")
    print("=" * 55)

    conn = oracledb.connect(user=DB_USER, password=DB_PASS,
                            dsn=f"{DB_HOST}:{DB_PORT}/{DB_SERVICE}")
    cur = conn.cursor()
    print(f"Connected as {DB_USER}\n")

    # ── Workspace context ──
    cur.execute("SELECT workspace_id FROM apex_workspaces WHERE workspace = :ws", ws=WORKSPACE)
    ws_id = cur.fetchone()[0]
    cur.execute(f"BEGIN apex_util.set_security_group_id({ws_id}); END;")
    print(f"Workspace ID: {ws_id}")

    # ── Remove existing app ──
    cur.execute("SELECT application_id FROM apex_applications WHERE alias = :a AND workspace_id = :w",
                a=APP_ALIAS, w=ws_id)
    row = cur.fetchone()
    if row:
        print(f"Removing existing app {row[0]}...")
        cur.execute(f"BEGIN wwv_flow_imp.remove_flow({row[0]}); commit; END;")
        print(f"  [OK] Removed {row[0]}")

    # ── Pick app ID ──
    cur.execute("SELECT NVL(MAX(application_id),199)+1 FROM apex_applications WHERE workspace_id = :w", w=ws_id)
    app_id = max(cur.fetchone()[0], 200)
    print(f"\n--- Creating app {app_id} ---")

    # ── Create app with auth_id linked ──
    auth_id = app_id * 100 + 1
    run(cur, """
        BEGIN
            wwv_flow_imp.create_flow(
                p_id                => :id,
                p_owner             => :owner,
                p_name              => :name,
                p_alias             => :alias,
                p_flow_language     => 'en',
                p_flow_status       => 'AVAILABLE_W_EDIT_LINK',
                p_flow_version      => '1.0.0',
                p_authentication    => 'PLUGIN',
                p_authentication_id => :auth_id
            );
            commit;
        END;
    """, f"App {app_id} created",
        binds=dict(id=app_id, owner=DB_USER, name=APP_NAME, alias=APP_ALIAS, auth_id=auth_id), fatal=True)

    ctx = f"wwv_flow.g_flow_id := {app_id};"
    run(cur, f"BEGIN {ctx} END;", "Set flow context")

    # ── Create NATIVE_APEX_ACCOUNTS auth with matching ID ──
    print("\n--- Authentication ---")
    run(cur, """
        BEGIN
            wwv_flow_imp_shared.create_authentication(
                p_id          => :aid,
                p_flow_id     => :fid,
                p_name        => :name,
                p_scheme_type => :stype
            );
            commit;
        END;
    """, "APEX Accounts auth",
        binds=dict(aid=auth_id, fid=app_id, name="Oracle APEX Accounts", stype="NATIVE_APEX_ACCOUNTS"))

    # Verify auth
    cur.execute("""
        SELECT authentication_scheme_name, scheme_type_code
        FROM apex_application_auth WHERE application_id = :a
    """, a=app_id)
    for r in cur.fetchall():
        print(f"  Auth: {r[0]} ({r[1]})")

    # ── Navigation Menu ──
    print("\n--- Navigation ---")
    # Find existing nav list
    cur.execute("SELECT list_id, list_name FROM apex_application_lists WHERE application_id = :a",
                a=app_id)
    nav_row = cur.fetchone()
    if nav_row:
        list_id = nav_row[0]
        print(f"  Using existing list: {nav_row[1]} (id={list_id})")
    else:
        list_id = app_id * 1000 + 1
        run(cur, f"""
            BEGIN
                {ctx}
                wwv_flow_imp_shared.create_list(
                    p_id => {list_id}, p_flow_id => {app_id},
                    p_name => 'Desktop Navigation Menu', p_list_status => 'PUBLIC'
                );
                commit;
            END;
        """, "Nav list created")

    nav_items = [
        (10, 'Dashboard',      '1', 'fa-home'),
        (20, 'EBS Apps',       '2', 'fa-th'),
        (30, 'Payables',       '3', 'fa-money-bill'),
        (40, 'AP Agents',      '4', 'fa-users'),
        (50, 'Observability',  '5', 'fa-line-chart'),
        (60, 'Process Mining', '6', 'fa-sitemap'),
        (70, 'Analyzers',      '7', 'fa-search'),
        (80, 'Sessions',       '8', 'fa-clock-o'),
    ]
    for seq, label, pg, icon in nav_items:
        iid = list_id * 100 + seq
        run(cur, """
            BEGIN
                wwv_flow_imp_shared.create_list_item(
                    p_id            => :iid,
                    p_list_id       => :lid,
                    p_list_item_display_sequence => :seq,
                    p_list_item_link_text => :name,
                    p_list_item_link_target => :target,
                    p_list_item_icon => :icon
                );
                commit;
            END;
        """, f"Nav: {label}",
            binds=dict(iid=iid, lid=list_id, seq=seq, name=label,
                       target=f"f?p=&APP_ID.:{pg}:&SESSION.::&DEBUG.::::", icon=icon))

    # ── Pages ──
    print("\n--- Pages ---")
    pages_def = [
        (1, 'Dashboard',      'HOME'),
        (2, 'EBS Apps',       'EBS-APPS'),
        (3, 'Payables',       'PAYABLES'),
        (4, 'AP Agents',      'AP-AGENTS'),
        (5, 'Observability',  'OBSERVABILITY'),
        (6, 'Process Mining', 'PROCESS-MINING'),
        (7, 'Analyzers',      'ANALYZERS'),
        (8, 'Sessions',       'SESSIONS'),
    ]

    # Check which pages already exist (wizard may create page 1)
    cur.execute("SELECT page_id FROM apex_application_pages WHERE application_id = :a", a=app_id)
    existing_pages = {r[0] for r in cur.fetchall()}
    print(f"  Existing pages: {sorted(existing_pages)}")

    for pg_id, pg_name, pg_alias in pages_def:
        if pg_id in existing_pages:
            print(f"  [SKIP] Page {pg_id}: {pg_name} (exists)")
            continue
        run(cur, """
            BEGIN
                wwv_flow_imp_page.create_page(
                    p_id       => :pid,
                    p_flow_id  => :fid,
                    p_name     => :name,
                    p_alias    => :alias,
                    p_step_title => :name
                );
                commit;
            END;
        """, f"Page {pg_id}: {pg_name}",
            binds=dict(pid=pg_id, fid=app_id, name=pg_name, alias=pg_alias))

    # ── Regions ──
    print("\n--- Regions ---")

    # Define regions with bind-variable-friendly SQL (no inline quoting issues)
    regions = []

    # Page 1: Dashboard
    regions.append((11001, 1, 'System Health', 10, 'NATIVE_SQL_REPORT',
        "SELECT 'EBS Version' label, '12.2.11' value, 'fa-database' icon FROM dual UNION ALL "
        "SELECT 'Database', '19c (19.22)', 'fa-server' FROM dual UNION ALL "
        "SELECT 'Active Agents', TO_CHAR((SELECT COUNT(*) FROM u2x_agent_state)), 'fa-users' FROM dual UNION ALL "
        "SELECT 'Open Findings', TO_CHAR((SELECT COUNT(*) FROM u2x_findings WHERE session_id='DEMO')), 'fa-warning' FROM dual UNION ALL "
        "SELECT 'Critical', TO_CHAR((SELECT COUNT(*) FROM u2x_findings WHERE session_id='DEMO' AND severity='CRITICAL')), 'fa-exclamation-triangle' FROM dual UNION ALL "
        "SELECT 'Fusion Apps', TO_CHAR((SELECT COUNT(*) FROM u2x_fusion_apps)), 'fa-th' FROM dual"))

    regions.append((11002, 1, 'Findings by Severity', 20, 'NATIVE_SQL_REPORT',
        "SELECT severity, COUNT(*) cnt FROM u2x_findings WHERE session_id = 'DEMO' "
        "GROUP BY severity ORDER BY DECODE(severity,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4,'INFO',5)"))

    regions.append((11003, 1, 'Agent Overview', 30, 'NATIVE_SQL_REPORT',
        "SELECT agent_id, agent_label, last_phase, last_severity, total_runs, total_errors, in_flight, "
        "TO_CHAR(last_ts, 'YYYY-MM-DD HH24:MI:SS') last_run FROM u2x_agent_state ORDER BY agent_id"))

    # Page 2: EBS Apps
    regions.append((12001, 2, 'Agentic App Catalog', 10, 'NATIVE_SQL_REPORT',
        "SELECT app_id, app_name, pillar, icon_class, tagline, kpis_json FROM u2x_fusion_apps "
        "WHERE is_active = 'Y' ORDER BY pillar, app_name"))

    # Page 3: Payables
    regions.append((13001, 3, 'AP Period Close Findings', 10, 'NATIVE_IR',
        "SELECT finding_id, section, finding, detail, severity, finding_count, "
        "TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created FROM u2x_findings "
        "WHERE session_id = 'DEMO' AND analyzer_id = 'ap_period_close' "
        "ORDER BY DECODE(severity,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4,'INFO',5)"))

    regions.append((13002, 3, 'All Payables Findings', 20, 'NATIVE_IR',
        "SELECT finding_id, analyzer_id, section, finding, severity, finding_count, "
        "TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created FROM u2x_findings "
        "WHERE session_id = 'DEMO' AND analyzer_id IN ('ap_period_close','workflow') ORDER BY created_at DESC"))

    # Page 4: AP Agents
    regions.append((14001, 4, 'Agent Status', 10, 'NATIVE_SQL_REPORT',
        "SELECT agent_id, agent_label, last_phase, NVL(last_severity, 'INFO') severity, "
        "NVL(last_duration_ms, 0) duration_ms, total_runs, total_errors, in_flight, "
        "TO_CHAR(last_ts, 'YYYY-MM-DD HH24:MI:SS') last_run FROM u2x_agent_state ORDER BY agent_id"))

    # Page 5: Observability
    regions.append((15001, 5, 'Observability Stats', 10, 'NATIVE_SQL_REPORT',
        "SELECT (SELECT COUNT(*) FROM u2x_obs_events) total_events, "
        "(SELECT COUNT(*) FROM u2x_agent_state) agents_registered, "
        "(SELECT NVL(SUM(total_runs),0) FROM u2x_agent_state) total_runs, "
        "(SELECT NVL(SUM(total_errors),0) FROM u2x_agent_state) total_errors, "
        "(SELECT NVL(SUM(in_flight),0) FROM u2x_agent_state) in_flight FROM dual"))

    regions.append((15002, 5, 'Agent State', 20, 'NATIVE_SQL_REPORT',
        "SELECT agent_id, agent_label, last_phase, last_severity, last_duration_ms, "
        "total_runs, total_errors, in_flight, TO_CHAR(last_ts, 'YYYY-MM-DD HH24:MI:SS') last_run "
        "FROM u2x_agent_state ORDER BY agent_id"))

    regions.append((15003, 5, 'Event Log', 30, 'NATIVE_IR',
        "SELECT event_id, run_id, agent_id, agent_label, phase, source, message, severity, "
        "rows_count, duration_ms, TO_CHAR(event_ts, 'YYYY-MM-DD HH24:MI:SS.FF3') event_time "
        "FROM u2x_obs_events ORDER BY event_ts DESC"))

    # Page 6: Process Mining
    regions.append((16001, 6, 'Process Mining Overview', 10, 'NATIVE_STATIC',
        '<div class="t-Alert t-Alert--info"><div class="t-Alert-body">'
        '<h2>AP Invoice Process Mining</h2>'
        '<p>Analyze the invoice lifecycle from receipt through payment.</p>'
        '<ul><li><b>Happy Path Rate:</b> 67%</li>'
        '<li><b>Process Variants:</b> 12 unique paths</li>'
        '<li><b>Avg Cycle Time:</b> 8.3 days (target: 5)</li>'
        '<li><b>Top Bottleneck:</b> PO Matching (avg 2.1 days)</li>'
        '</ul></div></div>'))

    regions.append((16002, 6, 'Process Flow Summary', 20, 'NATIVE_SQL_REPORT',
        "SELECT step_no, step_name, avg_days, pct_on_time, volume FROM ("
        "SELECT 1 step_no, 'Invoice Receipt' step_name, 0.5 avg_days, 95 pct_on_time, 1250 volume FROM dual UNION ALL "
        "SELECT 2, 'Validation', 0.8, 88, 1250 FROM dual UNION ALL "
        "SELECT 3, 'PO Matching', 2.1, 62, 980 FROM dual UNION ALL "
        "SELECT 4, 'Approval', 1.5, 75, 950 FROM dual UNION ALL "
        "SELECT 5, 'Accounting', 0.3, 98, 940 FROM dual UNION ALL "
        "SELECT 6, 'Payment Scheduling', 1.2, 82, 930 FROM dual UNION ALL "
        "SELECT 7, 'Payment Execution', 1.9, 70, 920 FROM dual) ORDER BY step_no"))

    # Page 7: Analyzers
    regions.append((17001, 7, 'Analyzer Summary', 10, 'NATIVE_SQL_REPORT',
        "SELECT analyzer_id, INITCAP(REPLACE(analyzer_id, '_', ' ')) analyzer_name, "
        "COUNT(*) finding_count, "
        "SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) critical_count, "
        "SUM(CASE WHEN severity = 'HIGH' THEN 1 ELSE 0 END) high_count, "
        "SUM(CASE WHEN severity = 'MEDIUM' THEN 1 ELSE 0 END) medium_count "
        "FROM u2x_findings WHERE session_id = 'DEMO' "
        "GROUP BY analyzer_id ORDER BY critical_count DESC, high_count DESC"))

    regions.append((17002, 7, 'All Findings', 20, 'NATIVE_IR',
        "SELECT finding_id, analyzer_id, INITCAP(REPLACE(analyzer_id, '_', ' ')) analyzer_name, "
        "section, finding, detail, severity, finding_count, "
        "TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created "
        "FROM u2x_findings WHERE session_id = 'DEMO' "
        "ORDER BY DECODE(severity,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4,'INFO',5)"))

    # Page 8: Sessions
    regions.append((18001, 8, 'Analysis Sessions', 10, 'NATIVE_IR',
        "SELECT s.session_id, TO_CHAR(s.created_at, 'YYYY-MM-DD HH24:MI:SS') created_at, s.status, "
        "(SELECT COUNT(*) FROM u2x_findings f WHERE f.session_id = s.session_id) finding_count, "
        "(SELECT COUNT(*) FROM u2x_audit_trail a WHERE a.session_id = s.session_id) audit_count "
        "FROM u2x_sessions s ORDER BY s.created_at DESC"))

    for reg_id, pg_id, reg_name, seq, src_type, source in regions:
        run(cur, """
            BEGIN
                wwv_flow_imp_page.create_page_plug(
                    p_id                    => :rid,
                    p_flow_id               => :fid,
                    p_page_id               => :pid,
                    p_plug_name             => :name,
                    p_plug_display_sequence => :seq,
                    p_plug_source_type      => :stype,
                    p_plug_source           => :src,
                    p_plug_query_num_rows   => 200
                );
                commit;
            END;
        """, f"Page {pg_id}: {reg_name}",
            binds=dict(rid=reg_id, fid=app_id, pid=pg_id, name=reg_name, seq=seq, stype=src_type, src=source))

    conn.commit()

    # ── Summary ──
    cur.execute("SELECT COUNT(*) FROM apex_application_pages WHERE application_id = :a", a=app_id)
    pg_count = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM apex_application_page_regions WHERE application_id = :a", a=app_id)
    reg_count = cur.fetchone()[0]
    cur.execute("""
        SELECT authentication_scheme_name, scheme_type_code
        FROM apex_application_auth WHERE application_id = :a
    """, a=app_id)
    auth_info = cur.fetchone()

    cur.close()
    conn.close()

    print("\n" + "=" * 55)
    print("Deployment complete!")
    print(f"  App ID:     {app_id}")
    print(f"  Pages:      {pg_count}")
    print(f"  Regions:    {reg_count}")
    print(f"  Auth:       {auth_info[0]} ({auth_info[1]})")
    print()
    print("Access:")
    print(f"  http://apps.example.com:8080/apex/f?p={app_id}")
    print(f"  Login: W1_ADMIN / Admin15429")
    print(f"  (or any Workspace1 user)")
    print()
    print("App Builder:")
    print(f"  http://apps.example.com:8080/apex/apex")
    print(f"  Workspace: WORKSPACE1 | W1_ADMIN / Admin15429")
    print("=" * 55)


if __name__ == "__main__":
    main()
