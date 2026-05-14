REM $Id: ar_docseq_analyze.sql, 200.44 2026/01/29 15:19:19 mamoreir Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ar_docseq_analyze.sql                                                  |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ar_docseq_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Receivables Document Sequence Analyzer
REM
REM MENU_START
REM
REM SQL: Run Receivables Document Sequence Analyzer
REM FNDLOAD: Load Receivables Document Sequence Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Receivables Document Sequence Analyzer Help [Doc ID: 2021711.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ar_docseq_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Receivables Document Sequence Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Receivables All"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: AR_TOP
REM PROG_NAME: ARDOCSEQ
REM DEF_REQ_GROUP: Receivables All
REM PROG_TEMPLATE: ARDOCSEQAZ.ldt
REM
REM PROD_SHORT_NAME: AR
REM CP_FILE: 
REM APP_NAME: Receivables
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ar_docseq_analyzer.sql
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
PROMPT Submitting Receivables Document Sequence Analyzer...

PROMPT ===========================================================================
PROMPT Enter the User Name used to log into Receivables. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_user_name CHAR   PROMPT 'Enter the User Name: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Responsibility ID used in Receivables application. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_resp_id NUMBER   PROMPT 'Enter the Responsibility ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Organization ID. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_org_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the document type that is missing a document sequence assignment.  The valid values are: TRANSACTION (for Invoices, Invoice Adjustments, Credit Memos, Debit Memos, Commitments, Bills Receivable), RECEIPT (for Cash Receipts, Miscellaneous Receipts, Bills Receivable Remittance) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_document_type CHAR   PROMPT 'Enter the Document Type: '
PROMPT
PROMPT ===========================================================================
PROMPT Either ID (Transaction ID or Receipt ID) OR Category (Transaction Type, Receipt Method or Adjustment Receivable Activity) This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_id_categ CHAR   PROMPT 'Enter the ID or Category: '
PROMPT
PROMPT ===========================================================================
PROMPT Include Apps Check: Valid values are Y or N. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_apps_check CHAR  DEFAULT 'N' PROMPT 'Enter the Include Apps Check: '
PROMPT
PROMPT
DECLARE
   p_user_name                    VARCHAR2(240)  := '~p_user_name';
   p_resp_id                      NUMBER         := '~p_resp_id';
   p_org_id                       NUMBER         := '~p_org_id';
   p_document_type                VARCHAR2(240)  := '~p_document_type';
   p_id_categ                     VARCHAR2(240)  := '~p_id_categ';
   p_apps_check                   VARCHAR2(240)  := '~p_apps_check';

BEGIN

IF p_org_id = -1 THEN
   p_org_id := NULL;
END IF;
IF p_user_name IS NULL THEN
   p_user_name := FND_GLOBAL.user_name;
END IF;

IF p_resp_id IS NULL THEN
   p_resp_id := FND_GLOBAL.RESP_NAME;
END IF;


   ar_docseq_analyzer_pkg.main(
     p_user_name                    => upper(p_user_name)
    ,p_resp_id                      => p_resp_id
    ,p_org_id                       => p_org_id
    ,p_document_type                => p_document_type
    ,p_id_categ                     => p_id_categ
    ,p_apps_check                   => upper(p_apps_check)
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;