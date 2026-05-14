-- ============================================================================
-- U2xAI EBS Agentic Apps — Uninstall Script
-- ============================================================================
-- Drops all objects created by install.sql
-- Run as the application schema owner
-- ============================================================================

SET SERVEROUTPUT ON

PROMPT =============================================
PROMPT U2xAI EBS Agentic Apps — Uninstall
PROMPT =============================================

-- Drop ORDS module
BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'u2xapi');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('ORDS module dropped.');
EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('ORDS module not found (skipped).');
END;
/

-- Drop packages
DROP PACKAGE u2x_agents;
DROP PACKAGE u2x_session_mgr;
DROP PACKAGE u2x_observability;
DROP PACKAGE u2x_demo_data;

-- Drop tables (order matters for FK constraints)
DROP TABLE u2x_audit_trail   PURGE;
DROP TABLE u2x_findings      PURGE;
DROP TABLE u2x_sessions      PURGE;
DROP TABLE u2x_obs_events    PURGE;
DROP TABLE u2x_agent_state   PURGE;
DROP TABLE u2x_analyzers     PURGE;
DROP TABLE u2x_fusion_apps   PURGE;

PROMPT =============================================
PROMPT Uninstall complete.
PROMPT Remember to also delete the APEX application
PROMPT via App Builder if imported.
PROMPT =============================================
