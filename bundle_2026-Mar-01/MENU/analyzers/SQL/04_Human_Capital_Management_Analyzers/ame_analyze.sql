REM $Id: ame_analyze.sql, 200.38 2026/01/29 07:58:43 siionesc Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ame_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ame_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Approvals Management Analyzer
REM
REM MENU_START
REM
REM SQL: Run Approvals Management Analyzer
REM FNDLOAD: Load Approvals Management Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Approvals Management Analyzer Help [Doc ID: 2332426.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ame_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Approvals Management Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Global HRMS Reports & Process"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PER_TOP
REM PROG_NAME: AME_ANALYZER
REM DEF_REQ_GROUP: Global HRMS Reports & Process
REM PROG_TEMPLATE: AMEAZ.ldt
REM PROG_TEMPLATE_11i: AMEAZ_11i.ldt
REM PROD_SHORT_NAME: PER
REM CP_FILE: 
REM APP_NAME: Human Resources
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ame_analyzer.sql
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
PROMPT Submitting Approvals Management Analyzer...

PROMPT ===========================================================================
PROMPT Application ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_AMEAPPID NUMBER  DEFAULT '-1' PROMPT 'Enter the Application ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Optional Transaction ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_trxn_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Optional Transaction ID: '
PROMPT
PROMPT
DECLARE
   p_AMEAPPID                     NUMBER         := '~p_AMEAPPID';
   p_trxn_id                      NUMBER         := '~p_trxn_id';

BEGIN

IF p_trxn_id = -1 THEN
   p_trxn_id := NULL;
END IF;

   ame_analyzer_pkg.main(
     p_AMEAPPID                     => p_AMEAPPID
    ,p_trxn_id                      => p_trxn_id
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;