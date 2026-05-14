REM $Id: hr_analyze.sql, 200.247 2026/02/27 13:39:09 siionesc Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    hr_analyze.sql                                                         |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the hr_analyzer_pkg.main procedure               |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: HR Technical Analyzer
REM
REM MENU_START
REM
REM SQL: Run HR Technical Analyzer
REM FNDLOAD: Load HR Technical Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  HR Technical Analyzer Help [Doc ID: 1562530]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs hr_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install HR Technical Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Global HRMS Reports & Process"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PER_TOP
REM PROG_NAME: HCM_ANALYZER_SQL
REM DEF_REQ_GROUP: Global HRMS Reports & Process
REM PROG_TEMPLATE: HRTECHNICALAZ.ldt
REM PROG_TEMPLATE_11i: HRTECHNICALAZ_11i.ldt
REM PROD_SHORT_NAME: PER
REM CP_FILE: 
REM APP_NAME: Human Resources
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM hr_analyzer.sql
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
PROMPT Submitting HR Technical Analyzer...

PROMPT
DECLARE

BEGIN


   hr_analyzer_pkg.main(
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;