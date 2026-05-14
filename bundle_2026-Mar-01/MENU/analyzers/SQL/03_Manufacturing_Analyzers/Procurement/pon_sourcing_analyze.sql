REM $Id: pon_sourcing_analyze.sql, 200.24 2026/01/27 13:34:25 dfelton Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    pon_sourcing_analyze.sql                                               |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the pon_sourcing_analyzer_pkg.main procedure     |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: Procurement Sourcing Analyzer
REM
REM MENU_START
REM
REM SQL: Run Procurement Sourcing Analyzer
REM FNDLOAD: Load Procurement Sourcing Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Procurement Sourcing Analyzer Help [Doc ID: 2327735.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs pon_sourcing_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Procurement Sourcing Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "All Reports"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: PO_TOP
REM PROG_NAME: PONANALYZERAZ
REM DEF_REQ_GROUP: All Reports
REM PROG_TEMPLATE: POPONANALYZERAZ.ldt
REM
REM PROD_SHORT_NAME: PO
REM CP_FILE: 
REM APP_NAME: Purchasing
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM pon_sourcing_analyzer.sql
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
PROMPT Submitting Procurement Sourcing Analyzer...

PROMPT ===========================================================================
PROMPT Enter the Negotiation number (without Round or Amendment suffix) for the Sourcing negotiation to analyze.  If blank, no Negotiation details will be gathered. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_negotiation_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Negotiation number (without Round or Amendment suffix): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Round number for the specified negotiation to limit the output to be relevant for this specific round. If blank, data for all rounds will be gathered. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_round_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Round number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Line number for the specified Negotiation to limit the output to be relevant for this specific negotiation line.  If blank, data for all lines will be gathered. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_line_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Negotiation Line number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Bid / Quote number for the Sourcing negotiation to limit the output to be relevant for this specific bid / quote.  If blank, data for all bid / quote responses will be gathered.  (NOTE:  Bid number takes precedence over Supplier) 
PROMPT ===========================================================================
PROMPT
ACCEPT p_bid_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Bid / Quote number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the Bid / Quote Line number for the specified Bid / Quote to limit the output to be relevant for this specific bid / quote line.  If blank, data for all bid / quote lines will be gathered. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_bid_line_number NUMBER  DEFAULT '-1' PROMPT 'Enter the Bid / Quote Line number: '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the full or partial supplier name for a supplier that has submitted a bid(s) to limit the output to be relevant for bids submitted by the matching supplier(s).   If blank, data for all suppliers will be gathered. 
PROMPT ===========================================================================
PROMPT
ACCEPT p_bidding_supplier CHAR   PROMPT 'Enter the Supplier (partial or full supplier name): '
PROMPT
PROMPT ===========================================================================
PROMPT Enter the maximum number of rows to display on row limited queries [20] 
PROMPT ===========================================================================
PROMPT
ACCEPT p_max_output_rows NUMBER  DEFAULT '20' PROMPT 'Enter the Maximum Rows to Display: '
PROMPT
PROMPT
DECLARE
   p_negotiation_number           NUMBER         := '~p_negotiation_number';
   p_round_number                 NUMBER         := '~p_round_number';
   p_line_number                  NUMBER         := '~p_line_number';
   p_bid_number                   NUMBER         := '~p_bid_number';
   p_bid_line_number              NUMBER         := '~p_bid_line_number';
   p_bidding_supplier             VARCHAR2(240)  := '~p_bidding_supplier';
   p_max_output_rows              NUMBER         := '~p_max_output_rows';

BEGIN

IF p_negotiation_number = -1 THEN
   p_negotiation_number := NULL;
END IF;
IF p_round_number = -1 THEN
   p_round_number := NULL;
END IF;
IF p_line_number = -1 THEN
   p_line_number := NULL;
END IF;
IF p_bid_number = -1 THEN
   p_bid_number := NULL;
END IF;
IF p_bid_line_number = -1 THEN
   p_bid_line_number := NULL;
END IF;

   pon_sourcing_analyzer_pkg.main(
     p_negotiation_number           => p_negotiation_number
    ,p_round_number                 => p_round_number
    ,p_line_number                  => p_line_number
    ,p_bid_number                   => p_bid_number
    ,p_bid_line_number              => p_bid_line_number
    ,p_bidding_supplier             => p_bidding_supplier
    ,p_max_output_rows              => p_max_output_rows
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;