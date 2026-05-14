REM $Id: isp_setup_analyze.sql, 200.28 2026/01/28 14:56:45 dfelton Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    isp_setup_analyze.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the isp_setup_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Procurement iSupplier Analyzer
REM
REM MENU_START
REM
REM SQL: Run Procurement iSupplier Analyzer
REM FNDLOAD: Load Procurement iSupplier Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Procurement iSupplier Analyzer Help [Doc ID: 2101059.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs isp_setup_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Procurement iSupplier Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PO_TOP
REM PROG_NAME: ISPGS
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: ISPGSAZ.ldt
REM
REM PROD_SHORT_NAME: PO
REM CP_FILE: 
REM APP_NAME: Purchasing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM isp_setup_analyzer.sql
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
PROMPT Submitting Procurement iSupplier Analyzer...

PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check: Valid values are "Y" or "N". This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR   PROMPT 'Enter the Include Diagnostic Apps Check: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the organization id  This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER   PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the supplier type. Valid Values are 'EXISTING' or 'REGISTERED'. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_supplier_type CHAR   PROMPT 'Enter the Supplier Type: '
PROMPT
PROMPT ===========================================================================
PROMPT supplier_id This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_supplier_id NUMBER  DEFAULT '-1' PROMPT 'Enter the supplier_id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_org_id                       NUMBER         := '~p_org_id';
   p_supplier_type                VARCHAR2(240)  := '~p_supplier_type';
   p_supplier_id                  NUMBER         := '~p_supplier_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_supplier_id = -1 THEN
   p_supplier_id := NULL;
END IF;
IF p_org_id IS NULL THEN
   p_org_id := mo_global.get_ou_name( nvl( fnd_profile.value('DEFAULT_ORG_ID'), fnd_profile.value('ORG_ID') ) );
END IF;


   isp_setup_analyzer_pkg.main(
     p_include_apps_check           => upper(p_include_apps_check)
    ,p_org_id                       => p_org_id
    ,p_supplier_type                => upper(nvl(p_supplier_type,'ANY'))
    ,p_supplier_id                  => p_supplier_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;