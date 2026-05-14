REM $Id: inv_trans_analyze.sql, 200.69 2026/02/23 18:15:17 jphipps Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    inv_trans_analyze.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the inv_trans_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Inventory Transactions Analyzer
REM
REM MENU_START
REM
REM SQL: Run Inventory Transactions Analyzer
REM FNDLOAD: Load Inventory Transactions Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Inventory Transactions Analyzer Help [Doc ID: 1499475.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs inv_trans_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Inventory Transactions Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Inclusive GUI"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: INV_TOP
REM PROG_NAME: INVTAZ
REM DEF_REQ_GROUP: All Inclusive GUI
REM PROG_TEMPLATE: INVTAZAZ.ldt
REM PROG_TEMPLATE_11i: INVTAZAZ_11i.ldt
REM PROD_SHORT_NAME: INV
REM CP_FILE: 
REM APP_NAME: Inventory
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM inv_trans_analyzer.sql
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
PROMPT Submitting Inventory Transactions Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Organization Code This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_code CHAR   PROMPT 'Enter the Organization Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Item (Optional) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_item_num CHAR   PROMPT 'Enter the Item (Item Name / Part Number - Optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Serial Number (Optional) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_serial_num CHAR   PROMPT 'Enter the Serial Number (Optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Lot Number (Optional) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_lot_num CHAR   PROMPT 'Enter the Lot Number (Optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter License Plate Number (Optional) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_lpn_num CHAR   PROMPT 'Enter the License Plate Number (Optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [100] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '100' PROMPT 'Enter the Maximum Rows to Display (Default 100): '
PROMPT
PROMPT
DECLARE
   p_org_code                     VARCHAR2(240)  := '~p_org_code';
   p_item_num                     VARCHAR2(240)  := '~p_item_num';
   p_serial_num                   VARCHAR2(240)  := '~p_serial_num';
   p_lot_num                      VARCHAR2(240)  := '~p_lot_num';
   p_lpn_num                      VARCHAR2(240)  := '~p_lpn_num';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   inv_trans_analyzer_pkg.main(
     p_org_code                     => p_org_code
    ,p_item_num                     => p_item_num
    ,p_serial_num                   => p_serial_num
    ,p_lot_num                      => p_lot_num
    ,p_lpn_num                      => p_lpn_num
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;