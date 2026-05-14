REM $Id: po_approval_analyze_all.sql, 200.72 2026/02/12 18:08:48 dfelton Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    po_approval_analyze_all.sql                                            |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the po_apprvl_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Procurement Approval Analyzer - ALL
REM
REM MENU_START
REM
REM SQL: Run Procurement Approval Analyzer - ALL
REM FNDLOAD: Load Procurement Approval Analyzer - ALL as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Procurement Approval Analyzer - ALL Help [Doc ID: 1525670.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs po_approval_analyze_all.sql as APPS user to create an HTML report
REM
REM    (2) Install Procurement Approval Analyzer - ALL as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PO_TOP
REM PROG_NAME: PODIAGAA_A
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: POAPPANALYZERAZ.ldt
REM
REM PROD_SHORT_NAME: PO
REM CP_FILE: 
REM APP_NAME: Purchasing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM po_approval_analyzer.sql
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
PROMPT Submitting Procurement Approval Analyzer...

PROMPT ===========================================================================
PROMPT Enter the org_id for the operating unit. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER   PROMPT 'Enter the org_id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the date from which to begin validating transactions. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_from_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the START DATE [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_org_id                       NUMBER         := '~p_org_id';
   p_from_date                    DATE           := to_date('~p_from_date','DD-MON-YYYY');
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_from_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_from_date := NULL;
END IF;
IF p_org_id IS NULL THEN
   p_org_id := mo_global.get_ou_name( nvl( fnd_profile.value('DEFAULT_ORG_ID'), fnd_profile.value('ORG_ID') ) );
END IF;

IF p_from_date IS NULL THEN
   p_from_date := fnd_date.date_to_displaydate(sysdate -90);
END IF;


   po_apprvl_analyzer_pkg.main(
     p_analysis_mode                => 'ALL'
    ,p_org_id                       => p_org_id
    ,p_from_date                    => p_from_date
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;