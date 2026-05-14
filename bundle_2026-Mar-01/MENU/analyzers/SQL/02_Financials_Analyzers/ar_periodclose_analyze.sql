REM $Id: ar_periodclose_analyze.sql, 200.63 2025/12/08 13:46:10 kgnanase Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ar_periodclose_analyze.sql                                             |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ar_perclos_analyzer_pkg.main procedure       |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Receivables Period Close Analyzer
REM
REM MENU_START
REM
REM SQL: Run Receivables Period Close Analyzer
REM FNDLOAD: Load Receivables Period Close Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Receivables Period Close Analyzer Help [Doc ID: 2019636.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ar_periodclose_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Receivables Period Close Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: ARPERANL
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: AR_PERIOD_CLOSEAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ar_periodclose_analyzer.sql
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
PROMPT Submitting Receivables Period Close Analyzer...

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
PROMPT Enter the Organization ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Period Name. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_period_name CHAR   PROMPT 'Enter the Period Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Scan for Events Not Processed, enter Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_not_proc CHAR   PROMPT 'Enter the Scan for Events Not Processed: '
PROMPT
PROMPT ===========================================================================
PROMPT Scan for Unposted Items, enter Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_unpost CHAR   PROMPT 'Enter the Scan for Unposted Items: '
PROMPT
PROMPT ===========================================================================
PROMPT Scan for Adjustment Integrity, enter Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_adj CHAR  DEFAULT 'N' PROMPT 'Enter the Scan for Adjustment Integrity: '
PROMPT
PROMPT ===========================================================================
PROMPT Scan for Transaction Integrity, enter Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_trx CHAR  DEFAULT 'N' PROMPT 'Enter the Scan for Transaction Integrity: '
PROMPT
PROMPT ===========================================================================
PROMPT Scan for Receipt Integrity, enter Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_rct CHAR  DEFAULT 'N' PROMPT 'Enter the Scan for Receipt Integrity: '
PROMPT
PROMPT ===========================================================================
PROMPT Scan for XLA to GL Integrity, enter Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_xla_gl CHAR  DEFAULT 'N' PROMPT 'Enter the Scan for XLA to GL Integrity: '
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
   p_org_id                       NUMBER         := '~p_org_id';
   p_period_name                  VARCHAR2(240)  := '~p_period_name';
   p_not_proc                     VARCHAR2(240)  := '~p_not_proc';
   p_unpost                       VARCHAR2(240)  := '~p_unpost';
   p_adj                          VARCHAR2(240)  := '~p_adj';
   p_trx                          VARCHAR2(240)  := '~p_trx';
   p_rct                          VARCHAR2(240)  := '~p_rct';
   p_xla_gl                       VARCHAR2(240)  := '~p_xla_gl';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN

IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;
IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.USER_NAME;
END IF;

IF p_resp_id IS NULL THEN
   p_resp_id := FND_GLOBAL.RESP_NAME;
END IF;


   ar_perclos_analyzer_pkg.main(
     p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_org_id                       => p_org_id
    ,p_period_name                  => p_period_name
    ,p_not_proc                     => upper(p_not_proc)
    ,p_unpost                       => upper(p_unpost)
    ,p_adj                          => upper(p_adj)
    ,p_trx                          => upper(p_trx)
    ,p_rct                          => upper(p_rct)
    ,p_xla_gl                       => upper(p_xla_gl)
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;