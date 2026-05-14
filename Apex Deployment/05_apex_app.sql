-- ============================================================================
-- U2xAI EBS Agentic Apps — APEX Application Definition
-- ============================================================================
-- This script creates the APEX application structure.
-- Import via: APEX App Builder > Import > Upload this file
--
-- NOTE: This is a creation script, not a full APEX export.
-- After running, customize pages in the APEX builder.
-- ============================================================================

SET DEFINE OFF

PROMPT Creating APEX Application: U2xAI EBS Agentic Apps...

BEGIN
    -- Remove existing app if re-installing
    FOR c IN (SELECT application_id FROM apex_applications WHERE alias = 'U2XEBS') LOOP
        APEX_APPLICATION_INSTALL.SET_APPLICATION_ID(c.application_id);
    END LOOP;
END;
/

-- ─── Application Creation ──────────────────────────────────────────────────
BEGIN
    APEX_APPLICATION_INSTALL.SET_APPLICATION_ALIAS('U2XEBS');
    APEX_APPLICATION_INSTALL.SET_APPLICATION_NAME('U2xAI EBS Agentic Apps');
    APEX_APPLICATION_INSTALL.GENERATE_APPLICATION_ID;
END;
/

DECLARE
    l_app_id NUMBER;
BEGIN
    l_app_id := APEX_APPLICATION_INSTALL.GET_APPLICATION_ID;

    -- ═══ Create Application ═══
    APEX_APPLICATION.CREATE_APPLICATION(
        p_application_id    => l_app_id,
        p_display_name      => 'U2xAI EBS Agentic Apps',
        p_application_group => NULL,
        p_owner             => USER,
        p_default_page      => 1,
        p_theme_number      => 42,  -- Universal Theme
        p_theme_style_id    => NULL
    );

    -- ═══ Application Substitution Strings ═══
    APEX_APPLICATION.CREATE_SUBSTITUTION(
        p_application_id => l_app_id,
        p_name           => 'G_DEMO_MODE',
        p_value          => 'Y'
    );
    APEX_APPLICATION.CREATE_SUBSTITUTION(
        p_application_id => l_app_id,
        p_name           => 'G_APP_TITLE',
        p_value          => 'U2xAI EBS Agentic Apps'
    );
    APEX_APPLICATION.CREATE_SUBSTITUTION(
        p_application_id => l_app_id,
        p_name           => 'G_LOGIN_USER',
        p_value          => 'Admin'
    );
    APEX_APPLICATION.CREATE_SUBSTITUTION(
        p_application_id => l_app_id,
        p_name           => 'G_LOGIN_PASS',
        p_value          => 'admin123'
    );

    -- ═══ Authentication Scheme (Custom) ═══
    APEX_AUTHENTICATION.CREATE_AUTHENTICATION(
        p_application_id       => l_app_id,
        p_name                 => 'U2xAI Static Login',
        p_scheme_type          => 'NATIVE_CUSTOM',
        p_authentication_function => q'[
FUNCTION u2x_authenticate(
    p_username IN VARCHAR2,
    p_password IN VARCHAR2
) RETURN BOOLEAN IS
BEGIN
    RETURN (p_username = V('G_LOGIN_USER') AND p_password = V('G_LOGIN_PASS'));
END;
]',
        p_is_current           => TRUE
    );

    -- ═══ Navigation Menu ═══
    -- Sidebar entries matching Flask app
    APEX_APPLICATION.CREATE_LIST(
        p_application_id => l_app_id,
        p_list_name      => 'Desktop Navigation Menu',
        p_list_type      => 'STATIC'
    );

    APEX_APPLICATION.CREATE_LIST_ENTRY(p_application_id => l_app_id, p_list_name => 'Desktop Navigation Menu',
        p_display_sequence => 10, p_entry_text => 'Dashboard',       p_entry_target => 'f?p=&APP_ID.:1:&SESSION.', p_entry_image => 'fa-home');
    APEX_APPLICATION.CREATE_LIST_ENTRY(p_application_id => l_app_id, p_list_name => 'Desktop Navigation Menu',
        p_display_sequence => 20, p_entry_text => 'EBS Apps',        p_entry_target => 'f?p=&APP_ID.:2:&SESSION.', p_entry_image => 'fa-robot');
    APEX_APPLICATION.CREATE_LIST_ENTRY(p_application_id => l_app_id, p_list_name => 'Desktop Navigation Menu',
        p_display_sequence => 30, p_entry_text => 'Payables',        p_entry_target => 'f?p=&APP_ID.:3:&SESSION.', p_entry_image => 'fa-file-invoice-dollar');
    APEX_APPLICATION.CREATE_LIST_ENTRY(p_application_id => l_app_id, p_list_name => 'Desktop Navigation Menu',
        p_display_sequence => 40, p_entry_text => 'AP Agents',       p_entry_target => 'f?p=&APP_ID.:4:&SESSION.', p_entry_image => 'fa-people-group');
    APEX_APPLICATION.CREATE_LIST_ENTRY(p_application_id => l_app_id, p_list_name => 'Desktop Navigation Menu',
        p_display_sequence => 50, p_entry_text => 'Observability',   p_entry_target => 'f?p=&APP_ID.:5:&SESSION.', p_entry_image => 'fa-wave-square');
    APEX_APPLICATION.CREATE_LIST_ENTRY(p_application_id => l_app_id, p_list_name => 'Desktop Navigation Menu',
        p_display_sequence => 60, p_entry_text => 'Process Mining',  p_entry_target => 'f?p=&APP_ID.:6:&SESSION.', p_entry_image => 'fa-diagram-project');
    APEX_APPLICATION.CREATE_LIST_ENTRY(p_application_id => l_app_id, p_list_name => 'Desktop Navigation Menu',
        p_display_sequence => 70, p_entry_text => 'Analyzers',       p_entry_target => 'f?p=&APP_ID.:7:&SESSION.', p_entry_image => 'fa-stethoscope');
    APEX_APPLICATION.CREATE_LIST_ENTRY(p_application_id => l_app_id, p_list_name => 'Desktop Navigation Menu',
        p_display_sequence => 80, p_entry_text => 'Sessions',        p_entry_target => 'f?p=&APP_ID.:8:&SESSION.', p_entry_image => 'fa-clock-rotate-left');

    DBMS_OUTPUT.PUT_LINE('Application ' || l_app_id || ' structure created.');
END;
/

-- ═══════════════════════════════════════════════════════════════════════════
-- Page Definitions
-- ═══════════════════════════════════════════════════════════════════════════
-- NOTE: APEX pages are best created via the Application Builder GUI.
-- Below are page-creation hints for manual setup after importing this script.
-- ═══════════════════════════════════════════════════════════════════════════

PROMPT
PROMPT =============================================
PROMPT APEX Application created. Now create pages:
PROMPT =============================================
PROMPT
PROMPT Page 1  - Dashboard (Home)
PROMPT           Region: Cards - System Health (source: /api/system/health)
PROMPT           Region: Cards - Quick Actions
PROMPT           Region: Chart - Severity Distribution
PROMPT
PROMPT Page 2  - EBS Agentic Apps
PROMPT           Region: Cards (source: u2x_fusion_apps)
PROMPT           Each card: icon, name, pillar, tagline, KPIs
PROMPT           Button: Run App -> Dynamic Action calling ORDS
PROMPT
PROMPT Page 3  - Payables Workspace
PROMPT           Region: IR - Unposted Invoices
PROMPT           Region: IR - Invoices On Hold
PROMPT           Region: IR - Aging Summary
PROMPT           Region: KPI Cards (STP Rate, Cycle Time, etc.)
PROMPT
PROMPT Page 4  - AP Agents
PROMPT           Region: Cards - 10 Agent tiles with status badges
PROMPT           Button: Run Agent / Run All
PROMPT           Dynamic Actions call u2x_agents.run_agent via AJAX
PROMPT
PROMPT Page 5  - Observability
PROMPT           Region: Cards - Agent State (source: u2x_agent_state)
PROMPT           Region: Classic Report - Live Events (source: u2x_obs_events)
PROMPT           Region: Stats pills (in-flight, runs, errors, avg ms)
PROMPT           Auto-refresh: Dynamic Action with timer (5 sec)
PROMPT
PROMPT Page 6  - Process Mining
PROMPT           Region: Chart - Process Flow (Sankey/Directed Graph)
PROMPT           Region: IR - Case List
PROMPT           Region: KPI Cards (Happy Path %, Variants, Avg Time)
PROMPT
PROMPT Page 7  - Analyzers
PROMPT           Region: IR on u2x_findings WHERE session_id = 'DEMO'
PROMPT           Faceted Search on: severity, analyzer_id, section
PROMPT
PROMPT Page 8  - Sessions
PROMPT           Region: IR on u2x_sessions
PROMPT           Link column to Session Detail (modal page)
PROMPT
PROMPT Page 9999 - Login Page
PROMPT           Custom authentication: u2x_authenticate function
PROMPT           Username: Admin, Password: admin123
PROMPT
PROMPT =============================================
PROMPT
PROMPT QUICK SETUP GUIDE:
PROMPT 1. Open APEX App Builder for this application
PROMPT 2. Create pages using the hints above
PROMPT 3. For each IR/CR region, use the SQL sources below
PROMPT =============================================

-- ─── SQL Sources for APEX Regions ──────────────────────────────────────────

PROMPT
PROMPT === Page 2: EBS Apps Cards ===
PROMPT SQL Source:
PROMPT   SELECT app_id, app_name, pillar, icon_class, tagline, kpis_json
PROMPT   FROM u2x_fusion_apps WHERE is_active = 'Y'
PROMPT   ORDER BY pillar, app_name

PROMPT
PROMPT === Page 4: Agent Tiles ===
PROMPT SQL Source:
PROMPT   SELECT agent_id, agent_label, last_phase, last_severity,
PROMPT          last_duration_ms, total_runs, total_errors, in_flight,
PROMPT          TO_CHAR(last_ts, 'YYYY-MM-DD HH24:MI:SS') last_run
PROMPT   FROM u2x_agent_state ORDER BY agent_id

PROMPT
PROMPT === Page 5: Observability Events ===
PROMPT SQL Source:
PROMPT   SELECT event_id, run_id, agent_id, agent_label, phase, source,
PROMPT          message, severity, rows_count, duration_ms,
PROMPT          TO_CHAR(event_ts, 'HH24:MI:SS.FF3') ts
PROMPT   FROM u2x_obs_events
PROMPT   ORDER BY event_ts DESC
PROMPT   FETCH FIRST 200 ROWS ONLY

PROMPT
PROMPT === Page 7: Findings / Analyzers ===
PROMPT SQL Source:
PROMPT   SELECT finding_id, analyzer_id, section, finding,
PROMPT          severity, finding_count,
PROMPT          TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created
PROMPT   FROM u2x_findings
PROMPT   ORDER BY created_at DESC

PROMPT
PROMPT === Page 8: Sessions ===
PROMPT SQL Source:
PROMPT   SELECT session_id,
PROMPT          TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created_at,
PROMPT          status,
PROMPT          (SELECT COUNT(*) FROM u2x_findings f
PROMPT           WHERE f.session_id = s.session_id) finding_count
PROMPT   FROM u2x_sessions s
PROMPT   WHERE session_id != 'DEMO'
PROMPT   ORDER BY created_at DESC

PROMPT
PROMPT === Dynamic Action: Run Agent ===
PROMPT   JavaScript:
PROMPT     apex.server.process('RUN_AGENT', {
PROMPT       x01: agentId,
PROMPT       x02: daysBack
PROMPT     }, {
PROMPT       success: function(data) { apex.region('agent_grid').refresh(); }
PROMPT     });
PROMPT
PROMPT   PL/SQL Process (AJAX Callback named RUN_AGENT):
PROMPT     DECLARE v_result CLOB;
PROMPT     BEGIN
PROMPT       v_result := u2x_agents.run_agent(APEX_APPLICATION.G_X01,
PROMPT                   NVL(APEX_APPLICATION.G_X02, 30), 'ui', 'Y');
PROMPT       HTP.P(v_result);
PROMPT     END;

PROMPT
PROMPT Installation complete.
