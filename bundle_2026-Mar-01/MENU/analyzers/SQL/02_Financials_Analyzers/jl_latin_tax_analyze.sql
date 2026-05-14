REM $Id: jl_latin_tax_analyze.sql, 200.11 2025/12/08 13:35:43 jdhincks Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    jl_latin_tax_analyze.sql                                               |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the jl_latin_tax_analyzer_pkg.main procedure     |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Latin Tax Analyzer
REM
REM MENU_START
REM
REM SQL: Run Latin Tax Analyzer
REM FNDLOAD: Load Latin Tax Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Latin Tax Analyzer Help [Doc ID: 2389945.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs jl_latin_tax_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Latin Tax Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "JLAR + AR Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: JL_TOP
REM PROG_NAME: JLTAXANL
REM DEF_REQ_GROUP: JLAR + AR Reports
REM PROG_TEMPLATE: JL_TAX_ANLZAZ.ldt
REM
REM PROD_SHORT_NAME: JL
REM CP_FILE: 
REM APP_NAME: Latin America Localizations
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM jl_latin_tax_analyzer.sql
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
PROMPT Submitting Latin Tax Analyzer...

PROMPT ===========================================================================
PROMPT Enter the User Name used to log into Receivables. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_user_name CHAR   PROMPT 'Enter the User Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Responsibility ID. This parameter is required.
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
PROMPT Enter the Tax Category ID (TAX_CATEGORY_ID). This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_tax_category_id CHAR   PROMPT 'Enter the Tax Category: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Transaction ID (CUSTOMER_TRX_ID). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_customer_trx_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Transaction ID: '
PROMPT
PROMPT
DECLARE
   p_user_name                    VARCHAR2(240)  := '~p_user_name';
   p_resp_id                      NUMBER         := '~p_resp_id';
   p_org_id                       VARCHAR2(240)  := '~p_org_id';
   p_tax_category_id              VARCHAR2(240)  := '~p_tax_category_id';
   p_customer_trx_id              NUMBER         := '~p_customer_trx_id';

BEGIN

IF p_customer_trx_id = -1 THEN
   p_customer_trx_id := NULL;
END IF;
IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.USER_NAME;
END IF;

IF p_resp_id IS NULL THEN
   p_resp_id := FND_GLOBAL.RESP_NAME;
END IF;


   jl_latin_tax_analyzer_pkg.main(
     p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_org_id                       => p_org_id
    ,p_tax_category_id              => p_tax_category_id
    ,p_customer_trx_id              => p_customer_trx_id
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;