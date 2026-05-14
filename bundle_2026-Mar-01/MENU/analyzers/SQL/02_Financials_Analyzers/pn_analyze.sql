REM $Id: pn_analyze.sql, 200.46 2026/01/28 13:15:49 monikgup Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    pn_analyze.sql                                                         |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the pn_analyzer_pkg.main procedure               |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.1 12.2
REM
REM MENU_TITLE: Property Manager Analyzer
REM
REM MENU_START
REM
REM SQL: Run Property Manager Analyzer
REM FNDLOAD: Load Property Manager Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Property Manager Analyzer Help [Doc ID: 2365436.1]
REM
REM  Compatible with: [12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs pn_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Property Manager Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "PN_ALL_REPORTS"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PN_TOP
REM PROG_NAME: PNANL
REM DEF_REQ_GROUP: PN_ALL_REPORTS
REM PROG_TEMPLATE: PNANALYZERAZ.ldt
REM
REM PROD_SHORT_NAME: PN
REM CP_FILE: 
REM APP_NAME: Property Manager
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM pn_analyzer.sql
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
PROMPT Submitting Property Manager Analyzer...

PROMPT ===========================================================================
PROMPT Org ID for the Operating Unit. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id CHAR   PROMPT 'Enter the ORG_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Lease Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_lease_num CHAR   PROMPT 'Enter the LEASE_NUM: '
PROMPT
PROMPT ===========================================================================
PROMPT VARIABLE RENT ID 
PROMPT ===========================================================================
PROMPT
ACCEPT P_VAR_RENT_ID CHAR   PROMPT 'Enter the VAR_RENT_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Equipment Lease Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_equipment_lease_num CHAR   PROMPT 'Enter the EQP_LEASE_NUM: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_org_id                       VARCHAR2(240)  := '~p_org_id';
   p_lease_num                    VARCHAR2(240)  := '~p_lease_num';
   P_VAR_RENT_ID                  VARCHAR2(240)  := '~P_VAR_RENT_ID';
   p_equipment_lease_num          VARCHAR2(240)  := '~p_equipment_lease_num';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   pn_analyzer_pkg.main(
     p_org_id                       => p_org_id
    ,p_lease_num                    => p_lease_num
    ,P_VAR_RENT_ID                  => P_VAR_RENT_ID
    ,p_equipment_lease_num          => p_equipment_lease_num
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;