"""Fix app 107: assign region templates and remove Hero via APEX_240100 schema."""
import oracledb, os

oracledb.init_oracle_client(lib_dir=os.path.expanduser(
    r"~\Downloads\instantclient-basic-windows.x64-23.26.1.0.0\instantclient_23_0"))
conn = oracledb.connect(user="IZU", password="IZU1001u",
                        dsn="140.245.24.128:1521/EBSDB")
cur = conn.cursor()
cur.execute("BEGIN apex_util.set_security_group_id(100101); END;")

APP = 107

# Template IDs from Universal Theme 42 in app 107
TMPL_STANDARD = 73647999069219887
TMPL_IR = 73638157529219884
TMPL_CARDS = 73588476704219869
TMPL_ALERT = 73576198585219865

# Map region IDs to desired templates
region_templates = {
    11001: TMPL_CARDS,      # System Health
    11002: TMPL_STANDARD,   # Findings by Severity
    11003: TMPL_STANDARD,   # Agent Overview
    12001: TMPL_CARDS,      # Agentic App Catalog
    13001: TMPL_IR,         # AP Period Close Findings
    13002: TMPL_IR,         # All Payables Findings
    14001: TMPL_CARDS,      # Agent Status
    15001: TMPL_STANDARD,   # Observability Stats
    15002: TMPL_STANDARD,   # Agent State
    15003: TMPL_IR,         # Event Log
    16001: TMPL_ALERT,      # Process Mining Overview
    16002: TMPL_STANDARD,   # Process Flow Summary
    17001: TMPL_STANDARD,   # Analyzer Summary
    17002: TMPL_IR,         # All Findings
    18001: TMPL_IR,         # Analysis Sessions
}

print("--- Updating region templates via APEX_240100 schema ---")
for reg_id, tmpl_id in region_templates.items():
    try:
        cur.execute("""
            UPDATE APEX_240100.wwv_flow_page_plugs
            SET plug_template = :tid
            WHERE id = :rid AND flow_id = :fid
        """, tid=tmpl_id, rid=reg_id, fid=APP)
        if cur.rowcount:
            print(f"  [OK] Region {reg_id} -> template {tmpl_id}")
        else:
            print(f"  [SKIP] Region {reg_id} not found")
    except Exception as e:
        print(f"  [ERROR] Region {reg_id}: {str(e)[:200]}")
conn.commit()

# Remove Hero region
print("\n--- Removing default Hero region ---")
try:
    cur.execute("""
        DELETE FROM APEX_240100.wwv_flow_page_plugs
        WHERE id = 73846051282220003 AND flow_id = :fid
    """, fid=APP)
    if cur.rowcount:
        print("  [OK] Removed Hero region")
    else:
        print("  [SKIP] Hero region not found")
    conn.commit()
except Exception as e:
    print(f"  [INFO] {str(e)[:150]}")

# Verify
cur.execute("""
    SELECT region_id, page_id, region_name, template
    FROM apex_application_page_regions
    WHERE application_id = :a AND page_id BETWEEN 1 AND 8
    ORDER BY page_id, display_sequence
""", a=APP)
print("\nFinal regions:")
for r in cur.fetchall():
    print(f"  Page {r[1]}: {r[2]} [{r[3]}]")

print(f"\n{'='*55}")
print(f"Done! Refresh: http://apps.example.com:8080/apex/f?p={APP}")
print(f"{'='*55}")

cur.close()
conn.close()
