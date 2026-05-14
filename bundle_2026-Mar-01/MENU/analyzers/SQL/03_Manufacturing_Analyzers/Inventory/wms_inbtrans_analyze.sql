REM $Id: wms_inbtrans_analyze.sql, 200.23 2026/02/23 18:23:00 skraya Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    wms_inbtrans_analyze.sql                                               |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the wms_inbtrans_analyzer_pkg.main procedure     |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Warehouse Management Analyzer
REM
REM MENU_START
REM
REM SQL: Run Warehouse Management Analyzer
REM FNDLOAD: Load Warehouse Management Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Warehouse Management Analyzer Help [Doc ID: 2226277.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs wms_inbtrans_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Warehouse Management Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All WMS Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: WMS_TOP
REM PROG_NAME: WMSIBT
REM DEF_REQ_GROUP: All WMS Reports
REM PROG_TEMPLATE: WMSIBTAZ.ldt
REM
REM PROD_SHORT_NAME: WMS
REM CP_FILE: 
REM APP_NAME: Warehouse Management
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM wms_inbtrans_analyzer.sql
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
PROMPT Submitting Warehouse Management Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Organization Code This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_code CHAR   PROMPT 'Enter the Organization Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter License Plate Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_lpn_num CHAR   PROMPT 'Enter the License Plate Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Y for 'Yes' Or N for 'No'  (Default is No) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Diagnostic Apps Check: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [50] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '100' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the debug mode [Y] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_debug_mode CHAR  DEFAULT 'Y' PROMPT 'Enter the Debug Mode: '
PROMPT
PROMPT
DECLARE
   p_org_code                     VARCHAR2(240)  := '~p_org_code';
   p_lpn_num                      VARCHAR2(240)  := '~p_lpn_num';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';
   p_debug_mode                   VARCHAR2(240)  := '~p_debug_mode';

BEGIN

IF p_lpn_num IS NULL THEN
   p_lpn_num := NULL;
END IF;


   wms_inbtrans_analyzer_pkg.main(
     p_org_code                     => p_org_code
    ,p_lpn_num                      => p_lpn_num
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
    ,p_debug_mode                   => p_debug_mode
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;