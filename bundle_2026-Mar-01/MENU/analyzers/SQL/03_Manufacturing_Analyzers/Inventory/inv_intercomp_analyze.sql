REM $Id: inv_intercomp_analyze.sql, 200.21 2026/01/29 16:53:46 tchavez Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    inv_intercomp_analyze.sql                                              |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the inv_intercomp_analyzer_pkg.main procedure    |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Inventory Intercompany AR and AP Invoicing Analyzer
REM
REM MENU_START
REM
REM SQL: Run Inventory Intercompany AR and AP Invoicing Analyzer
REM FNDLOAD: Load Inventory Intercompany AR and AP Invoicing Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Inventory Intercompany AR and AP Invoicing Analyzer Help [Doc ID: 2220141.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs inv_intercomp_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Inventory Intercompany AR and AP Invoicing Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Inclusive GUI"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: INV_TOP
REM PROG_NAME: INVICI
REM DEF_REQ_GROUP: All Inclusive GUI
REM PROG_TEMPLATE: INVICIAZ.ldt
REM PROG_TEMPLATE_11i: INVICIAZ_11i.ldt
REM PROD_SHORT_NAME: INV
REM CP_FILE: 
REM APP_NAME: Inventory
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM inv_intercomp_analyzer.sql
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
PROMPT Submitting Inventory Intercompany AR and AP Invoicing Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Sales Order Header ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_header_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Header ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check (Default is Y) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Diagnostic Apps Check (Default is Y): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_header_id                    NUMBER         := '~p_header_id';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_header_id = -1 THEN
   p_header_id := NULL;
END IF;

   inv_intercomp_analyzer_pkg.main(
     p_header_id                    => p_header_id
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;