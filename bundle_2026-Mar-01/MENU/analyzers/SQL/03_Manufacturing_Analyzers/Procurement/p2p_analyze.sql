REM $Id: p2p_analyze.sql, 200.26 2026/01/28 16:21:22 dfelton Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    p2p_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the p2p_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Procure To Pay Analyzer
REM
REM MENU_START
REM
REM SQL: Run Procure To Pay Analyzer
REM FNDLOAD: Load Procure To Pay Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Procure To Pay Analyzer Help [Doc ID: 2040474.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs p2p_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Procure To Pay Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PO_TOP
REM PROG_NAME: P2PAZ
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: P2PAZ.ldt
REM
REM PROD_SHORT_NAME: PO
REM CP_FILE: 
REM APP_NAME: Purchasing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM p2p_analyzer.sql
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
PROMPT Submitting Procure To Pay Analyzer...

PROMPT ===========================================================================
PROMPT Enter the organization id  This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER   PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Requisition number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_req_num CHAR   PROMPT 'Enter the Requisition number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the document type.  Valid values are "PO", "PA" or "RELEASE". This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_trx_type CHAR   PROMPT 'Enter the Document Type: '
PROMPT
PROMPT ===========================================================================
PROMPT Purchase Order Number This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_po_num CHAR   PROMPT 'Enter the Purchase Order Number: '
PROMPT
PROMPT ===========================================================================
PROMPT If the document type is RELEASE, enter the release number, otherwise leave blank. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_release_num NUMBER  DEFAULT '-1' PROMPT 'Enter the Release Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Invoice Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_invoice_num CHAR   PROMPT 'Enter the Invoice Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_org_id                       NUMBER         := '~p_org_id';
   p_req_num                      VARCHAR2(240)  := '~p_req_num';
   p_trx_type                     VARCHAR2(240)  := '~p_trx_type';
   p_po_num                       VARCHAR2(240)  := '~p_po_num';
   p_release_num                  NUMBER         := '~p_release_num';
   p_invoice_num                  VARCHAR2(240)  := '~p_invoice_num';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_release_num = -1 THEN
   p_release_num := NULL;
END IF;
IF p_org_id IS NULL THEN
   p_org_id := mo_global.get_ou_name( nvl( fnd_profile.value('DEFAULT_ORG_ID'), fnd_profile.value('ORG_ID') ) );
END IF;


   p2p_analyzer_pkg.main(
     p_org_id                       => p_org_id
    ,p_req_num                      => p_req_num
    ,p_trx_type                     => upper(nvl(p_trx_type,'ANY'))
    ,p_po_num                       => p_po_num
    ,p_release_num                  => p_release_num
    ,p_invoice_num                  => p_invoice_num
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;