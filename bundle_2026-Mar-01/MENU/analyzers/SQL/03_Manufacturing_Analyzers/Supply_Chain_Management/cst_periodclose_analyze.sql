REM $Id: cst_periodclose_analyze.sql, 200.36 2026/01/27 14:50:06 sothman Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    cst_periodclose_analyze.sql                                            |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the cst_periodclose_analyzer_pkg.main procedure  |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Cost Management Period Close Analyzer
REM
REM MENU_START
REM
REM SQL: Run Cost Management Period Close Analyzer
REM FNDLOAD: Load Cost Management Period Close Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Cost Management Period Close Analyzer Help [Doc ID: 2315206.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs cst_periodclose_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Cost Management Period Close Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Cost Management"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: BOM_TOP
REM PROG_NAME: CSTPERIODCLOSE
REM DEF_REQ_GROUP: Cost Management
REM PROG_TEMPLATE: CSTPERIODCLOSEAZ.ldt
REM
REM PROD_SHORT_NAME: BOM
REM CP_FILE: 
REM APP_NAME: Bills of Material
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM cst_periodclose_analyzer.sql
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
PROMPT Submitting Cost Management Period Close Analyzer...

PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [30] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '300' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   cst_periodclose_analyzer_pkg.main(
     p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;