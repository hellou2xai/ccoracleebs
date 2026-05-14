REM $Id: pa_pjc_p2p_analyze.sql, 200.28 2026/02/25 21:47:02 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    pa_pjc_p2p_analyze.sql                                                 |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the pa_pjc_p2p_analyzer_pkg.main procedure       |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Projects Procure to Pay Integration Analyzer
REM
REM MENU_START
REM
REM SQL: Run Projects Procure to Pay Integration Analyzer
REM FNDLOAD: Load Projects Procure to Pay Integration Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Projects Procure to Pay Integration Analyzer Help [Doc ID: 2596062.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs pa_pjc_p2p_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Projects Procure to Pay Integration Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Project Costing Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PA_TOP
REM PROG_NAME: PAPJCP2P
REM DEF_REQ_GROUP: All Project Costing Programs
REM PROG_TEMPLATE: PAP2PAZ.ldt
REM
REM PROD_SHORT_NAME: PA
REM CP_FILE: 
REM APP_NAME: Projects
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM pa_pjc_p2p_analyzer.sql
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
PROMPT Submitting Projects Procure to Pay Integration Analyzer...

PROMPT ===========================================================================
PROMPT Please enter the Project ID for which data needs to be collected This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_project_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Project ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Invoice ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_invoice_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Invoice ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Purchase Order Header ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_po_header_id NUMBER  DEFAULT '-1' PROMPT 'Enter the PO Header ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_project_id                   NUMBER         := '~p_project_id';
   p_invoice_id                   NUMBER         := '~p_invoice_id';
   p_po_header_id                 NUMBER         := '~p_po_header_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_project_id = -1 THEN
   p_project_id := NULL;
END IF;
IF p_invoice_id = -1 THEN
   p_invoice_id := NULL;
END IF;
IF p_po_header_id = -1 THEN
   p_po_header_id := NULL;
END IF;

   pa_pjc_p2p_analyzer_pkg.main(
     p_project_id                   => p_project_id
    ,p_invoice_id                   => p_invoice_id
    ,p_po_header_id                 => p_po_header_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;