REM $Id: ar_net_analyze.sql, 200.13 2025/12/08 13:33:46 nchiaram Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ar_net_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ar_net_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: AP/AR Netting Analyzer
REM
REM MENU_START
REM
REM SQL: Run AP/AR Netting Analyzer
REM FNDLOAD: Load AP/AR Netting Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  AP/AR Netting Analyzer Help [Doc ID: 2652174.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ar_net_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install AP/AR Netting Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: ARNETANLZ
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: ARNETANLZAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ar_net_analyzer.sql
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
PROMPT Submitting AP/AR Netting Analyzer...

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
PROMPT Enter Agreement ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_agreement_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Agreement ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Netting Batch ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_net_batch_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Netting Batch ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter AR Customer Trx ID (CUSTOMER_TRX_ID). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_customer_trx_id CHAR   PROMPT 'Enter the AR Customer Trx ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the AP Invoice ID (INVOICE_ID). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_invoice_id NUMBER  DEFAULT '-1' PROMPT 'Enter the AP Invoice ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the AP Check ID (CHECK_ID). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_check_id NUMBER  DEFAULT '-1' PROMPT 'Enter the AP Check ID: '
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
   p_agreement_id                 NUMBER         := '~p_agreement_id';
   p_net_batch_id                 NUMBER         := '~p_net_batch_id';
   p_customer_trx_id              VARCHAR2(240)  := '~p_customer_trx_id';
   p_invoice_id                   NUMBER         := '~p_invoice_id';
   p_check_id                     NUMBER         := '~p_check_id';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN

IF p_agreement_id = -1 THEN
   p_agreement_id := NULL;
END IF;
IF p_net_batch_id = -1 THEN
   p_net_batch_id := NULL;
END IF;
IF p_invoice_id = -1 THEN
   p_invoice_id := NULL;
END IF;
IF p_check_id = -1 THEN
   p_check_id := NULL;
END IF;
IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.USER_NAME;
END IF;

IF p_resp_id IS NULL THEN
   p_resp_id := FND_GLOBAL.RESP_NAME;
END IF;


   ar_net_analyzer_pkg.main(
     p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_agreement_id                 => p_agreement_id
    ,p_net_batch_id                 => p_net_batch_id
    ,p_customer_trx_id              => p_customer_trx_id
    ,p_invoice_id                   => p_invoice_id
    ,p_check_id                     => p_check_id
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;