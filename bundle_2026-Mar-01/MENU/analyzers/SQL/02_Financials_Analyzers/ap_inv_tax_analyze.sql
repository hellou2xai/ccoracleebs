REM $Id: ap_inv_tax_analyze.sql, 200.134 2026/02/25 12:09:02 sdenye Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ap_inv_tax_analyze.sql                                                 |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the tax_setup_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Payables Invoice Analyzer
REM
REM MENU_START
REM
REM SQL: Run Payables Invoice Analyzer
REM FNDLOAD: Load Payables Invoice Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Payables Invoice Analyzer Help [Doc ID: 1529429.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ap_inv_tax_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Payables Invoice Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AP_TOP
REM PROG_NAME: APEBTAXAZ
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: EB-TAX_AP_ARAZ.ldt
REM
REM PROD_SHORT_NAME: SQLAP
REM CP_FILE: 
REM APP_NAME: Payables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ap_inv_tax_analyzer.sql
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
PROMPT Submitting Payables Invoice Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Invoice ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_transaction_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Invoice ID: '
PROMPT
PROMPT ===========================================================================
PROMPT AP Data Validation Report or MGDF output lists the corruption specific to the Invoice ID you have selected for. Put N if don't want to run it. Else keep it Blank 
PROMPT ===========================================================================
PROMPT
ACCEPT p_master_gdf CHAR  DEFAULT 'Y' PROMPT 'Enter the Do you want to run the MGDF for the specific Invoice? (Default Y): '
PROMPT
PROMPT ===========================================================================
PROMPT Do you ONLY want to collect the Invoice data or do you also want to run the more detailed Invoice checks?  Default is N (detailed run) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_aplist CHAR  DEFAULT 'N' PROMPT 'Enter the Do you want to ONLY collect the Invoice diagnostic? (Default is N): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Check ID (optional with Invoice ID). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_check_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Check ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [1000] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '1000' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_transaction_id               NUMBER         := '~p_transaction_id';
   p_master_gdf                   VARCHAR2(240)  := '~p_master_gdf';
   p_aplist                       VARCHAR2(240)  := '~p_aplist';
   p_check_id                     NUMBER         := '~p_check_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_transaction_id = -1 THEN
   p_transaction_id := NULL;
END IF;
IF p_check_id = -1 THEN
   p_check_id := NULL;
END IF;

   tax_setup_analyzer_pkg.main(
     p_transaction_id               => p_transaction_id
    ,p_master_gdf                   => p_master_gdf
    ,p_aplist                       => p_aplist
    ,p_check_id                     => p_check_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;