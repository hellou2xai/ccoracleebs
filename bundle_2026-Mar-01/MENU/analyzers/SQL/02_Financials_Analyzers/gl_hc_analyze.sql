REM $Id: gl_hc_analyze.sql, 200.41 2025/12/13 22:14:50 viakula Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    gl_hc_analyze.sql                                                      |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the gl_analyzer_pkg.main procedure               |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: General Ledger Analyzer
REM
REM MENU_START
REM
REM SQL: Run General Ledger Analyzer
REM FNDLOAD: Load General Ledger Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  General Ledger Analyzer Help [Doc ID: 2117528.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs gl_hc_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install General Ledger Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "GL Concurrent Program Group"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: GL_TOP
REM PROG_NAME: FCGLANALYZER
REM DEF_REQ_GROUP: GL Concurrent Program Group
REM PROG_TEMPLATE: GLHCAZ.ldt
REM
REM PROD_SHORT_NAME: SQLGL
REM CP_FILE: 
REM APP_NAME: General Ledger
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM gl_hc_analyzer.sql
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
PROMPT Submitting General Ledger Analyzer...

PROMPT ===========================================================================
PROMPT Enter a Valid Ledger ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_ledger_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Enter a Valid Ledger ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Period Name in the Exact format from your GL Accounting Calendar setup. Period Name where Balances Corruption first started. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_period_name CHAR   PROMPT 'Enter the Period Name for Period Closing details.: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter a Valid Budget Version ID. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_bud_ver_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Enter a Valid Budget Version ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Do you want to run the Data Collection? 
PROMPT ===========================================================================
PROMPT
ACCEPT p_dc CHAR  DEFAULT 'Y' PROMPT 'Enter the Data Collection Response of Y or N: '
PROMPT
PROMPT ===========================================================================
PROMPT If you want to analyze a specific batch, please enter the je_batch_id. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_batch_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Enter a valid je_batch_id: '
PROMPT
PROMPT ===========================================================================
PROMPT If you want to analyze a specific recurring batch, please enter the RECURRING_BATCH_ID. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_rec_batch_id NUMBER  DEFAULT '-1' PROMPT 'Enter the RECURRING_BATCH_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter a Valid Code Combination ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_ccid NUMBER  DEFAULT '-1' PROMPT 'Enter the Enter a Valid Code Combination ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter a valid FSG Report ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_rep_id NUMBER  DEFAULT '-1' PROMPT 'Enter the FSG Report ID: '
PROMPT
PROMPT ===========================================================================
PROMPT If you want to analyze a specific consolidation setup, please enter the valid consolidation_id. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_consolidation_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Enter a Valid Consolidation ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [100] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '100' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_ledger_id                    NUMBER         := '~p_ledger_id';
   p_period_name                  VARCHAR2(240)  := '~p_period_name';
   p_bud_ver_id                   NUMBER         := '~p_bud_ver_id';
   p_dc                           VARCHAR2(240)  := '~p_dc';
   p_batch_id                     NUMBER         := '~p_batch_id';
   p_rec_batch_id                 NUMBER         := '~p_rec_batch_id';
   p_ccid                         NUMBER         := '~p_ccid';
   p_rep_id                       NUMBER         := '~p_rep_id';
   p_consolidation_id             NUMBER         := '~p_consolidation_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_ledger_id = -1 THEN
   p_ledger_id := NULL;
END IF;
IF p_bud_ver_id = -1 THEN
   p_bud_ver_id := NULL;
END IF;
IF p_batch_id = -1 THEN
   p_batch_id := NULL;
END IF;
IF p_rec_batch_id = -1 THEN
   p_rec_batch_id := NULL;
END IF;
IF p_ccid = -1 THEN
   p_ccid := NULL;
END IF;
IF p_rep_id = -1 THEN
   p_rep_id := NULL;
END IF;
IF p_consolidation_id = -1 THEN
   p_consolidation_id := NULL;
END IF;

   gl_analyzer_pkg.main(
     p_ledger_id                    => p_ledger_id
    ,p_period_name                  => p_period_name
    ,p_bud_ver_id                   => p_bud_ver_id
    ,p_dc                           => upper(p_dc)
    ,p_batch_id                     => p_batch_id
    ,p_rec_batch_id                 => p_rec_batch_id
    ,p_ccid                         => p_ccid
    ,p_rep_id                       => p_rep_id
    ,p_consolidation_id             => p_consolidation_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;