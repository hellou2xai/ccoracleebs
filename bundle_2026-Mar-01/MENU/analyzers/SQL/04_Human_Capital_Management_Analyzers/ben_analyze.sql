REM $Id: ben_analyze.sql, 200.99 2026/01/29 08:03:22 siionesc Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ben_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ben_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Benefits Analyzer
REM
REM MENU_START
REM
REM SQL: Run Benefits Analyzer
REM FNDLOAD: Load Benefits Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Benefits Analyzer Help [Doc ID: 2025944.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ben_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Benefits Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Global HRMS Reports & Process"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: BEN_TOP
REM PROG_NAME: BENAZ
REM DEF_REQ_GROUP: Global HRMS Reports & Process
REM PROG_TEMPLATE: BENAZ.ldt
REM PROG_TEMPLATE_11i: BENAZ_11i.ldt
REM PROD_SHORT_NAME: BEN
REM CP_FILE: 
REM APP_NAME: Human Resources
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ben_analyzer.sql
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
PROMPT Submitting Benefits Analyzer...

PROMPT ===========================================================================
PROMPT Enter the person_id. This parameter is required  This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_person_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Enter the person_id: '
PROMPT
PROMPT
DECLARE
   p_person_id                    NUMBER         := '~p_person_id';

BEGIN

IF p_person_id = -1 THEN
   p_person_id := NULL;
END IF;

   ben_analyzer_pkg.main(
     p_person_id                    => p_person_id
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;