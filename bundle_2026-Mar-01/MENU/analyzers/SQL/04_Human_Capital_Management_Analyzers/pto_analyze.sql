REM $Id: pto_analyze.sql, 200.16 2025/12/05 18:50:47 siionesc Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    pto_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the pto_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: PTO Accrual Plan Analyzer
REM
REM MENU_START
REM
REM SQL: Run PTO Accrual Plan Analyzer
REM FNDLOAD: Load PTO Accrual Plan Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  PTO Accrual Plan Analyzer Help [Doc ID: 2633288.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs pto_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install PTO Accrual Plan Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "HR Foundation"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PER_TOP
REM PROG_NAME: PTOAZ
REM DEF_REQ_GROUP: HR Foundation
REM PROG_TEMPLATE: PTOAZ.ldt
REM PROG_TEMPLATE_11i: PTOAZ_11i.ldt
REM PROD_SHORT_NAME: PER
REM CP_FILE: 
REM APP_NAME: Human Resources
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM pto_analyzer.sql
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
PROMPT Submitting PTO Accrual Plan Analyzer...

PROMPT ===========================================================================
PROMPT Accrual Plan ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_planid NUMBER  DEFAULT '-1' PROMPT 'Enter the Accrual Plan ID: '
PROMPT
PROMPT
DECLARE
   p_planid                       NUMBER         := '~p_planid';

BEGIN

IF p_planid = -1 THEN
   p_planid := NULL;
END IF;

   pto_analyzer_pkg.main(
     p_planid                       => p_planid
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;