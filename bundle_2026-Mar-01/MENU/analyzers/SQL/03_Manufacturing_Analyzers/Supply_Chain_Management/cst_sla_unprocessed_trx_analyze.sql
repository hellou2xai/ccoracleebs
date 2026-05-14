REM $Id: cst_sla_unprocessed_trx_analyze.sql, 200.30 2026/01/28 12:01:59 sothman Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    cst_sla_unprocessed_trx_analyze.sql                                    |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the cst_sla_analyzer_pkg.main procedure          |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Create Accounting-Cost Management Analyzer
REM
REM MENU_START
REM
REM SQL: Run Create Accounting-Cost Management Analyzer
REM FNDLOAD: Load Create Accounting-Cost Management Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Create Accounting-Cost Management Analyzer Help [Doc ID: 1580316.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs cst_sla_unprocessed_trx_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Create Accounting-Cost Management Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Cost Management - SLA"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: BOM_TOP
REM PROG_NAME: CSTSUTA
REM DEF_REQ_GROUP: Cost Management - SLA
REM PROG_TEMPLATE: CSTSUTAAZ.ldt
REM
REM PROD_SHORT_NAME: BOM
REM CP_FILE: 
REM APP_NAME: Bills of Material
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM cst_sla_unprocessed_trx_analyzer.sql
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
PROMPT Submitting Create Accounting-Cost Management Analyzer...

PROMPT ===========================================================================
PROMPT Ledger ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT ledger_id_sql NUMBER  DEFAULT '-1' PROMPT 'Enter the LEDGER_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Start Date (DD-MON-YYYY) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_from_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the Start Date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the End Date (DD-MON-YYYY) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_to_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the End Date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '300' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   ledger_id_sql                  NUMBER         := '~ledger_id_sql';
   p_from_date                    DATE           := to_date('~p_from_date','DD-MON-YYYY');
   p_to_date                      DATE           := to_date('~p_to_date','DD-MON-YYYY');
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF ledger_id_sql = -1 THEN
   ledger_id_sql := NULL;
END IF;
IF p_from_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_from_date := NULL;
END IF;
IF p_to_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_to_date := NULL;
END IF;
IF p_from_date IS NULL THEN
   p_from_date := to_char(sysdate-365,'DD-MON-YYYY');
END IF;

IF p_to_date IS NULL THEN
   p_to_date := to_char(sysdate,'DD-MON-YYYY');
END IF;


   cst_sla_analyzer_pkg.main(
     ledger_id_sql                  => ledger_id_sql
    ,p_from_date                    => p_from_date
    ,p_to_date                      => p_to_date
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;