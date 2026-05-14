REM $Id: inv_consignment_analyze.sql, 200.31 2026/02/23 18:02:28 jphipps Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    inv_consignment_analyze.sql                                            |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the inv_consign_analyzer_pkg.main procedure      |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Inventory Consignment Analyzer
REM
REM MENU_START
REM
REM SQL: Run Inventory Consignment Analyzer
REM FNDLOAD: Load Inventory Consignment Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Inventory Consignment Analyzer Help [Doc ID: 2048039.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs inv_consignment_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Inventory Consignment Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Inclusive GUI"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: INV_TOP
REM PROG_NAME: INV_CONSIGNMENT_ANALYZER_SQL
REM DEF_REQ_GROUP: All Inclusive GUI
REM PROG_TEMPLATE: INVCAZAZ.ldt
REM PROG_TEMPLATE_11i: INVCAZAZ_11i.ldt
REM PROD_SHORT_NAME: INV
REM CP_FILE: 
REM APP_NAME: Inventory
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM inv_consignment_analyzer.sql
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
PROMPT Submitting Inventory Consignment Analyzer...

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
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_org_code                     VARCHAR2(240)  := '~p_org_code';
   p_item_num                     VARCHAR2(240)  := '~p_item_num';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   inv_consign_analyzer_pkg.main(
     p_org_code                     => p_org_code
    ,p_item_num                     => p_item_num
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;