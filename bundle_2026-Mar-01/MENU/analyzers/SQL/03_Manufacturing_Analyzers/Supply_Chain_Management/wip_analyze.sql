REM $Id: wip_analyze.sql, 200.6 2026/01/28 13:12:47 dbuteica Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    wip_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the wip_conf_analyzer_pkg.main procedure         |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Work in Process (WIP) Analyzer
REM
REM MENU_START
REM
REM SQL: Run Work in Process (WIP) Analyzer
REM FNDLOAD: Load Work in Process (WIP) Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Work in Process (WIP) Analyzer Help [Doc ID: 2931244.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs wip_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Work in Process (WIP) Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: MFG_TOP
REM PROG_NAME: WIP_CONF
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: WIP_CONFAZ.ldt
REM
REM PROD_SHORT_NAME: MFG
REM CP_FILE: 
REM APP_NAME: Manufacturing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM wip_analyzer.sql
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
PROMPT Submitting Work in Process (WIP) Analyzer...

PROMPT ===========================================================================
PROMPT Optionally, enter the Discrete Job Number (Work Order Number). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_Job_Number CHAR   PROMPT 'Enter the Discrete Job Number (Work Order Number): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [500] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '500' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_Job_Number                   VARCHAR2(240)  := '~p_Job_Number';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   wip_conf_analyzer_pkg.main(
     p_Job_Number                   => p_Job_Number
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;