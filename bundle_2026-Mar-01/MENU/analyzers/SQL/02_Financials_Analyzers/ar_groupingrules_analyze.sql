REM $Id: ar_groupingrules_analyze.sql, 200.38 2026/01/29 15:27:07 mamoreir Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ar_groupingrules_analyze.sql                                           |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ar_groupingrules_analyzer_pkg.main procedure |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Receivables Grouping Rules Analyzer
REM
REM MENU_START
REM
REM SQL: Run Receivables Grouping Rules Analyzer
REM FNDLOAD: Load Receivables Grouping Rules Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Receivables Grouping Rules Analyzer Help [Doc ID: 2073657.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ar_groupingrules_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Receivables Grouping Rules Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: ARGRPANL
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: AR_GRPRULEAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ar_groupingrules_analyzer.sql
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
PROMPT Submitting Receivables Grouping Rules Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Organization ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id CHAR   PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter First Customer Transaction ID, this transaction should belong to the Org ID you provided earlier and must have a non-null BATCH_SOURCE_ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_first_trx_id NUMBER  DEFAULT '-1' PROMPT 'Enter the First Customer Transaction ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Second Customer Transaction ID, this transaction should belong to the Org ID you provided earlier, and should have the same BATCH_SOURCE_ID as First Customer Transaction ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_second_trx_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Second Transaction ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Apps Check: Valid values are Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Apps Check: '
PROMPT
PROMPT
DECLARE
   p_org_id                       VARCHAR2(240)  := '~p_org_id';
   p_first_trx_id                 NUMBER         := '~p_first_trx_id';
   p_second_trx_id                NUMBER         := '~p_second_trx_id';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN

IF p_first_trx_id = -1 THEN
   p_first_trx_id := NULL;
END IF;
IF p_second_trx_id = -1 THEN
   p_second_trx_id := NULL;
END IF;

   ar_groupingrules_analyzer_pkg.main(
     p_org_id                       => p_org_id
    ,p_first_trx_id                 => p_first_trx_id
    ,p_second_trx_id                => p_second_trx_id
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;