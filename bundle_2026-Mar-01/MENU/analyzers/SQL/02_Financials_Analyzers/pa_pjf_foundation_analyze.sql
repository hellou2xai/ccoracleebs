REM $Id: pa_pjf_foundation_analyze.sql, 200.7 2026/02/25 21:43:44 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    pa_pjf_foundation_analyze.sql                                          |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the pa_pjf_foundation_analyzer_pkg.main procedure|
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Project Foundation Analyzer
REM
REM MENU_START
REM
REM SQL: Run Project Foundation Analyzer
REM FNDLOAD: Load Project Foundation Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Project Foundation Analyzer Help [Doc ID: 3035961.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs pa_pjf_foundation_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Project Foundation Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Projects Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PA_TOP
REM PROG_NAME: PAPJF
REM DEF_REQ_GROUP: All Projects Programs
REM PROG_TEMPLATE: PAPJFAZ.ldt
REM
REM PROD_SHORT_NAME: PA
REM CP_FILE: 
REM APP_NAME: Projects
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM pa_pjf_foundation_analyzer.sql
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
PROMPT Submitting Project Foundation Analyzer...

PROMPT ===========================================================================
PROMPT Enter the org_id for the operating unit. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Org ID: '
PROMPT
PROMPT ===========================================================================
PROMPT To analyze a specific Project, enter the Project ID.  You can obtain the Project ID in SQL using the following query: SELECT project_id FROM pa_projects_all WHERE segment1 = '&project_number'; 
PROMPT ===========================================================================
PROMPT
ACCEPT p_project_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Project ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the User Name used to log into the Projects application. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_user_name CHAR   PROMPT 'Enter the User Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Responsibility ID used in the Projects application. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_resp_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Enter a valid Responsibility ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '250' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_org_id                       NUMBER         := '~p_org_id';
   p_project_id                   NUMBER         := '~p_project_id';
   p_user_name                    VARCHAR2(240)  := '~p_user_name';
   p_resp_id                      NUMBER         := '~p_resp_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;
IF p_project_id = -1 THEN
   p_project_id := NULL;
END IF;
IF p_resp_id = -1 THEN
   p_resp_id := NULL;
END IF;
IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.USER_NAME;
END IF;


   pa_pjf_foundation_analyzer_pkg.main(
     p_org_id                       => p_org_id
    ,p_project_id                   => p_project_id
    ,p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;