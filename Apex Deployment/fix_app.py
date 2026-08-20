"""Fix app 107: assign region templates, fix sidebar nav."""
import oracledb, os

oracledb.init_oracle_client(lib_dir=os.path.expanduser(
    r"~\Downloads\instantclient-basic-windows.x64-23.26.1.0.0\instantclient_23_0"))
conn = oracledb.connect(user="IZU", password="IZU1001u",
                        dsn="140.245.24.128:1521/EBSDB")
cur = conn.cursor()
cur.execute("BEGIN apex_util.set_security_group_id(100101); END;")
cur.execute("BEGIN wwv_flow.g_flow_id := 107; END;")

APP = 107

# Template IDs from Universal Theme 42 in app 107
TMPL_STANDARD = 73647999069219887
TMPL_IR = 73638157529219884
TMPL_CARDS = 73588476704219869
TMPL_ALERT = 73576198585219865
TMPL_CONTENT = 73610089602219876
SIDEBAR_LIST_ID = 73545103723219854

# ── Region -> Template mapping ──
region_templates = {
    # page 1: Dashboard
    11001: TMPL_CARDS,      # System Health -> Cards
    11002: TMPL_STANDARD,   # Findings by Severity
    11003: TMPL_STANDARD,   # Agent Overview
    # page 2: EBS Apps
    12001: TMPL_CARDS,      # Agentic App Catalog -> Cards
    # page 3: Payables
    13001: TMPL_IR,         # AP Period Close Findings
    13002: TMPL_IR,         # All Payables Findings
    # page 4: AP Agents
    14001: TMPL_CARDS,      # Agent Status -> Cards
    # page 5: Observability
    15001: TMPL_STANDARD,   # Stats
    15002: TMPL_STANDARD,   # Agent State
    15003: TMPL_IR,         # Event Log
    # page 6: Process Mining
    16001: TMPL_ALERT,      # Overview -> Alert
    16002: TMPL_STANDARD,   # Process Flow
    # page 7: Analyzers
    17001: TMPL_STANDARD,   # Summary
    17002: TMPL_IR,         # All Findings
    # page 8: Sessions
    18001: TMPL_IR,         # Sessions
}

print("--- Updating region templates ---")
for reg_id, tmpl_id in region_templates.items():
    try:
        cur.execute("""
            UPDATE wwv_flow_page_plugs
            SET plug_template = :tid
            WHERE id = :rid AND flow_id = :fid
        """, tid=tmpl_id, rid=reg_id, fid=APP)
        if cur.rowcount:
            print(f"  [OK] Region {reg_id} -> template {tmpl_id}")
        else:
            print(f"  [SKIP] Region {reg_id} not found")
    except Exception as e:
        print(f"  [ERROR] Region {reg_id}: {str(e)[:150]}")
conn.commit()

# ── Fix sidebar nav ──
print("\n--- Fixing sidebar navigation ---")

# Remove items from wrong list (Navigation Bar = 73834552895219995)
try:
    cur.execute("""
        DELETE FROM wwv_flow_list_items
        WHERE list_id = 73834552895219995
        AND flow_id = :fid
        AND list_item_link_text IN ('EBS Apps','Payables','AP Agents','Observability','Process Mining','Analyzers','Sessions')
    """, fid=APP)
    print(f"  Removed {cur.rowcount} items from Navigation Bar")
    conn.commit()
except Exception as e:
    print(f"  [WARN] Cleanup: {str(e)[:100]}")

# Check existing sidebar entries
cur.execute("""
    SELECT entry_text FROM apex_application_list_entries
    WHERE application_id = :a AND list_id = :lid
""", a=APP, lid=SIDEBAR_LIST_ID)
existing = {r[0] for r in cur.fetchall()}
print(f"  Existing sidebar: {existing}")

# Add sidebar items
nav_items = [
    (20, "EBS Apps",       "2", "fa-th"),
    (30, "Payables",       "3", "fa-money-bill"),
    (40, "AP Agents",      "4", "fa-users"),
    (50, "Observability",  "5", "fa-line-chart"),
    (60, "Process Mining", "6", "fa-sitemap"),
    (70, "Analyzers",      "7", "fa-search"),
    (80, "Sessions",       "8", "fa-clock-o"),
]

for seq, label, pg, icon in nav_items:
    if label in existing:
        continue
    iid = SIDEBAR_LIST_ID * 10 + seq
    try:
        cur.execute("""
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
        """, fid=APP, iid=iid, lid=SIDEBAR_LIST_ID, seq=seq, name=label,
             target=f"f?p=&APP_ID.:{pg}:&SESSION.::&DEBUG.::::", icon=icon)
        print(f"  [OK] Sidebar: {label}")
    except Exception as e:
        print(f"  [ERROR] {label}: {str(e)[:150]}")

# ── Remove default Hero region from page 1 ──
print("\n--- Cleanup ---")
try:
    cur.execute("""
        DELETE FROM wwv_flow_page_plugs
        WHERE id = 73846051282220003 AND flow_id = :fid
    """, fid=APP)
    if cur.rowcount:
        print("  [OK] Removed default Hero region from page 1")
    conn.commit()
except Exception as e:
    print(f"  [SKIP] Hero: {str(e)[:100]}")

# Verify
cur.execute("""
    SELECT region_id, page_id, region_name, template
    FROM apex_application_page_regions WHERE application_id = :a
    AND page_id BETWEEN 1 AND 8
    ORDER BY page_id, display_sequence
""", a=APP)
print("\nFinal regions:")
for r in cur.fetchall():
    print(f"  Page {r[1]}: {r[2]} [{r[3]}]")

cur.execute("""
    SELECT entry_text FROM apex_application_list_entries
    WHERE application_id = :a AND list_id = :lid
    ORDER BY display_sequence
""", a=APP, lid=SIDEBAR_LIST_ID)
print(f"\nSidebar: {[r[0] for r in cur.fetchall()]}")

print(f"\n{'='*55}")
print(f"Done! Refresh: http://apps.example.com:8080/apex/f?p={APP}")
print(f"{'='*55}")

cur.close()
conn.close()
