REM $Id: sla_setup_analyze.sql, 200.4 2025/12/08 13:48:00 kgnanase Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    sla_setup_analyze.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the sla_setup_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Subledger Accounting Setup Analyzer
REM
REM MENU_START
REM
REM SQL: Run Subledger Accounting Setup Analyzer
REM FNDLOAD: Load Subledger Accounting Setup Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Subledger Accounting Setup Analyzer Help [Doc ID: 2889525.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs sla_setup_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Subledger Accounting Setup Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: SLASTPANLZ
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: SLASTPANLZAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM sla_setup_analyzer.sql
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
PROMPT Submitting Subledger Accounting Setup Analyzer...

PROMPT ===========================================================================
PROMPT Enter Ledger ID (LEDGER_ID). This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_ledger_id NUMBER  DEFAULT '-1' PROMPT 'Enter the ledger ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Application ID  This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_application_id NUMBER  DEFAULT '-1' PROMPT 'Enter the APPLICATION_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Subledger Accounting Method Code This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_slam CHAR   PROMPT 'Enter the Subledger Accounting Method Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Application Accounting Definition Code This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_aad CHAR   PROMPT 'Enter the Application Accounting Definition Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Context Code (AMB Context Code) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_context CHAR   PROMPT 'Enter the Context Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Event Class Code 
PROMPT ===========================================================================
PROMPT
ACCEPT p_event_class CHAR   PROMPT 'Enter the Event Class Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Journal Line Definition Code 
PROMPT ===========================================================================
PROMPT
ACCEPT p_jld CHAR   PROMPT 'Enter the Journal Line Definition Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Journal Line Type Code 
PROMPT ===========================================================================
PROMPT
ACCEPT p_jlt CHAR   PROMPT 'Enter the Journal Line Type Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [500] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '500' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_ledger_id                    NUMBER         := '~p_ledger_id';
   p_application_id               NUMBER         := '~p_application_id';
   p_slam                         VARCHAR2(240)  := '~p_slam';
   p_aad                          VARCHAR2(240)  := '~p_aad';
   p_context                      VARCHAR2(240)  := '~p_context';
   p_event_class                  VARCHAR2(240)  := '~p_event_class';
   p_jld                          VARCHAR2(240)  := '~p_jld';
   p_jlt                          VARCHAR2(240)  := '~p_jlt';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_ledger_id = -1 THEN
   p_ledger_id := NULL;
END IF;
IF p_application_id = -1 THEN
   p_application_id := NULL;
END IF;

   sla_setup_analyzer_pkg.main(
     p_ledger_id                    => p_ledger_id
    ,p_application_id               => p_application_id
    ,p_slam                         => p_slam
    ,p_aad                          => p_aad
    ,p_context                      => p_context
    ,p_event_class                  => p_event_class
    ,p_jld                          => p_jld
    ,p_jlt                          => p_jlt
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;