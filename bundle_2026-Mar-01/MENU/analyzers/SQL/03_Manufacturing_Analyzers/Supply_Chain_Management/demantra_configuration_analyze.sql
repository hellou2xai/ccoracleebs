REM $Id: demantra_configuration_analyze.sql, 200.82 2026/01/28 14:33:31 oracle Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    demantra_configuration_analyze.sql                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the dm_demantra_analyzer_pkg.main procedure      |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Demantra Configuration Analyzer
REM
REM MENU_START
REM
REM SQL: Run Demantra Configuration Analyzer
REM FNDLOAD: Load Demantra Configuration Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Demantra Configuration Analyzer Help [Doc ID: 1618885.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs demantra_configuration_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Demantra Configuration Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Demand Planning"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: MSD_TOP
REM PROG_NAME: MSCDPA_SQL
REM DEF_REQ_GROUP: Demand Planning
REM PROG_TEMPLATE: MSCDPA_SQLAZ.ldt
REM PROG_TEMPLATE_11i: MSCDPA_SQLAZ_11i.ldt
REM PROD_SHORT_NAME: MSD
REM CP_FILE: 
REM APP_NAME: Demand Planning
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM demantra_configuration_analyzer.sql
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
PROMPT Submitting Demantra Configuration Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Demantra Schema Owner: This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_schema_owner CHAR   PROMPT 'Enter the Demantra Schema Owner: '
PROMPT
PROMPT ===========================================================================
PROMPT Number of Middle Tier CPUs installed. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_middle_tier_cpu NUMBER  DEFAULT '1' PROMPT 'Enter the Middle Tier CPUs: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '50' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_schema_owner                 VARCHAR2(240)  := '~p_schema_owner';
   p_middle_tier_cpu              NUMBER         := '~p_middle_tier_cpu';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   dm_demantra_analyzer_pkg.main(
     p_schema_owner                 => upper(p_schema_owner)
    ,p_middle_tier_cpu              => p_middle_tier_cpu
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;