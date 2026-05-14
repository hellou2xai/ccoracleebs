REM $Id: csd_analyze.sql, 200.22 2026/01/28 18:00:06 nkanumur Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    csd_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the csd_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.1 12.2
REM
REM MENU_TITLE: Depot Repair Analyzer
REM
REM MENU_START
REM
REM SQL: Run Depot Repair Analyzer
REM FNDLOAD: Load Depot Repair Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Depot Repair Analyzer Help [Doc ID: 2280570.1]
REM
REM  Compatible with: [12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs csd_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Depot Repair Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Depot Repair Program Group"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: CSD_TOP
REM PROG_NAME: CSDANALYZER
REM DEF_REQ_GROUP: Depot Repair Program Group
REM PROG_TEMPLATE: CSDAZ.ldt
REM
REM PROD_SHORT_NAME: CSD
REM CP_FILE: 
REM APP_NAME: Depot Repair
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM csd_analyzer.sql
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
PROMPT Submitting Depot Repair Analyzer...

PROMPT ===========================================================================
PROMPT Repair Number This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_repair_number CHAR   PROMPT 'Enter the Repair Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_repair_number                VARCHAR2(240)  := '~p_repair_number';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   csd_analyzer_pkg.main(
     p_repair_number                => p_repair_number
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;