# $Id: Menu.pl 200.170 2026/02/27 kjharris bburbage$
# *===========================================================================+
# |  Copyright (c) 2018 Oracle Corporation, Redwood Shores, California, USA  
# |  All rights reserved 
# |  Created by Oracle Support Proactive Services  
# +===========================================================================+
# |
# | FILENAME: Menu.pl
# |
# | PLATFORM
# |   Unix Generic
# |
# | NOTES
# |
# | See End of File for Revision HISTORY 
# +===========================================================================+
BEGIN
{
  require 5.8.0;
  #Check for apps environment variables which should generally indicate we have an apps env file sourced 
  die "\n\n   ERROR: Apps Environment Required\n\n\n" if ! $ENV{APPL_TOP} && ! $ENV{ORACLE_HOME} && ! $ENV{ADJVAPRG};
  $libdir = './perlLib';
  push @INC, "$libdir";
  
  die "\n\n   ERROR: 12.2 Requires Menu.pl be run in the \"RUN\" File System\n    and using the \"RUN\" Environment. \n\n\n" if $ENV{FILE_EDITION} =~ /patch/i;
  
  #check terminal height / width and prompt for optimal settings if too small 
  my $h = `tput lines`;
  my $w = `tput cols`;
  chomp($h); chomp($w);
  
  if ($w < 80)
  {
    system("clear");
    print qq(
    
   +---------------------------------------+
   |               ATTENTION              
   +---------------------------------------+
   | The recommended terminal width to run 
   | Menu.pl is 80 characters. The current 
   | width is: $w                          
   | To avoid line wrapping please stretch 
   | the width to at least 80 characters.  
   +---------------------------------------+

   Press [Enter] to Continue: );
    <STDIN>;
  }
  if ($h < 20) 
  {
    system("clear");
    print qq(
    
   +---------------------------------------+
   |               ATTENTION               
   +---------------------------------------+
   | The recommended terminal height to  
   | run Menu.pl is at least 20 lines. The 
   | current height is: $h                
   | Please stretch the height to at least 
   | 20 lines.                            
   +---------------------------------------+

   Press [Enter] to Continue: );
    <STDIN>;
  }
  
}#END: Begin block 

# +--------------------------------------------------------------------------+ 
use strict;
use POSIX;
use POSIX qw(strftime);
use Term::ANSIColor qw(:constants);
  $Term::ANSIColor::AUTORESET='1';

use Cwd;
use File::Find;
use File::Copy;
use File::Path;
use File::Basename;
use Net::Domain qw(hostdomain);
#MENU libs 
use MENU::Analyzer;
use MENU::AnalyzerXML;
use MENU::Java; 
use MENU::Load;
use MENU::Menu;
use MENU::SQL;
use MENU::Update;
use MENU::Logger;
# +--------------------------------------------------------------------------+
$main::logr = logger MENU::Logger('logs/Menu.' . (strftime "%Y-%m-%d_%H%M%S", localtime) . '.log');
# $main::log = 'logs/Menu.' . (strftime "%Y-%m-%d_%H%M%S", localtime) . '.log';
$main::logr->start();
@main::instProds = (); 

cls(); 
if ($#ARGV < 0 ) 
{
  print qq(
  ___________________________________________________________________________
   
   INFO: The "APPS" Database account/password is required and used by this to: 

    - Query FND tables for Concurrent Programs
    - Run FNDLOAD to load Concurrent Programs in a safe & supported manner
    - Load Analyzer Database Objects
   
    Account information is not stored, logged or displayed in any way
  ___________________________________________________________________________
  );
}

$main::connStrg;

if (! defined $ARGV[0]) 
{
  getAppsCreds();
}
elsif ($ARGV[0] =~ /^apps\//)  
{
  my ($au, $ap) = split('/', $ARGV[0]); 
  if (testSQLConnection($au, $ap))
  {
     $main::connStrg = connectStrg MENU::SQL($au, $ap);
  }
  else 
  {
    die "  ERROR: Invalid connection string passed at command line: \"$ARGV[0]\" \n"; 
  }
}
else 
{
  usage();
}

#update entry point 
#If we're doing an update, the "MENU/.update" file will be present. 
#when this file is detected, kick right into the update mode right after 
#the unzipping. This is a reboot to load up the new perl code into mem. 
if (-f '.update') 
{
  $main::logr->wlSO("INFO: Resuming Update.");
  beginUpdate('R');
}

# --- sand box 8:17 AM 6/18/2019

# beginUpdate('R');

# exit; 


# my (@families) = 'atg'; 

# my ($analyzers) = getAnalyzersAutoUpdate(\@families);

# use Data::Dumper; 
# print Dumper @families;
# print "\n ------------------ \n";
# print Dumper $analyzers;

#bulkload the analyzers based on ARGV[0]
# floadBulkAutoUpdate($analyzers);
# exit; 

# $main::instAnalyzers = getInstalledCCPs(); 

# use Data::Dumper;
# print Dumper ($main::instAnalyzers);

# print "\n --- grepping -- \n"; 

# my ($match) = grep { $$main::instAnalyzers{$_}{CCP} eq 'CP_ANALYZER_SQL' } keys %$main::instAnalyzers;

# print "match: $match \n"; 


# print "== Done == \n"; 
# exit; 
# --- end sand box 8:17 AM 6/18/2019 

#Main Menu entry point 
displayDirs('analyzers/SQL');


# +--------------------------------------------------------------------------+
# | sub: usage 
# +--------------------------------------------------------------------------+
# | Desc: shows usage info in case of bad command line args 
# +--------------------------------------------------------------------------+
# | Args: nebytiye
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub usage
{
  cls(); 
  print qq(
  ___________________________________________________________________________
                           Perl Analyzer Bundle Usage
  ___________________________________________________________________________
  
    \$perl $0 [<apps user>/<apps password>] 
    example 1: perl $0 apps/appspw 
      -> APPS credentials taken at command line 
    example 2: perl $0 
      -> You are prompted for APPS credentials. 
    
    No other args are accepted 
    
    More information see Doc ID: 1939637.1
  ___________________________________________________________________________\n\n); 
  exit;
}#END: usage() 
# +--------------------------------------------------------------------------+

__END__ 
# +===========================================================================+
# | History 
# +===========================================================================+
# | 200.0 BETA (09-JAN-2015)
# | 200.2 Beta Bundle 2 
# | 200.4 Beta Bundle 3
# | 200.5 GA (04-SEP-2015) 
# | 200.6 GA (07-SEP-2015)  
# | 200.7 GA (17-SEP-2015) 
# | 200.8 Fixed AIX "-maxdepth" issue 
# | 200.8 Fixed directory listing issue resulting in blank menus 
# |   -- this was also due to the AIX fix implemented. 
# | 200.9 Unzip / Update Fixes 
# | -- Fixed exit code 2304 when unzipping (file not found) 
# | -- Added archive dir to update/archive and zips are moved to archive 
# |    dir after they are unzipped during an update. 
# | 200.11 Nov 2015 Bundle 
# | --Added SQL*PLUS password handling: "perl Menu.pl apps/apps" is now valid 
# | 200.12 Dec 2015 Bundle 
# | --replaced usage of "stty size" with "tput" instead
# | 200.13 Jan 2016 Bundle
# | --Improved the Request Group assignment menu to allow multiple Request Groups 
# | 200.14 Jan 20 2016 Bundle 
# | --Updated SELECTS to only consider base US lang 
# | 200.16 Feb 2016 Bundle
# | --Corrected logging issue during update. Added PerlLib code for Install Base Analyzer
# | --to be able to work with R12.2
# | 200.23 Aug 2016 Bundle 
# | --Updated SQL*PLUS call to be backwards compat with 8.0.6 SQL*PLUS 
# | 200.50 12:39 PM 4/4/2018 
# | --> Updated apps credentials handling 
# +===========================================================================+
