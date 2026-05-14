REM $Id: qot_analyze.sql, 200.32 2026/01/28 17:18:53 svedula Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    qot_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the qot_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Quoting Analyzer
REM
REM MENU_START
REM
REM SQL: Run Quoting Analyzer
REM FNDLOAD: Load Quoting Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Quoting Analyzer Help [Doc ID: 2315991.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs qot_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Quoting Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Order Capture Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: ASO_TOP
REM PROG_NAME: QOTANALYZER
REM DEF_REQ_GROUP: Order Capture Reports
REM PROG_TEMPLATE: QOTANALYZERAZ.ldt
REM
REM PROD_SHORT_NAME: ASO
REM CP_FILE: 
REM APP_NAME: Order Capture
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM qot_analyzer.sql
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
PROMPT Submitting Quoting Analyzer...

PROMPT ===========================================================================
PROMPT If there is a Quote Number involved please enter. 
PROMPT ===========================================================================
PROMPT
ACCEPT QUOTE_NUMBER NUMBER  DEFAULT '-1' PROMPT 'Enter the Quote Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Inventory item description for a item not returned in Quoting search. 
PROMPT ===========================================================================
PROMPT
ACCEPT ITEM_DESCRIPTION CHAR   PROMPT 'Enter the Inventory item description: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   QUOTE_NUMBER                   NUMBER         := '~QUOTE_NUMBER';
   ITEM_DESCRIPTION               VARCHAR2(240)  := '~ITEM_DESCRIPTION';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF QUOTE_NUMBER = -1 THEN
   QUOTE_NUMBER := NULL;
END IF;

   qot_analyzer_pkg.main(
     QUOTE_NUMBER                   => QUOTE_NUMBER
    ,ITEM_DESCRIPTION               => ITEM_DESCRIPTION
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;