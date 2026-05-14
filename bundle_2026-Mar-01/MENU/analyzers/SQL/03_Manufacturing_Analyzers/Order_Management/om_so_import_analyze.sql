REM $Id: om_so_import_analyze.sql, 200.23 2026/01/28 14:39:47 cschmehl Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    om_so_import_analyze.sql                                               |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the om_so_import_analyzer_pkg.main procedure     |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Sales Order Import Analyzer
REM
REM MENU_START
REM
REM SQL: Run Sales Order Import Analyzer
REM FNDLOAD: Load Sales Order Import Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Sales Order Import Analyzer Help [Doc ID: 2720783.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs om_so_import_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Sales Order Import Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "OM Concurrent Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: ONT_TOP
REM PROG_NAME: OMSOIMPORT
REM DEF_REQ_GROUP: OM Concurrent Programs
REM PROG_TEMPLATE: OMSOIMPORTAZ.ldt
REM
REM PROD_SHORT_NAME: ONT
REM CP_FILE: 
REM APP_NAME: Order Management
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM om_so_import_analyzer.sql
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
PROMPT Submitting Sales Order Import Analyzer...

PROMPT ===========================================================================
PROMPT Enter value for Order Source Id: This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_order_source_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Order Source Id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Value for Orig Sys Document Reference: This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_orig_sys_document_ref CHAR   PROMPT 'Enter the Orig Sys Document Reference: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter value for Orig Sys Line Ref: 
PROMPT ===========================================================================
PROMPT
ACCEPT p_orig_sys_line_ref CHAR   PROMPT 'Enter the Orig Sys Line Ref: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check (Y/N) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Diagnostic Apps Check (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_order_source_id              NUMBER         := '~p_order_source_id';
   p_orig_sys_document_ref        VARCHAR2(240)  := '~p_orig_sys_document_ref';
   p_orig_sys_line_ref            VARCHAR2(240)  := '~p_orig_sys_line_ref';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_order_source_id = -1 THEN
   p_order_source_id := NULL;
END IF;

   om_so_import_analyzer_pkg.main(
     p_order_source_id              => p_order_source_id
    ,p_orig_sys_document_ref        => p_orig_sys_document_ref
    ,p_orig_sys_line_ref            => p_orig_sys_line_ref
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;