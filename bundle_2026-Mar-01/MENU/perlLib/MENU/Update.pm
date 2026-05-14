# $Id: Update.pm 200.28 06/20/23 5:00:00 PM amlepe bburbage $
# +===========================================================================+
# |  Copyright (c) 2018 Oracle Corporation, Redwood Shores, California, USA 
# |  All rights reserved 
# |  Created by Oracle Support Proactive Services  
# +===========================================================================+
# |
# | FILENAME: Update.pm
# |
# | Container for subs to do analyzer bundle updates 
# | 
# | PLATFORM
# |   Unix Generic
# |
# | NOTES / History at the end of the file 
# |   2020/06/01 Added new classes for BundleUpdate program
# |   2021/07/29 Added log for call to wget.sh from Menu
# |   2021/10/27 Changed SQL in getHttpProxy
# |   2021/11/04 Changed SQL in getHttpProxy to handle case when WEB_PROXY_HOST
# |              already includes the http protocol
# +===========================================================================+

use Cwd;

# +---------------------------------------------------------------------------+
# | sub: installPSDBundleVerPkg
# +---------------------------------------------------------------------------+
# | Desc: For AutoUpdate Concurrent Framework 
# |          Installs the 'PSD_BUNDLE_VERSION' function from: 
# |          MENU/update/autoupdate/psdbundlever.sql
# +---------------------------------------------------------------------------+
# | Args: nebytiye
# +---------------------------------------------------------------------------+
# | Returns: nada
# +---------------------------------------------------------------------------+
sub installPSDBundleVerPkg
{
  my $cs = $main::connStrg->getConnStrg();
  print "  INFO: Installing PSD_BUNDLE_VERSION function\n";
  my $status = system("sqlplus -s $cs \@update/autoupdate/psdbundlever.sql");

  if ($status > 0)
  {
    print "  ERROR: SQL*PLUS failed for \"update/autoupdate/psdbundlever.sql\"\n";
  }
  else 
  {
    print "  INFO: SQL*PLUS for \"update/autoupdate/psdbundlever.sql\" was successful \n";
  }
  
  if (-f 'sql/PSD_BUNDLE_VERSION.lst') 
  {
    open (my $fh, '<', 'sql/PSD_BUNDLE_VERSION.lst');
    my @out = <$fh>;
    close $fh;
  
    if (grep(/PLS-|ORA-/i,@out))
    {
      print "  ERROR: Detected an error in the spool file \n  Spool contents: \n------------------------\n";
      print "  $_ \n" foreach @out;
      print "------------------------\n\n";
      return();
    }
    else 
    {
      #remove the spool file if we didn't detect an error 
      unlink('sql/PSD_BUNDLE_VERSION.lst');
    }
  }
  else 
  {
    print "  ERROR: Spool file was not created by \"update/autoupdate/psdbundlever.sql\" \n";
  }

}#END: installPSDBundleVerPkg 

# +---------------------------------------------------------------------------+
# | sub: copyApplyBundlePerlCode
# +---------------------------------------------------------------------------+
# | Desc: copies applyBundleUpdate.pl to $FND_TOP/bin 
# +---------------------------------------------------------------------------+
# | Args: nebytiye
# +---------------------------------------------------------------------------+
# | Returns: nada
# +---------------------------------------------------------------------------+
sub copyApplyBundlePerlCode 
{
  my ($menuLoc) = @_;
  my $file = $menuLoc . "update/autoupdate/applyBundleUpdate.pl";
  my $target = $ENV{"FND_TOP"} . "/bin/";
  my $stat = 0;
  
  if (-f $file && -d $target) 
  {
    $stat = copy($file, $target);
  }
  else 
  {
    print "  ERROR: copyApplyBundlePerlCode(): File does not exist: $file \n" if ! -f $file;
    print "  ERROR: copyApplyBundlePerlCode(): File does not exist: $file \n" if ! -d $target;
  }
  
  if ($stat == 0) 
  {
     print "  ERROR: copyApplyBundlePerlCode(): Copied Failed:\n Source: \"$file\"\n Target: \"$target\" \n OSERR: $!\n\n";
  }
  else 
  {
    print "  INFO: copyApplyBundlePerlCode(): Successfully copied applyBundleUpdate.pl to \$FND_TOP/bin\n";
  }
  
  # For R12.2 copy files to Patch File System in case of ADOP patching  
  my $pbase = $ENV{"PATCH_BASE"};
  print "  Checking my Patch Base before update :$pbase \n";

  if ($pbase) 
  {
    my $rbase = $ENV{"RUN_BASE"};    
    my $fndtop = $ENV{"FND_TOP"};
    $fndtop =~ s/$rbase/$pbase/;

    print " Now FND_TOP/bin items in RUN fs to PATCH fs : $fndtop \n";

    my $patchtarget = $fndtop . "/bin/";
    mkpath($patchtarget, 1, 0755);

    if (! -d $patchtarget) 
    {
      print "  ERROR: copyApplyBundlePerlCode(): Patch Target dir does not exist: $! \n DIR: $patchtarget\n\n"; 
    }

    $stat = 0;
    $stat = copy($file, $patchtarget);

    if ($stat == 0)
    {
      print "  ERROR: copyApplyBundlePerlCode() - PATCH fsystem: Copied Failed:\n Source: \"$file\"\n Target on Patch filesystem: \"$patchtarget\" \n OSERR: $!\n\n";
    }
    else 
    {
      print "  INFO: copyApplyBundlePerlCode() - PATCH fsystem: Successfully copied:\n\n\"$file\"\n  to\n\n\"$patchtarget\"\n";
    }

  }


}#END: copyApplyBundlePerlCode

# +---------------------------------------------------------------------------+
# | Sub updateMenu
# +---------------------------------------------------------------------------+
# | the menu displayed after the user chooses "updates" from the main menu. 
# |
# +---------------------------------------------------------------------------+
sub updateMenu
{
  my $userSel;
  
  my $instStatus = checkAutoUpdateInstallStatus(); 
  
  until (2 == 1)
  {
    my $countDepth = $dir =~ tr/\///;
    cls();
    print "\n", RESET;
    print BOLD WHITE ON_BLUE "  Update, AutoUpdate, Uninstall Menu", RESET;
  
    print qq(
    
  [1] AutoUpdate Bundle Concurrent Program Setup    [$instStatus] 
  [2] Update Analyzer Bundle
  [3] Show Installed Analyzers
  [4] Uninstall Analyzers
    );
    
    print BOLD WHITE ON_BLUE "\n  [M]ain Menu | [H]elp | E[x]it\n";
    print BOLD WHITE ON_YELLOW "\n Invalid Selection", RESET if $userSel eq 'invalid';
    print "\n  Selection:";
    chomp($userSel = <STDIN>);
    $main::logr->exitLog() if $userSel =~ /^x{1}$/i;
    if ($userSel =~ /^m{1}/i)#main menu 
    {
      return();
    }
    elsif ($userSel =~ /^1{1}/i)#autoUpdate 
    {
      autoUpdateSetup("menu");
      $instStatus = checkAutoUpdateInstallStatus(); 
    }
    elsif ($userSel =~ /^2{1}/i)#check for updates/manual update 
    {
      beginUpdate();
    }
    elsif ( $userSel =~/^3{1}$/i ) # show installed analyzers 
    {
      pickListMenu('show');
    }
    elsif ( $userSel =~/^4{1}$/i ) # uninstall 
    {
      uninstall();
    }
    elsif ($userSel =~ /^h{1}/i) #help 
    { 
        system ("clear");
        print "\n";
        print BOLD WHITE ON_BLUE "  Updates Menu Help", RESET, "\n";
        print qq (
  [1] AutoUpdate Bundle Concurrent Program Setup 
        o Starts the setup process for the AutoUpdate Concurrent Program 
  [2] Update Analyzer Bundle
        o Starts the terminal-based update process 
        o Downloads from MOS, or uses a previously downloaded bundle.zip
           from the "MENU/updates" dir 
  [3] Show Installed Analyzers
        o Shows a list of currently installed Analyzers 
  [4] Uninstall Analyzers
        o Starts the Uninstall Process 

  See DocID 1939637.1 for more information 
  Press [Enter] to Continue:);
my $z=<STDIN>;
    }
    else
    {
      $userSel = 'invalid';
    }
  } #END:  until loop 

}


# +--------------------------------------------------------------------------+
# | sub: checkJDKVer
# +--------------------------------------------------------------------------+
# | Desc: 
# +--------------------------------------------------------------------------+
# | Args: java exe to check (full path) 
# +--------------------------------------------------------------------------+
# | Returns: JDK Maj. version (ie, "7", "8") 
# +--------------------------------------------------------------------------+
sub checkJDKVer
{
  my ($javaExe) = @_; 

  if (! -f $javaExe) 
  {
    $main::logr->wlSO("checkJDKVer(): ERROR: JDK Not Found for file passed to checkJDKVer: \"$javaExe\""); 
    cls(); 
    print "ERROR: JDK Not Found: $javaExe"; 
    return 0; 
  }
  
  my @javaVer = grep(/java\sversion\s\".+?\"/i, `$javaExe -version 2>&1`);
  my $javaRel = 'null';
  $javaRel = $+ if $javaVer[0] =~ /version\s\"1\.(\d{1})\.\d/i; 
  
  $main::logr->wlSO("INFO: Java Release $javaRel found. ($javaVer[0])"); 
  
  return $javaRel; 

}

# +---------------------------------------------------------------------------+
# | sub: autoUpdateSetup
# +---------------------------------------------------------------------------+
# | Desc:  
# +---------------------------------------------------------------------------+
# | Args: mode: Will allow this to be called from a script directly for 
# |                   ease of cloud provisioning 
# |  menu: 
# |  auto: run by CLOUD 
# |  
# +---------------------------------------------------------------------------+
# | Returns: nada
# +---------------------------------------------------------------------------+
sub autoUpdateSetup
{
  my ($mode) = @_;
  my $userSel;

  print "  INFO: Running autoUpdateSetup() [mode: $mode]\n"; 
  $main::logr->wl("autoUpdateSetup()"); 
  if ($mode eq "menu") 
  {
    #check JDK version 
    my $javaExe = $ENV{AF_JRE_TOP} . "/bin/java";
    if (-f $javaExe)
    {
      my $javaRel = checkJDKVer($javaExe);
      
      if ($javaRel >= 7)
      {
        print "  INFO: JDK 7 or greater is present \n  JDK Version: $javaRel";
        $main::logr->wl("autoUpdateSetup(): JDK Version $javaRel"); 
      }
      else 
      {
        cls();
        $main::logr->wl("autoUpdateSetup(): Failed JDK Requirement.");
        print qq(  
    INFO: JDK 7 or higher is required. Did not pass JDK requirement. 
              AutoUpdate Requires JDK 7+ on the Concurrent Processing 
              Tier Node. \(AF_JRE_TOP variable must reflect JDK 7+\) 
              See Requirements in DocID: 2377353.1 
              
              Press [Enter] to continue:);
              <STDIN>;
              return; 
      }
    }
    else 
    {
      $main::logr->wlSO("autoUpdateSetup(): Unable to find Java via the AF_JRE_TOP variable");
      die "  ERROR: AutoUpdate setup requires the APPS environment to be set."; 
    }
  }
  
  if ($mode eq "menu")
  {
    cls();
    my $instStatus = checkAutoUpdateInstallStatus();
    
    until (1 == 2) 
    {
      print BOLD WHITE ON_BLUE "\n  AutoUpdate Concurrent Program Setup", RESET;
      print BOLD WHITE ON_GREEN " [$instStatus]", RESET if ($instStatus eq "Installed");
      print BOLD WHITE  ON_RED" [$instStatus]", RESET if ($instStatus eq "Not Installed");
      
      print qq(
  You are about to setup AutoUpdate, the following actions will be done: 
   o Install 2 Concurrent Executables: 
      - PSD_DL_BUNDLE_EXE, PSD_APPLY_BUNDLE_EXE 
   o Install 2 Concurrent Programs 
      - PSD_DOWNLOAD_BUNDLE, PSD_APPLY_NEW_BUNDLE 
   o Copy "applyBundleUpdate.pl" to \$FND_TOP/bin
   o Add the Concurrent Programs to the "System Administrator Reports" Group 
   o Copy Java classes to \$JAVA_TOP/oracle/support/proactive/atg/bundle
   o Run CONCSUB to schedule the Concurrent Request (optional)
      - Validate MOS Credentials in OAM Setup 
   o See DocID: 2377353.1 for more information\n\n); 
   print BOLD WHITE ON_YELLOW "  Invalid Selection", RESET if length($userSel);
   
  print BOLD WHITE ON_BLUE "  [C]ontinue | [B]ack ", RESET;
  print BOLD WHITE ON_RED " [U]ninstall AutoUpdate ", RESET if ($instStatus eq "Installed"); 
  
  print "\n  Selection: "; 
  chomp($userSel = <STDIN>);
  cls(); 
      return if $userSel =~/b{1}/i;
      last if $userSel =~ /c{1}/i;
      last if $userSel =~ /u{1}/i;
    }#end until loop 
    if ($userSel =~ /u{1}/i)
    {
      if (! $instStatus) 
      {
        print "  INFO: AutoUpdate is not installed. \n  Press [Enter] to Continue:"; 
        <STDIN>; 
      }
      print "Starting uninstall of AutoUpdate \n";
      uninstallAutoUpdate(); 
    }
    else 
    {
      _run();
    }
  }#end if mode eq "menu"  
  elsif ($mode eq "auto")
  {
    _runAuto();
  }
  elsif ($mode eq "autoCloud")
  {
    _runAutoCloud();
  }
  

  #####
  #private Subs 
  ##################
  
  #for installs via installCloud.pl: 
  sub _runAutoCloud
  {
    $main::logr->wl("START _runAutoCloud()"); 
    my $status;
    $status = _runfndload();
    my $targDir = $ENV{JAVA_TOP} . "/oracle/support/proactive/atg/bundle";
    
    # $status = unzipFile("update/autoupdate/psd.zip", $targDir) if $status == 1; #status 1 = success 
    $status = copyJavaCode("") if $status == 1; 
    
    copyApplyBundlePerlCode("") if $status == 1;
    installPSDBundleVerPkg(); 
    #run concsub here if the $main concsub var is set 
    #9:16 AM 4/12/2018 will come back to this for cloudInstall.pl 
    #runCONCSUB("$prods", $loc);
    return(); 
    $main::logr->wl("END _runAutoCloud()"); 
  }
  
  
  #for installs via CP 
  # this does not run CONCSUB  
  sub _runAuto
  {
    $main::logr->wl("START _runAuto()");
    my $status;
    $status = _runfndload();
    my $targDir = $ENV{JAVA_TOP} . "/oracle/support/proactive/atg/bundle"; 
    
    $status = copyJavaCode("") if $status == 1;
    # $status = unzipFile("update/autoupdate/psd.zip", $targDir) if $status == 1; #status 1 = success 
    
    copyApplyBundlePerlCode("") if $status == 1;
    installPSDBundleVerPkg(); 
    #run concsub here if the $main concsub var is set 
    #9:16 AM 4/12/2018 will come back to this for cloudInstall.pl 
    #runCONCSUB("$prods", $loc);
    return(); 
    $main::logr->wl("END _runAuto()");
  }
  
  sub _run
  {
    #ask for consub to schedule CP 
    $main::logr->wl("START _run()");
    my $runCS = 'zp'; 
    until ($runCS =~ /^y{1}|^n{1}/i) 
    {
      cls(); 
      print BOLD WHITE ON_BLUE "\n Run CONCSUB to schedule AutoUpdate?", RESET; 
      print qq(\n Run \$FND_TOP/bin/CONCSUB to schedule the Analyzer Bundle AutoUpdate
 Concurrent Request now?
 
  o Schedules the AutoUpdate request for the 2nd of every month at midnight
     (request date & time are not configurable here)
  o Avoids manually scheduling the request in the application later\n );

  print BOLD WHITE ON_YELLOW "\n Invalid Selection!", RESET if $runCS !~ /^y|^n|^zp/i; 
  
  print qq(\n  Schedule AutoUpdate Now? [y|n]:);
    chomp($runCS = <STDIN>);
    }

    my $prods = ''; 
    if ($runCS =~ /^y/i)
    {
      $prods = concsubPickList();
    }
    else 
    {
      cls(); 
      print qq(
  INFO: You will need to schedule the AutoUpdate Concurrent Request 
       Request Name: PSD_DOWNLOAD_BUNDLE 
       Recommended Date: 2nd of each month, midnight (00:00:00)  
       Recommended Interval: Monthly
       
  INFO: PSD_DOWNLOAD_BUNDLE calls PSD_APPLY_NEW_BUNDLE 
        Do not schedule PSD_APPLY_NEW_BUNDLE
  
  Press [Enter] to continue:);
      <STDIN>; 
      cls(); 
    }
    #as long as status keeps coming back "1", we'll keep running the next tasks
    my $status;
    $status = _runfndload();
    
    my $targDir = $ENV{JAVA_TOP} . "/oracle/support/proactive/atg/bundle"; 
    
    # $status = unzipFile("update/autoupdate/psd.zip", $targDir) if $status == 1; #status 1 = success 
    #3:34 PM 4/20/2018
    copyJavaCode("") if $status == 1;
    
    copyApplyBundlePerlCode("") if $status == 1;
    installPSDBundleVerPkg(); 
    
    my $user = '';
    if ($runCS =~/^y/i)
    {
      my $mosCreds = ''; 
      until ($mosCreds == 1 || $mosCreds eq 'abort') 
      {
        $user = getFNDUser();
        $mosCreds = checkMOSCreds($user);
      }
      
      
      my $loc = cwd(); 
      $loc =~ s/\/MENU//;
      runCONCSUB($prods, $loc, $user) if $mosCreds ==1;
    }
    else 
    {
      cls(); 
      print BOLD WHITE ON_BLUE " INFO: Oracle Applications Manager Setup ", RESET, "\n"; 
      print qq(
  Before you can run the PSD_DOWNLOAD_BUNDLE Concurrent Program,
  you must first setup your MOS Credentials in Oracle Applications Manager. 
  
  Oracle Applications Manager->OAM Setup->My Oracle Support Credentials 
  [May be called "Metalink Credentials" in some EBS releases] 
  
  See DocID 2377353.1 for more information. 
  
  Press [Enter] to continue: );
    <STDIN>; 
    }
   
    
    $main::logr->wl("END _run()");
  }#end _run 
  
  sub _runfndload 
  {
    $main::logr->wl("START _runfndload()");
    my $status = 0;
    print "  INFO: Running FNDLOAD for AutoUpdate .. \n";
    #create the LDT for the release 
    $status = createProgLDT("", "PSD_DOWNLOAD_BUNDLE", "PSD_DOWNLOAD_BUNDLE.ldt");
    $status = createProgLDT("", "PSD_APPLY_NEW_BUNDLE", "PSD_APPLY_NEW_BUNDLE.ldt") if $status == 1;
    $status = runFNDLOAD() if $status == 1;
    
    #addToGroup (System Administrator Reports)
    addToGroup("", "Application Object Library", "System Administrator Reports", "single", "PSD_DOWNLOAD_BUNDLE", "FND"); 
    addToGroup("", "Application Object Library", "System Administrator Reports", "single", "PSD_APPLY_NEW_BUNDLE", "FND");
    
    print "  INFO: Done running FNDLOAD for AutoUpdate. \n";
    $main::logr->wl("END _runfndload()");
    return $status;
    
  }
  
   print "  INFO: Done with autoUpdateSetup() [mode: $mode]\n";
   
   if ($mode eq "menu") 
   {
      print "  Press [Enter] to Continue: "; 
      <STDIN>; 
   }
    
  return();
}#END: autoUpdateSetup

# +---------------------------------------------------------------------------+
# | sub: copyJavaCode
# +---------------------------------------------------------------------------+
# | Desc:  
# +---------------------------------------------------------------------------+
# | Args: nebytiye
# +---------------------------------------------------------------------------+
# | Returns: nada
# +---------------------------------------------------------------------------+
sub copyJavaCode 
{
  my ($menuLoc) = @_;
  
  my @files = ($menuLoc . "update/autoupdate/BundleUpdate.class"
                , $menuLoc . "update/autoupdate/BundleUpdate\$1.class"
                , $menuLoc . "update/autoupdate/BundleUpdate\$StreamGobbler.class"
                , $menuLoc . "update/autoupdate/BundleUpdate\$Worker.class"
                );
  
  my $target = $ENV{"JAVA_TOP"} . "/oracle/support/proactive/atg/bundle/";
  mkpath($target, 1, 0755);
  
  if (! -d $target) 
  {
    print "  ERROR: copyJavaCode(): Target dir does not exist: $! \n DIR: $target\n\n"; 
    return 0; 
  }
  
  my $stat = 1;
  
  foreach my $file (@files) 
  {
    if (-f $file && -d $target) 
	{
      $stat = copy($file, $target);
    }
    else 
    {
      print "  ERROR: copyJavaCode(): File does not exist:\n\"$file\" \n" if ! -f $file;
      print "  ERROR: copyJavaCode(): File does not exist:\n\"$file\" \n" if ! -d $target;
      return 0; #failed 
    }
    
    if ($stat == 0) 
    {
      print "  ERROR: copyJavaCode(): Copied Failed:\n Source: \"$file\"\n Target: \"$target\" \n OSERR: $!\n\n";
	  break;
    }
    else 
    {
      print "  INFO: copyJavaCode(): Successfully copied:\n\n\"$file\"\n  to\n\n\"$target\"\n";
    }
  }
  
  if ($stat != 0) 
  {
    # For R12.2 copy files to Patch File System in case of ADOP patching  
    # Need to also copy APPLY_NEW_BUNDLE perl program to Patch Filesystem

    my $pbase = $ENV{"PATCH_BASE"};
    print "Checking Patch Base before update :$pbase \n";

    if ($pbase) 
    {
      my $rbase = $ENV{"RUN_BASE"};
      my $jtop = $ENV{"JAVA_TOP"};
      $jtop =~ s/$rbase/$pbase/;

      print " Now my Java Top points to Patch fs : $jtop \n";

      my $patchtarget = $jtop . "/oracle/support/proactive/atg/bundle/";
      mkpath($patchtarget, 1, 0755);

      if (! -d $patchtarget) 
      {
        print "  ERROR: copyJavaCode() - PATCH base: Patch Target dir does not exist: $! \n DIR: $patchtarget\n\n"; 
        return 0; 
      }

      $stat = 1;

      foreach my $file (@files) 
      {
        if (-f $file && -d $patchtarget) 
        {
          $stat = copy($file, $patchtarget);
        }
        else 
        {
          print "  ERROR: copyJavaCode() - PATCH base: File does not exist:\n\"$file\" \n" if ! -d $patchtarget;
          return 0; #failed 
        }

        if ($stat == 0)
        {
          print "  ERROR: copyJavaCode() - PATCH base: Copied Failed:\n Source: \"$file\"\n Target on Patch filesystem: \"$patchtarget\" \n OSERR: $!\n\n";
		  break;
        }
        else 
        {
          print "  INFO: copyJavaCode() - PATCH base: Successfully copied:\n\n\"$file\"\n  to\n\n\"$patchtarget\"\n";
        }
      }
    }

    print "  INFO: copyJavaCode(): All files successfully copied\n";

  }
  
  return $stat;
  
}#END: copyJavaCode

# +---------------------------------------------------------------------------+
# | sub: uninstallAutoUpdate
# +---------------------------------------------------------------------------+
# | Desc: remove the autoupdate CP's, req Group entries, files 
# +---------------------------------------------------------------------------+
# | Args: nebytiye
# +---------------------------------------------------------------------------+
# | Returns: nada
# +---------------------------------------------------------------------------+
sub uninstallAutoUpdate 
{
  print " uninstallAutoUpdate() \n"; 
  my $perlFile = $ENV{FND_TOP} . "/bin/applyBundleUpdate.pl"; 
  my @javaFiles = (
  "$ENV{JAVA_TOP}" . "/oracle/support/proactive/atg/bundle/BundleUpdate.class", 
  "$ENV{JAVA_TOP}" . "/oracle/support/proactive/atg/bundle/BundleUpdate\$1.class", 
  "$ENV{JAVA_TOP}" . "/oracle/support/proactive/atg/bundle/BundleUpdate\$StreamGobbler.class", 
  "$ENV{JAVA_TOP}" . "/oracle/support/proactive/atg/bundle/BundleUpdate\$Worker.class",
  "$ENV{JAVA_TOP}" . "/oracle/support/proactive/atg/bundle/versionNotFoundException.class"
  ); 
  my %analyzers;
  $analyzers{1}{SELECTED} = '+'; 
  $analyzers{1}{CCP} = 'PSD_DOWNLOAD_BUNDLE';
  $analyzers{2}{SELECTED} = '+'; 
  $analyzers{2}{CCP} = 'PSD_APPLY_NEW_BUNDLE';
  
  my $ans = 0; 
  until ($ans =~ /^y|^n/i) 
  {
    cls(); 
    print "\n";
    print "  Uninstall AutoUpdate?\n\n";
    print BOLD WHITE ON_BLUE " [Y]es | [N]o | [H]elp",RESET, "\n  Selection:";
    chomp($ans = <STDIN>);
    _uninstallHelp() if $ans =~ /^h/i;
  }
  
  return if $ans =~ /^n/i;
  
  #removeConcProgs 
  removeConcProgs(\%analyzers);
 
  #removeReqGroupEntries
  removeReqGroupEntries(\%analyzers); 
  
  #unlink applyBundleUpdate.pl 
   if (-f $perlFile) 
   {
      unlink($perlFile);
   }
  
  use File::Path 'rmtree';
  
  #unlink java_top files
  #remove java_top dirs
  my $javaBase = $ENV{JAVA_TOP} . "/oracle/support/proactive/atg/bundle"; 
  rmtree($javaBase, 1, 1);
  
  _dropFunction(); 
   
  print "\n INFO: uninstallAutoUpdate() complete. \n";
  
  sub _uninstallHelp 
  {
    cls(); 
    print "\n"; 
    print BOLD WHITE ON_BLUE "  Uninstall AutoUpdate Help", RESET; 
    print qq( 
  o Removes Concurrent Programs & Executables: 
    -PSD_DOWNLOAD_BUNDLE, PSD_APPLY_NEW_BUNDLE 
    -PSD_DL_BUNDLE_EXE, PSD_APPLY_BUNDLE_EXE 
  o Removes Concurrent Programs from any Request Groups
  o Removes applyBundleUpdate.pl from \$FND_TOP/bin 
  o Removes java classes from:
    \$JAVA_TOP/oracle/support/proactive/atg/bundle
  
    Press [Enter] to Continue: ); 
    <STDIN>; 
  }
  
  sub _dropFunction
  {
    print "  INFO: Dropping Function PSD_BUNDLE_VERSION .. \n"; 
    my $cs = $main::connStrg->getConnStrg();
    open(my $drop, ">", 'sql/dropFunc.sql') || die "  ERROR: sub _dropFunction(): Unable to open \"sql/dropFunc.sql\": $! \n"; 
    print $drop qq(
SET SERVEROUTPUT ON
SET TERM OFF
SET VERIFY OFF
SET HEAD OFF

SPOOL sql/dropFunc.lst; 

DROP FUNCTION psd_bundle_version; 
/
SPOOL OFF;
EXIT;);
    close $drop; 
    
   system("sqlplus -s $cs \@sql\/dropFunc.sql");
   unlink("sql/dropFunc.sql"); 
  }#END:  _dropFunction() 
  
  
}#END: uninstallAutoUpdate();

# +---------------------------------------------------------------------------+
# | sub: checkAutoUpdateInstallStatus
# +---------------------------------------------------------------------------+
# | Desc: checks to see if the CP's are installed: 
# |  - PSD_DOWNLOAD_BUNDLE
# |  - PSD_APPLY_NEW_BUNDLE
# +---------------------------------------------------------------------------+
# | Args: nebytiye
# +---------------------------------------------------------------------------+
# | Returns: nada
# +---------------------------------------------------------------------------+
sub checkAutoUpdateInstallStatus
{
  #if we're running as part of AutoUpdate 
  if (length($main::bundleLoc) > 0) 
  {
    chdir($main::bundleLoc . "/MENU");
  }
  my $cs = $main::connStrg->getConnStrg();
  my @sql = qq(
  SET SERVEROUTPUT ON
  SET TERM OFF 
  SET VERIFY OFF 
  SET HEAD OFF

  SPOOL sql/checkAutoUpdateInstallStatus.lst
  SELECT user_concurrent_program_name FROM fnd_concurrent_programs_vl
  WHERE user_concurrent_program_name IN (
  'PSD_APPLY_NEW_BUNDLE', 'PSD_DOWNLOAD_BUNDLE'
  )
  /
  SPOOL OFF;
  EXIT);
  
  open (my $fh, '>', 'sql/checkAutoUpdateInstallStatus.sql' ) || die "  ERROR: checkAutoUpdateInstallStatus(): Cannot open sql/checkAutoUpdateInstallStatus.sql: $! \n";
    print $fh @sql;
  close $fh;
  my $status = system("sqlplus -s $cs \@sql\/checkAutoUpdateInstallStatus.sql");

  open(my $fh, "<", "sql/checkAutoUpdateInstallStatus.lst") || die "  ERROR: checkAutoUpdateInstallStatus(): Unable to open \"sql/checkAutoUpdateInstallStatus.lst\": $! \n"; 
    my @file = <$fh>; 
  close $fh;

  if (grep($_ =~ /PSD_DOWNLOAD_BUNDLE/, @file ) && grep($_ =~ /PSD_APPLY_NEW_BUNDLE/, @file))
  {
    return("Installed"); #good 
  }
  else 
  {
    return("Not Installed"); 
  }

}#END: checkAutoUpdateInstallStatus


# +---------------------------------------------------------------------------++
# | sub: beginUpdate
# +---------------------------------------------------------------------------++
# | Desc: 
# +---------------------------------------------------------------------------++
# | Args: 
# +---------------------------------------------------------------------------++
# | Returns: 
# +---------------------------------------------------------------------------++
sub beginUpdate 
{
  my ($mode) = (@_);
  # --> check for updated bundle.zip in update dir 
  my ($latestZipFile, $latestZipVer) = getHighVersionBundle();
  my $currVer = getBundleVer();
  $main::logr->wl("INFO: running beginUpdate()");
  if ($mode eq 'R')
  {
    my $status;
    unlink ('.update');
    $main::logr->wl("\n\n   INFO: Resuming Update. \n");
    print "\n\n   INFO: Resuming Update. Press [Enter]: ";
    <STDIN>;
    $status = pickListMenu('update');
    if ($status == 0) 
    {
      $main::logr->wlSO("\n\n   INFO: Update successful \n");
      return(0);
    }
    else 
    {
      $main::logr->wlSO("\n\n   ERROR: Update failed. \n");
      return(1);
    }
  }

  my $userSel;
  # if the updated bundle.zip is newer, use it or prompt to check for new? 
  if (defined $latestZipFile)
  {
    cls();
    until ($userSel =~ /^u{1}$/i || $userSel =~ /^d{1}$/i || $userSel =~ /^b{1}$/i)
    {
      print "  INFO: Found file: $latestZipFile, version: \'$latestZipVer\' \n";
      print "  INFO: You are currently using bundle version: \'$currVer\' \n";
      
      my ($minorVersCurr, $minorVersNew);
      $minorVersCurr = $+ if $currVer =~ /\d{3}\.(\d{1,4})/;
      $minorVersNew = $+ if $latestZipVer =~ /\d{3}\.(\d{1,4})/;
      
      print "  WARNING: The current Bundle is newer or equal to $latestZipFile\n\n   Updating is NOT recommended.\n\n" if $minorVersCurr >= $minorVersNew;
      print "  INFO: The current Bundle is lower than $latestZipFile\n\n   Updating is recommended.\n\n" if $minorVersCurr < $minorVersNew;
      print "\n  Use this bundle or attempt to download* a newer one?\n    [*requires My Oracle Support connectivity]\n\n";
      print BOLD WHITE ON_BLUE "  [U]se | [B]ack | [D]ownload",RESET ;
      print BOLD WHITE ON_YELLOW "  Invalid Selection", RESET if defined $userSel;
      print "\n\n   Selection:";
      chomp($userSel = <STDIN>);
      cls();
    }
  }
  else #didn't get a zip version 
  {
    until ($userSel =~ /^u{1}$/i || $userSel =~ /^d{1}$/i || $userSel =~ /^b{1}$/i)
    {
      cls();
      print "\n";
      print BOLD WHITE ON_BLUE "  No Bundle Zip Found",RESET ;
      print "\n\n   INFO: No valid Bundle zip file was found in \'MENU/update\' \n   Download now from Doc ID: 1939637.1?\n\n"   ;
      print BOLD WHITE ON_BLUE "  [D]ownload | [B]ack | [H]elp",RESET ;
      print BOLD WHITE ON_YELLOW "  Invalid Selection", RESET if defined $userSel;
      print "\n\n   Selection:";
      chomp($userSel = <STDIN>);
      _showHelp() if $userSel =~ /^h{1}/i;
      undef $userSel if $userSel =~ /^h{1}/i;
      cls();
    }
  }
  
  if ($userSel =~ /^d{1}/i)
  {
    #download 
    my $status = getBundleUpdate();
    if ($status == 0) 
    {
      my ($zip) = getHighVersionBundle();
      my $status = unzipBundle($zip); #the file name when automatically downloaded will always be bundle.zip  
      if ($status == 0) 
      {
        _reboot();
      }
      else
      {
        print "\n\n   ERROR: Unzip failed, cannot continue.\nPress [Enter]:";
        <STDIN>;
        return();
      }
    }
    else 
    {
      print "\n\n   ERROR: Failed to download new Bundle. \n   Download the bundle manually from Doc ID: 1939637.1\n   and place the zip into the MENU/update directory. \n   Then retry the update process selecting the [U]se option when prompted.  \n\n   Press [Enter] to Continue:";
      <STDIN>;
      return();
    }
  }
  elsif ($userSel =~ /^b{1}/i)
  {
    return();
  }
  elsif ($userSel =~ /^u{1}/i)
  {
    #use the existing MENU/update/bundle.zip 
    #unzip $latestZipFile 
    $main::logr->wlSO("   INFO: Unzipping new Bundle..\n");
    my $status = unzipBundle($latestZipFile);
    if ($status == 0) 
    {
      _reboot();
    }
    else
    {
      print "\n\n   ERROR: Unzip failed, cannot continue.\nPress [Enter]:";
      <STDIN>;
      return();
    }
  }
  
  # -----> if the in-place bundle.zip isn't avail or old, then attempt a download 
  # -------> If the download fails, prompt them to download manually and put it in the update dir 
  # ---> Unzip 
  # --> Run pick list 
  # --> 
  #private sub 
  sub _reboot
  {
    # reboot 
    open (my $fh, '>', '.update' ) || die "beginUpdate(): Cannot create .update: $! \n";
    close $fh;
    print "\n\n   INFO: Next task: Reinstall Concurrent Programs\n   A menu will be displayed upon restart\n\n   Menu.pl needs to be restarted using \'perl Menu.pl\' \n   The update process will resume after the restart. \n\n";
    exit;
  }
  sub _showHelp
  {
    cls(); 
    print "\n"; 
    print BOLD WHITE ON_BLUE "  Update Analyzer Bundle Help", RESET; 
    print qq( 
  o Uses MENU/update/bundle.zip, if present
    This assumes bundle.zip was downloaded previously (manually)
  o If no bundle.zip is present, attempts to download 
    from My Oracle Support via MENU/update/wget.pl
  
    Press [Enter] to Continue: );
    <STDIN>;  
  }#END:  _showHelp 
  
}#END: beginUpdate() 


# +---------------------------------------------------------------------------++
# | sub:  pickListMenu
# +---------------------------------------------------------------------------++
# | Desc: Displays the list of installed analyzers 
# +---------------------------------------------------------------------------++
# | Args: 
# | mode = 'bulk' for bulk load 
# | mode = 'show' for show installed analyzers 
# | mode = 'update" for update pick list. 
# +---------------------------------------------------------------------------++
# | Returns: 
# +---------------------------------------------------------------------------++
sub pickListMenu
{
  my ($mode, $dir) = @_;
  #CCPs is hash: 
  my ($analyzers);
  undef %$analyzers;
  ($analyzers) = getInstalledCCPs() if $mode ne 'bulk';
  my $height = `tput lines`;
  my $width = `tput cols`;
  my $pageSize = ($height - 7);
  
  my $userSel;
  my $invSel = 0;
  my $change;
  
  if ($analyzers == 1 && $mode ne 'bulk')
  {
    #no analyzers found 
    cls();
    print BOLD WHITE ON_BLUE "\n\n   No Analyzer Concurrent Programs Installed", RESET, "\n  Press [Enter] to Continue:";
    <STDIN>;
    return();
  }
  
  if ($mode eq 'update') 
  {
    getNewAnalyzers(\%$analyzers);
    foreach my $ID (sort { $a <=> $b } keys %$analyzers) 
    {
      #if either of the versions could not be detected, default to reload 
      if ($$analyzers{$ID}->{'CURRFILEVER'} =~ /null|new/ || $$analyzers{$ID}->{'NEWFILEVER'} eq '<null>')
      {
        $$analyzers{$ID}->{'SELECTED'} = '+';
      }
      else
      {
        my ($status, $action) = compVersions($$analyzers{$ID}->{'NEWFILEVER'}, $$analyzers{$ID}->{'CURRFILEVER'});
        #action will be replace, same or existing_higher 
        #status of 1 means version check could not be performed 
        
        # print "buggin.. $$analyzers{$ID}->{'FILE'}\n";
        # if ($$analyzers{$ID}->{'FILE'} =~ /workflow_analyzer/)
        # {
          # $DB::single = 1;
        # }
        
        
        if ($status == 0 && $action eq 'replace')
        {
          $$analyzers{$ID}->{'SELECTED'} = '+';
        }
        else
        {
          $$analyzers{$ID}->{'SELECTED'} = ' ';
        }
      }
    }
  }

# The following "if" section is used for updates. If the mode is 'show'
# that is used for the Main Menu Option - show installed analyzers 

if ($mode eq 'update')
{
  $pageSize = ($height - 8);
  my $currPage = 1;
  my $maxPage = (ceil(scalar(keys %$analyzers)/$pageSize));
  my $ID = 1;
  my $newCount = 0;
  until (1 == 2) 
  {
    my ($spc1, $spc2, $verLgth);
    cls();
    print "\n                         ";
    print BOLD WHITE ON_BLUE "Update Concurrent Programs", RESET;
    print "       ";
    print BOLD WHITE ON_GREEN "\n Legend: [+] = Selected To be Updated", RESET;
    print "             ";
    print BOLD WHITE ON_GREEN " [Page $currPage of $maxPage]",RESET;
    print BOLD WHITE ON_BLUE "\n  \#  SELECTED  FAM: TITLE                             INSTALLED | NEW ", RESET, "\n";
    $| = 1;
    for ($ID; $ID <= ($pageSize * $currPage); $ID++)
    {
      next if length($$analyzers{$ID}->{'FAM'}) < 3;
      $newCount++ if $$analyzers{$ID}->{'CURRFILEVER'} =~ /NONE/ && $$analyzers{$ID}->{'NEWFILEVER'} =~ /^\d/;
      print BOLD WHITE ON_GREEN "\n Legend: [+] = Selected To be Installed (New Analyzers)" if $newCount == 1;
      print BOLD WHITE ON_BLUE "\n  \#  SELECTED  FAM: TITLE                             INSTALLED | NEW ", RESET, "\n" if $newCount == 1;
      $spc1 = "  " if $ID > 9;
      $spc1 = "   " if $ID <= 9;
      my $title = $$analyzers{$ID}->{'FAM'} . ': ' . $$analyzers{$ID}->{'CCPTITLE'};
      my $length=length($title) + length("[$ID]") + length($spc1);
      if ($length > 42) 
        { $title = substr($title, 0, 36); $title .= "..."; } 
      my $tabs;
      
      $tabs = "\t\t\t\t" if $length > 14 && $length <= 21;
      $tabs = "\t\t\t" if $length > 21 && $length <= 28;
      $tabs = "\t\t" if $length > 28  && $length <= 37;
      $tabs = "\t" if $length > 37;
      $verLgth = length($$analyzers{$ID}->{'CURRFILEVER'});
      $spc2 = "   | " if $verLgth == 5;
      $spc2 = "  | " if $verLgth == 6;
      $spc2 = " | " if $verLgth == 7;
      print " [$ID]", $spc1, "[$$analyzers{$ID}->{'SELECTED'}]","     $title ",$tabs,"$$analyzers{$ID}->{'CURRFILEVER'}",$spc2,"$$analyzers{$ID}->{'NEWFILEVER'}  \n";
      # print " ^ $length ^\n";
    }
    
    print BOLD WHITE ON_BLUE "\n  [L]oad | [B]ack | [H]elp | E[x]it", RESET;
    print BOLD WHITE ON_GREEN "| [N]ext Page", RESET if $currPage < $maxPage;
    print BOLD WHITE ON_GREEN " | [P]rev Page", RESET if $currPage < $maxPage && $currPage > 1;
    print BOLD WHITE ON_GREEN "| [P]rev Page", RESET if $currPage == $maxPage && $currPage > 1;
    print BOLD WHITE ON_YELLOW "\n Invalid Selection", RESET if $invSel != 0;
    print "  \n   ...\n   Toggle Selections by Number\n";
    print "  Selection:";
    $invSel = 0;
    chomp($userSel = <STDIN>);
    $main::logr->exitLog() if $userSel =~ /^x{1}$/i;

  if (defined $$analyzers{$userSel}) 
  {
    if ($$analyzers{$userSel}->{'SELECTED'} =~ /\+/) {$$analyzers{$userSel}->{'SELECTED'} = ' ';}
    else {$$analyzers{$userSel}->{'SELECTED'} = '+';}
    $ID = ($ID - $pageSize);
  }
  elsif ($userSel =~ /^N{1}/i && $currPage != $maxPage)
  {
    $ID = ($pageSize * $currPage + 1);
    $currPage++;
  }
  elsif ($userSel =~ /^P{1}/i && $currPage != 1)
  {
    $ID = ($ID - ($pageSize * 2));
    $currPage = ($currPage -1);
  }
  elsif ( $userSel =~ /^b$/i )
  {return;}
  elsif ($userSel =~ /^l$/i)
  {
    print qq(\n\n   Reload the selected "[+]" Analyzers?\n);
    print BOLD WHITE ON_BLUE "  [Y]es | [N]o:", RESET;
    my $cont;
    until ($cont =~ /^y|^n/i)
    {
      chomp($cont = <STDIN>);
    }
    if ( $cont =~ /^y/i )
    {
      #8:43 AM 7/1/2019 
      #Changed functionality here: 
      # old code:     
      #my @arrayOfSelected;
      ##load an array to pass to floadbulk that contains all the selected analyzers 

      # foreach my $ID (keys %$analyzers)
      # {
         # if ($$analyzers{$ID}->{'SELECTED'} eq '+')
          # {
            # push (@arrayOfSelected, $$analyzers{$ID}->{'FILE'});
          # }
      # }
      #foreach (@arrayOfSelected) {print "debug106: $_ \n";}
      # floadBulkUpdates(\@arrayOfSelected) if scalar @arrayOfSelected > 0;
      # return;
      
      #end old code 
      #8:44 AM 7/1/2019 
      # new code for 200.15
      floadBulk($analyzers); 
    }
    else
    {
      $ID = 1;
      $currPage = 1;
    }
    
  }
  elsif ($userSel =~ /^h$/i) 
  {
      cls();
      print "\n";
      print BOLD WHITE ON_BLUE "  Reinstall Existing & New Analyzers as Concurrent Programs Help", RESET, "\n";
      print qq (
 o This menu lists and loads analyzers detected as previously installed in the 
   database as concurrent programs, as well as brand new Analyzers
 o Analyzers marked with a "+" will be loaded
 o All new analyzers as well as updated analyzers are marked to 
   be reinstalled by default
 o Selecting "Load" [L] will reinstall the Analyzer's package file (if required)
   and reload the analyzers LDT Program Definition file
 o Loading Analyzers from this menu *only loads the Concurrent Program LDT*, not the 
   Request Group LDT
 o Toggle which analyzers are loaded by selecting the associated number 

   Press [Enter] to Continue:); 
    <STDIN>;
    $ID = ($ID - $pageSize);
  }
  elsif ($userSel =~ /^x$/i)
  {
    $main::logr->exitLog();
  } 
  else
  {
    $ID = ($ID - $pageSize);
    $invSel = 1;
    #repeat the menu again 
    #need to write a loop around the line 146 foreach menu to redisplay it 
  }
  $newCount = 0;
  }#END:  until (1 == 2)
  
}#END:  if mode eq 'update' 
elsif ($mode eq 'show') 
{

$pageSize = ($height - 8);
my $currPage = 1;
my $maxPage = (ceil(scalar(keys %$analyzers)/$pageSize));
my $ID = 1;
my ($spc1, $spc2, $spc3, $verLgth);

until (1 == 2) 
  {
    cls();
    print "\n           ";
    print BOLD WHITE ON_BLUE "Installed Concurrent Programs", RESET;
    print "       ";
    print BOLD WHITE ON_GREEN "[Page $currPage of $maxPage]",RESET;
    print BOLD WHITE ON_BLUE "\n  \#    FAM: TITLE                                #ReqGrps  VERSION", RESET;
    print "\n";
    $| = 1;
    for ($ID; $ID <= ($pageSize * $currPage); $ID++)
    {
      next if length($$analyzers{$ID}->{'FAM'}) < 3;
      $spc1 = "  " if $ID > 9;
      $spc1 = "   " if $ID <= 9;
      $spc3 = " " if length($title) == 2;
      $spc3 = "  " if length($title) == 1;
      my $title = $$analyzers{$ID}->{'FAM'} . ': ' . $$analyzers{$ID}->{'CCPTITLE'};
      if (length $title > 42) 
      { $title = substr($title, 0, 40); $title .= "..."; } 
      my $tabs;
      my $length=((length($spc1) + length($title) + length("[$ID]")));
      $tabs = "\t\t\t\t\t" if $length <= 20;
      $tabs = "\t\t\t\t" if $length > 21 && $length <= 29;
      $tabs = "\t\t\t" if $length >= 30 && $length <= 37;
      $tabs = "\t\t" if $length >= 38 && $length <= 45; ;
      $tabs = "\t" if $length >= 46;
      $verLgth = length($$analyzers{$ID}->{'CURRFILEVER'});
      $spc2 = "   | " if $verLgth == 5;
      $spc2 = "  | " if $verLgth == 6;
      $spc2 = " | " if $verLgth == 7;
      print " [$ID]", $spc1,"$title ",$tabs,$spc3,$$analyzers{$ID}->{'CNTREQGRP'},'  ',"$$analyzers{$ID}->{'CURRFILEVER'}\n";
      #print " ^ $length ^\n";
    }
    print BOLD WHITE ON_BLUE "\n  [B]ack | [H]elp | E[x]it ", RESET;
    print BOLD WHITE ON_GREEN "| [N]ext Page", RESET if $currPage < $maxPage;
    print BOLD WHITE ON_GREEN " | [P]rev Page", RESET if $currPage < $maxPage && $currPage > 1;
    print BOLD WHITE ON_GREEN "| [P]rev Page", RESET if $currPage == $maxPage && $currPage > 1;
    print BOLD WHITE ON_YELLOW "Invalid Selection", RESET if $invSel != 0;
    
    print "  \n  ...\n  Select a Number For Details\n";
    print "\n  Selection:";
    $invSel = 0;
    chomp($userSel = <STDIN>);
  if ($userSel =~ /^b$/i)
  {
    return();
  }
  elsif ($userSel =~ /^N{1}/i && $currPage != $maxPage)
  {
    $ID = ($pageSize * $currPage + 1);
    $currPage++;
  }
  elsif ($userSel =~ /^P{1}/i && $currPage != 1)
  {
    $ID = ($ID - ($pageSize * 2));
    $currPage = ($currPage -1);
  }
  elsif ($userSel =~ /^h$/i) 
  {
      cls();
      print "\n";
      print BOLD WHITE ON_BLUE "  Show Installed Concurrent Programs Help", RESET, "\n";
      print qq (
 o This lists analyzers detected as installed in the database as 
   concurrent programs
 o Note that the version listed is the version of the code executed 
   as the analyzer is called by the Concurrent Managers. This may or 
   may not be the same as the SQL version of analyzers which use a 
   SQL "wrapper" to call their corresponding stored PLSQL packages.
 o "#ReqGrps" indicates the number of Request Groups which have been assigned to the Analyzer Concurrent Program.  
 o "<null>" or "NO_FILE" in the version column indicates the version 
   could not be determined 

   Press [Enter] to Continue:);
   <STDIN>;
   $ID = ($ID - $pageSize);
  }
  elsif ($userSel =~ /^x{1}$/i)
  {
    $main::logr->exitLog();
  }
  elsif (defined $$analyzers{$userSel}) 
  {
    my $return = showAnalyzerDetails($$analyzers{$userSel}->{'FILE'});
    return() if $return eq 'main';
    $ID = ($ID - $pageSize);
  }
  
  
else
  {
    $ID = ($ID - $pageSize);
    $invSel = 1;
    #repeat the menu again 
    #need to write a loop around the line 146 foreach menu to redisplay it 
  }


  }#END:  until (1 == 2)  
}#END:  mode eq show 
elsif ($mode eq 'bulk') 
{
  my @validAnalyzers;
  my %analyzers2;
  find( sub {return unless /\.sql$/; open (my $fh, '<', $_ ) || die $!; my @file=<$fh>; close $fh; push @validAnalyzers, $File::Find::name if grep (/ANALYZER_BUNDLE_START/, @file); }, $dir );
  my $relVer = getRelVer();
    #we have a list of valid analyzer files 
    #from that dir .. now check if they are valid
    foreach my $file (@validAnalyzers)
    {
      my ($compat, $valid) = checkCompat($file, $relVer);
      my $analyzer = analyzer MENU::Analyzer($file);
      my $prod = $analyzer->getProdShortName(); 
      if (! isProdInstalled($prod))
      {
        $main::logr->wlSO("INFO: Not installing $file as the required product \"$prod\" is currently not installed.");
        next;   
      }
      
      
      #version is legit for the release 
      if ($valid == 1)
      {
        #check that the prog template exists;
        
        if ( ! -f ('analyzers/template/' . $analyzer->getProgTemplate())) 
        {
          print "  WARNING: No LDT file exists for ", basename($file), "\n  Concurrent Program for ", $analyzer->getTitle() ," cannot be installed. \n";
          print "  Press [Enter] to Continue: ";
          <STDIN>;
          next;
        }
        else
        {
            my $CCP = $analyzer->getCCPName();
            $$analyzers{$CCP}->{'FILE'} = $file;
            $$analyzers{$CCP}->{'FAM'} = $analyzer->getFam();
            # $analyzers{$CCP}->{'CURRFILEVER'} = $analyzer->getFileVer();
            # $$analyzers{$CCP}->{'CCP'} = $CCP;
            $$analyzers{$CCP}->{'CCPTITLE'} = $analyzer->getTitle();
            # $analyzers{$CCP}->{'REQGROUP'} = $analyzer->getReqGroup();
            # $analyzers{$CCP}->{'PROD'} = $analyzer->getProdShortName();
            #so we can sort the values now: 
            $$analyzers{$CCP}->{'SORT'} = $$analyzers{$CCP}->{'FAM'} . ':' . $$analyzers{$CCP}->{'CCPTITLE'};
        }
      } 
    } 
    
    
    #sort the hash alpha 
      my @arr =  sort {lc($$analyzers{$a}->{'SORT'}) cmp lc($$analyzers{$b}->{'SORT'})} keys %$analyzers;
      my $id = 0;
      foreach my $ccp (@arr) 
      {
        my $analyzer = analyzer MENU::Analyzer($$analyzers{$ccp}->{'FILE'});
        $id++;
        # add to the %hash 
        $analyzers2{$id}->{'ID'} = $id;
        $analyzers2{$id}->{'CCP'} = $ccp;
        $analyzers2{$id}->{'FILE'} = $$analyzers{$ccp}->{'FILE'} ;
        
        $analyzers2{$id}->{'FAM'} = $analyzer->getFam();
        $analyzers2{$id}->{'CURRFILEVER'} = $analyzer->getFileVer();
        $analyzers2{$id}->{'CCPTITLE'} = $analyzer->getTitle();
        $analyzers2{$id}->{'REQGROUP'} = $analyzer->getReqGroup();
        $analyzers2{$id}->{'PROD'} = $analyzer->getProdShortName();
        $analyzers2{$id}->{'SELECTED'} = '+';
      }

  my $currPage = 1;
  my $maxPage = (ceil(scalar(keys %analyzers2)/$pageSize));
  my $ID = 1;
  until (1 == 2) 
  {
    my ($spc1, $verLgth);
    cls();
    $| = 1;
    print "\n                ";
    print BOLD WHITE ON_BLUE "Bulk Load Concurrent Programs",RESET;
    print "       ";
    print BOLD WHITE ON_GREEN "[Page $currPage of $maxPage]",RESET;
    print BOLD WHITE ON_BLUE "\n  \#  SELECTED  FAM: TITLE                                       VERSION", RESET, "\n";
      for ($ID; $ID <= ($pageSize * $currPage); $ID++)
      {
        next if length($analyzers2{$ID}->{'FAM'}) < 3;
        $spc1 = "  " if $ID > 9;
        $spc1 = "   " if $ID <= 9;
        my $title = $analyzers2{$ID}->{'FAM'} . ': ' . $analyzers2{$ID}->{'CCPTITLE'};
        my $length=((length($title) + length("[$ID]" + length($spc1))));
        if ($length > 43) 
          { $title = substr($title, 0, 43); $title .= "..."; } 
        my $tabs;
        #$tabs = "\t\t\t\t\t" if $length > 12 && $length <= 18;
        $tabs = "\t\t\t\t" if $length >= 19 && $length <= 24;
        $tabs = "\t\t\t" if $length > 24 && $length <= 32;
        $tabs = "\t\t" if $length > 32 && $length <= 40;
        $tabs = "\t" if $length > 40;
        $verLgth = length($analyzers2{$ID}->{'CURRFILEVER'});
        print " [$ID]", $spc1, "[$analyzers2{$ID}->{'SELECTED'}]","     $title ",$tabs,"$analyzers2{$ID}->{'CURRFILEVER'}\n";
      }
    print BOLD WHITE ON_BLUE "\n  [L]oad | [B]ack | [H]elp | E[x]it", RESET;
    print BOLD WHITE ON_GREEN "| [N]ext Page", RESET if $currPage < $maxPage;
    print BOLD WHITE ON_GREEN " | [P]rev Page", RESET if $currPage < $maxPage && $currPage > 1;
    print BOLD WHITE ON_GREEN "| [P]rev Page", RESET if $currPage == $maxPage && $currPage > 1;
    print BOLD WHITE ON_YELLOW " Invalid Selection", RESET if $invSel != 0;
    print "  \n   ...\n   Toggle Selections by Number\n";
    print "  Selection:";
    $invSel = 0;
    chomp($userSel = <STDIN>);
    $main::logr->exitLog() if $userSel =~ /^x{1}$/i;

  if (defined $analyzers2{$userSel}) 
  {
    if ($analyzers2{$userSel}->{'SELECTED'} =~ /\+/) {$analyzers2{$userSel}->{'SELECTED'} = ' ';}
    else {$analyzers2{$userSel}->{'SELECTED'} = '+';}
    $ID = ($ID - $pageSize);
  }
  elsif ($userSel =~ /^N{1}/i && $currPage != $maxPage)
  {
    $ID = ($pageSize * $currPage + 1);
    $currPage++;
  }
  elsif ($userSel =~ /^P{1}/i && $currPage != 1)
  {
    $ID = ($ID - ($pageSize * 2));
    $currPage = ($currPage -1);
  }
  elsif ( $userSel =~ /^b$/i )
  {return;}
  elsif ($userSel =~ /^l$/i)
  {
    print qq(\n\n   Load the Selected [+] Analyzers?\n);
    print BOLD WHITE ON_BLUE "  [Y]es | [N]o:", RESET;
    my $cont;
    until ($cont =~ /^y|^n/i)
    {
      chomp($cont = <STDIN>);
    }
    if ( $cont =~ /^y/i )
    {
      floadBulk(\%analyzers2);
      print "  INFO: Done with Bulk Load. Press [Enter] to Continue:";
      <STDIN>;
      return();
    }
  }
  elsif ($userSel =~ /^h$/i) 
    {
      cls();
      print "\n";
      print BOLD WHITE ON_BLUE "  Bulk Load Concurrent Programs Help", RESET, "\n";
      print qq (
   o This lists analyzers selected to be loaded as Concurrent Programs
   o Toggle Selections using numbers, [+] is selected, [ ] is deselected
   o Press [L] to load the selected analyzers into the database using FNDLOAD   
   o Note that the version listed is the version of the code executed 
     as the analyzer is called by the Concurrent Managers. This may or 
     may not be the same as the SQL version of analyzers which use a 
     SQL "wrapper" to call their corresponding stored PLSQL packages. 
   o "<null>" or "NO_FILE" in the version column indicates the version 
     could not be determined 

     Press [Enter] to Continue:);
     <STDIN>;
     $ID = ($ID - $pageSize);
    }
  elsif ($userSel =~ /^x$/i)
  {
    $main::logr->exitLog();
  } 
  else
  {  
    $ID = ($ID - $pageSize);
    $invSel = 1;
    #repeat the menu again 
    #need to write a loop around the line 146 foreach menu to redisplay it 
  }
  }#END:  until (1 == 2)
}#END:  if mode eq bulk 
 
} #END:  pickListMenu

# +---------------------------------------------------------------------------+
# | Sub showAnalyzerDetails 
# +---------------------------------------------------------------------------+ 
# | Args: 
# |
# +---------------------------------------------------------------------------+
sub showAnalyzerDetails
{
  my ($file) = @_;
  my $cs = $main::connStrg->getConnStrg();
  my $analyzer = analyzer MENU::Analyzer($file);
  my $menu = _runSQL($analyzer->getCCPName());
  my $userSel;
  my $invSel = 0;
  my $height = `tput lines`;
  my $width = `tput cols`;
  my $pageSize = ($height - 8);
  my $currPage = 1;
  my $maxPage = (ceil(scalar(keys %$menu)/$pageSize));
  my $ID = 1;
  until (1 == 2) 
  {
    cls();
    print "\n";
    
    #spacing considerations for title: 
    my $titleSpc;
    for (my $i=0; $i < ($width - 26); $i++)
      {
        $titleSpc = $titleSpc . ' ';
      } 
  
    print BOLD WHITE ON_BLUE "  Request Groups For:", $analyzer->getTitle(), RESET;
    print BOLD WHITE ON_GREEN " [Page $currPage of $maxPage]" if $maxPage > 1;
    print "\n";
    print BOLD WHITE ON_BLUE "  REQUEST GROUP",$titleSpc,"PRODUCT ", RESET;
    print "\n\n";
    
    for ($ID; $ID <= ($pageSize * $currPage); $ID++)
    #for my $key (sort { $a <=> $b } keys %$menu)
    {
      #spacing considerations to right align text to terminal 
      my $spcCnt;
      my $spc;
      my $lengthProd = (length($$menu{$ID}->{PRODUCT}) + length($$menu{$ID}->{PRODSHORTNAME}) + 4);
      my $lengthTitle = (length("[$ID]") + length($$menu{$ID}->{REQUESTGROUP}) + 5);
      last if length($$menu{$ID}->{REQUESTGROUP}) < 3;
      if ($width > $length) 
      {
        $spcCnt = -1 * ($lengthTitle - ($width - $lengthProd));
      }
      else 
      {
        $spcCnt = 1;
      }
      for (my $i=0;$i < $spcCnt; $i++)
      {
        $spc = $spc . ' ';
      } 
      print "  [$ID] $$menu{$ID}->{REQUESTGROUP}",$spc,"[$$menu{$ID}->{PRODUCT}, $$menu{$ID}->{PRODSHORTNAME}]\n";
      #print "length: $length spcCnt: $spcCnt spc: \'$spc\'\n";
    }
    print "\n";
    print BOLD WHITE ON_BLUE "  [B]ack | [M]ain Menu | [H]elp | E[x]it ";
    print BOLD WHITE ON_GREEN "| [N]ext Page", RESET if $currPage < $maxPage;
    print BOLD WHITE ON_GREEN " | [P]rev Page", RESET if $currPage < $maxPage && $currPage > 1;
    print BOLD WHITE ON_GREEN "| [P]rev Page", RESET if $currPage == $maxPage && $currPage > 1;
    print BOLD WHITE ON_YELLOW "| Invalid Selection " if $invSel == 1;
    print "\n\n  Select a number to see the associated Responsibilities \n";
    print "  Selection: ";
    chomp($userSel = <STDIN>);
    $invSel = 0;
  if ($userSel =~ /^x{1}/i)
  {
    $main::logr->exitLog();
  }
  elsif ($userSel =~ /^H{1}/i)
  {
    #print Help 
    cls();
    print "\n";
    print BOLD WHITE ON_BLUE "  Analyzer Details Help";
    print qq(
  o Displays a list of Request Groups currently assigned to an Analyzer
  o Choosing a number will show the responsibilities associated with 
    the request group
  o "# of Users Assigned" column shows how many Active Users currently 
    have the responsibility  
  o [B] - Back to the previous screen 
  o [H] - Displays this help 
  o [X] - Exits the application 
  
  Request Group Information: 
  A Concurrent Program cannot be run until it is assigned to a Request Group. 
  A single Request Group can be registered to multiple Responsibilities.

  Press [Enter] to Continue: 
);
  <STDIN>;
  $ID = ($ID - $pageSize);
  }
  elsif ($userSel =~ /^B{1}/i)
  {
    return();
  }
  elsif (defined $$menu{$userSel})
  {
    #Show Responsibilities for a given request group 
    my $return = showResp($$menu{$userSel}->{REQUESTGROUP}, $$menu{$userSel}->{PRODSHORTNAME}); #my ($reqGroup, $appShortName) = @_;
    return('main') if $return eq 'main';
    $ID = ($ID - $pageSize);
    $ID = 1 if $ID < 0;
    #print "debug: $ID \n"; <STDIN>;
  }
  elsif ($userSel =~ /^N{1}/i && $currPage != $maxPage)
  {
    $ID = ($pageSize * $currPage + 1);
    $currPage++;
  }
  elsif ($userSel =~ /^P{1}/i && $currPage != 1)
  {
    $ID = ($ID - ($pageSize * 2));
    $currPage = ($currPage -1);
  }
  elsif ($userSel =~ /^m{1}/i)
  {
    return('main');
  }
  else
  {
    $invSel = 1;
    $ID = ($ID - $pageSize);
    $ID = 1 if $ID < 0;
    #$currPage = ($currPage -1);
  }
  
  }#END:  until 1==2 

# +---------------------------------------------------------------------------++
# | private sub:  
# +---------------------------------------------------------------------------++
# | Desc: _runSQL
# +---------------------------------------------------------------------------++
# | Args: CCP Name 
# +---------------------------------------------------------------------------++
# | Returns: hash of lines from the spool file. 
# | AppShortName::Request Group Name::Responsibility 
# | $lines{$id}->{REQUESTGROUP}=$rg;
# | $lines{$id}->{PRODSHORTNAME}=$psn;
# |  $lines{$id}->{PRODUCT}=$prod;
# | 
# +---------------------------------------------------------------------------++
sub _runSQL
{

my ($ccp) = @_;
  unlink("sql/ccp_req_groups.lst") if -e "sql/ccp_req_groups.lst";
  unlink("sql/ccp_req_groups.sql") if -e "sql/ccp_req_groups.sql";
  
my @sql = qq(
SET SERVEROUTPUT ON
SET TERM OFF 
SET VERIFY OFF 
SET HEAD OFF

SPOOL sql/ccp_req_groups.lst
select distinct frg.request_group_name || '^' || fat2.application_name ||  '^' || fa2.application_short_name
FROM fnd_concurrent_programs fcp, fnd_concurrent_programs_tl fcpt, 
     fnd_application_tl fat, fnd_application fa, 
     fnd_application_tl fat2, fnd_application fa2,
     fnd_request_group_units frgu, fnd_request_groups frg
where fcp.CONCURRENT_PROGRAM_ID = fcpt.CONCURRENT_PROGRAM_ID
and fcp.application_id = fat.application_id 
and fat.application_id = fa.application_id 
and frgu.APPLICATION_ID = fa2.application_id
and fat2.application_id = fa2.application_id
and fat2.language = 'US'
and frgu.request_unit_id = fcp.concurrent_program_id 
and frg.request_group_id = frgu.request_group_id 
and upper(fcp.concurrent_program_name) = '$ccp';
SPOOL OFF;
EXIT);
  
  open (my $fh, '>', 'sql/ccp_req_groups.sql' ) || die "showAnalyzerDetails(): Cannot create sql/ccp_req_groups.sql: $! \n";
  print $fh @sql;
  close $fh;
  my $status = system("sqlplus -s $cs \@sql\/ccp_req_groups.sql");

  my @grps;
  if (-e "sql/ccp_req_groups.lst") 
  {
    open (my $fh, '<', 'sql/ccp_req_groups.lst' ) || die "showAnalyzerDetails(): Cannot create sql/ccp_req_groups.sql: $! \n";
    my @lst = <$fh>;
    close $fh;
    (@grps) = grep(/\^/,@lst);
  }
  else 
  {
    print "  ERROR: showAnalyzerDetails() did not create a spool file \n";
    print "  Press [Enter] to Continue:";
    <STDIN>;
  }

  unlink("sql/ccp_req_groups.lst") if -e "sql/ccp_req_groups.lst";
  unlink("sql/ccp_req_groups.sql") if -e "sql/ccp_req_groups.sql";
  
my %lines;
my $id = 0;

foreach my $line (@grps) 
{
  $id++;
  $line = trim($line);
  my ($rg, $prod, $psn) = split('\^', $line);
  
  $lines{$id}->{REQUESTGROUP}=$rg;
  $lines{$id}->{PRODSHORTNAME}=$psn;
  $lines{$id}->{PRODUCT}=$prod;
}  
return(\%lines);
}#END:  _runSQL

  return();

}#END:  showAnalyzerDetails 


# +---------------------------------------------------------------------------+
# | Sub getBundleUpdate
# +---------------------------------------------------------------------------+ 
# | uses wget.pl to download the bundle.zip from DocID: 1939637.1:BUNDLE 
# |
# +---------------------------------------------------------------------------+
sub getBundleUpdate
{
  cls();
  my $status;
  #check for wget 
  `which wget > /dev/null`;
  $status = $?;
  print "  \n\nERROR: wget executable is required, but not found in the \$PATH \n" if $status > 0;
  
  #check for unzip 
  `which unzip > /dev/null`;
  $status += $?;
  print "  \n\nERROR: unzip executable is required, but not found in the \$PATH \n" if $status > 0;
  
  if ($status > 0)
  {
    print "  \n\nERROR: wget and unzip are required in the \$PATH in order \n    to run this update option. \n   Ensure those utilities are available in the UNIX \$PATH environment variable\n    and retry. \n";
    print "  \n\nPATH: $ENV{PATH}";
  }
  elsif ($status == 0) 
  {
    my $baseURL = hostdomain;
    if ($baseURL =~ /\.oracle\.com$/) 
    {
      $baseURL = 'mosemp.us.oracle.com';
    }
    else 
    {
      $baseURL = 'support.oracle.com';
    }
    #chmod 0755, "update/wget.sh";
    my $httpProxy = getHttpProxy();

  
    if ( -f 'update/XXwget.pl') {
      $status = system("perl update/XXwget.pl \"BUNDLE\" $baseURL $httpProxy");
    } 
    else {
      #$status = system("update/wget.sh $baseURL $httpProxy 2>&1 | tee logs/BundleWget.log");
      $status = system("perl update/wget.pl \"BUNDLE\" $baseURL $httpProxy");
    }
  }
  #Download the bundle to <base>/updates 

  return($status);
}  #END:  getBundleUpdate

sub getHttpProxy
{
  my $cs = $main::connStrg->getConnStrg();
  my @sql = qq(
  SET SERVEROUTPUT ON
  SET TERM OFF 
  SET VERIFY OFF 
  SET HEAD OFF

  SPOOL sql/httpProxy.lst
select 
  extractValue(XMLType(TEXT),'//oa_context/oa_system/oa_web_server/webentryurlprotocol[\@oa_var="s_webentryurlprotocol"]') ||'://'|| 
   fnd_profile.value('WEB_PROXY_HOST') ||':'|| 
   fnd_profile.value('WEB_PROXY_PORT') proxy 
from fnd_oam_context_files a 
where name not in ('TEMPLATE','METADATA') 
  and (status is null or status !='H') 
  and CTX_TYPE = 'A'
  and a.last_synchronized = (select max(last_synchronized) from  fnd_oam_context_files b where a.node_name=b.node_name 
    and   b.name not in ('TEMPLATE','METADATA') 
    and a.CTX_TYPE=b.CTX_TYPE
    ) 
and rownum<2
  /
  SPOOL OFF;
  EXIT);
  
  open (my $fh, '>', 'sql/getHttpProxy.sql' ) || die "  ERROR: getHttpProxy(): Cannot open sql/getHttpProxy.sql: $! \n";
    print $fh @sql;
  close $fh;
  my $status = system("sqlplus -s $cs \@sql\/getHttpProxy.sql");
  print "  INFO: getHttpProxy SQLPLUS exited with status: $status \n";

  open(my $fh, "<", "sql/httpProxy.lst") || die "  ERROR: getHttpProxy(): Unable to open \"sql/httpProxy.lst\": $! \n"; 
  my $returnValue="NO_PROXY";
  
  while (my $line = <$fh>)
  {
    $line = trim($line);
    
    if ($line =~ /(https?:\/\/[^\.:]+(\.[^\.:]+){2,3}:[0-9]+)$/){
      $returnValue = $line;
      last;
    }
  }
  close $fh;

  return $returnValue;
}

# +---------------------------------------------------------------------------++
# | sub:  getHighVersionBundle
# +---------------------------------------------------------------------------++
# | Desc: 
# +---------------------------------------------------------------------------++
# | Args: n/a 
# +---------------------------------------------------------------------------++
# | Returns: the zip file from MENU/update dir 
# | that has the highest version 
# | 
# +---------------------------------------------------------------------------++
sub getHighVersionBundle
{
  my @zips;
  find( sub {return unless /.+?\.zip$/i; push @zips, $File::Find::name;}, "update/" );
  my $version = 0;
  my $highVer = 0;
  my $highVerFile;
  for my $file (@zips) 
  {
    #filter the archive dir out 
    next if $file =~ /archive/;
    #print "version is: $version \n\n";
    my @unzip = `unzip -z $file`;
    ($version) = grep(/version/i, @unzip);
    $version = $+ if $version =~ /(\d*\.\d*)/;
    #print "file: $file version: $version\n";
    
    if ($version > $highVer)
    {
      $highVer = $version;
      $highVerFile = $file;
    }
  }
  $highVer = trim($highVer);
  return ($highVerFile, $highVer);
}


# +---------------------------------------------------------------------------+
# | Sub manualUpdate
# +---------------------------------------------------------------------------+
# |
# | 
# +---------------------------------------------------------------------------+  
sub manualUpdate
{
my ($currVer, $ver);
my $userSel = 0;

sub _rebootManual
  {
    #reboot 
    open (my $fh, '>', '.updateManual' ) || die "manualUpdate(): Cannot create .updateManual: $! \n";
    close $fh;
    print "\n\n   The Perl menu needs to be restarted using \'perl Menu.pl\' \n   The update process will resume after the restart. \n   Press [Enter]: ";
    <STDIN>;
    exit;
  }

  if (-f '.updateManual') 
  {
    print "  INFO: Bundle unzipped successfully. Resuming Update. \n   Press [Enter]: ";
    <STDIN>;
    unlink ('.updateManual');
    pickListMenu('update');
  }
   
  

until (1 == 2) 
  {
      cls();
      print BOLD WHITE ON_BLUE "\n  Manual Download & Update",RESET ;
      print "\n\n";
      #print "  [1] Check bundle.zip version\n";
      #print "  [2] Download new bundle.zip\n";
      print "  [1] Unzip update/bundle.zip\n";
      print "  [2] Reinstall Concurrent Programs\n";
      print "\n  ...\n";
      print BOLD WHITE ON_BLUE "  [B]ack | [H]elp | E[x]it",RESET ;
      print BOLD WHITE ON_YELLOW "   Invalid Selection",RESET if $userSel eq 'invalid';
      print "\n\n   Selection:";
      chomp($userSel=<STDIN>);

  if ($userSel =~ /^1{1}$/i)
  {
    cls();
    print "\n\n   INFO: Please ensure that you have downloaded bundle.zip from \n   Doc ID: 1939637.1, named it \'bundle.zip\' and placed it into the\n   \'MENU/update\' directory.\n\n    Press [Enter] to Continue: ";
    <STDIN>;
    unzipBundle();
    _rebootManual();
  }
  elsif ($userSel =~ /^2{1}$/i)
  {
    pickListMenu('update');
  }
  elsif ($userSel =~ /^h{1}$/i)
  {
      system ("clear");
      print "\n";
      print BOLD WHITE ON_BLUE "  Manual Download & Update Menu Help", RESET, "\n";
      print qq(
 
 o [1] Unzip "update/bundle.zip"
   Unzips the bundle.zip into the base, "MENU" directory. 
   
 o [2] Reinstall Concurrent Programs
    Provides a picklist menu where the user can see which analyzers were 
    previously installed as Concurrent Programs and can choose which ones 
    to reinstall. Reinstalling after an update ensures any new parameters
    are in sync and new features can be used by the Concurrent Program users. 
  
   
     Press [Enter] to Continue:);
      my $w = <STDIN>;
  }
  elsif ($userSel =~ /^b{1}$/i)
  {
    return();
  }
  elsif ($userSel =~ /^x{1}$/i)
  {
    $main::logr->exitLog();
  }    
  else 
  {
    $userSel='invalid';
  }
    
    
  }#END:  until loop 
}#END:  manualUpdate 

# +---------------------------------------------------------------------------+
# | sub getBundleVer 
# +---------------------------------------------------------------------------+
# | 
# | 
# | 
# +---------------------------------------------------------------------------+
sub getBundleVer
  {
    my $line;
    open (my $fh, '<', 'Menu.pl' ) || die "getBundleVer(): Cannot open Menu.pl: $! \n";
    for (0 .. 2) 
      {
        $line = <$fh>;
        last if $line =~ /\$Id:/;
      }
    close $fh;
    my @ar = split(' ', $line);
    $ver = $ar[3];
    $ver = trim($ver);
    return ($ver);
  }
  
# +---------------------------------------------------------------------------+
# | Sub getInstalledCCPs
# +---------------------------------------------------------------------------+
# |#Gets the list of installed analyzers 
# | Returns a hash of Key: CCP Short Name Value: Analyzer File (full path) 
# +---------------------------------------------------------------------------+
sub getInstalledCCPs 
{
  my $cs = $main::connStrg->getConnStrg();
  my $progName;
  my $relVer = getRelVer();
  #build the "IN ('','','') arg and SQL command by grabbing the "PROG_NAME: <name>" line off the header of all valid analyzers.  
  my %analyzers;
  my %instAnalyzers;
  #find all analyzer files 
  my @files;
  find( sub {return unless /\.sql$/; open (my $fh, '<', $_ ) || die $!; my @file=<$fh>; close $fh; push @files, $File::Find::name if (($progName) = grep (/ANALYZER_BUNDLE_START/, @file)); }, 'analyzers/SQL' );
  
  foreach (@files) 
  {
    my $currFile = $_;
    #check if the file is compat 
    my ($compat, $valid) = checkCompat($currFile,$relVer);
    if ($valid == 1) 
    {
      my $analyzer = analyzer MENU::Analyzer($currFile);
      my $CCP = $analyzer->getCCPName();
      #11/19/19 6:11 AM added to stop installing if the product is not installed 
      my $prod = $analyzer->getProdShortName();
      
      if (isProdInstalled($prod))
        {
           $analyzers{$CCP}=$currFile if length($CCP) && length($currFile);
        }
      else 
        {
          $main::logr->wl("getInstalledCCPs(): Product $prod is NOT installed, therefore not installing this analyzer:");
          $main::logr->wl(" -  $currFile");
        }
    }
  }

  #analyzers hash built: Key: CCP name, value: relative path from MENU dir to
  #  file, ex: analyzers/SQL/03_Manufacturing_Analyzers/Procurement/analyze_all.sql 

  my $in = qq(\(\');
  my $i = 0;
  for my $key (keys %analyzers)
  {
    $i++;
    $in .= $key . "\'," if $i == 1;
    $in .= "\'" . $key . "\'," if $i > 1;
  } 
  $in =~ s/,$//;

  unlink('sql/run.sql') if -f 'sql/run.sql';
  unlink('sql/installed_ccps.lst') if -f 'sql/installed_ccps.lst';

my @sql = qq(
set serveroutput on
set term off 
set verify off
set trimspool on
set lines 120
set head off
spool sql/installed_ccps.lst

SELECT 'name:' || cp.concurrent_program_name,'title:' || cp.user_concurrent_program_name,'exe:' || decode(cp.execution_method_code,'I', upper(substr(fe.EXECUTION_FILE_NAME,0,instr(fe.EXECUTION_FILE_NAME,'.')-1)),'Q', '\$'||fav.basepath||'/sql/'||fe.EXECUTION_FILE_NAME||'.sql', cp.execution_method_code), 'CntReqGrp:' || count(rg.request_group_name)
FROM FND_EXECUTABLES fe,FND_APPLICATION_VL fav, fnd_request_groups rg,fnd_request_group_units rgu,fnd_concurrent_programs_vl cp
WHERE fav.application_id = cp.application_id
AND rg.request_group_id = rgu.request_group_id
AND rgu.Request_Unit_Id = cp.concurrent_program_id
and cp.executable_id = fe.executable_id
and fe.application_id = Fav.Application_Id
AND cp.Concurrent_Program_Name in 
$in\) 
group by cp.concurrent_program_name, cp.user_concurrent_program_name,decode(cp.execution_method_code,'I', upper(substr(fe.EXECUTION_FILE_NAME,0,instr(fe.EXECUTION_FILE_NAME,'.')-1)), 'Q', '\$'||fav.basepath||'/sql/'||fe.EXECUTION_FILE_NAME||'.sql', cp.execution_method_code);
spool off;
exit);

  open (my $fh, '>', 'sql/run.sql' ) || die "  getInstalledCCPs(): Cannot open sql/run.sql: $! \n";
  print $fh @sql;
  close $fh;
  my $status = system("sqlplus -s $cs \@sql\/run.sql");
  # check_installed_ccps.lst
  print "  INFO: getInstalledCCPs: SQLPLUS exited with status: $status \n";
  
  open (my $fh, '<', 'sql/installed_ccps.lst' ) || die "Cannot open sql/installed_ccps.lst: $! \n";
  
  my @ccps;
  while (my $line = <$fh>)
  {
    $line = trim($line);
    push @ccps, $line if $line =~/\:/;
  }
  close $fh;

  if (! grep /title:/, @ccps) 
  {
    #print "  INFO: getInstalledCCPs did not find any Analyzer Concurrent Programs \n";
    return(1);
  }

  #@ccps is the list of installed CCPs(concurrent progs) returned from the above DB query 
  #loop through the @ccps array, which is the spool file.. contents are such: 
  # name:APGDFVAL_SINGLE
  # title:AP Single Transaction Data Validation Analyzer
  # CntReqGrp:1
  # exe:AP_GDF_DETECT_PKG

  for (my $i=0; $i < $#ccps; $i++)
  {
    my $ccpName;
    my $line = $ccps[$i];
    if ($line =~ /^name:/)
    {
      $ccpName = $+ if $ccps[$i] =~ /^name:(\w+)/;
      $instAnalyzers{$ccpName}->{'CCP'} = $ccpName;
      #get Title 
      $i++;
      $instAnalyzers{$ccpName}->{'CCPTITLE'} = $+ if $ccps[$i] =~ /^title:(.+)/;
      #get Exe 
      $i++;
      $instAnalyzers{$ccpName}->{'EXECUTABLE'} = $+ if $ccps[$i] =~ /^exe:(\$*.+)/;
      $instAnalyzers{$ccpName}->{'FILE'} = $analyzers{$ccpName};
      my $analyzer = analyzer MENU::Analyzer($instAnalyzers{$ccpName}->{'FILE'});
      $instAnalyzers{$ccpName}->{'FAM'} = $analyzer->getFam();
      $instAnalyzers{$ccpName}->{'SUBFAM'} = $analyzer->getSubfam();
      $instAnalyzers{$ccpName}->{'SORT'} = $instAnalyzers{$ccpName}->{'FAM'} . ': ' . $instAnalyzers{$ccpName}->{'CCPTITLE'};
      $i++;
      $instAnalyzers{$ccpName}->{'CNTREQGRP'} = $+ if $ccps[$i] =~ /^CntReqGrp:(.+)/;
    }
  
    next if length($ccpName) < 3;
      #get versions if file 
    if ($instAnalyzers{$ccpName}->{'EXECUTABLE'} =~ /^\$/)
    {
      #file version checks 
      #convert "$PAY_TOP/sql/retropay_analyzer.sql" to full path 
      my $fullPath = $+ if $instAnalyzers{$ccpName}->{'EXECUTABLE'} =~ /\$(\w+_TOP)\//;
      $fullPath = $ENV{$fullPath} . '/sql/' . basename($instAnalyzers{$ccpName}->{'EXECUTABLE'});
      my $ver = getFileVer($fullPath);
      if ($ver == 1) 
      {
        $instAnalyzers{$ccpName}->{'CURRFILEVER'} ='<null>';
      }
      elsif ($ver == 2) 
      {
        $instAnalyzers{$ccpName}->{'CURRFILEVER'} = 'NO_FILE';
      }
      else 
      {
        #got ver 
        $instAnalyzers{$ccpName}->{'CURRFILEVER'} = $ver;
      }
    }
    else
    {
      my ($status, $ver) = getDBPkgVer($instAnalyzers{$ccpName}->{'EXECUTABLE'});
      if ($status == 0)
      {
        #got ver 
        $instAnalyzers{$ccpName}->{'CURRFILEVER'} = $ver;
      }
      elsif ($status == 2) 
      {
        #package does not exist 
        $instAnalyzers{$ccpName}->{'CURRFILEVER'} ='NO_PACKAGE';
      }
      else
      {
        $instAnalyzers{$ccpName}->{'CURRFILEVER'} ='<null>';
      }
    }
  }#END:  for (my $i=0; $i < $#ccps; $i++)

  
  my @sortedTitles =  sort {lc($instAnalyzers{$a}->{'SORT'}) cmp lc($instAnalyzers{$b}->{'SORT'})} keys %instAnalyzers;
  
  my $id;
  foreach my $ccp (@sortedTitles)
  {
    $id++;
    $instAnalyzers{$id}->{'FILE'} = $instAnalyzers{$ccp}->{'FILE'};
    $instAnalyzers{$id}->{'CURRFILEVER'} = $instAnalyzers{$ccp}->{'CURRFILEVER'};
    $instAnalyzers{$id}->{'EXECUTABLE'} = $instAnalyzers{$ccp}->{'EXECUTABLE'};
    $instAnalyzers{$id}->{'CCPTITLE'} = $instAnalyzers{$ccp}->{'CCPTITLE'};
    $instAnalyzers{$id}->{'CCP'} = $instAnalyzers{$ccp}->{'CCP'};
    $instAnalyzers{$id}->{'FAM'} = $instAnalyzers{$ccp}->{'FAM'};
    $instAnalyzers{$id}->{'SUBFAM'} = $instAnalyzers{$ccp}->{'SUBFAM'};
    $instAnalyzers{$id}->{'CNTREQGRP'} = $instAnalyzers{$ccp}->{'CNTREQGRP'};
    delete($instAnalyzers{$ccp});
  }

  #get the NEWFILEVER 
  for my $id (keys %instAnalyzers)
  {
    if (-e $instAnalyzers{$id}->{'FILE'})
    {
      #We need the version of the deps getDeps() 
      my $analyzer = analyzer MENU::Analyzer($instAnalyzers{$id}->{'FILE'});
      my $depFile = $analyzer->getDeps();
      $instAnalyzers{$id}->{'FAM'} = $analyzer->getFam();
      $instAnalyzers{$id}->{'SUBFAM'} = $analyzer->getSubfam();
      my $ver;
      if ($#$depFile == 0) 
      {
        foreach (@$depFile) 
        {
          $ver = getFileVer($_);
        }
      }
      else 
      {
        $ver = getFileVer($instAnalyzers{$id}->{'FILE'});
      }
      
      if ($ver == 1) 
      {
        $instAnalyzers{$id}->{'NEWFILEVER'} ='<null>';
      }
      else #got ver 
      {
        $instAnalyzers{$id}->{'NEWFILEVER'} =$ver;
      }
    }
    else
    {
      $instAnalyzers{$id}->{'FILE'} = 'NO_FILE';
    }
  }#END for my $id (keys %instAnalyzers)

  # unlink('sql/installed_ccps.lst') if -e 'sql/installed_ccps.lst';
  # unlink('sql/run.sql') if -e 'sql/run.sql';
  return(\%instAnalyzers);

}#END:  getInstalledCCPs 

# +---------------------------------------------------------------------------+
# | sub: getAnalyzersAutoUpdate
# +---------------------------------------------------------------------------+
# | Desc:  build hash of analyzers 
# +---------------------------------------------------------------------------+
# | Args: families of analyzers to get 
# +---------------------------------------------------------------------------+
# | Returns: nada
# +---------------------------------------------------------------------------+
sub getAnalyzersAutoUpdate
{
  my ($fams) = @_;
  my $cs = $main::connStrg->getConnStrg();
  my $progName;
  my $relVer = getRelVer();
  
  $main::logr->wl("getAnalyzersAutoUpdate()"); 
  
  #build the "IN ('','','') arg and SQL command by grabbing the "PROG_NAME: <name>" line off the header of all valid analyzers.  
  my %analyzers;
  my %instAnalyzers;
  #find all analyzer files 
  
  my %famMap = (
  "ATG"   =>  "analyzers/SQL/01_E-Business_Suite_Core_Analyzers",
  "FIN"   =>  "analyzers/SQL/02_Financials_Analyzers",
  "INV"   =>  "analyzers/SQL/03_Manufacturing_Analyzers/Inventory",
  "OM"    =>  "analyzers/SQL/03_Manufacturing_Analyzers/Order_Management",
  "PO"    =>  "analyzers/SQL/03_Manufacturing_Analyzers/Procurement",
  "SCM"   =>  "analyzers/SQL/03_Manufacturing_Analyzers/Supply_Chain_Management",
  "HCM"   =>  "analyzers/SQL/04_Human_Capital_Management_Analyzers",
  "CRM"   =>  "analyzers/SQL/05_Customer_Relationship_Management_Analyzers",
  "ALL"   =>  "analyzers/SQL");
  
  my @files;
  foreach my $f (@$fams) 
  { 
    $f = uc($f);
    if ($famMap{$f}) 
    {
      print "INFO: Searching for analyzers in family: $f \n";
      find( 
        sub 
        {
            return unless /\.sql$/; 
            open (my $fh, '<', $_ ) || die $!; 
            my @file=<$fh>; 
            close $fh; 
            push @files, $File::Find::name if (($progName) = grep (/ANALYZER_BUNDLE_START/, @file)); 
        }, 
        $famMap{$f} 
        );
    }
    else 
    {
       print qq(\n ---------------------------------------------------------------------------
  INFO: Unknown Analyzer Product Family: \"$f\"  \n" 
  --------------------------------------------------------------------------\n);
      usage(1);
    }
    
  }

  my $id = 0;
  foreach my $currFile (@files) 
  {
    #check if the file is compat 
    my ($compat, $valid) = checkCompat($currFile,$relVer);
    if ($valid == 1) 
    {
      $id++;
      my $analyzer = analyzer MENU::Analyzer($currFile);
      my $CCP = $analyzer->getCCPName();
      # $analyzers{$CCP}=$currFile if length($CCP) && length($currFile);
      $analyzers{$id}{'FILE'} = $currFile;
      $analyzers{$id}{'ID'} = $id;
      $analyzers{$id}{'CCPTITLE'} = $analyzer->getTitle();
      $analyzers{$id}{'PROD'} = $analyzer->getProdShortName(); ;
      $analyzers{$id}{'REQGROUP'} = $analyzer->getReqGroup() ;
      $analyzers{$id}{'CCP'} = $analyzer->getCCPName() ;
      $analyzers{$id}{'FAM'} = $analyzer->getFam();
      $analyzers{$id}{'SUBFAM'} = $analyzer->getSubfam();
      $analyzers{$id}{'SELECTED'} = '+';
    }
  }

 return(\%analyzers);
 
}#END: getAnalyzersAutoUpdate 

# +---------------------------------------------------------------------------+
# | sub: unzipFile
# +---------------------------------------------------------------------------+
# | Desc:  
# +---------------------------------------------------------------------------+
# | Args: zip file, the directory to unzip the contents into 
# +---------------------------------------------------------------------------+
# | Returns: 1 = true "success", 0 = false, "failed"
# +---------------------------------------------------------------------------+
sub unzipFile
{
  my ($file, $targetDir) = @_;
  my $unzip=`which unzip`;
  my $OSERR;
  my $status;
  #check for unzip 
  my @ar = `unzip -v`;
  $main::logr->wl("\nINFO: Running unzipFile() for $file\n\n");
  if (grep (/Info-ZIP/, @ar))
  {
    $main::logr->wlSO("  INFO: Found unzip in the \$PATH\n");
  }
  else
  {
    $main::logr->wlSO("  ERROR: No unzip in the \$PATH. \n   Add \'unzip\' to your \$PATH and try again. \n");
    return(0); #false 
  }
  
  #if we're running as part of AutoUpdate 
  if (length($main::bundleLoc) > 0) 
  {
    chdir($main::bundleLoc . "/MENU");
  }
  
  if (! -d $targetDir) 
  {
    mkpath($targetDir, 1, 0755);
    $OSERR = $!;
  }
  
  if (-f $file && -d $targetDir) 
  {
    $status = system("unzip -o $file -d $targetDir");
    $OSERR = $!;
  }
  else 
  {
    print "  ERROR: unzipFile() \n";
    die "  ERROR: File does not exist: $file\n OSERR: $OSERR" if ! -f $file;
    die "  ERROR: Dir does not exist and could not be created:\n dir: \"$targetDir\"\n OSERR: $OSERR" if ! -d $dir;
  }
  
  if ($status > 0) 
  {
    print "  ERROR: unzipFile() \n";
    die "  Failed to unzip:\n \"$file\" \n into dir: \n \"$dir\"\n OSERR: $OSERR";
  }
  
  return(1);
  
}#END: unzipFile

# +---------------------------------------------------------------------------+
# | Sub unzipBundle() 
# +---------------------------------------------------------------------------+
# |
# | 01-OCT-2015: 
# | Create archive dir if it doesn't exist 
# | move all zips into the archive dir 
# +---------------------------------------------------------------------------+
sub unzipBundle
{
  my ($file) = @_;
  my $status;
  my $unzip=`which unzip`;
  #check for unzip 
  my @ar = `unzip -v`;
  $main::logr->wl("\nINFO: Running unzipBundle\n\n");
  
  if (grep (/Info-ZIP/, @ar)) 
  {
    $main::logr->wlSO("   INFO: Found unzip in the \$PATH\n");
  }
  else
  {
    $main::logr->wlSO("   ERROR: No unzip in the \$PATH. \n   Add \'unzip\' to your \$PATH and try again. \n");
    my $w;
    print "  Press [Enter] to Continue: \n";
    $w=<STDIN>;
    return($status);
  }

  my $newDir = 'analyzers_' . (strftime "%Y-%m-%d_%H%M%S", localtime);
  $main::logr->wlSO("   INFO: Renaming the \'analyzers\' directory to: $newDir \n");
  rename("analyzers", $newDir) if -d 'analyzers';
  $main::logr->wlSO("   INFO: Unzipping $file.. \n");
  my $cmd = qq(unzip -o $file -d ../ > /dev/null);
  $status = system($cmd);
  if ($status > 0) 
  {
    $main::logr->wlSO("   ERROR: Unzip exited with status: $status \n");
    print "  Press [Enter] to Continue:";
    <STDIN>;
    return($status);
  }
  elsif ($status == 0) 
  {
    $main::logr->wlSO("   INFO: Unzip successful, status: $status \n");
    if (! -d "update/archive") 
    {
      $main::logr->wlSO("   INFO: Creating update/archive directory\n\n");
      mkdir("update/archive");
    }
    my $newFile = "update/archive/" . basename($file);
    $main::logr->wlSO("   INFO: Moving $file to $newFile");
    move($file, $newFile);
    print "\n\n   Press [Enter] to Continue:";
    <STDIN>;
    return($status);
  }
}


# +---------------------------------------------------------------------------++
# | sub: uninstall() 
# +---------------------------------------------------------------------------++
# | Desc: 
# +---------------------------------------------------------------------------++
# | Args: 
# +---------------------------------------------------------------------------++
# | Returns: 
# +---------------------------------------------------------------------------++
sub uninstall
{
my $userSel;

$main::logr->wl("\nINFO: Running uninstall()\n");
until (1 == 2) #END: less loop 
  {
    $| = 1;
    cls();
    my $count=0;
    print "\n";
    print BOLD WHITE ON_BLUE "  Analyzers Uninstall", RESET, "\n" if $count == 0;
    print BOLD WHITE ON_BLUE "\n  Choose an Option:", RESET, "\n\n" if $count == 0;
    print "  [1] Uninstall All Analyzers \n";
    print "  [2] Remove Individual Analyzers\n";
    print BOLD WHITE ON_BLUE "\n  [B]ack | [H]elp | E[x]it";
    print BOLD WHITE ON_YELLOW "   Invalid Selection", RESET if $userSel eq 'invalid';
    print "\n\n  Selection:";
    chomp($userSel = <STDIN>);
    $main::logr->exitLog() if $userSel =~ /^x{1}/i;
        
      if ($userSel =~ /^1{1}/i)
      {
        $main::logr->wl("\nINFO: User Selected to Uninstall all\n");
        uninstallAll();
      }
      elsif ($userSel =~ /^B{1}/i) 
      {
        return();
      }
      elsif ($userSel =~ /^2{1}/i) 
      {
        uninstallPickList();
      }
      elsif ($userSel =~ /^H{1}/i) 
      {
        #Help
        cls();
        print "\n";
        printf BOLD WHITE ON_BLUE "  Analyzers \"Remove All\" Help", RESET;
        print qq(\n   This option removes all remnants of the Analyzers from your system. The\n   following steps are taken: \n   o Remove all Concurrent Program Request Group Entries\n   o Remove all Concurrent Program Definitions\n   o Remove all Concurrent Executable Definitions\n   o Drop all Analyzer Database Objects\n   o Delete all Analyzer Files from <PROD_TOP>/sql\n\n   Note: All Concurrent Program Data Manipulation (DML) is achieved by this\n   script using the FND_PROGRAM API provided by Oracle Development. \n   See the Oracle Developers Guide for more information. \n\n   The Analyzer Bundle 'MENU' directory structure can be manually removed once \n   the uninstall is completed. (This script does not remove the bundle files). \n\n   Press [Enter] to return to the menu: );
        <STDIN>;
      }
      else
      {
        $userSel='invalid';
      }
  }
}
####### ##########
#  Subs 
########## #########
  
# +---------------------------------------------------------------------------+
# | sub uninstallPickList 
# | 
# +---------------------------------------------------------------------------+
# +---------------------------------------------------------------------------++
# | sub:  uninstallPickList
# +---------------------------------------------------------------------------++
# | Desc: without a mode passed, shows an uninstall picklist to remove analyzers 
# | if mode = show, shows a static list 
# | 
# +---------------------------------------------------------------------------++
# | Args: <null> (default) or "show" 
# +---------------------------------------------------------------------------++
# | Returns: 
# +---------------------------------------------------------------------------++
sub uninstallPickList 
{
  my $analyzers = getInstalledCCPs();
  my $userSel;
  my $invSel = 0;
  my $change;

  # open (my $fh, '>', 'CCPS.txt' );
  # use Data::Dumper;
  # print $fh Dumper (%$analyzers);
  # close $fh;
  
  for my $id (keys %$analyzers) 
  {
    $$analyzers{$id}->{'SELECTED'} = ' ';
    if ($$analyzers{$id}->{'EXECUTABLE'} !~ /^\$/)
    {
      $$analyzers{$id}->{'DROP'} = "drop package $$analyzers{$id}->{'EXECUTABLE'}";
    }
  }
  
  if (! defined $$analyzers{'1'}->{'CCPTITLE'})
    {
      print "  INFO: No Analyzers to Remove\n";
      print "  Press [Enter] to Continue: ";
      <STDIN>;
      return();
    }
  #loop forever. Other exit mechanisms are in place. 
  #keeps the menu alive until user specifies
  #Menu entry:
    my $spc;
    my $currPage = 1;
    my $height = `tput lines`;
    my $width = `tput cols`;
    my $pageSize = ($height - 8);
    my $maxPage = (ceil(scalar(keys %$analyzers)/$pageSize));
    my $ID = 1;
    until (1 == 2)
    {
      cls();
      print BOLD WHITE ON_GREEN "\n Legend: [+] = Selected To be Uninstalled   [Page $currPage of $maxPage]";
      print BOLD WHITE ON_BLUE "\n #  SELECTED    FAM: TITLE                              ", RESET;
      print "\n";
      $| = 1;
      for ($ID; $ID <= ($pageSize * $currPage); $ID++)
      {
        next if length $$analyzers{$ID}->{'FAM'} < 3;
        my $title = $$analyzers{$ID}->{'FAM'} . ': ' . $$analyzers{$ID}->{'CCPTITLE'};
        $spc = '  ' if ($ID > 9);
        $spc = '   ' if ($ID < 9);
        if (length $title > 59) 
          { $title = substr($title, 0, 60); $title .= "..."; } 
        my $tabs;
        my $length=((length($$analyzers{$ID}->{'CCP'}) + length("[$ID]")));
        $tabs = "\t\t\t" if $length <= 13;
        $tabs = "\t\t"  if $length >= 14 && $length <=16;
        $tabs = "\t\t" if $length > 16 && $length <= 20;
        $tabs = "\t" if $length > 20;
        #debug length: 
        # print "[$ID]",$spc,"[$$analyzers{$ID}->{'SELECTED'}]       $title ($length)\n";
        print "[$ID]",$spc,"[$$analyzers{$ID}->{'SELECTED'}]       $title\n";
      }
      print BOLD WHITE ON_BLUE "  [U]ninstall | Select [A]ll | [B]ack | [H]elp | E[x]it",RESET;
      # print BOLD WHITE ON_BLUE "\n  [S]how Analyzers without a Concurrent Program ",RESET;
      print BOLD WHITE ON_GREEN "\n  [N]ext Page", RESET if $currPage < $maxPage;
      print BOLD WHITE ON_GREEN "| [P]rev Page", RESET if $currPage < $maxPage && $currPage > 1;
      print BOLD WHITE ON_GREEN "\n  [P]rev Page", RESET if $currPage == $maxPage && $currPage > 1;
      print BOLD WHITE ON_YELLOW "Invalid Selection", RESET if $invSel != 0;
      print "\n  ...\n   Toggle Selections by Number, [U] to Proceed with Removal\n";
      print "  Selection:";
      $invSel = 0;
      chomp($userSel = <STDIN>);
      $main::logr->exitLog() if $userSel =~ /^x{1}$/i;

    if (defined $$analyzers{$userSel}) 
    {
      if ($$analyzers{$userSel}->{'SELECTED'} =~ /\+/) {$$analyzers{$userSel}->{'SELECTED'} = ' ';}
      elsif ($$analyzers{$userSel}->{'SELECTED'} eq ' ') {$$analyzers{$userSel}->{'SELECTED'} = '+';}
      $ID = ($ID - $pageSize);
    }
    elsif ($userSel =~ /^N{1}/i && $currPage != $maxPage)
    {
      $ID = ($pageSize * $currPage + 1);
      $currPage++;
    }
    elsif ($userSel =~ /^P{1}/i && $currPage != 1)
    {
      $ID = ($ID - ($pageSize * 2));
      $currPage = ($currPage -1);
    }
    elsif ($userSel =~ /^s{1}/i)
    {
      getAnalyzersNoCCP();
      return();
    }
    elsif ($userSel =~ /^u{1}/i)
    {
      my $ans;
      until ($ans =~ /^y|^n/i) 
      {
        print "  Uninstall the Selected [+] Analyzers? [y|n]: ";
        chomp($ans = <STDIN>);
      }
    
      if ($ans =~ /^y/i) 
      {
        $main::logr->wl("INFO: Running uninstallPickList()");
        $main::logr->wl("\n*** *** ***\nINFO: Removing Analyzers:");
        foreach my $ID (sort { $a <=> $b } keys %$analyzers) 
        {
          $main::logr->wl("\n----\nFILE: $$analyzers{$ID}->{'FILE'}\nConcurrent Program: $$analyzers{$ID}->{'CCPTITLE'} \($$analyzers{$ID}->{'CCP'}\)\n----\n ") if $$analyzers{$ID}->{'SELECTED'} =~ /\+/;
        }
        $main::logr->wl("\n*** *** ***\n");
        removeReqGroupEntries($analyzers);
        removeConcProgs($analyzers);
        dropObjects($analyzers);
        deleteFiles('TARGETED', $analyzers);
        return();
      }
      $ID = ($ID - $pageSize);
    }
    elsif ($userSel =~ /^b{1}/i)
    {  
      return();
    }
    elsif ($userSel =~ /^a{1}/i)
    {
      for my $id (keys %$analyzers)
      {
        if ($$analyzers{$id}->{'SELECTED'} eq ' ') {$$analyzers{$id}->{'SELECTED'} = '+';}
      }
      $ID = ($ID - $pageSize);
    }  
    elsif ($userSel =~ /^h{1}/i) 
    {
        cls();
        print "\n";
        print BOLD WHITE ON_BLUE "  Concurrent Program Reinstall Menu Help", RESET, "\n";
        print qq (
  INFO: 
  o This menu lists and uninstalls analyzers detected as installed in the 
   database as concurrent programs.
  o Analyzers marked with a "+" will be uninstalled.  
  o Selecting "Uninstall" [U] will remove: 
    -The Concurrent Program Definition 
    -Any Responsibility Group entries 
    -Any database objects associated with the analyzer
    -Any files installed in the <PROD_TOP>/sql for the analyzer
  USAGE: 
  o Toggle which analyzers are loaded by selecting a number 
    -Please note that the presence of a menu item indicates that either a 
     Concurrent Program or Executable definition exists 

  Press [Enter] to Continue:);
        <STDIN>;
        $ID = ($ID - $pageSize);
      }
    elsif ($userSel =~ /^x$/i)
    {
      $main::logr->exitLog();
    } 
    else
    {
      #invalid selection. 
      $invSel = 1;
      $ID = ($ID - $pageSize);
    }
  }#END:  until (1 == 2)
  
} #END:  pickListMenu


# +---------------------------------------------------------------------------+
# | sub uninstallAll 
# | 
# +---------------------------------------------------------------------------+
sub uninstallAll 
{
  my $analyzers=getInstalledCCPs();
  my $analyzerDBObjs=getInstalledDBobjs();
  my $sizeAnalyzers = keys %{ $analyzers };
  my $sizeAnalyzerDBObjs = keys %{ $analyzerDBObjs };
  if ($sizeAnalyzers == 0 && $sizeAnalyzerDBObjs == 0) 
  {
    print "  INFO: No Analyzers to Remove. \n   Press [Enter] To Continue: ";
    <STDIN>;
    return();
  }
  
  cls();
  $main::logr->wl("\nINFO: Running uninstallAll\n");

  my $ans = '777';
  until ($ans =~ /^y$/i || $ans =~ /^n$/i)
  {
    
    cls(); 
    $main::logr->wlSO("INFO: All Analyzers are about to be removed");
  print qq(\n\n  The following will be removed:
  o Analyzer Entries in Concurrent Request Groups
    [via the plsql API: fnd_program.remove_from_group]
  o Analyzer Concurrent Programs
    [via the plsql API: fnd_program.delete_program]
  o Analyzer Concurrent Executables
    [via the plsql API: fnd_program.delete_executable]
  o Analyzer Database Objects 
  o Analyzer Files stored in Product Tops \"sql\" directories\n\n);
    print BOLD WHITE ON_BLUE "  Continue with Uninstall? [Y|N]:",RESET; 
    print BOLD WHITE ON_YELLOW "  Invalid Selection!", RESET if $ans !~ /777|^y$|^n$/;
    print "\n ->"; 
    chomp($ans = <STDIN>);
    
  }
    if ($ans =~ /^y$/i)
    {
      $main::logr->wl("INFO: User selected to remove all analyzers."); 
      #build list of all analyzer CCPs
      if ($$analyzers{'1'}->{'CCPTITLE'})
      {
        $main::logr->wl("INFO: Running uninstallAll()");
        $main::logr->wl("\nINFO: User Selected To Continue with Uninstall All \n");
        #remove CCPs 
        $main::logr->wl("\n*** *** ***\nINFO: Removing Analyzers:");
        foreach my $ID (sort { $a <=> $b } keys %$analyzers) 
        {
          $main::logr->wl("\n----FILE: $$analyzers{$ID}->{'FILE'}\nConcurrent Program: $$analyzers{$ID}->{'CCPTITLE'} \($$analyzers{$ID}->{'CCP'}\)\n----\n ") if $$analyzers{$ID}->{'SELECTED'} = '+';
        }
        $main::logr->wl("\n*** *** ***\n");
        removeReqGroupEntries($analyzers);
        removeConcProgs($analyzers);
      }
      
      #check for all DB objects
       
      dropObjects($analyzerDBObjs);
      #check & Delete files 
      deleteFiles('all');
    }
    else 
    {return();}
      
print "  INFO: Uninstall Complete.\n";
print "  Press [Enter] to Continue: ";
<STDIN>;
return();

}#END:  uninstallAll


# +---------------------------------------------------------------------------+
# | sub deleteFiles
# | 
# | IF user is using the "uninstall" all option
# | then we'll just check for all possible files by checking an 
# | analyzer's template and removing any files that exist. 
# | Else we can take and return an array of files which exist 
# | 
# | mode: "get" -> return hash with 
# | mode: "all" -> check for and del all possible files from PROD_TOP/sql dirs 
# | mode: "targeted" -> remove files passed in 
# +---------------------------------------------------------------------------+
sub deleteFiles
{
  my ($mode, $analyzers) = @_;
  my @validAnalyzers;
  #get the largest Hash Key so we can add to it 
  my $i = getLargestHashKey($analyzers);
  my $match;
  find( sub {return unless /\.sql$/; open (my $fh, '<', $_ ) || die $!; my @file=<$fh>; close $fh; push @validAnalyzers, $File::Find::name . '::' . $match if (($match) = grep{/PROG_TEMPLATE:\s+?(\w+\.ldt)/} @file) },  'analyzers/SQL' );
  if ($mode eq 'all') 
  {
    foreach (@validAnalyzers) 
    {
      my $f = $_;
      my ($file, $template) = split('::', $f);
      $template = $+ if $template =~ /PROG_TEMPLATE:\s+?(\w+\.ldt)/;
      $template = 'analyzers/template/' . $template;
      open (my $fh, '<', $template ) || die "Cannot open $template for file: $file $! \n";
      my @a=<$fh>;
      close $fh;
      if (grep(/EXECUTION_METHOD_CODE\s\=\s\"Q\"/, @a))
      {
        my $analyzerObj = analyzer MENU::Analyzer($file);
        my $prodTop = $ENV{$analyzerObj->getProdTop} . '/sql/';
        my $file2 = $prodTop . basename($file);
        #print "DEBUG 205: File $file \n" if -f $file;
        
        if (-f $file2) 
        {
          unlink($file2) or warn "Unable to delete $file2: $!";
        }
        else 
        {
          open (my $fh, '<', $file ) || die $!; my @file=<$fh>; close $fh;
          #get the CP_FILE param 
          my ($CPFile) = grep(/REM\s?CP_FILE\:/,@file);
          chomp($CPFile);
          $CPFile =~ s/REM\s+CP_FILE:\s+//g;
          $CPFile = $prodTop . $CPFile;
          if (-f $CPFile)
          {
            unlink($CPFile) or warn "Unable to delete $CPFile: $!";
          }
        }
      }
    }  
  }
  elsif ($mode eq 'get') 
    {
      my @exists;
      foreach (@validAnalyzers) 
      {
        my $f = $_;
        my ($file, $template) = split('::', $f);
        $template = $+ if $template =~ /PROG_TEMPLATE:\s+?(\w+\.ldt)/;
        $template = 'analyzers/template/' . $template;
        open (my $fh, '<', $template ) || die "Cannot open1 $template $! \n";
        my @a=<$fh>;
        close $fh;
        if (grep(/EXECUTION_METHOD_CODE\s\=\s\"Q\"/, @a))
        {
          my $analyzerObj = analyzer MENU::Analyzer($file);
          my $prodTop = $ENV{$analyzerObj->getProdTop} . '/sql/';
          $file = $prodTop . basename($file);
          if (-f $file) #exists in PROD_TOP/sql, so "installed" 
          {
            my $title = $analyzerObj->getTitle();
            #check to see if the hash already contains this title 
            # so as to not add a duplicate. 
            my $match;
            for my $id (keys %$analyzers)
            {
              if ($title eq $$analyzers{$id}->{'CCPTITLE'})
              {
                $match = 'Y';
                $$analyzers{$id}->{'FILE_PROD_TOP'}=$file;
                last;
              }
            }
            if ($match ne 'Y')
            {
              $i++;
              $$analyzers{$i}->{'ID'}=$i;
              $$analyzers{$i}->{'FILE_PROD_TOP'}=$file;
              $$analyzers{$i}->{'SELECTED'}='+';
              $$analyzers{$i}->{'CCPTITLE'}=$title;
            }
          }
        }
      }
      return($analyzers);
    }
  elsif ($mode eq 'TARGETED') 
  {
    for my $id (keys %$analyzers)
    {
      if ($$analyzers{$id}->{'SELECTED'} =~ /\+/ && $$analyzers{$id}->{'EXECUTABLE'} =~ /^\$/ )
      {
        my $prodTop = $+ if $$analyzers{$id}->{'EXECUTABLE'} =~ /\$(\w+?_\w+?)\//;
        $prodTop = $ENV{$prodTop};
        my $file = $prodTop . '/sql/' . basename($$analyzers{$id}->{'EXECUTABLE'});
        unlink($file) or warn "Unable to delete \"$file\": $!" if -f $file;
      }
    }
  }
  return();
}#END deleteFilesCPP
    
# +---------------------------------------------------------------------------+
# | sub dropObjects
# | 
# | Drops database objects as passed in via a hash with a "DROP" key 
# | objects are dropped if they have SELECTED eq '+';
# +---------------------------------------------------------------------------+
sub dropObjects 
{
  my ($analyzers) = @_;
  my $i = 0;
  my $cs = $main::connStrg->getConnStrg();
  # use Data::Dumper;
  # print Dumper(@_);
  # print Dumper(%$analyzers);
  # print "waiting for return: DropObjects \n";
  # <STDIN>;


  unlink "sql/drop.sql" if -f "sql/drop.sql";
  #build a SQL File with the drop statements. 
  open (my $fh, '>', 'sql/drop.sql' ) || die "Cannot open sql/drop.sql: $! \n";

  for my $id (keys %$analyzers) 
    {
      if ($$analyzers{$id}->{'SELECTED'} =~ /\+/ && length($$analyzers{$id}->{'DROP'}) > 5)
      { 
        #print $fh "$$analyzers{$id}->{'DROP'} \;\n";
        print $fh "$$analyzers{$id}->{'DROP'}\n";
        $i++;
      } 
    }
  print $fh "\nexit;";
  close $fh;
  cls();
  #show the drop statements & give the user a chance to abort 
  if ($i >= 1) 
  {
    print "\n  INFO: About to run the following statments: \n   ...\n\n";
    open (my $fh, '<', 'sql/drop.sql' ) || die "Cannot open sql/drop.sql: $! \n";
    while (<$fh>)
    {
      print "   $_";
    }
    close $fh;
    my $ans = '777';
    until ($ans =~ /^b{1}|^c{1}/i) 
    {
      print BOLD WHITE ON_BLUE "\n  [B]ack | [C]ontinue:", RESET;
      print BOLD WHITE ON_YELLOW "  Invalid Selection:", RESET if $ans !~ /777|^b{1}|^c{1}/i;
      chomp($ans=<STDIN>);
    }
    return if $ans =~ /^b$/i ;
    my $status = system("sqlplus -s $cs \@sql/drop.sql"); 
  }

  unlink "sql/drop.sql"; 
  return();
}  
  
  
  
# +---------------------------------------------------------------------------++
# | sub: getInstalledDBobjs 
# +---------------------------------------------------------------------------++
# | Desc: gets all objects which are possible to create from all SQL files under $PWD+
# | Filters list of all objects by objects that are installed. 
# +---------------------------------------------------------------------------++
# | Args: none 
# +---------------------------------------------------------------------------++
# | Returns: %instDBObjs hash: 
# | 
# | 
# | 
# | 
# +---------------------------------------------------------------------------++
sub getInstalledDBobjs
{
  my @sqlFiles;
  my $line;
  my %instDBObjs;
  my $id = 0;
  my @DBObjs;
  my @sql;
  my $cs = $main::connStrg->getConnStrg();
  my $appsUser = $+ if $cs =~ /(\w+?)\//;
      find( sub {return unless /\.sql$/; open (my $fh, '<', $_ ) || die $!; my @file=<$fh>; close $fh; push @sqlFiles, $File::Find::name if grep (/create\s.*?(package\sbody|table|view|function|package)/i, @file) || grep (/create\s*?or\s*?replace/i,@file); }, 'analyzers/SQL' );
  foreach (@sqlFiles) 
  {
    my $file = $_;
    open (my $fh, '<', $file ) || die "Cannot open $file : $! \n";
    while (<$fh>)
    {
      $line = $_;
      $line = clean($line);
      $line = <$fh> until eof($fh) || $line =~ /create/i;
      if ($line =~ /^\s*create\s.*?(package\sbody|table|view|function|package|directory)/i || $line =~ /create\s*?or\s*?replace/i)  
      {
        my ($objectName, $objectType);
        $objectType = $+;
      
        if (! defined $objectType)
        {
          for (0..1)
          {
            $line .= <$fh>;
            $line = clean($line);
          } 
          $line =~ /^\s*(create)|(create\sor\sreplace)\s.*?(package\sbody|table|view|function|package|directory)/i;
          $objectType = $+;
          if (! defined $objectType)
          {
            cls();
            print qq(
  WARNING: getInstalledDBobjs() could not be determine, which, if any objects 
  are created by the following file: 
  
  File: $file 
  
  ACTION: Manually review the file to determine if there are database objects 
  created then drop those objects manually. 
  
  Press [Enter] to Continue: );
            <STDIN>;
          }
        }
        #keep appending the next line until we have the object name. 
        until (defined $objectName && defined $objectType) 
        {
          $line =~ s/\s{2,}/ /g;
          $line =~ s/apps\.//ig;
          $objectName = $+ if $line =~ /$objectType\s(\w*)/i;
          $line .= <$fh>;
          $line = clean($line);
          last if eof($fh);
        }
        
        if (defined $objectName && defined $objectType) 
          {
            next if $objectType eq 'PACKAGE BODY';
            $id++;
            my $statement = "drop " . $objectType . " $appsUser\." . uc($objectName) . ';';
            $objectName=uc($objectName);
            my $dup = 'N';
            for my $ids (keys %instDBObjs)
            {
              $dup = 'Y' if ($instDBObjs{$ids}->{'NAME'} eq $objectName && $instDBObjs{$ids}->{'TYPE'} eq $objectType);
            }
            if ($dup ne 'Y') 
            {
              $instDBObjs{$id}->{'FILE'}=$file; #file where the create statement was found 
              $instDBObjs{$id}->{'DROP'}=$statement;
              $instDBObjs{$id}->{'NAME'}=$objectName;
              $instDBObjs{$id}->{'TYPE'}=$objectType;
              $instDBObjs{$id}->{'SELECTED'}='+';
            }
          }
        }
    }
    close $fh;
  }
my $i=0;
my $in = qq(\(\');
  for my $id (keys %instDBObjs)
  {
    $i++;
    $in .= $instDBObjs{$id}->{'NAME'} . "\'," if $i == 1; ;
    $in .= "\'" . $instDBObjs{$id}->{'NAME'} . "\'," if $i > 1;
  } 
  $in =~ s/,$//;
  $in .= qq(\)\;);

@sql = qq(
set serveroutput off
set term off 
set verify off 
SET PAGESIZE 0

set head off\n\n
spool sql/installed_objs.lst 

SELECT object_name ||':'|| object_type
FROM user_objects
WHERE upper(object_name) in 
$in
spool off;
exit);

open (my $fh, '>', 'sql/checkObjs.sql' ) || die "Cannot open sql/checkObjs.sql: $! \n";
print $fh @sql;
close $fh;
my $status = system("sqlplus -s $cs \@sql\/checkObjs.sql");

  open (my $fh1, '<', "sql/installed_objs.lst" ) || die "Cannot open sql/installed_objs.lst: $! \n";
  while (<$fh1>)
  {
    my $line = $_;
    last if $line =~ /selected/;
    $line = clean($line);
    $line =~ s/\s{2,}//g;
    push @DBObjs, $line if length($line) > 1;
  }
  close $fh1;

  #filter the list of instAnalyzers with what's in the DB from installed_objs.lst 
  #object_name ||':'|| object_type 
  for my $ids (keys %instDBObjs)
  {
    #grep to see if the NAME is in @DBObjs;
    if (! grep /$instDBObjs{$ids}->{'NAME'}\:/, @DBObjs )
    {
      #delete $instDBObjs{$ids}->{'DROP'};
      delete $instDBObjs{$ids};
    }
  }

  unlink 'sql/checkObjs.sql' if -e 'sql/checkObjs.sql';
  unlink 'sql/installed_objs.lst' if -e 'sql/installed_objs.lst';

  return (\%instDBObjs);
} #END:  Sub getInstalledDBobjs
  
# +---------------------------------------------------------------------------+
#| sub linkObjToAnalyzer
#| Links a DB object (probably a dependency) back to an analyzer Title  
#| 
# +---------------------------------------------------------------------------+
sub linkObjToAnalyzer
{
  my ($objectName, $objectType, $file) = @_;
  my $title;
  #check if file is an analyzer SQL 
  open (my $fh, '<', $file ) || warn "Cannot open $file $! \n";
  my @a = <$fh>;
  close ($fh);
  if (grep(/ANALYZER_BUNDLE_START/, @a))
  {
    #This is an analyzer. get the title
    ($title) = grep(/MENU_TITLE:/, @a);
    $title =~ s/^REM\s+MENU_TITLE:\s*//g;
    chomp($title);
    return ($title);
  }
  else 
  {
  my $dir = dirname($file);
  my $fileOnly = basename($file);
  my @files;
  find( sub {return unless /\.sql$/; open (my $fh, '<', $_ ) || die $!; my @file=<$fh>; close $fh; push @files, $File::Find::name if grep (/ANALYZER_BUNDLE_START/i, @file) &&  grep (/$fileOnly/i,@file); }, $dir );
  my $elems = scalar(grep {defined $_} @files);
  if ($elems >= 1)
  {
    for (0 .. 1) 
    {
      my $analyzerFile = shift @files;
      open (my $fh, '<', $analyzerFile ) || die "Cannot open $analyzerFile $! \n";
      my @a = <$fh>;
      close $fh;
      ($title) = grep(/MENU_TITLE:/, @a);
      $title =~ s/^REM\s+MENU_TITLE:\s*//g;
      chomp($title);
      return ($title);
    }
  }
  else 
  {
    print "  ERROR: Unable to trace origins of object: $objectName Type: $objectType, to a file\n   Press [Enter] to Continue:";
    <STDIN>;
    return("Analyzer UNKNOWN, Object: $objectName($objectType)");
  }
}  

}#END linkObjToAnalyzer 

# +---------------------------------------------------------------------------++
# | sub:  getAnalyzersNoCCP
# +---------------------------------------------------------------------------++
# | Desc: locates analyzer packages 
# | which have no associated CPP and 
# | provides a menu interface to drop 
# | those packages 
# +---------------------------------------------------------------------------++
# | Args: none 
# +---------------------------------------------------------------------------++
# | Returns: none 
# +---------------------------------------------------------------------------++
sub getAnalyzersNoCCP 
{
  my $cs = $main::connStrg->getConnStrg();
  my @allDBObjs;
  my $analyzerDBObjs=getInstalledDBobjs();
  for my $id (keys %$analyzerDBObjs)
    {
      if (defined($$analyzerDBObjs{$id}->{'NAME'})) 
      {
        push @allDBObjs, $$analyzerDBObjs{$id}->{'NAME'};
      }
    } 
    
  #get all the CCP DB objects from my $analyzers = getInstalledCCPs();
  my $CCPs = getInstalledCCPs();

  #@CCPDBObjs the list of analyzer DB objects tied to CCPs 
  my @CCPDBObjs;
  for my $id (keys %$CCPs)
    {
      if (defined($$CCPs{$id}->{'CCP'}) && $$CCPs{$id}->{'EXECUTABLE'} !~ /^\$/) 
      {
        push @CCPDBObjs, $$CCPs{$id}->{'EXECUTABLE'};
      }
    }

  #if the object exists in @allDBObjs, but not in CCPDBObjs, add to @delta array 
  my $match;
  my %delta;
  my $i = 0;
  foreach my $obj (@allDBObjs) 
  {
    #if (($match) = grep (/$obj/, @CCPDBObjs))
    if (! grep (/$obj/, @CCPDBObjs))
    {
      $i++;
      $delta{$i}->{'OBJNAME'} = $obj;
      $delta{$i}->{'SELECTED'} = ' ';
      $delta{$i}->{'DROP'} = "drop package $obj;";
    }
  }
  
  my $invSel;
  my $userSel;
  until (1 == 2) 
  {
    my ($spc1, $spc2, $verLgth);
    cls();
    print "         ";
    print BOLD WHITE ON_BLUE "Analyzer Database Objects Without Concurrent Programs", RESET;
    print BOLD WHITE ON_GREEN "\n\n  Legend: [+] = Selected To be Dropped";
    print BOLD WHITE ON_BLUE "\n  \#  SELECTED  OBJECT NAME                  ", RESET;
    print "\n";
    
    $| = 1;
    foreach my $ID (sort { $a <=> $b } keys %delta) 
    {
      $spc1 = "  " if $ID > 9;
      $spc1 = "   " if $ID <= 9;
      my $tabs;
      my $length=((length($delta{$ID}->{'OBJNAME'}) + length("[$ID]")));
      $tabs = "\t\t\t\t" if $length > 12 && $length <= 18;
      $tabs = "\t\t\t" if $length >= 19 && $length <= 28;
      $tabs = "\t\t" if $length >= 28 && $length <= 34;

      $tabs = "\t" if $length > 35;
      print " [$ID]", $spc1, "[$delta{$ID}->{'SELECTED'}]","     $delta{$ID}->{'OBJNAME'} \n";
    
    }
    
    print BOLD WHITE ON_BLUE "\n  [D]rop Selected | [B]ack | [H]elp | E[x]it", RESET;
    print BOLD WHITE ON_YELLOW "Invalid Selection", RESET if $invSel != 0;
    print "  \n   ...\n   Toggle Selections by Number\n";
    print "  Selection:";
    $invSel = 0;
    chomp($userSel = <STDIN>);
    $main::logr->exitLog() if $userSel =~ /^x{1}$/i;

  if ($delta{$userSel} =~ /\d{1,3}/) 
  {
    if ($delta{$userSel}->{'SELECTED'} =~ /\+/) 
    {$delta{$userSel}->{'SELECTED'} = ' ';}
    elsif ($delta{$userSel}->{'SELECTED'} =~ /\s{1}/)
    {$delta{$userSel}->{'SELECTED'} = '+';}
    else
    {$invSel = 1}
  }
  elsif ( $userSel =~ /^b$/i )
  {return;}
  elsif ($userSel =~ /^d$/i)
  {
    if (! grep { $delta{$_}->{'SELECTED'} eq '+' } keys %delta)
    {
      print "  INFO: No Objects Selected. Press [Enter] to Continue:" ;
      <STDIN>;
    }
    else
    {
      dropObjects(\%delta);
      return();
    }
  }
  elsif ($userSel =~ /^h$/i) 
  {
      cls();
      print "\n";
      print BOLD WHITE ON_BLUE "  Drop Analyzer Objects Help", RESET, "\n";
      print qq (
 o This menu displays Analyzer objects that are not associated with a Concurrent Program  
 o These objects may have been loaded via a Menu option or outside the bundle by a 
    stand alone (non-bundled) download 
 o Whenever an analyzer which uses a database object is run, the Bundle Menu loads
   the object 

Press [Enter] to Continue:);
      my $w = <STDIN>;
  }
  elsif ($userSel =~ /^x$/i)
  {
    $main::logr->exitLog();
  } 
  else
  {
    $invSel = 1;
    #repeat the menu again 
    #need to write a loop around the line 146 foreach menu to redisplay it 
  }

  }#END:  until (1 == 2)

}
#END:  Sub getAnalyzersNoCCP

# +---------------------------------------------------------------------------+
#| sub removeConcProgs
#| Removes Conc Program and Executables 
#| 
# +---------------------------------------------------------------------------+
sub removeConcProgs
{
  my ($analyzers) = @_;
  print "  INFO: Running removeConcProgs() to remove Concurrent Programs \n";
  my $in = qq(\(\');
  my $i = 0;
  my $cs = $main::connStrg->getConnStrg();
  for my $id (keys %$analyzers)
  {
    if ($$analyzers{$id}->{'SELECTED'} =~ /\+/ && defined($$analyzers{$id}->{'CCP'})) 
    {
      $i++;
      $in .= $$analyzers{$id}->{'CCP'} . "\'," if $i == 1;
      $in .= "\'" . $$analyzers{$id}->{'CCP'} . "\'," if $i > 1;
    }
  } 
  $in =~ s/,$//;
  $in .= qq(\)\;);
  
  print "  INFO: No Analyzer Concurrent Program Defintions to Remove \n" if $i == 0; 
  return() if ($i == 0); 

unlink('sql/get_installed_ccps.sql') if -f 'sql/get_installed_ccps.sql';
unlink('sql/installed_ccps.lst') if -f 'sql/installed_ccps.lst';

my @sql = qq(
set serveroutput on
set term off 
set verify off 
set head off\n\n
spool sql/installed_ccps.lst

SELECT fcp.concurrent_program_name ||':'|| fav.application_short_name ||':'|| fe.executable_name
FROM fnd_application_vl fav, fnd_executables fe, fnd_concurrent_programs fcp
WHERE fcp.application_id = fav.application_id 
AND fe.application_id = fav.application_id 
AND fe.executable_id = fcp.executable_id 
AND fcp.concurrent_program_name in 
$in
;
spool off;
exit; );
  open (my $fh, '>', 'sql/get_installed_ccps.sql' ) || die "Cannot open sql/get_installed_ccps.sql $! \n";
  print $fh @sql;
  close $fh;
  my $status = system("sqlplus -s $cs \@sql\/get_installed_ccps.sql");
  open (my $fh1, '<', 'sql/installed_ccps.lst' ) || die "Cannot open sql/installed_ccps.lst: $! \n";

  my @a;
  while (<$fh1>) 
  {
    my $ln = $_;
    $ln=clean($ln);
    push @a, $ln if $ln =~ /^\w+\:/;
  }
  close $fh1;

  my @sql2;
  my $elems = scalar(grep {defined $_} @a);
  if ($elems > 0)
  {
    foreach (@a)
    {
      last if $_ =~ /selected\./;
      my ($CCP, $appShortName, $exeName) = split(':',$_);
      $exeName =~ s/\s//g; #clean($appShortName) 
      my $statement=qq(
declare
  lCnt number;
begin
  fnd_program.delete_program(program_short_name => '$CCP', application => '$appShortName');

  select count(*) into lCnt
  from fnd_concurrent_programs p, fnd_application a, fnd_executables e
  where  p.application_id = a.application_id
  and p.executable_application_id =  e.application_id
  and p.executable_id = e.executable_id
  and e.executable_name='$exeName'
  and a.application_short_name ='$appShortName';

  if (lCnt=0) then
    fnd_program.delete_executable(executable_short_name => '$exeName', application => '$appShortName');
  end if;
end;
/
);
      push @sql2, "$statement\n\n";
    }
    push @sql2, "\nCOMMIT; \n \/ \n exit;\n\n";
  } 

  unlink "sql/run_fnd_program_del_prog.sql" if -f "sql/run_fnd_program_del_prog.sql";
  open (my $fh, '>', 'sql/run_fnd_program_del_prog.sql' ) || die "Cannot open sql/run_fnd_program_del_prog.sql $! \n";
  print $fh @sql2;
  close $fh;
  my $elems = scalar(grep {defined $_} @sql2);
  if ($elems > 0) 
  {  
    my $status = system("sqlplus -s $cs \@sql\/run_fnd_program_del_prog.sql");
    #print "  INFO: removeConcProgs(): SQLPLUS command exited with status: $status \n";
    #print "  Press [Enter] to Continue:";
    #<STDIN>;
  } 
  else 
  {
    print "  INFO: removeConcProgs: No Concurrent Programs to Remove \n\n";
  }
  
  unlink "sql/run_fnd_program_del_prog.sql" if -f "sql/run_fnd_program_del_prog.sql";
  unlink('sql/get_installed_ccps.sql') if -f 'sql/get_installed_ccps.sql';
  unlink('sql/installed_ccps.lst') if -f 'sql/installed_ccps.lst';
  return();
}#END:  removeConcProgs
  
# +---------------------------------------------------------------------------+
#| sub removeReqGroupEntries
#| 
#| Uses fnd_program.remove_from_group to delete Concurrent Programs from any request groups 
#| they are associated with
# +---------------------------------------------------------------------------+
sub removeReqGroupEntries
{
  my ($analyzers) = @_;
  my $in = qq(\(\');
  my $i = 0;
  my $cs = $main::connStrg->getConnStrg();
  print "\n  INFO: Running removeReqGroupEntries() to remove Request Group Entries. \n";
  for my $id (keys %$analyzers)
  {
  if ($$analyzers{$id}->{'SELECTED'} =~ /\+/ && defined($$analyzers{$id}->{'CCP'})) 
    {
      $i++;
      $in .= $$analyzers{$id}->{'CCP'} . "\'," if $i == 1; ;
      $in .= "\'" . $$analyzers{$id}->{'CCP'} . "\'," if $i > 1;
    }
  } 
  $in =~ s/,$//;
  $in .= qq(\)\;);
  
  if ($i == 0) 
    {
      #print "  INFO: No Analyzer Request Group Entries to Remove \n   Press [Enter] to Continue:";
      #<STDIN>;
      return();
    }
    
unlink('sql/get_req_groups.sql') if -f 'sql/get_req_groups.sql';
unlink('sql/installed_req_groups.lst') if -f 'sql/installed_req_groups.lst';

my @sql = qq(
SET SERVEROUTPUT ON
SET TERM OFF 
SET VERIFY OFF
SET HEAD OFF\n\n
spool sql/installed_req_groups.lst

SELECT 
cp.concurrent_program_name ||':'|| fav.application_name ||':'|| rg.request_group_name ||':'|| fav.application_short_name
FROM 
FND_APPLICATION_VL fav, 
fnd_request_groups rg,
fnd_request_group_units rgu,
fnd_concurrent_programs cp,
fnd_concurrent_programs_tl cpt
WHERE fav.application_id = rg.application_id
AND rg.request_group_id = rgu.request_group_id
AND rgu.Request_Unit_Id = cp.concurrent_program_id
AND cp.concurrent_program_id = cpt.concurrent_program_id
AND cpt.language = USERENV('LANG')
AND cp.Concurrent_Program_Name in 
$in
;
spool off;
exit; );
  open (my $fh, '>', 'sql/get_req_groups.sql' ) || die "Cannot open sql/get_req_groups.sql $! \n";
  print $fh @sql;
  close $fh;
  my $status = system("sqlplus -s $cs \@sql\/get_req_groups.sql");
  print "  ERROR: Unable to run SQL*PLUS for \"sql\get_req_groups.sql\" " if $status != 0;
  open (my $fh1, '<', 'sql/installed_req_groups.lst' ) || die "Cannot open sql/installed_req_groups.lst: $! \n";
  my @a;
  while (<$fh1>) 
  {
    my $ln = $_;
    $ln=clean($ln);
    push @a, $ln if $ln =~ /^\w+\:/;
  }
  close $fh1;

  my @sql2;
  my $elems = scalar(grep {defined $_} @a);
  if ($elems > 0)
  {
    push @sql2, "SET ESCAPE ON\n";
    foreach (@a)
    {
      my ($CCP, $appName, $reqGrp, $appShortName) = split(':',$_);
      $appShortName =~ s/\s//g; #clean($appShortName) 
      $reqGrp =~ s/&/\\\&/g;
      my $statement=qq(exec fnd_program.remove_from_group (program_short_name => '$CCP', program_application => '$appName', request_group => '$reqGrp', group_application =>'$appShortName'););
      #print "\n****\nCCP: $CCP\nAppName: $appName\nReqGrp: $reqGrp\nShortName: $appShortName\n****\n";
      push @sql2, "$statement\n\n";
    }
    push @sql2, "\nCOMMIT; \n \/ \n exit;\n\n";
  } 

  unlink "sql/run_fnd_program_remove_group.sql" if -f "sql/run_fnd_program_remove_group.sql";
  open (my $fh, '>', 'sql/run_fnd_program_remove_group.sql' ) || die "Cannot open sql/run_fnd_program_remove_group.sql $! \n";
  print $fh @sql2;
  close $fh;
  my $elems = scalar(grep {defined $_} @sql2);
  if ($elems > 0) 
  {
    my $status = system("sqlplus -s $cs \@sql\/run_fnd_program_remove_group.sql");
  } 
  else 
  {
    print "  INFO: No Request Groups to Remove \n\n";
  }
  unlink 'sql/run_fnd_program_remove_group.sql' if -f 'sql/run_fnd_program_remove_group.sql';
  unlink('sql/get_req_groups.sql') if -f 'sql/get_req_groups.sql';
  unlink('sql/installed_req_groups.lst') if -f 'sql/installed_req_groups.lst';
  return();

}#END:  removeReqGroupEntries sub  

# +---------------------------------------------------------------------------+
# | sub clean 
# | cleans carriage returns off a var 
# +---------------------------------------------------------------------------+
sub clean 
  {
    my ($var) = @_;
    chomp($var);
    $var =~ s/\n//g;
    $var =~ s/\r//g;
    return($var);
  }

  
# +---------------------------------------------------------------------------+
# | sub getLargestHashKey
# | 
# | returns the largest key from a given hash. 
# +---------------------------------------------------------------------------+
sub getLargestHashKey
{
  my $hash = shift;
  keys %$hash;
  my ($large_key, $large_val) = each %$hash;
  while (my ($key, $val) = each %$hash) 
  {
    if ($key > $large_key) 
    {
      $large_key = $key;
      $large_key = $key;
    }
  }
  return $large_key;
}

# +---------------------------------------------------------------------------++
# | sub:  getNewAnalyzers
# +---------------------------------------------------------------------------++
# | Desc: searches for the 
# +---------------------------------------------------------------------------++
# | Args: 
# +---------------------------------------------------------------------------++
# | Returns: none - but modifies a hash ref of analyzers 
# +---------------------------------------------------------------------------++
sub getNewAnalyzers
{
  my ($analyzers) = @_;

  #find all the analyzers_<date> dirs and locate the one created most recently.. 
  my %dirs;
  # find( sub {return unless -d && $_ =~ /analyzers_/ ; $dirs{(stat($File::Find::name))[9]}->{'DIR'}=$File::Find::name}, cwd() );
  find( sub {return unless -d && $_ =~ /analyzers_/ ; $dirs{$File::Find::name}->{'TIME'}=(stat($File::Find::name))[9]}, cwd() );
  my $mostRecentDir = _getMax();
  
  my @old;
  my @new;
  #get all the SQL files in the most recent analyzers_ dir 
  # find( sub {return unless /\.sql$/; push @old, basename($File::Find::name)}, $mostRecentDir);
  find( sub {return unless /\.sql$/; open (my $fh, '<', $_ ) || die $!; my @file=<$fh>; close $fh; push @old, $File::Find::name if grep (/ANALYZER_BUNDLE_START/, @file); }, $mostRecentDir );
  #get all the SQL files in the new "analyzers" dir 
  # find( sub {return unless /\.sql$/; push @new, basename($File::Find::name)}, 'analyzers/SQL');
  find( sub {return unless /\.sql$/; open (my $fh, '<', $_ ) || die $!; my @file=<$fh>; close $fh; push @new, $File::Find::name if grep (/ANALYZER_BUNDLE_START/, @file); }, 'analyzers/SQL' );
  
  my %old;
  my %new;
  #create hash with file -> CCPNAME 
  foreach my $file (@new)
  {
    open (my $fh, '<', $file ) || die "Cannot open $file $! \n";
    my @a = <$fh>;
    close $fh;
    my ($CCP) = grep(/REM PROG_NAME:\s*(\w+)\s*$/, @a);
    $CCP = $+ if $CCP =~ /REM PROG_NAME:\s*(\w+)\s*$/;
    # print "$file: ccp \'$CCP\' \n";
    # <STDIN>;
    $new{$file}=$CCP;
  }
  
  foreach my $file (@old)
  {
    open (my $fh, '<', $file ) || die "Cannot open $file $! \n";
    my @a = <$fh>;
    close $fh;
    my ($CCP) = grep(/REM PROG_NAME:\s*(\w+)\s*$/, @a);
    $CCP = $+ if $CCP =~ /REM PROG_NAME:\s*(\w+)\s*$/;
    # print "$file: ccp \'$CCP\' \n";
    # <STDIN>;
    $old{$file}=$CCP;
  }

  #compare %new to %old .. 

  foreach my $newFile (keys %new)
  {
    foreach my $oldFile (keys %old) 
    {
      if ($new{$newFile} eq $old{$oldFile})
      {
        delete $new{$newFile};
      }
    }
  }
  
#the %new hash has been filtered down to only new analyzers 
#which is based on the CCP name existing in the newly unzipped 
#analyzers dir and not existing in the old analyzer_<date> dir
  
    #Get the largest ID from $analyzers hash and set ID to it. 
  my $ID = getLargestHashKey(\%$analyzers);
  
  for my $newFile(keys %new)
  {
      my ($compat, $valid) = checkCompat($newFile);
      if ($valid > 0) 
      {
        my $analyzer = analyzer MENU::Analyzer($newFile);
        next if length($analyzer->getTitle()) < 3;
        $ID++;
        $$analyzers{$ID}->{'ID'}=$ID;
        # find( sub {print "DEBUG:2412: $newFile\n"; return unless /$newFile/; $$analyzers{$ID}->{'FILE'}=$File::Find::name}, 'analyzers/SQL');
        $$analyzers{$ID}->{'CURRFILEVER'}='NONE  '; #intentionally left 2 spaces after "NONE  " for formatting in the menus.
        $$analyzers{$ID}->{'FILE'}=$newFile;
        $$analyzers{$ID}->{'FAM'}=$analyzer->getFam();
        $$analyzers{$ID}->{'CCP'}=$analyzer->getCCPName();
        $$analyzers{$ID}->{'NEWFILEVER'}=$analyzer->getFileVer();
        $$analyzers{$ID}->{'CCPTITLE'}=$analyzer->getTitle();
      }
  }

## private sub 
sub _getMax
{
  my $max = 0;
  my $maxDir;
  for my $dir (keys %dirs)
  {
    if ($dirs{$dir}->{'TIME'} > $max)
    {
      $max = $dirs{$dir}->{'TIME'};
      $maxDir = $dir;
    }
  }
  return ($maxDir);
}

}

return (1);
__END__
# +===========================================================================+
# | HISTORY
# | 200.0 Creation (Nov-11-2014) 
# | 200.1 Creation (Unzip Fixes, creation of the archive directory) 
# | -- all unzipped files (successful) are moved to update/archive/ 
# | 200.2 
# |  --> Fixed Sorting in Pick List Menus 
# |  --> Added in pages-style / tabbed functionality into pick lists. 
# | 200.3 
# | --> Added alphabetical sorting in pickList 
# | 200.4 
# | --> Fixed Request Group select in _runSQL private sub
# | 200.5 
# | --> Removed "/" from selects, causing the query to run 2X 
# | 200.6 
# | --> Updated SQL*PLUS calls, removing "-l" as that param is invalid in 8.0.6
# | 200.7 
# | --> Fixed issue in $BASEURL for wget where there was incorrect regex causing 
# |     internal connections to fail, trying support.oracle.com instead of the correct 
# |     URL for internal Oracle  
# | 200.8 
# | --> Updated all /dev/null redirects to "command > /dev/null" 
# |     This works universally on ksh/bash 
# | 200.9 
# | -- Updated "run.sql", adding "SET lines 120 " per SR 3-15830897651 
# | 200.10 
# | --> Added sub getAnalyzersAutoUpdate for AutoUpdate CCP 
# | 200.11 
# | --> Added installPSDBundleVerPkg() for AutoUpdate CCP  
# | --> Added copyApplyBundlePerlCode()
# | --> Changed updateMenu() for AutoUpdate options
# | 200.12
# | --> Updated to user Logger.pm for logging 
# | 200.13 
# | --> Fixed JDK detection issue for IBM AIX in autoUpdateSetup() sub 
# | 200.14 
# | --> Updates for hybrid 
# | 200.15 11/19/19 6:18 AM
# | --> Updated getInstalledCCPs which builds a hash of Analyzers to install 
# |     If the product is not spliced (such as CLE), the product will be 
# |     excluded from the %analyzers hash and as if the .sql file does not even 
# |     exist. 
# | 200.16 06/01/20 8:01 AM
# | --> Added new classes for BundleUpdate program
# | 200.17 07/14/20 5:13 PM
# | --> Modified message when module is not installed.
# | 200.19 12/15/20 11:24:00 AM
# | --> Added code to handle installation on OCI environment (new "batch" mode),
# |     and fix for issue with concurrent program delete when same EBS executable
# |     is used in more than one program
# | 200.20 06/21/21 18:00:00 AM
# | --> Added code to pull proxy from EBS instance and pass to wget.sh (new parameter)
# | 200.21 07/09/21 9:00:00 AM
# | --> Fixed sql to get proxy data
# | 200.24 10/27/21 9:00:00 PM
# | --> Changed sql to get proxy data in sub getHttpProxy()
# | 200.27 04/24/23 12:00 PM
# | --> Changed call to wget wrapper, now it is wget.pl
# | 200.28 06/20/23 5:00 PM
# | --> Added support for custom wget.pl: XXwget.pl
# |  +===========================================================================+
