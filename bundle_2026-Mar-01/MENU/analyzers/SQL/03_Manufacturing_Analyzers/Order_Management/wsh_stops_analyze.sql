REM $Id: wsh_stops_analyze.sql, 200.55 2026/01/28 16:53:30 cschmehl Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    wsh_stops_analyze.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the wsh_stops_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Shipping Execution Interface Trip Stop Analyzer
REM
REM MENU_START
REM
REM SQL: Run Shipping Execution Interface Trip Stop Analyzer
REM FNDLOAD: Load Shipping Execution Interface Trip Stop Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Shipping Execution Interface Trip Stop Analyzer Help [Doc ID: 2380643.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs wsh_stops_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Shipping Execution Interface Trip Stop Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "OM Concurrent Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: ONT_TOP
REM PROG_NAME: WSHSTOPS
REM DEF_REQ_GROUP: OM Concurrent Programs
REM PROG_TEMPLATE: WSHSTOPSAZ.ldt
REM
REM PROD_SHORT_NAME: ONT
REM CP_FILE: 
REM APP_NAME: Order Management
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM wsh_stops_analyzer.sql
REM
REM DEPENDENCIES_END
REM
REM CONDITION_START
REM 
REM CONDITION_END
REM
REM CONDITION_FAIL_START
REM 
REM CONDITION_FAIL_END
REM
REM OUTPUT_TYPE: UTL_FILE
REM
REM ANALYZER_BUNDLE_END


SET SERVEROUTPUT ON SIZE 1000000
SET ECHO OFF
SET VERIFY OFF
SET DEFINE "~"
SET ESCAPE ON
SET NUMWIDTH 16
PROMPT
PROMPT Submitting Shipping Execution Interface Trip Stop Analyzer...

PROMPT ===========================================================================
PROMPT Enter Pickup Stop ID of the Trip  This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_stp_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Pickup Stop ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Delivery ID. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_delivery_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Delivery ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Apps Check Information (Default=N) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Apps Check Information (Default=N): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_stp_id                       NUMBER         := '~p_stp_id';
   p_delivery_id                  NUMBER         := '~p_delivery_id';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_stp_id = -1 THEN
   p_stp_id := NULL;
END IF;
IF p_delivery_id = -1 THEN
   p_delivery_id := NULL;
END IF;

   wsh_stops_analyzer_pkg.main(
     p_stp_id                       => p_stp_id
    ,p_delivery_id                  => p_delivery_id
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;