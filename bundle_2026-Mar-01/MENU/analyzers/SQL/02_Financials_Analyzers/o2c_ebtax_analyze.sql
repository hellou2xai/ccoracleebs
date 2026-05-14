REM $Id: o2c_ebtax_analyze.sql, 200.12 2025/12/08 13:36:19 jdhincks Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    o2c_ebtax_analyze.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the o2c_ebtax_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Order to Cash E-Business Tax Analyzer
REM
REM MENU_START
REM
REM SQL: Run Order to Cash E-Business Tax Analyzer
REM FNDLOAD: Load Order to Cash E-Business Tax Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Order to Cash E-Business Tax Analyzer Help [Doc ID: 2543707.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs o2c_ebtax_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Order to Cash E-Business Tax Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: O2C_EBTAX
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: O2C_EBTAXAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM o2c_ebtax_analyzer.sql
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
PROMPT Submitting Order to Cash E-Business Tax Analyzer...

PROMPT ===========================================================================
PROMPT Enter the user name used to log into the application. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_user_name CHAR   PROMPT 'Enter the User Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Responsibility ID used in the application. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_resp_id NUMBER   PROMPT 'Enter the Responsibility ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Tax Regime (TAX_REGIME_CODE). This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_tax_regime CHAR   PROMPT 'Enter the Tax Regime: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Content Owner ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_co_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Content Owner Id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the tax. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_tax1 CHAR   PROMPT 'Enter the Tax: '
PROMPT
PROMPT ===========================================================================
PROMPT Provide the Transaction ID (CUSTOMER_TRX_ID). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_customer_trx_id CHAR   PROMPT 'Enter the Transaction ID: '
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
   p_tax_regime                   VARCHAR2(240)  := '~p_tax_regime';
   p_co_id                        NUMBER         := '~p_co_id';
   p_tax1                         VARCHAR2(240)  := '~p_tax1';
   p_customer_trx_id              VARCHAR2(240)  := '~p_customer_trx_id';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN

IF p_co_id = -1 THEN
   p_co_id := NULL;
END IF;
IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.USER_NAME;
END IF;

IF p_resp_id IS NULL THEN
   p_resp_id := FND_GLOBAL.RESP_NAME;
END IF;


   o2c_ebtax_analyzer_pkg.main(
     p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_tax_regime                   => p_tax_regime
    ,p_co_id                        => p_co_id
    ,p_tax1                         => upper(p_tax1)
    ,p_customer_trx_id              => p_customer_trx_id
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;