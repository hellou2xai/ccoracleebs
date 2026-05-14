REM $Id: il_gst_analyze.sql, 200.27 2026/01/28 07:56:15 saananth Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    il_gst_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the il_gst_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Financials for India GST Analyzer
REM
REM MENU_START
REM
REM SQL: Run Financials for India GST Analyzer
REM FNDLOAD: Load Financials for India GST Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Financials for India GST Analyzer Help [Doc ID: 2297311.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs il_gst_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Financials for India GST Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "JAI_Purchasing_RG"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: JA_TOP
REM PROG_NAME: ILGST
REM DEF_REQ_GROUP: JAI_Purchasing_RG
REM PROG_TEMPLATE: ILGSTAZ.ldt
REM
REM PROD_SHORT_NAME: JA
REM CP_FILE: 
REM APP_NAME: Asia/Pacific Localizations
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM il_gst_analyzer.sql
REM
REM DEPENDENCIES_END
REM
REM CONDITION_START
REM select 1 from dual
REM where ad_patch.is_patch_applied('R12',-1,'19283503') ='EXPLICIT'
REM and ad_patch.is_patch_applied('R12',-1,'26153906') ='EXPLICIT'
REM and ad_patch.is_patch_applied('R12',-1,'26003443') ='EXPLICIT'
REM and ad_patch.is_patch_applied('R12',-1,'26171921') ='EXPLICIT'
REM and exists
REM   (  SELECT 1 FROM fnd_application_vl a, fnd_product_installations b
REM      WHERE a.application_id = b.application_id
REM      and a.application_short_name ='JA'
REM      and upper(a.application_name) like '%ASIA%'
REM      and b.status='I'
REM   )
REM CONDITION_END
REM
REM CONDITION_FAIL_START
REM At least one of these required patches is not applied: 
REM - 19283503
REM - 26153906
REM - 26003443
REM - 26171921
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
PROMPT Submitting Financials for India GST Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Diagnostics  type.  Valid values are 'LOCSTATUS', 'LOCAPLIST', 'LOCPORCT', 'LOCOMLIST', 'LOCARLIST' or 'LOCFALIST' This parameter is required.
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
PROMPT PO Header ID (LOCPORCT only) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_po_header_id NUMBER  DEFAULT '-1' PROMPT 'Enter the PO Header ID (LOCPORCT only): '
PROMPT
PROMPT ===========================================================================
PROMPT RCV Shipment Header ID (LOCPORCT only) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_rcv_header_id NUMBER  DEFAULT '-1' PROMPT 'Enter the RCV Shipment Header ID (LOCPORCT only): '
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
PROMPT Cash Receipt ID (LOCARLIST only) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_cash_receipt_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Cash Receipt ID (LOCARLIST only): '
PROMPT
PROMPT ===========================================================================
PROMPT Book Book Type Code (LOCFALIST only) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_book_type_code_id CHAR   PROMPT 'Enter the Book Type Code (LOCFALIST only): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the date from which to begin validating transactions (LOCFALIST only). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_from_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the START DATE (LOCFALIST only) [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the date from which to stop validating transactions (LOCFALIST only). 
PROMPT ===========================================================================
PROMPT
ACCEPT p_end_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the END DATE (LOCFALIST only) [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '100' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_trx_type                     VARCHAR2(240)  := '~p_trx_type';
   p_invoice_id                   NUMBER         := '~p_invoice_id';
   p_po_header_id                 NUMBER         := '~p_po_header_id';
   p_rcv_header_id                NUMBER         := '~p_rcv_header_id';
   p_so_header_id                 NUMBER         := '~p_so_header_id';
   p_so_line_id                   NUMBER         := '~p_so_line_id';
   p_cust_trx_id                  NUMBER         := '~p_cust_trx_id';
   p_cash_receipt_id              NUMBER         := '~p_cash_receipt_id';
   p_book_type_code_id            VARCHAR2(240)  := '~p_book_type_code_id';
   p_from_date                    DATE           := to_date('~p_from_date','DD-MON-YYYY');
   p_end_date                     DATE           := to_date('~p_end_date','DD-MON-YYYY');
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_invoice_id = -1 THEN
   p_invoice_id := NULL;
END IF;
IF p_po_header_id = -1 THEN
   p_po_header_id := NULL;
END IF;
IF p_rcv_header_id = -1 THEN
   p_rcv_header_id := NULL;
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
IF p_cash_receipt_id = -1 THEN
   p_cash_receipt_id := NULL;
END IF;
IF p_from_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_from_date := NULL;
END IF;
IF p_end_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_end_date := NULL;
END IF;
IF p_from_date IS NULL THEN
   p_from_date := sysdate-90;
END IF;

IF p_end_date IS NULL THEN
   p_end_date := sysdate;
END IF;


   il_gst_analyzer_pkg.main(
     p_trx_type                     => upper(p_trx_type)
    ,p_invoice_id                   => p_invoice_id
    ,p_po_header_id                 => p_po_header_id
    ,p_rcv_header_id                => p_rcv_header_id
    ,p_so_header_id                 => p_so_header_id
    ,p_so_line_id                   => p_so_line_id
    ,p_cust_trx_id                  => p_cust_trx_id
    ,p_cash_receipt_id              => p_cash_receipt_id
    ,p_book_type_code_id            => upper(p_book_type_code_id)
    ,p_from_date                    => p_from_date
    ,p_end_date                     => p_end_date
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;