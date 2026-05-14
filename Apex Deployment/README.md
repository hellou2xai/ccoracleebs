# U2xAI EBS Agentic Apps - Oracle APEX Deployment

## Overview

This package deploys the U2xAI EBS Agentic Apps demo as a native Oracle APEX application,
running entirely within your Oracle database. No external Python/Flask server required.

## Architecture

```
Browser  -->  Oracle APEX  -->  PL/SQL Packages  -->  EBS Tables (live or demo)
                  |
                  +--> ORDS REST APIs (for AJAX regions)
```

## Prerequisites

- Oracle Database 19c+ with Oracle EBS 12.2 schema (or standalone for demo mode)
- Oracle APEX 23.1+ installed
- ORDS (Oracle REST Data Services) 23.x+
- An APEX workspace with at least one developer account

## Installation Steps

### 1. Connect as the application schema owner

```sql
sqlplus apps/apps@EBSDB
```

Or create a dedicated schema:

```sql
CREATE USER u2xai_apex IDENTIFIED BY <password>
  DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW,
      CREATE PROCEDURE, CREATE SEQUENCE, CREATE TRIGGER TO u2xai_apex;
-- Grant read access to EBS tables
GRANT SELECT ON apps.ap_invoices_all TO u2xai_apex;
GRANT SELECT ON apps.ap_holds_all TO u2xai_apex;
GRANT SELECT ON apps.fnd_concurrent_queues_vl TO u2xai_apex;
GRANT SELECT ON apps.fnd_application_vl TO u2xai_apex;
GRANT SELECT ON apps.fnd_product_groups TO u2xai_apex;
-- Add more grants as needed for each analyzer
```

### 2. Run the master install script

```sql
@install.sql
```

This executes in order:
1. `01_tables.sql` — Creates application tables and sequences
2. `02_packages.sql` — PL/SQL packages for demo data, analyzers, agents
3. `03_demo_data.sql` — Seeds demo/mock data for all modules
4. `04_ords_rest.sql` — Registers ORDS REST modules and handlers

### 3. Import the APEX application

1. Log in to APEX as a workspace admin
2. Go to **App Builder > Import**
3. Upload `05_apex_app.sql`
4. Follow the wizard: select workspace, parsing schema = your schema
5. Click **Install Application**

### 4. Configure the application

After import, set these APEX Substitution Strings (Shared Components > Application Definition > Substitutions):

| Name | Value | Description |
|------|-------|-------------|
| `G_DEMO_MODE` | `Y` | Set to `N` for live EBS queries |
| `G_APP_TITLE` | `U2xAI EBS Agentic Apps` | Application header title |
| `G_LOGIN_USER` | `Admin` | Static login username |
| `G_LOGIN_PASS` | `admin123` | Static login password |

### 5. Run the application

Navigate to:
```
https://your-server:port/ords/f?p=U2XEBS
```

Login: **Admin / admin123**

## File Inventory

| File | Purpose |
|------|---------|
| `install.sql` | Master installer — runs all scripts in order |
| `01_tables.sql` | DDL for application tables, sequences, indexes |
| `02_packages.sql` | PL/SQL packages: U2X_DEMO_DATA, U2X_ANALYZERS, U2X_AGENTS, U2X_OBSERVABILITY |
| `03_demo_data.sql` | INSERT statements for demo findings, agent results |
| `04_ords_rest.sql` | ORDS REST module with handlers matching Flask API |
| `05_apex_app.sql` | APEX application export (pages, regions, processes) |
| `uninstall.sql` | Drops all objects created by install.sql |

## Demo Mode vs Live Mode

- **Demo Mode (G_DEMO_MODE = Y):** All queries return realistic mock data from U2X_DEMO_DATA package. No EBS table access needed.
- **Live Mode (G_DEMO_MODE = N):** Queries execute against real EBS tables (ap_invoices_all, fnd_concurrent_queues_vl, etc.).

## Uninstall

```sql
@uninstall.sql
```
