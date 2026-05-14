#
## $Header: EDBPC.pl Version 1.0 2024/12/10 debasmis jdiaz ssasahoo adssriva $
#############################
# UTILITY VERSION CONTROL ######
#############################
my $toolVersion = "1.0";
my $toolDate    = "10-Dec-2024";
#############################
##
## +===========================================================================+
## |  Copyright (c) 2024 Oracle Corporation, Redwood Shores, California, USA   |
## |                        All rights reserved                                |
## |                       Applications  Division                              |
## +===========================================================================+
## |
## | FILENAME
## |   EDBPC.pl
## |
## | DESCRIPTION
## |   Script to generate the SQL file to set database parameters
## |
## | USAGE:
## |    perl EDBPC.pl
## |              -dbcontextfile=<context file name with complete path>
## |              -promptmsg=<Show prompt for credentials>
## |
## | VERSION HISTORY:
## |       VER              CHANGED BY                              DATE                  COMMENT
## | ==============================================================================================================
## |       1.0              debasmis jdiaz ssasahoo adssriva        10 Dec 2024            First version
## |
## |
## | PLATFORM
## |   Generic
## |
## | NOTES
## |
## | dbcontextfile    : - This argument is used to specify the context file with its
## |                      complete path
## |
## | promptmsg        : - This argument is used to specify whether the credentials
## |                      are passed as command line arguments or should be prompted
## |
## |                    - By default credentials will be prompted. To change this
## |                      behavior need to pass the value "hide"
## |
## |
## |
#

use strict;
use English;
use Carp;
use lib './';

require 5.005;

############################
## Package Specific Modules
#############################
use TXK::ARGS();
use TXK::Error();
use TXK::FileSys();
use TXK::OSD();
use TXK::Process();
use TXK::Restart();
use TXK::Runtime();
use TXK::Techstack();
use TXK::TechstackDB();
use TXK::Util();
use TXK::XML();
use ADX::util::Sysutil();
#
################################
## Forward method declarations
################################
#
sub getCmdLineArgValue;            #To get command Line Arguments
sub getAppsPass;                   #To get Apps password - Not implemented so far
sub getSysPass;                    #To get Sys password - Not implemented so far
sub logMessage;                    #this to print log messages in log file
sub validateContextFile;           # This validates contextfile if the provided input is correct or not
sub getCtxValue;                   #This is to read data from context file by passing proper tag
sub isMultiTenant;                 #to check if it is single-multi tenant. Not required as our scope is 19c onwards now.
sub executeSQLFile;                #this executes the SQL file created.
sub generateDBParamSQLFile;        #this is to generate the SQL file by appending proper SQLs
sub checkFileExists;               #to validate if a file exists or not
sub removeFile;                    #to remove a file after its usage for security purpose
sub removeDirectory;               #to remove a directory
sub loadFileContent;               #this will load files into perl arrays
sub parameterValidation;           #This is the MAIN LOGIC of validation
sub printReport;                   #This is to generate the report.
sub printalterc;                   #print Alter in CDB
sub printalterp;                   #print alter in PDB
sub checkCDBMax;                   #it will check if sum of all PDB values of a param is less than equal to CDB in a particular instance or not
sub isPDBOpen;                     #it will check if PDB is open or not.
sub getParamValue;                 #it will get param value from the provided input
sub eval_param;                    #it will evaluate param used for DERIVED case
##############################
## Command line argument keys
###############################
my $ARGS_PREFIX           = TXK::ARGS::PREFIX;
my $CONTEXT_FILE_KEY      = "dbcontextfile";
my $ORACLE_HOME_KEY       = "dboraclehome";
my $OUTDIR_KEY            = "outdir";
my $PROMPT_MSG_KEY        = "promptmsg";
my $TARGET_DB_VERSION_KEY = "targetdbversion";

##########################################
## Global Variables
##########################################
my $GLOBAL_CONFIG = {};
my $GLOBAL_TIMESTAMP  = TXK::Util->getTimestamp();
   $GLOBAL_TIMESTAMP     =~ s/(\s|:)/_/g;
   $GLOBAL_TIMESTAMP     =~ s/__/_/g;
my @SQL_OUTPUT_ARRAY; #keeps all params first captured from DB and used for further validation
my @SQL_OUTPUT_ARRAY_CP; #it is a copy of SQL_OUTPUT_ARRAY for reference;
my @INPUT_FILE_ARRAY;
my @REMOVE_ARRAY; #It will have all those parameters which is listed as removal section
my @VALIDATION_ARRAY; #it will keep all those are going to printed in validation part
my @ADDITIONAL_PARAMETERS;  #This will keep all nondefault additional params set in env explicitly
my @ADDITIONAL_EVENTS; #it will keep the records of additional parameters for EVENT cases
my @file_contents_rac; #it will contain the records related rac nodes from gvinstance
my $pdbname;
my $dbver;
my $ebsver;
my $rac_value;
my $host_name;
my $valid_env = "Y";
my $host_name = "DUMMY HOST";
my @ADDITIONAL_COMMENT; #this will store all comments for SIZING category validation it can be be used for other comments in future
my @RECOMMENDATION_REMARK; #this will store all comments of parameters recommendation
my $default_string = " "; #this is for printing the default string across the report
my $str_3015099 = "https://support.oracle.com/epmos/faces/DocumentDisplay?id=3015099.1";
my $str_396009 = "https://support.oracle.com/epmos/faces/DocumentDisplay?id=396009.1";
my $str_2528000 = "https://support.oracle.com/epmos/faces/DocumentDisplay?id=2528000.1";
my $db_version_display;
my $append_string = "<small><sup> (1) </sup></small> ";
# -------------------------------------------
# # Variables for Perl Infrastructure objects
# # -------------------------------------------
my $RUNTIME;
my $FSYS = TXK::FileSys->new();
my $PROC = TXK::Process->new();
my $TECHSTACKDB;

# -------------------------
# # Variables for log files
# # -------------------------
my $DEFAULT_OUT_DIR;
my $DEFAULT_OUT_FILE;
my $DEFAULT_RT_ARGS;
my $TEMPORARY_LOG_FILE;
my $SQL_FILE_LOC;
my $SQL_RAC_OUTPUT_LOC;
my $SQL_FILE_RAC_INST;
my $SQL_DB_VERSION;
my $SQL_DB_VERSION_OUTPUT;
my $SQL_OUTPUT_LOC;
my $SQL_REPORT_LOC;
my $ALTER_SQL_CDB;
my $ALTER_SQL_PDB;
my $INIT_FILE_LOC;
my $SQL_FILE_CDBMAX;
my $SQL_OUT_CDBMAX;
my $OS_ZIP_OUT;

# --------------------------
# # Arguments for the script
# # this will handle all the arguments for this script
# # dbcontextfile - Database Context File
# # promptmsg - Argument to pass credentials as command line argument (used as ad txk standard)
# # --------------------------
#

my $ARGS_DEFN = <<ARGS_DEFN;
<?xml version="1.0"?>
<ScriptArgs>
     <arg name="dbcontextfile"
          desc="Database Context File"
          type="String"
          required="Yes"
          prompt="Enter the Context File Name with full path: "
          confirm="No"
          default="" />
     <arg name="promptmsg"
          desc="Argument to pass credentials as command line argument"
          type="String"
          required="No"
          prompt="Show the prompt for credentials <Press ENTER to proceed>:"
          confirm="No"
          default="" />
          </arg>
</ScriptArgs>
ARGS_DEFN

########################################################
## Main - Main Process starts of here
########################################################
print "========================================================================\n";
print "Always use the latest version of the EDBPC.zip, downloaded from Using the Oracle E-Business Suite Database Parameter Checker (EDBPC), My Oracle Support Knowledge Document 3015099.1\n";
print "========================================================================\n";
my $myArgs = TXK::ARGS->new();
$myArgs->validateArgs({ args       => \@ARGV,
                        definition => $ARGS_DEFN,
                        type       => TXK::ARGS::XML_STRING,
                        useprompt  => TXK::Util::TRUE
                     });
my $argHash = $myArgs->getArgTable();
my $prompt_msg = getCmdLineArgValue("$PROMPT_MSG_KEY");
#setting GLOBAL_CONFIG Array with arguments
$GLOBAL_CONFIG->{$CONTEXT_FILE_KEY}      = TXK::OSD->trDirPathToBase($argHash->{$CONTEXT_FILE_KEY});

if (TXK::OSD->isWindows())
{
    $GLOBAL_CONFIG->{'binExt'} = ".exe";
}

# Below code is picking the path of the script that is downloaded in DB server
# The same path will be used to generate the zip output
# $0 shows the filename provided in perl command, getDirName is AD TXK code to give its path
my $code_path = TXK::OSD->getDirName($0);
# If user only uses file name in perl command then set currect directory as default directory
if ($code_path eq $0)
{
    $code_path = ".";
}

#setting default files dir path for execution
$DEFAULT_OUT_DIR  = TXK::OSD->trDirPathToBase($code_path . '/EDBPC_results');
$DEFAULT_OUT_FILE = "EDBPC.log";
$SQL_FILE_LOC     = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "dbparamgen.sql");
$SQL_FILE_RAC_INST= TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "dbracgen.sql");
$SQL_DB_VERSION   = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "dbversiongen.sql");
$SQL_DB_VERSION_OUTPUT   = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "dbversiongen.out");
$SQL_FILE_CDBMAX= TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "dbcdbmax.sql");
$SQL_OUTPUT_LOC   = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "dbparamgen.out");
$SQL_RAC_OUTPUT_LOC   = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "dbracgen.out");
$SQL_OUT_CDBMAX= TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "dbcdbmax.out");
$SQL_REPORT_LOC   = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "EDBPC_Report.html");
$ALTER_SQL_CDB    = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "alter_sql_cdb.sql");
$ALTER_SQL_PDB    = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "alter_sql_pdb.sql");
$INIT_FILE_LOC    = TXK::OSD->trDirPathToBase($code_path . "/" . "inputFile.txt");
$OS_ZIP_OUT       = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "zip_verify.out");

$DEFAULT_RT_ARGS  = { outDir       => $DEFAULT_OUT_DIR,
                      logDir       => $DEFAULT_OUT_DIR,
                      restartDir   => $DEFAULT_OUT_DIR,
                      reportDir    => $DEFAULT_OUT_DIR,
                      useTimestamp => TXK::Util::TRUE,
                      useRestart   => TXK::Util::FALSE,
                      useLog       => TXK::Util::TRUE,
                      recordStdout => TXK::Util::FALSE,
                      logFile      => $DEFAULT_OUT_FILE,
                      hideInitialLogInfo => TXK::Util::TRUE
                    };

$RUNTIME = TXK::Runtime->create($DEFAULT_RT_ARGS);
#

#getAppsPass();
#In our code we may need SYSTEM credential if it run from MT. For that below needs to be uncommented
#getSysPass();
logMessage("\n");
logMessage("Script Name    : EDBPC.pl");
logMessage("Script Version : $toolVersion");
logMessage("Script Date    : $toolDate");
logMessage("Generated on   : " . qx(date));
logMessage("Log File       : " . TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . $DEFAULT_OUT_FILE));

logMessage("\n");
logMessage("-----------");
logMessage("Values used");
logMessage("-----------");
logMessage("Database Context File : " . $GLOBAL_CONFIG->{$CONTEXT_FILE_KEY});
logMessage("OUT Directory         : " . $GLOBAL_CONFIG->{$OUTDIR_KEY});
logMessage("\n");

$FSYS = $RUNTIME->getFileSys();

## validate the Arguments
validateContextFile();

# code should get the PDB name from DB context file and then it should add the con_id as per the same PDB to SELECT query.
# for this we need to access dba_pdbs(con_id) and need to join with gv$system_parameter
$pdbname = getCtxValue('s_pdb_name');
$rac_value = getCtxValue('s_database_type');
if ($rac_value eq "RAC") { $rac_value = "Yes"; } else { $rac_value = "No"; }
$dbver   = getCtxValue('s_database');
$ebsver  = getCtxValue('s_apps_version');
$host_name = getCtxValue('s_dbhost');
logMessage("PDB - $pdbname | RAC - $rac_value | DB Ver - $dbver | EBS ver -  $ebsver");
if ($rac_value eq "Yes") { $rac_value = "RAC"; }

# Report initialization
# variables to create report and sql file handlings
  my $io_1write = TXK::IO->new(); # this is for report html
  my $io_2write = TXK::IO->new(); # this is for alter script of CDB
  my $io_3write = TXK::IO->new(); # # this is for alter script of PDB
  # opening files in mode=1
  my $result1 = $io_1write->open({fileName=>$SQL_REPORT_LOC,mode=>1});
  my $result2 = $io_3write->open({fileName=>$ALTER_SQL_CDB,mode=>1});
  my $result3 = $io_2write->open({fileName=>$ALTER_SQL_PDB,mode=>1});
  $io_2write->print("/* alter_sql_pdb.sql script will contain ALTER statements for all PDB parameters that failed validation. This script must be reviewed by the user before running. \n Note - Parameters having scope as SPFILE will require a database bounce to come into effect. */ \n");
  $io_3write->print("/* alter_sql_cdb.sql script will contain ALTER statements for all CDBROOT container parameters that failed validation. This script must be reviewed by the user before running. \n Note - Parameters having scope as SPFILE will require a database bounce to come into effect. */ \n");
# End Report initialiation

#-----------------------------------------------------------------------------------
# We need to source PDB environment to get all the TXK packages
# After PDB environment is sourced on DB tier, ORACLE_SID/LOCAL will be set to PDB
# With this setting, sysdba connections will connect to IDLE instance
# To avoid, need to reset the ORACLE_SID/LOCAL to CDB so that we can connect to CDB
#
# For non-CDB environments, no impact because of below code as s_instName has
# required SID
#-----------------------------------------------------------------------------------
if (isMultiTenant())
{
    logMessage("DB type is multi-tenant. Re-setting ORACLE_SID.");
    TXK::OSD->setEnvVar({name=>'ORACLE_SID', value=>getCtxValue('s_instName'), translate=>TXK::Util::TRUE});
}

# ====================================================================================================
# G E N E R A T I N G      S Q L      F I L E      A N D     L O A D I N G      I N T O    A R R A Y
# ====================================================================================================
# below sub will create the SQL files to be executed to get system information
generateDBParamSQLFile();
my $sql_exit = executeSQLFile($SQL_FILE_LOC,$SQL_OUTPUT_LOC);
my $sql_exit1= executeSQLFile($SQL_FILE_RAC_INST,$SQL_RAC_OUTPUT_LOC);
my $sql_exit2= executeSQLFile($SQL_DB_VERSION,$SQL_DB_VERSION_OUTPUT);
# Remove the SQL files after being executed
removeFile($SQL_FILE_LOC);
removeFile($SQL_FILE_RAC_INST);
removeFile($SQL_DB_VERSION);
logMessage("EXIT: param SQL : $sql_exit RAC inst SQL: $sql_exit1");
#-------------------------------------------------------------------
# Load the content of SQL output and inputFile  into global arrays
#-------------------------------------------------------------------
loadFileContent();
# Removing Files after loading into arrays
removeFile($SQL_OUTPUT_LOC);
removeFile($SQL_RAC_OUTPUT_LOC);
removeFile($SQL_DB_VERSION_OUTPUT);


# ======================================================
# V A L I D A T I O N    P R O C E S S      S T A R T
# ======================================================
if (isPDBOpen($pdbname) eq "FALSE")
{
    $valid_env = "P";
}
system("zip -L >$OS_ZIP_OUT 2>&1");  # Verifying the ZIP utility existence
if ($? != 0)
{
    $valid_env = "Z";
}
removeFile($OS_ZIP_OUT);
if ($valid_env eq "Y")  # If currect system is compatible then validate
{
    parameterValidation();
    #closing all file pointers
    logMessage("=======================================================================================");
    logMessage("** EDBPC Logging Operation Completed **");
    logMessage("=======================================================================================");    
    $io_1write->close();
    $io_2write->close();
    $io_3write->close();
}
else
{
    $io_1write->close();
    $io_2write->close();
    $io_3write->close();
    removeFile($ALTER_SQL_CDB);
    removeFile($ALTER_SQL_PDB);
    removeFile($SQL_REPORT_LOC);
    if($valid_env eq "F")
    {
        logMessage("===================================================================================================");
        logMessage("========================= S Y S T E M        N O T      S U P P O R T E D =========================");
        logMessage(" ");
        logMessage("Current E-Business Suite Version $ebsver with $dbver is not supported for this Validation Checker Utility");
        logMessage("===================================================================================================");
    }
    elsif($valid_env eq "E")
    {
        logMessage("===================================================================================================");
        logMessage("============================= I S S U E    W I T H   D A T A B A S E ==============================");
        logMessage(" ");
        logMessage("Please check the database, either the database is down or not accessible via sysdba.");
        logMessage("===================================================================================================");
    }
    elsif ($valid_env eq "P")
    {
        logMessage("===================================================================================================");
        logMessage("========================== I S S U E    W I T H   D A T A B A S E (PDB) ============================");
        logMessage(" ");
        logMessage("Please check the database, either the PDB is down or not accessible.");
        logMessage("===================================================================================================");
    }
    elsif ($valid_env eq "Z")
    {
        logMessage("===================================================================================================");
        logMessage("========================== Z I P    U T I L I T Y    N O T    F O U N D ============================");
        logMessage(" ");
        logMessage("zip is not found. Please verify if zip is installed in this environment.");
        logMessage("===================================================================================================");
    }
}

my $zip_name = $DEFAULT_OUT_DIR."_".uc($host_name).".zip";
system("zip -rj $zip_name $DEFAULT_OUT_DIR");
$RUNTIME->close();
#removeDirectory($DEFAULT_OUT_DIR);
print "====================================================================\n";
print "OUTPUT FILE : $zip_name\n";
print "====================================================================\n";

########################################################
# E N D     of      M A I N        Process
########################################################


########################################################
## Definition of sub-programs used in this module
########################################################
#
##################################################################################
## getCmdLineArgValue - Gets the argument value from the command line arguments
##                      Example: -argName=argValue
###################################################################################

sub getCmdLineArgValue
{
    my $argName  = $ARG[0];
    my $argValue = undef;

    $argName = $ARGS_PREFIX . $argName;

    my @argNameFromArgv = grep { /$argName=/ } @ARGV;

    if ( scalar ( @argNameFromArgv ) > 0 )
    {
        $argValue = $argNameFromArgv[0]  if ( $argNameFromArgv[0] =~ s/$argName=// ) ;
    }

    return $argValue;
}

##################################################################################
### getAppsPass - Gets the APPS user credential
####################################################################################
#
sub getAppsPass
{
    my $appspass="";
    if ($prompt_msg eq "hide")
    {
        chomp($appspass= <STDIN>);
    }
    else
    {
        if (!(TXK::OSD->isWindows()))
        {
            system "stty -echo";
        }

        print "Enter the APPS schema password: ";
        chomp($appspass = <STDIN>);
        print "\n";

        if (!(TXK::OSD->isWindows()))
        {
            system "stty echo";
        }
    }

    $appspass =~ s/\s+$//;
    $appspass =~ s/^\s+//;
    $GLOBAL_CONFIG->{'appspass'} = $appspass;
}

##################################################################################
#### getAppsPass - Gets the APPS user credential
#####################################################################################
#
sub getSysPass
{
    my $syspass="";
    if ($prompt_msg eq "hide")
    {
        chomp($syspass= <STDIN>);
    }
    else
    {
        if (!(TXK::OSD->isWindows()))
        {
            system "stty -echo";
        }

        print "Enter the SYSTEM password: ";
        chomp($syspass = <STDIN>);
        print "\n";
        if (!(TXK::OSD->isWindows()))
        {
            system "stty echo";
        }
    }

    $syspass =~ s/\s+$//;
    $syspass =~ s/^\s+//;
    $GLOBAL_CONFIG->{'syspass'} = $syspass;
}

########################################################
## logMessage - Redirects the output to log and console
#########################################################

sub logMessage
{
    my $log_message = $ARG[0];
    $RUNTIME->printStdMsg("$log_message");
}

#############################################################
# validateContextFile - Validates the database context file
#############################################################
sub validateContextFile
{
    logMessage("\n");
    logMessage("==========================");
    logMessage("Validating context file...");
    logMessage("==========================");

    my $result = $FSYS->access({ fileName  => $GLOBAL_CONFIG->{$CONTEXT_FILE_KEY},
                                 type      => TXK::FileSys::FILE,
                                 checkMode => TXK::FileSys::READ_ACCESS
                 });

    if ($result ne TXK::Error::SUCCESS)
    {
        logMessage(TXK::Error->getFormatedErrorMsg($FSYS->getError()));
        TXK::Error->stop($FSYS->getError());
    }

    logMessage("Context file: " .  $GLOBAL_CONFIG->{$CONTEXT_FILE_KEY} . " exists.");
}

#################################################################
# getCtxValue - Reads and verifies values from the context file
#################################################################
sub getCtxValue
{
    my $ctx_var      = $ARG[0];
    my $ctx_type     = $ARG[1];
    my $check        = $ARG[2];
    my $context_file = $GLOBAL_CONFIG->{$CONTEXT_FILE_KEY};

    #-----------------------------------------------------------------------
    # Always load the context file to get the latest variables, since
    # while updating one variable might have caused a derived value to
    # be updated.
    #-----------------------------------------------------------------------
    my $ctx_xml = TXK::XML->new();
    $ctx_xml->loadDocument({file => $context_file});

    my $result = "";

    $result = $ctx_xml->getOAVar($ctx_var);
    $result = TXK::OSD->trDirPathToBase($result);

    if ($check == 1)
    {
        #For extra validation to the result
        if ($result eq "")
        {
            #This is for throwing error if the value is not defined
            logMessage(TXK::Error->getFormatedErrorMsg("$ctx_var is not defined in $context_file."));
            TXK::Error->stop("$ctx_var is not defined in $context_file.");
        }

        if ($ctx_type eq 'd')
        {
            #This is for throwing error to check if the result is a directory or not
            if (! checkDirectoryExists($result))
            {
                logMessage(TXK::Error->getFormatedErrorMsg("The value <$result> for $ctx_var in $context_file isn't a directory."));
                TXK::Error->stop("The value <$result> for $ctx_var in $context_file isn't a directory.");
            }
        }
        elsif ($ctx_type eq 'f')
        {
            #This is for throwing error if the result is a valid file or not
            if (! checkFileExists($result))
            {
                logMessage(TXK::Error->getFormatedErrorMsg("The value <$result> for $ctx_var in $context_file isn't a file."));
                TXK::Error->stop("The value <$result> for $ctx_var in $context_file isn't a file.");
            }
        }
    }
    logMessage("Reading Context for $ctx_var --> $result");
    return $result;
}

############################################################################
# isMultiTenant - check whether the database is multitenant or singletenant
############################################################################
sub isMultiTenant
{
    if (getCtxValue('s_db_tenancy') eq "multi-tenant")
    {
        return 1;
    }

    return 0;
}

##############################################
# executeSQLFile - Executes a SQL given file
##############################################
sub executeSQLFile
{
    logMessage("\n");
    my $sql_output = TXK::OSD->trDirPathToBase($ARG[0]);
    my $sql_output_log = TXK::OSD->trDirPathToBase($ARG[1]);
    logMessage("Inside executeSQLFile.for.$sql_output.");
    logMessage("===============================================");

    $PROC->abortOnError({ enable => TXK::Util::FALSE });

    my $sql_exit = $PROC->run({ command     => 'sqlplus -s /nolog',
                                    arg1        => "\@$sql_output",
                                showCommand => TXK::Util::TRUE,
                                showOutput  => TXK::Util::FALSE,
                                stdout      => $sql_output_log
                            });

    $PROC->abortOnError({ enable => TXK::Util::TRUE });

    return($sql_exit)
}

#######################################################################
# generateDBParamSQLFile - Creates the SQL file to be executed to get
#                          the DB parameters from database
#######################################################################
sub generateDBParamSQLFile
{
    logMessage("\n");
    logMessage("==================================");
    logMessage("Inside generateDBParamSQLFile()...");
    logMessage("==================================");

    #--------------------------------------------------------------------
    # Get the connect string used -- Currently we are using / as sysdba
    #--------------------------------------------------------------------
    my $connect_string = "connect / as sysdba\n";

    #------------------------------------------
    # Initialize different parts of the query
    #------------------------------------------
    my $select_clause = "SELECT vsp.name || '|' || NVL(vsp.value,'NULL') || '|' || NVL(vsp.display_value,'NULL') || '|' || decode (vsp.CON_ID,0,'CDB','PDB') || '|' || vsp.TYPE || '|' || vi.INST_ID || '|' || UPPER(vi.INST_ID) || '-' || UPPER(vi.INSTANCE_NAME)|| '|' || UPPER(vsp.isdefault) || '|' ||UPPER(vsp.ismodified)|| '|' ||UPPER(vsp.DEFAULT_VALUE)";
    my $event_select_clause = "SELECT vsp.name || '|' || NVL(vsp.value,'NULL') || '|' || NVL(vsp.display_value,'NULL') || '|' || decode (vsp.CON_ID,0,'CDB','PDB') || '|' || vsp.TYPE || '|' || vi.INST_ID || '|' || UPPER(vi.INST_ID) || '-' || UPPER(vi.INSTANCE_NAME)|| '|' || UPPER(vsp.isdefault) || '|' ||UPPER(vsp.ismodified)|| '|' ||'NONE'";
    my $from_clause_nonevent = " FROM gv\$system_parameter vsp , gv\$instance vi";
    my $from_clause_event = " FROM gv\$system_parameter2 vsp , gv\$instance vi";
    my $init_where = " WHERE 1 = 1 AND vsp.INST_ID = vi.INST_ID";
    my $cmn_condition = " AND ( vsp.CON_ID IN (SELECT dp.CON_ID FROM DBA_PDBS dp WHERE PDB_NAME ='$pdbname') OR vsp.CON_ID = 0)";
    my $non_event_condition = " AND UPPER(vsp.NAME) <> 'EVENT'";
    my $event_condition = " AND UPPER(vsp.NAME) = 'EVENT'";
    my $order_by = " ORDER BY 1";


    my $sql_query = $select_clause . $from_clause_nonevent . $init_where . $cmn_condition . $non_event_condition . " UNION ALL " . $event_select_clause . $from_clause_event . $init_where . $cmn_condition . $event_condition . $order_by ;

    logMessage("\nParam SQL QUERY -");
    logMessage("$sql_query");

    #---------------------------
    # Generate the SQL content for OUTPUT
    #---------------------------
    my $io_write = TXK::IO->new();
    my $result = $io_write->open({ fileName => $SQL_FILE_LOC,
                             mode => TXK::IO::WRITE
                          });

    $io_write->print($connect_string);
    $io_write->print("set head off;\n");
    $io_write->print("set feedback off;\n");
    $io_write->print("set lines 500;\n");
    $io_write->print("set pages 700;\n");
    $io_write->print($sql_query . ";\n");
    $io_write->print("set head on;\n");
    $io_write->print("exit;\n");
    $io_write->close();

    #to get all RAC node instance names present in DB, this is only for RAC
    #for non-RAC there will be only 1 instance name in DB
    my $sql_instance = "SELECT vi.INST_ID || '-' || UPPER(vi.INSTANCE_NAME) FROM gv\$instance vi ORDER BY 1";
    logMessage("\nRAC instance SQL QUERY -");
    logMessage("$sql_instance");
    #---------------------------
    # Generate the SQL content for RAC
    #---------------------------
    my $io_write_rac = TXK::IO->new();
    my $result1 = $io_write_rac->open({ fileName => $SQL_FILE_RAC_INST,
                             mode => TXK::IO::WRITE
                          });

    $io_write_rac->print($connect_string);
    $io_write_rac->print("set head off;\n");
    $io_write_rac->print("set feedback off;\n");
    $io_write_rac->print("set lines 500;\n");
    $io_write_rac->print("set pages 700;\n");
    $io_write_rac->print($sql_instance . ";\n");
    $io_write_rac->print("set head on;\n");
    $io_write_rac->print("exit;\n");
    $io_write_rac->close();


    my $sql_db_version = "select version_full from gv\$instance where rownum = 1";
    logMessage("\nDB Version SQL QUERY -");
    logMessage("$sql_db_version");
    #---------------------------
    # Generate the SQL content for DB Version
    #---------------------------
    my $io_write_dbv = TXK::IO->new();
    my $result2 = $io_write_dbv->open({ fileName => $SQL_DB_VERSION,
                             mode => TXK::IO::WRITE
                          });

    $io_write_dbv->print($connect_string);
    $io_write_dbv->print("set head off;\n");
    $io_write_dbv->print("set feedback off;\n");
    $io_write_dbv->print("set lines 500;\n");
    $io_write_dbv->print("set pages 700;\n");
    $io_write_dbv->print($sql_db_version . ";\n");
    $io_write_dbv->print("set head on;\n");
    $io_write_dbv->print("exit;\n");
    $io_write_dbv->close();
}

#################################################################
# checkFileExists - Checks whether specified file exists or not
#################################################################
sub checkFileExists
{
    my $file_path = $ARG[0];

    $FSYS->abortOnError({enable => TXK::Util::FALSE});

    my $file_exists = $FSYS->access({ fileName  => $file_path,
                                      type      => TXK::FileSys::FILE,
                                      checkMode => TXK::FileSys::READ_ACCESS
                                   });

    $FSYS->abortOnError({enable => TXK::Util::TRUE});

    if ($file_exists eq TXK::Error::FAIL)
    {
        return TXK::Util::FALSE;
    }
    else
    {
        return TXK::Util::TRUE;
    }
}

#####################################
# removeFile - Removes a given file
#####################################
sub removeFile
{
    my $file_path = TXK::OSD->trDirPathToBase($ARG[0]);

    # ------------------------------------------------
    # Check whether the file to delete exists or not
    # ------------------------------------------------
    if (checkFileExists($file_path))
    {
        logMessage("Removing the file: $file_path\n");
    }
    else
    {
        logMessage("File $file_path does not exist.\n");
        return;
    }

    my $fsys = TXK::FileSys->new();

    $fsys->rmfile({ fileName => $file_path });
}

#############################################################################
# loadFileContent - Loads the content of output generated by
#                   SQL queries into an array and loads the provided
#                   inputFile data to another array for further check
#############################################################################
sub loadFileContent
{
    logMessage("\n");
    logMessage("====================================");
    logMessage("Inside loadFileContent()...");
    logMessage("====================================");

    #my $sql_output_log = TXK::OSD->trDirPathToBase($SQL_OUTPUT_LOC);

    my $io_read_sql = TXK::IO->new();
    my $io_read_infl = TXK::IO->new();
    my $io_read_rac =  TXK::IO->new();
    my $io_read_dbv = TXK::IO->new();
    my $result_sql = $io_read_sql->open({ fileName  =>  $SQL_OUTPUT_LOC });
    my $result_infl = $io_read_infl->open({ fileName  =>  $INIT_FILE_LOC });
    my $result_rac  = $io_read_rac->open({ fileName  =>  $SQL_RAC_OUTPUT_LOC });
    my $result_dbv  = $io_read_dbv->open({ fileName  =>  $SQL_DB_VERSION_OUTPUT });

    if ($result_sql ne TXK::Error::SUCCESS)
    {
        logMessage(TXK::Error->getFormatedErrorMsg("File $SQL_OUTPUT_LOC could not be opened.\n"));
        TXK::Error->stop("File $SQL_OUTPUT_LOC could not be opened.");
    }
    if ($result_infl ne TXK::Error::SUCCESS)
    {
        logMessage(TXK::Error->getFormatedErrorMsg("File $INIT_FILE_LOC could not be opened.\n"));
        TXK::Error->stop("File $INIT_FILE_LOC could not be opened.");
    }
    if ($result_rac ne TXK::Error::SUCCESS)
    {
        logMessage(TXK::Error->getFormatedErrorMsg("File $SQL_RAC_OUTPUT_LOC could not be opened.\n"));
        TXK::Error->stop("File $SQL_RAC_OUTPUT_LOC could not be opened.");
    }
    if ($result_dbv ne TXK::Error::SUCCESS)
    {
        logMessage(TXK::Error->getFormatedErrorMsg("File $SQL_DB_VERSION_OUTPUT could not be opened.\n"));
        TXK::Error->stop("File $SQL_DB_VERSION_OUTPUT could not be opened.");
    }

    my $file_handle_sql     = $io_read_sql->getFileHandle();
    my @file_contents_sql   = <$file_handle_sql>;
    $io_read_sql->close();
    my $file_handle_infl    = $io_read_infl->getFileHandle();
    my @file_contents_infl  = <$file_handle_infl>;
    $io_read_infl->close();
    my $file_handle_rac    = $io_read_rac->getFileHandle();
    @file_contents_rac  = <$file_handle_rac>;
    $io_read_rac->close();
    my $file_handle_dbv   = $io_read_dbv->getFileHandle();
    my @file_content_dbv   = <$file_handle_dbv>;
    @file_content_dbv = grep (/^\S/, @file_content_dbv);  #Removing blank lines
    $io_read_dbv->close();
    $db_version_display = @file_content_dbv[0];
    logMessage("DB Version : $db_version_display");
    @SQL_OUTPUT_ARRAY     = grep (!/.*rows selected.$/, @file_contents_sql);
    @SQL_OUTPUT_ARRAY     = grep (/^\S/, @SQL_OUTPUT_ARRAY);  #Removing blank lines
    @SQL_OUTPUT_ARRAY_CP  = @SQL_OUTPUT_ARRAY;
    logMessage("Count of SQL_OUTPUT_ARRAY : ".scalar(@SQL_OUTPUT_ARRAY));
    my $ebsver1 = substr($ebsver,0,4);
    my $search_pat = "^".$ebsver1.".".$dbver;
    @INPUT_FILE_ARRAY  = @file_contents_infl;
    @INPUT_FILE_ARRAY  = grep (/^\S/,@INPUT_FILE_ARRAY);  #Removing blank lines
    logMessage("search pattern from the inputfile - $search_pat");
    @INPUT_FILE_ARRAY     = grep (/$search_pat/, @INPUT_FILE_ARRAY);
    logMessage("Count of INPUT_FILE_ARRAY : ".scalar(@INPUT_FILE_ARRAY));
    @file_contents_rac    = grep (/^\d/, @file_contents_rac);  #Removing blank
    logMessage("Count of file_contents_rac : ".scalar(@file_contents_rac));

    my @SQL_ERROR_ARRAY     = grep (/^ERROR/, @file_contents_sql);
    if (scalar(@SQL_ERROR_ARRAY) != 0)
    {
        logMessage("valid_env = E");
        $valid_env = "E"; #This is for database ERROR
    }
    elsif (scalar(@INPUT_FILE_ARRAY) == 0)
    {
        # if there is no record for system in input file, it means currect system is not compartible
        logMessage("valid_env = F");
        $valid_env = "F";
    }

    logMessage("Content loaded successfully");
}

#############################################################################
# L O G I C    F O R    P A R A M E T E R      V A L I D A T I O N
#############################################################################
# parameterValidation - this function will have the validation logic
#                     - This function is important for main logic
#############################################################################
sub parameterValidation
{
    logMessage("\n");
    logMessage("====================================");
    logMessage("Inside parameterValidation()...");
    logMessage("====================================");
    my $event_value;
    my $sys_event_value;
    my $rac_cnt;
    # variables for alter reset print control
    my $container_print = 1;
    logMessage("Testing");
    #For each node in RAC below loop will continue. In non-RAC it will be only 1 node so the loop will run once for 1 node.
    for ($rac_cnt=0; $rac_cnt < scalar(@file_contents_rac); $rac_cnt++)
    {
        logMessage("FOR LOOP Started for RAC Node");
        my $rac_line = $file_contents_rac[$rac_cnt]; chomp($rac_line);
        logMessage("For RAC instance : $rac_line");
        my @sys_line_inst = grep (/$rac_line/, @SQL_OUTPUT_ARRAY);
        my $cnt;
        my @inst_details = split(/-/,$rac_line);
        for ($cnt=0; $cnt < scalar(@INPUT_FILE_ARRAY); $cnt++)
        {
            logMessage("..FOR LOOP Started for INPUT FILE");
            my $data_line = $INPUT_FILE_ARRAY[$cnt];
            logMessage("..$data_line");
            my @line_array = split("[|]", $data_line);
            my $platform = $line_array[2]; chomp($platform);
            my $parameter_name = $line_array[3]; chomp($parameter_name);
            my $parameter_value = $line_array[4]; chomp($parameter_value);
            my $mandatory = $line_array[5]; chomp($mandatory);
            my $type = $line_array[6]; chomp($type);
            my $scope = $line_array[7]; chomp($scope);
            my $action = $line_array[8]; chomp($action);
            my $exist_cdb = "F";
            my $exist_pdb = "F";
            my $exist_event = "F";
            my $status;
            my $p_type;
            my $check_cdb_pdb = "N";
            if ($platform eq "RAC" && $rac_value ne "RAC")
            {
                # S K I P  - This parameter is meant for RAC environment only and current platform is not RAC
                logMessage("..$parameter_name -- $platform is not validated as RAC value is $rac_value");
            }
            else
            {
                logMessage("..Processing --> $parameter_name");
                my @sys_line = grep (/$parameter_name/, @sys_line_inst);
                my $cntr;
                for ($cntr=0; $cntr < scalar(@sys_line); $cntr++)
                {
                    logMessage("....FOR LOOP Started for SYSTEM DATA");
                    my $sys_line_rec   = $sys_line[$cntr]; chomp($sys_line_rec);
                    logMessage("....$sys_line_rec");
                    my @sys_line_array = split("[|]", $sys_line_rec);
                    my $sys_param_name = $sys_line_array[0]; chomp($sys_param_name);
                    my $sys_scope = $sys_line_array[3]; chomp($sys_scope);
                    my $sys_value = $sys_line_array[2]; chomp($sys_value);
                    #getting the inst_id and inst_name in case of RAC it will be different
                    my $sys_inst_name = $sys_line_array[6]; chomp($sys_inst_name);
                    my $inst_id = $sys_line_array[5]; chomp($inst_id);
                    my $sys_param_type = $sys_line_array[4]; chomp($sys_param_type);
                    my $isdefault = $sys_line_array[7]; chomp($isdefault);
                    my $ismodified = $sys_line_array[8]; chomp($ismodified);
                    my $db_default_value = $sys_line_array[9]; chomp($db_default_value);
                    my $sys_value_display = $sys_value;

                    #Deciding the system value is default or not
                    my $default_flag = "T";
                    if ($isdefault ne "TRUE" || ($isdefault eq "TRUE" && $ismodified ne "FALSE"))
                    {
                        #it is non default means set explicitly in spfile-pfile or memory
                        $default_flag = "F";
                    }
                    else
                    {
                        #to denote default value we are appending an asteric into the value
                        $sys_value_display = $sys_value.$append_string;
                    }

                    logMessage("....comparing $sys_param_name with $parameter_name");
                    if (uc($sys_param_name) eq uc($parameter_name))
                    {
                        $p_type = $sys_param_type;
                        #Below is check whether value is explicitly set in cdb or pdb

                        if (uc($sys_scope) eq "CDB")
                        {
                            $exist_cdb = "Y";
                            if ($default_flag eq "T")
                            {
                                $exist_cdb = "D";
                            }
                        }
                        else
                        {
                            $exist_pdb = "Y";
                            if ($default_flag eq "T")
                            {
                                $exist_pdb = "D";
                            }
                        }

                        #If scope is different it will ask to remove that from inproper container otherwise will proceed for validation
                        #If shared_pool_size is set at PDB with non default value then validation needs to be performed and it should not be skipped.
                        if (uc($scope) eq "CDB" && uc($sys_scope) eq "PDB" && (uc($sys_param_name) ne "SHARED_POOL_SIZE"))
                        {
                            $status = "FAIL";
                            #call the Alter sql for resetting it to default in PDB for type not eqal SIZING
                            #for FIX it will be having scope=both, for other than FIX it will generate scope=spfile
                            if (uc($type) ne "SIZING" && uc($type) ne "OTHER" && uc($type) ne "DERIVED")
                            {
                                my $cmd = "ALTER SYSTEM RESET \"".$parameter_name."\"";

                                if (uc($type) eq "FIX")
                                {
                                $cmd = $cmd." SCOPE = BOTH";
                                }
                                else
                                {
                                $cmd = $cmd." SCOPE = SPFILE";
                                }

                                #if it is RAC then add instance name in SID
                                if ($rac_value eq "RAC")
                                {
                                $cmd = $cmd." sid='$inst_details[1]'";
                                }
                                $cmd = $cmd.";";
                                $io_2write->print("$cmd\n");

                            }
                        }
                        elsif (uc($scope) eq "PDB" && uc($sys_scope) eq "CDB")
                        {
                            if (uc($sys_value) eq uc($db_default_value))
                            {
                                #default case in CDB for PDB specific param
                                $status = "WARNING";
                                # this parameter is desired to set in PDB, but it is set in CDB
                                # however the value is matching with db_default, hence it is WARNING
                            }
                            else
                            {
                                # PDB specific param is set in CDB with other value than db default
                                $status = "FAIL";
                                #call the Alter sql for resetting it to default in CDB for type not eqal SIZING
                                #for FIX it will be having scope=both, for other than FIX it will generate scope=spfile
                                if (uc($type) ne "SIZING" && uc($type) ne "OTHER" && uc($type) ne "DERIVED")
                                {
                                    my $cmd = "ALTER SYSTEM RESET \"".$parameter_name."\"";

                                    if (uc($type) eq "FIX")
                                    {
                                    $cmd = $cmd." SCOPE = BOTH";
                                    }
                                    else
                                    {
                                    $cmd = $cmd." SCOPE = SPFILE";
                                    }

                                    #if it is RAC then add instance name in SID
                                    #if ($rac_value eq "RAC")
                                    if ($rac_value eq "RAC" && lc($parameter_name) ne "container_data")
                                    {
                                    $cmd = $cmd." sid='$inst_details[1]'";
                                    }
                                $cmd = $cmd.";";
                                if ($rac_value ne "RAC") {
                                    $io_3write->print("$cmd\n");   
                                }
                                else {
                                    if (lc($parameter_name) eq "container_data" ) {
                                       if ($container_print) {
                                           $io_3write->print("$cmd\n");
                                           $container_print = 0;
                                       }
                                    }
                                    else {
                                        $io_3write->print("$cmd\n");
                                    }
                                }   
                                } 
                            }
                        }
                        else
                        {
                            #First to check the EVENT category
                            if (uc($type) eq "EVENT")
                            {
                                $event_value = $parameter_value;
                                $event_value =~ s/\s+//g;
                                $sys_event_value = $sys_value;
                                $sys_event_value =~ s/\s+//g;
                                logMessage("....Comparing Event - $event_value with $sys_event_value");
                                if (uc($event_value) eq uc($sys_event_value))
                                {
                                    $status = "PASS";
                                    $exist_event = "Y";
                                    # As it is validated then push the value to VALIDATION_ARRAY
                                    logMessage("....$parameter_name is added to VALIDATION_ARRAY");
                                    push @VALIDATION_ARRAY, "$parameter_name|$parameter_value|$scope|$sys_value_display|$sys_scope|$status|$sys_inst_name";
                                    # If the event value found and validated then only that event value need to be deleted from the SQL_OUTPUT_ARRAY
                                    my $search_pat = '^'.$parameter_name.'.'.$sys_value.'.*'.$rac_line;
                                    logMessage("....Removing $search_pat from SQL_OUTPUT_ARRAY");
                                    @SQL_OUTPUT_ARRAY = grep {!/$search_pat/} @SQL_OUTPUT_ARRAY;
                                }
                                else
                                {
                                    #if any other EVENT is present in system, do not react
                                    #reset the status to NULL for next iteration
                                    logMessage("....This is additional event present in the system");
                                    $status = "";
                                }
                            }
                            #Second check with REMOVE type
                            elsif(uc($type) eq "REMOVE")
                            {
                            #This code is added for removal category. Here we will highlight that this additional param is listed as removal in 396009.1
                            #This will add value in array which will have pipe delimted line with below info
                                    #   [0] parameter_name
                                    #   [1] value in system
                                    #   [2] container in which present
                                    #   [3] instance for RAC
                                if (uc($parameter_name) eq "EVENT")
                                {
                                    #For events need to check the value without space
                                    my $event_value1 = $parameter_value;
                                    $event_value1 =~ s/\s+//g;
                                    my $sys_event_value1 = $sys_value;
                                    $sys_event_value1 =~ s/\s+//g;
                                    logMessage("....EVENT REMOVE . Comparing : $event_value1 - with : $sys_event_value1");
                                    if (uc($event_value1) eq uc($sys_event_value1))
                                    {
                                        push @REMOVE_ARRAY, "$parameter_name|$sys_value|$sys_scope|$sys_inst_name";
                                        #After porcessing removing the parameter value
                                        my $search_pat = '^'.$parameter_name.'.'.$sys_value.'.*'.$rac_line;
                                        logMessage("....Removing $search_pat from SQL_OUTPUT_ARRAY");
                                        @SQL_OUTPUT_ARRAY = grep {!/$search_pat/} @SQL_OUTPUT_ARRAY;
                                    }
                                }
                                elsif($default_flag eq "F")
                                {
                                    logMessage("....$parameter_name added to REMOVE_ARRAY");
                                    push @REMOVE_ARRAY, "$parameter_name|$sys_value|$sys_scope|$sys_inst_name";
                                    #After porcessing removing the parameter value
                                    my $search_pat = '^'.$parameter_name.'.'.$sys_value.'.*'.$rac_line;
                                    @SQL_OUTPUT_ARRAY = grep {!/$search_pat/} @SQL_OUTPUT_ARRAY;
                                }
                            }
                            #If other than EVENT or REMOVE type then normal validation will start
                            elsif (uc($parameter_value) eq uc($sys_value) || uc($mandatory) eq "N")
                            {
                                logMessage("....parameters value are same or Mandatory flag is N");
                                $status = "PASS";
                                if (uc($type) eq "SIZING" || uc($type) eq "DERIVED")
                                {
                                    #For sizing we need to check the validation PDB vs CDB
                                    $check_cdb_pdb = "Y";
                                }
                            }
                            elsif (uc($type) eq "DERIVED")
                            {
                                logMessage("....This is for DERIVED case");
                                my $new_param_value = eval_param($parameter_value, $inst_details[1]);
                                if (toByte($new_param_value) <= toByte($sys_value))
                                {
                                    $status = "PASS";
                                }
                                else
                                {
                                    $status = "FAIL";
                                    #For sizing NO alter command will be fired
                                }
                                $check_cdb_pdb = "Y";
                            }
                            elsif (uc($type) eq "SIZING")
                            {
                                if (toByte($parameter_value) <= toByte($sys_value) ||
                                    ## For sga_target and share_pool_size below validation is performed for PDB centric case and the values exist as default (i.e 0)
                                    ((uc($sys_param_name) eq "SHARED_POOL_SIZE" || uc($sys_param_name) eq "SGA_TARGET") && uc($sys_scope) eq "PDB" && $sys_value eq 0))
                                {
                                    $status = "PASS";
                                }
                                elsif (uc($mandatory) eq "Y")
                                {
                                    $status = "FAIL";
                                    #For sizing NO alter command will be fired
                                }
                                elsif (uc($mandatory) eq "YW")
                                {
                                    $status = "WARNING";
                                    #for result_cache_max_size example
                                }
                                $check_cdb_pdb = "Y";

                            }
                            elsif (uc($type) eq "FIXSP")
                            {
                                $status = "FAIL";
                                #Alter command to be fired in FIXSP category for scope=spfile.
                                if (uc($sys_scope) eq "CDB")
                                {
                                printalterc($parameter_name,$parameter_value, "SPFILE", $inst_details[1], $p_type);
                                }
                                else
                                {
                                printalterp($parameter_name,$parameter_value, "SPFILE", $inst_details[1], $p_type);
                                }
                            }
                            elsif (uc($type) eq "FIX")
                            {
                                $status = "FAIL";
                                #call the Alter sql for reseting it to default in scope
                                    if (uc($sys_scope) eq "CDB" && ((($exist_cdb eq "D" && pdbNotFound($parameter_name)) || $exist_cdb ne "D"  && $scope eq "ANY") || $scope ne "ANY" ))
                                    {
                                    printalterc($parameter_name,$parameter_value, "BOTH", $inst_details[1], $p_type);
                                    logMessage('$exists_pdb is '.pdbNotFound($parameter_name)." ==");
                                    }
                                    if (uc($sys_scope) eq "PDB")
                                    {
                                    printalterp($parameter_name,$parameter_value, "BOTH", $inst_details[1], $p_type);
                                    }
                            }
                            else
                            {
                                $status = "PASS";
                            }

                        }
                        #event is taken care of so in else cases it need to push the validation info to VALIDATION_ARRAY
                        if ($type ne "EVENT" && $type ne "REMOVE")
                        {
                        logMessage("....$parameter_name is added to VALIDATION_ARRAY");
                        push @VALIDATION_ARRAY, "$parameter_name|$parameter_value|$scope|$sys_value_display|$sys_scope|$status|$sys_inst_name";
                        }
                    } # End of comparing sys_param_name with parameter_name
                    logMessage("....END OF FOR LOOP for SYSTEM DATA");
                }#End of 3rd for loop - for validation
                if ($check_cdb_pdb eq "Y") #This condition only works for SIZING as of now
                {
                    my $mtcdb_res = checkCDBMax($parameter_name,$inst_details[0]);
                    logMessage("....$mtcdb_res");
                    if ($mtcdb_res eq "FAIL")
                    {
                        logMessage("....Entering $parameter_name for $inst_details[1] to ADDITIONAL_COMMENT ");
                        push @ADDITIONAL_COMMENT, "Sum of values of $parameter_name across all or single PDB(s) is greater than the value set at CDB level.|$rac_line";
                    }

                }
                # If value is not present in recommended container then it will make a status fail
                # need to add this in validation ARRAY as FAIL
                if ( $type ne "EVENT" && $type ne "REMOVE")
                {
                    if ( $scope eq "CDB" || $scope eq "BOTH")
                    {
                        if ($exist_cdb eq "F" && uc($type) ne "OTHER")
                        {
                        logMessage("..$parameter_name is DEFAULT in CDB and added to VALIDATION_ARRAY");
                        push @VALIDATION_ARRAY, "$parameter_name|$parameter_value|$scope|$default_string|  |FAIL|$rac_line";
                        #alter statement to be appneded in CDB script
                            if (uc($type) ne "SIZING" && uc($type) ne "DERIVED")
                            {
                                if (uc($type) eq "FIX")
                                {
                                printalterc($parameter_name,$parameter_value,"BOTH", $inst_details[1], $p_type);
                                }
                                else
                                {
                                printalterc($parameter_name,$parameter_value,"SPFILE", $inst_details[1], $p_type);
                                }
                            }

                        }
                        elsif ($exist_cdb eq "F" && uc($type) eq "OTHER")
                        {
                            logMessage("..$parameter_name is DEFAULT in CDB and Other for warning added to VALIDATION ARRAY");
                            push @VALIDATION_ARRAY, "$parameter_name|$parameter_value|$scope|$default_string|  |WARNING|$rac_line";
                        }
                    }
                    if ($scope eq "PDB" || $scope eq "BOTH")
                    {
                        if ($exist_pdb eq "F" && uc($type) ne "OTHER")
                        {
                        logMessage("..$parameter_name is DEFAULT in PDB and added to VALIDATION_ARRAY");
                        push @VALIDATION_ARRAY, "$parameter_name|$parameter_value|$scope|$default_string|  |FAIL|$rac_line";
                        #alter statement to be appneded in PDB script
                            if (uc($type) ne "SIZING" && uc($type) ne "DERIVED")
                            {
                                if (uc($type) eq "FIX")
                                {
                                printalterp($parameter_name,$parameter_value,"BOTH", $inst_details[1]);
                                }
                                else
                                {
                                printalterp($parameter_name,$parameter_value,"SPFILE", $inst_details[1]);
                                }
                            }
                        }
                        elsif ($exist_pdb eq "F" && uc($type) eq "OTHER")
                        {
                            logMessage("..$parameter_name is DEFAULT in CDB and Other for warning added to VALIDATION_ARRAY");
                            push @VALIDATION_ARRAY, "$parameter_name|$parameter_value|$scope|$default_string|  |WARNING|$rac_line";
                        }
                    }
                    if ($scope eq "ANY")
                    {
                        if ($exist_cdb eq "F" && $exist_pdb eq "F" && uc($type) ne "OTHER")
                        {
                        logMessage("..$parameter_name is DEFAULT in both CDB and PDB and added to VALIDATION_ARRAY");
                        push @VALIDATION_ARRAY, "$parameter_name|$parameter_value|$scope|$default_string|  |FAIL|$rac_line";
                        #alter statement to be appneded in CDB script
                            if (uc($type) ne "SIZING" && uc($type) ne "DERIVED")
                            {
                                if (uc($type) eq "FIX")
                                {
                                printalterc($parameter_name,$parameter_value,"BOTH", $inst_details[1], $p_type);
                                }
                                else
                                {
                                printalterc($parameter_name,$parameter_value,"SPFILE", $inst_details[1], $p_type);
                                }
                            }
                        }
                        elsif ($exist_cdb eq "F" && $exist_pdb eq "F" && uc($type) eq "OTHER")
                        {
                            logMessage("..$parameter_name is DEFAULT in CDB and PDB and Other for warning added to VALIDATION_ARRAY");
                            push @VALIDATION_ARRAY, "$parameter_name|$parameter_value|$scope|$default_string|  |WARNING|$rac_line";
                        }
                        elsif ($exist_cdb eq "D" && $exist_pdb eq "Y")
                        {
                            #remove the line from VALIDATE_ARRAY for CDB against the param
                            my $search_pat = '^'.$parameter_name.'.'.$parameter_value.'.ANY.*CDB.*'.$rac_line;
                            logMessage("removing CDB : $search_pat");
                            @VALIDATION_ARRAY = grep {!/$search_pat/} @VALIDATION_ARRAY;
                            logMessage("..$parameter_name is removed from VALIDATION_ARRAY for CDB default");
                        }
                        elsif ($exist_cdb eq "Y" && $exist_pdb eq "D")
                        {
                            #remove the line from VALIDATE_ARRAY for PDB against the param
                            my $search_pat = '^'.$parameter_name.'.'.$parameter_value.'.ANY.*CDB.*'.$rac_line;
                            logMessage("removing PDB : $search_pat");
                            @VALIDATION_ARRAY = grep {!/$search_pat/} @VALIDATION_ARRAY;
                            logMessage("..$parameter_name is removed from VALIDATION_ARRAY for PDB default");
                        }
                    }

                    #removing the row from system array as it is already processed, so it can be used for additional param validations
                    #regular expression which starts with $parameter_name and ends with $rac_line and gets removed from the ARRAY
                    my $search_pat = '^'.$parameter_name.'.*'.$rac_line;
                    @SQL_OUTPUT_ARRAY = grep {!/$search_pat/} @SQL_OUTPUT_ARRAY;
                }
                if ($type eq "EVENT" && $exist_event eq "F")
                {
                    logMessage("..EVENT for $parameter_value is not present, added to VALIDATION_ARRAY");
                    push @VALIDATION_ARRAY, "$parameter_name|$parameter_value|$scope|$default_string|  |FAIL|$rac_line";
                    $parameter_value = "\"".$parameter_value."\"";
                    printalterc($parameter_name,$parameter_value,"SPFILE", $inst_details[1], $p_type);
                }
            } # end of else for platform validation
            if ($rac_cnt == 0 && $type ne "REMOVE" && $type ne "EVENT")
            {
                push @RECOMMENDATION_REMARK, "$parameter_name | $action";
            }
            elsif($rac_cnt == 0 && $type eq "EVENT")
            {
                push @RECOMMENDATION_REMARK, "$parameter_name | $parameter_value <br> $action";
            }
            logMessage("..END OF FOR LOOP Input File");
        }  #end of for Input file - 2nd loop
        logMessage("END OF  FOR LOOP RAC NODE");
    }  #end of main for loop - rac nodes

#filtering all non-default records from SQL_OUTPUT_ARRAY and pushing to ADDITIONAL_PARAMETERS for reporting
for (my $i=0; $i < scalar(@SQL_OUTPUT_ARRAY); $i++)
{
    my $sys_line_rec   = $SQL_OUTPUT_ARRAY[$i]; chomp($sys_line_rec);
    my @sys_line_array = split("[|]", $sys_line_rec);
    my $isdefault = $sys_line_array[7]; chomp($isdefault);
    my $ismodified = $sys_line_array[8]; chomp($ismodified);
    if ($isdefault ne "TRUE" || ($isdefault eq "TRUE" && $ismodified ne "FALSE"))
    {
        push @ADDITIONAL_PARAMETERS, "$sys_line_rec";
    }
}

#Printing all arrays in log for validations
logMessage("==============================");
logMessage ("Validated Parameters");
logMessage("==============================");
my $i;
for ($i=0; $i < scalar(@VALIDATION_ARRAY); $i++) { logMessage($VALIDATION_ARRAY[$i]); }
logMessage("==============================");
logMessage ("Additional Parameters");
logMessage("==============================");
for ($i=0; $i < scalar(@ADDITIONAL_PARAMETERS); $i++) { logMessage($ADDITIONAL_PARAMETERS[$i]); }
logMessage("==============================");
logMessage ("Additional Event Parameters");
logMessage("==============================");
for ($i=0; $i < scalar(@ADDITIONAL_EVENTS); $i++) { logMessage($ADDITIONAL_EVENTS[$i]); }
logMessage("==============================");
logMessage ("Additional Comments");
logMessage("==============================");
for ($i=0; $i < scalar(@ADDITIONAL_COMMENT); $i++) { logMessage($ADDITIONAL_COMMENT[$i]); }
logMessage("==============================");
logMessage ("Recommendation Remarks Comments");
logMessage("==============================");
for ($i=0; $i < scalar(@RECOMMENDATION_REMARK); $i++) { logMessage($RECOMMENDATION_REMARK[$i]); }
logMessage("==============================");
logMessage ("REMOVAL list of parameters");
logMessage("==============================");
for ($i=0; $i < scalar(@REMOVE_ARRAY); $i++) { logMessage($REMOVE_ARRAY[$i]); }
logMessage("==============================");

#Calling the printing sub program to generate the report
printReport();
}


#################################################################
# toByte - Convert the values from KB MB GB to byte
#################################################################
sub toByte
{
    my $val = $ARG[0];
    my @result = grep length, split /(\d+)/, $val;
    my $ret_val;
    if (uc($result[1]) eq "G")
    {
        $ret_val = $result[0] * 1024 * 1024 *1024;
    }
    elsif (uc($result[1]) eq "M")
    {
        $ret_val = $result[0] * 1024 * 1024;
    }
    elsif (uc($result[1]) eq "K")
    {
        $ret_val = $result[0] * 1024;
    }
    else
    {
        $ret_val = $result[0];
    }
    logMessage("......toByte($val)=$ret_val");
    return $ret_val;
}

#################################################################
# printalterp -  add alter statement inside alter_sql_pdb.sql
#################################################################
sub printalterp {
     (my $parametro, my $valor, my $scope, my $inst, my $type) = @_;
     logMessage("printalerp---->".$parametro."|valor|".$valor."|tipo|".$type);
     my $out3_line;
     if ((($type == 2) || ($type eq "2")) && ($parametro ne "event"))
     {
        $out3_line = "ALTER SYSTEM SET \"" . $parametro . "\" = '" . $valor . "' scope = ".$scope;
     }
     else
     {
        $out3_line = "ALTER SYSTEM SET \"" . $parametro . "\" = " . $valor . " scope = ".$scope;
     }
     #if it is RAC then add instance name in SID
     if ($rac_value eq "RAC")
     {
     $out3_line = $out3_line." sid='$inst'";
     }
     $out3_line = $out3_line.";";
     $io_2write->print("$out3_line\n");
}

#################################################################
# printalterc -  add alter statement inside alter_sql_cdb.sql
#################################################################
sub printalterc {
     (my $parametro, my $valor, my $scope, my $inst, my $type) = @_;
      logMessage("printalerc---->".$parametro."|valor|".$valor."|tipo|".$type);
     my $out3_line;
     if ((($type == 2) || ($type eq "2")) && ($parametro ne "event"))
     {
        $out3_line = "ALTER SYSTEM SET \"" . $parametro . "\" = '" . $valor . "' scope = ".$scope;
     }
     else
     {
        $out3_line = "ALTER SYSTEM SET \"" . $parametro . "\" = " . $valor . " scope = ".$scope;
     }
     #if it is RAC then add instance name in SID
     if ($rac_value eq "RAC")
     {
     $out3_line = $out3_line." sid='$inst'";
     }
     $out3_line = $out3_line.";";
     $io_3write->print("$out3_line\n");
}

#####################################
# removeDirectory - Removes a given directory
#####################################
sub removeDirectory
{
    my $file_path = TXK::OSD->trDirPathToBase($ARG[0]);
    my $fsys = TXK::FileSys->new();
    $fsys->rmdir({ dirName => $file_path });
}

#################################################################
# isPDBOpen - This will say if the PDB is open and active or not
#################################################################
sub isPDBOpen
{
   logMessage("Inside isPDBOpen");
   my $param = $ARG[0];
    #--------------------------------------------------------------------
    # Get the connect string used -- Currently we are using / as sysdba
    #--------------------------------------------------------------------
    my $connect_string = "connect / as sysdba\n";
    #------------------------------------------
    # Initialize different parts of the query
    #------------------------------------------
    my $select_clause = "select decode(open_mode, 'READ ONLY', 'TRUE', 'READ WRITE', 'TRUE', 'FALSE') status from v\$pdbs where name='$param'";
    logMessage($select_clause);

    my $ispdbsql_loc = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "ispdbopen.sql");
    my $ispdb_out_loc   = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "ispdbopen.out");
    #---------------------------
    # Generate the SQL content
    #---------------------------
    my $io_write = TXK::IO->new();
    my $result = $io_write->open({ fileName => $ispdbsql_loc,
                             mode => TXK::IO::WRITE
                          });

    $io_write->print($connect_string);
    $io_write->print("set head off;\n");
    $io_write->print("set feedback off;\n");
    $io_write->print("set lines 500;\n");
    $io_write->print("set pages 700;\n");
    $io_write->print($select_clause . ";\n");
    $io_write->print("set head on;\n");
    $io_write->print("exit;\n");
    $io_write->close();
    my $sql_exit = executeSQLFile($ispdbsql_loc,$ispdb_out_loc);

    my $io_read_sql_cdb = TXK::IO->new();
    my $result_sql_cdb = $io_read_sql_cdb->open({ fileName  =>  $ispdb_out_loc });
    if ($result_sql_cdb ne TXK::Error::SUCCESS)
    {
        logMessage(TXK::Error->getFormatedErrorMsg("File $ispdb_out_loc could not be opened.\n"));
        TXK::Error->stop("File $ispdb_out_loc could not be opened.");
    }
    my $file_handle_sql     = $io_read_sql_cdb->getFileHandle();
    my @file_contents_sql   = <$file_handle_sql>;
    @file_contents_sql = grep (/^\S/, @file_contents_sql);
    $io_read_sql_cdb->close();
    my $sql_result = $file_contents_sql[0]; chomp($sql_result);
    logMessage("...Printing the output: $sql_result");
    removeFile($ispdbsql_loc);
    removeFile($ispdb_out_loc);
    logMessage("...End of isPDBOpen");
    return($sql_result);
}


#################################################################
# checkCDBMax -  This is called for all SIZING parameter where
#                we check, if the sum of values accross all PDB for
#                the parameter is less than value in CDB or not
#################################################################
sub checkCDBMax
{
    logMessage("......Inside checkCDBMax");
    my $param = $ARG[0];
    my $inst  = $ARG[1];
    #--------------------------------------------------------------------
    # Get the connect string used -- Currently we are using / as sysdba
    #--------------------------------------------------------------------
    my $connect_string = "connect / as sysdba\n";

    #------------------------------------------
    # Initialize different parts of the query
    #------------------------------------------
    my $select_clause = "select case when PDB > CDB then 'FAIL' else 'PASS' end as result from  (select inst_id, name, value, isdefault, decode(con_id,0,'CDB','PDB') CON from gv\$system_parameter where 1=1 and upper(name) = upper('$param') and inst_id = '$inst' and isdefault = 'FALSE' and con_id NOT IN (select pdb_id from dba_pdbs where pdb_name = 'PDB\$SEED')) PIVOT ( sum(value) for con in ('PDB'as PDB ,'CDB' as CDB) )";
    logMessage($select_clause);

    my $CDBMAX_SQL_LOC = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "cdbmax.sql");
    my $CDBMAX_OUTPUT_LOC   = TXK::OSD->trDirPathToBase($DEFAULT_OUT_DIR . "/" . "cdbmax.out");
    #---------------------------
    # Generate the SQL content
    #---------------------------
    my $io_write = TXK::IO->new();
    my $result = $io_write->open({ fileName => $CDBMAX_SQL_LOC,
                             mode => TXK::IO::WRITE
                          });

    $io_write->print($connect_string);
    $io_write->print("set head off;\n");
    $io_write->print("set feedback off;\n");
    $io_write->print("set lines 500;\n");
    $io_write->print("set pages 700;\n");
    $io_write->print($select_clause . ";\n");
    $io_write->print("set head on;\n");
    $io_write->print("exit;\n");
    $io_write->close();
    my $sql_exit = executeSQLFile($CDBMAX_SQL_LOC,$CDBMAX_OUTPUT_LOC);

    my $io_read_sql_cdb = TXK::IO->new();
    my $result_sql_cdb = $io_read_sql_cdb->open({ fileName  =>  $CDBMAX_OUTPUT_LOC });
    if ($result_sql_cdb ne TXK::Error::SUCCESS)
    {
        logMessage(TXK::Error->getFormatedErrorMsg("File $CDBMAX_OUTPUT_LOC could not be opened.\n"));
        TXK::Error->stop("File $CDBMAX_OUTPUT_LOC could not be opened.");
    }
    my $file_handle_sql     = $io_read_sql_cdb->getFileHandle();
    my @file_contents_sql   = <$file_handle_sql>;
    @file_contents_sql = grep (/^\S/, @file_contents_sql);
    $io_read_sql_cdb->close();
    my $sql_result = $file_contents_sql[0]; chomp($sql_result);
    logMessage(".......Printing the output: $sql_result");
    removeFile($CDBMAX_SQL_LOC);
    removeFile($CDBMAX_OUTPUT_LOC);
    logMessage(".......End of checkCDBMax");
    return($sql_result);
}

################################################################
# Subroutine getParamValue
# searches the system value for the specified parameter name
# from SQL_OUTPUT_ARRAY_CP
################################################################
sub getParamValue
{
    my @parameter_row ;
    my $param_value;
    my $select_parameter = $_[0];
    my $instance_input = $_[1];
    my @selectedParams = grep { /$select_parameter/i } @SQL_OUTPUT_ARRAY_CP;
    @selectedParams = grep { /$instance_input/i } @selectedParams;
    @parameter_row = split ("[\|]",@selectedParams[0]);
    $param_value = @parameter_row[1];
    return($param_value);
}
######################################################################
#  Subroutine eval_param calculates the derived value of a parameter
#  input is the expresion to evaluate and the current instance
#  where the value is calculated.
######################################################################
sub eval_param {
 my $parameter_input;
 my $instance_input;
 my @token;
 my @tokens;
 my $param_name;
 my $input_value;
 my @input_values;
 my $value_to_compare;

 logMessage(".......Start of eval_param");
 $parameter_input = $_[0];
 @tokens = split(/ /,$parameter_input);
 $instance_input = $_[1];
 @token = grep (/^\#/, @tokens);
 $param_name = $token[0];
 $param_name = substr $param_name , 1;
 $input_value = getParamValue($param_name,$instance_input);
 logMessage("........ value = $input_value");
 # substitute the column input name for the actual value and generate
 # the actual value to use in the formula to get the value to compare
 # $value_to_compare has the actual value to use in the evaluation parameter section
 $parameter_input =~ s/@token/$input_value/;
 #print $parameter;
 #print eval $parameter;
 $value_to_compare = eval $parameter_input;
 logMessage("........ Final Value = $value_to_compare");
 logMessage(".......End of eval_param");
 return $value_to_compare;
}
# -------------------------------------------------------------------
# Below function is for checking the existence of parameter in PDB 
# for deciding if alter system CDB is necessary for FIX ANY parameter
# --------------------------------------------------------------------
sub pdbNotFound {
    my @sql_system_par;
    my @sql_system_line;
    my $sql_sys_line;
    my $select_parameter = $_[0];
    @sql_system_par = grep { /$select_parameter/i } @SQL_OUTPUT_ARRAY_CP;
    logMessage("++++ pdbNotFound executed +++++");
    #print @sql_system_par; 
    logMessage('Number of rows in query '.scalar(@sql_system_par));
    @sql_system_line = grep { /PDB/i } @sql_system_par;
    #print '------------'; print "\n";
    #print @sql_system_line."\n";
    $sql_sys_line=scalar(@sql_system_line);
    #print '$'.$sql_sys_line."\n";
    if ($sql_sys_line > 0) {
        return 0;
    }
    else {
        return 1;
    }
}
#########################################################################################################################
#   R E P O R T I N G      I N T O      H T M L
#########################################################################################################################
# Finally below arrays contains the data with a pipe separated after the validation process is over
# VALIDATION_ARRAY - This contains all the parameters are validated
# ADDITIONAL_PARAMETERS - This contains all additional parameters except events which are not present in File but in system
# REMOVE_ARRAY - This contains all additional parameters which are listed as REMOVE in inputFile.
# ADDITIONAL_EVENTS - This contains the additional parameters but only EVENTS. This is addition to the ADDITIONAL_PARAMETERS
# ADDITIONAL_COMMENT - This will have comments as per each instance related. should be printed in each instance section.
# RECOMMENDATION_REMARK - Static remarks for each parameters which will be printed at end of the report.
#########################################################################################################################
# Basic information related to system will be catured from contextfile and will be printed in header
#########################################################################################################################
sub printReport{

my $rnumber;

sub printheading {
   (my $ebsver, my $dbver, my $timestamp, my $pdbn, my $hostnam, my $platform_os, my $ractag) = @_;
   my $line_out1 = ' ';
   my @timetoken = split(/_/,$timestamp);
   $timestamp = $timetoken[2].'-'.$timetoken[1].'-'.$timetoken[6]." : ".$timetoken[3].":".$timetoken[4].":".$timetoken[5];

   my $initial_heading = "<!DOCTYPE html>
<html>
<head>
<title>EDBPC Utility</title>
</head>
<style>
   table, th, td {
     border: 1px solid rgb(112, 110, 110);
     border-collapse: collapse;
     text-align: left;
   }
   th, td {
     background-color: #FFFFFF;
   }
   body {
     font-family:Arial;
     font-size: 16px;
   }
</style>
<body>
<p style='color:gray'>E-Business Suite Database Parameter Checker (EDBPC) Version : $toolVersion, Dated: $toolDate<br>
Report generated  on $timestamp
</p>
<h2>E-Business Suite Database Parameter Checker (EDBPC)</h2>
<p>
The E-Business Suite Database Parameter Checker (EDBPC) <a href = '$str_3015099' target=\"_blank\"> Document 3015099.1</a> compares your databases parameter settings to the latest recommendations in My Oracle Support Knowledge <a href='$str_396009' target=\"_blank\">Document 396009.1</a>,  <em>Database Initialization Parameters for Oracle E-Business Suite Release 12</em>. It reports on any differences, and makes recommendations about the database parameters for your environment. The utility can  be run against Oracle E-Business Suite Release 12.2 with Oracle Database 19c or later.
</p>
<h3> <strong> Key Points </strong> </h3>
<ul>
  <li>Always use the latest version of the checking utility, as older versions will not check recently introduced database parameters as present in  <em>Database Initialization Parameters for Oracle E-Business Suite Release 12 <a href = '$str_396009' target=\"_blank\">Document 396009.1 </a></em></li>
  <li>You should test all suggestions against a test system before applying to a production environment.<br>
  </li>
  <li>After reviewing, the generated scripts should be applied to the respective instances i.e., Container Database (CDB)/Pluggable Database (PDB):</li>
      <ul>
          <li><code>alter_sql_cdb.sql</code> : CDB </li>
          <li><code>alter_sql_pdb.sql</code> : PDB </li>
      </ul>
  <li>Sizing parameters: The utility will not generate any <code>ALTER</code> statements for the sizing related parameters  if FAIL appears  in the report. You can adjust these parameters as per the environment and system resource capacity. Refer to Section 9, Database Initialization Parameter Sizing, of My Oracle Support Knowledge <a href='$str_396009' target=\"_blank\">Document 396009.1</a>, <em>Database Initialization Parameters for Oracle E-Business Suite Release 12</em>  for a small instance configuration. The sizing table lists recommendations and guidelines based on the number of deployed and active EBS users. For additional guidelines on  sizing you should also refer to Section 7, Sizing Your Oracle E-Business Suite, of My Oracle Support Knowledge <a href='$str_2528000' target=\"_blank\">Document 2528000.1</a><em>,Oracle E-Business Suite Performance Best Practices.</em></li>
  <li>This utility will not generate any <code>ALTER</code> statements for the  parameters  if a WARNING appears  in the report.</li>
  <li>The <code>ALTER</code> statements, appearing in the <code>ALTER</code> scripts with <code>scope=SPFILE</code>, may require the database to be restarted for them to take into effect.</li>
  <li>Parameters, may be appering in \"Additional Parameters Set in the System\" as \"<strong>&lt;To be Removed&gt;</strong>\",  are marked to be obsolete  as per My Oracle Support Knowledge <a href='$str_396009' target=\"_blank\">Document 396009.1</a> (Refer to Section, Parameter Removal List for Oracle Database). For such cases, <code>ALTER</code> statements will not be generated and these parameters should be removed manually.
</ul>
<h3> Oracle E-Business Suite Environment Summary </h3>
<table style='width:100%'>
    <tr>
      <th style='background-color:#d1d1d1'>SID</th>
      <th style='background-color:#d1d1d1'>EBS Release</th>
      <th style='background-color:#d1d1d1'>DB Version</th>
      <th style='background-color:#d1d1d1'>RAC</th>
      <th style='background-color:#d1d1d1'>Hostname</th>
      <th style='background-color:#d1d1d1'>Platform</th>
      <th style='background-color:#d1d1d1'>Date</th>
  </tr>
    <tr>
      <td>$pdbn</td>
      <td>$ebsver</td>
      <td>$db_version_display</td>
      <td>$ractag</td>
      <td>$hostnam</td>
      <td>$platform_os</td>
      <td>$timestamp</td>
    </tr>
</table>
  <p> For recommendations, click <a href='#remarks'>Recommendation Remarks.</a></p>";

  $io_1write->print($initial_heading);
}
##############################
# Prints Additional parameters title
# ###########################3
sub printadditionalheading{
 my $instance = $ARG[0];
 my @inst_details = split(/-/,$instance);
 my $AddHeader = "</table>
<h3> Additional Parameters Set in the System</h3>
<p>These parameters are additionally set in the system which are not recommended by My Oracle Support Knowledge <a href='$str_396009' target=\"_blank\">Document 396009.1</a>, <em>Database Initialization Parameters for Oracle E-Business Suite Release 12</em>.</p>
<table style='width:100%'>
<tr>
<th style='background-color:#d1d1d1' colspan='5'>Instance ID: $inst_details[0], Instance Name: $inst_details[1]</th>
</tr>
<tr>
<th style='background-color:#d1d1d1' width='2%'>#</th>
<th style='background-color:#d1d1d1' width='32%'>Parameter Name </th>
<th style='background-color:#d1d1d1' width='46%'>Parameter Value</th>
<th style='background-color:#d1d1d1' width='6%'>CDB/ PDB</th>
<th style='background-color:#d1d1d1' width='14%'>Remark</th>
</tr>";

  $io_1write->print("$AddHeader");
}
##############################
## Prints Comments title
## ###########################3
sub printCommentheading{
  my $instance = $ARG[0];
  my @inst_details = split(/-/,$instance);
  my $AddHeader = "</table>
  <h3> Additional Comments</h3>
  <table style='width:100%'>
  <tr>
  <th style='background-color:#d1d1d1'>Instance ID: $inst_details[0], Instance Name: $inst_details[1]</th>
  </tr>
  <tr>
  <th style='background-color:#d1d1d1' >Comment</th>
  </tr>";

    $io_1write->print("$AddHeader");
  }
############################################
#  prints additional parameters line
############################################
sub printaddparams{
  my $linein  = $ARG[0];
  my @paramrow = split("[|]",$linein);
  $rnumber++;
  my $line_out = "<tr><td>$rnumber<td>$paramrow[0]<td style='background-color:#d6e5f8'>$paramrow[1]<td style='background-color:#d6e5f8'>$paramrow[3]</td><td style='background-color:#d6e5f8'></td></tr>";
  if (length($paramrow[1]) > 0) {
     $io_1write->print("$line_out");
  }
}
############################################
#  prints pameter remove line
############################################
sub printaddremove{
  my $linein  = $ARG[0];
  my @paramrow = split("[|]",$linein);
  $rnumber++;
  my $line_out = "<tr><td>$rnumber<td>$paramrow[0]<td style='background-color:rgb(255, 255, 0)'>$paramrow[1]<td style='background-color:rgb(255, 255, 0)'>$paramrow[2]<td style='background-color:rgb(255, 255, 0)'>&lt;To be Removed&gt;</td></tr>";
  if (length($paramrow[1]) > 0) {
     $io_1write->print("$line_out");
  }
}
############################################
##  prints additional events line
#############################################
sub printaddEvents{
 my $linein  = $ARG[0];
 my @paramrow = split(/\|/,$linein);
 my $line_out = "<tr><td>$paramrow[0]<td>$paramrow[1]<td>$paramrow[3]</tr>";
 #if (length($paramrow[1]) > 0) {
     $io_1write->print("$line_out");
 #}
}
############################################
##  prints additional comments
#############################################
sub printaddComment{
  my $linein  = $ARG[0];
  my @paramrow = split(/\|/,$linein);
  my $line_out = "<tr><td>$paramrow[0]</td></tr>";
  #if (length($paramrow[7]) > 1) {
      $io_1write->print("$line_out");
  # }
}
############################################
###  prints additional remarks
##############################################
sub printaddremarks{
  my $linein  = $ARG[0];
  my @paramrow = split(/\|/,$linein);
  my $line_out = "<tr><td style='font-size: 14px;'>$paramrow[0]<td style='font-size: 14px;background-color:#e5f9e9;'>$paramrow[1]</tr>";
  if (length($paramrow[1]) > 1) {
     $io_1write->print("$line_out");
  }
}
##################################
#  endReport  finalizes the html report
###################################
sub endReport{
  my $finish_line = "
  </table>

  <div class='remarks' id='remarks'>
  <h3> Recommendation Remarks </h3>
  </div>
  <table style='width:100%'>
  <tr>
  <th style= 'background-color:#d1d1d1' 'width:26%;'>Parameter Name</th>
  <th style= 'background-color:#d1d1d1' 'width:90%'>Remark</th>
  </tr>";
  my $rem_line_add="";
  $io_1write->print("$finish_line");
   for (my $cnt = 0; $cnt < scalar(@RECOMMENDATION_REMARK); $cnt++)
   {
    $rem_line_add = $RECOMMENDATION_REMARK[$cnt];
    printaddremarks($rem_line_add);
   }
  $finish_line="</table></body></html>";
  $io_1write->print("$finish_line");
}
##
## arrayheading prints title for every instance
##
sub arrayheading {
      (my $ins_name)=@_;
      my @inst_details = split(/-/,$ins_name);
       my $line_out2 = "
  <h3>Oracle Database Parameters Validation</h3>
  <table style='width:100%'>
  <tr>
    <th style='background-color:#d1d1d1' colspan='7'>Instance ID: $inst_details[0], Instance Name: $inst_details[1]</th>
   </tr>
   <tr>
       <th style='background-color:#d1d1d1' rowspan='2' colspan='1' width='2%'>#</th>
       <th style='background-color:#d1d1d1' rowspan='2' colspan='1' width='23%'>Parameter Name</th>
       <th style='background-color:#d1d1d1' colspan='2' width='33%'>Database Current Settings</th>
       <th style='background-color:#d1d1d1' colspan='2' width='33%'>Recommended Settings as per My Oracle Support Knowledge Document 396009.1</th>
       <th style='background-color:#d1d1d1' rowspan='2' width='9%'>Status</th>
   </tr>
   <tr>
    <th style='background-color:#d1d1d1'>Parameter Value</th>
    <th style='background-color:#d1d1d1'>CDB/PDB</th>
    <th style='background-color:#d1d1d1'>Recommended Value</th>
    <th style='background-color:#d1d1d1'>Scope</th>
    </tr>";
    $io_1write->print("$line_out2");
}
#######################################################
#  Begin printReport
#  Main subrutine prints the whole report
#########################################################
 my $In= 0;
 my $line_out = "";
 my @paramtoken;
 my $parameter_name;
 my $system_value;
 my $scope;
 my $recommended_value;
 my $hostname;
 my $status;
 my $remark;
 my $s_scope;
 my $instance;
 my $instance_ant = ' ';
 my @valrow;
 my @instances;
 my $previous_instance='';
 my $print_title = 1;
 my $current_instance;
 my @current_row;
 my @additional_params;
 my @additional_remove;
 my $platform_os;

 if ($rac_value eq "RAC") { $rac_value = "Yes"; } else { $rac_value = "No"; }

 $hostname = getCtxValue('s_dbhost');
 $platform_os = getCtxValue('s_platform');
 for (my $i=0; $i <scalar(@VALIDATION_ARRAY);$i++) {
      @valrow = split("[|]",$VALIDATION_ARRAY[$i]);
      $instance = $valrow[6];
      if ($previous_instance ne $instance) {
         @instances = (@instances,$instance);
         $previous_instance = $instance;
      }
 }
 my $inst_count = @instances;
 printheading ($ebsver,$dbver,$GLOBAL_TIMESTAMP,$pdbname,$hostname,$platform_os,$rac_value);

# Loop thru all instances
for (my $k=0; $k < scalar(@instances);$k++) {
 $instance = $instances[$k];
 $rnumber = 1;
 for ($In = 0; $In < scalar(@VALIDATION_ARRAY); $In++ ) {
     @paramtoken = split (/\|/,$VALIDATION_ARRAY[$In]);
     $parameter_name = $paramtoken[0];
     $recommended_value = $paramtoken[1];    #
     $scope = $paramtoken[4];
     $system_value = $paramtoken[3];
     $s_scope = $paramtoken[2];
     $status = $paramtoken[5];
     $current_instance = $paramtoken[6];
     if ($print_title) {
        arrayheading($instance);
        $print_title=0;
     }

    $line_out="<tr>
    <td>$rnumber</td>
    <td>$parameter_name</td>
    <td style='background-color:#d6e5f8; word-break: break-all;'>$system_value</td>
    <td style='background-color:#d6e5f8'>$scope</td>
    <td style='background-color:#e5f9e9'>$recommended_value</td>
    <td style='background-color:#e5f9e9'>$s_scope</td>";
    if ($status eq 'FAIL') {
       $line_out = $line_out . "<td style='background-color:rgb(255, 0, 0);'>$status</td></tr>";
    }
    elsif ($status eq 'PASS') {
      $line_out = $line_out . "<td style='background-color:rgb(0, 255, 0);'>$status</td></tr>";
    }
    else
    {
      $line_out = $line_out . "<td style='background-color:rgb(255, 255, 0);'>$status</td></tr>";
    }
    if ($current_instance eq $instance) {
       $io_1write->print("$line_out");
       $rnumber++;
    }
  }
  $io_1write->print("</table>");
  $io_1write->print(" ");
  $io_1write->print("<p> $append_string - These parameters are DB default i.e., these are not set explicitly in pfile / spfile.</p>");

  @additional_remove = grep {/$instance/} @REMOVE_ARRAY;

  my $data_line_add;
  my @linerow='';
  $print_title = 1;
  @additional_params = grep {/$instance/} @ADDITIONAL_PARAMETERS;
  $rnumber = 0;
  for ($In = 0; $In < scalar(@additional_params); $In++ ) {
      @linerow = split(/\|/,$additional_params[$In]);
      $current_instance = $linerow[6];
     if ($print_title){
        printadditionalheading($instance);
        $print_title=0;
     }

    $data_line_add = $additional_params[$In];
    printaddparams($data_line_add);
   } #End loop of additional params
   # Now print parameters for remove
   for ($In = 0; $In < scalar(@additional_remove); $In++ ) {
     $data_line_add = $additional_remove[$In];
     printaddremove($data_line_add);
   }
# Additional events
  for ($In = 0; $In < scalar(@ADDITIONAL_EVENTS); $In++ ) {
      @linerow = split(/\|/,$ADDITIONAL_EVENTS[$In]);
      $current_instance = $linerow[4];
     chomp($current_instance);
     if ($current_instance eq $instance) {
         $data_line_add = $ADDITIONAL_EVENTS[$In];
         printaddEvents($data_line_add);
     }
   } #End loop of additional events
 #$io_1write->print("</table>");
 $print_title = 1;
# Comments
  for ($In = 0; $In < scalar(@ADDITIONAL_COMMENT); $In++ ) {
      @linerow = split(/\|/,$ADDITIONAL_COMMENT[$In]);
      $current_instance = $linerow[1];
      chomp($current_instance);
     if ($print_title){
        printCommentheading($instance);
        $print_title=0;
     }
     if ($current_instance eq $instance) {
         $data_line_add = $ADDITIONAL_COMMENT[$In];
         printaddComment($data_line_add);
     }
   } #End loop of comments
   $io_1write->print("</table>");
  $print_title = 1;
} # End loop of instances
 endReport();
} # End of printReport