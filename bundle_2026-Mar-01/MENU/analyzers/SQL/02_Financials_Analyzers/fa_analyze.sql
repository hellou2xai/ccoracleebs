REM $Id: fa_analyze.sql, 200.82 2026/01/28 13:28:11 irkiss Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    fa_analyze.sql                                                         |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the fa_analyzer_pkg.main procedure               |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Fixed Assets Analyzer
REM
REM MENU_START
REM
REM SQL: Run Fixed Assets Analyzer
REM FNDLOAD: Load Fixed Assets Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Fixed Assets Analyzer Help [Doc ID: 2061234.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs fa_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Fixed Assets Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports and Programs"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: FA_TOP
REM PROG_NAME: FAANALYZER
REM DEF_REQ_GROUP: All Reports and Programs
REM PROG_TEMPLATE: FAANALYZERAZ.ldt
REM
REM PROD_SHORT_NAME: OFA
REM CP_FILE: 
REM APP_NAME: Assets
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM fa_analyzer.sql
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
PROMPT Submitting Fixed Assets Analyzer...

PROMPT ===========================================================================
PROMPT This is your Posting Book This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_posting_book CHAR   PROMPT 'Enter the Posting Book: '
PROMPT
PROMPT ===========================================================================
PROMPT If you want to analyze a specific Asset by book, enter the Asset ID. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_asset_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Asset ID: '
PROMPT
PROMPT ===========================================================================
PROMPT If you want to analyze why a specific AP Invoice is not picked up by Mass Additions Create (APMACR) and transferred to Assets, enter the Invoice ID. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_apinvoice_id NUMBER  DEFAULT '-1' PROMPT 'Enter the AP Invoice ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Start Date (DD-MON-YYYY) from which to begin validating Gaps/Overlaps in Asset Calendars and Prorate Conventions 
PROMPT ===========================================================================
PROMPT
ACCEPT p_start_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the Start Date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the End Date (DD-MON-YYYY) from which to begin validating Gaps/Overlaps in Asset Calendars and Prorate Conventions 
PROMPT ===========================================================================
PROMPT
ACCEPT p_end_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the End Date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [50] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '50' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_posting_book                 VARCHAR2(240)  := '~p_posting_book';
   p_asset_id                     NUMBER         := '~p_asset_id';
   p_apinvoice_id                 NUMBER         := '~p_apinvoice_id';
   p_start_date                   DATE           := to_date('~p_start_date','DD-MON-YYYY');
   p_end_date                     DATE           := to_date('~p_end_date','DD-MON-YYYY');
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_asset_id = -1 THEN
   p_asset_id := NULL;
END IF;
IF p_apinvoice_id = -1 THEN
   p_apinvoice_id := NULL;
END IF;
IF p_start_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_start_date := NULL;
END IF;
IF p_end_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_end_date := NULL;
END IF;

   fa_analyzer_pkg.main(
     p_posting_book                 => upper(p_posting_book)
    ,p_asset_id                     => p_asset_id
    ,p_apinvoice_id                 => p_apinvoice_id
    ,p_start_date                   => p_start_date
    ,p_end_date                     => p_end_date
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;