-- ============================================================================
-- U2xAI EBS Agentic Apps — ORDS REST API Module
-- ============================================================================
-- These REST endpoints mirror the Flask app's /api/* routes.
-- They are consumed by APEX AJAX callbacks and Interactive Reports.
-- ============================================================================

BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled             => TRUE,
        p_schema              => USER,
        p_url_mapping_type    => 'BASE_PATH',
        p_url_mapping_pattern => 'u2xebs',
        p_auto_rest_auth      => FALSE
    );
    COMMIT;
END;
/

-- ─── Module: U2xAI EBS API ─────────────────────────────────────────────────
BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'u2xapi',
        p_base_path      => '/api/',
        p_items_per_page => 200,
        p_status         => 'PUBLISHED',
        p_comments       => 'U2xAI EBS Agentic Apps REST API'
    );
    COMMIT;
END;
/

-- ─── GET /api/system/health ────────────────────────────────────────────────
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'u2xapi',
        p_pattern     => 'system/health'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'u2xapi',
        p_pattern     => 'system/health',
        p_method      => 'GET',
        p_source_type => 'plsql/block',
        p_source      => q'[
DECLARE
    v_stats CLOB;
BEGIN
    v_stats := u2x_observability.get_stats;
    OWA_UTIL.MIME_HEADER('application/json', FALSE);
    HTP.P('{');
    HTP.P('"app_version":"1.0.0",');
    HTP.P('"app_ready":true,');
    HTP.P('"ebs_version":"12.2.11",');
    HTP.P('"oracle":{"connected":true,"demo_mode":true},');
    HTP.P('"observability":' || NVL(v_stats,'{}'));
    HTP.P('}');
END;
]'
    );
    COMMIT;
END;
/

-- ─── GET /api/fusion/apps ──────────────────────────────────────────────────
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'u2xapi',
        p_pattern     => 'fusion/apps'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'u2xapi',
        p_pattern     => 'fusion/apps',
        p_method      => 'GET',
        p_source_type => 'json/collection',
        p_source      => q'[
SELECT app_id, app_name, pillar, icon_class, tagline, kpis_json
FROM u2x_fusion_apps
WHERE is_active = 'Y'
ORDER BY pillar, app_name
]'
    );
    COMMIT;
END;
/

-- ─── GET /api/payables_agents/list ─────────────────────────────────────────
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'u2xapi',
        p_pattern     => 'payables_agents/list'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'u2xapi',
        p_pattern     => 'payables_agents/list',
        p_method      => 'GET',
        p_source_type => 'plsql/block',
        p_source      => q'[
BEGIN
    HTP.P('{"agents":' || u2x_agents.list_agents || '}');
END;
]'
    );
    COMMIT;
END;
/

-- ─── POST /api/payables_agents/run/:agent_id ───────────────────────────────
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'u2xapi',
        p_pattern     => 'payables_agents/run/:agent_id'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'u2xapi',
        p_pattern     => 'payables_agents/run/:agent_id',
        p_method      => 'POST',
        p_source_type => 'plsql/block',
        p_source      => q'[
DECLARE
    v_result CLOB;
    v_days   NUMBER := NVL(:days_back, 30);
BEGIN
    v_result := u2x_agents.run_agent(:agent_id, v_days, 'ui', 'Y');
    HTP.P(v_result);
END;
]'
    );
    COMMIT;
END;
/

-- ─── POST /api/payables_agents/run_all ─────────────────────────────────────
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'u2xapi',
        p_pattern     => 'payables_agents/run_all'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'u2xapi',
        p_pattern     => 'payables_agents/run_all',
        p_method      => 'POST',
        p_source_type => 'plsql/block',
        p_source      => q'[
DECLARE
    v_results CLOB;
    v_days    NUMBER := NVL(:days_back, 30);
BEGIN
    v_results := u2x_agents.run_all_agents(v_days, 'ui', 'Y');
    HTP.P('{"results":' || v_results || '}');
END;
]'
    );
    COMMIT;
END;
/

-- ─── GET /api/observability/recent ─────────────────────────────────────────
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'u2xapi',
        p_pattern     => 'observability/recent'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'u2xapi',
        p_pattern     => 'observability/recent',
        p_method      => 'GET',
        p_source_type => 'json/collection',
        p_source      => q'[
SELECT event_id, run_id, agent_id, agent_label, phase, source,
       message, severity, rows_count, duration_ms,
       TO_CHAR(event_ts, 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"') ts
FROM u2x_obs_events
ORDER BY event_ts DESC
FETCH FIRST 200 ROWS ONLY
]'
    );
    COMMIT;
END;
/

-- ─── GET /api/sessions ─────────────────────────────────────────────────────
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'u2xapi',
        p_pattern     => 'sessions'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'u2xapi',
        p_pattern     => 'sessions',
        p_method      => 'GET',
        p_source_type => 'json/collection',
        p_source      => q'[
SELECT session_id,
       TO_CHAR(created_at, 'YYYY-MM-DD"T"HH24:MI:SS') created_at,
       status
FROM u2x_sessions
WHERE session_id != 'DEMO'
ORDER BY created_at DESC
FETCH FIRST 20 ROWS ONLY
]'
    );
    COMMIT;
END;
/

-- ─── GET /api/sessions/:session_id ─────────────────────────────────────────
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'u2xapi',
        p_pattern     => 'sessions/:session_id'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'u2xapi',
        p_pattern     => 'sessions/:session_id',
        p_method      => 'GET',
        p_source_type => 'plsql/block',
        p_source      => q'[
DECLARE
    v_json CLOB;
BEGIN
    v_json := u2x_session_mgr.get_session_json(:session_id);
    IF v_json IS NULL THEN
        OWA_UTIL.STATUS_LINE(404);
        HTP.P('{"error":"Session not found"}');
    ELSE
        HTP.P(v_json);
    END IF;
END;
]'
    );
    COMMIT;
END;
/

-- ─── GET /api/analyzers (demo findings grouped by analyzer) ────────────────
BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'u2xapi',
        p_pattern     => 'analyzers'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'u2xapi',
        p_pattern     => 'analyzers',
        p_method      => 'GET',
        p_source_type => 'json/collection',
        p_source      => q'[
SELECT analyzer_id,
       COUNT(*) finding_count,
       MAX(severity) top_severity
FROM u2x_findings
WHERE session_id = 'DEMO'
GROUP BY analyzer_id
ORDER BY analyzer_id
]'
    );
    COMMIT;
END;
/

PROMPT ORDS REST modules registered successfully.
