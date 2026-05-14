REM $Id: cst_reconciliation_analyze.sql, 200.7 2026/01/28 12:20:30 sothman Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    cst_reconciliation_analyze.sql                                         |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the cst_recon_analyzer_pkg.main procedure        |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Inventory to General Ledger Reconciliation Analyzer
REM
REM MENU_START
REM
REM SQL: Run Inventory to General Ledger Reconciliation Analyzer
REM FNDLOAD: Load Inventory to General Ledger Reconciliation Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Inventory to General Ledger Reconciliation Analyzer Help [Doc ID: 2660156.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs cst_reconciliation_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Inventory to General Ledger Reconciliation Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Cost Management"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: BOM_TOP
REM PROG_NAME: CSTRECON
REM DEF_REQ_GROUP: Cost Management
REM PROG_TEMPLATE: CSTRECONAZ.ldt
REM
REM PROD_SHORT_NAME: BOM
REM CP_FILE: 
REM APP_NAME: Bills of Material
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM cst_reconciliation_analyzer.sql
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
PROMPT Submitting Inventory to General Ledger Reconciliation Analyzer...

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
PROMPT Enter valid Ledger Id This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_ledger_id_sql NUMBER  DEFAULT '-1' PROMPT 'Enter the Ledger Id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter COST_GROUP_ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_COST_GROUP_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the COST_GROUP_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Account ID code_combination_id This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_Account_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the Account ID code_combination_id: '
PROMPT
PROMPT ===========================================================================
PROMPT Period Name-example: Dec-22 This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_Period_Name CHAR   PROMPT 'Enter the p_Period_Name-example: Dec-22: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '300' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_from_date                    DATE           := to_date('~p_from_date','DD-MON-YYYY');
   p_to_date                      DATE           := to_date('~p_to_date','DD-MON-YYYY');
   p_organization_id              NUMBER         := '~p_organization_id';
   p_ledger_id_sql                NUMBER         := '~p_ledger_id_sql';
   p_COST_GROUP_ID                NUMBER         := '~p_COST_GROUP_ID';
   p_Account_ID                   NUMBER         := '~p_Account_ID';
   p_Period_Name                  VARCHAR2(240)  := '~p_Period_Name';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_organization_id = -1 THEN
   p_organization_id := NULL;
END IF;
IF p_ledger_id_sql = -1 THEN
   p_ledger_id_sql := NULL;
END IF;
IF p_COST_GROUP_ID = -1 THEN
   p_COST_GROUP_ID := NULL;
END IF;
IF p_Account_ID = -1 THEN
   p_Account_ID := NULL;
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


   cst_recon_analyzer_pkg.main(
     p_from_date                    => p_from_date
    ,p_to_date                      => p_to_date
    ,p_organization_id              => p_organization_id
    ,p_ledger_id_sql                => p_ledger_id_sql
    ,p_COST_GROUP_ID                => p_COST_GROUP_ID
    ,p_Account_ID                   => p_Account_ID
    ,p_Period_Name                  => p_Period_Name
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;