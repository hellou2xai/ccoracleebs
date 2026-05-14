REM $Id: drop_configurator_analyzer.sql, 200.31 2026/01/27 20:44:36 cschmehl Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    drop_configurator_analyzer.sql                                         |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    If needed, SQL to drop package used for Configurator Analyzer          |
REM |                                                                           |
REM |                                                                           |
REM | IMPORTANT NOTE:  Make sure to disable concurrent request if analyzer has  |
REM | been setup to run as concurrent program.                                  |
REM |                                                                           |
REM +===========================================================================+

DROP PACKAGE cz_analyzer_pkg;