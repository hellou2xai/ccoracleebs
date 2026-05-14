REM $Id: pa_workplan_analyze.sql, 200.19 2026/02/25 21:44:43 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    pa_workplan_analyze.sql                                                |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the pa_workplan_analyzer_pkg.main procedure      |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.1 12.2
REM
REM MENU_TITLE: Project Planning and Control Analyzer
REM
REM MENU_START
REM
REM SQL: Run Project Planning and Control Analyzer
REM FNDLOAD: Load Project Planning and Control Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Project Planning and Control Analyzer Help [Doc ID: 2860729.1]
REM
REM  Compatible with: [12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs pa_workplan_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Project Planning and Control Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Projects Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PA_TOP
REM PROG_NAME: PAWOKPLANAZ
REM DEF_REQ_GROUP: All Projects Programs
REM PROG_TEMPLATE: PAWORKPLANAZ.ldt
REM
REM PROD_SHORT_NAME: PA
REM CP_FILE: 
REM APP_NAME: Projects
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM pa_workplan_analyzer.sql
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
PROMPT Submitting Project Planning and Control Analyzer...

PROMPT ===========================================================================
PROMPT Please enter the Project ID for which data needs to be collected 
PROMPT ===========================================================================
PROMPT
ACCEPT project_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Project ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [50] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '50' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   project_id                     NUMBER         := '~project_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF project_id = -1 THEN
   project_id := NULL;
END IF;

   pa_workplan_analyzer_pkg.main(
     project_id                     => project_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;