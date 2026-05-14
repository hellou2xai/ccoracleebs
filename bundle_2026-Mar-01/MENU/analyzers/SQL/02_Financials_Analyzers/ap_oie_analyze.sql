REM $Id: ap_oie_analyze.sql, 200.47 2026/02/25 11:25:07 sdenye Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ap_oie_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ap_oie_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Internet Expenses Analyzer
REM
REM MENU_START
REM
REM SQL: Run Internet Expenses Analyzer
REM FNDLOAD: Load Internet Expenses Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Internet Expenses Analyzer Help [Doc ID: 1559272.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ap_oie_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Internet Expenses Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Payables Reports Only"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AP_TOP
REM PROG_NAME: APOIEAZ
REM DEF_REQ_GROUP: Payables Reports Only
REM PROG_TEMPLATE: APOIEAZ.ldt
REM
REM PROD_SHORT_NAME: SQLAP
REM CP_FILE: 
REM APP_NAME: Payables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ap_oie_analyzer.sql
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
PROMPT Submitting Internet Expenses Analyzer...

PROMPT ===========================================================================
PROMPT Org_id(s) for the operating unit(s). For multiple operating units, separate with commas. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_ids CHAR   PROMPT 'Enter the OU org_id(s): '
PROMPT
PROMPT ===========================================================================
PROMPT Person ID for the employee 
PROMPT ===========================================================================
PROMPT
ACCEPT p_per NUMBER  DEFAULT '-1' PROMPT 'Enter the Person_id: '
PROMPT
PROMPT ===========================================================================
PROMPT Responsibility Name 
PROMPT ===========================================================================
PROMPT
ACCEPT p_resp CHAR   PROMPT 'Enter the responsibility name: '
PROMPT
PROMPT ===========================================================================
PROMPT To analyze a certain Expense Report 
PROMPT ===========================================================================
PROMPT
ACCEPT p_expense_report_num CHAR   PROMPT 'Enter the Expense Report Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the debug mode [N] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_debug_mode CHAR  DEFAULT 'Y' PROMPT 'Enter the Debug Mode: '
PROMPT
PROMPT
DECLARE
   p_org_ids                      VARCHAR2(240)  := '~p_org_ids';
   p_per                          NUMBER         := '~p_per';
   p_resp                         VARCHAR2(240)  := '~p_resp';
   p_expense_report_num           VARCHAR2(240)  := '~p_expense_report_num';
   p_debug_mode                   VARCHAR2(240)  := '~p_debug_mode';

BEGIN

IF p_per = -1 THEN
   p_per := NULL;
END IF;

   ap_oie_analyzer_pkg.main(
     p_org_ids                      => p_org_ids
    ,p_per                          => p_per
    ,p_resp                         => p_resp
    ,p_expense_report_num           => p_expense_report_num
    ,p_debug_mode                   => p_debug_mode
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;