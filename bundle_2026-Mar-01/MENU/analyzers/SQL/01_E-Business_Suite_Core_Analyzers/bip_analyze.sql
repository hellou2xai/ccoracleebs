REM $Id: bip_analyze.sql, 200.55 2026/02/25 16:18:02 dterrell Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    bip_analyze.sql                                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    Wrapper SQL to submit the ebs_bip_analyzer_pkg.main procedure          |
REM |                                                                           |
REM | HISTORY                                                                   |
REM |                                                                           |
REM +===========================================================================+
REM
REM ANALYZER_BUNDLE_START
REM
REM COMPAT: 12.0 12.1 12.2
REM
REM MENU_TITLE: BIP for EBS Analyzer
REM
REM MENU_START
REM
REM SQL: Run BIP for EBS Analyzer
REM FNDLOAD: Load BIP for EBS Analyzer as a Concurrent Program
REM
REM MENU_END
REM
REM
REM HELP_START
REM
REM  BIP for EBS Analyzer Help [Doc ID: 2032715.1]
REM
REM  Compatible with: [12.0|12.1|12.2]
REM
REM  Explanation of available options:
REM
REM    (1) Runs bip_analyze.sql as APPS user to create an HTML report
REM
REM    (2) Install BIP for EBS Analyzer as Concurrent Program
REM        o Runs FNDLOAD as APPS
REM        o Defines the analyzer as a concurrent executable/program
REM        o Adds the analyzer to default request group: "XML Publisher Request Set"
REM
REM HELP_END
REM
REM FNDLOAD_START
REM
REM PROD_TOP: XDO_TOP
REM PROG_NAME: BIP
REM DEF_REQ_GROUP: XML Publisher Request Set
REM PROG_TEMPLATE: BIPAZ.ldt
REM
REM PROD_SHORT_NAME: XDO
REM CP_FILE: 
REM APP_NAME: XML Publisher
REM
REM FNDLOAD_END
REM
REM DEPENDENCIES_START
REM
REM bip_analyzer.sql
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
PROMPT Submitting BIP for EBS Analyzer...

PROMPT
DECLARE

BEGIN


   ebs_bip_analyzer_pkg.main(
  );

EXCEPTION WHEN OTHERS THEN
  dbms_output.put_line('Error encountered: '||sqlerrm);

END;
/
exit;