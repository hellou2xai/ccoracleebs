REM $Id: ar_lockbox_analyze.sql, 200.66 2026/02/15 16:53:31 bcampesi Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ar_lockbox_analyze.sql                                                 |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ar_lockbox_analyzer_pkg.main procedure       |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Receivables Lockbox Analyzer
REM
REM MENU_START
REM
REM SQL: Run Receivables Lockbox Analyzer
REM FNDLOAD: Load Receivables Lockbox Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Receivables Lockbox Analyzer Help [Doc ID: 2323322.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ar_lockbox_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Receivables Lockbox Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: ARLOCKANL
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: AR_LOCKBOX_ANLZAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ar_lockbox_analyzer.sql
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
PROMPT Submitting Receivables Lockbox Analyzer...

PROMPT ===========================================================================
PROMPT Enter the User Name used to log into Receivables. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_user_name CHAR   PROMPT 'Enter the User Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Responsibility ID used in Receivables application. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_resp_id NUMBER   PROMPT 'Enter the Responsibility ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Transmission Name. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_trans_name CHAR   PROMPT 'Enter the Transmission Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Receipt Number from the interface table. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_rctnum CHAR   PROMPT 'Enter the Receipt Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Apps Check: Valid values are Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Apps Check: '
PROMPT
PROMPT
DECLARE
   p_user_name                    VARCHAR2(240)  := '~p_user_name';
   p_resp_id                      NUMBER         := '~p_resp_id';
   p_trans_name                   VARCHAR2(240)  := '~p_trans_name';
   p_rctnum                       VARCHAR2(240)  := '~p_rctnum';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN

IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.USER_NAME;
END IF;

IF p_resp_id IS NULL THEN
   p_resp_id := FND_GLOBAL.RESP_NAME;
END IF;


   ar_lockbox_analyzer_pkg.main(
     p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_trans_name                   => p_trans_name
    ,p_rctnum                       => p_rctnum
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;