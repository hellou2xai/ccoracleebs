REM $Id: cn_analyze.sql, 200.2 2025/12/11 12:34:44 vamuruge Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    cn_analyze.sql                                                         |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the cn_analyzer_pkg.main procedure               |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Incentive Compensation Analyzer
REM
REM MENU_START
REM
REM SQL: Run Incentive Compensation Analyzer
REM FNDLOAD: Load Incentive Compensation Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Incentive Compensation Analyzer Help [Doc ID: 3060115.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs cn_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Incentive Compensation Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Compensation Manager Requests"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: CN_TOP
REM PROG_NAME: CN_ANALYZER
REM DEF_REQ_GROUP: Compensation Manager Requests
REM PROG_TEMPLATE: CN_ANALYZERAZ.ldt
REM
REM PROD_SHORT_NAME: CN
REM CP_FILE: 
REM APP_NAME: Incentive Compensation
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM cn_analyzer.sql
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
PROMPT Submitting Incentive Compensation Analyzer...

PROMPT ===========================================================================
PROMPT * Enter Salesrep Id This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_salesrep_id CHAR   PROMPT 'Enter the * Enter Salesrep Id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Period Id (Optional) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_period_id CHAR   PROMPT 'Enter the Enter Period Id (Optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Organization Id (Optional) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Enter Organization Id (Optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Select Section: (All - 1, Open Period - 2, Collection - 3, Calculation - 4, Payment - 5) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_section CHAR  DEFAULT '1' PROMPT 'Enter the Section (Optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_salesrep_id                  VARCHAR2(240)  := '~p_salesrep_id';
   p_period_id                    VARCHAR2(240)  := '~p_period_id';
   p_org_id                       NUMBER         := '~p_org_id';
   p_section                      VARCHAR2(240)  := '~p_section';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;

   cn_analyzer_pkg.main(
     p_salesrep_id                  => p_salesrep_id
    ,p_period_id                    => p_period_id
    ,p_org_id                       => p_org_id
    ,p_section                      => p_section
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;