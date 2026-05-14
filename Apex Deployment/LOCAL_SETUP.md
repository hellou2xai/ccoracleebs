# Local Deployment Guide — Oracle APEX + ORDS on Windows

Complete step-by-step guide to run U2xAI EBS Agentic Apps locally
using Oracle APEX on your existing Oracle EBS database.

## Architecture

```
Browser (localhost:8080)
    |
    v
ORDS (Java standalone, port 8080)
    |
    v
Oracle Database (140.245.24.128:1521 / EBSDB)
    |-- APEX engine (installed in DB)
    |-- U2X_* packages (our app logic)
    |-- EBS tables (live or demo data)
```

## Prerequisites

- Windows 10/11
- Java 11+ (JDK or JRE) — required for ORDS
- Oracle Instant Client 23.x (you already have this)
- Oracle SQL*Plus or SQLcl
- Access to Oracle DB at 140.245.24.128:1521

---

## Step 1: Install APEX into the Database

APEX runs entirely inside the Oracle database. Install it once.

### 1.1 Download APEX

Download from: https://www.oracle.com/tools/downloads/apex-downloads/
- Choose **Oracle APEX 24.1** (or latest)
- Extract to `C:\apex`

### 1.2 Connect as SYSDBA

```cmd
sqlplus sys/your_sys_password@//140.245.24.128:1521/EBSDB as sysdba
```

### 1.3 Run APEX Install

```sql
-- From the C:\apex directory
@apexins.sql SYSAUX SYSAUX TEMP /i/

-- This takes 20-45 minutes. Do NOT interrupt.
-- Parameters: tablespace for APEX, tablespace for files, temp tablespace, images alias
```

### 1.4 Create APEX Instance Admin

```sql
-- Set the APEX admin password
BEGIN
    APEX_UTIL.SET_SECURITY_GROUP_ID(10);
    APEX_UTIL.CREATE_USER(
        p_user_name       => 'ADMIN',
        p_email_address   => 'admin@u2xai.com',
        p_web_password    => 'Admin123!',
        p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
        p_change_password_on_first_use => 'N'
    );
    COMMIT;
END;
/
```

### 1.5 Configure APEX REST

```sql
@apex_rest_config.sql

-- When prompted, enter passwords for APEX_LISTENER and APEX_REST_PUBLIC_USER
-- Use: OracleRest1!  (or your preferred password)
```

### 1.6 Unlock APEX accounts

```sql
ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;
ALTER USER APEX_PUBLIC_USER IDENTIFIED BY OracleApex1!;

ALTER USER APEX_REST_PUBLIC_USER ACCOUNT UNLOCK;
ALTER USER APEX_REST_PUBLIC_USER IDENTIFIED BY OracleRest1!;

ALTER USER APEX_LISTENER ACCOUNT UNLOCK;
ALTER USER APEX_LISTENER IDENTIFIED BY OracleRest1!;
```

---

## Step 2: Install ORDS (Standalone)

ORDS is the web server that serves APEX pages.

### 2.1 Download ORDS

Download from: https://www.oracle.com/database/technologies/appdev/rest-data-services-downloads.html
- Choose **ORDS 24.x** (latest)
- Extract to `C:\ords`

### 2.2 Verify Java

```cmd
java -version
```

Requires Java 11+. If not installed, download from https://adoptium.net/

### 2.3 Configure ORDS

```cmd
cd C:\ords\bin

ords install ^
  --admin-user SYS ^
  --db-hostname 140.245.24.128 ^
  --db-port 1521 ^
  --db-servicename EBSDB ^
  --feature-sdw true ^
  --log-folder C:\ords\logs ^
  --config-dir C:\ords\config
```

When prompted:
- SYS password: your sys password
- APEX static files: Choose "Enter the APEX static resources location": `C:\apex\images`
- Accept defaults for other prompts

### 2.4 Copy APEX Static Files

```cmd
mkdir C:\ords\config\global\doc_root\i
xcopy /E /I C:\apex\images C:\ords\config\global\doc_root\i
```

### 2.5 Start ORDS

```cmd
cd C:\ords\bin
ords serve --port 8080
```

You should see:
```
Oracle REST Data Services initialized
...
Mapped local pools from ...
Oracle REST Data Services - Started
```

### 2.6 Verify APEX is Running

Open browser: **http://localhost:8080/ords/apex_admin**

Login:
- Workspace: INTERNAL
- Username: ADMIN
- Password: Admin123!

---

## Step 3: Create APEX Workspace

### 3.1 Via APEX Admin

1. Login to http://localhost:8080/ords/apex_admin
2. Click **Create Workspace**
3. Settings:
   - Workspace Name: `U2XEBS`
   - Schema: `APPS` (or create new schema `U2XEBS_APP`)
   - Workspace Admin: `ADMIN` / `Admin123!`
4. Click **Create Workspace**

### 3.2 Via SQL (alternative)

```sql
BEGIN
    APEX_INSTANCE_ADMIN.ADD_WORKSPACE(
        p_workspace      => 'U2XEBS',
        p_primary_schema => 'APPS'
    );

    APEX_UTIL.SET_WORKSPACE('U2XEBS');
    APEX_UTIL.CREATE_USER(
        p_user_name       => 'ADMIN',
        p_email_address   => 'admin@u2xai.com',
        p_web_password    => 'Admin123!',
        p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
        p_change_password_on_first_use => 'N'
    );
    COMMIT;
END;
/
```

---

## Step 4: Deploy U2xAI App

### 4.1 Run SQL Scripts

Connect as the workspace schema owner:

```cmd
cd "C:\Users\SambitTripathy\OneDrive - U2xAI\ClaudeCode Demos\Support\EBS\Apex Deployment"

sqlplus apps/apps@//140.245.24.128:1521/EBSDB @install.sql
```

This creates tables, packages, demo data, and ORDS REST endpoints.

### 4.2 Import APEX Application

1. Open http://localhost:8080/ords/f?p=4550
2. Login to workspace `U2XEBS` as `ADMIN`
3. Go to **App Builder** > **Import**
4. Upload: `05_apex_app.sql`
5. Click through the wizard:
   - File Type: Application Export
   - Schema: APPS (or your schema)
   - Build Status: Run and Build Application
6. Click **Install Application**

### 4.3 Run the Application

Open: **http://localhost:8080/ords/f?p=U2XEBS**

Login: **Admin / admin123**

---

## Step 5: Create a Windows Service (Optional)

To run ORDS as a background service so it starts automatically:

### 5.1 Create start script

Save as `C:\ords\start_ords.bat`:

```bat
@echo off
cd /d C:\ords\bin
java -jar ords.war standalone --port 8080
```

### 5.2 Using NSSM (recommended)

Download NSSM from https://nssm.cc/download

```cmd
nssm install OracleORDS "C:\ords\start_ords.bat"
nssm set OracleORDS AppDirectory "C:\ords\bin"
nssm set OracleORDS DisplayName "Oracle REST Data Services"
nssm set OracleORDS Start SERVICE_AUTO_START

net start OracleORDS
```

### 5.3 Using Task Scheduler (alternative)

1. Open Task Scheduler
2. Create Basic Task: "Oracle ORDS"
3. Trigger: At Startup
4. Action: Start Program → `C:\ords\start_ords.bat`
5. Check "Run whether user is logged on or not"

---

## Quick Reference

| Component | URL |
|-----------|-----|
| APEX Admin | http://localhost:8080/ords/apex_admin |
| App Builder | http://localhost:8080/ords/f?p=4550 |
| U2xAI App | http://localhost:8080/ords/f?p=U2XEBS |
| ORDS REST API | http://localhost:8080/ords/u2xebs/api/ |
| Health Check | http://localhost:8080/ords/u2xebs/api/system/health |

| Credential | Username | Password |
|------------|----------|----------|
| APEX Admin | ADMIN | Admin123! |
| App Login | Admin | admin123 |
| DB Schema | apps | apps |

---

## Troubleshooting

### ORDS won't start
- Check Java version: `java -version` (needs 11+)
- Check port not in use: `netstat -an | findstr 8080`
- Check ORDS logs: `C:\ords\logs\`

### APEX pages show 404
- Verify APEX images path: `C:\ords\config\global\doc_root\i\` should contain apex CSS/JS files
- Re-run: `ords install` and specify the correct images path

### "ORA-20001: Package not found"
- Ensure `@install.sql` was run as the correct schema
- Check: `SELECT object_name, status FROM user_objects WHERE object_name LIKE 'U2X%';`

### Login fails
- Default credentials: Admin / admin123
- Check substitution strings in Shared Components > Application Definition

### REST API returns 404
- Verify ORDS module: `SELECT * FROM user_ords_modules;`
- Re-run `04_ords_rest.sql`
- Check schema is ORDS-enabled: `SELECT * FROM user_ords_schemas;`
