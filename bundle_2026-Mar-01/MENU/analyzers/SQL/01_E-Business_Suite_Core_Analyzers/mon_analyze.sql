REM $Id: mon_analyze.sql, 200.19 2026/02/25 15:49:06 siionesc Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    mon_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the mon_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Monitoring Analyzer
REM
REM MENU_START
REM
REM SQL: Run Monitoring Analyzer
REM FNDLOAD: Load Monitoring Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Monitoring Analyzer Help [Doc ID: 2886645]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs mon_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Monitoring Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "System Administrator Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: FND_TOP
REM PROG_NAME: MON_ANALYZER_SQL
REM DEF_REQ_GROUP: System Administrator Reports
REM PROG_TEMPLATE: MONAZ.ldt
REM PROG_TEMPLATE_11i: MONAZ_11i.ldt
REM PROD_SHORT_NAME: FND
REM CP_FILE: 
REM APP_NAME: Application Object Library
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM mon_analyzer.sql
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
PROMPT Submitting Monitoring Analyzer...

PROMPT
DECLARE

BEGIN


   mon_analyzer_pkg.main(
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;