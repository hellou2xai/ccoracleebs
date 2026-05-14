REM $Id: lns_analyze.sql, 200.12 2025/12/08 13:36:01 jnieman Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    lns_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the lns_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Loans Analyzer
REM
REM MENU_START
REM
REM SQL: Run Loans Analyzer
REM FNDLOAD: Load Loans Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Loans Analyzer Help [Doc ID: 2652176.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs lns_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Loans Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "LNS_ADMIN_REQUESTS"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: LNS_TOP
REM PROG_NAME: LNSANLZ
REM DEF_REQ_GROUP: LNS_ADMIN_REQUESTS
REM PROG_TEMPLATE: LNSANLZAZ.ldt
REM
REM PROD_SHORT_NAME: LNS
REM CP_FILE: 
REM APP_NAME: Loans
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM lns_analyzer.sql
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
PROMPT Submitting Loans Analyzer...

PROMPT ===========================================================================
PROMPT Enter the User Name used to log into the Loans application. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_user_name CHAR   PROMPT 'Enter the User Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Responsibility ID used in the Loans application. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_resp_id NUMBER   PROMPT 'Enter the Responsibility ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Loan ID used in Loans application. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_loan_id CHAR   PROMPT 'Enter the Loan ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Apps Check: Valid values are Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_apps_check CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Apps Check: '
PROMPT
PROMPT
DECLARE
   p_user_name                    VARCHAR2(240)  := '~p_user_name';
   p_resp_id                      NUMBER         := '~p_resp_id';
   p_loan_id                      VARCHAR2(240)  := '~p_loan_id';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN

IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.USER_NAME;
END IF;

IF p_resp_id IS NULL THEN
   p_resp_id := FND_GLOBAL.RESP_NAME;
END IF;


   lns_analyzer_pkg.main(
     p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_loan_id                      => p_loan_id
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;