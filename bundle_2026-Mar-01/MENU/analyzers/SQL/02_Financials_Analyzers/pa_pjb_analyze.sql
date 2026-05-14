REM $Id: pa_pjb_analyze.sql, 200.28 2026/02/25 21:48:04 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    pa_pjb_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the pa_pjb_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Projects Revenue and Billing Analyzer
REM
REM MENU_START
REM
REM SQL: Run Projects Revenue and Billing Analyzer
REM FNDLOAD: Load Projects Revenue and Billing Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Projects Revenue and Billing Analyzer Help [Doc ID: 2778912.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs pa_pjb_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Projects Revenue and Billing Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Projects Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PA_TOP
REM PROG_NAME: PAPJB
REM DEF_REQ_GROUP: All Projects Programs
REM PROG_TEMPLATE: PAPJBAZ.ldt
REM
REM PROD_SHORT_NAME: PA
REM CP_FILE: 
REM APP_NAME: Projects
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM pa_pjb_analyzer.sql
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
PROMPT Submitting Projects Revenue and Billing Analyzer...

PROMPT ===========================================================================
PROMPT Please enter the Project ID for which data needs to be collected This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_project_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Project ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Please enter the Draft Invoice Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_draft_invoice_num NUMBER  DEFAULT '-1' PROMPT 'Enter the Draft Invoice Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Please enter the Draft Revenue Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_draft_revenue_num NUMBER  DEFAULT '-1' PROMPT 'Enter the Draft Revenue Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Please enter the Expenditure Item ID if exists 
PROMPT ===========================================================================
PROMPT
ACCEPT p_expenditure_item_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Expenditure Item ID: '
PROMPT
PROMPT ===========================================================================
PROMPT If you want to analyze a specific event ID for the project, enter the event ID. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_event_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Event ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [100] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '100' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_project_id                   NUMBER         := '~p_project_id';
   p_draft_invoice_num            NUMBER         := '~p_draft_invoice_num';
   p_draft_revenue_num            NUMBER         := '~p_draft_revenue_num';
   p_expenditure_item_id          NUMBER         := '~p_expenditure_item_id';
   p_event_id                     NUMBER         := '~p_event_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_project_id = -1 THEN
   p_project_id := NULL;
END IF;
IF p_draft_invoice_num = -1 THEN
   p_draft_invoice_num := NULL;
END IF;
IF p_draft_revenue_num = -1 THEN
   p_draft_revenue_num := NULL;
END IF;
IF p_expenditure_item_id = -1 THEN
   p_expenditure_item_id := NULL;
END IF;
IF p_event_id = -1 THEN
   p_event_id := NULL;
END IF;

   pa_pjb_analyzer_pkg.main(
     p_project_id                   => p_project_id
    ,p_draft_invoice_num            => p_draft_invoice_num
    ,p_draft_revenue_num            => p_draft_revenue_num
    ,p_expenditure_item_id          => p_expenditure_item_id
    ,p_event_id                     => p_event_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;