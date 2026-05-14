REM $Id: drop_eam_conf_analyzer.sql, 200.30 2026/01/28 12:51:55 dbuteica Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    drop_eam_conf_analyzer.sql                                             |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    If needed, SQL to drop package used for EAM Configuration Analyzer     |
REM |                                                                           |
REM |                                                                           |
REM | IMPORTANT NOTE:  Make sure to disable concurrent request if analyzer has  |
REM | been setup to run as concurrent program.                                  |
REM |                                                                           |
REM +===========================================================================+

DROP PACKAGE eam_conf_analyzer_pkg;