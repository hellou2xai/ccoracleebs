REM $Id: fin_emea_analyze.sql, 200.15 2026/01/28 07:13:01 saananth Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    fin_emea_analyze.sql                                                   |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the fin_emea_analyzer_pkg.main procedure         |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Financials for EMEA Analyzer
REM
REM MENU_START
REM
REM SQL: Run Financials for EMEA Analyzer
REM FNDLOAD: Load Financials for EMEA Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Financials for EMEA Analyzer Help [Doc ID: 2431799.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs fin_emea_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Financials for EMEA Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Regional Cross Product Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: JG_TOP
REM PROG_NAME: JE_FIN_EMEA
REM DEF_REQ_GROUP: Regional Cross Product Reports
REM PROG_TEMPLATE: JE_FIN_EMEAAZ.ldt
REM
REM PROD_SHORT_NAME: JG
REM CP_FILE: 
REM APP_NAME: Regional Localizations
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM fin_emea_analyzer.sql
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
PROMPT Submitting Financials for EMEA Analyzer...

PROMPT ===========================================================================
PROMPT Enter VAT Reporting Entity ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_vat_rep_entity_id NUMBER  DEFAULT '-1' PROMPT 'Enter the VAT Reporting Entity ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter EMEA VAT Selection Process - Request ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_emea_vat_sel_process NUMBER  DEFAULT '-1' PROMPT 'Enter the EMEA VAT Selection Process - Request ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the application name. Valid values are "Payables" or "Receivables" This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_application CHAR   PROMPT 'Enter the Application: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Transaction ID (Invoice ID). This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_transaction_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Invoice ID / Transaction ID: '
PROMPT
PROMPT
DECLARE
   p_vat_rep_entity_id            NUMBER         := '~p_vat_rep_entity_id';
   p_emea_vat_sel_process         NUMBER         := '~p_emea_vat_sel_process';
   p_application                  VARCHAR2(240)  := '~p_application';
   p_transaction_id               NUMBER         := '~p_transaction_id';

BEGIN

IF p_vat_rep_entity_id = -1 THEN
   p_vat_rep_entity_id := NULL;
END IF;
IF p_emea_vat_sel_process = -1 THEN
   p_emea_vat_sel_process := NULL;
END IF;
IF p_transaction_id = -1 THEN
   p_transaction_id := NULL;
END IF;

   fin_emea_analyzer_pkg.main(
     p_vat_rep_entity_id            => p_vat_rep_entity_id
    ,p_emea_vat_sel_process         => p_emea_vat_sel_process
    ,p_application                  => p_application
    ,p_transaction_id               => p_transaction_id
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;