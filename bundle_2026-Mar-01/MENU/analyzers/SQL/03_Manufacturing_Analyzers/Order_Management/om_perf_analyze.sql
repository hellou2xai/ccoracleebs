REM $Id: om_perf_analyze.sql, 200.15 2026/01/27 21:04:59 cschmehl Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    om_perf_analyze.sql                                                    |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the om_perf_analyzer_pkg.main procedure          |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Order Management Suite Performance Analyzer
REM
REM MENU_START
REM
REM SQL: Run Order Management Suite Performance Analyzer
REM FNDLOAD: Load Order Management Suite Performance Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Order Management Suite Performance Analyzer Help [Doc ID: 2968687.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs om_perf_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Order Management Suite Performance Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "OM Concurrent Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: ONT_TOP
REM PROG_NAME: ONTPERF
REM DEF_REQ_GROUP: OM Concurrent Programs
REM PROG_TEMPLATE: ONTPERFAZ.ldt
REM
REM PROD_SHORT_NAME: ONT
REM CP_FILE: 
REM APP_NAME: Order Management
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM om_perf_analyzer.sql
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
PROMPT Submitting Order Management Suite Performance Analyzer...

PROMPT ===========================================================================
PROMPT Do you want Order Management information included?  (Default=Y) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_ont CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Order Management Information (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Do you want Shipping information included?  (Default=Y) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_wsh CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Shipping Information (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Do you want Advanced Pricing information included?  (Default=Y) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_qp CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Advanced Pricing Information (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Do you want Configurator information included?  (Default=Y) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_cz CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Configurator Information (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Do you want Workflow information included?  (Default=Y) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_wf CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Workflow Information (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Do you want Database information included?  (Default=Y) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_db CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Database Information (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check (Default is Y) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Diagnostic Apps Check (Default is Y): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [100] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '100' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_include_ont                  VARCHAR2(240)  := '~p_include_ont';
   p_include_wsh                  VARCHAR2(240)  := '~p_include_wsh';
   p_include_qp                   VARCHAR2(240)  := '~p_include_qp';
   p_include_cz                   VARCHAR2(240)  := '~p_include_cz';
   p_include_wf                   VARCHAR2(240)  := '~p_include_wf';
   p_include_db                   VARCHAR2(240)  := '~p_include_db';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   om_perf_analyzer_pkg.main(
     p_include_ont                  => upper(p_include_ont)
    ,p_include_wsh                  => upper(p_include_wsh)
    ,p_include_qp                   => upper(p_include_qp)
    ,p_include_cz                   => upper(p_include_cz)
    ,p_include_wf                   => upper(p_include_wf)
    ,p_include_db                   => upper(p_include_db)
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;