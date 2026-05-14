REM $Id: logistics_pick_release_analyze.sql, 200.29 2026/02/23 18:17:40 jjanaiti Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    logistics_pick_release_analyze.sql                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the logistic_pick_rel_analyzer_pkg.main procedure|
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Logistics Pick Release Analyzer
REM
REM MENU_START
REM
REM SQL: Run Logistics Pick Release Analyzer
REM FNDLOAD: Load Logistics Pick Release Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Logistics Pick Release Analyzer Help [Doc ID: 2349700.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs logistics_pick_release_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Logistics Pick Release Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Inclusive GUI"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: INV_TOP
REM PROG_NAME: LOGISTICSPR
REM DEF_REQ_GROUP: All Inclusive GUI
REM PROG_TEMPLATE: LOGPRAZ.ldt
REM PROG_TEMPLATE_11i: LOGPRAZ_11i.ldt
REM PROD_SHORT_NAME: INV
REM CP_FILE: 
REM APP_NAME: Inventory
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM logistics_pick_release_analyzer.sql
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
PROMPT Submitting Logistics Pick Release Analyzer...

PROMPT ===========================================================================
PROMPT Valid values are WSH (for Shipping or Order Management), LOGISTICS (for Inventory or WMS), or WIP (for Discrete Jobs). This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_diag_type CHAR   PROMPT 'Enter the Diagnostics Type: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Picking Batch ID (Required if Diagnostics Type = WSH) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_batch_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Picking Batch ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Sales Order Header ID (Required if Diagnostics Type = WSH Or LOGISTICS) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_header_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Sales Order Header ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Sales Order Line ID (Required, if Diagnostics Type = LOGISTICS) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_so_line_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Sales Order Line ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Discrete Job ID (Required if Diagnostics Type is WIP) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_wip_entity_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Discrete Job ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Gather and Include Apps Check Information (Y/N) ( Default = N) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_print_appscheck CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Apps Check Information (Y/N): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the debug mode [Y] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_debug_mode CHAR  DEFAULT 'Y' PROMPT 'Enter the Debug Mode: '
PROMPT
PROMPT
DECLARE
   p_diag_type                    VARCHAR2(240)  := '~p_diag_type';
   p_batch_id                     NUMBER         := '~p_batch_id';
   p_header_id                    NUMBER         := '~p_header_id';
   p_so_line_id                   NUMBER         := '~p_so_line_id';
   p_wip_entity_id                NUMBER         := '~p_wip_entity_id';
   p_print_appscheck              VARCHAR2(240)  := '~p_print_appscheck';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';
   p_debug_mode                   VARCHAR2(240)  := '~p_debug_mode';

BEGIN

IF p_batch_id = -1 THEN
   p_batch_id := NULL;
END IF;
IF p_header_id = -1 THEN
   p_header_id := NULL;
END IF;
IF p_so_line_id = -1 THEN
   p_so_line_id := NULL;
END IF;
IF p_wip_entity_id = -1 THEN
   p_wip_entity_id := NULL;
END IF;

   logistic_pick_rel_analyzer_pkg.main(
     p_diag_type                    => upper(p_diag_type)
    ,p_batch_id                     => p_batch_id
    ,p_header_id                    => p_header_id
    ,p_so_line_id                   => p_so_line_id
    ,p_wip_entity_id                => p_wip_entity_id
    ,p_print_appscheck              => upper(p_print_appscheck)
    ,p_max_output_rows              => p_max_output_rows
    ,p_debug_mode                   => p_debug_mode
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;