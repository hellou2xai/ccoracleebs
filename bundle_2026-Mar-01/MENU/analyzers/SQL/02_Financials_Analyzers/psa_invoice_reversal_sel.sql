REM $Id: psa_invoice_reversal_sel.sql,v 200.5 2016/05/16 20:00:14 alumpe Exp alumpe $
REM +=========================================================================+
REM |                Copyright (c) 2013 Oracle Corporation
REM |                   Redwood Shores, California, USA
REM |                        All rights reserved.
REM +=========================================================================+
REM |  Name 
REM |       psa_invoice_reversal_sel.sql
REM | 
REM |  Issue Detail: 
REM |       Script to populate all the impacted invoices.
REM |  
REM |  Script Type:
REM |       Selection
REM |
REM |
REM |  Datafix Type:
REM |       One time datafix
REM |  
REM |  Functional Impact :
REM |       Incorrect encumbrance accounting
REM |
REM |  CrossProduct Impact :
REM |       Undo accounting needs to be done for fixing the impacted 
REM |       transactions. This means that current journals for the selected 
REM |       events will be reversed and the events will set to unaccounted 
REM |       status.
REM |
REM |  List of steps/verification before datafix:
REM |       1. Execute below ACTION PLAN ON TEST INSTANCE and if issue RESOLVED move it to PRODUCTION.
REM |       2. Apply patch before applying this generic fix 
REM |          14563642:R12.PSA.A (12.0.0 or higher)  OR 19266556:R12.PSA.B (12.1.1 or higher)
REM |                 
REM |       3. Please have the pre-req patch 14082924 applied which contains all 
REM |        latest undo accounting code from AP and XLA..
REM |  
REM |  List of steps/verification after datafix:
REM |       Revalidate and reaccount the Invoices.
REM |       Rerun the selection script to ensure there are no more records 
REM |       with missing info
REM |       
REM |  Version History:
REM |       1. Created by YANASING
REM |
REM |
REM +=========================================================================+

WHENEVER SQLERROR CONTINUE;

DROP TABLE psa_invoice_reversal_drv;

CREATE TABLE psa_invoice_reversal_drv
AS
(SELECT  ai.Invoice_ID,
                ai.Invoice_type_lookup_code,
                ai.Invoice_date,
                ai.Invoice_Amount,
                d.invoice_line_number,
                d.distribution_line_number,
                d.invoice_distribution_id,
                d.amount,
                d.base_amount,
                d.match_status_flag,
                d.encumbered_flag,
                d.posted_flag,
                d.bc_event_id,
                d.accounting_event_id event_id,
                d.org_id,
                d.set_of_books_id,
                'Y' process_flag
			FROM xla_events e , 
			xla_transaction_entities_upg xt,
      ap_invoice_distributions_all d,
				ap_invoices_all ai
			WHERE
			 e.entity_id =  xt.entity_id
			AND xt.application_id = 200  
			AND xt.source_id_int_1 = ai.invoice_id            
			AND budgetary_control_flag = 'Y' 
			AND process_status_code= 'P' 
			AND xt.entity_code = 'AP_INVOICES' 
			AND d.invoice_id = xt.source_id_int_1   
			AND d.encumbered_flag = 'N'
			AND bc_event_id = e.event_id  
UNION
      SELECT  ai.Invoice_ID,
                ai.Invoice_type_lookup_code,
                ai.Invoice_date,
                ai.Invoice_Amount,
                aid2.invoice_line_number,
                aid2.distribution_line_number,
                aid2.invoice_distribution_id,
                aid2.amount,
                aid2.base_amount,
                aid2.match_status_flag,
                aid2.encumbered_flag,
                aid2.posted_flag,
                aid2.bc_event_id,
                aid2.accounting_event_id event_id,
                aid2.org_id,
                aid2.set_of_books_id,
                'Y' process_flag
			FROM  xla_events eve,
			ap_invoice_distributions_all aid1,                   
			ap_invoice_distributions_all aid2,
			 ap_invoices_all ai
			WHERE eve.event_id = aid2.bc_event_id
			AND aid2.encumbered_flag = 'Y'
			AND aid1.parent_reversal_id = aid2.invoice_distribution_id
			AND aid1.encumbered_flag = 'R'
			AND aid1.invoice_id = aid2.invoice_id  
			AND ai.invoice_id = aid1.invoice_id
  UNION
          select  ai.Invoice_ID,
                ai.Invoice_type_lookup_code,
                ai.Invoice_date,
                ai.Invoice_Amount,
                aid2.invoice_line_number,
                aid2.distribution_line_number,
                aid2.invoice_distribution_id,
                aid2.amount,
                aid2.base_amount,
                aid2.match_status_flag,
                aid2.encumbered_flag,
                aid2.posted_flag,
                aid2.bc_event_id,
                aid2.accounting_event_id event_id,
                aid2.org_id,
                aid2.set_of_books_id,
                'Y' process_flag
			FROM  xla_events eve,
			ap_invoice_distributions_all aid1,                   
			ap_invoice_distributions_all aid2,
			ap_invoices_all ai 
			WHERE eve.event_id = aid1.bc_event_id
			AND aid1.encumbered_flag = 'Y'
			AND aid1.parent_reversal_id = aid2.invoice_distribution_id
			AND aid2.encumbered_flag = 'R'
			AND aid1.invoice_id = aid2.invoice_id  
			AND aid1.invoice_id = ai.invoice_id
  UNION
     select  ai.Invoice_ID,
                ai.Invoice_type_lookup_code,
                ai.Invoice_date,
                ai.Invoice_Amount,
                d.invoice_line_number,
                d.distribution_line_number,
                d.invoice_distribution_id,
                d.amount,
                d.base_amount,
                d.match_status_flag,
                d.encumbered_flag,
                d.posted_flag,
                d.bc_event_id,
                d.accounting_event_id event_id,
                d.org_id,
                d.set_of_books_id,
                'Y' process_flag  
			FROM xla_events e , 
			xla_transaction_entities_upg xt,
      ap_invoice_distributions_all d,
				ap_invoices_all ai
			WHERE	 e.entity_id =  xt.entity_id
			AND xt.application_id = 200  
			AND xt.source_id_int_1 = ai.invoice_id            
			AND budgetary_control_flag = 'Y'
			AND process_status_code= 'U' 
			AND xt.entity_code = 'AP_INVOICES'
			AND d.invoice_id = xt.source_id_int_1   
			AND d.encumbered_flag = 'Y'  
			AND bc_event_id = e.event_id  
UNION
SELECT   ai.Invoice_ID, 
          ai.Invoice_type_lookup_code,
                ai.Invoice_date,
                ai.Invoice_Amount,
                aid2.invoice_line_number,
                aid2.distribution_line_number,
                aid2.invoice_distribution_id,
                aid2.amount,
                aid2.base_amount,
                aid2.match_status_flag,
                aid2.encumbered_flag,
                aid2.posted_flag,
                aid2.bc_event_id,
                aid2.accounting_event_id event_id,
                aid2.org_id,
                aid2.set_of_books_id,
                'Y' process_flag       
from ap_invoice_distributions_all aid2,
ap_invoices_all ai
where ai.invoice_id=aid2.invoice_id
and aid2.invoice_id in( select invoice_id  from  
			(SELECT a.invoice_id,
			ah.event_type_code 
			FROM xla_ae_lines l,                    
			xla_ae_headers ah,
			xla_transaction_entities_upg xt,                     
			xla_events e,
			ap_invoices_all a         
			WHERE 
			l.ae_header_id = ah.ae_header_id
			AND ah.entity_id =  xt.entity_id
			AND a.invoice_id = xt.source_id_int_1 
			AND xt.application_id = 200                  
			AND xt.entity_code = 'AP_INVOICES'
			AND ah.application_id = 200                   
			AND ah.balance_type_code = 'E' 
			AND e.process_status_code = 'P'                  
			AND e.event_status_code = 'P' 
			AND e.entity_id = xt.entity_id                  
			AND l.accounting_class_code not in ( 'RFE','PURCHASE_ORDER')                  
			AND ap_invoices_utility_pkg.get_posting_status(a.invoice_id) = 'Y'              
			GROUP BY a.invoice_id,ah.event_type_code              
			HAVING Sum(nvl(l.accounted_dr,0)) <>sum(nvl(l.accounted_cr,0))) )
      );


PROMPT ________________________________________________________
PROMPT Driver table psa_invoice_reversal_drv created with problematic transactions
PROMPT with incorrect encumbrance accounting.
PROMPT   
PROMPT REVIEW the transactions and update process_flag to N for
PROMPT transactions for which fix should not be executed.
PROMPT   
PROMPT Use below update statement to update the process_flag.
PROMPT UPDATE psa_invoice_reversal_drv
PROMPT   SET process_flag = 'N'
PROMPT  WHERE invoice_id = enter_invoice_id;
PROMPT  
PROMPT Apply patch 13602149:R12.AP.A/AP.B before applying this generic fix 
PROMPT   
PROMPT Run the following script to undo accounting
PROMPT ( FIRST ON TEST instance and issue RESOLVED apply on PRODUCTION)
PROMPT http://www-apps.us.oracle.com/~vasvenka/df2support/ap_mass_inv_undo.sql
PROMPT
PROMPT When prompted for parameters enter:
PROMPT P_DRIVER_TABLE        : PSA_INVOICE_REVERSAL_DRV
PROMPT P_USER_NAME           : A Valid Application user name.
PROMPT P_RESPONSIBILITY_NAME : A valid Payables Responsibility Name
PROMPT (Case Sensitive) associated to the user entered. 
PROMPT
PROMPT If invoice is revalidation status, please validate and 
PROMPT then account the invoice.
PROMPT Rerun the create accounting process.
PROMPT For any issues with UNDO accounting,please review following checklist
PROMPT
PROMPT http://www-apps.us.oracle.com/~gagrawal/undo_transfer_checklist.txt
PROMPT 
PROMPT If still the issue is not resolved, collect and upload following to SR:
PROMPT  1. FND log
PROMPT  2. AP List
PROMPT  3. PSA Diagnostics
PROMPT ________________________________________________________
