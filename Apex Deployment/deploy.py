"""
U2xAI EBS Agentic Apps — Deploy SQL objects to Oracle DB via python-oracledb.
Usage: python deploy.py
"""
import oracledb
import sys
import os

# Enable thick mode for NNE (Native Network Encryption)
INSTANT_CLIENT = os.path.expanduser(
    r"~\Downloads\instantclient-basic-windows.x64-23.26.1.0.0\instantclient_23_0"
)
if os.path.isdir(INSTANT_CLIENT):
    oracledb.init_oracle_client(lib_dir=INSTANT_CLIENT)
    print(f"Thick mode enabled: {INSTANT_CLIENT}")
else:
    print(f"WARNING: Instant Client not found at {INSTANT_CLIENT}")
    print("Connection may fail if NNE is required.")

DB_HOST = "140.245.24.128"
DB_PORT = 1521
DB_SERVICE = "EBSDB"
DB_USER = "IZU"
DB_PASS = "IZU1001u"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# SQL files to run in order (04_ords_rest.sql skipped — ORDS is server-managed)
SQL_FILES = [
    "01_tables.sql",
    "02_packages.sql",
    "03_demo_data.sql",
]


def split_plsql_blocks(content):
    """Split a SQL file into executable statements.
    Handles CREATE TABLE, INSERT, CREATE INDEX, CREATE OR REPLACE PACKAGE, BEGIN...END blocks.
    Splits on '/' on its own line (PL/SQL block terminator) and ';' for DDL/DML.
    """
    blocks = []
    current = []
    in_plsql = False

    for line in content.splitlines():
        stripped = line.strip()

        # Skip empty lines, comments, PROMPT, SET commands
        if not stripped or stripped.startswith("--") or stripped.upper().startswith("PROMPT") or stripped.upper().startswith("SET "):
            continue

        # Detect PL/SQL block start
        if stripped.upper().startswith(("CREATE OR REPLACE PACKAGE", "CREATE OR REPLACE FUNCTION",
                                        "CREATE OR REPLACE PROCEDURE", "DECLARE", "BEGIN")):
            in_plsql = True

        if in_plsql:
            # '/' on its own line terminates a PL/SQL block
            if stripped == "/":
                block = "\n".join(current).strip()
                if block:
                    blocks.append(block)
                current = []
                in_plsql = False
            else:
                current.append(line)
        else:
            current.append(line)
            # ';' terminates DDL/DML
            if stripped.endswith(";"):
                block = "\n".join(current).strip()
                # Remove trailing semicolon for oracledb execute
                if block.endswith(";"):
                    block = block[:-1].strip()
                if block:
                    blocks.append(block)
                current = []

    # Leftover
    if current:
        block = "\n".join(current).strip()
        if block.endswith(";"):
            block = block[:-1].strip()
        if block and block != "/":
            blocks.append(block)

    return blocks


def run_sql_file(cursor, filepath):
    filename = os.path.basename(filepath)
    print(f"\n--- Running {filename} ---")
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    blocks = split_plsql_blocks(content)
    success = 0
    errors = 0

    for i, block in enumerate(blocks, 1):
        try:
            cursor.execute(block)
            success += 1
            # Show what we created
            upper = block.upper()[:80]
            if "CREATE TABLE" in upper:
                tname = block.split("(")[0].split()[-1]
                print(f"  [OK] Table {tname}")
            elif "CREATE INDEX" in upper:
                iname = block.split(" ON ")[0].split()[-1]
                print(f"  [OK] Index {iname}")
            elif "CREATE OR REPLACE PACKAGE BODY" in upper:
                pname = upper.split("PACKAGE BODY")[1].strip().split()[0]
                print(f"  [OK] Package Body {pname}")
            elif "CREATE OR REPLACE PACKAGE" in upper:
                pname = upper.split("PACKAGE")[1].strip().split()[0]
                print(f"  [OK] Package {pname}")
            elif "INSERT INTO" in upper:
                tname = block.upper().split("INSERT INTO")[1].strip().split()[0]
                print(f"  [OK] Insert into {tname}")
        except oracledb.DatabaseError as e:
            err = str(e)
            # Ignore "table already exists", "name already used"
            if "ORA-00955" in err or "ORA-01408" in err:
                obj = block.split("(")[0].split()[-1] if "(" in block else "object"
                print(f"  [SKIP] {obj} already exists")
                success += 1
            elif "ORA-00001" in err:  # unique constraint (duplicate insert)
                print(f"  [SKIP] Row already exists")
                success += 1
            else:
                print(f"  [ERROR] Statement {i}: {err[:200]}")
                errors += 1

    print(f"  {filename}: {success} OK, {errors} errors")
    return errors


def main():
    print("=" * 50)
    print("U2xAI EBS Agentic Apps — SQL Deployment")
    print(f"Target: {DB_USER}@{DB_HOST}:{DB_PORT}/{DB_SERVICE}")
    print("=" * 50)

    try:
        conn = oracledb.connect(
            user=DB_USER,
            password=DB_PASS,
            dsn=f"{DB_HOST}:{DB_PORT}/{DB_SERVICE}"
        )
        print(f"\nConnected as {DB_USER}")
    except Exception as e:
        print(f"\nConnection failed: {e}")
        sys.exit(1)

    cursor = conn.cursor()
    total_errors = 0

    for sql_file in SQL_FILES:
        filepath = os.path.join(SCRIPT_DIR, sql_file)
        if not os.path.exists(filepath):
            print(f"\n[SKIP] {sql_file} not found")
            continue
        total_errors += run_sql_file(cursor, filepath)

    conn.commit()
    cursor.close()
    conn.close()

    print("\n" + "=" * 50)
    if total_errors == 0:
        print("Deployment complete — all objects created successfully!")
    else:
        print(f"Deployment complete with {total_errors} error(s).")
    print()
    print("Next steps:")
    print("  1. Login to APEX: http://apps.example.com:8080/apex/apex")
    print("     Workspace: Workspace1")
    print("     Username:  W1_ADMIN")
    print("     Password:  Admin15429")
    print("  2. App Builder > Import > Upload 05_apex_app.sql")
    print("  3. Set parsing schema to IZU")
    print("=" * 50)


if __name__ == "__main__":
    main()
