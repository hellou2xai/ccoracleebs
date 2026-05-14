REM $Id: po_accrual_analyze.sql, 200.16 2026/01/28 15:25:00 pksethi Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    po_accrual_analyze.sql                                                 |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the po_accrual_analyzer_pkg.main procedure       |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Procurement Accrual Accounting Analyzer
REM
REM MENU_START
REM
REM SQL: Run Procurement Accrual Accounting Analyzer
REM FNDLOAD: Load Procurement Accrual Accounting Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Procurement Accrual Accounting Analyzer Help [Doc ID: 1969667.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs po_accrual_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Procurement Accrual Accounting Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PO_TOP
REM PROG_NAME: POACCRUAL
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: POACCRUALAZ.ldt
REM
REM PROD_SHORT_NAME: PO
REM CP_FILE: 
REM APP_NAME: Purchasing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM po_accrual_analyzer.sql
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
PROMPT Submitting Procurement Accrual Accounting Analyzer...

PROMPT ===========================================================================
PROMPT Enter the operating unit. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT l_operating_unit_id NUMBER  DEFAULT '-1' PROMPT 'Enter the operating_unit_id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Ledger ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT l_ledger_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Ledger ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the accrual code combination ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT l_code_combination_id NUMBER  DEFAULT '-1' PROMPT 'Enter the accrual code combination ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the start date of reconciliation. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT l_start_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the START DATE [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the End date of reconciliation. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT l_end_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the End DATE [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   l_operating_unit_id            NUMBER         := '~l_operating_unit_id';
   l_ledger_id                    NUMBER         := '~l_ledger_id';
   l_code_combination_id          NUMBER         := '~l_code_combination_id';
   l_start_date                   DATE           := to_date('~l_start_date','DD-MON-YYYY');
   l_end_date                     DATE           := to_date('~l_end_date','DD-MON-YYYY');
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF l_operating_unit_id = -1 THEN
   l_operating_unit_id := NULL;
END IF;
IF l_ledger_id = -1 THEN
   l_ledger_id := NULL;
END IF;
IF l_code_combination_id = -1 THEN
   l_code_combination_id := NULL;
END IF;
IF l_start_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   l_start_date := NULL;
END IF;
IF l_end_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   l_end_date := NULL;
END IF;

   po_accrual_analyzer_pkg.main(
     l_operating_unit_id            => l_operating_unit_id
    ,l_ledger_id                    => l_ledger_id
    ,l_code_combination_id          => l_code_combination_id
    ,l_start_date                   => l_start_date
    ,l_end_date                     => l_end_date
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;