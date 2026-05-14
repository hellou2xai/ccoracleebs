REM $Id: po_autocreate_analyze_single.sql, 200.54 2026/01/28 14:27:51 loinonen Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    po_autocreate_analyze_single.sql                                       |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the po_autocreate_analyzer_pkg.main procedure    |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Procurement Autocreate Analyzer - SINGLE
REM
REM MENU_START
REM
REM SQL: Run Procurement Autocreate Analyzer - SINGLE
REM FNDLOAD: Load Procurement Autocreate Analyzer - SINGLE as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Procurement Autocreate Analyzer - SINGLE Help [Doc ID: 2101058.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs po_autocreate_analyze_single.sql as APPS user to create an HTML report
REM
REM    (2) Install Procurement Autocreate Analyzer - SINGLE as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PO_TOP
REM PROG_NAME: POAUCR_S
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: POAUCRAZ.ldt
REM
REM PROD_SHORT_NAME: PO
REM CP_FILE: 
REM APP_NAME: Purchasing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM po_autocreate_analyzer.sql
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
PROMPT Submitting Procurement Autocreate Analyzer...

PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check: Valid values are "Y" or "N". This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Diagnostic Apps Check: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the organization id  This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER   PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the document number  This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_trx_num CHAR   PROMPT 'Enter the Requisition Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the line number to only check that specific line, otherwise leave blank to run for all lines.  
PROMPT ===========================================================================
PROMPT
ACCEPT p_line_num NUMBER  DEFAULT '-1' PROMPT 'Enter the Requisition Line Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20]  
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display : '
PROMPT
PROMPT
DECLARE
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_org_id                       NUMBER         := '~p_org_id';
   p_trx_num                      VARCHAR2(240)  := '~p_trx_num';
   p_line_num                     NUMBER         := '~p_line_num';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_line_num = -1 THEN
   p_line_num := NULL;
END IF;
IF p_org_id IS NULL THEN
   p_org_id := mo_global.get_ou_name( nvl( fnd_profile.value('DEFAULT_ORG_ID'), fnd_profile.value('ORG_ID') ) );
END IF;


   po_autocreate_analyzer_pkg.main(
     p_analysis_mode                => 'SINGLE'
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_org_id                       => p_org_id
    ,p_trx_num                      => p_trx_num
    ,p_line_num                     => p_line_num
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;