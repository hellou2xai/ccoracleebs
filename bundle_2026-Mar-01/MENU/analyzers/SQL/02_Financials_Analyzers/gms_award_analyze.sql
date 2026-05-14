REM $Id: gms_award_analyze.sql, 200.21 2026/02/25 21:42:38 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    gms_award_analyze.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the gms_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Grants Award Analyzer
REM
REM MENU_START
REM
REM SQL: Run Grants Award Analyzer
REM FNDLOAD: Load Grants Award Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Grants Award Analyzer Help [Doc ID: 2627952.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs gms_award_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Grants Award Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Grants Accounting Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: GMS_TOP
REM PROG_NAME: GMSANL
REM DEF_REQ_GROUP: All Grants Accounting Programs
REM PROG_TEMPLATE: GRANTS_AWARDAZ.ldt
REM
REM PROD_SHORT_NAME: GMS
REM CP_FILE: 
REM APP_NAME: Grants Accounting
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM gms_award_analyzer.sql
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
PROMPT Submitting Grants Award Analyzer...

PROMPT ===========================================================================
PROMPT Award ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_award_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Award_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '100' PROMPT 'Enter the Maximum Rows to Display [20]: '
PROMPT
PROMPT
DECLARE
   p_award_id                     NUMBER         := '~p_award_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_award_id = -1 THEN
   p_award_id := NULL;
END IF;

   gms_analyzer_pkg.main(
     p_award_id                     => p_award_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;