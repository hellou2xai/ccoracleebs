REM $Id: ap_xtr_analyze.sql, 200.18 2026/02/25 12:33:36 sdenye Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ap_xtr_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ap_xtr_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Treasury Analyzer
REM
REM MENU_START
REM
REM SQL: Run Treasury Analyzer
REM FNDLOAD: Load Treasury Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Treasury Analyzer Help [Doc ID: 2430571.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ap_xtr_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Treasury Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: XTR_TOP
REM PROG_NAME: APXTRAZ
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: APXTRAZ.ldt
REM
REM PROD_SHORT_NAME: XTR
REM CP_FILE: 
REM APP_NAME: Treasury
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ap_xtr_analyzer.sql
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
PROMPT Submitting Treasury Analyzer...

PROMPT ===========================================================================
PROMPT Application Login user name This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_user_name CHAR   PROMPT 'Enter the User Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Deal Type (EXP,IAC,OTHER,or N/A) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_deal_type CHAR   PROMPT 'Enter the Deal Type: '
PROMPT
PROMPT ===========================================================================
PROMPT Provide the Deal Number, if applicable.  Otherwise, leave blank. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_deal_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Deal Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Transaction Number is required if the Deal Number is being passed as 0. For IAC, please get Transaction number field value using the following steps => In the 'Inter-Account Transfers'  form, click on the 'Review Transfers' button => Use Help > Diagnostics > Examine > (Give field as Transaction_Number) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_trx_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Transaction Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_user_name                    VARCHAR2(240)  := '~p_user_name';
   p_deal_type                    VARCHAR2(240)  := '~p_deal_type';
   p_deal_number                  NUMBER         := '~p_deal_number';
   p_trx_number                   NUMBER         := '~p_trx_number';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_deal_number = -1 THEN
   p_deal_number := NULL;
END IF;
IF p_trx_number = -1 THEN
   p_trx_number := NULL;
END IF;

   ap_xtr_analyzer_pkg.main(
     p_user_name                    => p_user_name
    ,p_deal_type                    => p_deal_type
    ,p_deal_number                  => p_deal_number
    ,p_trx_number                   => p_trx_number
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;