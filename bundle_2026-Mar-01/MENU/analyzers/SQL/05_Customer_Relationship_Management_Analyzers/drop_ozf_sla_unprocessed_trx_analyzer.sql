REM $Id: drop_ozf_sla_unprocessed_trx_analyzer.sql, 200.23 2026/01/28 16:19:17 svedula Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    drop_ozf_sla_unprocessed_trx_analyzer.sql                              |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    If needed, SQL to drop package used for Channel Revenue Management (   |
REM | ChRM) SLA Unprocessed Transactions Analyzer                               |
REM |                                                                           |
REM |                                                                           |
REM | IMPORTANT NOTE:  Make sure to disable concurrent request if analyzer has  |
REM | been setup to run as concurrent program.                                  |
REM |                                                                           |
REM +===========================================================================+

DROP PACKAGE ozf_sla_trx_analyzer_pkg;