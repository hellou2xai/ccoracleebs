REM $Id: pay_analyze.sql, 200.239 2026/02/27 13:42:19 siionesc Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    pay_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the pay_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Payroll Analyzer
REM
REM MENU_START
REM
REM SQL: Run Payroll Analyzer
REM FNDLOAD: Load Payroll Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Payroll Analyzer Help [Doc ID: 1631780]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs pay_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Payroll Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Global SLA/Payroll Processes"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PAY_TOP
REM PROG_NAME: PAY_ANALYZER_SQL
REM DEF_REQ_GROUP: Global SLA/Payroll Processes
REM PROG_TEMPLATE: PAYAZ.ldt
REM PROG_TEMPLATE_11i: PAYAZ_11i.ldt
REM PROD_SHORT_NAME: PAY
REM CP_FILE: 
REM APP_NAME: Payroll
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM pay_analyzer.sql
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
PROMPT Submitting Payroll Analyzer...

PROMPT
DECLARE

BEGIN


   pay_analyzer_pkg.main(
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;