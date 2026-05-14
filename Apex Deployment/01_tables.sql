-- ============================================================================
-- U2xAI EBS Agentic Apps — Table Definitions
-- ============================================================================

-- Sessions
CREATE TABLE u2x_sessions (
    session_id      VARCHAR2(64)  PRIMARY KEY,
    created_at      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    status          VARCHAR2(20)  DEFAULT 'active',
    metadata_json   CLOB          CONSTRAINT u2x_sess_json CHECK (metadata_json IS JSON)
);

CREATE INDEX u2x_sessions_created_idx ON u2x_sessions (created_at DESC);

-- Findings (analyzer results)
CREATE TABLE u2x_findings (
    finding_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id      VARCHAR2(64)  NOT NULL REFERENCES u2x_sessions(session_id),
    analyzer_id     VARCHAR2(100) NOT NULL,
    section         VARCHAR2(200),
    finding         VARCHAR2(4000),
    detail          CLOB,
    severity        VARCHAR2(20)  NOT NULL,
    finding_count   NUMBER        DEFAULT 0,
    created_at      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE INDEX u2x_findings_sess_idx ON u2x_findings (session_id, created_at);
CREATE INDEX u2x_findings_sev_idx  ON u2x_findings (severity);

-- Audit trail
CREATE TABLE u2x_audit_trail (
    audit_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    session_id      VARCHAR2(64)  NOT NULL REFERENCES u2x_sessions(session_id),
    action          VARCHAR2(200) NOT NULL,
    detail          CLOB,
    created_at      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE INDEX u2x_audit_sess_idx ON u2x_audit_trail (session_id, created_at);

-- Observability events (agent execution log)
CREATE TABLE u2x_obs_events (
    event_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    run_id          VARCHAR2(40),
    agent_id        VARCHAR2(100),
    agent_label     VARCHAR2(200),
    phase           VARCHAR2(20),
    source          VARCHAR2(20),
    message         VARCHAR2(4000),
    severity        VARCHAR2(20),
    rows_count      NUMBER,
    duration_ms     NUMBER,
    error_text      CLOB,
    event_ts        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE INDEX u2x_obs_ts_idx    ON u2x_obs_events (event_ts DESC);
CREATE INDEX u2x_obs_agent_idx ON u2x_obs_events (agent_id, event_ts DESC);
CREATE INDEX u2x_obs_run_idx   ON u2x_obs_events (run_id);

-- Agent state (aggregated per agent)
CREATE TABLE u2x_agent_state (
    agent_id        VARCHAR2(100) PRIMARY KEY,
    agent_label     VARCHAR2(200),
    last_phase      VARCHAR2(20),
    last_run_id     VARCHAR2(40),
    last_severity   VARCHAR2(20),
    last_duration_ms NUMBER,
    last_ts         TIMESTAMP,
    total_runs      NUMBER        DEFAULT 0,
    total_errors    NUMBER        DEFAULT 0,
    in_flight       NUMBER        DEFAULT 0
);

-- Analyzer registry cache
CREATE TABLE u2x_analyzers (
    analyzer_id     VARCHAR2(100) PRIMARY KEY,
    name            VARCHAR2(200) NOT NULL,
    module          VARCHAR2(100),
    category        VARCHAR2(100),
    description     VARCHAR2(4000),
    severity_rules  CLOB          CONSTRAINT u2x_anlz_json CHECK (severity_rules IS JSON),
    is_active       VARCHAR2(1)   DEFAULT 'Y'
);

-- Fusion/EBS Agentic Apps catalog
CREATE TABLE u2x_fusion_apps (
    app_id          VARCHAR2(100) PRIMARY KEY,
    app_name        VARCHAR2(200) NOT NULL,
    pillar          VARCHAR2(50),
    icon_class      VARCHAR2(100),
    tagline         VARCHAR2(1000),
    kpis_json       CLOB          CONSTRAINT u2x_fapp_json CHECK (kpis_json IS JSON),
    queries_json    CLOB,
    is_active       VARCHAR2(1)   DEFAULT 'Y'
);

PROMPT Tables and indexes created successfully.
