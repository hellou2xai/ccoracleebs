REM $Id: psa_data_analyze.sql, 200.52 2026/02/25 11:58:05 sdenye Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    psa_data_analyze.sql                                                   |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the psa_data_analyzer_pkg.main procedure         |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: PSA Data Validation Analyzer
REM
REM MENU_START
REM
REM SQL: Run PSA Data Validation Analyzer
REM FNDLOAD: Load PSA Data Validation Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  PSA Data Validation Analyzer Help [Doc ID: 2086996.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs psa_data_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install PSA Data Validation Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Payables Reports Only"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AP_TOP
REM PROG_NAME: PSADIAGNOSTICS
REM DEF_REQ_GROUP: Payables Reports Only
REM PROG_TEMPLATE: PSADIAGNOSTICSAZ.ldt
REM
REM PROD_SHORT_NAME: SQLAP
REM CP_FILE: 
REM APP_NAME: Payables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM psa_data_analyzer.sql
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
PROMPT Submitting PSA Data Validation Analyzer...

PROMPT ===========================================================================
PROMPT Enter the invoice ID for the transaction to be validated.  This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_invoice_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Invoice ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_invoice_id                   NUMBER         := '~p_invoice_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_invoice_id = -1 THEN
   p_invoice_id := NULL;
END IF;

   psa_data_analyzer_pkg.main(
     p_invoice_id                   => p_invoice_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;