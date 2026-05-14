REM $Id: oks_billing_analyze.sql, 200.23 2026/01/28 18:16:24 mantonyk Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    oks_billing_analyze.sql                                                |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the oks_billing_analyzer_pkg.main procedure      |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Service Contracts Billing Analyzer
REM
REM MENU_START
REM
REM SQL: Run Service Contracts Billing Analyzer
REM FNDLOAD: Load Service Contracts Billing Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Service Contracts Billing Analyzer Help [Doc ID: 1987555.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs oks_billing_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Service Contracts Billing Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Service Contracts All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: OKS_TOP
REM PROG_NAME: OKS_BILLING
REM DEF_REQ_GROUP: Service Contracts All
REM PROG_TEMPLATE: OKS_BILLINGAZ.ldt
REM
REM PROD_SHORT_NAME: OKS
REM CP_FILE: 
REM APP_NAME: Service Contracts
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM oks_billing_analyzer.sql
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
PROMPT Submitting Service Contracts Billing Analyzer...

PROMPT ===========================================================================
PROMPT Please execute the query in sqlplus to get the relevant Contract ID: select id from okc_k_headers_all_b where contract_number = '&contract_number' and NVL(contract_number_modifier,'-') = NVL('&contract_number_modifier','-'); This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_contract_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Contract ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_contract_id                  NUMBER         := '~p_contract_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_contract_id = -1 THEN
   p_contract_id := NULL;
END IF;

   oks_billing_analyzer_pkg.main(
     p_contract_id                  => p_contract_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;