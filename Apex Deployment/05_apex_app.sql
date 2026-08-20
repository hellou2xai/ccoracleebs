prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- Oracle APEX export file
--
-- You should run this script connected to SQL*Plus as the Oracle user
-- APEX_xxxxxx or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------

-- Application Export:
--   Application:     100
--   Name:            U2xAI EBS Agentic Apps
--   Date and Time:   14:00 Wednesday May 14, 2026
--   Exported By:     W1_ADMIN
--   Flashback:       0
--   Export Type:     Application Export
--     Pages:                      9
--       Items:                    2
--       Processes:                2
--       Regions:                 16
--       Lists:                    1
--     Shared Components:
--       Authentication:           1
--       Authorization:            0
--   Skip Metadata:   N
--   Workspace Name:  WORKSPACE1
--   Schema:          IZU

prompt --application/set_application
begin
    wwv_flow_application_install.set_application_id(100);
    wwv_flow_application_install.set_schema('IZU');
end;
/

prompt --application/delete_application
begin
    wwv_flow_api.remove_flow(wwv_flow.g_flow_id);
exception when others then null;
end;
/

prompt --application/create_application
begin
wwv_flow_api.create_flow(
  p_id                  => wwv_flow.g_flow_id
 ,p_owner               => nvl(wwv_flow_application_install.get_schema,'IZU')
 ,p_name                => 'U2xAI EBS Agentic Apps'
 ,p_alias               => 'U2XEBS'
 ,p_page_view_logging   => 'YES'
 ,p_page_protection_enabled_y_n => 'Y'
 ,p_checksum_salt_last_reset => '20260514000000'
 ,p_max_session_length_sec => 28800
 ,p_max_session_idle_sec  => 3600
 ,p_compatibility_mode   => '19.2'
 ,p_flow_language        => 'en'
 ,p_flow_language_derived_from => 'FLOW_PRIMARY_LANGUAGE'
 ,p_direction_right_to_left => 'N'
 ,p_flow_image_prefix    => nvl(wwv_flow_application_install.get_image_prefix,'')
 ,p_authentication       => 'PLUGIN'
 ,p_authentication_id    => wwv_flow_api.id(1)
 ,p_application_tab_set  => 1
 ,p_logo_type            => 'T'
 ,p_logo_text            => 'U2xAI EBS Agentic Apps'
 ,p_public_user          => 'APEX_PUBLIC_USER'
 ,p_proxy_server         => nvl(wwv_flow_application_install.get_proxy,'')
 ,p_no_proxy_domains     => nvl(wwv_flow_application_install.get_no_proxy_domains,'')
 ,p_flow_version         => '1.0.0'
 ,p_flow_status          => 'AVAILABLE_W_EDIT_LINK'
 ,p_exact_substitutions_only => 'Y'
 ,p_browser_cache        => 'N'
 ,p_browser_frame        => 'D'
 ,p_rejoin_existing_sessions => 'N'
 ,p_friendly_url         => 'N'
 ,p_last_updated_by      => 'W1_ADMIN'
 ,p_last_upd_yyyymmddhh24miss => '20260514140000'
);
end;
/

--------------------------------------------------------------------------------
-- Authentication
--------------------------------------------------------------------------------
prompt --application/shared_components/security/authentication/u2xai_login
begin
wwv_flow_api.create_authentication(
  p_id            => wwv_flow_api.id(1)
 ,p_flow_id       => wwv_flow.g_flow_id
 ,p_name          => 'U2xAI Login'
 ,p_scheme_type   => 'NATIVE_CUSTOM'
 ,p_attribute_05  => q'[RETURN UPPER(:P9999_USERNAME) = 'ADMIN' AND :P9999_PASSWORD = 'admin123';]'
 ,p_invalid_session_type => 'LOGIN'
 ,p_invalid_session_url  => 'f?p=&APP_ID.:9999:&SESSION.'
 ,p_logout_url    => 'f?p=&APP_ID.:9999:&SESSION.'
 ,p_cookie_name   => 'U2XEBS_SESSION'
 ,p_use_login_cookie  => 'Y'
 ,p_use_secure_cookie_yn => 'N'
 ,p_ras_mode      => 0
);
end;
/

--------------------------------------------------------------------------------
-- Application Substitution Strings
--------------------------------------------------------------------------------
prompt --application/shared_components/globalization/substitution_strings
begin
wwv_flow_api.create_flow_item(
  p_id            => wwv_flow_api.id(100001)
 ,p_flow_id       => wwv_flow.g_flow_id
 ,p_name          => 'G_APP_TITLE'
 ,p_protection_level => 'I'
 ,p_item_comment  => 'Application title displayed in header'
);
end;
/

--------------------------------------------------------------------------------
-- Navigation Menu (List)
--------------------------------------------------------------------------------
prompt --application/shared_components/navigation/lists/desktop_navigation_menu
begin
wwv_flow_api.create_list(
  p_id            => wwv_flow_api.id(200)
 ,p_flow_id       => wwv_flow.g_flow_id
 ,p_name          => 'Desktop Navigation Menu'
 ,p_list_status   => 'PUBLIC'
);

-- Dashboard
wwv_flow_api.create_list_item(
  p_id            => wwv_flow_api.id(201)
 ,p_list_id       => wwv_flow_api.id(200)
 ,p_list_item_display_sequence => 10
 ,p_list_item_link_text => 'Dashboard'
 ,p_list_item_link_target => 'f?p=&APP_ID.:1:&SESSION.::&DEBUG.::::'
 ,p_list_item_icon => 'fa-home'
 ,p_list_item_current_type => 'TARGET_PAGE'
);

-- EBS Apps
wwv_flow_api.create_list_item(
  p_id            => wwv_flow_api.id(202)
 ,p_list_id       => wwv_flow_api.id(200)
 ,p_list_item_display_sequence => 20
 ,p_list_item_link_text => 'EBS Apps'
 ,p_list_item_link_target => 'f?p=&APP_ID.:2:&SESSION.::&DEBUG.::::'
 ,p_list_item_icon => 'fa-robot'
 ,p_list_item_current_type => 'TARGET_PAGE'
);

-- Payables
wwv_flow_api.create_list_item(
  p_id            => wwv_flow_api.id(203)
 ,p_list_id       => wwv_flow_api.id(200)
 ,p_list_item_display_sequence => 30
 ,p_list_item_link_text => 'Payables'
 ,p_list_item_link_target => 'f?p=&APP_ID.:3:&SESSION.::&DEBUG.::::'
 ,p_list_item_icon => 'fa-money-bill'
 ,p_list_item_current_type => 'TARGET_PAGE'
);

-- AP Agents
wwv_flow_api.create_list_item(
  p_id            => wwv_flow_api.id(204)
 ,p_list_id       => wwv_flow_api.id(200)
 ,p_list_item_display_sequence => 40
 ,p_list_item_link_text => 'AP Agents'
 ,p_list_item_link_target => 'f?p=&APP_ID.:4:&SESSION.::&DEBUG.::::'
 ,p_list_item_icon => 'fa-users'
 ,p_list_item_current_type => 'TARGET_PAGE'
);

-- Observability
wwv_flow_api.create_list_item(
  p_id            => wwv_flow_api.id(205)
 ,p_list_id       => wwv_flow_api.id(200)
 ,p_list_item_display_sequence => 50
 ,p_list_item_link_text => 'Observability'
 ,p_list_item_link_target => 'f?p=&APP_ID.:5:&SESSION.::&DEBUG.::::'
 ,p_list_item_icon => 'fa-line-chart'
 ,p_list_item_current_type => 'TARGET_PAGE'
);

-- Process Mining
wwv_flow_api.create_list_item(
  p_id            => wwv_flow_api.id(206)
 ,p_list_id       => wwv_flow_api.id(200)
 ,p_list_item_display_sequence => 60
 ,p_list_item_link_text => 'Process Mining'
 ,p_list_item_link_target => 'f?p=&APP_ID.:6:&SESSION.::&DEBUG.::::'
 ,p_list_item_icon => 'fa-diagram-project'
 ,p_list_item_current_type => 'TARGET_PAGE'
);

-- Analyzers
wwv_flow_api.create_list_item(
  p_id            => wwv_flow_api.id(207)
 ,p_list_id       => wwv_flow_api.id(200)
 ,p_list_item_display_sequence => 70
 ,p_list_item_link_text => 'Analyzers'
 ,p_list_item_link_target => 'f?p=&APP_ID.:7:&SESSION.::&DEBUG.::::'
 ,p_list_item_icon => 'fa-search'
 ,p_list_item_current_type => 'TARGET_PAGE'
);

-- Sessions
wwv_flow_api.create_list_item(
  p_id            => wwv_flow_api.id(208)
 ,p_list_id       => wwv_flow_api.id(200)
 ,p_list_item_display_sequence => 80
 ,p_list_item_link_text => 'Sessions'
 ,p_list_item_link_target => 'f?p=&APP_ID.:8:&SESSION.::&DEBUG.::::'
 ,p_list_item_icon => 'fa-clock-o'
 ,p_list_item_current_type => 'TARGET_PAGE'
);

end;
/

--------------------------------------------------------------------------------
-- Page 1: Dashboard
--------------------------------------------------------------------------------
prompt --application/pages/page_00001
begin
wwv_flow_api.create_page(
  p_id             => 1
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_user_interface_id => wwv_flow_api.id(0)
 ,p_name           => 'Dashboard'
 ,p_alias          => 'HOME'
 ,p_step_title     => 'Dashboard'
 ,p_autocomplete_on_off => 'OFF'
 ,p_page_template_options => 'DEFAULT'
 ,p_page_is_public_y_n => 'N'
 ,p_last_updated_by => 'W1_ADMIN'
 ,p_last_upd_yyyymmddhh24miss => '20260514140000'
);

-- Region: System Health Cards
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(1001)
 ,p_plug_name      => 'System Health'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 10
 ,p_plug_source_type => 'NATIVE_SQL_REPORT'
 ,p_plug_source    => q'[SELECT
  'EBS Version' label, '12.2.11' value, 'fa-database' icon, 'u-success' css FROM dual UNION ALL
SELECT 'Database', '19c (19.22)', 'fa-server', 'u-success' FROM dual UNION ALL
SELECT 'Active Agents', TO_CHAR((SELECT COUNT(*) FROM u2x_agent_state)), 'fa-users', 'u-info' FROM dual UNION ALL
SELECT 'Open Findings', TO_CHAR((SELECT COUNT(*) FROM u2x_findings WHERE session_id='DEMO')), 'fa-warning', 'u-warning' FROM dual UNION ALL
SELECT 'Critical Issues', TO_CHAR((SELECT COUNT(*) FROM u2x_findings WHERE session_id='DEMO' AND severity='CRITICAL')), 'fa-exclamation-triangle', 'u-danger' FROM dual UNION ALL
SELECT 'Demo Data Rows', TO_CHAR((SELECT COUNT(*) FROM u2x_fusion_apps)), 'fa-table', 'u-info' FROM dual]'
 ,p_plug_query_num_rows => 20
);

-- Region: Severity Distribution
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(1002)
 ,p_plug_name      => 'Findings by Severity'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 20
 ,p_plug_source_type => 'NATIVE_SQL_REPORT'
 ,p_plug_source    => q'[SELECT severity, COUNT(*) cnt
FROM u2x_findings
WHERE session_id = 'DEMO'
GROUP BY severity
ORDER BY DECODE(severity,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4,'INFO',5)]'
 ,p_plug_query_num_rows => 20
);

-- Region: Recent Agent Activity
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(1003)
 ,p_plug_name      => 'Agent Status'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 30
 ,p_plug_source_type => 'NATIVE_SQL_REPORT'
 ,p_plug_source    => q'[SELECT agent_id, agent_label, last_phase, last_severity,
       total_runs, total_errors, in_flight,
       TO_CHAR(last_ts, 'YYYY-MM-DD HH24:MI:SS') last_run
FROM u2x_agent_state
ORDER BY agent_id]'
 ,p_plug_query_num_rows => 20
);

end;
/

--------------------------------------------------------------------------------
-- Page 2: EBS Agentic Apps
--------------------------------------------------------------------------------
prompt --application/pages/page_00002
begin
wwv_flow_api.create_page(
  p_id             => 2
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_user_interface_id => wwv_flow_api.id(0)
 ,p_name           => 'EBS Agentic Apps'
 ,p_alias          => 'EBS-APPS'
 ,p_step_title     => 'EBS Agentic Apps'
 ,p_autocomplete_on_off => 'OFF'
 ,p_page_template_options => 'DEFAULT'
 ,p_page_is_public_y_n => 'N'
 ,p_last_updated_by => 'W1_ADMIN'
 ,p_last_upd_yyyymmddhh24miss => '20260514140000'
);

-- Region: App Catalog Cards
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(2001)
 ,p_plug_name      => 'Agentic App Catalog'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 10
 ,p_plug_source_type => 'NATIVE_SQL_REPORT'
 ,p_plug_source    => q'[SELECT app_id,
       app_name,
       pillar,
       icon_class,
       tagline,
       kpis_json,
       CASE pillar
         WHEN 'FINANCE' THEN 'u-color-1'
         WHEN 'PROCUREMENT' THEN 'u-color-5'
         WHEN 'SUPPLY_CHAIN' THEN 'u-color-9'
         WHEN 'HCM' THEN 'u-color-13'
         ELSE 'u-color-3'
       END pillar_css
FROM u2x_fusion_apps
WHERE is_active = 'Y'
ORDER BY pillar, app_name]'
 ,p_plug_query_num_rows => 50
);

end;
/

--------------------------------------------------------------------------------
-- Page 3: Payables Workspace
--------------------------------------------------------------------------------
prompt --application/pages/page_00003
begin
wwv_flow_api.create_page(
  p_id             => 3
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_user_interface_id => wwv_flow_api.id(0)
 ,p_name           => 'Payables'
 ,p_alias          => 'PAYABLES'
 ,p_step_title     => 'Payables Workspace'
 ,p_autocomplete_on_off => 'OFF'
 ,p_page_template_options => 'DEFAULT'
 ,p_page_is_public_y_n => 'N'
 ,p_last_updated_by => 'W1_ADMIN'
 ,p_last_upd_yyyymmddhh24miss => '20260514140000'
);

-- Region: AP Period Close Findings
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(3001)
 ,p_plug_name      => 'AP Period Close Findings'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 10
 ,p_plug_source_type => 'NATIVE_IR'
 ,p_plug_source    => q'[SELECT finding_id,
       section,
       finding,
       detail,
       severity,
       finding_count,
       TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created
FROM u2x_findings
WHERE session_id = 'DEMO'
  AND analyzer_id = 'ap_period_close'
ORDER BY DECODE(severity,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4,'INFO',5), finding_id]'
 ,p_plug_query_num_rows => 50
);

-- Region: All AP Findings
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(3002)
 ,p_plug_name      => 'All Payables Findings'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 20
 ,p_plug_source_type => 'NATIVE_IR'
 ,p_plug_source    => q'[SELECT finding_id,
       analyzer_id,
       section,
       finding,
       severity,
       finding_count,
       TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created
FROM u2x_findings
WHERE session_id = 'DEMO'
  AND analyzer_id IN ('ap_period_close','workflow')
ORDER BY created_at DESC]'
 ,p_plug_query_num_rows => 100
);

end;
/

--------------------------------------------------------------------------------
-- Page 4: AP Agents
--------------------------------------------------------------------------------
prompt --application/pages/page_00004
begin
wwv_flow_api.create_page(
  p_id             => 4
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_user_interface_id => wwv_flow_api.id(0)
 ,p_name           => 'AP Agents'
 ,p_alias          => 'AP-AGENTS'
 ,p_step_title     => 'AP Agents'
 ,p_autocomplete_on_off => 'OFF'
 ,p_page_template_options => 'DEFAULT'
 ,p_page_is_public_y_n => 'N'
 ,p_last_updated_by => 'W1_ADMIN'
 ,p_last_upd_yyyymmddhh24miss => '20260514140000'
);

-- Region: Agent Tiles
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(4001)
 ,p_plug_name      => 'Agent Status'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 10
 ,p_plug_source_type => 'NATIVE_SQL_REPORT'
 ,p_plug_source    => q'[SELECT agent_id,
       agent_label,
       last_phase,
       NVL(last_severity, 'INFO') severity,
       NVL(last_duration_ms, 0) duration_ms,
       total_runs,
       total_errors,
       in_flight,
       TO_CHAR(last_ts, 'YYYY-MM-DD HH24:MI:SS') last_run,
       CASE last_phase
         WHEN 'complete' THEN 'u-success'
         WHEN 'error'    THEN 'u-danger'
         WHEN 'start'    THEN 'u-warning'
         ELSE 'u-info'
       END phase_css,
       CASE
         WHEN total_errors > 0 THEN 'fa-exclamation-triangle u-danger-text'
         WHEN total_runs > 0 THEN 'fa-check-circle u-success-text'
         ELSE 'fa-clock-o u-info-text'
       END status_icon
FROM u2x_agent_state
ORDER BY agent_id]'
 ,p_plug_query_num_rows => 20
);

-- Region: Run Agent (AJAX callback)
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(4002)
 ,p_plug_name      => 'Agent Actions'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 5
 ,p_plug_source_type => 'NATIVE_STATIC'
 ,p_plug_source    => q'[<p>Click <b>Run All Agents</b> to execute all 10 AP agents in demo mode, or run individual agents from the grid below.</p>]'
);

end;
/

--------------------------------------------------------------------------------
-- Page 5: Observability
--------------------------------------------------------------------------------
prompt --application/pages/page_00005
begin
wwv_flow_api.create_page(
  p_id             => 5
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_user_interface_id => wwv_flow_api.id(0)
 ,p_name           => 'Observability'
 ,p_alias          => 'OBSERVABILITY'
 ,p_step_title     => 'Observability'
 ,p_autocomplete_on_off => 'OFF'
 ,p_page_template_options => 'DEFAULT'
 ,p_page_is_public_y_n => 'N'
 ,p_last_updated_by => 'W1_ADMIN'
 ,p_last_upd_yyyymmddhh24miss => '20260514140000'
);

-- Region: Stats Summary
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(5001)
 ,p_plug_name      => 'Observability Stats'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 10
 ,p_plug_source_type => 'NATIVE_SQL_REPORT'
 ,p_plug_source    => q'[SELECT
  (SELECT COUNT(*) FROM u2x_obs_events) total_events,
  (SELECT COUNT(*) FROM u2x_agent_state) agents_registered,
  (SELECT NVL(SUM(total_runs),0) FROM u2x_agent_state) total_runs,
  (SELECT NVL(SUM(total_errors),0) FROM u2x_agent_state) total_errors,
  (SELECT NVL(SUM(in_flight),0) FROM u2x_agent_state) in_flight,
  (SELECT NVL(ROUND(AVG(CASE WHEN phase='complete' THEN duration_ms END)),0) FROM u2x_obs_events) avg_duration_ms
FROM dual]'
 ,p_plug_query_num_rows => 1
);

-- Region: Agent State Grid
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(5002)
 ,p_plug_name      => 'Agent State'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 20
 ,p_plug_source_type => 'NATIVE_SQL_REPORT'
 ,p_plug_source    => q'[SELECT agent_id, agent_label, last_phase, last_severity,
       last_duration_ms, total_runs, total_errors, in_flight,
       TO_CHAR(last_ts, 'YYYY-MM-DD HH24:MI:SS') last_run
FROM u2x_agent_state
ORDER BY agent_id]'
 ,p_plug_query_num_rows => 20
);

-- Region: Live Event Log (Interactive Report)
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(5003)
 ,p_plug_name      => 'Event Log'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 30
 ,p_plug_source_type => 'NATIVE_IR'
 ,p_plug_source    => q'[SELECT event_id,
       run_id,
       agent_id,
       agent_label,
       phase,
       source,
       message,
       severity,
       rows_count,
       duration_ms,
       TO_CHAR(event_ts, 'YYYY-MM-DD HH24:MI:SS.FF3') event_time
FROM u2x_obs_events
ORDER BY event_ts DESC]'
 ,p_plug_query_num_rows => 200
);

end;
/

--------------------------------------------------------------------------------
-- Page 6: Process Mining
--------------------------------------------------------------------------------
prompt --application/pages/page_00006
begin
wwv_flow_api.create_page(
  p_id             => 6
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_user_interface_id => wwv_flow_api.id(0)
 ,p_name           => 'Process Mining'
 ,p_alias          => 'PROCESS-MINING'
 ,p_step_title     => 'Process Mining'
 ,p_autocomplete_on_off => 'OFF'
 ,p_page_template_options => 'DEFAULT'
 ,p_page_is_public_y_n => 'N'
 ,p_last_updated_by => 'W1_ADMIN'
 ,p_last_upd_yyyymmddhh24miss => '20260514140000'
);

-- Region: Process Mining Overview
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(6001)
 ,p_plug_name      => 'Process Mining'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 10
 ,p_plug_source_type => 'NATIVE_STATIC'
 ,p_plug_source    => q'[<div class="t-Alert t-Alert--info">
<div class="t-Alert-icon"><span class="fa fa-diagram-project"></span></div>
<div class="t-Alert-body">
<h2 class="t-Alert-title">AP Invoice Process Mining</h2>
<p>Analyze the invoice lifecycle from receipt through payment. Identify bottlenecks, process variants, and optimization opportunities.</p>
<ul>
<li><strong>Happy Path Rate:</strong> 67% of invoices follow the standard flow</li>
<li><strong>Process Variants:</strong> 12 unique process paths identified</li>
<li><strong>Avg Cycle Time:</strong> 8.3 days (target: 5 days)</li>
<li><strong>Top Bottleneck:</strong> PO Matching (avg 2.1 days wait)</li>
</ul>
</div>
</div>]'
);

-- Region: Process Steps
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(6002)
 ,p_plug_name      => 'Process Flow Summary'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 20
 ,p_plug_source_type => 'NATIVE_SQL_REPORT'
 ,p_plug_source    => q'[SELECT step_no, step_name, avg_days, pct_on_time, volume FROM (
SELECT 1 step_no, 'Invoice Receipt' step_name, 0.5 avg_days, 95 pct_on_time, 1250 volume FROM dual UNION ALL
SELECT 2, 'Validation', 0.8, 88, 1250 FROM dual UNION ALL
SELECT 3, 'PO Matching', 2.1, 62, 980 FROM dual UNION ALL
SELECT 4, 'Approval', 1.5, 75, 950 FROM dual UNION ALL
SELECT 5, 'Accounting', 0.3, 98, 940 FROM dual UNION ALL
SELECT 6, 'Payment Scheduling', 1.2, 82, 930 FROM dual UNION ALL
SELECT 7, 'Payment Execution', 1.9, 70, 920 FROM dual
) ORDER BY step_no]'
 ,p_plug_query_num_rows => 20
);

end;
/

--------------------------------------------------------------------------------
-- Page 7: Analyzers / Findings
--------------------------------------------------------------------------------
prompt --application/pages/page_00007
begin
wwv_flow_api.create_page(
  p_id             => 7
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_user_interface_id => wwv_flow_api.id(0)
 ,p_name           => 'Analyzers'
 ,p_alias          => 'ANALYZERS'
 ,p_step_title     => 'Analyzers'
 ,p_autocomplete_on_off => 'OFF'
 ,p_page_template_options => 'DEFAULT'
 ,p_page_is_public_y_n => 'N'
 ,p_last_updated_by => 'W1_ADMIN'
 ,p_last_upd_yyyymmddhh24miss => '20260514140000'
);

-- Region: Analyzer Summary
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(7001)
 ,p_plug_name      => 'Analyzer Summary'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 10
 ,p_plug_source_type => 'NATIVE_SQL_REPORT'
 ,p_plug_source    => q'[SELECT analyzer_id,
       INITCAP(REPLACE(analyzer_id, '_', ' ')) analyzer_name,
       COUNT(*) finding_count,
       SUM(CASE WHEN severity = 'CRITICAL' THEN 1 ELSE 0 END) critical_count,
       SUM(CASE WHEN severity = 'HIGH' THEN 1 ELSE 0 END) high_count,
       SUM(CASE WHEN severity = 'MEDIUM' THEN 1 ELSE 0 END) medium_count
FROM u2x_findings
WHERE session_id = 'DEMO'
GROUP BY analyzer_id
ORDER BY critical_count DESC, high_count DESC]'
 ,p_plug_query_num_rows => 20
);

-- Region: All Findings (Interactive Report)
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(7002)
 ,p_plug_name      => 'All Findings'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 20
 ,p_plug_source_type => 'NATIVE_IR'
 ,p_plug_source    => q'[SELECT finding_id,
       analyzer_id,
       INITCAP(REPLACE(analyzer_id, '_', ' ')) analyzer_name,
       section,
       finding,
       detail,
       severity,
       finding_count,
       TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI') created
FROM u2x_findings
WHERE session_id = 'DEMO'
ORDER BY DECODE(severity,'CRITICAL',1,'HIGH',2,'MEDIUM',3,'LOW',4,'INFO',5), created_at DESC]'
 ,p_plug_query_num_rows => 200
);

end;
/

--------------------------------------------------------------------------------
-- Page 8: Sessions
--------------------------------------------------------------------------------
prompt --application/pages/page_00008
begin
wwv_flow_api.create_page(
  p_id             => 8
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_user_interface_id => wwv_flow_api.id(0)
 ,p_name           => 'Sessions'
 ,p_alias          => 'SESSIONS'
 ,p_step_title     => 'Sessions'
 ,p_autocomplete_on_off => 'OFF'
 ,p_page_template_options => 'DEFAULT'
 ,p_page_is_public_y_n => 'N'
 ,p_last_updated_by => 'W1_ADMIN'
 ,p_last_upd_yyyymmddhh24miss => '20260514140000'
);

-- Region: Sessions List (Interactive Report)
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(8001)
 ,p_plug_name      => 'Analysis Sessions'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 10
 ,p_plug_source_type => 'NATIVE_IR'
 ,p_plug_source    => q'[SELECT s.session_id,
       TO_CHAR(s.created_at, 'YYYY-MM-DD HH24:MI:SS') created_at,
       s.status,
       (SELECT COUNT(*) FROM u2x_findings f WHERE f.session_id = s.session_id) finding_count,
       (SELECT COUNT(*) FROM u2x_audit_trail a WHERE a.session_id = s.session_id) audit_count
FROM u2x_sessions s
ORDER BY s.created_at DESC]'
 ,p_plug_query_num_rows => 50
);

end;
/

--------------------------------------------------------------------------------
-- Page 9999: Login
--------------------------------------------------------------------------------
prompt --application/pages/page_09999
begin
wwv_flow_api.create_page(
  p_id             => 9999
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_user_interface_id => wwv_flow_api.id(0)
 ,p_name           => 'Login Page'
 ,p_alias          => 'LOGIN'
 ,p_step_title     => 'U2xAI EBS Agentic Apps - Sign In'
 ,p_autocomplete_on_off => 'OFF'
 ,p_page_template_options => 'DEFAULT'
 ,p_page_is_public_y_n => 'Y'
 ,p_last_updated_by => 'W1_ADMIN'
 ,p_last_upd_yyyymmddhh24miss => '20260514140000'
);

-- Region: Login Form
wwv_flow_api.create_page_plug(
  p_id             => wwv_flow_api.id(9001)
 ,p_plug_name      => 'U2xAI EBS Agentic Apps'
 ,p_region_template_options => 'DEFAULT'
 ,p_plug_template  => wwv_flow_api.id(0)
 ,p_plug_display_sequence => 10
 ,p_plug_source_type => 'NATIVE_STATIC'
 ,p_plug_source    => '<p>Sign in with your credentials.</p>'
);

-- Item: Username
wwv_flow_api.create_page_item(
  p_id             => wwv_flow_api.id(9901)
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_flow_step_id   => 9999
 ,p_name           => 'P9999_USERNAME'
 ,p_item_sequence   => 10
 ,p_item_plug_id   => wwv_flow_api.id(9001)
 ,p_prompt          => 'Username'
 ,p_display_as      => 'NATIVE_TEXT_FIELD'
 ,p_cSize           => 40
 ,p_cMaxlength      => 100
 ,p_label_alignment => 'RIGHT'
 ,p_field_alignment => 'LEFT'
 ,p_item_template_options => 'DEFAULT'
 ,p_attribute_01   => 'N'
 ,p_attribute_02   => 'N'
 ,p_attribute_04   => 'TEXT'
);

-- Item: Password
wwv_flow_api.create_page_item(
  p_id             => wwv_flow_api.id(9902)
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_flow_step_id   => 9999
 ,p_name           => 'P9999_PASSWORD'
 ,p_item_sequence   => 20
 ,p_item_plug_id   => wwv_flow_api.id(9001)
 ,p_prompt          => 'Password'
 ,p_display_as      => 'NATIVE_PASSWORD'
 ,p_cSize           => 40
 ,p_cMaxlength      => 100
 ,p_label_alignment => 'RIGHT'
 ,p_field_alignment => 'LEFT'
 ,p_item_template_options => 'DEFAULT'
 ,p_attribute_01   => 'Y'
 ,p_attribute_02   => 'Y'
);

-- Process: Login
wwv_flow_api.create_page_process(
  p_id             => wwv_flow_api.id(9903)
 ,p_process_sequence => 10
 ,p_process_point  => 'AFTER_SUBMIT'
 ,p_process_type   => 'NATIVE_PLSQL'
 ,p_process_name   => 'Set Username Cookie'
 ,p_process_sql_clob => 'wwv_flow_custom_auth_std.login(P_UNAME=>:P9999_USERNAME,P_PASSWORD=>:P9999_PASSWORD,P_SESSION_ID=>v(''APP_SESSION''),P_FLOW_PAGE=>:APP_ID||'':1'');'
 ,p_process_error_message => 'Invalid login credentials.'
);

-- Button: Sign In
wwv_flow_api.create_page_button(
  p_id             => wwv_flow_api.id(9904)
 ,p_flow_id        => wwv_flow.g_flow_id
 ,p_flow_step_id   => 9999
 ,p_button_sequence => 30
 ,p_button_plug_id => wwv_flow_api.id(9001)
 ,p_button_name    => 'LOGIN'
 ,p_button_action  => 'SUBMIT'
 ,p_button_template_options => 'DEFAULT'
 ,p_button_is_hot  => 'Y'
 ,p_button_image_alt => 'Sign In'
 ,p_button_position => 'REGION_BODY'
);

end;
/

prompt --application/end_environment
begin
  wwv_flow_application_install.clear_all;
  commit;
end;
/

prompt
prompt =============================================
prompt Application export complete.
prompt =============================================
