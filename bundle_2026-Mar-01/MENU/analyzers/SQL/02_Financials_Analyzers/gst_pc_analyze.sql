REM $Id: gst_pc_analyze.sql, 200.11 2026/01/27 09:47:36 saananth Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    gst_pc_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the gst_pc_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: GST Period Close Analyzer
REM
REM MENU_START
REM
REM SQL: Run GST Period Close Analyzer
REM FNDLOAD: Load GST Period Close Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  GST Period Close Analyzer Help [Doc ID: 2611916.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs gst_pc_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install GST Period Close Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "JAI_Purchasing_RG"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: JA_TOP
REM PROG_NAME: GSTPC
REM DEF_REQ_GROUP: JAI_Purchasing_RG
REM PROG_TEMPLATE: GSTPCAZ.ldt
REM
REM PROD_SHORT_NAME: JA
REM CP_FILE: 
REM APP_NAME: Asia/Pacific Localizations
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM gst_pc_analyzer.sql
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
PROMPT Submitting GST Period Close Analyzer...

PROMPT ===========================================================================
PROMPT Operating Unit This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Operating Unit: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Period Name This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_per_name CHAR   PROMPT 'Enter the Enter Period Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Inventory Organization ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_organization_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Inventory Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Reconciliation Report ( Yes or No) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_recon_report CHAR   PROMPT 'Enter the Include Reconciliation Report ( Yes or No): '
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
   p_per_name                     VARCHAR2(240)  := '~p_per_name';
   p_organization_id              NUMBER         := '~p_organization_id';
   p_recon_report                 VARCHAR2(240)  := '~p_recon_report';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;
IF p_organization_id = -1 THEN
   p_organization_id := NULL;
END IF;

   gst_pc_analyzer_pkg.main(
     p_org_id                       => p_org_id
    ,p_per_name                     => p_per_name
    ,p_organization_id              => p_organization_id
    ,p_recon_report                 => p_recon_report
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;