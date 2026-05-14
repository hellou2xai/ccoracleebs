REM $Id: clm_analyze.sql, 200.41 2026/01/28 14:41:47 loinonen Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    clm_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the clm_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.2
REM
REM MENU_TITLE: CLM Analyzer
REM
REM MENU_START
REM
REM SQL: Run CLM Analyzer
REM FNDLOAD: Load CLM Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  CLM Analyzer Help [Doc ID: 2398956.1]
REM
REM  Compatible with: [12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs clm_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install CLM Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Purchasing Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PO_TOP
REM PROG_NAME: CLM
REM DEF_REQ_GROUP: Purchasing Reports
REM PROG_TEMPLATE: CLMAZ.ldt
REM
REM PROD_SHORT_NAME: PO
REM CP_FILE: 
REM APP_NAME: Purchasing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM clm_analyzer.sql
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
PROMPT Submitting CLM Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Organization ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Organizaton ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Login name of user running analyzer.  This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_user_name CHAR   PROMPT 'Enter the Enter Login Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Responsibility ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_responsibility_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Enter the Responsibility ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the CLM Requisition Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_req_num CHAR   PROMPT 'Enter the Enter the Requisition Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the CLM Award Number: 
PROMPT ===========================================================================
PROMPT
ACCEPT p_award_num CHAR   PROMPT 'Enter the Enter the CLM Award Number:: '
PROMPT
PROMPT ===========================================================================
PROMPT CLM Solicitation Number: 
PROMPT ===========================================================================
PROMPT
ACCEPT p_sol_num CHAR   PROMPT 'Enter the CLM Solicitation Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Modification Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_mod_num CHAR   PROMPT 'Enter the Enter the complete Modification Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the PAR Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_par_num CHAR   PROMPT 'Enter the Enter the PAR Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the CLM Document Amendment Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_amend_num CHAR   PROMPT 'Enter the Enter the Amendment Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Should GL Data be Included (Y or N) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_gl CHAR  DEFAULT 'Y' PROMPT 'Enter the Should GL Data be Included (Enter Y or N): '
PROMPT
PROMPT ===========================================================================
PROMPT Pull Extrinsic Attribute Data (Y or N) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_pull_ext CHAR  DEFAULT 'N' PROMPT 'Enter the Pull Extrinsic Attribute Data (Y or N): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '200' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check: Valid values are "Y" or "N". This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Diagnostic Apps Check: '
PROMPT
PROMPT
DECLARE
   p_org_id                       NUMBER         := '~p_org_id';
   p_user_name                    VARCHAR2(240)  := '~p_user_name';
   p_responsibility_id            NUMBER         := '~p_responsibility_id';
   p_req_num                      VARCHAR2(240)  := '~p_req_num';
   p_award_num                    VARCHAR2(240)  := '~p_award_num';
   p_sol_num                      VARCHAR2(240)  := '~p_sol_num';
   p_mod_num                      VARCHAR2(240)  := '~p_mod_num';
   p_par_num                      VARCHAR2(240)  := '~p_par_num';
   p_amend_num                    VARCHAR2(240)  := '~p_amend_num';
   p_include_gl                   VARCHAR2(240)  := '~p_include_gl';
   p_pull_ext                     VARCHAR2(240)  := '~p_pull_ext';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';

BEGIN

IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;
IF p_responsibility_id = -1 THEN
   p_responsibility_id := NULL;
END IF;

   clm_analyzer_pkg.main(
     p_org_id                       => p_org_id
    ,p_user_name                    => upper(p_user_name)
    ,p_responsibility_id            => p_responsibility_id
    ,p_req_num                      => p_req_num
    ,p_award_num                    => p_award_num
    ,p_sol_num                      => p_sol_num
    ,p_mod_num                      => p_mod_num
    ,p_par_num                      => p_par_num
    ,p_amend_num                    => p_amend_num
    ,p_include_gl                   => p_include_gl
    ,p_pull_ext                     => p_pull_ext
    ,p_max_output_rows              => p_max_output_rows
    ,p_include_apps_check           => p_include_apps_check
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;