REM $Id: bom_analyze.sql, 200.20 2026/01/29 16:43:00 rcastro Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    bom_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the bom_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Bills of Material Analyzer
REM
REM MENU_START
REM
REM SQL: Run Bills of Material Analyzer
REM FNDLOAD: Load Bills of Material Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Bills of Material Analyzer Help [Doc ID: 2633472.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs bom_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Bills of Material Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Inclusive GUI"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: INV_TOP
REM PROG_NAME: BOMAZ
REM DEF_REQ_GROUP: All Inclusive GUI
REM PROG_TEMPLATE: BOMAZAZ.ldt
REM PROG_TEMPLATE_11i: BOMAZAZ_11i.ldt
REM PROD_SHORT_NAME: INV
REM CP_FILE: 
REM APP_NAME: Inventory
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM bom_analyzer.sql
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
PROMPT Submitting Bills of Material Analyzer...

PROMPT ===========================================================================
PROMPT Enter the organization code where the bill is defined This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_code CHAR   PROMPT 'Enter the Organization Code: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Assembly Item Number for the bill. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_item_number CHAR   PROMPT 'Enter the Assembly Item Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the batch_id used in the BOM Open Interface. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_batch_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Batch ID (Optional): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the set_process_id used in the Item Open Interface 
PROMPT ===========================================================================
PROMPT
ACCEPT p_set_process_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Set Process ID  (Optional): '
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
   p_item_number                  VARCHAR2(240)  := '~p_item_number';
   p_batch_id                     NUMBER         := '~p_batch_id';
   p_set_process_id               NUMBER         := '~p_set_process_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_batch_id = -1 THEN
   p_batch_id := NULL;
END IF;
IF p_set_process_id = -1 THEN
   p_set_process_id := NULL;
END IF;

   bom_analyzer_pkg.main(
     p_org_code                     => p_org_code
    ,p_item_number                  => p_item_number
    ,p_batch_id                     => p_batch_id
    ,p_set_process_id               => p_set_process_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;