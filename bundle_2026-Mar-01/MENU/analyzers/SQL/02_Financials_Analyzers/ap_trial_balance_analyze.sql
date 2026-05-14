REM $Id: ap_trial_balance_analyze.sql, 200.65 2026/02/24 19:54:33 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ap_trial_balance_analyze.sql                                           |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ap_trial_balance_analyzer_pkg.main procedure |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Payables Trial Balance Analyzer
REM
REM MENU_START
REM
REM SQL: Run Payables Trial Balance Analyzer
REM FNDLOAD: Load Payables Trial Balance Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Payables Trial Balance Analyzer Help [Doc ID: 1553507.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ap_trial_balance_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Payables Trial Balance Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AP_TOP
REM PROG_NAME: APTBVAL
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: AP_TBAZ.ldt
REM
REM PROD_SHORT_NAME: SQLAP
REM CP_FILE: 
REM APP_NAME: Payables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ap_trial_balance_analyzer.sql
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
PROMPT Submitting Payables Trial Balance Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Analyzer Mode (Transaction/Daterange) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_mode CHAR   PROMPT 'Enter the mode: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Ledger ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_ledger_id CHAR   PROMPT 'Enter the ledger_id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the TB Definition Code This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_tb_code CHAR   PROMPT 'Enter the tb_code: '
PROMPT
PROMPT ===========================================================================
PROMPT Full Liability Code Combination (with separator) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_liab_acc2 CHAR   PROMPT 'Enter the Full Liability Code Combination (with separator): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the invoice_id (For Transaction Mode) or press enter to leave blank. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_invoice_id NUMBER  DEFAULT '-1' PROMPT 'Enter the invoice_id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Start Date(DD-MON-YYYY) in case of Date Range else leave blank. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_start_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the start_date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the End Date(DD-MON-YYYY) in case of Date Range else leave blank. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_end_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the end_date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [500] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '500' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_mode                         VARCHAR2(240)  := '~p_mode';
   p_ledger_id                    VARCHAR2(240)  := '~p_ledger_id';
   p_tb_code                      VARCHAR2(240)  := '~p_tb_code';
   p_liab_acc2                    VARCHAR2(240)  := '~p_liab_acc2';
   p_invoice_id                   NUMBER         := '~p_invoice_id';
   p_start_date                   DATE           := to_date('~p_start_date','DD-MON-YYYY');
   p_end_date                     DATE           := to_date('~p_end_date','DD-MON-YYYY');
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_invoice_id = -1 THEN
   p_invoice_id := NULL;
END IF;
IF p_start_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_start_date := NULL;
END IF;
IF p_end_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_end_date := NULL;
END IF;

   ap_trial_balance_analyzer_pkg.main(
     p_mode                         => p_mode
    ,p_ledger_id                    => p_ledger_id
    ,p_tb_code                      => p_tb_code
    ,p_liab_acc2                    => p_liab_acc2
    ,p_invoice_id                   => p_invoice_id
    ,p_start_date                   => p_start_date
    ,p_end_date                     => p_end_date
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;