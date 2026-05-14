# $Id: Logger.pm 200.3 2:23 PM 12/15/2020 amlepe $
# +===========================================================================+
# |  Copyright (c) 2018 Oracle Corporation, Redwood Shores, California, USA    
# |  All rights reserved 
# |  Created by Oracle Support Proactive Services
# +===========================================================================+
# |
# | FILENAME: Logger.pm
# |
# | Creates an analyzer object out of an analyzer SQL so that the attribs of 
# | the analyzer can be easily accessed 
# | 
# | PLATFORM
# |   Unix Generic 
# |
# | NOTES
# |
# | HISTORY
# | See end of file for full history 
# | 
# +===========================================================================+
package MENU::Logger;

use POSIX qw(strftime);
use Exporter qw(import);
our @EXPORT = qw(wl closeLog, logName);

sub logger
{
  my $class = shift;
  my ($log) = @_;
  my $logger = {$fh}; 
  open($fh, ">>", $log) || die "  ERROR: Logger(): Unable to open \"$log\": $! \n"; 
  bless $logger, $class; 
  return $logger;

  #write line 
  sub wl 
  {
    my ($logr, $ln) = @_;
    print $fh "\n[", (strftime "%Y-%m-%d %H:%M:%S", localtime), "] "; 
    print $fh qq($ln\n);
    if ( $main::run_mode eq 'BATCH' )
    {
      print qq($ln\n);
    }
  } 
  
  #write to log & stdout 
  sub wlSO 
  {
    my ($logr, $ln) = @_;
    print $fh "\n[", (strftime "%Y-%m-%d %H:%M:%S", localtime), "] "; 
    print $fh qq($ln\n);
    print qq($ln\n);
  }

  sub start
  {
    print $fh "\n\n*****$0 Session Start:", (strftime "%Y-%m-%d %H:%M:%S", localtime), "*****\n"; 
  }
  
  sub exitLog
  {
    my ($logr, $ln) = @_;
    print $fh "\n\n*****$0 Session End:", (strftime "%Y-%m-%d %H:%M:%S",   localtime), "*****\n\n";
    print "\n  exit.\n  INFO: $0 Log: ", $log, "\n\n";
    close $fh;
    cleanTmpFiles(); 
    exit; 
  }

  #close 
  sub closeLog 
  {
    close $fh;
  }
  
  sub logName 
  {
    print "$log \n"; 
  }
  
  #2:08 PM 6/18/2019
  #clean out files from MENU/sql 
  sub cleanTmpFiles
  {
    while ($_ = glob('sql/* sql/.*')) 
    {
      next if -d $_;
      unlink($_)
    }
  }
  
  

}#END: logger 

1;

__END__ 


+===========================================================================+
| History 
+===========================================================================+
| 200.1 (14-AUG-2018) 
|  --> Updated missing "%" on line 56 in Sub "start" 
| 200.2 (2:22 PM 6/18/2019) 
| --> added cleanTmpFiles sub to clean out files from sql/ dir 
| 200.3 (11:00 AM 12/15/2020)
| --> added condition for the case of OCI use (new "batch" mode)
+===========================================================================+
