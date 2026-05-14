REM $Id: ib_txnerr_analyze.sql, 200.52 2026/01/28 18:06:28 svedula Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ib_txnerr_analyze.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ib_analyzer_pkg.main procedure               |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Install Base Analyzer
REM
REM MENU_START
REM
REM SQL: Run Install Base Analyzer
REM FNDLOAD: Load Install Base Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Install Base Analyzer Help [Doc ID: 1597450.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ib_txnerr_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Install Base Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Installed Base Processors"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: CSI_TOP
REM PROG_NAME: IB_ANALYZER_SQL
REM DEF_REQ_GROUP: Installed Base Processors
REM PROG_TEMPLATE: IBAZ.ldt
REM
REM PROD_SHORT_NAME: CSI
REM CP_FILE: 
REM APP_NAME: Install Base
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ib_txnerr_analyzer.sql
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
PROMPT Submitting Install Base Analyzer...

PROMPT ===========================================================================
PROMPT Please Enter an Inventory Material Transaction ID (Optional) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_mtl_txn_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Material_Transaction_ID (Optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_mtl_txn_id                   NUMBER         := '~p_mtl_txn_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_mtl_txn_id = -1 THEN
   p_mtl_txn_id := NULL;
END IF;

   ib_analyzer_pkg.main(
     p_mtl_txn_id                   => p_mtl_txn_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;