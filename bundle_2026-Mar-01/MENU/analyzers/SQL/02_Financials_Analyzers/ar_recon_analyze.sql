REM $Id: ar_recon_analyze.sql, 200.26 2025/12/08 13:47:00 kgnanase Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ar_recon_analyze.sql                                                   |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ar_recon_analyzer_pkg.main procedure         |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Receivables Reconciliation Analyzer
REM
REM MENU_START
REM
REM SQL: Run Receivables Reconciliation Analyzer
REM FNDLOAD: Load Receivables Reconciliation Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Receivables Reconciliation Analyzer Help [Doc ID: 2255895.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ar_recon_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Receivables Reconciliation Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: ARRECANL
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: AR_RECON_ANALYZERAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ar_recon_analyzer.sql
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
PROMPT Submitting Receivables Reconciliation Analyzer...

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
ACCEPT p_org_id CHAR   PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the start gl_date for the period you are trying to reconcile. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_gl_start_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the Start GL_Date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the end gl_date for the period you are trying to reconcile. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_gl_end_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the End GL_Date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Scan for Potential Reconciling Items, enter Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_pot_recon_items CHAR  DEFAULT 'Y' PROMPT 'Enter the Scan for Potential Reconciling Items: '
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
   p_org_id                       VARCHAR2(240)  := '~p_org_id';
   p_gl_start_date                DATE           := to_date('~p_gl_start_date','DD-MON-YYYY');
   p_gl_end_date                  DATE           := to_date('~p_gl_end_date','DD-MON-YYYY');
   p_pot_recon_items              VARCHAR2(240)  := '~p_pot_recon_items';
   p_xla_gl                       VARCHAR2(240)  := '~p_xla_gl';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN

IF p_gl_start_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_gl_start_date := NULL;
END IF;
IF p_gl_end_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_gl_end_date := NULL;
END IF;
IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.USER_NAME;
END IF;

IF p_resp_id IS NULL THEN
   p_resp_id := FND_GLOBAL.RESP_NAME;
END IF;


   ar_recon_analyzer_pkg.main(
     p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_org_id                       => p_org_id
    ,p_gl_start_date                => p_gl_start_date
    ,p_gl_end_date                  => p_gl_end_date
    ,p_pot_recon_items              => p_pot_recon_items
    ,p_xla_gl                       => upper(p_xla_gl)
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;