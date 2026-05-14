REM $Id: drop_po_encumbrance_analyzer.sql, 200.18 2026/02/23 22:24:20 pksethi Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    drop_po_encumbrance_analyzer.sql                                       |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    If needed, SQL to drop package used for Procurement Encumbrance        |
REM | Accounting Analyzer                                                       |
REM |                                                                           |
REM |                                                                           |
REM | IMPORTANT NOTE:  Make sure to disable concurrent request if analyzer has  |
REM | been setup to run as concurrent program.                                  |
REM |                                                                           |
REM +===========================================================================+

DROP PACKAGE po_enc_analyzer_pkg;