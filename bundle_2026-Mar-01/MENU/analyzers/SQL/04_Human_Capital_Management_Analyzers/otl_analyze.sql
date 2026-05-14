REM $Id: otl_analyze.sql, 200.105 2026/01/29 08:10:37 siionesc Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    otl_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the otl_analyzer_pkg.main procedure              |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 11i 12.0 12.1 12.2
REM
REM MENU_TITLE: Oracle Time and Labor (OTL) Analyzer
REM
REM MENU_START
REM
REM SQL: Run Oracle Time and Labor (OTL) Analyzer
REM FNDLOAD: Load Oracle Time and Labor (OTL) Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  Oracle Time and Labor (OTL) Analyzer Help [Doc ID: 1580490.1]
REM
REM  Compatible with: [11i|12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs otl_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install Oracle Time and Labor (OTL) Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "OTLR Reports and Processes"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: HXT_TOP
REM PROG_NAME: OTL_ANALYZE
REM DEF_REQ_GROUP: OTLR Reports and Processes
REM PROG_TEMPLATE: OTLAZ.ldt
REM PROG_TEMPLATE_11i: OTLAZ_11i.ldt
REM PROD_SHORT_NAME: HXT
REM CP_FILE: 
REM APP_NAME: Time and Labor
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM otl_analyzer.sql
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
PROMPT Submitting Oracle Time and Labor (OTL) Analyzer...

PROMPT ===========================================================================
PROMPT Output your OTL Product Technical Information 
PROMPT ===========================================================================
PROMPT
ACCEPT l_technical CHAR  DEFAULT 'Y' PROMPT 'Enter the Do you want to output your OTL Product Technical Information (y/n): '
PROMPT
PROMPT ===========================================================================
PROMPT Do you want to output your OTL Setup Analyzer? 
PROMPT ===========================================================================
PROMPT
ACCEPT l_setup CHAR  DEFAULT 'Y' PROMPT 'Enter the Do you want to output your OTL Setup Analyzer? (y/n): '
PROMPT
PROMPT ===========================================================================
PROMPT Output an HXC (Self Service, Timekeeper, API) Timecard Data 
PROMPT ===========================================================================
PROMPT
ACCEPT l_hxc CHAR  DEFAULT 'Y' PROMPT 'Enter the Do you want to output an HXC (Self Service/Timekeeper/API) Timecard Data? (y/n): '
PROMPT
PROMPT ===========================================================================
PROMPT Provide Person ID of the affected Timecard owner (if not needed 0) 
PROMPT ===========================================================================
PROMPT
ACCEPT l_person NUMBER  DEFAULT '0' PROMPT 'Enter the Person ID of the affected Timecard owner (if not needed 0): '
PROMPT
PROMPT ===========================================================================
PROMPT Provide Start Date of the affected Timecard (use format 12-MAR-2019):   
PROMPT ===========================================================================
PROMPT
ACCEPT l_t_date DATE FORMAT 'DD-MON-YYYY' DEFAULT '31-DEC-9999' PROMPT 'Enter the Start Date of the affected Timecard (use format  12-MAR-2019) [DD-MON-YYYY]: '
PROMPT
PROMPT ===========================================================================
PROMPT Output also the Timecard Owners Preferences 
PROMPT ===========================================================================
PROMPT
ACCEPT l_pref CHAR  DEFAULT 'Y' PROMPT 'Enter the Do you want to output the Timecard Owners Preferences (y/n): '
PROMPT
PROMPT ===========================================================================
PROMPT Output an HXT (OTLR/PUI) Timecard Data 
PROMPT ===========================================================================
PROMPT
ACCEPT l_hxt CHAR  DEFAULT 'Y' PROMPT 'Enter the Do you want to output an HXT (OTLR/PUI) Timecard Data (y/n): '
PROMPT
PROMPT ===========================================================================
PROMPT Provide tim_id(hxt_timecards_f.id) of the affected Timecard (if not needed 0) 
PROMPT ===========================================================================
PROMPT
ACCEPT l_hxt_id NUMBER  DEFAULT '0' PROMPT 'Enter the Tim_id(hxt_timecards_f.id) of the affected Timecard (if not needed 0): '
PROMPT
PROMPT ===========================================================================
PROMPT Output a specific Batch Information 
PROMPT ===========================================================================
PROMPT
ACCEPT l_batch CHAR  DEFAULT 'Y' PROMPT 'Enter the Do you want to output a specific Batch Information (y/n): '
PROMPT
PROMPT ===========================================================================
PROMPT Provide batch_id of the required Batch (if not needed 0) 
PROMPT ===========================================================================
PROMPT
ACCEPT l_batch_id NUMBER  DEFAULT '0' PROMPT 'Enter the Batch_id of the required Batch (if not needed 0): '
PROMPT
PROMPT
DECLARE
   l_technical                    VARCHAR2(240)  := '~l_technical';
   l_setup                        VARCHAR2(240)  := '~l_setup';
   l_hxc                          VARCHAR2(240)  := '~l_hxc';
   l_person                       NUMBER         := '~l_person';
   l_t_date                       DATE           := to_date('~l_t_date','DD-MON-YYYY');
   l_pref                         VARCHAR2(240)  := '~l_pref';
   l_hxt                          VARCHAR2(240)  := '~l_hxt';
   l_hxt_id                       NUMBER         := '~l_hxt_id';
   l_batch                        VARCHAR2(240)  := '~l_batch';
   l_batch_id                     NUMBER         := '~l_batch_id';

BEGIN

IF l_t_date = to_date('31-DEC-9999','DD-MON-YYYY') THEN
   l_t_date := NULL;
END IF;
IF l_t_date IS NULL THEN
   l_t_date := sysdate;
END IF;


   otl_analyzer_pkg.main(
     l_technical                    => l_technical
    ,l_setup                        => l_setup
    ,l_hxc                          => l_hxc
    ,l_person                       => l_person
    ,l_t_date                       => l_t_date
    ,l_pref                         => l_pref
    ,l_hxt                          => l_hxt
    ,l_hxt_id                       => l_hxt_id
    ,l_batch                        => l_batch
    ,l_batch_id                     => l_batch_id
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;