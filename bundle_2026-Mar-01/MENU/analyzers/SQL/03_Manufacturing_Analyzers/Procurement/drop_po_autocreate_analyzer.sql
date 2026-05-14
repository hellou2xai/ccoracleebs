REM $Id: drop_po_autocreate_analyzer.sql, 200.54 2026/01/28 14:27:51 loinonen Exp $
REM +===========================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                     |
REM |                          Austin, Texas, USA                               |
REM |                         All rights reserved.                              |
REM +===========================================================================+
REM |                                                                           |
REM | FILENAME                                                                  |
REM |    drop_po_autocreate_analyzer.sql                                        |
REM |                                                                           |
REM | DESCRIPTION                                                               |
REM |    If needed, SQL to drop package used for Procurement Autocreate Analyzer|
REM |                                                                           |
REM |                                                                           |
REM | IMPORTANT NOTE:  Make sure to disable concurrent request if analyzer has  |
REM | been setup to run as concurrent program.                                  |
REM |                                                                           |
REM +===========================================================================+

DROP PACKAGE po_autocreate_analyzer_pkg;