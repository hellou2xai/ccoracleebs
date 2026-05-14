REM $Id: oph_analyze.sql, 200.14 2026/01/29 16:37:20 srayadur Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    oph_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the oph_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Product Hub Analyzer
REM
REM MENU_START
REM
REM SQL: Run Product Hub Analyzer
REM FNDLOAD: Load Product Hub Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Product Hub Analyzer Help [Doc ID: 2272263.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs oph_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Product Hub Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Item Manager RG"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: EGO_TOP
REM PROG_NAME: OPH_ANALYZER_SQL
REM DEF_REQ_GROUP: Item Manager RG
REM PROG_TEMPLATE: OPHANLYAZ.ldt
REM PROG_TEMPLATE_11i: OPHANLYAZ_11i.ldt
REM PROD_SHORT_NAME: EGO
REM CP_FILE: 
REM APP_NAME: Advanced Product Catalog
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM oph_analyzer.sql
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
PROMPT Submitting Product Hub Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Organization Code for the warehouse This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_code CHAR   PROMPT 'Enter the Organization Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Change Order Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_chg_ord_num CHAR   PROMPT 'Enter the Change Order Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Inventory Item Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_item_number CHAR   PROMPT 'Enter the Inventory Item Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '50' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_org_code                     VARCHAR2(240)  := '~p_org_code';
   p_chg_ord_num                  VARCHAR2(240)  := '~p_chg_ord_num';
   p_item_number                  VARCHAR2(240)  := '~p_item_number';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   oph_analyzer_pkg.main(
     p_org_code                     => p_org_code
    ,p_chg_ord_num                  => p_chg_ord_num
    ,p_item_number                  => p_item_number
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;