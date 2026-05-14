# $Id: Java.pm 200.2 12:02 PM 11/20/2020 amlepe $
# *===========================================================================+
# |  Copyright (c) 2019 Oracle Corporation, Redwood Shores, California, USA
# |  All rights reserved 
# |  Created by Oracle Support Proactive Services  
# +===========================================================================+
# |
# | FILENAME: Java.pm
# |
# | PLATFORM
# |   Unix Generic
# |
# | NOTES ** See end of file for history / notes ** 
# +===========================================================================+

# +--------------------------------------------------------------------------+
# | sub: runJava 
# +--------------------------------------------------------------------------+
# | Desc: Set Apps vars for java, run a java class 
# +--------------------------------------------------------------------------+
# | Args: The HA XML to run 
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub runJava
{
  my ($file) = @_;
  $main::logr->wl("runJava(): starting runJava"); 

  my $jvaprg = $ENV{AFJVAPRG};
  my $cp = $ENV{AF_CLASSPATH}; 
  $cp = "javaLib/HA.jar:" . $cp;
  
  my $javaRel = checkJDKVer($jvaprg); 
  
  if ($javaRel < 7) 
  {
    print "  Press [Enter] to continue: "; 
    $main::logr->wlSO("INFO: Unable to run this Analyzer as it requires JDK 7 or higher."); 
    <STDIN>; 
    return; 
  }
  
  # this will need to be modified for a XML arg 
  # 1:58 PM 6/19/2019 command: java -Danalyzer=testcollections_analyzer.xml -jar HA.jar 
  # Original command: (XML not embedded) 
  # my $cmd = qq($jvaprg -cp $cp -Danalyzer=$file -DrequestID=7738889 -Dp_max_rows=50 -Dp_fnd_user="SYSADMIN" oracle.support.proactive.hybridanalyzer.CommandLine);
  # New command 6:38 AM 6/20/2019 
  my $appsCreds = $main::connStrg->getConnStrg();
  
  use Cwd qw(getcwd);

  #my $cmd = qq($jvaprg -cp $cp -DappsCredentials=$appsCreds -Danalyzer=$file -jar HA.jar);
  my $cmd = qq(bash run_analyzer.sh -DappsCredentials=$appsCreds -Danalyzer=\"$file\");
  my $cmdPrt = $cmd; 
  $cmdPrt =~ s/-DappsCredentials=\w+?\/\w+?\s/-DAppsCredentials=****\/**** /; 

  $main::logr->wlSO("runJava(): Running command: $cmdPrt");
  
  my $status;
  if (! -d "javaLib/HAF") 
  {
    chdir("javaLib");
    $status = system("unzip -qo HA.zip");
    chdir("../");
    if ($status > 0)
    {
      print "  ERROR: trying to unzip HA.zip (Status: $status)"; 
      $main::logr->wl("runJava(): unzip of HA.zip failed. ");
      return;
    }
  }

  chdir("javaLib/HAF");
  $status = system($cmd); 
  moveLogs();
  chdir("../../");

  cls(); 
  if ($status > 0)
  {
    print "  ERROR: Java command for $file failed. (Status: $status)"; 
    $main::logr->wl("runJava(): Java command for $file failed. ");
  }
  else
  {
    print "  INFO: Java command for $file succeeded.";
    $main::logr->wl("runJava(): Java command for $file succeeded. ");
  }

  moveLogs(); 
  
  print "\n  INFO: runJava done. \n\n";
  print BOLD WHITE ON_BLUE "  Output Info", RESET; 
  print "\n  INFO: HTML, and zip files created are located in the \"output\" directory\n"; 
  #print "\n  INFO: log files are located in the \"logs\" directory\n"; 
  print "  Press [Enter] to continue: "; 
  <STDIN>; 
  
}

# +--------------------------------------------------------------------------+
# | sub: moveLogs
# +--------------------------------------------------------------------------+
# | Desc: move Hybrid Zip and Logs to the output dir
# +--------------------------------------------------------------------------+
# | Args: nebytiye
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub moveLogs 
{
  my (@files) = glob('*.log *.html *.zip'); 
  
  foreach my $f (@files) 
  {
    next if -d $f; 
    if ($f =~ /\.log/)
    {
      print "\n  INFO: Moving $f to logs dir\n"; 
      move($f, "../../logs/$f");
    }
    else 
    {
      print "  INFO: Moving $f to output dir\n"; 
      move($f, "../../output/$f");
    }
  }
}

1;
__END__  
# +===========================================================================+
# |
# | HISTORY
# | 200.0 Creation (23-JAN-2019) 
# | 200.1 Added chdir() to cd in proximity to where HA scripts are stored under 
# |       MENU/javaLib/ dir. Tool cd's to javaLib, then back out 
# | 200.2 Changed runJava() to uptake Java analyzer framework (HAF)version 6.12
# +===========================================================================+