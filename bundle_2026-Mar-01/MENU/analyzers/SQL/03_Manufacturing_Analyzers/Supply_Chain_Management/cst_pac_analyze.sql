REM $Id: cst_pac_analyze.sql, 200.13 2026/01/28 11:35:44 sothman Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    cst_pac_analyze.sql                                                    |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the CST_PAC_analyzer_pkg.main procedure          |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Cost Management Periodic Average Costing (PAC) Analyzer
REM
REM MENU_START
REM
REM SQL: Run Cost Management Periodic Average Costing (PAC) Analyzer
REM FNDLOAD: Load Cost Management Periodic Average Costing (PAC) Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Cost Management Periodic Average Costing (PAC) Analyzer Help [Doc ID: 2535197.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs cst_pac_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Cost Management Periodic Average Costing (PAC) Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Cost Management"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: BOM_TOP
REM PROG_NAME: CSTPAC
REM DEF_REQ_GROUP: Cost Management
REM PROG_TEMPLATE: CSTPACAZ.ldt
REM
REM PROD_SHORT_NAME: BOM
REM CP_FILE: 
REM APP_NAME: Bills of Material
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM cst_pac_analyzer.sql
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
PROMPT Submitting Cost Management Periodic Average Costing (PAC) Analyzer...

PROMPT ===========================================================================
PROMPT Is this an Item Issue: Valid values are Y or N This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_Item_issue CHAR  DEFAULT 'N' PROMPT 'Enter the Is this an Item Issue: Valid values are Y or N: '
PROMPT
PROMPT ===========================================================================
PROMPT Is this a PO Issue : Valid values are Y or N This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_PO_issue CHAR  DEFAULT 'N' PROMPT 'Enter the Is this a PO Issue : Valid values are Y or N: '
PROMPT
PROMPT ===========================================================================
PROMPT Is this a WIP Issue: Valid values are Y or N This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_WIP_issue CHAR  DEFAULT 'N' PROMPT 'Enter the Is this a WIP Issue: Valid values are Y or N: '
PROMPT
PROMPT ===========================================================================
PROMPT Is this an LCM Issue: Valid values are Y or N This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_LCM_issue CHAR  DEFAULT 'N' PROMPT 'Enter the Is this an LCM Issue: Valid values are Y or N: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Organization ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_organization_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Organization ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Category_Set_ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_Category_Set_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the Category_Set_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Inventory_Item_ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_Inventory_Item_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the Inventory_Item_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter PAC_Cost_Type_ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_PAC_Cost_Type_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the PAC_Cost_Type_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter PAC_Cost_Group_ID This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_PAC_Cost_Group_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the PAC_Cost_Group_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter Receiving Transaction_ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_TRANSACTION_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the Receiving TRANSACTION_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter PO Receipt Number 
PROMPT ===========================================================================
PROMPT
ACCEPT p_POrct NUMBER  DEFAULT '-1' PROMPT 'Enter the PO Receipt Number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter OSP_TXN_ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_OSP_txn NUMBER  DEFAULT '-1' PROMPT 'Enter the OSP_TXN_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter JOB_ID  
PROMPT ===========================================================================
PROMPT
ACCEPT p_Job_ID NUMBER  DEFAULT '-1' PROMPT 'Enter the JOB_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Purchase Order Header_ID 
PROMPT ===========================================================================
PROMPT
ACCEPT p_po_header_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Purchase Order Header_ID: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '300' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_Item_issue                   VARCHAR2(240)  := '~p_Item_issue';
   p_PO_issue                     VARCHAR2(240)  := '~p_PO_issue';
   p_WIP_issue                    VARCHAR2(240)  := '~p_WIP_issue';
   p_LCM_issue                    VARCHAR2(240)  := '~p_LCM_issue';
   p_organization_id              NUMBER         := '~p_organization_id';
   p_Category_Set_ID              NUMBER         := '~p_Category_Set_ID';
   p_Inventory_Item_ID            NUMBER         := '~p_Inventory_Item_ID';
   p_PAC_Cost_Type_ID             NUMBER         := '~p_PAC_Cost_Type_ID';
   p_PAC_Cost_Group_ID            NUMBER         := '~p_PAC_Cost_Group_ID';
   p_TRANSACTION_ID               NUMBER         := '~p_TRANSACTION_ID';
   p_POrct                        NUMBER         := '~p_POrct';
   p_OSP_txn                      NUMBER         := '~p_OSP_txn';
   p_Job_ID                       NUMBER         := '~p_Job_ID';
   p_po_header_id                 NUMBER         := '~p_po_header_id';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_organization_id = -1 THEN
   p_organization_id := NULL;
END IF;
IF p_Category_Set_ID = -1 THEN
   p_Category_Set_ID := NULL;
END IF;
IF p_Inventory_Item_ID = -1 THEN
   p_Inventory_Item_ID := NULL;
END IF;
IF p_PAC_Cost_Type_ID = -1 THEN
   p_PAC_Cost_Type_ID := NULL;
END IF;
IF p_PAC_Cost_Group_ID = -1 THEN
   p_PAC_Cost_Group_ID := NULL;
END IF;
IF p_TRANSACTION_ID = -1 THEN
   p_TRANSACTION_ID := NULL;
END IF;
IF p_POrct = -1 THEN
   p_POrct := NULL;
END IF;
IF p_OSP_txn = -1 THEN
   p_OSP_txn := NULL;
END IF;
IF p_Job_ID = -1 THEN
   p_Job_ID := NULL;
END IF;
IF p_po_header_id = -1 THEN
   p_po_header_id := NULL;
END IF;

   CST_PAC_analyzer_pkg.main(
     p_Item_issue                   => upper(p_Item_issue)
    ,p_PO_issue                     => upper(p_PO_issue)
    ,p_WIP_issue                    => upper(p_WIP_issue)
    ,p_LCM_issue                    => upper(p_LCM_issue)
    ,p_organization_id              => p_organization_id
    ,p_Category_Set_ID              => p_Category_Set_ID
    ,p_Inventory_Item_ID            => p_Inventory_Item_ID
    ,p_PAC_Cost_Type_ID             => p_PAC_Cost_Type_ID
    ,p_PAC_Cost_Group_ID            => p_PAC_Cost_Group_ID
    ,p_TRANSACTION_ID               => p_TRANSACTION_ID
    ,p_POrct                        => p_POrct
    ,p_OSP_txn                      => p_OSP_txn
    ,p_Job_ID                       => p_Job_ID
    ,p_po_header_id                 => p_po_header_id
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;