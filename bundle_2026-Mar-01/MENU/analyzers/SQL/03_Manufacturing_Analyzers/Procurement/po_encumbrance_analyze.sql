REM $Id: po_encumbrance_analyze.sql, 200.18 2026/02/23 22:24:20 pksethi Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    po_encumbrance_analyze.sql                                             |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the po_enc_analyzer_pkg.main procedure           |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Procurement Encumbrance Accounting Analyzer
REM
REM MENU_START
REM
REM SQL: Run Procurement Encumbrance Accounting Analyzer
REM FNDLOAD: Load Procurement Encumbrance Accounting Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Procurement Encumbrance Accounting Analyzer Help [Doc ID: 1970384.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs po_encumbrance_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Procurement Encumbrance Accounting Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PO_TOP
REM PROG_NAME: PODIAGEA
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: PODIAGEAAZ.ldt
REM
REM PROD_SHORT_NAME: PO
REM CP_FILE: 
REM APP_NAME: Purchasing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM po_encumbrance_analyzer.sql
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
PROMPT Submitting Procurement Encumbrance Accounting Analyzer...

PROMPT ===========================================================================
PROMPT Enter the org_id for the operating unit. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER   PROMPT 'Enter the org_id (required): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the document type. Valid values are PO, RELEASE or REQ. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_doc_type CHAR   PROMPT 'Enter the Document Type - PO, RELEASE or REQ - (required): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter document number. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_doc_num CHAR   PROMPT 'Enter the Document Number (required): '
PROMPT
PROMPT ===========================================================================
PROMPT If the document type is RELEASE, enter the release number, otherwise leave blank. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_release_num NUMBER  DEFAULT '-1' PROMPT 'Enter the Release Number - required only for RELEASE - leave blank for PO and REQ: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [2000] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '2000' PROMPT 'Enter the Maximum Rows to Display (default 2000): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the debug mode [N] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_debug_mode CHAR  DEFAULT 'N' PROMPT 'Enter the Debug Mode [N]: '
PROMPT
PROMPT
DECLARE
   p_org_id                       NUMBER         := '~p_org_id';
   p_doc_type                     VARCHAR2(240)  := '~p_doc_type';
   p_doc_num                      VARCHAR2(240)  := '~p_doc_num';
   p_release_num                  NUMBER         := '~p_release_num';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';
   p_debug_mode                   VARCHAR2(240)  := '~p_debug_mode';

BEGIN

IF p_release_num = -1 THEN
   p_release_num := NULL;
END IF;
IF p_org_id IS NULL THEN
   p_org_id := mo_global.get_ou_name( nvl( fnd_profile.value('DEFAULT_ORG_ID'), fnd_profile.value('ORG_ID') ) );
END IF;


   po_enc_analyzer_pkg.main(
     p_org_id                       => p_org_id
    ,p_doc_type                     => p_doc_type
    ,p_doc_num                      => p_doc_num
    ,p_release_num                  => p_release_num
    ,p_max_output_rows              => p_max_output_rows
    ,p_debug_mode                   => p_debug_mode
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;