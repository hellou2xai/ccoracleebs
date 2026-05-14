REM $Id: iby_fd_analyze.sql, 200.113 2026/02/24 19:56:40 aliclin Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    iby_fd_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the iby_fd_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Payments (IBY) Funds Disbursement Analyzer
REM
REM MENU_START
REM
REM SQL: Run Payments (IBY) Funds Disbursement Analyzer
REM FNDLOAD: Load Payments (IBY) Funds Disbursement Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Payments (IBY) Funds Disbursement Analyzer Help [Doc ID: 1587455.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs iby_fd_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Payments (IBY) Funds Disbursement Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AP_TOP
REM PROG_NAME: APPMTANL
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: IBYFDAZ.ldt
REM
REM PROD_SHORT_NAME: SQLAP
REM CP_FILE: 
REM APP_NAME: Payables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM iby_fd_analyzer.sql
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
PROMPT Submitting Payments (IBY) Funds Disbursement Analyzer...

PROMPT ===========================================================================
PROMPT org_id for the operating unit. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id CHAR   PROMPT 'Enter the org_id: '
PROMPT
PROMPT ===========================================================================
PROMPT To analyze a specific Payment Process Request (PPR). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_ppr_name CHAR   PROMPT 'Enter the PPR Name (skip if Quick Payment): '
PROMPT
PROMPT ===========================================================================
PROMPT To analyze a specific invoice. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_invoice_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Invoice ID: '
PROMPT
PROMPT ===========================================================================
PROMPT To analyze a specific check. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_check_id CHAR   PROMPT 'Enter the Check ID: '
PROMPT
PROMPT ===========================================================================
PROMPT To analyze a specific Bank Account. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_bank_account NUMBER  DEFAULT '-1' PROMPT 'Enter the EXT_BANK_ACCOUNT_ID from iby_ext_bank_accounts AND same org_id: '
PROMPT
PROMPT ===========================================================================
PROMPT Check Payments Data if upgraded from earlier version 
PROMPT ===========================================================================
PROMPT
ACCEPT p_upgrade CHAR  DEFAULT 'N' PROMPT 'Enter the response of Y, if not, press Enter: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '50' PROMPT 'Enter the Maximum Rows to Display [50]: '
PROMPT
PROMPT
DECLARE
   p_org_id                       VARCHAR2(240)  := '~p_org_id';
   p_ppr_name                     VARCHAR2(240)  := '~p_ppr_name';
   p_invoice_id                   NUMBER         := '~p_invoice_id';
   p_check_id                     VARCHAR2(240)  := '~p_check_id';
   p_bank_account                 NUMBER         := '~p_bank_account';
   p_upgrade                      VARCHAR2(240)  := '~p_upgrade';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_invoice_id = -1 THEN
   p_invoice_id := NULL;
END IF;
IF p_bank_account = -1 THEN
   p_bank_account := NULL;
END IF;
IF p_org_id IS NULL THEN
   p_org_id := mo_global.get_ou_name( nvl( fnd_profile.value('DEFAULT_ORG_ID'), fnd_profile.value('ORG_ID') ) );
END IF;


   iby_fd_analyzer_pkg.main(
     p_org_id                       => p_org_id
    ,p_ppr_name                     => p_ppr_name
    ,p_invoice_id                   => p_invoice_id
    ,p_check_id                     => p_check_id
    ,p_bank_account                 => p_bank_account
    ,p_upgrade                      => upper(p_upgrade)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;