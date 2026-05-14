REM $Id: ocm_analyze.sql, 200.11 2025/12/08 13:34:27 jnieman Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ocm_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ocm_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Credit Management Analyzer
REM
REM MENU_START
REM
REM SQL: Run Credit Management Analyzer
REM FNDLOAD: Load Credit Management Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Credit Management Analyzer Help [Doc ID: 2587061.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ocm_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Credit Management Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: OCMANLZ
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: OCM_ANLZAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ocm_analyzer.sql
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
PROMPT Submitting Credit Management Analyzer...

PROMPT ===========================================================================
PROMPT Enter Case Folder Number (leave this NULL if you have an Application Number) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_case_folder_number CHAR   PROMPT 'Enter the Case Folder Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Provide Application Number only if you do not have a case folder number. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_application_number CHAR   PROMPT 'Enter the Application Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Apps Check: Valid values are Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Apps Check: '
PROMPT
PROMPT
DECLARE
   p_case_folder_number           VARCHAR2(240)  := '~p_case_folder_number';
   p_application_number           VARCHAR2(240)  := '~p_application_number';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN


   ocm_analyzer_pkg.main(
     p_case_folder_number           => p_case_folder_number
    ,p_application_number           => p_application_number
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;