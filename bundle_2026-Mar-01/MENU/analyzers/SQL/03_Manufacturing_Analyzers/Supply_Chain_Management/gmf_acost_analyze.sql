REM $Id: gmf_acost_analyze.sql, 200.32 2026/01/27 12:34:06 dbuteica Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    gmf_acost_analyze.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the gmf_acost_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: OPM Financials Analyzer
REM
REM MENU_START
REM
REM SQL: Run OPM Financials Analyzer
REM FNDLOAD: Load OPM Financials Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  OPM Financials Analyzer Help [Doc ID: 1629384.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs gmf_acost_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install OPM Financials Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "OPM GMF Request Group"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: GMF_TOP
REM PROG_NAME: GMFACANL
REM DEF_REQ_GROUP: OPM GMF Request Group
REM PROG_TEMPLATE: GMFACANLAZ.ldt
REM
REM PROD_SHORT_NAME: GMF
REM CP_FILE: 
REM APP_NAME: Process Manufacturing Financials
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM gmf_acost_analyzer.sql
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
PROMPT Submitting OPM Financials Analyzer...

PROMPT ===========================================================================
PROMPT Legal Entity ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_legal_entity_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Legal Entity ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_legal_entity_id              NUMBER         := '~p_legal_entity_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_legal_entity_id = -1 THEN
   p_legal_entity_id := NULL;
END IF;

   gmf_acost_analyzer_pkg.main(
     p_legal_entity_id              => p_legal_entity_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;