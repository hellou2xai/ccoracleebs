REM $Id: rcv_podata_analyze.sql, 200.55 2026/02/23 18:20:16 oracle Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    rcv_podata_analyze.sql                                                 |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the inv_rec_analyzer_pkg.main procedure          |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Receiving Analyzer
REM
REM MENU_START
REM
REM SQL: Run Receiving Analyzer
REM FNDLOAD: Load Receiving Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Receiving Analyzer Help [Doc ID: 2012304.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs rcv_podata_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Receiving Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Inclusive GUI"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: INV_TOP
REM PROG_NAME: PORCVANL
REM DEF_REQ_GROUP: All Inclusive GUI
REM PROG_TEMPLATE: PORCVANLAZ.ldt
REM PROG_TEMPLATE_11i: PORCVANLAZ_11i.ldt
REM PROD_SHORT_NAME: INV
REM CP_FILE: 
REM APP_NAME: Inventory
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM rcv_podata_analyzer.sql
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
PROMPT Submitting Receiving Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Source Document Type. For Standard Purchase orders type "PO", For Blanket Release "PR", For Return Material Authorization "RMA", For Inter Org Transfer based Shipments "IOT", For Internal Requisition "RQ" This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_doc_type CHAR   PROMPT 'Enter the Source Document Type: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Purchase Order Type (Only if Document type is PO or PR). For Standard Purchase orders type "ST", for Planned Purchase Orders "PL", for Blanket Purchase Agreements "BL", for Contract Purchase Agreements "CO". 
PROMPT ===========================================================================
PROMPT
ACCEPT p_po_type CHAR   PROMPT 'Enter the Purchase Order Type: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the operating unit id (only required and needed if the source document type is PO, PR, RMA, and RQ) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Operating unit id: '
PROMPT
PROMPT ===========================================================================
PROMPT Please enter the Purchase order number (Only if Document type is PO) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_po_number CHAR   PROMPT 'Enter the Purchase Order Number: '
PROMPT
PROMPT ===========================================================================
PROMPT  Release number(Only if source doc is Blanket release) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_release_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Blanket Release number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the RMA Number (Only if Source document type is RMA) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_rma_number CHAR   PROMPT 'Enter the RMA Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Internal Requisition Number (Only if Source document type is RQ) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_req_number CHAR   PROMPT 'Enter the Internal Requisition Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Destination inventory organization id (Only if Source document type is Inter Org Shipment) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_organization_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Destination inventory organization id (For Inter Org Shipment): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Inter Org Shipment Number (Only if Source document type is IOT) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_iot_number CHAR   PROMPT 'Enter the Inter Org Shipment Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Y for 'Yes' Or N for 'No'  (Default is No) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_include_apps_check CHAR  DEFAULT 'Y' PROMPT 'Enter the Include Diagnostic Apps Check: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '200' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_doc_type                     VARCHAR2(240)  := '~p_doc_type';
   p_po_type                      VARCHAR2(240)  := '~p_po_type';
   p_org_id                       NUMBER         := '~p_org_id';
   p_po_number                    VARCHAR2(240)  := '~p_po_number';
   p_release_number               NUMBER         := '~p_release_number';
   p_rma_number                   VARCHAR2(240)  := '~p_rma_number';
   p_req_number                   VARCHAR2(240)  := '~p_req_number';
   p_organization_id              NUMBER         := '~p_organization_id';
   p_iot_number                   VARCHAR2(240)  := '~p_iot_number';
   p_include_apps_check           VARCHAR2(240)  := '~p_include_apps_check';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;
IF p_release_number = -1 THEN
   p_release_number := NULL;
END IF;
IF p_organization_id = -1 THEN
   p_organization_id := NULL;
END IF;

   inv_rec_analyzer_pkg.main(
     p_doc_type                     => p_doc_type
    ,p_po_type                      => p_po_type
    ,p_org_id                       => p_org_id
    ,p_po_number                    => p_po_number
    ,p_release_number               => p_release_number
    ,p_rma_number                   => p_rma_number
    ,p_req_number                   => p_req_number
    ,p_organization_id              => p_organization_id
    ,p_iot_number                   => p_iot_number
    ,p_include_apps_check           => upper(p_include_apps_check)
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;