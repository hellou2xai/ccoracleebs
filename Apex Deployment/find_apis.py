"""Find available APEX APIs for modifying/deleting page plugs."""
import oracledb, os

oracledb.init_oracle_client(lib_dir=os.path.expanduser(
    r"~\Downloads\instantclient-basic-windows.x64-23.26.1.0.0\instantclient_23_0"))
conn = oracledb.connect(user="IZU", password="IZU1001u",
                        dsn="140.245.24.128:1521/EBSDB")
cur = conn.cursor()

# Find remove/delete procedures in wwv_flow_imp_page
cur.execute("""
    SELECT DISTINCT object_name FROM all_arguments
    WHERE package_name = 'WWV_FLOW_IMP_PAGE'
    AND object_name LIKE '%REMOVE%' OR (package_name = 'WWV_FLOW_IMP_PAGE' AND object_name LIKE '%DELETE%')
    ORDER BY object_name
""")
print("Remove/Delete in WWV_FLOW_IMP_PAGE:")
for r in cur.fetchall():
    print(f"  {r[0]}")

# Check wwv_flow_api for page plug operations
cur.execute("""
    SELECT DISTINCT object_name FROM all_arguments
    WHERE package_name = 'WWV_FLOW_API'
    AND object_name LIKE '%PLUG%'
    ORDER BY object_name
""")
print("\nPlug-related in WWV_FLOW_API:")
for r in cur.fetchall():
    print(f"  {r[0]}")

# Check for any update/set procedure for page plugs
cur.execute("""
    SELECT DISTINCT package_name, object_name FROM all_arguments
    WHERE object_name LIKE '%PAGE_PLUG%'
    AND package_name IS NOT NULL
    ORDER BY package_name, object_name
""")
print("\nAll *PAGE_PLUG* procedures:")
for r in cur.fetchall():
    print(f"  {r[0]}.{r[1]}")

# Check if APEX_240100 schema table is accessible
cur.execute("""
    SELECT COUNT(*) FROM all_tables
    WHERE table_name = 'WWV_FLOW_PAGE_PLUGS'
""")
print(f"\nwwv_flow_page_plugs visible in all_tables: {cur.fetchone()[0]}")

# Try to find synonyms
cur.execute("""
    SELECT owner, synonym_name, table_owner, table_name
    FROM all_synonyms
    WHERE synonym_name = 'WWV_FLOW_PAGE_PLUGS'
""")
print("\nSynonyms for WWV_FLOW_PAGE_PLUGS:")
for r in cur.fetchall():
    print(f"  {r}")

# Can we access through fully qualified name?
try:
    cur.execute("SELECT COUNT(*) FROM APEX_240100.wwv_flow_page_plugs WHERE flow_id = :a", a=107)
    print(f"\nAPEX_240100.wwv_flow_page_plugs accessible: {cur.fetchone()[0]} rows")
except Exception as e:
    print(f"\nAPEX_240100.wwv_flow_page_plugs: {str(e)[:150]}")

# Check if wwv_flow has any DML helpers
cur.execute("""
    SELECT DISTINCT package_name, object_name FROM all_arguments
    WHERE package_name IN ('WWV_FLOW', 'WWV_FLOW_API', 'WWV_FLOW_UTILITIES')
    AND (object_name LIKE '%DELETE%PLUG%' OR object_name LIKE '%REMOVE%PLUG%'
         OR object_name LIKE '%UPDATE%PLUG%')
    ORDER BY package_name, object_name
""")
print("\nDML helpers for plugs:")
for r in cur.fetchall():
    print(f"  {r[0]}.{r[1]}")

cur.close()
conn.close()
