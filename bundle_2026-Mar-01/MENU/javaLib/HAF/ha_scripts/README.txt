## $Header: README.txt $
## Version: 1.0
## Date: 10-Dec-2024
##
## +===========================================================================+
## |  Copyright (c) 2024 Oracle Corporation, Redwood Shores, California, USA   |
## |                        All rights reserved                                |
## |                       Applications  Division                              |
## +===========================================================================+
## |
## | FILENAME
## |   README.txt
## |
ABOUT:

The EBS Database Parameter Checker (EDBPC) maps missing or incorrectly set 
database parameters on your EBS Release 12.2 system to the recommended parameters listed 
in My Oracle Support Knowledge <Document 396009.1>, Database Initialization Parameters for 
Oracle E-Business Suite Release 12, and displays them in a database parameter validation 
summary report.
Oracle highly recommends using this utility to ensure that all required database parameters 
have been set correctly in your EBS database.


Key Points:
Before you start using the EBS Database Parameter Checker (EDBPC), 
review the following points for important guidance:

Always use the latest version of the EDBPC, as older versions will not 
check recently introduced database parameters as present in My Oracle Support Knowledge 
<Document 396009.1>, Database Initialization Parameters for Oracle E-Business Suite Release 12.

You should run the utility periodically and include doing so as part of your regular database 
maintenance or upgrade operations.

Always try out suggestions against a test instance before applying them to a production instance.

It is safe to run the utility against production instances to generate a validation report, and ALTER 
scripts of the environment for a specific instance. This is because no DML is used in the utility script, 
and no ALTER commands are automatically run as part of the utility execution.


USAGE:

Interactive Mode:

perl EDBPC.pl
 -dbcontextfile=<Complete path to the database context file>
 -promptmsg=<Show prompt for credentials>

## | NOTES
## |
## | dbcontextfile    : - This argument is used to specify the location of the
## |                      database context file
## |
## |
## |
## | promptmsg        : - This argument is used to specify whether the credentials
## |                      are passed as command line arguments or should be prompted
## |
## |                    - By default credentials will be prompted. To change this
## |                      behavior need to pass the value "hide"

Non-interactive mode:

perl EDBPC.pl -dbcontextfile=<Database context file name with full path>

RESULT:

Running the utility will create a zip file in the same directory where the scripts are located, 
with a name in the format EDBPC_<$GLOBAL_TIMESTAMP>_<$HOSTNAME>.zip.

EDBPC_Report.html 	            : Overall database initialization parameter validation report.
alter_sql_cdb.sql 	            : Generated SQL file that will contain ALTER statements for all 
                                 CDB$ROOT container parameters that failed validation. You must 
                                 review this script before running.
alter_sql_pdb.sql 	            : Generated SQL file will contain ALTER statements for all PDB 
                                 parameters that failed validation. You must review 
                                 this script before running.
EDBPC.log 	                    : Log file that will contain records of the entire run of this 
                                 validation utility, and can be used for checking any errors or exceptions.