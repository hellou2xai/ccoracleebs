REM $Id: cle_emea_addon_analyze.sql, 200.17 2026/01/28 06:49:44 saananth Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    cle_emea_addon_analyze.sql                                             |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the cle_emea_addon_analyzer_pkg.main procedure   |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: EMEA Add-On Localizations Analyzer
REM
REM MENU_START
REM
REM SQL: Run EMEA Add-On Localizations Analyzer
REM FNDLOAD: Load EMEA Add-On Localizations Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  EMEA Add-On Localizations Analyzer Help [Doc ID: 2576588.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs cle_emea_addon_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install EMEA Add-On Localizations Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: CLE_TOP
REM PROG_NAME: CLEEMEAANL
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: CLEEMEAAZ.ldt
REM
REM PROD_SHORT_NAME: CLE
REM CP_FILE: 
REM APP_NAME: EMEA Consulting Localizations
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM cle_emea_addon_analyzer.sql
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
PROMPT Submitting EMEA Add-On Localizations Analyzer...

PROMPT ===========================================================================
PROMPT Valid values: ITALY, HUNGARY, PORTUGAL, POLAND, RUSSIA, ISRAEL, GERMANY or OTHER This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_country CHAR   PROMPT 'Enter the EMEA ADD-On Country: '
PROMPT
PROMPT ===========================================================================
PROMPT Valid values are LOCSTATUS, LOCAPLIST, LOCOMLIST, LOCARLIST. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_trx_type CHAR   PROMPT 'Enter the Diagnostics Type: '
PROMPT
PROMPT ===========================================================================
PROMPT AP Invoice ID (LOCAPLIST only) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_invoice_id NUMBER  DEFAULT '-1' PROMPT 'Enter the AP Invoice ID (LOCAPLIST only): '
PROMPT
PROMPT ===========================================================================
PROMPT Sales Order Header ID (LOCOMLIST only) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_so_header_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Sales Order Header ID (LOCOMLIST only): '
PROMPT
PROMPT ===========================================================================
PROMPT Sales Order line ID (LOCOMLIST only) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_so_line_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Sales Order line ID (LOCOMLIST only): '
PROMPT
PROMPT ===========================================================================
PROMPT Customer Trx ID (LOCARLIST only) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_cust_trx_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Customer Trx ID (LOCARLIST only): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_country                      VARCHAR2(240)  := '~p_country';
   p_trx_type                     VARCHAR2(240)  := '~p_trx_type';
   p_invoice_id                   NUMBER         := '~p_invoice_id';
   p_so_header_id                 NUMBER         := '~p_so_header_id';
   p_so_line_id                   NUMBER         := '~p_so_line_id';
   p_cust_trx_id                  NUMBER         := '~p_cust_trx_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_invoice_id = -1 THEN
   p_invoice_id := NULL;
END IF;
IF p_so_header_id = -1 THEN
   p_so_header_id := NULL;
END IF;
IF p_so_line_id = -1 THEN
   p_so_line_id := NULL;
END IF;
IF p_cust_trx_id = -1 THEN
   p_cust_trx_id := NULL;
END IF;

   cle_emea_addon_analyzer_pkg.main(
     p_country                      => upper(p_country)
    ,p_trx_type                     => upper(p_trx_type)
    ,p_invoice_id                   => p_invoice_id
    ,p_so_header_id                 => p_so_header_id
    ,p_so_line_id                   => p_so_line_id
    ,p_cust_trx_id                  => p_cust_trx_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;