REM $Id: om_agreement_analyze.sql, 200.39 2026/01/28 15:32:26 cschmehl Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    om_agreement_analyze.sql                                               |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the om_agreement_analyzer_pkg.main procedure     |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Sales Agreement Analyzer
REM
REM MENU_START
REM
REM SQL: Run Sales Agreement Analyzer
REM FNDLOAD: Load Sales Agreement Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Sales Agreement Analyzer Help [Doc ID: 2295096.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs om_agreement_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Sales Agreement Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "OM Concurrent Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: ONT_TOP
REM PROG_NAME: ONTBLSO
REM DEF_REQ_GROUP: OM Concurrent Programs
REM PROG_TEMPLATE: ONTBLSOAZ.ldt
REM
REM PROD_SHORT_NAME: ONT
REM CP_FILE: 
REM APP_NAME: Order Management
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM om_agreement_analyzer.sql
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
PROMPT Submitting Sales Agreement Analyzer...

PROMPT ===========================================================================
PROMPT Enter Sales Agreement Header_ID to specify the Sales Agreement to be analyzed This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_header_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Header ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Entering a Line ID is only required when you wish to have output for one order line.  Otherwise all lines on the order will be included in the output. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_line_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Line ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Diagnostic Apps Check (Default is N) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Diagnostic Apps Check (Default is N): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_header_id                    NUMBER         := '~p_header_id';
   p_line_id                      NUMBER         := '~p_line_id';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_header_id = -1 THEN
   p_header_id := NULL;
END IF;
IF p_line_id = -1 THEN
   p_line_id := NULL;
END IF;

   om_agreement_analyzer_pkg.main(
     p_header_id                    => p_header_id
    ,p_line_id                      => p_line_id
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;