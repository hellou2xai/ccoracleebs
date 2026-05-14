REM $Id: iby_fc_analyze.sql, 200.40 2026/01/28 16:41:17 palfonso Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    iby_fc_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the iby_fc_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Payments (IBY) Funds Capture Analyzer
REM
REM MENU_START
REM
REM SQL: Run Payments (IBY) Funds Capture Analyzer
REM FNDLOAD: Load Payments (IBY) Funds Capture Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Payments (IBY) Funds Capture Analyzer Help [Doc ID: 1602845.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs iby_fc_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Payments (IBY) Funds Capture Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "IBY_SCHED_GROUP"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: IBY_TOP
REM PROG_NAME: IBYANL
REM DEF_REQ_GROUP: IBY_SCHED_GROUP
REM PROG_TEMPLATE: IBYFCAZ.ldt
REM
REM PROD_SHORT_NAME: IBY
REM CP_FILE: 
REM APP_NAME: Payments
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM iby_fc_analyzer.sql
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
PROMPT Submitting Payments (IBY) Funds Capture Analyzer...

PROMPT ===========================================================================
PROMPT Payment System Name. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_bep_suffix CHAR   PROMPT 'Enter the Payment System Suffix: '
PROMPT
PROMPT ===========================================================================
PROMPT If you wish to analyze a specific Settlement batch 
PROMPT ===========================================================================
PROMPT
ACCEPT p_batch_id CHAR   PROMPT 'Enter the Settlement Batch ID: '
PROMPT
PROMPT ===========================================================================
PROMPT If you wish to analyze a specific payment transaction 
PROMPT ===========================================================================
PROMPT
ACCEPT p_tangibleid CHAR   PROMPT 'Enter the Enter Tangibleid (PSON): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [50] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '100' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_bep_suffix                   VARCHAR2(240)  := '~p_bep_suffix';
   p_batch_id                     VARCHAR2(240)  := '~p_batch_id';
   p_tangibleid                   VARCHAR2(240)  := '~p_tangibleid';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN


   iby_fc_analyzer_pkg.main(
     p_bep_suffix                   => p_bep_suffix
    ,p_batch_id                     => p_batch_id
    ,p_tangibleid                   => p_tangibleid
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;