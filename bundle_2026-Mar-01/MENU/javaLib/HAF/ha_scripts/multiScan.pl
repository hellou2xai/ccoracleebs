# $Id: multiScan.pl 1.04 3:30 PM 04/06/2020 amlepe $
# History
# 2019-10-29: initial version - amlepe
# 2020-02-19: For EBSHAF-325 (issue: multiScan.pl reports failures that are not
#             failures), part of the solution is to allow to aim 
#             specific ADOP Session (rather than last n sessions) as
#             typically past sessions issues are already addressed (no
#             need to report with adopscanlog). New parameter p_AdopSessionID
#             created for such purpose, user to enter any ADOP session ID.
#             When used from the ADOP Analyzer, use the same session as given to
#             the analyzer. - amlepe
# 2020-04-06: Added validations so that parameters can be optional (and if
#             provided, a valid session ID value) - amlepe
#!/usr/bin/perl

use strict;
use English;
use TXK::ARGS();

require 5.005;

use Cwd 'abs_path';
use List::Util qw( min max );

sub getMaxSession {
  my $dir = @_[0] ;
  #print "\n\t\t\t dir: $dir";

  opendir ( BASEDIR, $dir) || die "\nCannot open $dir\n";
  my $max_session_id = max ( grep { -d "$dir$_" && /^\d+$/ } readdir (BASEDIR) );
  closedir(BASEDIR);

  #print "\n\t (sub) max session in adop log directory: $max_session_id\n";
  return $max_session_id;
}

sub validateSessionID {
  my $adopSessID = @_[0];
  my $maxSession = @_[1];
  my $adop_dir = @_[2];
  my $retVal= 0;

  if ( $adopSessID ne "" ) {
    if ( $adopSessID =~ /^\d+$/ ) {
      if ( $adopSessID <= $maxSession ) {
        my $targetSessId= "$adop_dir/$adopSessID";
        if (-e $targetSessId and -d $targetSessId) {
          $retVal= $adopSessID;
        }
        else {
          print "\t\tNO SUCH adop session ID!\n";
          $retVal= $maxSession;
        }
      }
      else {
        print "\t\tNO SUCH adop session ID!\n";
        $retVal= $maxSession;
      }
    }
    else {
      print "\t adopSessID: $adopSessID -> NUMBER PATTERN WAS NOT MATCHED!\n";
      $retVal= $maxSession;
    }
  }

  return $retVal;
}

sub validateMaxToProcess {
  my $maxSession = @_[0] ;
  my $_maxSessions2Process = @_[1] ;
  my $adopSessID = @_[2] ;
  my $originalParam = $_maxSessions2Process;

  if ( $adopSessID != 0 ) {
        return 1;
  }

  #max number of sessions to scan is 3
  my $retValue = min (3, $maxSession);

  if ( $_maxSessions2Process eq "" ) {
    return $retValue;
  }

  if ( $_maxSessions2Process =~ /^[a|A][l|L][l|L]$/ ) {
    $_maxSessions2Process = $maxSession;
  }

  #print "\n\t\t\tsub param value (entered): $_maxSessions2Process\n";

  my $sess_number;
  if ( $_maxSessions2Process =~ /^\d+$/ ) {
    $sess_number = $&;
    $sess_number = min( $sess_number , $maxSession);
  } else {
    print "\t maxSessions2Process: $_maxSessions2Process -> NUMBER PATTERN WAS NOT MATCHED!\n";
    $sess_number= $retValue;
  }

  #print "\n\t\t\tsub param value (derived): $sess_number\n";
  
  return $sess_number;
}

#MAIN
my $filename='multi_scan_log.out';
my $args = TXK::ARGS->new();
my %argTable = ();

$args->validateArgs( { args       => \@ARGV,
                       definition => \%argTable,
                       type       => TXK::ARGS::HASH_TABLE,
                       useprompt  => TXK::Util::FALSE,
                       allowUndefinedArgs => TXK::Util::TRUE,
                     } );

#my $maxNumSessionsToProcess = $ARGV[0];
my $maxNumSessionsToProcess = $args->getArgValue("p_maxNumSessionsToProcess");
print "maxNumSessionsToProcess: $maxNumSessionsToProcess\n";
my $adopSessionID = $args->getArgValue("p_adop_session_id");
print "adopSessionID: $adopSessionID\n";

my $base_dir = abs_path("$ENV{NE_BASE}/EBSapps/log/adop")."/";

#banner
my $banner="\n\n\tThis program executes the Online Patching Log Analyzer Utility (adopscanlog)\n";
$banner= $banner . "\twhich scans the adop log directories for errors; it will scan the ADOP\n";
$banner= $banner . "\tsession ID provided (parameter p_AdopSessionID) or, if not provided, the\n";
$banner= $banner . "\tthe latest N adop tsessions available (parameter p_maxNumSessionsToProcess),\n"; 
$banner= $banner . "\tat the default loglevel (ie, Error level).\n";
$banner= $banner . "\tIf log files are matched, it will show, for each file, the full path file\n";
$banner= $banner . "\tname first, followed by the the line numbers and the error message(s).\n\n";
print $banner;

#obtain the max session available in $ADOP_LOG_HOME directory
my $maxSession = getMaxSession($base_dir);
print "\n\t        Current max number of adop sessions: $maxSession\n";

#validate parameters
$adopSessionID = validateSessionID( $adopSessionID , $maxSession, $base_dir );
my $maxNumSessionsToProcess = validateMaxToProcess($maxSession, $maxNumSessionsToProcess, $adopSessionID);
print "\tNumber of adop sessions to scan: $maxNumSessionsToProcess\n";

#backward loop to scan log files
my $it;
my $currSessId = $maxSession;
my $missCnt=0;
my $commOutput;
my $targetDirectory = $base_dir . "/" . $currSessId ;

if ( $adopSessionID != 0 ) {
  $currSessId = $adopSessionID;
}

for ($it = $maxNumSessionsToProcess; $it > 0; ) {

  if ( -d $targetDirectory ) {
    $missCnt=0;

    print "\t$it, scanning adop session Id: $currSessId\n";
    $commOutput = $commOutput . "\n\n+-------------------------------------------------------------------------+" ;
    $commOutput = $commOutput . "\n>>>>>> Session Id: $currSessId\n";
    $commOutput = $commOutput . `adopscanlog session_id=$currSessId` ;
   
    $it = $it-1;
  } else {
    $missCnt = $missCnt +1;
  }

  $currSessId = $currSessId -1;
  $targetDirectory = $base_dir . "/" . $currSessId ;
  
  #if more than 3 consecutive directories are missed, quit
  if ( $missCnt > 3) {
    last;
  }
}
print "$commOutput";


open(FH, '>', $filename) or die $!;
print FH $banner;
print FH $commOutput ;
close(FH);

print "\nend of program\n";
