REM $Id: pa_pjc_capital_analyze.sql, 200.16 2026/02/25 21:45:08 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    pa_pjc_capital_analyze.sql                                             |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the pa_pjc_capital_analyzer_pkg.main procedure   |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Projects Capital Analyzer
REM
REM MENU_START
REM
REM SQL: Run Projects Capital Analyzer
REM FNDLOAD: Load Projects Capital Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Projects Capital Analyzer Help [Doc ID: 2958343.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs pa_pjc_capital_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Projects Capital Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Projects Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PA_TOP
REM PROG_NAME: PAPJCCAP
REM DEF_REQ_GROUP: All Projects Programs
REM PROG_TEMPLATE: PAPJCCAPAZ.ldt
REM
REM PROD_SHORT_NAME: PA
REM CP_FILE: 
REM APP_NAME: Projects
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM pa_pjc_capital_analyzer.sql
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
PROMPT Submitting Projects Capital Analyzer...

PROMPT ===========================================================================
PROMPT To analyze a specific Project, enter the Project ID.  You can obtain the Project ID in SQL using the following query: SELECT project_id FROM pa_projects_all WHERE segment1 = '&project_number'; This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_project_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Project ID: '
PROMPT
PROMPT ===========================================================================
PROMPT If you want to analyze a specific asset for the project, enter the Asset Name. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_asset_name CHAR   PROMPT 'Enter the Asset Name: '
PROMPT
PROMPT ===========================================================================
PROMPT If you want to analyze a specific expenditure item ID for the project, enter the Expenditure Item ID. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_expenditure_item_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Expenditure Item ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [500] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '1000' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_project_id                   NUMBER         := '~p_project_id';
   p_asset_name                   VARCHAR2(240)  := '~p_asset_name';
   p_expenditure_item_id          NUMBER         := '~p_expenditure_item_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_project_id = -1 THEN
   p_project_id := NULL;
END IF;
IF p_expenditure_item_id = -1 THEN
   p_expenditure_item_id := NULL;
END IF;

   pa_pjc_capital_analyzer_pkg.main(
     p_project_id                   => p_project_id
    ,p_asset_name                   => p_asset_name
    ,p_expenditure_item_id          => p_expenditure_item_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;