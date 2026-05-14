-- ============================================================================
-- U2xAI EBS Agentic Apps — APEX Master Install Script
-- ============================================================================
-- Run as the application schema owner:
--   sqlplus apps/apps@EBSDB @install.sql
-- ============================================================================

SET SERVEROUTPUT ON
SET DEFINE OFF

PROMPT =============================================
PROMPT U2xAI EBS Agentic Apps — APEX Installation
PROMPT =============================================

PROMPT [1/4] Creating tables and sequences...
@@01_tables.sql

PROMPT [2/4] Creating PL/SQL packages...
@@02_packages.sql

PROMPT [3/4] Seeding demo data...
@@03_demo_data.sql

PROMPT [4/4] Registering ORDS REST modules...
@@04_ords_rest.sql

PROMPT =============================================
PROMPT Installation complete.
PROMPT
PROMPT Next steps:
PROMPT   1. Import 05_apex_app.sql via APEX App Builder
PROMPT   2. Set substitution strings (see README.md)
PROMPT   3. Run the application
PROMPT =============================================
