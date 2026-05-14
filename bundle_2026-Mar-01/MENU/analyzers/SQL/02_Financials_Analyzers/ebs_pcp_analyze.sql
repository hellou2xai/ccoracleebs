REM $Id: ebs_pcp_analyze.sql, 200.22 2025/12/08 13:35:26 kobeid Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ebs_pcp_analyze.sql                                                    |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ebs_pcp_analyzer_pkg.main procedure          |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: EBS Period Close Process Analyzer
REM
REM MENU_START
REM
REM SQL: Run EBS Period Close Process Analyzer
REM FNDLOAD: Load EBS Period Close Process Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  EBS Period Close Process Analyzer Help [Doc ID: 2468739.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ebs_pcp_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install EBS Period Close Process Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "GL Concurrent Program Group"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: GL_TOP
REM PROG_NAME: EBSPCPANLZ
REM DEF_REQ_GROUP: GL Concurrent Program Group
REM PROG_TEMPLATE: EBS_PCP_ANALYZERAZ.ldt
REM
REM PROD_SHORT_NAME: SQLGL
REM CP_FILE: 
REM APP_NAME: General Ledger
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ebs_pcp_analyzer.sql
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
PROMPT Submitting EBS Period Close Process Analyzer...

PROMPT ===========================================================================
PROMPT Enter Ledger ID (LEDGER_ID). This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_ledger_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Ledger ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the GL Period Name of the period you are currently processing/analyzing. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_period_name CHAR   PROMPT 'Enter the GL Period Name: '
PROMPT
PROMPT
DECLARE
   p_ledger_id                    NUMBER         := '~p_ledger_id';
   p_period_name                  VARCHAR2(240)  := '~p_period_name';

BEGIN

IF p_ledger_id = -1 THEN
   p_ledger_id := NULL;
END IF;

   ebs_pcp_analyzer_pkg.main(
     p_ledger_id                    => p_ledger_id
    ,p_period_name                  => p_period_name
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;