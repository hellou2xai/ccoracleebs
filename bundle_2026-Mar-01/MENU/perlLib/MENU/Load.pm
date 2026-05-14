# $Id: Load.pm 200.22 01/19/2024 4:00 PM amlepe bburbage $
# *===========================================================================+
# |  Copyright (c) 2018 Oracle Corporation, Redwood Shores, California, USA  
# |  All rights reserved 
# |  Created by Oracle Support Proactive Services  
# +===========================================================================+
# |
# | FILENAME: Load.pm
# |
# | 
# | PLATFORM
# |   Unix Generic
# |
# | NOTES
# |
# | HISTORY
# | See end of file for history 
# +===========================================================================+

use File::Copy qw(move);
# +---------------------------
# | Subs 
# +---------------------------

# +--------------------------------------------------------------------------+
# | sub: floadBulkAutoUpdate
# +--------------------------------------------------------------------------+
# | Desc:
# |   Bulk Loads analyzers, called from new (Feb 2018) 
# |   "applyBundleUpdate.pl". This is not called, cannot be from Menu.pl 
# | 
# | 
# +--------------------------------------------------------------------------+
# | Args: hash ref 
# | Hash format: 
# | 
# | 'FILE' => 'analyzers/SQL/01_E-Business_Suite_Core_Analyzers/db_param_analyzer.sql',
# | 'ID' => 4,
# | 'CCPTITLE' => 'Database Parameter Settings Analyzer',
# | 'CCP' => 'DB_PARAM_SQL',
# | 'CURRFILEVER' => '200.2',
# | 'FAM' => 'ATG'
# | 'SELECTED' => '+' (if selected) 
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub floadBulkAutoUpdate
{
  my ($analyzers)=@_;
  $main::logr->wlSO("Starting floadBulkAutoUpdate()");
  
  #8:52 AM 7/1/2019 get installed CP's so we can skip loading them to request groups later 
  my $instAnalyzers = getInstalledCCPs(); 
  
  #clean up misc hash entries 
  for my $id (keys %$analyzers)
  {
    if (length($$analyzers{$id}->{'FILE'}) < 3)
    {
      delete($$analyzers{$id});
    }
  }

  for my $id (keys %$analyzers)
  {
    #skip all if the analyzer is was deselected by the user 
    next if $$analyzers{$id}->{'SELECTED'} ne '+';
    
    #start version checking 
    my $check = verChkBeforeLoad($$analyzers{$id}->{'FILE'});
    
    if (1 == 1)
    {
        #masked this off from block vars w/ 1==1 
        my $analyzer = analyzer MENU::Analyzer($$analyzers{$id}->{'FILE'});
        $main::logr->wlSO("INFO: floadBulkAutoUpdate(): Checking if " . $analyzer->getProdShortName() . " is installed"); 
        
        if (! isProdInstalled( $analyzer->getProdShortName()) )
        {
          my $prod = $analyzer->getProdShortName(); 
          $main::logr->wlSO("INFO: Not installing $file as the required product \"$prod\" is currently not installed.");
          next; 
        } 
        
        $main::logr->wlSO("DEBUG1: running isProdInstalled? " . isProdInstalled( $analyzer->getProdShortName())); 
        $main::logr->wlSO("DEBUG2: running isProdInstalled? " . isProdInstalled("BSPROD") ); 

    }
    
    
    #if check == 1, version is equal or higher.. skip everything 
    if ($check == 1) 
    {
      $main::logr->wlSO("INFO: Skipping FNDLOAD of: \"$$instAnalyzers{$id}{CCP}\"\n [$$instAnalyzers{$id}{FILE}] \n The installed version is higher than this bundle provides."); 
      next; 
    } 
    
    if ($check == 2) 
    {
      $main::logr->wlSO("INFO: Unable to version check file: \n", basename($$analyzers{$id}->{'FILE'}),"\n  File will be installed without version checking.\n"); 
    }
    #end version checking 

    $main::logr->wlSO("\nINFO: About to load $$analyzers{$id}->{'FILE'} as a Concurrent Program\n*** *** ***");
    $main::logr->wlSO("\nTITLE: $$analyzers{$id}->{'CCPTITLE'}\nPROGRAM: $$analyzers{$id}->{'CCP'}\nPRODUCT: $$analyzers{$id}->{'PROD'}\nREQUEST GROUP: $$analyzers{$id}->{'REQGROUP'}\n*** *** ***\n\n");
    my $status = checkPrereq($$analyzers{$id}->{'FILE'}, 'cp');
    next if $status > 0;
    
    $status = runDepen($$analyzers{$id}->{'FILE'});
    next if $status > 0;
    
    createProgLDT($$analyzers{$id}->{'FILE'});
    #copySQL($$analyzers{$id}->{'FILE'});
    
    runFNDLOAD();
    my ($match) = grep { $$instAnalyzers{$_}{CCP} eq $$analyzers{$id}{CCP}} keys %$instAnalyzers;
    if (! length($match) )
    {
      $main::logr->wlSO("\nINFO: $$analyzers{$id}{CCP} is not currently installed. Adding it to the default request group:  $$analyzers{$id}{REQGROUP}");
      addToGroup($$analyzers{$id}->{'FILE'});
    }
    else 
    {
      $main::logr->wlSO("\nINFO: $$analyzers{$id}{CCP} is already installed. Skipped adding it to the default request group:  $$analyzers{$id}{REQGROUP}");
    }
  }

  print "INFO: Done with floadBulkAutoUpdate() \n";

}#end floadBulkAutoUpdate

# +--------------------------------------------------------------------------+
# | sub: floadBulkAutoUpdateCloud
# +--------------------------------------------------------------------------+
# | Desc:
# |   Bulk Loads analyzers, called from new (Feb 2018) 
# |   "applyBundleUpdate.pl". This is not called, cannot be from Menu.pl 
# | 
# | 
# +--------------------------------------------------------------------------+
# | Args: hash ref 
# | Hash format: 
# | 
# | 'FILE' => 'analyzers/SQL/01_E-Business_Suite_Core_Analyzers/db_param_analyzer.sql',
# | 'ID' => 4,
# | 'CCPTITLE' => 'Database Parameter Settings Analyzer',
# | 'CCP' => 'DB_PARAM_SQL',
# | 'CURRFILEVER' => '200.2',
# | 'FAM' => 'ATG'
# | 'SELECTED' => '+' (if selected) 
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub floadBulkAutoUpdateCloud_NOT_IMPLEMENTED
{
  print "INFO: Starting floadBulkAutoUpdateCloud() \n";
  my ($analyzers)=@_;
  for my $id (keys %$analyzers)
  {
    if (length($$analyzers{$id}->{'FILE'}) < 3) 
    {
      delete($$analyzers{$id});
    }
  }
  
  for my $id (keys %$analyzers)
  {
    my $check = verChkBeforeLoad($$analyzers{$id}->{'FILE'});
    if ($check == 2)
    {
      print "INFO: Unable to version check file: \n", basename($$analyzers{$id}->{'FILE'}),"\n  File will be installed without version checking.\n";
    }
    if ($check == 0)
    {
      $main::logr->wl("\nINFO: Loading:\n\"$$analyzers{$id}->{'FILE'}\" as a Concurrent Program\n=====================================");
      $main::logr->wl("TITLE: $$analyzers{$id}->{'CCPTITLE'}\nPROGRAM: $$analyzers{$id}->{'CCP'}\nPRODUCT: $$analyzers{$id}->{'PROD'}\nREQUEST GROUP: $$analyzers{$id}->{'REQGROUP'}\n=====================================\n\n");
      my $status = runDepen($$analyzers{$id}->{'FILE'}, 'cp');
      next if $status > 0;
      createProgLDT($$analyzers{$id}->{'FILE'});
      copySQL($$analyzers{$id}->{'FILE'});
    }
    elsif ($check == 1)
    {
      print "INFO: No FNDLOAD actions for $file because the system already contains a higher version\n";
    }
  }

  if (keys %$analyzers > 0)
  {
    my $instAnalyzers = getInstalledCCPs(); 
    for my $id (keys %$analyzers)
    {
      #11:37 AM 6/18/2019 
      #%$analyzers = analyzers for a given family to install 
      #%$instAnalyzers = Analyzers which are installed in the DB 
      my ($match) = grep { $$instAnalyzers{$_}{CCP} eq $$analyzers{$id}{CCP}} keys %$instAnalyzers;
      if (! length($match) )
      {
        $main::logr->wl("\nINFO: $$analyzers{$id}{CCP} is not currently installed. Adding it to the default request group:  $$analyzers{$id}{REQGROUP}");
        addToGroup($$analyzers{$id}->{'FILE'});
      }
      else 
      {
        $main::logr->wl("\nINFO: $$analyzers{$id}{CCP} is already installed. Skipped adding it to the default request group:  $$analyzers{$id}{REQGROUP}");
      }
    }
  }
  runFNDLOAD();
  print "INFO: Done with floadBulkAutoUpdateCloud() \n";

}#end floadBulkAutoUpdateCloud

# +-------------------------------------------------------------------------+
# | sub:  floadBulkUpdates
# +-------------------------------------------------------------------------+
# | Desc: Loads all analyzers provided in a flat array WITHOUT any request groups
# +-------------------------------------------------------------------------+
# | Args: array of analyzers to load 
# +-------------------------------------------------------------------------+
# | Returns: 
# +-------------------------------------------------------------------------+
# | Notes: 
# | 8:45 AM 7/1/2019: 
# | Killed this as we are going to use floadBulk for e're thing 
# +-------------------------------------------------------------------------+
sub floadBulkUpdates_DEAD 
{
  my ($analyzers)=@_;
  my $check;
  my $status;
  my $ans;
  foreach my $file (@$analyzers)
  {
    # my $file = $_ ;
    $check = verChkBeforeLoad($file);
    
    if ($check == 2) 
    {
      print "INFO: Unable to version check file: \n   $file\n   Do you wish to load the file without version checking?\n";
      until ($ans =~ /^y|^n/i)
      {
        print "[Y|N]:";
        <STDIN>;
      }
      if ($ans =~ /^y/i) 
      {
        $check = 0;
      }
      else
      {
        print "INFO: User decided to not proceed with the load of $file \n\n";
      }
    }

    if ($check == 0) 
    {
      my $status = runDepen($file);
      next if $status > 0;
      createProgLDT($file);
      copySQL($file);
    }
    elsif ($check == 1) 
    {
      print "INFO: No FNDLOAD actions for $file because the system already contains a higher version\n";
    }
  }#end foreach 
    
  #new 12:39 PM 6/18/2019
  if (scalar @$analyzers > 0)
  {
    my $instAnalyzers = getInstalledCCPs(); 
    
    foreach my $file (@$analyzers)
    {
      #11:37 AM 6/18/2019 
      #%$analyzers = analyzers for a given family to install 
      #%$instAnalyzers = Analyzers which are installed in the DB 
      my ($match) = grep { $$instAnalyzers{$_}{FILE} eq $file} keys %$instAnalyzers;
      if (! length($match) )
      {
        $main::logr->wl("\nINFO: \"$file\" is not currently installed. Adding the associated concurrent program to the default request group.");
        addToGroup($file);
      }
      else 
      {
        $main::logr->wl("\nINFO: \"$file\" is already installed as a concurrent program. Skipped adding the associated concurrent program to the default request group.");
      }
    }
  }
  runFNDLOAD();
  #old: 12:43 PM 6/18/2019
  # if (scalar @$analyzers > 0)
  # {
  
    # runFNDLOAD();
    # foreach my $file (@$analyzers)
    # {
      # addToGroup($file);
    # } 
  # }
}#End floadBulkUpdates 

# +-------------------------------------------------------------------------+
# | sub:  floadBulk
# +-------------------------------------------------------------------------+
# | Desc: Loads all analyzers provided from a hash 
# | 
# | Hash format: 
# | 
# | 'FILE' => 'analyzers/SQL/01_E-Business_Suite_Core_Analyzers/db_param_analyzer.sql',
# | 'ID' => 4,
# | 'CCPTITLE' => 'Database Parameter Settings Analyzer',
# | 'CCP' => 'DB_PARAM_SQL',
# | 'CURRFILEVER' => '200.2',
# | 'FAM' => 'ATG'
# | 
# +-------------------------------------------------------------------------+
# | Args: array ref 
# +-------------------------------------------------------------------------+
# | Returns: 
# +-------------------------------------------------------------------------+
sub floadBulk
{
  my ($analyzers)=@_;
  
  my $ans;
  if ( $main::run_mode ne 'BATCH' )
  {
    $ans = printWarning();
  }
  else
  {
    $ans = 0;  # continue with default req groups
  }

  displayDirs('analyzers/SQL') if $ans == 2;
  #printReqGroups will optionally print 
  #all the CCP info into a text file / log 
  printReqGroups($analyzers);

  return() if $ans == 1;
  
  
  #clean up misc hash entries 
  for my $id (keys %$analyzers)
  {
    if (length($$analyzers{$id}->{'FILE'}) < 3)
    {
      delete($$analyzers{$id});
    }
  }
  
  my $instAnalyzers = getInstalledCCPs();
  for my $id (keys %$analyzers)
  {
  
    #skip all if the analyzer is was deselected by the user 
    next if $$analyzers{$id}->{'SELECTED'} ne '+';
    
    #start version checking 
    my $check = verChkBeforeLoad($$analyzers{$id}->{'FILE'});
    
    #if check == 1, version is equal or higher.. skip everything 
    if ($check == 1) 
    {
      $main::logr->wlSO("INFO: Skipping FNDLOAD of: \"$$instAnalyzers{$id}{CCP}\"\n [$$instAnalyzers{$id}{FILE}] \n The installed version is higher than this bundle provides."); 
      next; 
    } 
    
    if ($check == 2) 
    {
      if ( $main::run_mode ne 'BATCH' )
      {
        print "INFO: Unable to version check file: \n", basename($$analyzers{$id}->{'FILE'}),"\n  Do you wish to load the file without version checking?\n";
      }
      else
      {
        print "INFO: Unable to version check file: \n", basename($$analyzers{$id}->{'FILE'})," continuing...\n";
        $ans = 'Y';
      }
      until ($ans =~ /^y|^n/i)
      {
        print BOLD WHITE ON_BLUE "  [Y]es | [N]o:", RESET;
        chomp($ans = <STDIN>);
      }
      if ($ans =~ /^y/i) 
      {
        $check = 0;
      }
      else
      {
        $main::logr->wlSO("INFO: User decided to not proceed with the load of $file");
        next; 
      }
    }
    #end version checking 

    $main::logr->wl("\nINFO: About to load $$analyzers{$id}->{'FILE'} as a Concurrent Program\n*** *** ***");
    $main::logr->wl("\nTITLE: $$analyzers{$id}->{'CCPTITLE'}\nPROGRAM: $$analyzers{$id}->{'CCP'}\nPRODUCT: $$analyzers{$id}->{'PROD'}\nREQUEST GROUP: $$analyzers{$id}->{'REQGROUP'}\n*** *** ***\n\n");
    my $status = checkPrereq($$analyzers{$id}->{'FILE'});
    next if $status > 0;
    $status = runDepen($$analyzers{$id}->{'FILE'});
    next if $status > 0;
    createProgLDT($$analyzers{$id}->{'FILE'});
    #copySQL($$analyzers{$id}->{'FILE'});
    
    runFNDLOAD();
    my ($match) = grep { $$instAnalyzers{$_}{CCP} eq $$analyzers{$id}{CCP}} keys %$instAnalyzers;
    if (! length($match) )
    {
      $main::logr->wl("\nINFO: $$analyzers{$id}{CCP} is not currently installed. Adding it to the default request group:  $$analyzers{$id}{REQGROUP}");
      addToGroup($$analyzers{$id}->{'FILE'});
    }
    else 
    {
      $main::logr->wl("\nINFO: $$analyzers{$id}{CCP} is already installed. Skipped adding it to the default request group:  $$analyzers{$id}{REQGROUP}");
    }
  }

}#END: floadBulk 

# +-------------------------------------------------------------------------+
# | sub: printWarning
# +-------------------------------------------------------------------------+
# | Desc: prints the warning before CCPs are bulkloaded 
# +-------------------------------------------------------------------------+
# | Args: none 
# +-------------------------------------------------------------------------+
# | Returns: none 
# +-------------------------------------------------------------------------+
sub printWarning
{

cls(); 

print qq(
  +-----------------------------------------------------------------+
                             Attention                               
  +-----------------------------------------------------------------+
   You are about to bulk load Analyzers as Concurrent Programs and 
   register those Concurrent Programs with default Request Groups.
   Those default Request Groups are: 
    o Seeded into all E-Business Suite Installations 
    o Available to specific Responsibilities
    o In the same Product Area (FND, AP, MFG, etc.) as the Analyzer 
      being loaded 

   Select [C]ontinue to see the list of analyzers included in this 
   bulk load and the default Request Group for each.

   Select [M]ain Menu if you wish to register an Analyzer with a 
   specific Request Group, navigate to the Product, then the Analyzer
   to find single FNDLOAD option where you can optionally change
   the Request Group. 
  +-----------------------------------------------------------------+);

  my $ans;
  until ($ans =~ /^c{1}|^m{1}|^b{1}/i)  
  {
    print BOLD WHITE ON_BLUE "\n  [C]ontinue  [B]ack  [M]ain Menu ";
    print "\n  Selection: ";
    $ans = <STDIN>;
    chomp($ans);
  }
  return (0) if $ans =~ /^c{1}/i;
  return (1) if $ans =~ /^b{1}/i;
  return (2) if $ans =~ /^m{1}/i;
}#END: printWarning

# +-------------------------------------------------------------------------+
# | sub: printReqGroups
# +-------------------------------------------------------------------------+
# | Desc: 
# +-------------------------------------------------------------------------+
# | Args: 
# +-------------------------------------------------------------------------+
# | Returns: 
# +-------------------------------------------------------------------------+
sub printReqGroups 
{
  my ($analyzers) = @_;
  my $ans;
  
  if ( $main::run_mode ne 'BATCH' )
  {
    until ($ans =~ /^y{1,3}|^n{1,2}/i) 
    {
      # system("clear");
      print "  Would you like a log of each Concurrent Program Created? \n   (Includes Request Group Information)\n";
      print BOLD WHITE ON_BLUE "  [Y]es | [N]o:", RESET;
      chomp($ans = <STDIN>);
    }
  }
  else
  {
    $ans = 'Y';
  }

  #getReqGroup 
  if ($ans =~ /^y/i)
  {
    $CCPlog = 'logs/' . "ConcurrentInfo_" . (strftime "%Y-%m-%d_%H%M%S", localtime) . ".log";
    open (my $fh, '>', "$CCPlog" ) || die "printReqGroups(): Cannot open $CCPlog: $! \n";
    print $fh "+--------------------------------+\n Generated on ", (strftime "%d %h %Y %H:%M:%S", localtime)," \n+--------------------------------+\n";
    for my $id (keys %$analyzers) 
    {
      next if length($$analyzers{$id}->{'CCPTITLE'}) < 3;
      print $fh "\n\n";
      my $dash = '+';
      my $cnt = length($$analyzers{$id}->{'CCPTITLE'});
      for (my $i = 0; $i < $cnt; $i++)
      {
        $dash .= '-';
      }
      $dash .= "+\n";
      print $fh " ", $$analyzers{$id}->{'CCPTITLE'}, "\n", $dash;
      print $fh " -Concurrent Program Name: ", $$analyzers{$id}->{'CCP'}, "\n";
      print $fh " -Product Short Name: ", $$analyzers{$id}->{'PROD'}, "\n";
      print $fh " -Request Group: ", $$analyzers{$id}->{'REQGROUP'}, "\n";
      print $fh "$dash\n";
    }
    close $fh;
    print "INFO: The Concurrent Program Information Log is:\n   $CCPlog \n\n";
    if ( $main::run_mode ne 'BATCH' )
    {
      print "  Press [Enter] to Continue: ";
      <STDIN>;
    }
  }
}#END: printReqGroups 


# +-------------------------------------------------------------------------+
# | sub: floadSingle 
# +-------------------------------------------------------------------------+
# | Desc: Loads a single analyzer as a concurrent program
# +-------------------------------------------------------------------------+
# | Args: 
# +-------------------------------------------------------------------------+
# | Returns: 
# +-------------------------------------------------------------------------+
sub floadSingle
{
  my ($file, $floadRef) = @_;
  my $cs = $main::connStrg->getConnStrg();
  my $prodTop;
  my $reqGroup;
  my $progName;
  my $progTemplate;
  my $relVer = getRelVer();
  
  my $analyzer = analyzer MENU::Analyzer($file);
  my $title = $analyzer->getTitle();
  my $deps = $analyzer->getDeps();
  my $reqGrp = $analyzer->getReqGroup();
  my $prodTop = $analyzer->getProdTop();
  my $CCPName = $analyzer->getCCPName();
  my $prodShortName = $analyzer->getProdShortName();
  my $reqGrpApp = $analyzer->getAppName();
  my %groupsToAdd;
  my $userSel;

    if (! isProdInstalled( $prodShortName ))
    {
      cls(); 
      $main::logr->wlSO("INFO: Not running FNDLOAD for $file as the required product \"$prodShortName\" is currently not installed.");
      print "Press [Enter]:"; 
      <STDIN>; 
      return;  
    } 
  
  
  
  if (! -e $file) 
  {
    find( sub {return unless /\.sql$/; $file = $File::Find::name if "$file" eq "$_" }, 'analyzers/SQL' );
  }

  my $check = verChkBeforeLoad($file);
    
  if ($check == 2) 
  {
    print "INFO: Unable to version check file: \n   $file\n   Do you wish to load the file without version checking?\n";
    until ($ans =~ /^y|^n/i)
    {
      print "[Y|N]:";
      <STDIN>;
    }
    if ($ans =~ /^y/i) 
    {
      $check = 0;
    }
    else
    {
      print "INFO: User decided to not proceed with the load of $file\n   Press [Enter] to Continue:";
      <STDIN>;
      return();
    }
  }
  elsif ($check == 1) 
  {
    print "INFO: No FNDLOAD actions for $file because the system already contains a higher version\n   Press [Enter] to Continue:";
    <STDIN>;
    return();
  }
  
#if the check == 0, we did not return yet.. and the following code executes:   

#####
#Check for compat
###
my ($compat, $valid) = checkCompat($file,$relVer);

if ($valid != 1)
  {
    print "ERROR: This Analyzer is not compatible with your E-Business Suite Release ($relVer) \n   Compatible Releases: $compat\n\n   Press [Enter] to Continue: ";
    my $wait = <STDIN>;
    return 1;
  }

#####
#Check if the user wants to use a diff request group other than the default and tell them what they are about to do. 
###

#initialize groupsToAdd with the default req group info
$groupsToAdd{'DEFAULT'}->{'APP_NAME'} = $reqGrpApp;
$groupsToAdd{'DEFAULT'}->{'REQ_GRP'} = $reqGrp;
$groupsToAdd{'DEFAULT'}->{'REQ_GRP_CODE'} = '';

  until (1 == 2)
  {
    my ($reqGrpCode);
    cls(); 
    my $filename = basename($file);
    #just in case 
    chomp($title);
    chomp($filename);
    print BOLD WHITE ON_BLUE "  $title \[$filename\]", RESET;
    print "\n  INFO: About to FNDLOAD the following analyzer as a Concurrent Program.\n  Only the Request Group is optional and configurable.\n";
    print "\n The following parameters will be used:\n"; 
    print "\n  o Concurrent Program Executable Name: $CCPName\n   - Product Short Name: $prodShortName\n   - Product Top: $prodTop \n";
    #diff menus if there were multiple request groups selected. 
    if (keys %groupsToAdd) 
    {
      for my $id (sort { $a <=> $b } keys %groupsToAdd) 
      {
        print "\n  Request Group [Default]\n" if $id =~ /DEFAULT/;
        print "\n  Request Group #$id \n" if $id =~/^\d/;
        print "  o Request Group Application: \'$groupsToAdd{$id}->{'APP_NAME'}\' \n   - Request Group: \'$groupsToAdd{$id}->{'REQ_GRP'}\' \n";
      }
    }
    else 
    {
      print "  o Request Group: \"$reqGrp\"\n  o Request Group Application: \"$reqGrpApp\ \n";
    }

    print BOLD WHITE ON_BLUE "\n  [L]oad | [C]hange/Add Request Groups | [B]ack | [N]o Request Group";
    print BOLD WHITE ON_YELLOW " | Invalid Selection", RESET if $userSel eq 'invalid';
    print "\n";
    print "\n  Selection:";
    chomp($userSel = <STDIN>);
    if ($userSel =~ /^b$/i)
    {
      my $dir = dirname($file);
      my $file = basename($file);
      my ($fileType) = $+ if $file =~ /\.(xml|sql)$/;
      
      #print "debug: $fileType \n"; <STDIN>; 
      
      #11:45 AM 6/20/2019 need to pass the file type in 
      fileMenu($dir, $file, $fileType);
    }
    elsif ($userSel =~ /^n$/i) #no Req Group Load 
    {
      print "\n  Load this Analyzer with no request group?\n   [A request group is required before the Concurrent Program may be run]\n   [Y|N]:";
      chomp(my $resp = <STDIN>);
      if ($resp =~ /^y/i) 
      {
        my $status = checkPrereq($file);
        next if $status > 0;
        $status = runDepen($file);
        next if $status > 0;
        createProgLDT($file);
        #copySQL($file);
        runFNDLOAD($cs);
        return;
      }
    } 
    elsif ($userSel =~ /^c$/i)
    {
      #call changeReqGroup to get a list of groups to add to. Either 0, 1 or more could be returned in a hash.
      if (defined $groupsToAdd{'DEFAULT'}) 
      {
        system('clear');
        my $ans;
        until ($ans =~ /^y{1}/i || $ans =~ /^n{1}/i) 
        {
          print "\n\n";
          print BOLD WHITE ON_BLUE "  Change and/or Add Request Groups", RESET, "\n";
          print "INFO: The default Request Group is:  \n";
          print "  o Request Group: \'$groupsToAdd{'DEFAULT'}->{'REQ_GRP'}\'\n  o Request Group Application: \'$groupsToAdd{'DEFAULT'}->{'APP_NAME'}\' \n";
          print "\n  Would you like to keep the default Request Group? [y|n]:";
          chomp($ans = <STDIN>);
        }
       delete($groupsToAdd{'DEFAULT'}) if $ans =~ /^n{1}/i;
      }
    
      changeReqGroup(\%groupsToAdd);
      
    }#elsif ($userSel =~ /^c$/i)
    elsif ($userSel =~ /^l$/i)
    {
      $main::logr->wl("\nINFO: About to load $filename as a Concurrent Program\n*** *** ***");
      $main::logr->wl("\nTITLE: $title\nPROGRAM: $CCPName\nPRODUCT: $prodShortName\n*** *** ***\n\n");
      my $status = checkPrereq($file);
      next if $status > 0;
      $status = runDepen($file);
      next if $status > 0;
      createProgLDT($file);
      runFNDLOAD($cs);
      for my $id (keys %groupsToAdd) 
      {
        # addToGroup($file, $reqGrpApp, $reqGrp, 'single');
        addToGroup($file, $groupsToAdd{$id}->{'APP_NAME'}, $groupsToAdd{$id}->{'REQ_GRP'},'single');
      }
      #copySQL($file);
      return;
    }
    else
    {
      $userSel = 'invalid';
    }
  }#end UNTIL loop;
  
}#END: floadSingle 

# +-------------------------------------------------------------------------+
# | sub:  changeReqGroup
# +-------------------------------------------------------------------------+
# | Desc: Change / add request groups for the 
# | single FNDLOAD option 
# +-------------------------------------------------------------------------+
# | Args: takes a hash ref as an arg
# | format of hash:
# |   $$groupsToAdd{$ID}->{'APP_NAME'} <request grp application name> 
# |   $$groupsToAdd{$ID}->{'REQ_GRP_CODE'} <request group code - defines forms-level request groups> 
# |   $$groupsToAdd{$ID}->{'REQ_GRP'} <request group name> 
# |  
# +-------------------------------------------------------------------------+
# | Returns: nothing.. modifies the hash ref 
# +-------------------------------------------------------------------------+
sub changeReqGroup 
{
  my ($groupsToAdd) = @_;
  #get the max ID from %$groupsToAdd 
  my $ID = getMaxHashID($groupsToAdd);
  $ID++;
  $ID = 1 if $ID <= 1;
  my $psn;
  until (1 == 2)
  {
    system("clear");
    print "\n";
    print BOLD WHITE ON_BLUE "  Enter Product Short Name", RESET;
    print "\n  Enter the product short name for the desired Request Group.\n  Product Short Name examples: \"FND\",\"AR\",\"SQLAP\", \"XDO\", etc.\n  (Product Short Names are from the FND_APPLICATION table)\n\n  Product Short Name:";
    chomp($psn=<STDIN>);
    
    #get a hash with all the request groups for a given product: 
    my ($h) = getReqGroups($psn);
    if (keys %$h) 
    {
      my ($selGroups) = reqGrpPickList(\%$h);
      return() if $selGroups eq 'main';
      my $dups = 'n';
      if (keys %$selGroups)
      {
        for my $id (sort { $$selGroups{$a} <=> $$selGroups{$b} } keys %$selGroups) 
        {
          $dups = 'n';
          if (keys %$groupsToAdd) 
          {
            #check for dups 
            for my $id2 (keys %$groupsToAdd) 
            {
              if ($$groupsToAdd{$id2}->{'APP_NAME'} eq $$selGroups{$id}->{'APP_NAME'} && $$groupsToAdd{$id2}->{'REQ_GRP'} eq $$selGroups{$id}->{'REQ_GRP'}) 
              {
                print "\n\nINFO: You previously added the following Request Group:\n  o Request Group Application: \'$$selGroups{$id}->{'APP_NAME'}\' \n  o Request Group: \'$$selGroups{$id}->{'REQ_GRP'}' \n  This will not be added to the queue. \n\n  Press [Enter] to Continue:";
                $dups = 'y';
                <STDIN>;
              }
            }
          }
          #add the groups to the queue if they are not dups 
          if ($dups eq 'n')
          {
            $$groupsToAdd{$ID}->{'APP_NAME'} = $$selGroups{$id}->{'APP_NAME'};
            $$groupsToAdd{$ID}->{'REQ_GRP_CODE'} = $$selGroups{$id}->{'REQ_GRP_CODE'};
            $$groupsToAdd{$ID}->{'REQ_GRP'} = $$selGroups{$id}->{'REQ_GRP'};
            print BOLD WHITE ON_BLUE "\n  Queued to load:", RESET," \n  o Request Group: \'$$selGroups{$id}->{'REQ_GRP'}\' \n  o Request Group Application: $$selGroups{$id}->{'APP_NAME'} \n";
            $ID++;
          }
        }
        print "\nINFO: The new Request Group(s) are not committed until you run\n  the \'[L]oad\' option from the Menu \n";
      }#end if keys %$selGroups 
      else
      {
        #user aborted pick list.. 
        print "\n\nINFO: User Aborted the Request Group Pick List.\n";
        print "  Press [Enter] to Continue:";
        <STDIN>;
      }
    }
    print "\n\n  Add Another Request Group for this Concurrent Program? [y|n]: ";
    my $userResp;
    chomp($userResp = <STDIN>);
    return() if $userResp =~ /^n.*$/i;
  }#end until() 

}#END: changeReqGroup 

# +-------------------------------------------------------------------------+
# | sub:  getMaxHashID
# +-------------------------------------------------------------------------+
# | Desc: checks a hash and returns the max integer from the key 
# +-------------------------------------------------------------------------+
# | Args: a request group to be validated 
# +-------------------------------------------------------------------------+
# | Returns: max ID (int) 
# +-------------------------------------------------------------------------+
sub getMaxHashID
{
  my ($hash) = @_;
  my $max = 0;
  for my $id (sort { $$hash{$a} <=> $$hash{$b} } keys %$hash)
  {
    if ($id > $max)
    {
      $max = $id;
    }
  }
  return ($max);
}#END: getMaxHashID


# +-------------------------------------------------------------------------+
# | sub:  validateReqGrp
# +-------------------------------------------------------------------------+
# | Desc: checks to see if a request group 
# | exists and is valid for a given product 
# +-------------------------------------------------------------------------+
# | Args: a request group to be validated 
# +-------------------------------------------------------------------------+
# | Returns: hash:  $h{$prod}=$grp;
# +-------------------------------------------------------------------------+
sub validateReqGrp
{
  unlink 'sql/req_groups.lst' if -e 'sql/req_groups.lst';
  my ($wantedReqGrp) = @_;
  my $cs = $main::connStrg->getConnStrg();
  my %h;
  
  if (! -f "sql/check_req_group.sql") 
  {
    open(my $fh, '>', 'sql/check_req_group.sql' ) || die "Cannot open 'sql/check_req_group.sql': $! \n";
    print $fh qq(
SET SERVEROUTPUT ON
SET TERM OFF
SET VERIFY OFF
SET HEAD OFF

SPOOL sql/req_groups.lst

SELECT fa.application_short_name || ':' || frg.request_group_name || ':' || frg.request_group_code
FROM FND_APPLICATION FA, FND_REQUEST_GROUPS FRG
WHERE frg.application_id = fa.application_id
AND frg.request_group_name = '&1';
SPOOL OFF;
EXIT;);
close $fh;
  }
    
  my $status = system("sqlplus -S $cs \@sql/check_req_group.sql \"$wantedReqGrp\"");
  warn "sqlplus failed while checking for a valid request group" if $status != 0;
    
  if (-f 'sql/req_groups.lst')
  {
    open (my $fh, '<', 'sql/req_groups.lst' ) || die "Cannot open 'sql/req_groups.lst': $! \n";
    while (my $line = <$fh>) 
    {
      next unless $line =~ /$wantedReqGrp/;
      chomp($line);
      my ($prod, $grp, $rgCode) = split(':', $line);
      $prod = trim($prod);
      $grp = trim($grp);
      $rgCode = trim($rgCode);
      
      $h{$prod}=$grp;
      $h{$prod}->{'REQ_GRP_CODE'}=$rgCode;
    }
    close $fh;
  }
  else
  {
    print "  WARNING: Unable to run SQL*PLUS to check the Request Group \n   A spool file was not created from the command: \n  sqlplus -S <connect string> \@sql/check_req_group.sql \"$wantedReqGrp\" ";
    print "  Press [Enter] to Continue: ";
    <STDIN>;
  }
  unlink 'sql/req_groups.lst' if -e 'sql/req_groups.lst';
  return(\%h);
}#END: validateReqGrp 

# +---------------------------
# | sub getRelVer() 
# | Determine Release from Context File 
# | 05-JUL-2016: BugFix: 
# |    In 11i SQL "compat = 11i" but in the 
# |    context file, it's 11.5.X.. 
# +---------------------------
sub getRelVer
{
  my $contextFile = $ENV{"CONTEXT_FILE"};
  my $relVer;
  open my $fh, '<', $contextFile or die "   ERROR: Could not open $contextFile: $!";
  while (<$fh>) 
    {
      $relVer = $1 if $_ =~ /s_apps_version\">(\d{2}.+)<\/config_option\>/;
      last if defined $relVer;
    }
  close $fh;

  #Validate Release Version 
  die "   ERROR: Unable to determine Release Version from Context File\n" if $relVer !~ /^11\.5|^12\.0|^12\.1|^12.2/;
  #11i bugFix: 
  $relVer = '11i' if $relVer =~ /^11/;
  return ($relVer);
}#END: getRelVer 


# +-------------------------------------------------------------------------+
# | sub:copySQL  
# +-------------------------------------------------------------------------+
# | Desc: Checks the EXECUTION_METHOD_CODE of the analyzer's 
# | LDT and if EXECUTION_METHOD_CODE = I, copy the file to PROD_TOP
# +-------------------------------------------------------------------------+
# | Args: the file to be cp'd
# +-------------------------------------------------------------------------+
# | Returns: 
# +-------------------------------------------------------------------------+
sub copySQL_noLongerUsed # 24-Jan-19 amlepe, no longer copying files to locations outside BUNDLE_TOP
{
  my $relVer = getRelVer();
  #get relVer .. 12.2 has special copy considerations 
  my ($file) = @_;
  
  #if we're running as part of AutoUpdate 
  if (length($main::bundleLoc) > 0) 
  {
    chdir($main::bundleLoc . "/MENU");
  }
  
  my $replace = versionCheckFiles($file);
  find( sub {return unless /$file/; $file = $File::Find::name;}, "analyzers/SQL" ) if (my $i = $file =~ tr/\///) == 0;
  my $analyzer = analyzer MENU::Analyzer($file);
  my $progTemplate = 'analyzers/template/' . $analyzer->getProgTemplate;
  open (my $fh, '<', $progTemplate ) || die "copySQL(): Cannot open $progTemplate $! \n";
  my @a=<$fh>;
  close $fh;
  my $prodTop;
  my $ans;
  
  if ($analyzer->getCPFile)
  {
    $file = $analyzer->getCPFile;
    find( sub {return unless basename($_) eq $file; $file = $File::Find::name;}, "analyzers/SQL" );
  }

  if (grep(/EXECUTION_METHOD_CODE\s\=\s\"Q\"/, @a) && $replace == 0)
  {
    $prodTop = $ENV{$analyzer->getProdTop} . '/sql/';
    $main::logr->wlSO("\nINFO: Copying file: $file to $prodTop ..\n");
    _copyFile($file, $prodTop);
  }
  elsif (grep(/EXECUTION_METHOD_CODE\s\=\s\"Q\"/, @a) && $replace == 2)
  {
    print "\n\n   WARNING: Unable to version check: ",basename($file)," \n";
    until ($ans =~ /^y|^n/i) 
    {
      print "  Copy the file without version checking? [Y|N]:";
      $ans = <STDIN>;
      chomp($ans);
      print "  Invalid answer. \n" if $ans !~ /^y|^n/i;
    }
    if ($ans =~ /^y/i)
    {
      $prodTop = $ENV{$analyzer->getProdTop} . '/sql/';
      if (-d $prodTop) 
      {
        $main::logr->wlSO("\nINFO: Copying file: $file to $prodTop ..\n");
        _copyFile($file, $prodTop);
      }
      else 
      {
        #12:23 PM 3/21/2018 added in case the dir does not exist 
        $main::logr->wlSO("\nINFO: _copyFile(): Target Product Top ($analyzer->getProdTop) dir \"$prodTop\" does not exist.");
      }
    }
    else
    {
      $main::logr->wlSO("   INFO: Did not copy $file to $prodTop \n");
    }
  }
  
  #in all releases, even 12.2, the above "copy"
  #got the file to the primary/current file system
  #But in 12.2, we need to do another copy 
  if ($relVer =~ /^12\.2/i && ($replace == 0 || $ans =~ /^y/i)) 
  {
    my $otherFS = getFSVars(); #/oracle/VISION/12.2/fs2 
    #append PROD_TOP/sql 
    my $prod = $analyzer->getProdTop;
    $prod =~ s/_TOP//;
    $prod = lc($prod);
    $prodTop = $otherFS . '/EBSapps/appl/' . $prod . '/12.0.0/sql/';
    _copyFile ($file, $prodTop);
  }
  
  sub _copyFile 
  {
    my ($src, $targ) = @_;
    
    if (copy($src, $targ))
    {
      print "INFO: File Copy Successful!\n   file: $targ \n";
    }
    else 
    {
      $main::logr->wlSO("  ERROR: Unable to copy $file to $prodTop: $!");
      return();
    }
  }#end _copyFile 

}#END: copySQL

# +---------------------------
# | sub getFSVars() 
# | gets both FS vars from the CONTEXT_FILE for 12.2 so
# | both file systems are updated when copying SQL to PROD_TOP/sql 
# +---------------------------
sub getFSVars
{
  my $contextFile = $ENV{"CONTEXT_FILE"};
  my $otherBase;
  open my $fh, '<', $contextFile or die "   ERROR: Could not open $contextFile: $!";
  while (<$fh>) 
  {
    $otherBase = $1 if $_ =~ /s_other_base\">(.+?)<\/OTHER_BASE\>/;
    last if defined $otherBase;
  }
  close $fh;

  #Validate Release Version 
  warn "   ERROR: Unable to determine secondary 12.2 File System from Context File (s_other_base)\n" if ! -d $otherBase;
  return ($otherBase);

}#END: getFSVars

# +-------------------------------------------------------------------------+
# | sub:  runFNDLOAD() 
# +-------------------------------------------------------------------------+
# | Desc: runs FNDLOAD for any files in the LDT/run dir 
# +-------------------------------------------------------------------------+
# | Args: nada 
# +-------------------------------------------------------------------------+
# | Returns: nada 
# +-------------------------------------------------------------------------+
sub runFNDLOAD
{
  # +=============================================================+ 
  # | afcpprog.lct is for loading the program
  # | afcpreqg.lct is for registering the program
  # | FNDLOAD %%SQL_USER%%/%%SQL_PASS%% O Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct <REQ_LDT>
  # | FNDLOAD %%SQL_USER%%/%%SQL_PASS%% O Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct <PROG_LDT>
  # +=============================================================+
  my $cs = $main::connStrg->getConnStrg();
  my $status;
  my $retStatus = 1; #1 = success, 0 = fail 
  my $mode = 'none';
  #if we're running as part of AutoUpdate 
  if (length($main::bundleLoc) > 0)
  {
    chdir($main::bundleLoc . "/MENU");
    $mode = 'cp';
  }

  my $runDir = 'analyzers/LDT/run';
  my @progList;
  #my @reqGrpList;
  #find( sub {return unless $_ =~ /_REQGRP.ldt/; push @reqGrpList, $File::Find::name;}, $runDir );
  find( sub {return unless $_ =~ /\.ldt/; push @progList, $File::Find::name if -f $_;}, $runDir );
  return if (scalar @progList) == 0; # we may not always have a reqgrp ldt, but should always have a proggrp ldt.

  print "INFO: Running FNDLOAD \n";

  #load the prog LDTs first
  while ((scalar @progList) > 0)
  {
    my $file = shift @progList;
    $main::logr->wl("\nINFO: running FNDLOAD: \"FNDLOAD ****\/**** O Y UPLOAD \$FND_TOP/patch/115/import/afcpprog.lct $file \"\n\n");
    $status=system("FNDLOAD $cs O Y UPLOAD \$FND_TOP/patch/115/import/afcpprog.lct $file CUSTOM_MODE=FORCE");
    #Check status 
    if ($status == 0)
    {
      $main::logr->wlSO ("\nINFO: FNDLOAD for $file successful \n\n")  if $mode eq 'none';
      $retStatus = 1; 
    }
    else
    {
      $main::logr->wlSO ("\n  ERROR: FNDLOAD failed for $file\n\n")  if $mode eq 'none';
      $retStatus = 0; 
    }
    my $filename = basename($file);
    #move $file, "analyzers/LDT/$filename";
    system("mv $file \"analyzers/LDT/$filename\"");
  }

  my $logLoc = "INFO: FNDLOAD logs are located in: " . cwd() . "/logs/*.req"; 
  
  print "$logLoc\n"; 
  
  $main::logr->wl($logLoc) if $mode eq 'none';
  
  if (length($main::bundleLoc) > 0) 
  {
    my $sourceDir = $main::bundleLoc . "/MENU/*.log";
    my $targetDir = $main::bundleLoc . "/MENU/logs/";
    my @logs = glob($sourceDir);
    foreach my $f (@logs) 
    {
      move($f, $targetDir);
    }
  }
  else 
  {
    my $s = system("ls *.log > /dev/null");
    system("mv *.log logs/") if $s == 0;
  }
  
  return($retStatus);
}#END: runFNDLOAD() 

###  
## createProgLDT: takes Release Version / Load.pl mode (single=script/family=<fam>/family=<all>)
## Determines which analyzers need to be processed, then creates the request group LDT for that list. 
## There are no customizations or off-standard changes needed or possible to the program group LDT
## There is no variable instantiation done, we simply match the top part of the template, which is release-specific to
## the bottom, generic part of the template which is generic. 
###

# +---------------------------
# |
# | createProgLDT($relVer, $mode, $analyzers);
# +---------------------------
sub createProgLDT
{
  my ($file, $CCPName, $progTemplate) = @_;
  my $relVer = getRelVer();
  #11/20/19 6:25 AM change for product installation check 
  my $analyzer; 
  if (length($file))
  { 
    $analyzer = analyzer MENU::Analyzer($file); 
  
    if (! isProdInstalled( $analyzer->getProdShortName()) )
      {
        my $prodName =  $analyzer->getProdShortName();
        $main::logr->wlSO("INFO: Not installing $file as the required product \"$prodName\" is currently not installed.");
        return 1;
      } 
  }
  
  
  #this retStatus is not really used right now, but adding it for future 
  # ER and need it for AutoUpdate. 
  my $retStatus = 1; #1 == success, 0 == failure 
  
  #9:09 AM 3/15/2018 
  #if we don't pass in CCPName, we are running for a normal SQL analyzer 
  # if we do pass in CCPName, we are running for AutoUpdate 
  if (length($CCPName) == 0) 
  {
    $progTemplate = $analyzer->getProgTemplate();
    $CCPName = $analyzer->getCCPName();
  }

  my @newFile;
  my @newFile1;
  my $topTemplate;
  
  #if we're running as part of AutoUpdate 
  if (length($main::bundleLoc) > 0) 
  {
    chdir($main::bundleLoc . "/MENU");
  }
  
  if (! -d "analyzers/LDT/run")
  {
    print "INFO: createProgLDT(): Creating \"run\" directory \n";
    mkdir('analyzers/LDT/run', 0755);
  }

  $CCPName.="\.ldt";
  #printf "REL VER: $relVer \n";
  $relVer =~ /^11/ ? $topTemplate = '11iProg.ldt' : 
  $relVer =~ /^12\.0.?/ ? $topTemplate = '120Prog.ldt' : 
  $relVer =~ /^12\.1.?/ ? $topTemplate = '121Prog.ldt' : 
  $relVer =~ /^12\.2.?/ ? $topTemplate = '122Prog.ldt' : die "   ERROR: createProgLDT(): Unable to determine release from context file. \n";
  #Copy top 1/2 (release-specific data definition) into an Array 
  open(my $FH1, "<", "analyzers/template/$topTemplate") || die "   ERROR [1]: createProgLDT(): Cannot open: analyzers/template/$topTemplate\": $!";
  @newFile=<$FH1>;
  close $FH1;
  #Copy bottom 1/2 (program data, analyzer-specific) into the same array 
  open(my $FH2, "<", "analyzers/template/$progTemplate") || die "   ERROR [2]: createProgLDT(): Cannot open: analyzers/template/$progTemplate\": $!";
  @newFile1=<$FH2>;
  close $FH2;
  
   my $time = (strftime "%Y-%m-%d_%H%M%S\n\n", localtime);
   $time=trim($time);
   #$time =~ s/\n//g;
   rename("analyzers/LDT/$CCPName", "analyzers/LDT/" . $CCPName . "\." . $time) if -e "analyzers/LDT/$CCPName";
  
  open(my $FH3, ">", "analyzers/LDT/run/$CCPName") || die "   ERROR [3]: createProgLDT(): Cannot open: analyzers/LDT/run/$CCPName\": $!";
    print $FH3 @newFile;
    print $FH3 @newFile1;
  close $FH3;
  
  #9:55 AM 3/15/2018 
  # we could do some extra error checking here, but essentially there 
  # are so may die's here, that if a file cannot be read / opened, 
  # the entire program is going to exit 
  
  return ($retStatus);
}#END: createProgLDT()

# +-------------------------------------------------------------------------+
# | sub: addToGroup
# +-------------------------------------------------------------------------+
# | Desc: adds a file's concurrent program to a request group 
# +-------------------------------------------------------------------------+
# | Args: analyzer file with a bundle header 
# +-------------------------------------------------------------------------+
# | Returns: int (status )
# +-------------------------------------------------------------------------+
sub addToGroup
{
  #From the EBS Dev Guide: 
  # program_short_ name   The short name used as the developer name of the concurrent program.
  # program_ application   The application that owns the concurrent program.
  # request_group   The request group to which to add the concurrent program.
  # group_ application   The application that owns the request group.  

  my ($file,$appName,$reqGroup,$mode, $ccpName, $prodShortName) = @_;
  my $cs = $main::connStrg->getConnStrg();
  my $analyzer; 
  
  if (length($main::bundleLoc) > 0) 
  {
    chdir($main::bundleLoc . "/MENU");
  }
  
  if (length($file) > 0) 
  {
    $analyzer = analyzer MENU::Analyzer($file);
    $ccpName = $analyzer->getCCPName();
    $prodShortName = $analyzer->getProdShortName();
  }

  #ccpname and prodShortName are constant no matter if defining a request 
  # group or using one from the SQL Header 
  #we use this if we only have a file passed in 
  #this equates to using all default params for request group & fndload
  if ($mode ne 'single')
  {
    $appName = $analyzer->getAppName();
    $reqGroup = $analyzer->getReqGroup();
  }

  if (length $appName < 1 || length $reqGroup < 1 || length $prodShortName < 1 || length $ccpName < 1) 
  {
    print "ERROR: addToGroup(): unable to get all parameters from $file. \n";
    print "ERROR: Unable to add request group entry for $file \n   Press [Enter] to Continue:";
    <STDIN>;
    return(1);
  }
  
  unlink('sql/add_to_group.sql') if -f 'sql/add_to_group.sql';
  my $spool = 'sql/add_to_group.lst' . (strftime "%Y-%m-%d_%H%M%S", localtime) . '.lst';
  my @sql = qq(
SPOOL $spool
SET DEFINE OFF;
SET SERVEROUTPUT ON;
BEGIN

fnd_program.add_to_group(program_short_name => '$ccpName', program_application => '$prodShortName', request_group => '$reqGroup', group_application => '$appName');

EXCEPTION
   WHEN DUP_VAL_ON_INDEX THEN
   dbms_output.put_line('\n   INFO: Program: $ccpName already included in Request Group: $reqGroup');
END;
/
SPOOL OFF;
exit);
    open (my $fh, '>', 'sql/add_to_group.sql' ) || die "addToGroup(): Cannot open sql/add_to_group.sql \n";
    print $fh @sql;
    close $fh;
  print qq(
  INFO: Adding Concurrent Program to Request Group:
    o Program: $ccpName
    o Concurrent Program Product: $prodShortName
    o Request Group: $reqGroup 
    o Request Group Application: $appName\n\n);
    
  my $status = system("sqlplus -s $cs \@sql/add_to_group.sql");
  
  print "INFO: addToGroup(): SQLPLUS exited with status: $status \n";
  #check for errors in the $spool file and only stop if there's an error 
  if (checkSQL("$spool") > 0)
  {
    print "ERROR: The addToGroup() failed to add $ccpName to $reqGroup \n   Check the sql/add_to_group spool file for details.\n";
  }
  
  # unlink('sql/add_to_group.sql') if -e 'sql/add_to_group.sql';
  return($status);
}#END: addToGroup

# +-------------------------------------------------------------------------+
# | sub: getReqGroups
# +-------------------------------------------------------------------------+
# | Desc: gets sorted request groups for 
# | given product short name $prodSN
# +-------------------------------------------------------------------------+
# | Args: PRODUCT_SHORT_NAME 
# +-------------------------------------------------------------------------+
# | Returns: hashref
# | 'APP_NAME' => 'Payroll',
# | 'REQ_GRP' => 'Global SLA/Payroll Processes',
# | 'PROD' => 'PAY',
# | 'REQ_GRP_CODE' => 'GLB_SLA_PAYROLL_PROCESS
# | 'COUNT' => '<count of responsibilities having the req. group>';
# +-------------------------------------------------------------------------+
sub getReqGroups
{
  my ($prodSN) = @_;
  my %reqGrps;
  my $cs = $main::connStrg->getConnStrg();
  #make sure there's no trailing spaces 
  $prodSN = trim($prodSN);
  $prodSN = uc($prodSN);
  print "INFO: Getting Request Groups for \'$prodSN\' ...\n";
  open (my $fh, '>', 'sql/getReqGrps.sql' ) || die "getReqGroups(): Cannot open \'sql/getReqGrps.sql\': $! \n";
  
  print $fh qq(
  SPOOL sql/getReqGrps.lst
  SET HEAD OFF 
  SET LINESIZE 1000 
  SET SERVEROUTPUT ON
  SET TERM OFF
  SET VERIFY OFF
  SELECT fa.application_short_name || '::' || frg.request_group_name || '::' || frg.request_group_code || '::' || fat.application_name || '::' || count(frv.RESPONSIBILITY_NAME)
  FROM fnd_application fa, fnd_request_groups frg, fnd_application_tl fat, FND_RESPONSIBILITY_VL frv
  WHERE frg.application_id = fa.application_id
  AND frv.REQUEST_GROUP_ID (+) = frg.REQUEST_GROUP_ID
  AND fat.application_id = frg.application_id
  AND fat.language = 'US'
  AND upper(fa.application_short_name) = '$prodSN'
  group by fa.application_short_name || '::' || frg.request_group_name || '::' || frg.request_group_code || '::' || fat.application_name
  order by fa.application_short_name || '::' || frg.request_group_name || '::' || frg.request_group_code || '::' || fat.application_name || '::' || count(frv.RESPONSIBILITY_NAME);
  SPOOL OFF;
  EXIT;);
  close $fh;
  
  my $status = system("sqlplus -s $cs \@sql/getReqGrps.sql");
  
  print "INFO: SQL*PLUS command for sql/getReqGrps.sql exited with status: $status \n";
  if (checkSQL('sql/getReqGrps.lst'))
  {
    print "INFO: Request Group Select failed. \n";
  }
  else
  {
    if (-f 'sql/getReqGrps.lst')
    {
      open (my $fh1, '<', 'sql/getReqGrps.lst' ) || die "Cannot open 'sql/req_groups.lst': $! \n";
      my $id = 0;
      while (my $line = <$fh1>) 
      {
        next unless $line =~ /^$prodSN/;
        $id++;
        chomp($line);
        #my ($prod, $grp, $rgCode, $appName, $count) = split(':', $line);
        ($reqGrps{$id}->{'PROD'}, $reqGrps{$id}->{'REQ_GRP'}, $reqGrps{$id}->{'REQ_GRP_CODE'}, $reqGrps{$id}->{'APP_NAME'}, $reqGrps{$id}->{'COUNT'}) = split('::', $line);
         $reqGrps{$id}->{'COUNT'}=trim($reqGrps{$id}->{'COUNT'});
        $reqGrps{$id}->{'SEL'}=' ';
        
        if ($reqGrps{$id}->{'COUNT'} eq '' || $reqGrps{$id}->{'COUNT'} eq ' ') 
        {
          $reqGrps{$id}->{'COUNT'} = 0;
        }
      }
      close $fh1;
    }
    # print Dumper(%reqGrps);
    # <STDIN>;
  }#end else 
  if (keys %reqGrps)
  {
    return(\%reqGrps);
  }
  else
  {
    print "\n\n   INFO: No Request Groups found. Is $prodSN a valid Product Short Name?\n";
    print "  Press [Enter] to Continue: "; <STDIN>;
    return(1);
  }
}#END: getReqGroups 

# +-------------------------------------------------------------------------+
# | sub: checkSQL
# +-------------------------------------------------------------------------+
# | Desc: checks if a spool file 
# | contains an ORA- error 
# +-------------------------------------------------------------------------+
# | Args: spool file  
# +-------------------------------------------------------------------------+
# | Returns: 0 (success) or 1 (failed) 
# +-------------------------------------------------------------------------+
sub checkSQL
{
  my ($spoolFile) = @_;
  open (my $fh, '<', $spoolFile ) || die "checkSQL(): Cannot open $spoolFile: $! \n";
  my @f = <$fh>;
  close $fh;
  
  if (grep(/ORA\-/, @f)) 
  {
    my @err = grep(/ORA\-/i, @f);
    print "\nINFO: SQL statment returned 1 or more ORA- errors: \n";
    print "  $_ \n" foreach(@err);
    print "\n  Check $spoolFile for the errors. \n   Press [Enter] to Continue:";
    <STDIN>;
    return(1);
  }
  else 
  {
    print "\nINFO: SQL statement completed. (No ORA- errors) \n";
    return(0);
  }
}#END: checkSQL() 

# +-------------------------------------------------------------------------+
# | sub: reqGrpPickList
# +-------------------------------------------------------------------------+
# | Desc: pick list to allow 
# | user to select a request group 
# | from a given product short name  
# +-------------------------------------------------------------------------+
# | Args: hash ref of request groups: 
# | 'APP_NAME' => 'Payroll',
# | 'REQ_GRP' => 'Global SLA/Payroll Processes',
# | 'PROD' => 'PAY',
# | 'REQ_GRP_CODE' => 'GLB_SLA_PAYROLL_PROCESS
# +-------------------------------------------------------------------------+
# | Returns: 
# +-------------------------------------------------------------------------+
sub reqGrpPickList
{
  my ($groups) = @_;
  my $height = `tput lines`;
  my $width = `tput cols`;
  my $pageSize = ($height - 8);
  my $currPage = 1;
  my $maxPage = (ceil(scalar(keys %$groups)/$pageSize));
  my $ID = 1;
  my $invSel = 0;
  my $userSel;
  my $newCount = 0;
  
  if (! keys %$groups)
  {
    print "INFO: No Request Groups Found \n";
    print "  Press [Enter] to Continue:";
    <STDIN>;
    return();
  }
  
  until (1 == 2) 
  {
    my ($spc1, $spc2, $verLgth);
    system("clear");
    print "\n";
    print BOLD WHITE ON_BLUE "  Select Request Group for: $$groups{1}->{'APP_NAME'} ($$groups{1}->{'PROD'})", RESET;
    print BOLD WHITE ON_GREEN " [Page $currPage of $maxPage]",RESET if $maxPage > 1;
    print "\n\n";
    print BOLD WHITE ON_BLUE "  #  SELECTED  REQUEST GROUP                            # of Responsibilities", RESET, "\n";
    $| = 1;
    for ($ID; $ID <= ($pageSize * $currPage); $ID++)
    {
      next if length($$groups{$ID}->{'PROD'}) < 2;
      #spacing considerations to right align text to terminal 
      my $spcCnt;
      my $spc;
      my $title = $$groups{$ID}->{'REQ_GRP'};
      if (length $title > 38) 
        { $title = substr($title, 0, 36); $title .= "..."; } 
      my $lengthTitle = ((length($title) + length("[$ID]")) + 24);
      if ($width > $lengthTitle) 
      { $spcCnt = -1 * ($lengthTitle - $width); }
      else 
      { $spcCnt = 1; }

      $spcCnt++ if $ID > 9;
      for (my $i=0;$i < $spcCnt; $i++)
      { $spc = $spc . ' '; } 
      
      $spc1 = "  " if $ID > 9;
      $spc1 = "   " if $ID <= 9;
      print " [$ID]", $spc1, "[$$groups{$ID}->{'SEL'}]","     $title",$spc,"$$groups{$ID}->{'COUNT'}\n";
    }
    
    print BOLD WHITE ON_BLUE "\n  [A]dd Selected Request Groups | [B]ack | [H]elp | E[x]it ", RESET;
    print BOLD WHITE ON_GREEN "| [N]ext Page", RESET if $currPage < $maxPage;
    print BOLD WHITE ON_GREEN " | [P]rev Page", RESET if $currPage < $maxPage && $currPage > 1;
    print BOLD WHITE ON_GREEN "| [P]rev Page", RESET if $currPage == $maxPage && $currPage > 1;
    print BOLD WHITE ON_YELLOW "| Invalid Selection", RESET if $invSel != 0;
    print "  \n  ...\n  Select by Entering a #, then [A]dd to continue\n";
    print "  Selection:";
    $invSel = 0;
    chomp($userSel = <STDIN>);
    $main::logr->exitLog() if $userSel =~ /^x{1}$/i;
    
    if (defined $$groups{$userSel}) 
    {
      if (length($$groups{$userSel}->{'REQ_GRP'}) < 2) 
      {
        $invSel = 1;
        $ID = ($ID - $pageSize);
        next;
      }

      if ($$groups{$userSel}->{'COUNT'} == 0)
      {
        print "\nINFO: This Request Group is not assigned to any Responsibilities. \n   Choose another Request Group or add it to a Responsibility first. \n   Press [Enter] to Continue:" ;
        <STDIN>;
        #deselect all 
        #for my $i (keys %$groups) {$$groups{$i}->{'SEL'} = ' ';} 
      }
        
      if ($$groups{$userSel}->{'COUNT'} > 0)
      {
        my $ans;
        until ($ans =~ /^y|^n/i)
        {
          #system("clear");
          print "\nINFO: Request Group: \"$$groups{$userSel}->{'REQ_GRP'}\"\n        is assigned to ",$$groups{$userSel}->{'COUNT'}," Responsibilities\n";
          print "\n  Would you like to see the list of Responsibilities? [Y|N]: ";
          chomp($ans=<STDIN>);
        }
        my $return = showResp($$groups{$userSel}->{'REQ_GRP'},$$groups{$userSel}->{'PROD'}) if $ans =~ /^y/i;
        return('main') if $return eq 'main';
            #deselect all 
        #for my $i (keys %$groups) {$$groups{$i}->{'SEL'} = ' ';} 
        if ($$groups{$userSel}->{'SEL'} !~ /\+/)
        {$$groups{$userSel}->{'SEL'} = '+';} 
        else
        {$$groups{$userSel}->{'SEL'} = ' ';} 
      }
      $ID = ($ID - $pageSize);
    }
    elsif ($userSel =~ /^n{1}/i) #next page 
    {
      if ($currPage == $maxPage) 
      {
        $invSel = 1;
        $ID = ($ID - $pageSize);
      }
      else
      {
        $ID = ($pageSize * $currPage + 1);
        $currPage++;
      }
    }
    elsif ( $userSel =~ /^p{1}/i) #previous page 
    {
      if ($currPage == 1) 
      {
        $invSel = 1;
        $ID = 0;
      }
      else 
      {
        $ID = ($ID - ($pageSize * 2));
        $currPage = ($currPage -1);
      } 
    }
    
    elsif ($userSel =~ /^b{1}$/i)
    {
      print "INFO: Selection of new Request Groups was aborted. \n";
      print "  (Select [U]se to add the selected Request Group.) \n";
      #user quit without finalizing selection 
      return(1);
    }
    elsif ($userSel =~ /^h{1}$/i)
    {
      system("clear");
      print BOLD WHITE ON_BLUE "  Request Group Pick List Help", RESET, "\n";
      print qq (
  This list shows all Request Groups for the product entered.  
   
  Select a Request Group which has at least 1 Responsibility assigned 
  by entering the corresponding number on the left. Then select [U]se
  to proceed to the confirmation screen. 

  Selecting [B]ack returns to the Load screen with no Request Group 
  selected. 
   
  If you wish to see the Responsibilities which have the Request Group
  assigned, select a number, then answer "y" when prompted to view the 
  Responsibilities. 

      \n   Press [Enter] to Continue:);
      <STDIN>;
      $ID = ($ID - $pageSize);
    }
    elsif ($userSel =~ /^a{1}$/i)
    {
      my %return;
      my $ID2 = getMaxHashID($groups);
      $ID2++;
      foreach my $ID (keys %$groups)
      {
        if ($$groups{$ID}->{'SEL'} =~ /\+/)
        {
          $ID2++;
          $return{$ID2}->{'SEL'} = $$groups{$ID}->{'SEL'};
          $return{$ID2}->{'REQ_GRP'} = $$groups{$ID}->{'REQ_GRP'};
          $return{$ID2}->{'PROD'} = $$groups{$ID}->{'PROD'};
          $return{$ID2}->{'APP_NAME'} = $$groups{$ID}->{'APP_NAME'};
          $return{$ID2}->{'REQ_GRP_CODE'} = $$groups{$ID}->{'REQ_GRP_CODE'};
        }
        #return($$groups{$ID}->{'REQ_GRP'}, $$groups{$ID}->{'PROD'}, $$groups{$ID}->{'APP_NAME'}, $$groups{$ID}->{'REQ_GRP_CODE'}) if $$groups{$ID}->{'SEL'} =~ /\+/;
      }
      
      if (keys %return)
      {
        return(\%return);
      }
      else 
      {
        print "INFO: No group selected. Press [Enter] to Continue:";
        <STDIN>;
        $ID = ($ID - $pageSize);
      }
    }
    else 
    {
      $invSel = 1;
      $ID = ($ID - $pageSize);
    }
  }
}#END: reqGrpPickList

# +-------------------------------------------------------------------------+
# | sub: showResp 
# +-------------------------------------------------------------------------+
# | Desc: Shows which responsibilities 
# | are associated with a particular 
# | request group / product 
# +-------------------------------------------------------------------------+
# | Args: request group / prod(*?) 
# +-------------------------------------------------------------------------+
# | Returns: <nada>
# +-------------------------------------------------------------------------+
sub showResp
{
  my ($reqGroup, $appShortName) = @_;
  my $height = `tput lines`;
  my $width = `tput cols`;
  my $pageSize = ($height - 7);
  my $currPage = 1;
  my $ID = 1;
  my $invSel = 0;
  my $userSel;
  my $newCount = 0;
  my $cs = $main::connStrg->getConnStrg();
  
  open (my $fh, '>', 'sql/getReqGrpResp.sql' ) || die "showResp(): Cannot open \'sql/getReqGrpResp.sql\': $! \n";
  print $fh qq(
SPOOL sql/getReqGrpResp.lst
SET DEFINE '~';
SET HEAD OFF 
SET SERVEROUTPUT ON
SET TERM OFF
SET VERIFY OFF
SET FEEDBACK OFF
SELECT wfr.display_name || '::' || COUNT(r.name)
FROM WF_USER_ROLE_ASSIGNMENTS_V wura, wf_local_roles r, wf_roles wfr, fnd_user f
WHERE r.name = f.user_name
AND r.user_flag = 'Y'
AND r.status = 'ACTIVE'
AND wura.user_name = r.name
AND wura.role_name = wfr.name
AND wura.role_name in (SELECT name FROM wf_roles WHERE display_name IN
         (SELECT frv.RESPONSIBILITY_NAME
                FROM fnd_request_groups frg, fnd_application fa, FND_RESPONSIBILITY_VL frv
                WHERE fa.application_id = frg.application_id
                AND frv.REQUEST_GROUP_ID = frg.REQUEST_GROUP_ID
                AND frg.request_group_name = '$reqGroup'
                AND fa.application_short_name = '$appShortName')
        )
AND ((wura.start_date < sysdate) AND ((wura.end_date is null) OR (wura.end_date
> sysdate)))
AND ((f.start_date < sysdate) AND ((f.end_date is null) OR (f.end_date > sysdate
)))
GROUP BY wfr.display_name;



SPOOL OFF
EXIT
/);
  close $fh;

  my $status = system("sqlplus -s $cs \@sql/getReqGrpResp.sql");
  
  print "INFO: SQL*PLUS command for sql/getReqGrpResp.sql exited with status: $status \n";
  if (checkSQL('sql/getReqGrpResp.lst'))
  {
    #this should probably never happen .. but.. 
    print "INFO: showResp(): No Responibilities Found for App Short Name: $appShortName Request Group: $reqGroup\n";
    print "  Press [Enter] to Continue:"; <STDIN>;
    return();
  }
  
  #convert spool file into %hash 
  my @resp;
  open (my $fh1, '<', "sql/getReqGrpResp.lst" ) || die "showResp(): Cannot open \"sql/getReqGrpResp.lst\":  $! \n";
  @resp = <$fh1>;
  close $fh1;

  my $maxPage = (ceil(scalar(@resp)/$pageSize));
  my $i;
  my $titleSpaceCnt = ($width-39);
  my $titleSpace;
  $titleSpace = $titleSpace . ' ' for (1..$titleSpaceCnt);
  
  until (1 == 2) 
  {
    my ($spc1, $spc2, $verLgth);
    system("clear");
    print "\n";
    print BOLD WHITE ON_BLUE "  Responsibilities for $appShortName: $reqGroup", RESET;
    print BOLD WHITE ON_GREEN " [Page $currPage of $maxPage]",RESET if $maxPage > 1;
    print "\n\n";
    print BOLD WHITE ON_BLUE "  Responsibility", $titleSpace,"# of Users Assigned", RESET;
    print "\n";
    $| = 1;
    if (scalar @resp > 0) 
    {
      for ($i; $i <= ($pageSize * $currPage); $i++)
      {
        next if length($resp[$i]) < 3;
        $resp[$i] = trim($resp[$i]);
        my ($r, $u) = split("::", $resp[$i]);
        my $spcCnt = ($width - (length($r) + length($u) + 4));
        my $spc;
        for (1..$spcCnt) 
        {
          $spc = $spc . ' ';
        }
        
        print "  $r", $spc,"$u\n";
        #print " ^ $length ^\n";
      }
      
      print BOLD WHITE ON_BLUE "\n  [B]ack | [M]ain Menu | [H]elp | E[x]it", RESET;
      print BOLD WHITE ON_GREEN "| [N]ext Page", RESET if $currPage < $maxPage;
      print BOLD WHITE ON_GREEN " | [P]rev Page", RESET if $currPage < $maxPage && $currPage > 1;
      print BOLD WHITE ON_GREEN "| [P]rev Page", RESET if $currPage == $maxPage && $currPage > 1;
      print BOLD WHITE ON_YELLOW " | Invalid Selection", RESET if $invSel != 0;
      print "\n  Selection:";
      $invSel = 0;
      chomp($userSel = <STDIN>);
      $main::logr->exitLog() if $userSel =~ /^x{1}$/i;
      if ( $userSel =~ /^h{1}/i)
      {
        system("clear");
  print BOLD WHITE ON_BLUE "  Request Group Responsibilities List Help", RESET;
        print qq (
  o This screen shows all Responsibilities which have the 
    Request Group : "Workflow Administrator" assigned to them. 
  o Loading an Analyzer into a Request Group gives these Responsibilities 
    (and "# of Users Assigned" to the given responsibility) access to run 
    and view the Analyzer output. 

  Press [Enter] to Continue:);
        <STDIN>;
        $i = ($i - $pageSize);
      }
      elsif ( $userSel =~ /^p{1}/i)
      {
        if ($currPage == 1) 
        {
          $invSel = 1;
          $i = 0;
        }
        else 
        {
          $i = ($i - ($pageSize * 2));
          $currPage = ($currPage -1);
        } 
      }
      elsif ( $userSel =~ /^n{1}/i)
      {
        if ($currPage == $maxPage) 
        {
          $invSel = 1;
          $i = ($i - $pageSize);
        }
        else
        {
          $i = ($pageSize * $currPage + 1);
          $currPage++;
        }
      }
      elsif ( $userSel =~ /^b{1}/i)
      {
        return();
      }
      elsif ( $userSel =~ /^m{1}/i)
      {
        return('main');
      }
      else
      {
        $i = ($i - $pageSize);
        $invSel = 1;
      }
    }#END if (scalar @resp > 0) 
    else
    {
      print "\n\nINFO: This Request Group is not assigned to any Responsibilities\n\n  Press [Enter] to Continue:";
      <STDIN>;
      return();
    }
  }
}#END: showResp

# +--------------------------------------------------------------------------+
# | sub: runDepen
# +--------------------------------------------------------------------------+
# | Desc:  
# +--------------------------------------------------------------------------+
# | Args: nebytiye
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub runDepen
{
  my ($file, $mode) = @_;
  my $cs = $main::connStrg->getConnStrg();
  #1 Run dependencies which, so far, never take params 
  my $analyzer = analyzer MENU::Analyzer($file);
  my ($depen) = $analyzer->getDeps();
  #if we're running as part of AutoUpdate 
  if (length($main::bundleLoc) > 0) 
  {
    chdir($main::bundleLoc . "/MENU");
  }
  
  $mode = 'none' if $mode ne 'cp';

  my $status = 0;
    
  if (scalar @$depen > 0) 
  {
    foreach my $depFile ( @$depen )
    {
      $depFile=trim($depFile);
      my $isPkg = checkObjectCreates($depFile);
      #if object_type == package, version check. 
      my $load;
      
      #10-Jan-20, if the dep file doesn't exist 
      #just return 1 without running anything. 
      #anything other than 0 returned is processed
      #as a failure by subs that call this 
      return 1 if ($isPkg eq 'FILE_NOT_FOUND'); 

      if (uc($isPkg) eq 'PACKAGE') 
      {
        #what if this comes back != 0? 
        $load = versCheckDBToFile($depFile);
      }
      else 
      {
        $load = 0;
      }
      
      if ($load == 2) 
      {
        #The dependency file could not be version checked in the 
        #DB 
        my $cont;
        until ( $cont =~ /^y|^n/i)
        {
          print qq( 
   ERROR: Unable to version check $depFile
   Continue to load this Analyzer Dependency?  
   
   INFO: By selecting 'N', the associated Concurrent Program 
    will not be loaded. 

   [Y|N]: );
        if ($mode eq 'none') 
        { 
          $cont = <STDIN>;
          chomp ($cont);
        }
        else 
        {
          $cont = 'y';
        }

        }
        if ($cont =~ /^y/i ) 
        {
          $load = 0;
        }
        elsif ($cont =~ /^n/i ) 
        {
          next;
          $status += 1;
        }
      }
      elsif ($load == 1)
      {
        #version in DB is already higher or equal so don't load it. 
        print "INFO: A equal or higher version of dependency file\, ", basename($file),"\, is already loaded.\n" ;
      }
      elsif ($load == 0)
      {
        my $runCmd = "sqlplus -s $cs \@" . $depFile;
        #$runCmd .= $depFile;
        $main::logr->wlSO("   INFO: About to run dependency..\n   Dependency: \"$depFile\"\n  Analyzer:$file\n\n") if $mode eq 'none';
        my $stat = system($runCmd);
        $main::logr->wlSO("   INFO: Dependency File exited with status: $stat \n") if $mode eq 'none';
        if ( $stat != 0 )
        {
          $main::logr->wlSO("   ERROR: Dependency file failed to run:\n    $depFile \n    The Concurrent Program for $file may not work as expected. \n\n") if $mode eq 'none';
          print "  Continue? [Y|N]: ";
          my $cont;
          if ($mode eq 'none') 
          { 
            $cont = <STDIN>;
            chomp ($cont);
          }
          else 
          {
            $cont = 'y';
          }

          if ( $cont =~ /^n/i ) 
          {
            $status += 1;
          }
         }
      }
    }
    print "INFO: Done with all dependencies. \n\n ";
  }
  else 
  {
    print "INFO: Analyzer: ", basename($file), " has no dependencies. \n";
  }
  
  return ($status);
}#END: runDepen


sub checkPrereq
{
  my ($file, $mode) = @_;
  my $analyzer = analyzer MENU::Analyzer($file);
  my $prer = $analyzer->getPrereq();
  #if we're running as part of AutoUpdate
  if (length($main::bundleLoc) > 0)
  {
    chdir($main::bundleLoc . "/MENU");
  }
  my $ret=0;

  $mode = 'none' if $mode ne 'cp';
  
  if ( $prer )
  {
    $ret = runPrereq($prer);
  }

  if ( $ret )
  {
    my $analyzerName = $analyzer->getTitle();
    my $failMessage = $analyzer->getFailMsg();
    if ( ! defined $failMessage || $failMessage eq "" )
    {
      $failMessage = "   ERROR: analyzer " . $analyzerName . ": pre-requisite NOT met.";
    }
    else 
    {
       $failMessage = "   ERROR: analyzer " . $analyzerName . ", prerequisite(s) not met:\n" . $failMessage;
    }
    $main::logr->wlSO($failMessage);
    if ($mode eq 'none')
    {
      print qq(   ENTER to continue ); <STDIN>;
    }
  }

  return $ret;
}

sub runPrereq
{
  my ( $sql ) = @_;
  my $ret=0;
  cls();
  unlink('sql/prereq.lst');
  unlink('sql/prereq.sql');

  open(my $fh, ">", 'sql/prereq.sql') || die "  ERROR: sub runPrereq():  Unable to open \"sql/prereq.sql\": $!\n";
  print $fh qq(
SET SERVEROUTPUT ON
SET TERM OFF
SET VERIFY OFF
SET HEAD OFF
SET LINESIZE 20

SPOOL sql/prereq.lst
$sql;
exit;
);
  close($fh);

  my $cs= $main::connStrg->getConnStrg();
  print " INFO: Running SQL*PLUS for analyzer prerequisite\n";
  my $sps = system("sqlplus -s $cs \@sql/prereq.sql");
  print " INFO: Done running SQL*PLUS for prerequisite [Exit Status: $sps]\n";
  open(my $fh1, "<", 'sql/prereq.lst') || warn " WARN: sub runPrereq(): Unable to open spool \"sql/prereq.lst\": $! \n";
  my @arr = <$fh1>;
  close $fh1;
  
  foreach my $ln (@arr)
  {
    $ln =~ s/\s//g;
    next unless length($ln);

    if ( $ln =~ /norowsselected/i || $ln =~ /ORA-/ || $ln =~ /ERROR/ )
    {
      $ret=1;
      last;
    }
  }

  return $ret;
}

# +--------------------------------------------------------------------------+
# | sub: checkMOSCreds
# +--------------------------------------------------------------------------+
# | Desc:  
# +--------------------------------------------------------------------------+
# | Args: nebytiye
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub checkMOSCreds 
{
  my ($user) = @_; 
  cls(); 
  print qq( INFO: Checking MOS Credentials setup in Oracle Applications Manager 
  for user: $user .. \n);
  if(_validateMOSCreds(uc($user)))
  {
    print qq( INFO: Successfully validated MOS Credentials for \"$user\" \n); 
    return(1); 
  }
  else 
  {
    cls(); 
    print BOLD WHITE ON_YELLOW "\n  ATTN: Could not validate MOS Credentials for \"$user\"", RESET; 
    print qq(
  INFO: \"$user\" does not have MOS Credentials configured in
        Oracle Applications Manager
  
  The concurrent programs and files for AutoUpdate are installed. However, 
  PSD_DOWNLOAD_BUNDLE cannot download the latest bundle.zip 
  without MOS Credentials setup in Oracle Applications Manager.
    
  There are 3 options:
   1\) Login to EBS, setup OAM Credentials as \"$user\"  then manually 
       schedule PSD_DOWNLOAD_BUNDLE as a concurrent request 
       [See DocID 2377353.1 for more info]
  
   2\) Setup MOS Credentials for "$user" and try this setup again
       [See DocID 2377353.1 for more info]
   
   3\) Try another EBS user that has MOS Credentials setup
       [You will be prompted on the next screen]
       
  Press [Enter] to continue: );
  <STDIN>; 
    
    my $ans; 
    until ($ans =~ /^y{1}|^n{1}/i) 
    {
      cls(); 
      print BOLD WHITE ON_BLUE "  Try another EBS User?", RESET, "\n"; 
      print "  [y|n]: "; 
      chomp($ans = <STDIN>); 
    }
    if ($ans =~ /^y/) 
    {
      return(0); 
    }
    else 
    {
      return("abort"); 
    }
  }
  
  sub _validateMOSCreds 
  {
      cls(); 
      my ($user) = @_; 
      print " Checking \"$user\" for MOS Credentials...\n";

      unlink('sql/validateMOSCreds.lst');
      unlink('sql/validateMOSCreds.sql');

      open(my $fh, ">", 'sql/validateMOSCreds.sql') || die "  ERROR: sub _validateMOSCreds(): Unable to open \"sql/validateMOSCreds.sql\": $! \n"; 
      print $fh qq(
SET SERVEROUTPUT ON
SET TERM OFF 
SET VERIFY OFF
SET HEAD OFF
SET LINESIZE 20

SPOOL sql/validateMOSCreds.lst

SELECT COUNT(*)
FROM fnd_oam_metalink_cred fomc, fnd_user fu
WHERE fu.user_Id = fomc.User_Id
AND upper(fu.user_name) = '$user';
exit; 
   ); 

    my $cs = $main::connStrg->getConnStrg();
    print " INFO: Running SQL*PLUS\n"; 
    my $sps = system("sqlplus -s $cs \@sql/validateMOSCreds.sql");
    print " INFO: Done running SQL*PLUS [Exit Status: $sps]\n"; 

    open(my $fh1, "<", 'sql/validateMOSCreds.lst') || warn " WARN: sub _validateMOSCreds(): Unable to open spool \"sql/validateMOSCreds.lst\": $! \n"; 
    my @arr = <$fh1>;
    close $fh1; 
    
    foreach my $ln (@arr) 
    {
      $ln =~ s/\s//g;
      next unless length($ln); 
      return 1 if $ln > 0; 
      return 0 if $ln == 0;
    }
  }#END private _validateUser; 

}#END: checkMOSCreds


# +--------------------------------------------------------------------------+
# | sub: getFNDUser
# +--------------------------------------------------------------------------+
# | Desc:  
# +--------------------------------------------------------------------------+
# | Args: nebytiye
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub getFNDUser 
{
   my $fndUser = '';
   my $validUser = 0;
   my $i = 0; 
   until ($validUser)
   {
      cls();
      if ($i > 0) 
      {
        print BOLD WHITE ON_YELLOW "\n ATTN: User \"$fndUser\" is not a valid user \n       or does not have the System Administrator Responsibility!", RESET, "\n"; 
      }
      print BOLD WHITE ON_BLUE "\n Enter an Applications User for CONCSUB", RESET, "\n"; 
   
      print qq( 
 Enter an EBS user name to schedule the Bundle AutoUpdate
 Concurrent Program (PSD_DOWNLOAD_BUNDLE) 
 
 The user must have the "System Administrator" Responsibility \(ex: SYSADMIN\)\n\n);
      
      print BOLD WHITE ON_BLUE " [H]elp | E[x]it ", RESET, "\n"; 
      print " Enter EBS User:"; 
      chomp($fndUser = <STDIN>);
      if ($fndUser =~ /^H{1}/i)
      {
         _printFndUserHelp();
         next;
      }
      elsif($fndUser =~ /^x{1}/i)
      {
        exit;
      }
      else
      {
        $validUser = _validateUser(uc($fndUser));
        if ($validUser) 
        {
          return ($fndUser);
        }
        $i++;
      }
   }#end until 
   
  sub _printFndUserHelp 
  {
    cls(); 
    print BOLD WHITE ON_BLUE " CONCSUB EBS User Help", RESET, "\n"; 
    print qq(
  The E-Business Suite Application user entered here will be used 
  by this program as a parameter passed to \$FND_TOP/bin/CONCSUB 
  
  CONCSUB is an API used to submit and schedule the Bundle AutoUpdate 
  concurrent program PSD_DOWNLOAD_BUNDLE
  
  INFO: PSD_DOWNLOAD_BUNDLE calls PSD_APPLY_NEW_BUNDLE 
        Do not schedule PSD_APPLY_NEW_BUNDLE
  
  User account information is not stored or reused by $0\
  
  See DocID 2377353.1 for more information 
  
  Press [Enter] to Continue: ); 
  <STDIN>; 
  return(0);
  }
   
   
   
  sub _validateUser 
  {
      cls(); 
      my ($user) = @_; 
      print " Checking \"$user\" for System Administrator Responsibility...\n";

      unlink('sql/validateUser.lst');
      unlink('sql/validateUser.sql');

      open(my $fh, ">", 'sql/validateUser.sql') || die "  ERROR: sub _validateUser(): Unable to open \"sql/validateUser.sql\": $! \n"; 
      print $fh qq(
SET SERVEROUTPUT ON
SET TERM OFF 
SET VERIFY OFF
SET HEAD OFF
SET LINESIZE 20

SPOOL sql/validateUser.lst

SELECT  count(*)
FROM FND_USER_RESP_GROUPS furg, FND_USER fu, FND_RESPONSIBILITY_TL frt
WHERE furg.USER_ID = fu.USER_ID
   AND furg.RESPONSIBILITY_ID = frt.RESPONSIBILITY_ID
   AND frt.RESPONSIBILITY_NAME = 'System Administrator'
   AND upper(fu.USER_NAME) = '$user'; 
exit; 
   ); 

    my $cs = $main::connStrg->getConnStrg();
    print " INFO: Running SQL*PLUS\n"; 
    my $sps = system("sqlplus -s $cs \@sql/validateUser.sql");
    print " INFO: Done running SQL*PLUS [Exit Status: $sps]\n"; 

    open(my $fh1, "<", 'sql/validateUser.lst') || warn " WARN: sub _validateUser(): Unable to open spool \"sql/validateUser.lst\": $! \n"; 
    my @arr = <$fh1>;
    close $fh1; 
    
    foreach my $ln (@arr) 
    {
      $ln =~ s/\s//g;
      next unless length($ln); 
      return 1 if $ln > 0; 
      return 0 if $ln == 0;
    }
  }#END private _validateUser; 

}#END: getFNDUser



# +--------------------------------------------------------------------------+
# | sub: concsubPickList
# +--------------------------------------------------------------------------+
# | Desc: Get the product list to install 
# +--------------------------------------------------------------------------+
# | Args: nebytiye
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub concsubPickList 
{
  my %prods;
  $prods{1}{DESC} = 'Core (ATG)';
  $prods{1}{PROD} = 'atg'; 
  $prods{2}{DESC} = 'Financials';
  $prods{2}{PROD} = 'fin'; 
  $prods{3}{DESC} = 'Inventory';
  $prods{3}{PROD} = 'inv';
  $prods{4}{DESC} = 'Order Management';
  $prods{4}{PROD} = 'om';
  $prods{5}{DESC} = 'Procurement';
  $prods{5}{PROD} = 'po';
  $prods{6}{DESC} = 'Supply Chain Management';
  $prods{6}{PROD} = 'scm';
  $prods{7}{DESC} = 'Human Capital Management';
  $prods{7}{PROD} = 'hcm';
  $prods{8}{DESC} = 'Customer Relationship Management';
  $prods{8}{PROD} = 'crm';
  
  foreach my $id (keys %prods)
  {
    $prods{$id}{SEL}='+';
  }
  
  my $userSel = '';
  cls(); 
  my $i = 0; 
  until(1==2)
  {
    cls();
    print BOLD WHITE ON_BLUE "\n Product Family Selection  [Toggle Analyzer Families By Number]", RESET, "\n" if $i == 0;
    print BOLD WHITE ON_BLUE "\n SEL [#] Description", RESET, "\n" if $i == 0;
    foreach my $id (sort{$a <=> $b} keys %prods) 
    {
      print " [$prods{$id}{SEL}] [$id] $prods{$id}{DESC}\n";
    }
    print BOLD WHITE ON_BLUE "\n Toggle [A]ll | [C]ontinue | [H]elp", RESET;
    print BOLD WHITE ON_YELLOW " Invalid Selection!", RESET if $userSel eq 'invalid'; 
    print "\n SELECTION:", RESET;
    chomp($userSel = <STDIN>);
    
    if (defined $prods{$userSel})
    {
      if ($prods{$userSel}{SEL} eq '+') 
      {
        $prods{$userSel}{SEL} = ' '; 
      }
      else 
      {
        $prods{$userSel}{SEL} = '+';
      }
    }
    elsif ($userSel =~ /^c{1}/i)
    {
      my $ans = _confirmSel();
      if ($ans eq 'y') 
      {
        my $ret;
        foreach my $id (keys %prods) 
        {
          next unless $prods{$id}{SEL} eq '+';
          if (! defined $ret)
          {
            $ret = $prods{$id}{PROD};
          }
          else 
          {
            $ret = $ret . ',' . $prods{$id}{PROD};
          }
        }
        $ret =~ s/,$//;
        return($ret);
      }
    }
    elsif ($userSel =~ /^h{1}/i)
    {
      _printHelp();
    }
    elsif ($userSel =~ /^a{1}/i)
    {
      if ($prods{1}{SEL} eq ' ')
      {
        foreach my $id (keys %prods)
        {
          $prods{$id}{SEL}='+';
        }
      }
      else 
      {
        foreach my $id (keys %prods)
        {
          $prods{$id}{SEL}=' ';
        }
      }
    }
    else
    {
      $userSel = 'invalid'; 
    }
  }#end util loop 
  
  ###
  #private subs 
  #############
  sub _confirmSel 
  {
    cls();
    #make sure something is selected
    
    if (! grep { $prods{$_}{SEL} eq '+' } keys %prods) 
    {
      print BOLD WHITE ON_BLUE "\n  No Families Selected", RESET, "\n"; 
      print "  INFO: Please make at least 1 Product Family Selection!\n\n  Press [Enter]:";
      <STDIN>;
      return('n');
    }
    
    print BOLD WHITE ON_BLUE "\n  Confirm Selections", RESET, "\n"; 
    print qq(  You have selected the following Analyzer Families to be installed
  each month by AutoUpdate:\n);
      
    print " ______________________________________________________________________________\n"; 
    foreach my $id (sort{$a <=> $b} keys %prods)
    {
      if ($prods{$id}{SEL} eq '+')
      {
        print "   -$prods{$id}{DESC}\n"; 
      }
    }
    print " ______________________________________________________________________________\n"; 
    
    my $ans = ''; 
    until ( $ans =~ /^y|^n/i ) 
    {
      print qq( Is this correct? [y|n]: ); 
      chomp($ans = <STDIN>); 
    }
    
    return('y') if $ans =~ /^y/i; 
    return('n') if $ans =~ /^n/i; 

  }
  
  sub _printHelp 
  {
    cls(); 
    print BOLD WHITE ON_BLUE " Product Family Selection Help", RESET, "\n"; 
    print qq(
  Toggle a product family selection by entering the corresponding number. 
  Multiple families can be selected at once.
  
  Entering "1", for example, will install *all* of the ATG "Core" Analyzers each time 
  a new bundle is downloaded around the 1st of the month. 
    
  o Doc ID 2377353.1 for information on the AutoUpdate Concurrent Program
  o Doc ID 1939637.1 for the latest Analyzer Bundle information 
  o Doc ID 1545562.1 for details about which analyzers are included
  in which product families. 
  
  Press [Enter] to continue: );
  <STDIN>; 
    
  }#END: _printHelp 
  
}#END: concsubPickList

# +--------------------------------------------------------------------------+
# | sub: runCONCSUB
# +--------------------------------------------------------------------------+
# | Desc: schedules PSD_BUNDLE_DOWNLOAD for 2nd of next mon 
# +--------------------------------------------------------------------------+
# | Args: Familes to install: (atg, hcm, crm, fin, etc..) 
# |         location of bundle 
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+  
sub runCONCSUB
{
  my ($argFam, $argLoc, $user) = @_;
  my $cs = $main::connStrg->getConnStrg();
  my $cmd = '';
  
  #check if the needed CCP Is installed: 
  my $instStatus = checkAutoUpdateInstallStatus();
  
  #make sure the PSD% CP's are installed 
  if ($instStatus eq 'Not Installed')
  {
    print qq(\n  ERROR: Concurrent program "PSD_DOWNLOAD_BUNDLE" is not installed  
  therefore, CONCSUB cannot run to schedule the concurrent program. 
  Action: Check MENU/logs/L*.log for FNDLOAD errors related to 
  "PSD_DOWNLOAD_BUNDLE"
  
  Press [Enter]: );
  <STDIN>;
    return(0);
  }

  #check if PSD_DOWNLOAD_BUNDLE is already scheduled: 
  my $stat = -1;
  #check if the program is already scheduled
  if (! _checkSched('pre')) 
  {
    $cmd = _buildCmd($argLoc, $argFam, $user, $cs);
  }
  else
  {
    cls();
    _showSched('pre');
    print qq( Press [Enter]:); 
    <STDIN>; 
    cls(); 
    my $ans = ''; 
    until ($ans =~ /^y{1}|^n{1}/i) 
    {
      print BOLD WHITE ON_YELLOW " ATTN: The AutoUpdate Concurrent Program is already scheduled to run\n";
      print qq(  Do you wish to schedule another instance of AutoUpdate? (Not Recommended) 

  Schedule Another Request[y|n]?: );

      chomp($ans = <STDIN>); 
    }
    if ($ans =~ /^y/i) 
    {
      $cmd = _buildCmd($argLoc, $argFam, $user, $cs); 
    }
    else 
    {
      return();
    }
  }
  
  print "INFO: Running CONCSUB to schedule the concurrent program \"PSD_DOWNLOAD_BUNDLE\" "; 

  $stat = system($cmd);

  print "INFO: Done with CONCSUB. [Exit Status: $stat]\n";
  
  if ($stat > 0) 
  {
    cls(); 
    print qq(  ERROR: CONCSUB Failed. Command:
  ______________________________________________________________________________
  $cmd
  ______________________________________________________________________________
  Action: Check the above error messages from CONCSUB
  
  Press [Enter] to Continue: ); 
  return(0); 
  }
  else 
  {
    if(_checkSched())
    {
      _showSched('x');
    }
    else
    {
      cls(); 
      print qq(ERROR: failed to schedule the PSD_DOWNLOAD_BUNDLE concurrent program. 
ACTION: Try running the following command manually: 

$cmd 

If the problem persists contact: 
 -Kyle.Harris\@Oracle.com 
 -William.Burbage\@Oracle.com
    
  Press [Enter] to continue:); 
    <STDIN>; 
    }
    return(1); 
  }

############
#private subs 
#################

  sub _buildCmd 
  {
    my ($argLoc, $argFam, $user, $cs) = @_;
    my $cmd = ''; 
    my $mon = (strftime "%m", localtime);
    my $year = (strftime "%y", localtime);
    ($mon, $year) = _getDate($mon, $year);
    my $date = "02-$mon-$year 00:00:00";
    
    #Set this to test the CP running right away: 
    # $date = "19-APR-2018 16:40:00";
    
    $cmd = qq(CONCSUB $cs SYSADMIN \"System Administrator\" $user CONCURRENT FND PSD_DOWNLOAD_BUNDLE PROGRAM_NAME=PSD_DOWNLOAD_BUNDLE REPEAT_INTERVAL=1 REPEAT_INTERVAL_UNIT=\"MONTHS\" START=\'\"$date\"\' "$argLoc" \'\"$argFam\"\' );
  
    return($cmd); 
  }#END: _buildCmd


  sub _showSched 
  {
    my ($mode) = @_; 
    #for cloudInstall.pl 
    if (! -d "sql") 
    {
      chdir("../../"); 
    }

    print BOLD WHITE ON_YELLOW "\n ATTN: PSD_DOWNLOAD_BUNDLE was *previously* scheduled to run", RESET, "\n" if $mode eq 'pre';
    print BOLD WHITE ON_BLUE "\n INFO: PSD_DOWNLOAD_BUNDLE is scheduled to run", RESET, "\n" if $mode ne 'pre';
    
    open(my $fh, "<", 'sql/checkSched.lst') || warn "  ERROR: runCONCSUB(): Unable to open \"sql/checkSched.lst\": $! \n"; 
    print " ______________________________________________________________________________\n"; 
    while (my $ln = <$fh>)
    {
      $ln =~ s/\s+/ /;
      next if $ln =~ /COUNT|^\s+/;
      if ($ln =~ /Arguments/) #args line might be long 
      {
        if (length($ln) > 69) 
        {
          my $ln2 = $ln;
          $ln = <$fh>;
          $ln2 = $ln2 . $ln;
          $ln2 =~ s/\s//g; 
          print "  $ln2";
        }
        else
        {
          print "  $ln";
        }
        print "\n_____________________________________________________________________________\n\n";
      }
      else 
      {
        print "  $ln";
      }
    }
    close $fh;
     
  }
  
  #confirm the program is scheduled 
  sub _checkSched 
  {
    #mode eq "pre" checks to see if it's already scheduled before doing it again. 
    my ($mode) = @_; 
  
    #for cloudInstall.pl 
    if (! -d "sql") 
    {
      chdir("../../"); 
    }
  
    unlink('sql/checkSched.sql'); 
    unlink('sql/checkSched.lst'); 
    open(my $fh, ">", 'sql/checkSched.sql') || die "  ERROR: sub _checkSched(): Unable to open \"sql/checkSched.sql\": $! \n"; 
    print $fh qq(
SET SERVEROUTPUT ON
SET TERM OFF 
SET VERIFY OFF
SET HEAD OFF
SET LINESIZE 70;

SPOOL sql/checkSched.lst 
SELECT 'COUNT-' || COUNT(*) 
FROM apps.fnd_concurrent_programs_tl fcpt,
apps.fnd_concurrent_requests fcr,
apps.fnd_user fu,
apps.fnd_conc_release_classes fcrc
WHERE fcpt.application_id = fcr.program_application_id
AND fcpt.concurrent_program_id = fcr.concurrent_program_id
AND fcr.requested_by = fu.user_id
AND fcr.phase_code = 'P'
AND fcr.requested_start_date > SYSDATE
AND fcpt.LANGUAGE = 'US'
AND fcrc.release_class_id(+) = fcr.release_class_id
AND fcrc.application_id(+) = fcr.release_class_app_id
AND fcpt.USER_CONCURRENT_PROGRAM_NAME LIKE 'PSD%BUNDLE%';

SELECT 'Request ID: ' || fcr.request_id ||  chr(10)  || 'Concurrent Program Name: ' ||
DECODE(fcpt.user_concurrent_program_name,
'Report Set',
'Report Set:' || fcr.description, 
fcpt.user_concurrent_program_name) || chr(10) ||  'FND User: ' || fu.user_name || chr(10) || 'Requested Start [DD-MON-YYYY HH:MM:SS]: ' || to_char(requested_start_date, 'DD-MON-YYYY HH24:MI:SS') || chr(10) || 'Arguments:' || fcr.argument_text || chr(10)
FROM apps.fnd_concurrent_programs_tl fcpt,
apps.fnd_concurrent_requests fcr,
apps.fnd_user fu,
apps.fnd_conc_release_classes fcrc
WHERE fcpt.application_id = fcr.program_application_id
AND fcpt.concurrent_program_id = fcr.concurrent_program_id 
AND fcpt.concurrent_program_id = fcr.concurrent_program_id
AND fcr.requested_by = fu.user_id
AND fcr.phase_code = 'P'
AND fcr.requested_start_date > SYSDATE
AND fcpt.LANGUAGE = 'US'
AND fcrc.release_class_id(+) = fcr.release_class_id
AND fcrc.application_id(+) = fcr.release_class_app_id
AND fcpt.USER_CONCURRENT_PROGRAM_NAME LIKE 'PSD%BUNDLE%';
exit; 
);
    close $fh;
    
    print "INFO: Running SQL*PLUS\n"; 
    my $sps = system("sqlplus -s $cs \@sql/checkSched\.sql");
    print "INFO: Done running SQL*PLUS [Exit Status: $sps]\n"; 
    
    open(my $fh1, "<", 'sql/checkSched.lst') || warn "  WARN: sub _checkSched(): Unable to open spool \"sql/checkSched.lst\": $! \n"; 
    my @arr = <$fh1>;
    close $fh1; 
    
    #run in pre mode to see if the cp is already scheduled: 
    if ($mode eq 'pre')
    {
      my (@count) = grep(/^COUNT-(\d)/, @arr);
      my $cnt = 0; 
      $cnt = $+ if $count[0] =~ /^COUNT-(\d)/;
      return(1) if $cnt > 0;
      return(0); 
    }
   
    my $ln; 
    my $i = 0; 
    foreach my $ln (@arr)
    {
      $ln =~ s/^\s+?|\s+?$//g; 
      next unless $ln =~ /:/;
      $i++ if $ln =~ /PSD_DOWNLOAD_BUNDLE/;
      return(1) if $i > 0; 
    }
    if ($i == 0)
    {
      print "  ERROR: CONCSUB could not schedule the concurrent program.\n";
    }
  }#END: _checkSched
  
  sub _getDate
  {
    my ($mon, $yr) = @_;
    my %dates = (
      1 =>   'JAN',
      2 =>   'FEB',
      3 =>   'MAR',
      4 =>   'APR',
      5 =>   'MAY',
      6 =>   'JUN',
      7 =>   'JUL',
      8 =>   'AUG',
      9 =>   'SEP',
      10 => 'OCT',
      11 => 'NOV',
      12 => 'DEC'
    );
    
    my $newMon = $mon + 1;
    $newMon = 1 if $newMon == 13;
    $yr++ if $newMon == 1; 
    return($dates{$newMon}, $yr);
  }#END: _getDate 
  
}#END: runCONCSUB 

# +-------------------------------------------------------------------------+
# | sub:  isProdInstalled
# +-------------------------------------------------------------------------+
# | Desc: instantiates $main::instProds; 
# +-------------------------------------------------------------------------+
# | Args: 
# +-------------------------------------------------------------------------+
# | Returns: 1 = true, 0 = false 
# +-------------------------------------------------------------------------+
# | Notes: 
# | 11/18/19 11:56 AM8:45 AM 7/1/2019: 
# | 
# +-------------------------------------------------------------------------+
sub isProdInstalled
{
    my ($prod) = @_; 
    
    if ((scalar @main::instProds) == 0)
    {  getInstProds(); }

    if (my ($matched) = grep $_ eq $prod, @main::instProds) 
    {return 1;}
    else 
    {return 0;} 
}


# +-------------------------------------------------------------------------+
# | sub:  getInstProds
# +-------------------------------------------------------------------------+
# | Desc: instantiates $main::instProds; 
# +-------------------------------------------------------------------------+
# | Args: 
# +-------------------------------------------------------------------------+
# | Returns: 
# +-------------------------------------------------------------------------+
# | Notes: 
# | 11/18/19 11:56 AM8:45 AM 7/1/2019: 
# | 
# +-------------------------------------------------------------------------+
sub getInstProds
{
print "INFO: getInstProds() running... \n"; 
    
my $cs = $main::connStrg->getConnStrg();

unlink('sql/checkProds.lst'); 
unlink('sql/checkProds.sql'); 
open(my $fh, ">", 'sql/checkProds.sql') || die "  ERROR: sub getInstProds(): Unable to open \"sql/checkProds.sql\": $! \n"; 
print $fh qq(
SET SERVEROUTPUT ON
SET TERM OFF 
SET VERIFY OFF
SET HEAD OFF
SET LINESIZE 70;

SPOOL sql/checkProds.lst 
SELECT distinct a.application_short_name
FROM fnd_application a, fnd_product_installations i
WHERE a.application_id = i.application_id
AND i.status in ('S','I');
exit; 
);
close $fh;

print "INFO: Running SQL*PLUS\n"; 
my $sps = system("sqlplus -s $cs \@sql/checkProds\.sql");
print "INFO: Done running SQL*PLUS [Exit Status: $sps]\n"; 

open(my $fh1, "<", 'sql/checkProds.lst') || warn "  WARN: sub getInstProds(): Unable to open spool \"sql/checkProds.lst\": $! \n"; 
@main::instProds = <$fh1>;
close $fh1; 

unlink('sql/checkProds.lst'); 
unlink('sql/checkProds.sql'); 

foreach my $e (@main::instProds)
{
    $e = trim($e);
}

print "INFO: getInstProds() done\n\n"; 
 
}





return 1;

__END__
# +===========================================================================+
# | History 
# +===========================================================================+
# | 200.0 Creation (OCT-16-2014) 
# | 200.1 
# | ->Print out CCP information when calling fnd_program.add_to_group 
# | 200.2 
# | --> Removed the '/' from selects / SQL files, causing them to run twice. 
# | 200.3
# | --> Added "CUSTOM_MODE=FORCE" parameter to the FNDLOAD command when updating
# |     an Analyzer so changes are forced but keeps associated Req Groups.
# | 200.4
# | --> Added "ORDER BY" to sort Request Groups listed when adding to Analyzers.
# | 200.5 
# | --> 11i version bugFix in checkCompat(). 
# |     Context File 11i is formated like "11.5.x.." but 
# |     our checkCompat sub was checking for a string of "11i" 
# | 200.6 
# | --> 11i bug fix into createProgLDT where regEx was looking for "11.5" 
# |     but needs to look for "11i" 
# | 200.7 
# | --> Fixed floadBulk() where all analyzers passed in were being 
# |     loaded. (SR 3-13002745461) 
# | 200.9 
# | --> Added some enhanced error reporting if the 
# |     file cannot be copied in copySQL sub 
# | 200.10 
# | --> Updated all /dev/null redirects to "command > /dev/null" 
# |     This works universally on ksh/bash 
# | 200.11 
# | --> Updated SET LINESIZE 1000 in getReqGroups() 
# |      to prevent line wrapping, which ends up in a "0" for request groups 
# |      assigned (SR 3-15796146401) 
# | 200.12 
# | --> Updated for AutoUpdate CCP, added "sub floadBulkAutoUpdate" 
# | 200.13 
# | --> Updated chdir() into subs that need to run during AutoUpdate
# |       to allow those subs to run with relative dir 
# |       added floadAutoUpdateLDTs()
# |       Updated createProgLDT() to work with the LDTs for AutoUpdate 
# |       Added runCONCSUB() sub to schedule PSD_BUNDLE_DOWNLOAD 
# | 200.14 
# | --> Using Logger.pm for logging
# | 200.15 
# | --> Updates for Hybrid 
# | 200.16 
# | --> Added product installation check prior to running FNDLOAD 
# | 200.17 
# | --> Fixed hard-coded apps creds left after testing new getInstProds() sub 
# | 200.18 
# | --> Fixed issue caused by missing dependencies (file not found was causing a
# |     full bulk load failure) 
# | 200.19
# | --> Modified message when module is not installed.
# | 200.20
# | --> Merged with code to handle installation on OCI environment ("batch" mode)
# | 200.21
# | --> Added sub checkPrereq() to check analyzers prerequisites before loading.
# | 200.22
# | --> Remove calls to copySQL(), not leaving any files outside BUNDLE_TOP.
# |  +===========================================================================+
