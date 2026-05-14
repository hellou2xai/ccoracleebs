REM $Id: inventory_item_analyze.sql, 200.31 2026/02/23 18:12:51 srayadur Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    inventory_item_analyze.sql                                             |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the inv_item_analyzer_pkg.main procedure         |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Inventory Item Analyzer
REM
REM MENU_START
REM
REM SQL: Run Inventory Item Analyzer
REM FNDLOAD: Load Inventory Item Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Inventory Item Analyzer Help [Doc ID: 2047671.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs inventory_item_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Inventory Item Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Inclusive GUI"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: INV_TOP
REM PROG_NAME: INVITMANZ
REM DEF_REQ_GROUP: All Inclusive GUI
REM PROG_TEMPLATE: INVITMANALYZERAZ.ldt
REM PROG_TEMPLATE_11i: INVITMANALYZERAZ_11i.ldt
REM PROD_SHORT_NAME: INV
REM CP_FILE: 
REM APP_NAME: Inventory
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM inventory_item_analyzer.sql
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
PROMPT Submitting Inventory Item Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Organization Code (not Org ID) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_code CHAR   PROMPT 'Enter the Organization Code (not Org ID): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Item (not Item ID) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_item_num CHAR   PROMPT 'Enter the Item (not Item ID): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Y for 'Yes' Or N for 'No'  (Default is No) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Diagnostic Apps Check: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the debug mode [Y] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_debug_mode CHAR  DEFAULT 'Y' PROMPT 'Enter the Debug Mode: '
PROMPT
PROMPT
DECLARE
   p_org_code                     VARCHAR2(240)  := '~p_org_code';
   p_item_num                     VARCHAR2(240)  := '~p_item_num';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';
   p_debug_mode                   VARCHAR2(240)  := '~p_debug_mode';

BEGIN


   inv_item_analyzer_pkg.main(
     p_org_code                     => p_org_code
    ,p_item_num                     => p_item_num
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
    ,p_debug_mode                   => p_debug_mode
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;