REM $Id: ascp_perf_analyze.sql, 200.102 2026/01/28 13:47:23 oracle Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ascp_perf_analyze.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ascp_perf_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: ASCP Performance Analyzer
REM
REM MENU_START
REM
REM SQL: Run ASCP Performance Analyzer
REM FNDLOAD: Load ASCP Performance Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  ASCP Performance Analyzer Help [Doc ID: 1554183.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ascp_perf_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install ASCP Performance Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All MSC Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: MSC_TOP
REM PROG_NAME: MSCAPA_SQL
REM DEF_REQ_GROUP: All MSC Reports
REM PROG_TEMPLATE: ASCP_PERFORMANCEAZ.ldt
REM PROG_TEMPLATE_11i: ASCP_PERFORMANCEAZ_11i.ldt
REM PROD_SHORT_NAME: MSC
REM CP_FILE: 
REM APP_NAME: Advanced Supply Chain Planning
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ascp_perf_analyzer.sql
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
PROMPT Submitting ASCP Performance Analyzer...

PROMPT
DECLARE

BEGIN


   ascp_perf_analyzer_pkg.main(
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;