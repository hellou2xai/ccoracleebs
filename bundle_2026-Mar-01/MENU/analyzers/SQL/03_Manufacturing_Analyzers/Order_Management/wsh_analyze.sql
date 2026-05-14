REM $Id: wsh_analyze.sql, 200.43 2026/01/28 17:18:56 cschmehl Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    wsh_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the wsh_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: WSH Shipping Analyzer
REM
REM MENU_START
REM
REM SQL: Run WSH Shipping Analyzer
REM FNDLOAD: Load WSH Shipping Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  WSH Shipping Analyzer Help [Doc ID: 1947935.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs wsh_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install WSH Shipping Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "OM Concurrent Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: ONT_TOP
REM PROG_NAME: SEWSHANL
REM DEF_REQ_GROUP: OM Concurrent Programs
REM PROG_TEMPLATE: SEWSHANLAZ.ldt
REM
REM PROD_SHORT_NAME: ONT
REM CP_FILE: 
REM APP_NAME: Order Management
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM wsh_analyzer.sql
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
PROMPT Submitting WSH Shipping Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Org (warehouse) Code of Delivery Details This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_code CHAR   PROMPT 'Enter the Org (warehouse) Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the From Date (DD-MON-YYYY) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_from_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the From Date  (DD-MON-YYYY) [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the To Date (DD-MON-YYYY) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_to_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the To Date (DD-MON-YYYY) [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Test trailing spaces Y/N (Default=Y) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_trailing CHAR  DEFAULT 'Y' PROMPT 'Enter the Test trailing spaces: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Apps Check Information (Default=N) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Apps Check Information (Default=N): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_org_code                     VARCHAR2(240)  := '~p_org_code';
   p_from_date                    DATE           := to_date('~p_from_date','DD-MON-YYYY');
   p_to_date                      DATE           := to_date('~p_to_date','DD-MON-YYYY');
   p_trailing                     VARCHAR2(240)  := '~p_trailing';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_from_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_from_date := NULL;
END IF;
IF p_to_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_to_date := NULL;
END IF;
IF p_from_date IS NULL THEN
   p_from_date := sysdate-365;
END IF;

IF p_to_date IS NULL THEN
   p_to_date := sysdate;
END IF;


   wsh_analyzer_pkg.main(
     p_org_code                     => p_org_code
    ,p_from_date                    => to_char(p_from_date,'DD-MON-YYYY') 
    ,p_to_date                      => to_char(p_to_date,'DD-MON-YYYY') 
    ,p_trailing                     => upper(p_trailing)
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;