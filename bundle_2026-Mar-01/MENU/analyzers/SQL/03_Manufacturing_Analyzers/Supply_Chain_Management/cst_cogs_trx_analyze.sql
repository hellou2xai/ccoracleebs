REM $Id: cst_cogs_trx_analyze.sql, 200.15 2026/01/27 14:25:25 sothman Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    cst_cogs_trx_analyze.sql                                               |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the CST_COGS_analyzer_pkg.main procedure         |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Cost Management COGS/DCOGS Analyzer
REM
REM MENU_START
REM
REM SQL: Run Cost Management COGS/DCOGS Analyzer
REM FNDLOAD: Load Cost Management COGS/DCOGS Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Cost Management COGS/DCOGS Analyzer Help [Doc ID: 2453170.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs cst_cogs_trx_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Cost Management COGS/DCOGS Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Cost Management"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: BOM_TOP
REM PROG_NAME: CSTCOGS
REM DEF_REQ_GROUP: Cost Management
REM PROG_TEMPLATE: CSTCOGSAZ.ldt
REM
REM PROD_SHORT_NAME: BOM
REM CP_FILE: 
REM APP_NAME: Bills of Material
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM cst_cogs_trx_analyzer.sql
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
PROMPT Submitting Cost Management COGS/DCOGS Analyzer...

PROMPT ===========================================================================
PROMPT COGS Issue: Valid values are Y or N This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_COGS_issue CHAR   PROMPT 'Enter the COGS Issue: Valid values are Y or N: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Sales Order number if you have an issue with a specific Order. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_order_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Sales Order number if you have an issue with a specific Order: '
PROMPT
PROMPT ===========================================================================
PROMPT Start Date - Format DD-MON-YYYY 
PROMPT ===========================================================================
PROMPT
ACCEPT p_from_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the Start Date - Format DD-MON-YYYY [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT End Date - format DD-MON-YYYY 
PROMPT ===========================================================================
PROMPT
ACCEPT p_to_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the End Date - format DD-MON-YYYY [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Organization ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_organization_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Ledger Id This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT P_LEDGER_ID2 NUMBER  DEFAULT '-1' PROMPT 'Enter the Ledger Id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '300' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_COGS_issue                   VARCHAR2(240)  := '~p_COGS_issue';
   p_order_number                 NUMBER         := '~p_order_number';
   p_from_date                    DATE           := to_date('~p_from_date','DD-MON-YYYY');
   p_to_date                      DATE           := to_date('~p_to_date','DD-MON-YYYY');
   p_organization_id              NUMBER         := '~p_organization_id';
   P_LEDGER_ID2                   NUMBER         := '~P_LEDGER_ID2';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_order_number = -1 THEN
   p_order_number := NULL;
END IF;
IF p_organization_id = -1 THEN
   p_organization_id := NULL;
END IF;
IF P_LEDGER_ID2 = -1 THEN
   P_LEDGER_ID2 := NULL;
END IF;
IF p_from_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_from_date := NULL;
END IF;
IF p_to_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_to_date := NULL;
END IF;
IF p_from_date IS NULL THEN
   p_from_date := to_char(sysdate-365,'DD-MON-YYYY');
END IF;

IF p_to_date IS NULL THEN
   p_to_date := to_char(sysdate,'DD-MON-YYYY');
END IF;


   CST_COGS_analyzer_pkg.main(
     p_COGS_issue                   => upper(p_COGS_issue)
    ,p_order_number                 => p_order_number
    ,p_from_date                    => p_from_date
    ,p_to_date                      => p_to_date
    ,p_organization_id              => p_organization_id
    ,P_LEDGER_ID2                   => P_LEDGER_ID2
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;