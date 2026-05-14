REM $Id: qp_all_analyze.sql, 200.27 2026/01/27 18:46:13 cschmehl Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    qp_all_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the qp_all_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Advanced Pricing Analyzer
REM
REM MENU_START
REM
REM SQL: Run Advanced Pricing Analyzer
REM FNDLOAD: Load Advanced Pricing Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Advanced Pricing Analyzer Help [Doc ID: 2676826.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs qp_all_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Advanced Pricing Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "QP Concurrent Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: QP_TOP
REM PROG_NAME: QPALL
REM DEF_REQ_GROUP: QP Concurrent Programs
REM PROG_TEMPLATE: QPALLAZ.ldt
REM
REM PROD_SHORT_NAME: QP
REM CP_FILE: 
REM APP_NAME: Advanced Pricing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM qp_all_analyzer.sql
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
PROMPT Submitting Advanced Pricing Analyzer...

PROMPT ===========================================================================
PROMPT Include Performance Analysis (Y/N) - Default is Y 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_performance CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Performance Analysis (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Include Pricing Data Analysis (Y/N) - Default is Y 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_data_analysis CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Pricing Data Analysis (YN): '
PROMPT
PROMPT ===========================================================================
PROMPT Include Pricing Security (Y/N) - Default is N 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_security CHAR  DEFAULT 'N' PROMPT 'Enter the Include Pricing Security (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Include QP: Bulk Import of Price List Information (Y/N) - Default is N 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_bulk_loader CHAR  DEFAULT 'N' PROMPT 'Enter the Include QP: Bulk Import of Price List Information (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check (Y/N) - Default is Y 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Diagnostic Apps Check (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_include_performance          VARCHAR2(240)  := '~p_include_performance';
   p_include_data_analysis        VARCHAR2(240)  := '~p_include_data_analysis';
   p_include_security             VARCHAR2(240)  := '~p_include_security';
   p_include_bulk_loader          VARCHAR2(240)  := '~p_include_bulk_loader';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   qp_all_analyzer_pkg.main(
     p_include_performance          => upper(p_include_performance)
    ,p_include_data_analysis        => upper(p_include_data_analysis)
    ,p_include_security             => upper(p_include_security)
    ,p_include_bulk_loader          => upper(p_include_bulk_loader)
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;