REM $Id: ap_period_close_analyze.sql, 200.68 2026/02/24 19:53:45 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ap_period_close_analyze.sql                                            |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ap_pclose_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Payables Period Close Analyzer
REM
REM MENU_START
REM
REM SQL: Run Payables Period Close Analyzer
REM FNDLOAD: Load Payables Period Close Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Payables Period Close Analyzer Help [Doc ID: 1489381.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ap_period_close_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Payables Period Close Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Payables Reports Only"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AP_TOP
REM PROG_NAME: APPCLOSEVAL
REM DEF_REQ_GROUP: Payables Reports Only
REM PROG_TEMPLATE: AP_PCLOSEAZ.ldt
REM
REM PROD_SHORT_NAME: SQLAP
REM CP_FILE: 
REM APP_NAME: Payables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ap_period_close_analyzer.sql
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
PROMPT Submitting Payables Period Close Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Ledger ID which you are trying to close. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_ledger_id2 CHAR   PROMPT 'Enter the Ledger ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the period name which you are trying to close. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_per_name2 CHAR   PROMPT 'Enter the Period Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the org_id(s) for the operating unit(s). For multiple operating units, separate with commas.  For all, leave blank. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_ids2 CHAR   PROMPT 'Enter the OU org_id(s): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '500' PROMPT 'Enter the Max Rows per Validation [500]: '
PROMPT
PROMPT
DECLARE
   p_ledger_id2                   VARCHAR2(240)  := '~p_ledger_id2';
   p_per_name2                    VARCHAR2(240)  := '~p_per_name2';
   p_org_ids2                     VARCHAR2(240)  := '~p_org_ids2';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   ap_pclose_analyzer_pkg.main(
     p_ledger_id2                   => p_ledger_id2
    ,p_per_name2                    => p_per_name2
    ,p_org_ids2                     => regexp_replace(p_org_ids2, '[^,0-9]')
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;