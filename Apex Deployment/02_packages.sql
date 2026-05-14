-- ============================================================================
-- U2xAI EBS Agentic Apps — PL/SQL Packages
-- ============================================================================

-- ─── U2X_DEMO_DATA: Mock data for demo mode ────────────────────────────────
CREATE OR REPLACE PACKAGE u2x_demo_data AS

    TYPE t_finding IS RECORD (
        section     VARCHAR2(200),
        finding     VARCHAR2(4000),
        detail      CLOB,
        severity    VARCHAR2(20),
        cnt         NUMBER
    );
    TYPE t_findings IS TABLE OF t_finding;

    FUNCTION get_findings(p_analyzer_id VARCHAR2) RETURN SYS_REFCURSOR;
    FUNCTION get_ebs_version RETURN SYS_REFCURSOR;
    FUNCTION get_installed_products RETURN SYS_REFCURSOR;
    FUNCTION get_concurrent_managers RETURN SYS_REFCURSOR;
    FUNCTION get_agent_result(p_agent_id VARCHAR2) RETURN CLOB;

END u2x_demo_data;
/

CREATE OR REPLACE PACKAGE BODY u2x_demo_data AS

    FUNCTION get_findings(p_analyzer_id VARCHAR2) RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT section, finding, detail, severity, finding_count
            FROM u2x_findings
            WHERE analyzer_id = p_analyzer_id
              AND session_id = 'DEMO'
            ORDER BY finding_id;
        RETURN v_cur;
    END;

    FUNCTION get_ebs_version RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT '12.2.11' release_name,
                   '19.22.0.0.0' db_version,
                   '19' db_version_short,
                   'EBSDB' instance_name,
                   'apps.example.com' host_name
            FROM dual;
        RETURN v_cur;
    END;

    FUNCTION get_installed_products RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT 'SQLGL' app_short, 'General Ledger' app_name, 'I' status FROM dual UNION ALL
            SELECT 'AR',   'Receivables',       'I' FROM dual UNION ALL
            SELECT 'AP',   'Payables',          'I' FROM dual UNION ALL
            SELECT 'FA',   'Assets',            'I' FROM dual UNION ALL
            SELECT 'CE',   'Cash Management',   'I' FROM dual UNION ALL
            SELECT 'PO',   'Purchasing',        'I' FROM dual UNION ALL
            SELECT 'INV',  'Inventory',         'I' FROM dual UNION ALL
            SELECT 'BOM',  'Bills of Material', 'I' FROM dual UNION ALL
            SELECT 'WIP',  'Work In Process',   'I' FROM dual UNION ALL
            SELECT 'OE',   'Order Management',  'I' FROM dual UNION ALL
            SELECT 'HR',   'Human Resources',   'I' FROM dual UNION ALL
            SELECT 'PA',   'Projects',          'I' FROM dual UNION ALL
            SELECT 'WF',   'Workflow',          'I' FROM dual UNION ALL
            SELECT 'FND',  'Application Object Library', 'I' FROM dual
            ORDER BY 2;
        RETURN v_cur;
    END;

    FUNCTION get_concurrent_managers RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT 'Internal Concurrent Manager' mgr, 1 target, 1 actual, 0 running, 0 pending, 'ACTIVE' status FROM dual UNION ALL
            SELECT 'Standard Manager',            5,   5,        3,        8,         'ACTIVE' FROM dual UNION ALL
            SELECT 'Scheduler',                   1,   1,        0,        0,         'ACTIVE' FROM dual UNION ALL
            SELECT 'Conflict Resolution Manager', 1,   1,        0,        0,         'ACTIVE' FROM dual UNION ALL
            SELECT 'Output Post Processor',       2,   2,        1,        0,         'ACTIVE' FROM dual;
        RETURN v_cur;
    END;

    FUNCTION get_agent_result(p_agent_id VARCHAR2) RETURN CLOB IS
        v_result CLOB;
    BEGIN
        -- Returns JSON result for a given agent in demo mode
        SELECT JSON_OBJECT(
            'agent_id'   VALUE p_agent_id,
            'demo_mode'  VALUE 'true',
            'severity'   VALUE NVL(last_severity, 'INFO'),
            'summary'    VALUE 'Demo result for ' || agent_label,
            'row_count'  VALUE total_runs
        )
        INTO v_result
        FROM u2x_agent_state
        WHERE agent_id = p_agent_id;

        RETURN v_result;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN '{"agent_id":"' || p_agent_id || '","severity":"INFO","summary":"No demo data","row_count":0}';
    END;

END u2x_demo_data;
/

-- ─── U2X_OBSERVABILITY: Event logging ──────────────────────────────────────
CREATE OR REPLACE PACKAGE u2x_observability AS

    PROCEDURE emit_event(
        p_run_id      VARCHAR2,
        p_agent_id    VARCHAR2,
        p_agent_label VARCHAR2,
        p_phase       VARCHAR2,
        p_source      VARCHAR2,
        p_message     VARCHAR2,
        p_severity    VARCHAR2 DEFAULT NULL,
        p_rows        NUMBER   DEFAULT NULL,
        p_duration_ms NUMBER   DEFAULT NULL,
        p_error       CLOB     DEFAULT NULL
    );

    PROCEDURE update_agent_state(
        p_agent_id    VARCHAR2,
        p_agent_label VARCHAR2,
        p_phase       VARCHAR2,
        p_run_id      VARCHAR2,
        p_severity    VARCHAR2 DEFAULT NULL,
        p_duration_ms NUMBER   DEFAULT NULL
    );

    FUNCTION recent_events(
        p_limit    NUMBER   DEFAULT 200,
        p_agent_id VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR;

    FUNCTION get_stats RETURN CLOB;

END u2x_observability;
/

CREATE OR REPLACE PACKAGE BODY u2x_observability AS

    PROCEDURE emit_event(
        p_run_id      VARCHAR2,
        p_agent_id    VARCHAR2,
        p_agent_label VARCHAR2,
        p_phase       VARCHAR2,
        p_source      VARCHAR2,
        p_message     VARCHAR2,
        p_severity    VARCHAR2 DEFAULT NULL,
        p_rows        NUMBER   DEFAULT NULL,
        p_duration_ms NUMBER   DEFAULT NULL,
        p_error       CLOB     DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO u2x_obs_events (
            run_id, agent_id, agent_label, phase, source,
            message, severity, rows_count, duration_ms, error_text
        ) VALUES (
            p_run_id, p_agent_id, p_agent_label, p_phase, p_source,
            p_message, p_severity, p_rows, p_duration_ms, p_error
        );

        update_agent_state(p_agent_id, p_agent_label, p_phase,
                          p_run_id, p_severity, p_duration_ms);
        COMMIT;
    END;

    PROCEDURE update_agent_state(
        p_agent_id    VARCHAR2,
        p_agent_label VARCHAR2,
        p_phase       VARCHAR2,
        p_run_id      VARCHAR2,
        p_severity    VARCHAR2 DEFAULT NULL,
        p_duration_ms NUMBER   DEFAULT NULL
    ) IS
    BEGIN
        MERGE INTO u2x_agent_state t
        USING (SELECT p_agent_id aid FROM dual) s
        ON (t.agent_id = s.aid)
        WHEN MATCHED THEN UPDATE SET
            agent_label    = NVL(p_agent_label, t.agent_label),
            last_phase     = p_phase,
            last_run_id    = p_run_id,
            last_ts        = SYSTIMESTAMP,
            last_severity  = CASE WHEN p_phase IN ('complete','error') THEN NVL(p_severity, t.last_severity) ELSE t.last_severity END,
            last_duration_ms = CASE WHEN p_phase IN ('complete','error') THEN p_duration_ms ELSE t.last_duration_ms END,
            total_runs     = t.total_runs + CASE WHEN p_phase = 'complete' THEN 1 ELSE 0 END,
            total_errors   = t.total_errors + CASE WHEN p_phase = 'error' THEN 1 ELSE 0 END,
            in_flight      = GREATEST(0, t.in_flight
                             + CASE WHEN p_phase = 'start' THEN 1
                                    WHEN p_phase IN ('complete','error') THEN -1
                                    ELSE 0 END)
        WHEN NOT MATCHED THEN INSERT (
            agent_id, agent_label, last_phase, last_run_id,
            last_severity, last_duration_ms, last_ts,
            total_runs, total_errors, in_flight
        ) VALUES (
            p_agent_id, p_agent_label, p_phase, p_run_id,
            p_severity, p_duration_ms, SYSTIMESTAMP,
            CASE WHEN p_phase = 'complete' THEN 1 ELSE 0 END,
            CASE WHEN p_phase = 'error' THEN 1 ELSE 0 END,
            CASE WHEN p_phase = 'start' THEN 1 ELSE 0 END
        );
    END;

    FUNCTION recent_events(
        p_limit    NUMBER   DEFAULT 200,
        p_agent_id VARCHAR2 DEFAULT NULL
    ) RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT event_id, run_id, agent_id, agent_label,
                   phase, source, message, severity,
                   rows_count, duration_ms, error_text,
                   TO_CHAR(event_ts, 'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"') ts
            FROM u2x_obs_events
            WHERE (p_agent_id IS NULL OR agent_id = p_agent_id)
            ORDER BY event_ts DESC
            FETCH FIRST p_limit ROWS ONLY;
        RETURN v_cur;
    END;

    FUNCTION get_stats RETURN CLOB IS
        v_json CLOB;
    BEGIN
        SELECT JSON_OBJECT(
            'events_total' VALUE COUNT(*),
            'total_runs'   VALUE SUM(CASE WHEN phase = 'complete' THEN 1 ELSE 0 END),
            'total_errors' VALUE SUM(CASE WHEN phase = 'error' THEN 1 ELSE 0 END),
            'in_flight'    VALUE (SELECT NVL(SUM(in_flight),0) FROM u2x_agent_state),
            'avg_duration_ms' VALUE NVL(
                ROUND(AVG(CASE WHEN phase = 'complete' THEN duration_ms END)),0),
            'agents_seen'  VALUE (SELECT COUNT(*) FROM u2x_agent_state)
        )
        INTO v_json
        FROM u2x_obs_events;
        RETURN v_json;
    END;

END u2x_observability;
/

-- ─── U2X_AGENTS: Agent execution engine ────────────────────────────────────
CREATE OR REPLACE PACKAGE u2x_agents AS

    FUNCTION run_agent(
        p_agent_id  VARCHAR2,
        p_days_back NUMBER   DEFAULT 30,
        p_source    VARCHAR2 DEFAULT 'ui',
        p_demo_mode VARCHAR2 DEFAULT 'Y'
    ) RETURN CLOB;

    FUNCTION run_all_agents(
        p_days_back NUMBER   DEFAULT 30,
        p_source    VARCHAR2 DEFAULT 'ui',
        p_demo_mode VARCHAR2 DEFAULT 'Y'
    ) RETURN CLOB;

    FUNCTION list_agents RETURN CLOB;

END u2x_agents;
/

CREATE OR REPLACE PACKAGE BODY u2x_agents AS

    FUNCTION run_agent(
        p_agent_id  VARCHAR2,
        p_days_back NUMBER   DEFAULT 30,
        p_source    VARCHAR2 DEFAULT 'ui',
        p_demo_mode VARCHAR2 DEFAULT 'Y'
    ) RETURN CLOB IS
        v_run_id  VARCHAR2(40) := DBMS_RANDOM.STRING('x', 12);
        v_label   VARCHAR2(200);
        v_t0      TIMESTAMP := SYSTIMESTAMP;
        v_ms      NUMBER;
        v_result  CLOB;
    BEGIN
        -- Get agent label
        BEGIN
            SELECT agent_label INTO v_label
            FROM u2x_agent_state WHERE agent_id = p_agent_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN v_label := INITCAP(REPLACE(p_agent_id, '_', ' '));
        END;

        -- Emit start
        u2x_observability.emit_event(
            v_run_id, p_agent_id, v_label, 'start', p_source,
            v_label || ' started'
        );

        -- Execute (demo mode returns mock data)
        IF p_demo_mode = 'Y' THEN
            v_result := u2x_demo_data.get_agent_result(p_agent_id);
        ELSE
            -- Live mode: execute actual EBS queries
            -- Placeholder for live query execution
            v_result := '{"agent_id":"' || p_agent_id || '","severity":"INFO","summary":"Live mode query executed","row_count":0}';
        END IF;

        -- Calculate duration
        v_ms := EXTRACT(SECOND FROM (SYSTIMESTAMP - v_t0)) * 1000;

        -- Emit complete
        u2x_observability.emit_event(
            v_run_id, p_agent_id, v_label, 'complete', p_source,
            v_label || ' done (' || v_ms || 'ms)',
            JSON_VALUE(v_result, '$.severity'),
            JSON_VALUE(v_result, '$.row_count' RETURNING NUMBER),
            v_ms
        );

        RETURN v_result;

    EXCEPTION
        WHEN OTHERS THEN
            v_ms := EXTRACT(SECOND FROM (SYSTIMESTAMP - v_t0)) * 1000;
            u2x_observability.emit_event(
                v_run_id, p_agent_id, v_label, 'error', p_source,
                v_label || ' error: ' || SQLERRM,
                p_duration_ms => v_ms,
                p_error => SQLERRM
            );
            RETURN '{"agent_id":"' || p_agent_id || '","error":"' || SQLERRM || '"}';
    END;

    FUNCTION run_all_agents(
        p_days_back NUMBER   DEFAULT 30,
        p_source    VARCHAR2 DEFAULT 'ui',
        p_demo_mode VARCHAR2 DEFAULT 'Y'
    ) RETURN CLOB IS
        v_results CLOB := '[';
        v_first   BOOLEAN := TRUE;
    BEGIN
        FOR r IN (SELECT agent_id FROM u2x_agent_state ORDER BY agent_id) LOOP
            IF NOT v_first THEN v_results := v_results || ','; END IF;
            v_results := v_results || run_agent(r.agent_id, p_days_back, p_source, p_demo_mode);
            v_first := FALSE;
        END LOOP;
        v_results := v_results || ']';
        RETURN v_results;
    END;

    FUNCTION list_agents RETURN CLOB IS
        v_json CLOB;
    BEGIN
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'id'           VALUE agent_id,
                'label'        VALUE agent_label,
                'last_phase'   VALUE last_phase,
                'last_severity' VALUE last_severity,
                'total_runs'   VALUE total_runs,
                'total_errors' VALUE total_errors
            ) ORDER BY agent_id
        )
        INTO v_json
        FROM u2x_agent_state;
        RETURN NVL(v_json, '[]');
    END;

END u2x_agents;
/

-- ─── U2X_SESSION_MGR: Session management ───────────────────────────────────
CREATE OR REPLACE PACKAGE u2x_session_mgr AS

    FUNCTION create_session RETURN VARCHAR2;
    PROCEDURE save_finding(
        p_session_id  VARCHAR2,
        p_analyzer_id VARCHAR2,
        p_section     VARCHAR2,
        p_finding     VARCHAR2,
        p_detail      CLOB,
        p_severity    VARCHAR2,
        p_count       NUMBER DEFAULT 0
    );
    PROCEDURE log_audit(
        p_session_id VARCHAR2,
        p_action     VARCHAR2,
        p_detail     CLOB DEFAULT NULL
    );
    FUNCTION get_session_json(p_session_id VARCHAR2) RETURN CLOB;
    FUNCTION recent_sessions(p_limit NUMBER DEFAULT 5) RETURN SYS_REFCURSOR;

END u2x_session_mgr;
/

CREATE OR REPLACE PACKAGE BODY u2x_session_mgr AS

    FUNCTION create_session RETURN VARCHAR2 IS
        v_id VARCHAR2(64) := SYS_GUID();
    BEGIN
        INSERT INTO u2x_sessions (session_id) VALUES (v_id);
        COMMIT;
        RETURN v_id;
    END;

    PROCEDURE save_finding(
        p_session_id  VARCHAR2,
        p_analyzer_id VARCHAR2,
        p_section     VARCHAR2,
        p_finding     VARCHAR2,
        p_detail      CLOB,
        p_severity    VARCHAR2,
        p_count       NUMBER DEFAULT 0
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO u2x_findings (
            session_id, analyzer_id, section, finding, detail, severity, finding_count
        ) VALUES (
            p_session_id, p_analyzer_id, p_section, p_finding, p_detail, p_severity, p_count
        );
        COMMIT;
    END;

    PROCEDURE log_audit(
        p_session_id VARCHAR2,
        p_action     VARCHAR2,
        p_detail     CLOB DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO u2x_audit_trail (session_id, action, detail)
        VALUES (p_session_id, p_action, p_detail);
        COMMIT;
    END;

    FUNCTION get_session_json(p_session_id VARCHAR2) RETURN CLOB IS
        v_json CLOB;
    BEGIN
        SELECT JSON_OBJECT(
            'session_id' VALUE s.session_id,
            'created_at' VALUE TO_CHAR(s.created_at, 'YYYY-MM-DD"T"HH24:MI:SS'),
            'findings'   VALUE (
                SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'section'  VALUE f.section,
                        'finding'  VALUE f.finding,
                        'severity' VALUE f.severity,
                        'count'    VALUE f.finding_count
                    ) ORDER BY f.finding_id
                )
                FROM u2x_findings f WHERE f.session_id = s.session_id
            )
        )
        INTO v_json
        FROM u2x_sessions s
        WHERE s.session_id = p_session_id;
        RETURN v_json;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END;

    FUNCTION recent_sessions(p_limit NUMBER DEFAULT 5) RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT session_id,
                   TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created_at,
                   status
            FROM u2x_sessions
            ORDER BY created_at DESC
            FETCH FIRST p_limit ROWS ONLY;
        RETURN v_cur;
    END;

END u2x_session_mgr;
/

PROMPT PL/SQL packages created successfully.
