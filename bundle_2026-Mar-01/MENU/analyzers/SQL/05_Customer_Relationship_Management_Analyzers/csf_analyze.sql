REM $Id: csf_analyze.sql, 200.20 2026/01/28 18:12:08 svedula Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    csf_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the csf_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.1 12.2
REM
REM MENU_TITLE: Field Service Analyzer
REM
REM MENU_START
REM
REM SQL: Run Field Service Analyzer
REM FNDLOAD: Load Field Service Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Field Service Analyzer Help [Doc ID: 2246049.1]
REM
REM  Compatible with: [12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs csf_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Field Service Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Service Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: CS_TOP
REM PROG_NAME: CSFAZ
REM DEF_REQ_GROUP: Service Reports
REM PROG_TEMPLATE: CSFAZ.ldt
REM
REM PROD_SHORT_NAME: CS
REM CP_FILE: 
REM APP_NAME: Service
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM csf_analyzer.sql
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
PROMPT Submitting Field Service Analyzer...

PROMPT ===========================================================================
PROMPT Enter Specific Application Id( 513 -  Field Service, 523 - Spares Management ,883 - Mobile Field Service, 698 - Advanced Scheduler). This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_app_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Application: '
PROMPT
PROMPT ===========================================================================
PROMPT Organization This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Organization: '
PROMPT
PROMPT ===========================================================================
PROMPT Resource Number This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_resource_num CHAR   PROMPT 'Enter the Resource Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Task Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_task_number CHAR   PROMPT 'Enter the Task Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Part Requirement Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_req_num NUMBER  DEFAULT '-1' PROMPT 'Enter the Part Requirement Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Item Name 
PROMPT ===========================================================================
PROMPT
ACCEPT p_item_name CHAR   PROMPT 'Enter the Item Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Serial Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_serial_number CHAR   PROMPT 'Enter the Serial Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_app_id                       NUMBER         := '~p_app_id';
   p_org_id                       NUMBER         := '~p_org_id';
   p_resource_num                 VARCHAR2(240)  := '~p_resource_num';
   p_task_number                  VARCHAR2(240)  := '~p_task_number';
   p_req_num                      NUMBER         := '~p_req_num';
   p_item_name                    VARCHAR2(240)  := '~p_item_name';
   p_serial_number                VARCHAR2(240)  := '~p_serial_number';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_app_id = -1 THEN
   p_app_id := NULL;
END IF;
IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;
IF p_req_num = -1 THEN
   p_req_num := NULL;
END IF;

   csf_analyzer_pkg.main(
     p_app_id                       => p_app_id
    ,p_org_id                       => p_org_id
    ,p_resource_num                 => p_resource_num
    ,p_task_number                  => upper(p_task_number)
    ,p_req_num                      => p_req_num
    ,p_item_name                    => upper(p_item_name)
    ,p_serial_number                => upper(p_serial_number)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;