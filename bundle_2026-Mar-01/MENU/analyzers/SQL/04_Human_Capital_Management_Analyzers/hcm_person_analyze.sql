REM $Id: hcm_person_analyze.sql, 200.106 2026/01/29 08:06:32 siionesc Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    hcm_person_analyze.sql                                                 |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the hcm_person_analyzer_pkg.main procedure       |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: HCM Person Analyzer
REM
REM MENU_START
REM
REM SQL: Run HCM Person Analyzer
REM FNDLOAD: Load HCM Person Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  HCM Person Analyzer Help [Doc ID: 1675487.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs hcm_person_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install HCM Person Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Global HRMS Reports & Process"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PER_TOP
REM PROG_NAME: PERSON_ANALYZER_SQL
REM DEF_REQ_GROUP: Global HRMS Reports & Process
REM PROG_TEMPLATE: PERSONAZ.ldt
REM PROG_TEMPLATE_11i: PERSONAZ_11i.ldt
REM PROD_SHORT_NAME: PER
REM CP_FILE: 
REM APP_NAME: Human Resources
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM hcm_person_analyzer.sql
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
PROMPT Submitting HCM Person Analyzer...

PROMPT ===========================================================================
PROMPT Enter the person_id(required) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT l_person_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Enter the person_id(required): '
PROMPT
PROMPT
DECLARE
   l_person_id                    NUMBER         := '~l_person_id';

BEGIN

IF l_person_id = -1 THEN
   l_person_id := NULL;
END IF;

   hcm_person_analyzer_pkg.main(
     l_person_id                    => l_person_id
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;