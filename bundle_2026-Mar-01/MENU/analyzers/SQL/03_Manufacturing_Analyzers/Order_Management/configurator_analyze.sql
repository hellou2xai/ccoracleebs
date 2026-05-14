REM $Id: configurator_analyze.sql, 200.31 2026/01/27 20:44:36 cschmehl Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    configurator_analyze.sql                                               |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the cz_analyzer_pkg.main procedure               |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.1 12.2
REM
REM MENU_TITLE: Configurator Analyzer
REM
REM MENU_START
REM
REM SQL: Run Configurator Analyzer
REM FNDLOAD: Load Configurator Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Configurator Analyzer Help [Doc ID: 2255449.1]
REM
REM  Compatible with: [12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs configurator_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Configurator Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "CZ_CONC_GROUPS"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: CZ_TOP
REM PROG_NAME: CZCP
REM DEF_REQ_GROUP: CZ_CONC_GROUPS
REM PROG_TEMPLATE: CZAZ.ldt
REM
REM PROD_SHORT_NAME: CZ
REM CP_FILE: 
REM APP_NAME: Configurator
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM configurator_analyzer.sql
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
PROMPT Submitting Configurator Analyzer...

PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check (Default is Y) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Diagnostic Apps Check (Default is Y): '
PROMPT
PROMPT
DECLARE
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';

BEGIN


   cz_analyzer_pkg.main(
     p_include_apps_check           => upper(p_include_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;