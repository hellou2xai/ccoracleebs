REM $Id: agis_analyze.sql, 200.34 2025/12/13 22:12:34 viakula Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    agis_analyze.sql                                                       |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the agis_analyzer_pkg.main procedure             |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: AGIS Analyzer
REM
REM MENU_START
REM
REM SQL: Run AGIS Analyzer
REM FNDLOAD: Load AGIS Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  AGIS Analyzer Help [Doc ID: 2208479.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs agis_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install AGIS Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Intercompany Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: FUN_TOP
REM PROG_NAME: FUNAGIS
REM DEF_REQ_GROUP: All Intercompany Reports
REM PROG_TEMPLATE: FUNAGISAZ.ldt
REM
REM PROD_SHORT_NAME: FUN
REM CP_FILE: 
REM APP_NAME: Financials Common Modules
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM agis_analyzer.sql
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
PROMPT Submitting AGIS Analyzer...

PROMPT ===========================================================================
PROMPT Please introduce your Ledger Id for Intercompany Initiator Organization. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_ledger_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Ledger Id: '
PROMPT
PROMPT ===========================================================================
PROMPT If you want to analyze a specific batch, please enter the Batch number. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_batch_number CHAR   PROMPT 'Enter the Batch_number(optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the application User ID for which you are trying to check Organization assignment details. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_user_id NUMBER  DEFAULT '-1' PROMPT 'Enter the User ID(optional): '
PROMPT
PROMPT
DECLARE
   p_ledger_id                    NUMBER         := '~p_ledger_id';
   p_batch_number                 VARCHAR2(240)  := '~p_batch_number';
   p_user_id                      NUMBER         := '~p_user_id';

BEGIN

IF p_ledger_id = -1 THEN
   p_ledger_id := NULL;
END IF;
IF p_user_id = -1 THEN
   p_user_id := NULL;
END IF;

   agis_analyzer_pkg.main(
     p_ledger_id                    => p_ledger_id
    ,p_batch_number                 => p_batch_number
    ,p_user_id                      => p_user_id
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;