REM $Id: ap_gdf_detect_analyze_single.sql, 200.498 2026/02/25 11:39:12 sdenye Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ap_gdf_detect_analyze_single.sql                                       |
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
REM MENU_TITLE: Master GDF Diagnostic Analyzer - SINGLE
REM
REM MENU_START
REM
REM SQL: Run Master GDF Diagnostic Analyzer - SINGLE
REM FNDLOAD: Load Master GDF Diagnostic Analyzer - SINGLE as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Master GDF Diagnostic Analyzer - SINGLE Help [Doc ID: 1360390.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ap_gdf_detect_analyze_single.sql as APPS user to create an HTML report
REM
REM    (2) Install Master GDF Diagnostic Analyzer - SINGLE as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Payables Reports Only"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AP_TOP
REM PROG_NAME: APGDFVAL_S
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
PROMPT Enter the INVOICE ID or press enter to leave blank:  
PROMPT ===========================================================================
PROMPT
ACCEPT p_invoice_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Invoice ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the CHECK ID or press enter to leave blank:  
PROMPT ===========================================================================
PROMPT
ACCEPT p_check_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Check ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the VENDOR ID  or press enter to leave blank:  
PROMPT ===========================================================================
PROMPT
ACCEPT p_vendor_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Vendor ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Validations to Perform (GDF|NON-GDF|ALL) [ALL] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_validations CHAR  DEFAULT 'ALL' PROMPT 'Enter the Validations to Perform [GDF|NON-GDF|ALL]: '
PROMPT
PROMPT ===========================================================================
PROMPT Indicate whether or not to run general checks which are not associated with the transaction(s) specified.  This may be advantageous for performance reasons. Default = N.  Enter Y or N 
PROMPT ===========================================================================
PROMPT
ACCEPT p_skip_general CHAR  DEFAULT 'N' PROMPT 'Enter the Skip General Section (Y|N)  [Default = N]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the max rows to display on row limited queries. Default=20 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_invoice_id                   NUMBER         := '~p_invoice_id';
   p_check_id                     NUMBER         := '~p_check_id';
   p_vendor_id                    NUMBER         := '~p_vendor_id';
   p_validations                  VARCHAR2(240)  := '~p_validations';
   p_skip_general                 VARCHAR2(240)  := '~p_skip_general';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_invoice_id = -1 THEN
   p_invoice_id := NULL;
END IF;
IF p_check_id = -1 THEN
   p_check_id := NULL;
END IF;
IF p_vendor_id = -1 THEN
   p_vendor_id := NULL;
END IF;

   ap_gdf_detect_analyzer_pkg.main(
     p_analysis_mode                => 'SINGLE'
    ,p_invoice_id                   => p_invoice_id
    ,p_check_id                     => p_check_id
    ,p_vendor_id                    => p_vendor_id
    ,p_validations                  => p_validations
    ,p_skip_general                 => p_skip_general
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;