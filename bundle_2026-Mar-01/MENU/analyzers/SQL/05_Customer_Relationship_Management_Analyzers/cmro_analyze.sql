REM $Id: cmro_analyze.sql, 200.19 2026/01/28 17:38:17 svedula Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    cmro_analyze.sql                                                       |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the cmro_analyzer_pkg.main procedure             |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Complex Maintenance Repair and Overhaul Analyzer
REM
REM MENU_START
REM
REM SQL: Run Complex Maintenance Repair and Overhaul Analyzer
REM FNDLOAD: Load Complex Maintenance Repair and Overhaul Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Complex Maintenance Repair and Overhaul Analyzer Help [Doc ID: 2201872.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs cmro_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Complex Maintenance Repair and Overhaul Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AHL_TOP
REM PROG_NAME: CMRO_ANALYZER_SQL
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: CMROAZ.ldt
REM
REM PROD_SHORT_NAME: AHL
REM CP_FILE: 
REM APP_NAME: Complex Maintenance Repair and Overhaul
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM cmro_analyzer.sql
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
PROMPT Submitting Complex Maintenance Repair and Overhaul Analyzer...

PROMPT ===========================================================================
PROMPT Enter a valid Visit Id [Optional]. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_visit_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Visit Id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter a valid Workorder Id [Optional]. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_workorder_id CHAR   PROMPT 'Enter the Workorder Id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter a valid MR Header Id [Optional]. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_mr_header_id CHAR   PROMPT 'Enter the MR Header Id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_visit_id                     NUMBER         := '~p_visit_id';
   p_workorder_id                 VARCHAR2(240)  := '~p_workorder_id';
   p_mr_header_id                 VARCHAR2(240)  := '~p_mr_header_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_visit_id = -1 THEN
   p_visit_id := NULL;
END IF;

   cmro_analyzer_pkg.main(
     p_visit_id                     => p_visit_id
    ,p_workorder_id                 => p_workorder_id
    ,p_mr_header_id                 => p_mr_header_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;