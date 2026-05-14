REM $Id: pa_pjc_expend_analyze.sql, 200.37 2026/02/25 21:45:24 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    pa_pjc_expend_analyze.sql                                              |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the pa_pjc_expend_analyzer_pkg.main procedure    |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Projects Expenditure Processing Analyzer
REM
REM MENU_START
REM
REM SQL: Run Projects Expenditure Processing Analyzer
REM FNDLOAD: Load Projects Expenditure Processing Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Projects Expenditure Processing Analyzer Help [Doc ID: 2443481.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs pa_pjc_expend_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Projects Expenditure Processing Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Projects Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PA_TOP
REM PROG_NAME: PAEXPND
REM DEF_REQ_GROUP: All Projects Programs
REM PROG_TEMPLATE: PAEXPNDAZ.ldt
REM
REM PROD_SHORT_NAME: PA
REM CP_FILE: 
REM APP_NAME: Projects
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM pa_pjc_expend_analyzer.sql
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
PROMPT Submitting Projects Expenditure Processing Analyzer...

PROMPT ===========================================================================
PROMPT Provide Expenditure Item Id This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_expenditure_item_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Expenditure Item Id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [2000] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '2000' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_expenditure_item_id          NUMBER         := '~p_expenditure_item_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_expenditure_item_id = -1 THEN
   p_expenditure_item_id := NULL;
END IF;

   pa_pjc_expend_analyzer_pkg.main(
     p_expenditure_item_id          => p_expenditure_item_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;