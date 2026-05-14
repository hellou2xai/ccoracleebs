REM $Id: ar_tca_analyze.sql, 200.36 2025/12/08 13:51:42 iuflorea Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ar_tca_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ar_tca_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Trading Community Architecture Analyzer
REM
REM MENU_START
REM
REM SQL: Run Trading Community Architecture Analyzer
REM FNDLOAD: Load Trading Community Architecture Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Trading Community Architecture Analyzer Help [Doc ID: 2107726.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ar_tca_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Trading Community Architecture Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: TCAANALYZR
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: TCAAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ar_tca_analyzer.sql
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
PROMPT Submitting Trading Community Architecture Analyzer...

PROMPT ===========================================================================
PROMPT Enter Party ID (PARTY_ID). This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_party_id CHAR   PROMPT 'Enter the Party ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Party Information, enter Y or N. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_party CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Party Information: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Data Quality Management Y or N 
PROMPT ===========================================================================
PROMPT
ACCEPT p_dqm CHAR  DEFAULT 'N' PROMPT 'Enter the Include Data Quality Management: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Geography Information Y or N. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_geographies CHAR  DEFAULT 'N' PROMPT 'Enter the Include Geography Information: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter a valid Country Code. This value will be used if the parameter 'Include Geography Information' is Y.  
PROMPT ===========================================================================
PROMPT
ACCEPT p_country_code CHAR   PROMPT 'Enter the Enter Country Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Business Event Tracking, enter Y or N 
PROMPT ===========================================================================
PROMPT
ACCEPT p_business CHAR  DEFAULT 'N' PROMPT 'Enter the Include Business Event Tracking: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Data Integrity, enter Y or N. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_data_integrity CHAR  DEFAULT 'N' PROMPT 'Enter the Include Data Integrity: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Apps Check: Valid values are Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Apps Check: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Data Integrity For This Party, enter Y or N. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_data_integrity_party CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Data Integrity For This Party: '
PROMPT
PROMPT
DECLARE
   p_party_id                     VARCHAR2(240)  := '~p_party_id';
   p_party                        VARCHAR2(240)  := '~p_party';
   p_dqm                          VARCHAR2(240)  := '~p_dqm';
   p_geographies                  VARCHAR2(240)  := '~p_geographies';
   p_country_code                 VARCHAR2(240)  := '~p_country_code';
   p_business                     VARCHAR2(240)  := '~p_business';
   p_data_integrity               VARCHAR2(240)  := '~p_data_integrity';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';
   p_data_integrity_party         VARCHAR2(240)  := '~p_data_integrity_party';

BEGIN


   ar_tca_analyzer_pkg.main(
     p_party_id                     => p_party_id
    ,p_party                        => upper(p_party)
    ,p_dqm                          => upper(p_dqm)
    ,p_geographies                  => upper(p_geographies)
    ,p_country_code                 => upper(p_country_code)
    ,p_business                     => upper(p_business)
    ,p_data_integrity               => upper(p_data_integrity)
    ,p_apps_check                   => upper(p_apps_check)
    ,p_data_integrity_party         => p_data_integrity_party
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;