REM $Id: qp_line_analyze.sql, 200.51 2026/01/27 20:26:07 cschmehl Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    qp_line_analyze.sql                                                    |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the qp_line_analyzer_pkg.main procedure          |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Advanced Pricing List Line Analyzer
REM
REM MENU_START
REM
REM SQL: Run Advanced Pricing List Line Analyzer
REM FNDLOAD: Load Advanced Pricing List Line Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Advanced Pricing List Line Analyzer Help [Doc ID: 2096583.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs qp_line_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Advanced Pricing List Line Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "QP Concurrent Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: QP_TOP
REM PROG_NAME: QPLINE
REM DEF_REQ_GROUP: QP Concurrent Programs
REM PROG_TEMPLATE: QPLINEAZ.ldt
REM
REM PROD_SHORT_NAME: QP
REM CP_FILE: 
REM APP_NAME: Advanced Pricing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM qp_line_analyzer.sql
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
PROMPT Submitting Advanced Pricing List Line Analyzer...

PROMPT ===========================================================================
PROMPT list_line_id can be found by position the cursor on list line in the pricelist / modifierlist form: menu Help > Diagnostics > Examine > Field List_Line_Id value This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_list_line_id NUMBER  DEFAULT '-1' PROMPT 'Enter the List Line ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_list_line_id                 NUMBER         := '~p_list_line_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_list_line_id = -1 THEN
   p_list_line_id := NULL;
END IF;

   qp_line_analyzer_pkg.main(
     p_list_line_id                 => p_list_line_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;