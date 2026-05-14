REM $Id: ozf_sla_unprocessed_trx_analyze.sql, 200.23 2026/01/28 16:19:17 svedula Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    ozf_sla_unprocessed_trx_analyze.sql                                    |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ozf_sla_trx_analyzer_pkg.main procedure      |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.1 12.2
REM
REM MENU_TITLE: Channel Revenue Management (ChRM) SLA Unprocessed Transactions Analyzer
REM
REM MENU_START
REM
REM SQL: Run Channel Revenue Management (ChRM) SLA Unprocessed Transactions Analyzer
REM FNDLOAD: Load Channel Revenue Management (ChRM) SLA Unprocessed Transactions Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Channel Revenue Management (ChRM) SLA Unprocessed Transactions Analyzer Help [Doc ID: 2058083.1]
REM
REM  Compatible with: [12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs ozf_sla_unprocessed_trx_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Channel Revenue Management (ChRM) SLA Unprocessed Transactions Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "Trade Management Request Group"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: OZF_TOP
REM PROG_NAME: OZFSLATRN
REM DEF_REQ_GROUP: Trade Management Request Group
REM PROG_TEMPLATE: OZFSLAAZ.ldt
REM
REM PROD_SHORT_NAME: OZF
REM CP_FILE: 
REM APP_NAME: Trade Management
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM ozf_sla_unprocessed_trx_analyzer.sql
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
PROMPT Submitting Channel Revenue Management (ChRM) SLA Unprocessed Transactions Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Ledger Id.  This parameter is required. This parameter is required.
PROMPT ===========================================================================
PROMPT
ACCEPT p_ledger_id NUMBER  DEFAULT '-1' PROMPT 'Enter the Ledger Id: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the End Date in 'DD-MON-YYYY' format 
PROMPT ===========================================================================
PROMPT
ACCEPT p_end_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the End Date [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_ledger_id                    NUMBER         := '~p_ledger_id';
   p_end_date                     DATE           := to_date('~p_end_date','DD-MON-YYYY');
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_ledger_id = -1 THEN
   p_ledger_id := NULL;
END IF;
IF p_end_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   p_end_date := NULL;
END IF;
IF p_end_date IS NULL THEN
   p_end_date := sysdate;
END IF;


   ozf_sla_trx_analyzer_pkg.main(
     p_ledger_id                    => p_ledger_id
    ,p_end_date                     => p_end_date
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;