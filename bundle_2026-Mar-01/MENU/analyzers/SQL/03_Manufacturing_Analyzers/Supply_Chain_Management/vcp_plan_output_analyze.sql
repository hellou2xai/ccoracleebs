REM $Id: vcp_plan_output_analyze.sql, 200.92 2026/01/28 14:17:06 oracle Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    vcp_plan_output_analyze.sql                                            |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the vcp_plan_output_analyzer_pkg.main procedure  |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: VCP Planning Output Setup Analyzer
REM
REM MENU_START
REM
REM SQL: Run VCP Planning Output Setup Analyzer
REM FNDLOAD: Load VCP Planning Output Setup Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  VCP Planning Output Setup Analyzer Help [Doc ID: 2315022.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs vcp_plan_output_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install VCP Planning Output Setup Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All MSC Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: MSC_TOP
REM PROG_NAME: VCP_PLAN_OUTPUT_ANALYZER_SQL
REM DEF_REQ_GROUP: All MSC Reports
REM PROG_TEMPLATE: VCP_PLAN_OUTPUTAZ.ldt
REM PROG_TEMPLATE_11i: VCP_PLAN_OUTPUTAZ_11i.ldt
REM PROD_SHORT_NAME: MSC
REM CP_FILE: 
REM APP_NAME: Advanced Supply Chain Planning
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM vcp_plan_output_analyzer.sql
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
PROMPT Submitting VCP Planning Output Setup Analyzer...

PROMPT ===========================================================================
PROMPT Provide an Instance Code from msc_apps_instances.instance_code (Press Enter to skip if you use MRP ONLY) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_instance_code CHAR   PROMPT 'Enter the Instance Code from msc_apps_instances.instance_code (Press Enter - MRP only): '
PROMPT
PROMPT
DECLARE
   p_instance_code                VARCHAR2(240)  := '~p_instance_code';

BEGIN


   vcp_plan_output_analyzer_pkg.main(
     p_instance_code                => upper(p_instance_code)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;