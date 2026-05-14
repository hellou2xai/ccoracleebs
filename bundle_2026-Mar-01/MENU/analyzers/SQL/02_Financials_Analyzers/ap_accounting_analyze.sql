REM $Id: ap_accounting_analyze.sql, 200.80 2026/02/24 19:53:16 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ap_accounting_analyze.sql                                              |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ap_accounting_analyzer_pkg.main procedure    |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Payables Create Accounting Analyzer
REM
REM MENU_START
REM
REM SQL: Run Payables Create Accounting Analyzer
REM FNDLOAD: Load Payables Create Accounting Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Payables Create Accounting Analyzer Help [Doc ID: 1665706.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ap_accounting_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Payables Create Accounting Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AP_TOP
REM PROG_NAME: APCAANL
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: AP_CREATE_ACCTGAZ.ldt
REM
REM PROD_SHORT_NAME: SQLAP
REM CP_FILE: 
REM APP_NAME: Payables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ap_accounting_analyzer.sql
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
PROMPT Submitting Payables Create Accounting Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Ledger ID where you are trying to create accounting. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_ledger_id2 NUMBER  DEFAULT '-1' PROMPT 'Enter the Ledger ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Invoice ID (optional with Check ID). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_invoice_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Invoice ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Check ID (optional with Invoice ID). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_check_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Check ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include invoice data collection (APList)?  Default value is Y. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_aplist CHAR  DEFAULT 'Y' PROMPT 'Enter the Include APList Information (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [500] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '500' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_ledger_id2                   NUMBER         := '~p_ledger_id2';
   p_invoice_id                   NUMBER         := '~p_invoice_id';
   p_check_id                     NUMBER         := '~p_check_id';
   p_aplist                       VARCHAR2(240)  := '~p_aplist';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_ledger_id2 = -1 THEN
   p_ledger_id2 := NULL;
END IF;
IF p_invoice_id = -1 THEN
   p_invoice_id := NULL;
END IF;
IF p_check_id = -1 THEN
   p_check_id := NULL;
END IF;

   ap_accounting_analyzer_pkg.main(
     p_ledger_id2                   => p_ledger_id2
    ,p_invoice_id                   => p_invoice_id
    ,p_check_id                     => p_check_id
    ,p_aplist                       => nvl(trim(upper(p_aplist)),'Y')
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;