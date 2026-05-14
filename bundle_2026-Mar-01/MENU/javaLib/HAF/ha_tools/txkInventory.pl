# $Header: txkInventory.pl 120.9.12020000.4 2020/02/24 06:26:35 eslyter ship $
# +===========================================================================+
# |   Copyright (c) 2002 Oracle Corporation, Redwood Shores, California, USA
# |                         All Rights Reserved
# |                        Applications Division
# +===========================================================================+
# |
# | FILENAME
# |   txkInventory.pl
# |
# | DESCRIPTION
# |   
# |   Generates a report containing versions of various technology components
# |   in Oracle Applications techstack.
# |
# |
# | PLATFORM
# |   Generic
# |
# +===========================================================================+
# dbdrv: none 

######################################
# Standard Modules
######################################

use strict;
use English;
use Carp;

require 5.005;


######################################
# Package Specific Modules
######################################

#
# Not all of these packages have to be included but are listed to provide
# a complete reference.
#

use TXK::AutoConfig();
use TXK::Error();
use TXK::FileSys();
use TXK::IO();
use TXK::Log();
use TXK::OSD();
use TXK::Process();
use TXK::Restart();
use TXK::Runtime();
use TXK::Util();
use TXK::XML();
use TXK::AutoBuild();
use TXK::SQLPLUS();
use TXK::ARGS();
use TXK::Validate();


######################################
# Constants
######################################

use constant PROGRAM_DESC => 
    "**** This script is for validating R12 technology requirements. ****";

######################################
# Variable Declarations
######################################

my $CONTEXT_FILE_KEY    = TXK::Techstack::APPS_CTX_FILE_KEY;
my $APPS_USER_KEY       = TXK::Techstack::APPS_USER_KEY;
my $APPS_PASSWORD_KEY   = TXK::Techstack::APPS_PASSWORD_KEY;
my $APPS_USER           = undef;
my $TEMP_DIR            = undef;
my $APPS_PWD            = undef;
my $XML_DEFN_KEY        = 'xmldefinition';
my $XML_MSG_DEFN_KEY    = 'msgdefinition';
my $REPORT_FILE         = 'outfile';
my $REPORT_TYPE         = 'reporttype';
my $DEBUG               = "debug";
my $BASE_DEFN_DIRECTORY = "basedefndir";
my $LOGFILE             = "logfile";
my $VALIDATE_XML_FILE   = TXK::Validate::XML_DEFN_FILE;
my $MSG_FILE_KEY        = TXK::Validate::MESSAGE_FILE_KEY;
my $TEMPDIR             = "tempDir";
my $EM_AGENT            = 'emagent';

my $APPS_USER_DB_INVALID_CREDNTIALS = "Invalid APPS database user credentials.\n";
my $CONTEXT_FILE_NOT_FOUND_ERROR    = "Context file not found.";
my $NO_CREATE_ACCESS_FOR_REPORT_FILE= "Report file does not have permission to be created.\n";
my $BASE_DEFN_DIR_NOT_READABLE      = "Base definition directory is not readable.\n";
my $TWO_TASK_NOT_DEFINED            = "TWO_TASK (LOCAL on NT) or ORACLE_SID environment variable not defined.";
my $XMLDEFN_FILE_NOT_READABLE       = "XML Definition file is not readable.";
my $XML_MSG_DEFN_FILE_NOT_READABLE  = "XML Message Definition file is not readable.";

#####################################
# Argument Definition
#####################################

push(@ARGV, "-appspass=" . $ENV{'APPSPASS'});
push(@ARGV, "-appsuser=" . $ENV{'APPSUSER'});

my @valid_args = ($CONTEXT_FILE_KEY, $APPS_USER_KEY, $APPS_PASSWORD_KEY, $REPORT_FILE, $LOGFILE, $DEBUG, $REPORT_TYPE, $EM_AGENT, $XML_DEFN_KEY, $XML_MSG_DEFN_KEY, $BASE_DEFN_DIRECTORY, $TEMPDIR);

my %argTable = ( $CONTEXT_FILE_KEY  => { required => TXK::ARGS::YES,
				         prompt   => 'Enter Applications Context file',
				        default  => TXK::OSD->getEnvVar(  { name => 'CONTEXT_FILE',
									     translate => TXK::Util::TRUE } ) 
},
		 $APPS_USER_KEY     => { required => TXK::ARGS::NO },
		 $APPS_PASSWORD_KEY => { required => TXK::ARGS::YES,
                                         secure   => TXK::ARGS::YES,
				         prompt   => 'Enter Apps password' },
		 $REPORT_FILE       => { required => TXK::ARGS::YES,
					 prompt   => 'Enter Report File name'},
		 $LOGFILE           => { required => TXK::ARGS::NO },
		 $DEBUG             => { required => TXK::ARGS::NO,
					 type     => TXK::ARGS::YESNO,
					 default  => TXK::ARGS::NO },
		 $REPORT_TYPE       => { required => TXK::ARGS::NO,
					 default          => TXK::Reports::REPORT_HTML,
					 allowable_values => TXK::Reports::REPORT_TEXT,TXK::Reports::REPORT_HTML},
		 $EM_AGENT           => {required => TXK::ARGS::NO},
		 $XML_DEFN_KEY       => {required => TXK::ARGS::NO},
		 $XML_MSG_DEFN_KEY   => {required => TXK::ARGS::NO},
		 $BASE_DEFN_DIRECTORY=>{ required => TXK::ARGS::NO },
		 $TEMPDIR            =>{ required => TXK::ARGS::NO } 
	       ) ;


######################################
# Main
######################################

my $args = TXK::ARGS->new();

my $localArgTable = checkArgs(\@ARGV);

$args->validateArgs( { args       => \@ARGV,
		       definition => \%argTable,
		       type       => TXK::ARGS::HASH_TABLE,
		       useprompt  => TXK::Util::TRUE } );

$APPS_USER = $args->getArgValue($APPS_USER_KEY);
$APPS_PWD  = $args->getArgValue($APPS_PASSWORD_KEY) ;

$TEMP_DIR  = $args->getArgValue($TEMPDIR) ;
validateInputParameters($args);
if ( ($args->getArgValue($EM_AGENT) =~ m/^Yes$/i)  && ($TEMP_DIR ne "")){
          $ENV{'APPLTMP'} = "$TEMP_DIR";
          $ENV{'APPLRGF'} = "$TEMP_DIR";
}
my $rt ;

my ( $logAndoutDir,$baseDefnDir,$valXMLFile,$valXSLFile,$msgFile,$objMapFile) ;

my $logAndoutDir = TXK::Techstack->getAppsTempDir( { $CONTEXT_FILE_KEY => $args->getArgValue($CONTEXT_FILE_KEY) } );

if ( !  TXK::Techstack->txkIsDBContext ( { $CONTEXT_FILE_KEY => $args->getArgValue($CONTEXT_FILE_KEY) } ) )
 {
     $logAndoutDir = TXK::OSD->trDirPathToBase(TXK::OSD->getEnvVar({name => 'APPLRGF'})."/TXK" );

     $baseDefnDir = TXK::OSD->trDirPathToBase( TXK::OSD->getEnvVar({name=>'FND_TOP'}) . "/html");
 }
else # this is the database context
 {
     $logAndoutDir = TXK::OSD->trDirPathToBase(TXK::OSD->getEnvVar({name => 'ORACLE_HOME'})."/appsutil/temp/TXK");

     $baseDefnDir = TXK::OSD->trDirPathToBase( TXK::OSD->getEnvVar({name=>'ORACLE_HOME'}) ."/appsutil/html" );

     my $appltmp = TXK::OSD->trDirPathToBase(TXK::OSD->getEnvVar({name => 'ORACLE_HOME'})."/appsutil/temp" );
     TXK::OSD->setEnvVar({name=>'APPLTMP', value=>$appltmp, translate=>TXK::Util::TRUE});

 }

$baseDefnDir = ( $args->getArgValue($BASE_DEFN_DIRECTORY ) eq "" ) ? $baseDefnDir :
		                                                     $args->getArgValue($BASE_DEFN_DIRECTORY) ;

$valXMLFile =  TXK::OSD->trFileName( $baseDefnDir . "/txkInventory.xml");

$valXSLFile =  TXK::OSD->trDirPathToBase( $baseDefnDir . "/txkValidate.xsl");

$msgFile    = TXK::OSD->trDirPathToBase( $baseDefnDir . "/txkMessages.xml");

$objMapFile = TXK::OSD->trDirPathToBase( $baseDefnDir . "/txkValObjMap.xml");

if ( $args->getArgValue($XML_DEFN_KEY) ne "" )
 {
   $valXMLFile = TXK::OSD->trFileName( $baseDefnDir . "/".$args->getArgValue($XML_DEFN_KEY) );
 }

if ( $args->getArgValue($XML_MSG_DEFN_KEY) ne "" )
 {
   $msgFile = TXK::OSD->trFileName( $baseDefnDir . "/".$args->getArgValue($XML_MSG_DEFN_KEY) );
 }

my $rt_args = { outDir      => $logAndoutDir,
                logDir      => $logAndoutDir,
                useReport   => TXK::Util::FALSE,
		useLog      => TXK::Util::FALSE,
	        useRestart  => TXK::Util::FALSE };

if ( $args->getArgValue($LOGFILE) ne ""  )
 {
     $rt_args->{stdoutFile} = $args->getArgValue($LOGFILE) ;
     $rt_args->{logDir}     = TXK::OSD->getDirName($args->getArgValue($LOGFILE))  ;
 }

$rt = TXK::Runtime->create($rt_args);

my $validate = TXK::Validate->new();

$validate->setDebug(TXK::Util::TRUE) if ( $args->getArgValue($DEBUG) eq 'Yes' ) ;

my $val_args = { $VALIDATE_XML_FILE => $valXMLFile,
		 $CONTEXT_FILE_KEY  => $args->getArgValue($CONTEXT_FILE_KEY),
		 $APPS_PASSWORD_KEY => $APPS_PWD,
                 $APPS_USER_KEY     => $args->getArgValue($APPS_USER_KEY),
                 $MSG_FILE_KEY      => $msgFile,
                 $TEMPDIR           => $logAndoutDir,
		 "ObjectMap"        => $objMapFile
	       };

unless ( $APPS_USER eq "" )
 {
     $val_args->{$APPS_USER_KEY} = $APPS_USER;
 }
    
$validate->loadDocuments( $val_args );

my $retVal = $validate->ProcessActions();

my $report  = undef ;

my $report_file = setReportFileLoc($args->getArgValue($REPORT_FILE));

if ( $retVal )
{
    $report = $validate->generateReport( { 'reportfile'  => $report_file,
					   'reporttype'  => $args->getArgValue($REPORT_TYPE),
					   'xslfile'     => $valXSLFile } );
}
else
{
  $rt->close();
  print "Generation of report file ". $report_file . " FAILED.\n";
  exit 0;
}

$rt->close();

my $reportfile = $args->getArgValue($REPORT_FILE);


$report->printReport() if ( defined $report );

print "Reportfile ". $report_file ." generated successfully.\n";

exit 0;

######################################
# End of Main
######################################

#####################################
# checkArgs: supports any argument with "_no<ACTION_NAME>=Yes"
#            to not execute that particular action.
#            ACTION_NAME comes from the xml file used
#            for validation e.g. txkVal11510MP.xml.
#####################################

sub checkArgs
{
    my $argv = $ARG[0];

    my $argTable  = {};

    my @localARGV;

    my ($arg,$key,$value);

    my $index = 0;

    while ( $index <= scalar( @$argv) )
     {
	 $arg = $argv->[$index];

	 ( $key, $value ) = split ( '=' , $arg );

	 $key =~ s/^-//g;

         if (($key ne "") && ($key ne ""))
         {
             validate_argument($key, $value);
         }

	 push ( @localARGV, $arg ) unless ( $key =~ m/^_/ );
	 
	 $argTable->{$key} = $value;

	 $index++;
     }

    # if invoked from emagent (Enterprise Manager) then no need to ask for the apps password
    # since when invoked from emagent, there is no connection to the database

    if ( scalar ( grep( /-$EM_AGENT=/ , @localARGV ) ) > 0 )
     {
	 my @passvalue = ("-$APPS_PASSWORD_KEY=APPS");
	 push ( @localARGV , @passvalue ) ;
     }

    @ARGV = @localARGV;

    return $argTable;
}

#####################################
# validateInputParameters
#####################################

sub validateInputParameters
{
    my $args_object = $ARG[0];

    #----------------------------
    # validate context file
    #----------------------------

    my $fsys = TXK::FileSys->new();

    $fsys->access({fileName    => $args_object->getArgValue($CONTEXT_FILE_KEY),
		   type        => TXK::FileSys::FILE,
		   checkMode   => TXK::FileSys::READ_ACCESS })
	or TXK::Error->stop("$CONTEXT_FILE_NOT_FOUND_ERROR\n", $fsys->getError() );

    #----------------------------
    # validate apps password
    #----------------------------

    if ( $APPS_PWD =~ m /\// )
     {
       ( $APPS_USER, $APPS_PWD ) = split ( /\// , $APPS_PWD );
     }

    if ( $APPS_USER eq "" )
     { 
	 my $xml = TXK::XML->new();
	 $xml->loadDocument({ file => $args_object->getArgValue($CONTEXT_FILE_KEY) });
	 $APPS_USER = $xml->getOAVar('s_apps_user');
     }

    my $two_task = TXK::OSD->isNT() ?  TXK::OSD->getEnvVar({name=>'LOCAL'}) : 
	                               TXK::OSD->getEnvVar({name=>'TWO_TASK'}) ;

    $two_task = TXK::OSD->getEnvVar({name=>'ORACLE_SID'}) if ( $two_task eq "" );

    TXK::Error->stop($TWO_TASK_NOT_DEFINED) if ( $two_task eq "" );
    
    #----------------------------------------------
    # no check for database credentials for emagents
    #-----------------------------------------------

    unless ( $args_object->getArgValue($EM_AGENT) =~ m/^Yes$/i )
     {
       TXK::TechstackDB->validateDBPassword({user=>$APPS_USER, password=>$APPS_PWD,
					     two_task => $two_task})
	   or TXK::Error->stop($APPS_USER_DB_INVALID_CREDNTIALS) ;
     }

    #----------------------------
    # validate write access on output reportfile
    #----------------------------

    $fsys->access({fileName    => $args_object->getArgValue($REPORT_FILE),
		   type        => TXK::FileSys::FILE,
		   checkMode   => TXK::FileSys::CREATE_ACCESS })
	or TXK::Error->stop("$NO_CREATE_ACCESS_FOR_REPORT_FILE\n", $fsys->getError() );

    #----------------------------
    # validate read access on basedefndir
    #----------------------------

    if ( $args_object->getArgValue($BASE_DEFN_DIRECTORY) ne "" )
     {
	 $fsys->access({dirName     => $args_object->getArgValue($BASE_DEFN_DIRECTORY),
			type        => TXK::FileSys::DIRECTORY,
			checkMode   => TXK::FileSys::READ_ACCESS })
	     or TXK::Error->stop("$BASE_DEFN_DIR_NOT_READABLE\n", $fsys->getError() );
     }

    if ( $args_object->getArgValue($XML_DEFN_KEY) ne "" )
     {
	 $fsys->access({fileName    => TXK::OSD->trFileName( $args_object->getArgValue($BASE_DEFN_DIRECTORY) . "/".
							     $args_object->getArgValue($XML_DEFN_KEY) ),
			type        => TXK::FileSys::FILE,
			checkMode   => TXK::FileSys::READ_ACCESS })
	     or TXK::Error->stop("$XMLDEFN_FILE_NOT_READABLE\n", $fsys->getError() );
     }

    if ( $args_object->getArgValue($XML_MSG_DEFN_KEY) ne "" )
     {
	 $fsys->access({fileName    => TXK::OSD->trFileName( $args_object->getArgValue($BASE_DEFN_DIRECTORY) . "/".
							     $args_object->getArgValue($XML_MSG_DEFN_KEY) ),
			type        => TXK::FileSys::FILE,
			checkMode   => TXK::FileSys::READ_ACCESS })
	     or TXK::Error->stop("$XML_MSG_DEFN_FILE_NOT_READABLE\n", $fsys->getError() );
     }

    return TXK::Error::SUCCESS;
}

#######################################################################################
# setReportFileLoc - Defaults the location Report File if not specified explicitly
#                    Report will always be generated under <APPLRGF> if not specified
#                    explicitly by the users
#######################################################################################
sub setReportFileLoc
{
    my @path_array;

    my $input_file = $ARG[0];

    if ( TXK::OSD->isWindows() )
    {
         @path_array = split(/\\/,$input_file);
    }
    else
    {
         @path_array = split(/\//,$input_file);
    }

    my $array_count = $#path_array;

    if ($array_count == 0)
    {
         return TXK::OSD->trDirPathToBase($logAndoutDir . '/' . $input_file);
    }
    else
    {
         return TXK::OSD->trDirPathToBase($input_file);
    }
}

##################################################################################
# validate_argument - Checks whether the argument passed is valid or not
#                     If the argument passed is NOT valid, script will error out
##################################################################################
sub validate_argument
{
    my $input_arg   = $ARG[0];
    my $input_value = $ARG[1];
    my $valid_arg   = TXK::Util::TRUE;
    my $array_element;

    for $array_element (@valid_args)
    {
         if ( $input_arg =~ m/^$array_element$/i )
	 {
              if (($input_value eq "") || ($input_value eq " "))
              {
                   print "*** Value passed for \"$input_arg\" is EMPTY\n";
                   TXK::Error->stop("Invalid value for input parameter\n");
              }
	      return;
	 }
	 $valid_arg = TXK::Util::FALSE;
    }
    if (! $valid_arg)
    {
        print "*** Argument \"$input_arg\" is not VALID\n";
	print "\n";
        print "=======================USAGE========================\n";
	print "\n";
	print "perl <FND_TOP>/patch/115/bin/TXKScript.pl\n";
	print "     -script=<FND_TOP>/patch/115/bin/txkInventory.pl\n";
	print "     -txktop=<APPLTMP>\n";
	print "     -contextfile=<CONTEXT FILE>\n";
	print "     -appspass=<APPS schema password>\n";
	print "     -outfile=<Location of the output report>\n";
	print "\n";
        print "====================================================\n";
        TXK::Error->stop("Invalid input parameter passed\n");
    }

}

