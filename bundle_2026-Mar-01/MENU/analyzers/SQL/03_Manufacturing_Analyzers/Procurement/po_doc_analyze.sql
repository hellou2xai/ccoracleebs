REM $Id: po_doc_analyze.sql, 200.55 2026/01/27 20:11:54 loinonen Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    po_doc_analyze.sql                                                     |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the po_doc_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Procurement Document Analyzer
REM
REM MENU_START
REM
REM SQL: Run Procurement Document Analyzer
REM FNDLOAD: Load Procurement Document Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Procurement Document Analyzer Help [Doc ID: 2547817.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs po_doc_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Procurement Document Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Purchasing Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PO_TOP
REM PROG_NAME: PODOC
REM DEF_REQ_GROUP: Purchasing Reports
REM PROG_TEMPLATE: PODOCAZ.ldt
REM
REM PROD_SHORT_NAME: PO
REM CP_FILE: 
REM APP_NAME: Purchasing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM po_doc_analyzer.sql
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
PROMPT Submitting Procurement Document Analyzer...

PROMPT ===========================================================================
PROMPT Enter the org_id for the operating unit. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER   PROMPT 'Enter the Org ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the document type PO, BPA, REL,REQ, RFQ, or QUOTATION.  Enter PO for (PURCHASE ORDER or CONTRACT AGREEMENT).  Enter BPA for (BLANKET AGREEMENT).  Enter REL for (BLANKET RELEASE). Enter REQ for (PURCHASE REQUISITION or INTERNAL REQUISITION). Enter RFQ for (REQUEST FOR QUOTE). Enter QUOTATION for (QUOTATION in PURCHASING).  This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_doc_type CHAR   PROMPT 'Enter the Document Type: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the document number, based on your document type selection.  Example: For Blanket Release 105-12 enter 105 only. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_doc_number CHAR   PROMPT 'Enter the Document Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Release Number (Optional - only applicable for Blanket Agreement Releases).  Example: For Blanket Release 105-12 enter 12 only. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_doc_release NUMBER  DEFAULT '-1' PROMPT 'Enter the Release Number (for BPA Releases only): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the requisition line number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_req_line_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Requisition Line Number: '
PROMPT
PROMPT ===========================================================================
PROMPT PO Line Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_po_line_number NUMBER  DEFAULT '-1' PROMPT 'Enter the PO Line Number: '
PROMPT
PROMPT ===========================================================================
PROMPT BPA Line Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_bpa_line_number NUMBER  DEFAULT '-1' PROMPT 'Enter the BPA Line Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Release Shipment Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_rel_line_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Release Shipment Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Diag Apps Check This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Diag Apps Check: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '200' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_org_id                       NUMBER         := '~p_org_id';
   p_doc_type                     VARCHAR2(240)  := '~p_doc_type';
   p_doc_number                   VARCHAR2(240)  := '~p_doc_number';
   p_doc_release                  NUMBER         := '~p_doc_release';
   p_req_line_number              NUMBER         := '~p_req_line_number';
   p_po_line_number               NUMBER         := '~p_po_line_number';
   p_bpa_line_number              NUMBER         := '~p_bpa_line_number';
   p_rel_line_number              NUMBER         := '~p_rel_line_number';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_doc_release = -1 THEN
   p_doc_release := NULL;
END IF;
IF p_req_line_number = -1 THEN
   p_req_line_number := NULL;
END IF;
IF p_po_line_number = -1 THEN
   p_po_line_number := NULL;
END IF;
IF p_bpa_line_number = -1 THEN
   p_bpa_line_number := NULL;
END IF;
IF p_rel_line_number = -1 THEN
   p_rel_line_number := NULL;
END IF;
IF p_org_id IS NULL THEN
   p_org_id := mo_global.get_ou_name( nvl( fnd_profile.value('DEFAULT_ORG_ID'), fnd_profile.value('ORG_ID') ) );
END IF;


   po_doc_analyzer_pkg.main(
     p_org_id                       => p_org_id
    ,p_doc_type                     => p_doc_type
    ,p_doc_number                   => p_doc_number
    ,p_doc_release                  => p_doc_release
    ,p_req_line_number              => p_req_line_number
    ,p_po_line_number               => p_po_line_number
    ,p_bpa_line_number              => p_bpa_line_number
    ,p_rel_line_number              => p_rel_line_number
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;