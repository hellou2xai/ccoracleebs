REM $Id: ap_sup_analyze.sql, 200.59 2026/02/25 12:18:28 sdenye Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ap_sup_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ap_sup_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Payables Supplier Analyzer
REM
REM MENU_START
REM
REM SQL: Run Payables Supplier Analyzer
REM FNDLOAD: Load Payables Supplier Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Payables Supplier Analyzer Help [Doc ID: 2380650.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ap_sup_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Payables Supplier Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Payables Reports Only"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AP_TOP
REM PROG_NAME: APSUPANLZ
REM DEF_REQ_GROUP: Payables Reports Only
REM PROG_TEMPLATE: APSUPAZ.ldt
REM
REM PROD_SHORT_NAME: SQLAP
REM CP_FILE: 
REM APP_NAME: Payables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ap_sup_analyzer.sql
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
PROMPT Submitting Payables Supplier Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Supplier ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_supplier_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the Supplier ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Supplier Site ID. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_supplier_site_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the Supplier Site ID (optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Merged Supplier ID. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_to_supplier_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the Merged Supplier ID (optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Merged Supplier Site ID. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_to_supplier_site_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the Merged Supplier Site ID (optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check section?  Default value is Y. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Apps Check Information (Y/N): '
PROMPT
PROMPT
DECLARE
   p_supplier_ID                  NUMBER         := '~p_supplier_ID';
   p_supplier_site_ID             NUMBER         := '~p_supplier_site_ID';
   p_to_supplier_ID               NUMBER         := '~p_to_supplier_ID';
   p_to_supplier_site_ID          NUMBER         := '~p_to_supplier_site_ID';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';

BEGIN

IF p_supplier_ID = -1 THEN
   p_supplier_ID := NULL;
END IF;
IF p_supplier_site_ID = -1 THEN
   p_supplier_site_ID := NULL;
END IF;
IF p_to_supplier_ID = -1 THEN
   p_to_supplier_ID := NULL;
END IF;
IF p_to_supplier_site_ID = -1 THEN
   p_to_supplier_site_ID := NULL;
END IF;

   ap_sup_analyzer_pkg.main(
     p_supplier_ID                  => p_supplier_ID
    ,p_supplier_site_ID             => p_supplier_site_ID
    ,p_to_supplier_ID               => p_to_supplier_ID
    ,p_to_supplier_site_ID          => p_to_supplier_site_ID
    ,p_include_apps_check           => trim(upper(p_include_apps_check))
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;