REM $Id: ar_trx_feat_analyze.sql, 200.26 2026/01/29 15:30:07 mamoreir Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ar_trx_feat_analyze.sql                                                |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ar_trx_feat_analyzer_pkg.main procedure      |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Receivables Transaction Features Setup Analyzer
REM
REM MENU_START
REM
REM SQL: Run Receivables Transaction Features Setup Analyzer
REM FNDLOAD: Load Receivables Transaction Features Setup Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Receivables Transaction Features Setup Analyzer Help [Doc ID: 2652087.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ar_trx_feat_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Receivables Transaction Features Setup Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: ARTXFANLZ
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: ARTXFANLZAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ar_trx_feat_analyzer.sql
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
PROMPT Submitting Receivables Transaction Features Setup Analyzer...

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
PROMPT Enter Transaction Feature, valid values are: EDI, BFB, LATE CHARGES. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_feature CHAR   PROMPT 'Enter the Transaction Feature: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Customer Account ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_cust_account_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Customer Account ID: '
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
   p_feature                      VARCHAR2(240)  := '~p_feature';
   p_cust_account_id              NUMBER         := '~p_cust_account_id';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN

IF p_cust_account_id = -1 THEN
   p_cust_account_id := NULL;
END IF;
IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.USER_NAME;
END IF;

IF p_resp_id IS NULL THEN
   p_resp_id := FND_GLOBAL.RESP_NAME;
END IF;


   ar_trx_feat_analyzer_pkg.main(
     p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_org_id                       => p_org_id
    ,p_feature                      => upper(p_feature)
    ,p_cust_account_id              => p_cust_account_id
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;