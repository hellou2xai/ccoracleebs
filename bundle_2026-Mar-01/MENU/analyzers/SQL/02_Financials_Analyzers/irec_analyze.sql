REM $Id: irec_analyze.sql, 200.12 2025/12/08 13:51:58 jnieman Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    irec_analyze.sql                                                       |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the irec_analyzer_pkg.main procedure             |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: iReceivables Analyzer
REM
REM MENU_START
REM
REM SQL: Run iReceivables Analyzer
REM FNDLOAD: Load iReceivables Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  iReceivables Analyzer Help [Doc ID: 2652175.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs irec_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install iReceivables Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: IRECANLZ
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: IRECANLZAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM irec_analyzer.sql
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
PROMPT Submitting iReceivables Analyzer...

PROMPT ===========================================================================
PROMPT Enter the User Name used to log into Receivables. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_user_name CHAR   PROMPT 'Enter the User Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Responsibility ID used in Receivables application. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_resp_id NUMBER   PROMPT 'Enter the Responsibility ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Organization ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Apps Check: Valid values are Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Apps Check: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Party ID (PARTY_ID) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_party_id CHAR   PROMPT 'Enter the Party ID: '
PROMPT
PROMPT
DECLARE
   p_user_name                    VARCHAR2(240)  := '~p_user_name';
   p_resp_id                      NUMBER         := '~p_resp_id';
   p_org_id                       NUMBER         := '~p_org_id';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';
   p_party_id                     VARCHAR2(240)  := '~p_party_id';

BEGIN

IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;
IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.user_name;
END IF;

IF p_resp_id IS NULL THEN
   p_resp_id := FND_GLOBAL.RESP_NAME;
END IF;


   irec_analyzer_pkg.main(
     p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_org_id                       => p_org_id
    ,p_apps_check                   => upper(p_apps_check)
    ,p_party_id                     => p_party_id
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;