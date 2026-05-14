REM $Id: ap_gdf_detect_analyze_all.sql, 200.498 2026/02/25 11:39:12 sdenye Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ap_gdf_detect_analyze_all.sql                                          |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ap_gdf_detect_analyzer_pkg.main procedure    |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Master GDF Diagnostic Analyzer - ALL
REM
REM MENU_START
REM
REM SQL: Run Master GDF Diagnostic Analyzer - ALL
REM FNDLOAD: Load Master GDF Diagnostic Analyzer - ALL as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Master GDF Diagnostic Analyzer - ALL Help [Doc ID: 1360390.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ap_gdf_detect_analyze_all.sql as APPS user to create an HTML report
REM
REM    (2) Install Master GDF Diagnostic Analyzer - ALL as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Payables Reports Only"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AP_TOP
REM PROG_NAME: APGDFVAL_A
REM DEF_REQ_GROUP: Payables Reports Only
REM PROG_TEMPLATE: MGDAZ.ldt
REM
REM PROD_SHORT_NAME: SQLAP
REM CP_FILE: 
REM APP_NAME: Payables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ap_gdf_detect_analyzer.sql
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
PROMPT Submitting Master GDF Diagnostic Analyzer...

PROMPT ===========================================================================
PROMPT Enter the transaction type [INVOICE|PAYMENT|SUPPLIER|ALL] Default=ALL 
PROMPT ===========================================================================
PROMPT
ACCEPT p_trx_type CHAR  DEFAULT 'ALL' PROMPT 'Enter the Transaction Type: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the START DATE for transactions to validate  
PROMPT ===========================================================================
PROMPT
ACCEPT p_start_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the Start Date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the END DATE for the transactions to validate  
PROMPT ===========================================================================
PROMPT
ACCEPT p_end_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the End Date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter a comma separated list of org_id(s) for the operating unit(s) to validate. Default=ALL 
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_ids_sql NUMBER  DEFAULT '-1' PROMPT 'Enter the org_id(s): '
PROMPT
PROMPT ===========================================================================
PROMPT Validations to Perform (GDF|NON-GDF|ALL) [ALL] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_validations CHAR  DEFAULT 'ALL' PROMPT 'Enter the Validations to Perform [GDF|NON-GDF|ALL]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the max rows to display on row limited queries. Default=20 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_trx_type                     VARCHAR2(240)  := '~p_trx_type';
   p_start_date                   DATE           := to_date('~p_start_date','DD-MON-YYYY');
   p_end_date                     DATE           := to_date('~p_end_date','DD-MON-YYYY');
   p_org_ids_sql                  NUMBER         := '~p_org_ids_sql';
   p_validations                  VARCHAR2(240)  := '~p_validations';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_org_ids_sql = -1 THEN
   p_org_ids_sql := NULL;
END IF;
IF p_start_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_start_date := NULL;
END IF;
IF p_end_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_end_date := NULL;
END IF;

   ap_gdf_detect_analyzer_pkg.main(
     p_analysis_mode                => 'ALL'
    ,p_trx_type                     => p_trx_type
    ,p_start_date                   => p_start_date
    ,p_end_date                     => p_end_date
    ,p_org_ids_sql                  => p_org_ids_sql
    ,p_validations                  => p_validations
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;