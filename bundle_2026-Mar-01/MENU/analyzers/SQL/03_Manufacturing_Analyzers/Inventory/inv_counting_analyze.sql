REM $Id: inv_counting_analyze.sql, 200.20 2026/02/23 18:06:09 rcastro Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    inv_counting_analyze.sql                                               |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the inv_counting_analyzer_pkg.main procedure     |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Inventory Counting Analyzer
REM
REM MENU_START
REM
REM SQL: Run Inventory Counting Analyzer
REM FNDLOAD: Load Inventory Counting Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Inventory Counting Analyzer Help [Doc ID: 2820764.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs inv_counting_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Inventory Counting Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Inclusive GUI"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: INV_TOP
REM PROG_NAME: INV_COUNTING_ANALYZER_SQL
REM DEF_REQ_GROUP: All Inclusive GUI
REM PROG_TEMPLATE: INVCOUNTINGAZ.ldt
REM PROG_TEMPLATE_11i: INVCOUNTINGAZ_11i.ldt
REM PROD_SHORT_NAME: INV
REM CP_FILE: 
REM APP_NAME: Inventory
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM inv_counting_analyzer.sql
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
PROMPT Submitting Inventory Counting Analyzer...

PROMPT ===========================================================================
PROMPT Enter the organization code (not org_id) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_code CHAR   PROMPT 'Enter the Organization code (not org_id): '
PROMPT
PROMPT ===========================================================================
PROMPT Count Type you which to collect information from. CC for Cycle Count or PI for Physical Inventory. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_count_type CHAR   PROMPT 'Enter the Enter the Count Type (CC or PI): '
PROMPT
PROMPT ===========================================================================
PROMPT Cycle Count Name 
PROMPT ===========================================================================
PROMPT
ACCEPT p_cc_name CHAR   PROMPT 'Enter the Cycle Count Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Physical Inventory Name 
PROMPT ===========================================================================
PROMPT
ACCEPT p_pi_name CHAR   PROMPT 'Enter the Physical Inventory Name: '
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
   p_count_type                   VARCHAR2(240)  := '~p_count_type';
   p_cc_name                      VARCHAR2(240)  := '~p_cc_name';
   p_pi_name                      VARCHAR2(240)  := '~p_pi_name';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   inv_counting_analyzer_pkg.main(
     p_org_code                     => p_org_code
    ,p_count_type                   => p_count_type
    ,p_cc_name                      => p_cc_name
    ,p_pi_name                      => p_pi_name
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;