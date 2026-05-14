REM $Id: iex_analyze.sql, 200.19 2025/12/08 13:34:10 jnieman Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    iex_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the iex_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Advanced Collections Analyzer
REM
REM MENU_START
REM
REM SQL: Run Advanced Collections Analyzer
REM FNDLOAD: Load Advanced Collections Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Advanced Collections Analyzer Help [Doc ID: 2536952.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs iex_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Advanced Collections Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: IEXANLZ
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: IEXANLZAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM iex_analyzer.sql
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
PROMPT Submitting Advanced Collections Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Organization ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Universal Work Queue, enter Y or N This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_uwq CHAR  DEFAULT 'N' PROMPT 'Enter the Include Universal Work Queue: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Dunning Information, enter Y or N This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_dunning CHAR  DEFAULT 'N' PROMPT 'Enter the Include Dunning Information: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Strategy Information, enter Y or N This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_strategy CHAR  DEFAULT 'N' PROMPT 'Enter the Include Strategy Information: '
PROMPT
PROMPT ===========================================================================
PROMPT If you entered 'Y' to any of the 'Include...' parameters above, enter a Party ID (PARTY_ID). This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_party_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Party ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Apps Check: Valid values are Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Apps Check: '
PROMPT
PROMPT
DECLARE
   p_org_id                       NUMBER         := '~p_org_id';
   p_uwq                          VARCHAR2(240)  := '~p_uwq';
   p_dunning                      VARCHAR2(240)  := '~p_dunning';
   p_strategy                     VARCHAR2(240)  := '~p_strategy';
   p_party_id                     NUMBER         := '~p_party_id';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN

IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;
IF p_party_id = -1 THEN
   p_party_id := NULL;
END IF;

   iex_analyzer_pkg.main(
     p_org_id                       => p_org_id
    ,p_uwq                          => upper(p_uwq)
    ,p_dunning                      => upper(p_dunning)
    ,p_strategy                     => upper(p_strategy)
    ,p_party_id                     => p_party_id
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;