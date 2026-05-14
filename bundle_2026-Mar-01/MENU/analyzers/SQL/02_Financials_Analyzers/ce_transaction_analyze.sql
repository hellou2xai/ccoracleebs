REM $Id: ce_transaction_analyze.sql, 200.47 2026/02/25 10:48:15 sdenye Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ce_transaction_analyze.sql                                             |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ce_transaction_analyzer_pkg.main procedure   |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Cash Management Transaction Analyzer
REM
REM MENU_START
REM
REM SQL: Run Cash Management Transaction Analyzer
REM FNDLOAD: Load Cash Management Transaction Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Cash Management Transaction Analyzer Help [Doc ID: 2069274.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ce_transaction_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Cash Management Transaction Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: CE_TOP
REM PROG_NAME: CETRXN
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: CETRXNAZ.ldt
REM
REM PROD_SHORT_NAME: CE
REM CP_FILE: 
REM APP_NAME: Cash Management
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ce_transaction_analyzer.sql
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
PROMPT Submitting Cash Management Transaction Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Ledger ID to which the Transaction belongs This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_ledger_id2 NUMBER  DEFAULT '-1' PROMPT 'Enter the Ledger ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Transaction Type. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_trx_type CHAR   PROMPT 'Enter the Transaction Type [PAYMENT, RECEIPT, CASHFLOW or JOURNAL]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Transaction ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_trx_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Transaction ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [10] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '10' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_ledger_id2                   NUMBER         := '~p_ledger_id2';
   p_trx_type                     VARCHAR2(240)  := '~p_trx_type';
   p_trx_id                       NUMBER         := '~p_trx_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_ledger_id2 = -1 THEN
   p_ledger_id2 := NULL;
END IF;
IF p_trx_id = -1 THEN
   p_trx_id := NULL;
END IF;

   ce_transaction_analyzer_pkg.main(
     p_ledger_id2                   => p_ledger_id2
    ,p_trx_type                     => p_trx_type
    ,p_trx_id                       => p_trx_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;