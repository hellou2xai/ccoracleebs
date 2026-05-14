REM $Id: rlm_schedule_analyze.sql, 200.17 2026/01/28 16:23:01 cschmehl Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    rlm_schedule_analyze.sql                                               |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the rlm_schedule_analyzer_pkg.main procedure     |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Release Management (RLM) Schedule Analyzer
REM
REM MENU_START
REM
REM SQL: Run Release Management (RLM) Schedule Analyzer
REM FNDLOAD: Load Release Management (RLM) Schedule Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Release Management (RLM) Schedule Analyzer Help [Doc ID: 2794745.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs rlm_schedule_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Release Management (RLM) Schedule Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: RLM_TOP
REM PROG_NAME: RLMSCHED
REM DEF_REQ_GROUP: Reports
REM PROG_TEMPLATE: RLMSCHEDAZ.ldt
REM
REM PROD_SHORT_NAME: RLM
REM CP_FILE: 
REM APP_NAME: Release Management
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM rlm_schedule_analyzer.sql
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
PROMPT Submitting Release Management (RLM) Schedule Analyzer...

PROMPT ===========================================================================
PROMPT Schedule Reference Number This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_schedule_number CHAR   PROMPT 'Enter the Schedule Reference Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Interface Header ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_header_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Interface Header ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Customer Item Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_customer_item CHAR   PROMPT 'Enter the Customer Item Number: '
PROMPT
PROMPT ===========================================================================
PROMPT RLM Org ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Org ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check: Valid values are 'Y' or 'N'. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Diagnostic Apps Check: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [2000] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '2000' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_schedule_number              VARCHAR2(240)  := '~p_schedule_number';
   p_header_id                    NUMBER         := '~p_header_id';
   p_customer_item                VARCHAR2(240)  := '~p_customer_item';
   p_org_id                       NUMBER         := '~p_org_id';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_header_id = -1 THEN
   p_header_id := NULL;
END IF;
IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;

   rlm_schedule_analyzer_pkg.main(
     p_schedule_number              => p_schedule_number
    ,p_header_id                    => p_header_id
    ,p_customer_item                => p_customer_item
    ,p_org_id                       => p_org_id
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;