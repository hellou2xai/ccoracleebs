REM $Id: drop_osn_setup_analyzer_directory_object.sql, 200.1 2016/02/15 08:47:05 jeff.mccall@oracle.com Exp $
REM +====================================================================================+
REM |                 Copyright (c) 2001 Oracle Corporation                              |
REM |                    Redwood Shores, California, USA                                 |
REM |                         All rights reserved.                                       |
REM +====================================================================================+
REM |                                                                                    |
REM | FILENAME                                                                           |
REM |    drop_osn_setup_analyzer_directory_object.sql                                    |
REM |                                                                                    |
REM | DESCRIPTION                                                                        |
REM |    If needed, SQL to drop directory object used for OSN                            |
REM |                                                                                    |
REM |                                                                                    |
REM |  IMPORTANT NOTE:  The directory object is a logical alias for physical directory   |
REM |                   path name on the operating system. This SQL needs to be          |
REM |                   run as the SYSTEM user as it is owned by SYS.                    |
REM |                                                                                    |
REM +====================================================================================+

DROP DIRECTORY OSN_SETUP_ANALYZER_DIRECTORY;