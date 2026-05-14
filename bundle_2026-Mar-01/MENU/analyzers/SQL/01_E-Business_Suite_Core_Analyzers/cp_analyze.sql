REM $Id: cp_analyze.sql, 200.125 2026/02/23 20:12:09 bburbage Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    cp_analyze.sql                                                         |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the fnd_cp_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Concurrent Processing Analyzer
REM
REM MENU_START
REM
REM SQL: Run Concurrent Processing Analyzer
REM FNDLOAD: Load Concurrent Processing Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Concurrent Processing Analyzer Help [Doc ID: 1411723.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs cp_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Concurrent Processing Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "System Administrator Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: FND_TOP
REM PROG_NAME: CP_ANALYZER_SQL
REM DEF_REQ_GROUP: System Administrator Reports
REM PROG_TEMPLATE: CPAZ.ldt
REM PROG_TEMPLATE_11i: CPAZ_11i.ldt
REM PROD_SHORT_NAME: FND
REM CP_FILE: 
REM APP_NAME: Application Object Library
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM cp_analyzer.sql
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
PROMPT Submitting Concurrent Processing Analyzer...

PROMPT ===========================================================================
PROMPT (Optional) Minimum acceptable volume of closed runtime FND_CONCURRENT_REQUEST data 
PROMPT ===========================================================================
PROMPT
ACCEPT p_min_volume NUMBER  DEFAULT '3500' PROMPT 'Enter the Minimum acceptable volume of FND_CONCURRENT_REQUEST data (3500): '
PROMPT
PROMPT ===========================================================================
PROMPT (Optional) Maximum acceptable volume of closed runtime FND_CONCURRENT_REQUEST data 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_volume NUMBER  DEFAULT '5000' PROMPT 'Enter the Maximum acceptable volume of FND_CONCURRENT_REQUEST data (5000): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '30' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_min_volume                   NUMBER         := '~p_min_volume';
   p_max_volume                   NUMBER         := '~p_max_volume';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   fnd_cp_analyzer_pkg.main(
     p_min_volume                   => p_min_volume
    ,p_max_volume                   => p_max_volume
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;