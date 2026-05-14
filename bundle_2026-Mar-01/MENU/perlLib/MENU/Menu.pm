# $Id: Menu.pm 200.14 07/24/2023 11:00 AM amlepe bburbage kjharris $ 
# *===========================================================================+
# |  Copyright (c) 2018 Oracle Corporation, Redwood Shores, California, USA
# |  All rights reserved 
# |  Created by Oracle Support Proactive Services  
# +===========================================================================+
# |
# | FILENAME: Menu.pm
# |
# | PLATFORM
# |   Unix Generic
# |
# | NOTES ** See end of file for history / notes ** 
# +===========================================================================+

# +-------------------------------------+
# | sub: testSQLConnection 
# +-------------------------------------+
# | Desc: test SQL connection 
# +-------------------------------------+
# | Args: user/pass 
# +-------------------------------------+
# | Returns: 1 = success, 0 = fail 
# +-------------------------------------+
sub testSQLConnection
{
  my ($user, $pass) = @_;
  my $status = 99;

  #added for cloudInstall.pl 
  if (! -d "sql") 
  {
    chdir ("../../"); 
  }

  unlink('sql/out');
  
  #create sql/testConn.sql 
  if (! -f 'sql/testConn.sql') 
  {
    open (my $fh, '>', 'sql/testConn.sql') || die "  ERROR: testSQLConnection(): Cannot open sql/testConn.sql: $! \n";
    print $fh qq(
    SET VERIFY OFF
    SET ECHO OFF
    exit;
    );
    close $fh;
  } 
  print "\nINFO: Testing SQL Connectivity.. \n";
  my $pid = fork();
  if ($pid > 0)
  {
    eval
    {
      local $SIG{ALRM} = sub {kill 9, -$pid; die "TIMEOUT!"};
      alarm 3;
      waitpid($pid, 0);
      alarm 0; #end fork 
    };
  }
  elsif ($pid == 0)
  {
    setpgrp(0,0);
    system("sqlplus $user\/$pass \@sql\/testConn.sql \> sql\/out 2\>\&1");
    exit(0); #end fork 
  }

  open (my $fh, '<', 'sql/out') || die "testSQLConnection(): Cannot open sql/out: $! \n";
  my @out = <$fh>;
  close $fh;
  
  if (grep(/Connected\sto:/,@out))
  {
    print "INFO: SQL Connection: Success! \n";
    return 1;
  }
  elsif (grep(/ORA-01017/,@out))
  {
    print "ERROR: ORA-01017: invalid username/password; logon denied \n";
    return 0;
  }
  else 
  {
    print "ERROR: Unknown SQL Connection Error: \n";
    print "  $_ \n" foreach @out;
    print "  Press [Enter] to Continue: ";
    <STDIN>;
    return 0;
  }
}

# +--------------------------------------------------------------------------+
# | sub: getAppsCreds 
# | 12:28 PM 4/4/2018 
# +--------------------------------------------------------------------------+
# | Desc: get & check the apps credentials 
# +--------------------------------------------------------------------------+
# | Args: nebytiye
# +--------------------------------------------------------------------------+
# | Returns: 1 = true (good), 0 = false (failed) 
# +--------------------------------------------------------------------------+
sub getAppsCreds
{
  my $appsPass; 
  
  if(_getPass()) 
  {
    $main::connStrg = connectStrg MENU::SQL("apps", $appsPass)
  }
  
  sub _getPass 
  {
    my $cnt = 1;
    until ($cnt > 3) 
    {
      if ($cnt > 1) 
      {
        print BOLD WHITE ON_RED "\nINFO: Unable to Connect! \n\n"; 
        sleep 2; 
        cls(); 
        print "\n  [Attempt $cnt of 3]"; 
      }
      print "\n  Enter your APPS password: ";
      system('stty','-echo');
      chomp($appsPass=<STDIN>);
      system('stty','echo');
      if (testSQLConnection("apps", $appsPass)) 
      {
        return(1); 
      }
      print "\n\n"; 
      $cnt++;
    }
    die "\n\n  ERROR: No valid apps password entered after 3 attempts. " if $cnt > 2;
  }
}#END: getAppsCreds


# +---------------------------+
# | sub:  checkCompat 
# +---------------------------+
# | Desc: 
# +---------------------------+
# | Args: 
# +---------------------------+
# | Returns: 
# +---------------------------+
sub checkCompat
{
  my ($file, $relVer) = @_;
  my ($compat, $valid) = ("null", 0);
  $relVer = getRelVer() if (! $relVer);
  #in case the file passed was not a full path.. 
  if (! -e $file) 
  {
    find( sub {return unless /\.sql$|\.info$|\.xml$/; $file = $File::Find::name if "$file" eq "$_" }, 'analyzers/SQL' );
  }
  
  my $analyzer; 
  
  if ($file =~ /\.xml$/) 
  {
    $analyzer = analyzer MENU::AnalyzerXML($file);
  }
  else #sql files 
  {
    $analyzer = analyzer MENU::Analyzer($file);
  }

  $compat = $analyzer->getCompat();
  $compat =~ s/\s/|/g;
  $compat =~ s/\|$//;
  $relVer = substr $relVer, 0, 4;
  if ($relVer =~ /$compat/i)
  {
    $valid = 1; #true 
  }
  else 
  {
    $valid = 0; #false 
  }
  
  return($compat, $valid);
}#END checkCompat 

# +---------------------------+
# | sub:  displayDirs
# +---------------------------+
# | Desc: Show the product dirs in a menu format 
# +---------------------------+
# | Args: $dir to show 
# +---------------------------+
# | Returns: nada 
# +---------------------------+
sub displayDirs 
{
  my ($dir) = @_;
  chomp($dir);
  my @dirs;
  my %menu;
  my $userSel;
  my $ver = getBundleVer();
  
  if ($dir =~ /^\d/) 
  {
    $dir = 'analyzers/SQL/' . $dir;
  } 
  until (1 == 2) 
  {
    # @dirs = `ls -d $dir/*`;
    opendir my $DH, $dir or die "displayDirs(): Cannot open $dir: $!";
    @dirs = readdir $DH;
    closedir $DH;
    @dirs = sort @dirs;
    my $countDepth = $dir =~ tr/\///;
    cls();
    my $count=0;
    printf "\n     ", RESET if $countDepth == 1;
    printf BOLD WHITE ON_BLUE "E-Business Suite Support Analyzers Main Menu (bundle ver: $ver)", RESET, "\n" if $countDepth == 1;
    printf BOLD WHITE ON_BLUE "\n  Choose a Product:", RESET, "\n\n" if $count < 1;
    foreach my $d (@dirs) 
    {  
      next if $d =~ /^\./;
      $count++;
      chomp($d);
      $d =~ s/\/$//;
      $menu{$count}=$d;
      $d =~ s/\d{2}\_//g;
      $d =~ s/\_/ /g;
      $d = $+ if $d =~ /^.+\/(.+)/;
      print "  [$count] $d \n";
    }

    if ($countDepth == 1)
    {
      #updated 9:46 AM 3/14/2018 
      print qq(  ...\n  [L] Bulk FNDLOAD ALL Analyzers
  [S] Show Installed Analyzers
  [U] Update, AutoUpdate, Uninstall\n\n);
    }
    printf BOLD WHITE ON_BLUE "\n  [B]ack | [M]ain Menu | E[x]it" if $countDepth > 1;
    printf BOLD WHITE ON_BLUE "  [H]elp | E[x]it" if $countDepth == 1;
    print BOLD WHITE ON_YELLOW "   Invalid Selection", RESET if $userSel eq 'invalid';
    printf "\n\n  Selection:";
    chomp($userSel = <STDIN>);
    $main::logr->exitLog() if $userSel =~ /^x{1}$/i;
    
    if ($userSel =~ /^b{1}$/i && $countDepth > 1) 
    {
      $dir = $+ if $dir =~ /^(.+)\/.+/;
      displayDirs($dir);
    }
    elsif ($userSel =~ /^b{1}$/i && $countDepth < 2)
    {
      $userSel = 'invalid';
    }
    elsif ($userSel =~ /^L{1}/i) 
    {
      # bulkMenu($dir);
      pickListMenu('bulk',$dir);
      $count=0;
    }
    # elsif ($userSel =~ /^U{1}/i) 
    # {
      # uninstall();
    # }
    elsif ( $userSel =~/^m{1}$/i ) 
    {
      displayDirs('analyzers/SQL');
    }
    elsif ( $userSel =~/^u{1}$/i ) 
    {
      updateMenu();
    }
    elsif ( $userSel =~/^s{1}$/i ) 
    {
      pickListMenu('show');
    }
    elsif (exists $menu{$userSel})
    {
      opendir my $DH2, $dir . '/' . $menu{$userSel} or die "displayDirs(): Cannot open \" $dir . '/' . $menu{$userSel}\": $!";
      my @dirs1 = readdir $DH2;
      closedir $DH2; 
	  # 11/5/2019 
      my @dirs2 = grep { $_ !~ /\./ } @dirs1;
      my @files = grep { $_ =~ /\.\w{1,4}$/ } @dirs1;
	  my $dirCount = scalar @dirs2; 
	  my $fileCount = scalar @files;
      foreach (@dirs1){chomp($_);}
	  # 11/5/2019 fix for mixed dirs + files 
	  # from ADOP analyzer 
	  if ($fileCount > 0) 
	  {
		displayFiles($dir . '/' . $menu{$userSel} . '/');
	  }
	  else 
	  {
		displayDirs($menu{$userSel});
	  }
    }
    elsif ($userSel =~ /^H{1}/i) 
    {
      system ("clear");
      print "\n";
      print BOLD WHITE ON_BLUE "  Main Menu Help", RESET, "\n";
        print qq (
  o Options 1-5 displays a sub-menu of available Analyzers 
    for that Product Family
  o From the sub-menu, individual Analyzers can be selected, 
    then *run or *loaded as Concurrent Programs 
    (*Not all Analyzers have run and load options) 
  o [L]oad 
    -Loads all the Analyzers in Bulk mode as Concurrent Programs 
  o [C]heck For An Updated Analyzer Bundle 
    -Starts the update process to update to the latest Analyzer Bundle 
  o [S]how Installed Analyzers 
    -Shows Analyzers currently installed as Current Programs 
  o [U]ninstall Analyzers 
    -Starts the Uninstall process (remove Concurrent Programs & Packages) 

  Press [Enter] to Continue:);
  <STDIN>;
    }
    else
    {
      $userSel='invalid' unless $userSel =~ /^L{1}/i;
      $count=0;
    }
  }
}
  
# +---------------------------+
# | sub: displayFiles
# +---------------------------+
# | Desc: shows the analyzer files in a given 
# | dir 
# +---------------------------+
# | Args: $dir  
# +---------------------------+
# | Returns: nada 
# +---------------------------+
sub displayFiles
  {
    my ($dir) = @_;
    # $dir = 'analyzers/SQL/' . $dir . '/';
    my @files;
    my %files;
    my $userSel;
    my %menu;
    my $valid;
    my $relVer = getRelVer();
    my $count = 0;
    opendir my $DH, $dir or die "Cannot open $dir: $!";
    my @files2 = readdir $DH;
    closedir $DH;
  foreach my $f (@files2) 
  {
   #12:21 PM 2/27/2018 
   # push @files, $f if $f =~ /^\.sql/;  <-- bad regex 
    push @files, $f if $f =~ /\.sql$|\.xml$/;
  }
  
  #filter out any files which aren't analyzer files  
  my $elemCnt = scalar(@files);
  for (my $i=0; $i != $elemCnt; $i++)
  {
    my $check = shift @files;
    my $title;
    chomp($check);
    chomp($dir);
    open my $fh, '<', "$dir\/$check" or die "    ERROR: Could not open $dir\/$check: $!";
    my @currFile = <$fh>;
    close $fh;
    my $fileType; 
    
    if ($check =~ /\.sql$/)
    {
      ($title) = grep(/MENU_TITLE:\s+(.+)$/i, @currFile);
      $title = $+ if $title =~ /MENU_TITLE:\s+(.+)$/i;
      $fileType = 'sql'; 
    }
    elsif ($check =~ /\.xml$/)
    {
      ($title) = grep(/\<title\>(.+?)\<\/title\>/i, @currFile);
      $title = $+ if $title =~ /\<title\>(.+?)\<\/title\>/i;
      $fileType = 'xml'; 
    }
    
    undef @currFile;

    my ($compat, $valid) = checkCompat($check, $relVer);
     
    if (defined $title && $valid == 1)
    {
      $count++;
      #split title into ~60 char chunks to forego line wraps 
      if (length($title) > 70) 
      {
        my @splitUp = split(/\s/, $title);
        my $line1 = ''; my $line2;
        $line1 .= (shift@splitUp) . ' ' until length($line1) > 60 ;
        $line2 .= $_ . ' ' foreach (@splitUp);
        $title = $line1 . "\n     " . $line2;
      }
      
      $menu{$count}->{'TITLE'} = $title . "\n      " . '[' . $check . ']';
      $menu{$count}->{'FILE'} = $check;
      $menu{$count}->{'FILETYPE'} = $fileType;
      #push (@files, $title . "\n     " . '[' . $check . ']');
    }
  }

  my $ID = 1;
  my $height = `tput lines`;
  my $width = `tput cols`;
  my $pageSize = ($height - 8)/3;
  my $currPage = 1;
  my $maxPage = (ceil(scalar(keys %menu)/$pageSize));
  my $debug = scalar(keys %menu)/$pageSize;

  until (1 == 2) 
  {
    cls();
    print BOLD WHITE ON_BLUE "\n  Select a Number For Available Options", RESET;
    print BOLD WHITE ON_GREEN " [Page $currPage of $maxPage]",RESET if $maxPage > 1;
    print "\n";
    # for ($ID; $ID <= ($pageSize * $currPage); $ID++)
    for ($ID; $ID <= ($pageSize * $currPage); $ID++)
    {
      next if length($menu{$ID}->{'TITLE'}) < 5;
      print "  [$ID] $menu{$ID}->{'TITLE'}\n\n";
    }
    print "  ...\n  [L] Bulk FNDLOAD Analyzers Listed in This Menu\n";
    # my $countDepth = $dir =~ tr/\///;
    printf BOLD WHITE ON_BLUE "\n  [B]ack | [M]ain Menu | E[x]it";
    print BOLD WHITE ON_GREEN "| [N]ext Page", RESET if $currPage < $maxPage;
    print BOLD WHITE ON_GREEN " | [P]rev Page", RESET if $currPage < $maxPage && $currPage > 1;
    print BOLD WHITE ON_GREEN "| [P]rev Page", RESET if $currPage == $maxPage && $currPage > 1;
    print BOLD WHITE ON_YELLOW " | Invalid Selection", RESET if $userSel eq 'invalid';
    print "\n\n  Selection:";
    chomp($userSel = <STDIN>);
    $main::logr->exitLog() if $userSel =~ /^x{1}$/i;
    if ( $userSel =~ /^b{1}$/i ) 
    {
      $dir = $+ if $dir =~ /(^.+)\/.+/;
      displayDirs($dir);
    }
    elsif ( $userSel =~ /^N{1}/i ) 
    {
      if ($currPage == $maxPage) 
      {
        $userSel = 'invalid';
        $ID = ($ID - $pageSize);
      }
      else
      {
        $ID = floor($pageSize * $currPage + 1);
        $currPage++;
      }
    }
    elsif ( $userSel =~ /^P{1}/i ) 
    {
      if ($currPage == 1) 
      {
        $userSel = 'invalid';
        $ID = 0;
      }
      else 
      {
        $ID = ceil($ID - ($pageSize * 2));
        $currPage = ($currPage -1);
      } 
    }
    elsif ( $userSel =~ /^L{1}/i ) 
    {
      pickListMenu('bulk',$dir);
      $ID = 0;
    }
    elsif ( $userSel =~/^m{1}$/i )
    {
      displayDirs('analyzers/SQL');
    }
    elsif (exists $menu{$userSel})
    {
      #my $file = $+ if $menu{$userSel} =~ /\[(.+\.sql)\]/;
      fileMenu($dir, $menu{$userSel}->{'FILE'}, $menu{$userSel}->{'FILETYPE'});
    }
    else
    {
      $userSel='invalid';
      $count=0;
      $ID = ($ID - $pageSize);
    }
  }
}
  
# +---------------------------+
# | sub:  fileMenu
# +---------------------------+
# | Desc: shows the menu header from an 
# | analyzer file 
# +---------------------------+
# | Args: $dir and file 
# +---------------------------+
# | Returns: nada 
# +---------------------------+

sub fileMenu
{
  my ($dir, $file, $fileType) = @_;
  chomp($dir);
  chomp($file);
  
  #1:26 PM 6/19/2019 Updated for HA 
  my $analyzer; 
  my $title; 
  my $menu; 
  my $runOpts; 
  my $fload; 
  my $help; 
  my $outputType; 
  
  if ($fileType eq 'sql') 
  {
    $analyzer = analyzer MENU::Analyzer($file);
    $title = $analyzer->getTitle();
    $menu = $analyzer->getMenu();
    $runOpts = $analyzer->getRunOpts();
    $fload = $analyzer->getFNDLOADOpts();
    $help = $analyzer->getHelp();
    $outputType = $analyzer->getOutputType();
  
  }
  else #hybrid 
  {
    $analyzer = analyzer MENU::AnalyzerXML($file);
    $title = $analyzer->getTitle();
    $menu = $analyzer->getMenu();
    # $runOpts = $analyzer->getRunOpts();
    # $fload = $analyzer->getFNDLOADOpts();
    $help = $analyzer->getHelp();
    # $outputType = $analyzer->getOutputType();
  }

  my $userSel;
  my %menu;
  my $invSel = 0;
  until ( 1 == 2 )
  {
    my $count = 0;
    foreach (@$menu) 
    {  
      $count++;
      $menu{$count}=$_;
      if ($count == 1)
      {
        cls();
        print "\n";
        print BOLD WHITE ON_BLUE "  $title",RESET;
        print "\n\n";
        print BOLD WHITE ON_BLUE, "  Options for: $file",RESET;
        print "\n";
      }
      print "\n";
      print "  [$count]$_\n";
    }

    print BOLD WHITE ON_BLUE "\n  [B]ack | [M]ain Menu | [H]elp | E[x]it ";
    print BOLD WHITE ON_YELLOW " | Invalid Selection", RESET if $invSel != 0;
    #print "\n  ...\n\n   Selection:";
    print "\n\n   Selection:";
    $invSel = 0;
    chomp($userSel = <STDIN>);
    $main::logr->exitLog() if $userSel =~ /^x{1}$/i;
    
    if ( $userSel =~ /^b{1}$/i )
    {
      displayFiles($dir);
    }
    elsif ( $userSel =~ /^h{1}$/i )
    {
      cls();
      print "\n";
      print BOLD WHITE ON_BLUE "  $title", RESET;
      print "\n\n";
      #11:11 AM 6/19/2019 changed help to string from array 
      # for my $ln (@$help)
      # {
        # print "  $ln\n";
      # }
      print $help; 
      
      printf "\n\n    Press [Enter] to Continue: ";
      <STDIN>;
    }
    elsif ( $userSel =~/^m{1}$/i ) 
    {
      displayDirs('analyzers/SQL');
    }
    
    elsif (exists $menu{$userSel})
    {
      #printf "user selected $menu{$userSel} \n";
      if ( $menu{$userSel} =~ /SQL/ )
      {
        printf "   INFO: Calling runSQL() \n";
        runSQL($dir, $file, $outputType, $runOpts);
      }
      elsif ( $menu{$userSel} =~ /FNDLOAD/ ) 
      {
        #Run Load.pl 
        printf "   INFO: Calling floadSingle() \n";
        floadSingle($file, $fload);
      }
      elsif ( $menu{$userSel} =~ /JAVA:/ ) 
      {
          runJava($file); 
      }
    }
  else
  {
    $invSel = 1;
    #repeat the menu again 
    #need to write a loop around the line 146 foreach menu to redisplay it 
  }
  }#end until loop 
}# end fileMenu sub 
#END fileMenu

# +------------
# | sub trim
# | 
# + ------------
sub trim
{
  my ($v) = @_;
  chomp($v);
  $v =~ s/^REM//ig;
  $v =~ s/^\s+//g;
  $v =~ s/\s+$//g;
  return $v;
}

# +---------------------------+
# | sub: verChkBeforeLoad
# +---------------------------+
# | Desc: version checks an analyzer before
# | it's loaded as a conc program
# +---------------------------+
# | Args: main analyzer file to be loaded
# +---------------------------+
# | Returns: 
# | 
# | 0 = Load 
# | 1 = Don't load (version verified as already higher)
# | 2 = Unknown, couldn't validate version 
# +---------------------------+
sub verChkBeforeLoad
{
  my ($file) = @_;
  my $execMethod;
  my $analyzer = analyzer MENU::Analyzer($file);
  my $progTemplate = 'analyzers/template/' . $analyzer->getProgTemplate;
  my $prodTop = $analyzer->getProdTop . '/sql/';
  # check execution type Q or I from the prog LDT 
  # Q = SQL (PROD_TOP/sql/file.sql), I = plsql pkg (db package)  
  open (my $fh, '<', $progTemplate ) || die "verChkBeforeLoad(): Cannot open $progTemplate $! \n";
  my @a=<$fh>;
  close $fh;
  my $check;
  if (grep(/EXECUTION_METHOD_CODE\s\=\s\"Q\"/, @a))
  {
    #file execution
    $check = versionCheckFiles($file);
    $execMethod = 'Q';
    #what's returned: 0,1,2 (load, don't load, unable to version check) 
  }
  elsif (grep(/EXECUTION_METHOD_CODE\s\=\s\"I\"/, @a))
  {
    #DB pkg execution
    $check = versCheckDBToFile($file);
    $execMethod = 'I';
    #what's returned: 0,1,2 (load, don't load, unable to version check) 
  }
  elsif (grep(/^\s*create\s.*package\sbody|table|view|function|package/, @a))
  {
    #catch-all for packages which do not have menu headers 
    $check = versCheckDBToFile($file);
  }
  else 
  {
    $check = 2;
  }
  
  return($check, $execMethod, $prodTop);
}#end verChkBeforeLoad


# +---------------------------+
# | sub:  checkObjectCreates
# +---------------------------+
# | Desc: checks if a SQL creates a package 
# +---------------------------+
# | Args: a SQL file 
# +---------------------------+
# | Returns: W = sql wrapper 
# | S = anonymous SQL block file 
# | <type> = object creation script 
# +---------------------------+
sub checkObjectCreates
{
  my ($file) = @_;
  my @fileArr;
  my $objType;
  
  if (! -f $file)
  {
    $main::logr->wlSO("WARN: checkObjectCreates(): File does not exist: $file : OS ERR : $!");
    return("FILE_NOT_FOUND"); 
  }
  
  open (my $fh, '<', $file ) || die "checkObjectCreates(): Cannot open $file $! \n";
  
  @fileArr = <$fh>;
  
  if ($#fileArr < 300)
  {
    #wrapper SQL  
    # print "wrapper\n";
    return 'W';
  }
  else 
  {
    foreach my $line (@fileArr)
    {
      $objType = $+ if ($line =~ /^\s*create\s.*?(package\sbody|table|view|function|package)/i || $line =~ /create\s*?or\s*?replace\s.*?(package\sbody|table|view|function|package)/i);
      return ($objType) if defined $objType;
    }
  } 
    
  # while (my $line = <$fh>)
  # {
    # $objType = $+ if ($line =~ /^\s*create\s.*?(package\sbody|table|view|function|package)/i || $line =~ /create\s*?or\s*?replace\s.*?(package\sbody|table|view|function|package)/i);
    # print "debug 584: $objType, $line \n";
    # last if defined $objType;
  # } 
  # close $fh;

  return 'S' if (! defined $objType);
  
  
  # if ($objType =~ /package/i)
  # {
    # return('Y');
  # }
  # else
  # {
    # return('N');
  # }
  
}


# +---------------------------+
# | sub:  runSQL
# +---------------------------+
# | Desc: 
# +---------------------------+
# | Args: 
# +---------------------------+
# | Returns: 
# +---------------------------+
sub runSQL
{
  my ($dir, $file, $outputType, $runOptsRef, $depenRef) = @_;
  my $scriptArgs;
  my $ans;
  my $cs = $main::connStrg->getConnStrg();
  my $runCmd = "sqlplus -s $cs \@";
  #@$runOptsRef @$depenRef 
  my $relVer = getRelVer();
  my ($compat, $valid) = checkCompat($file,$relVer);
  #add a trailing slash so we can append the file to the dir 
  if ($dir !~ /.+\/$/) 
  {
    $dir.='/';
  }
  if ($valid != 1)
  {
    printf "   ERROR: This Analyzer is not compatible with your E-Business Suite Release ($relVer) \n   Compatible Releases: $compat\n\n   Press [Enter] to Continue: ";
    my $wait = <STDIN>;
    return 1;
  }

  #verChkBeforeLoad checks for the execution type 
  # of the ccp and from that can deduce what 
  # the file is (SQL (anon. block) or plsql pkg) 
  #if check == 0, version is higher.. run 
  # check == 1 || 2 , version is lower or version was 
  # not able to be checked.. prompt what to do 
  
  my ($check, $execMethod, $prodTop) = verChkBeforeLoad($dir . $file);
  if ($check == 1 && $execMethod eq 'Q') 
  {
    print "INFO: The version of this file is higher in the $prodTop than in the bundle. It is recommended to exit the Menu and run the file from $prodTop. \n\n   Run the older bundle file now?\n";
    until ($ans =~ /^y|^n/i)
    {
      print "[Y|N]:";
      chomp($ans = <STDIN>);
    }
    if ($ans =~ /^y/i) 
    {
      $check = 0;
    }
    else
    {
      print "INFO: User decided to not proceed with the running of $file \n\n   Press [Enter] to Continue:";
      <STDIN>;
      return();
    }
  }
  elsif ($check == 1 && $execMethod eq 'I') 
  {
    print "INFO: The version of this file is higher in the database than in the bundle. It is recommended to exit the Menu and run the package from the database. \n\n   Run the older bundle file now?\n";
    until ($ans =~ /^y|^n/i)
    {
      print "  [Y|N]:";
      chomp($ans = <STDIN>);
    }
    if ($ans =~ /^y/i) 
    {
      $check = 0;
    }
    else
    {
      print "INFO: User decided to not proceed with the running of $file \n\n   Press [Enter] to Continue:";
      <STDIN>;
      return();
    }
  }
  # elsif ($check == 3) # a return of 3 means the SQL is a wrapper 
  # {
    # print "INFO: Unable to version check file: \n   $file\n   Do you wish to run the file without version checking?\n";
    # until ($ans =~ /^y|^n/i)
    # {
      # print "  [Y|N]:";
      # chomp($ans = <STDIN>);
    # }
    # if ($ans =~ /^y/i) 
    # {
      # $check = 0;
    # }
    # else
    # {
      # print "INFO: User decided to not proceed with the running of $file \n\n   Press [Enter] to Continue:";
      # <STDIN>;
      # return();
    # }
  # }

#we should have already kicked out if the check was not reconciled by now 
# but just in case.. 
return if ($check != 3 && $check != 0);
  
  #always run runDepen, it will figure out if there's no dependencies.. 
  my $status = checkPrereq($dir . $file);
  if ( $status > 0 ) {
    print "  runSQL(): Analyzer prerequisite(s) for $file not met. \n   Running of $file will not succeed, thus exiting. \n   Press [Enter] to Continue:";
    <STDIN>;
    return();
  }

  my $checkDepens = runDepen($dir . $file);
  if ($checkDepens > 0)
  {
    print "  runSQL(): Analyzer dependencies for $file failed. \n   Running of $file will not succeed, thus exiting. \n   Press [Enter] to Continue:";
    <STDIN>;
    return();
  }
  
  if (scalar @$runOptsRef > 0) 
  {
    $runCmd = "sqlplus -s $cs \@";
    foreach (@$runOptsRef)
    {
      my $line = $_;
      if ( $line =~ /ARG:/)
      {
        my $default = $+ if $line =~ /DEFAULT:(.+)$/;
        $default=trim($default);
        my $prompt = $+ if $line =~ /.+?:.+?:(.+)\s?DEFAULT/;
        #get user input
        printf "$prompt (Enter for default: $default): " if length $default > 0;
        printf "$prompt: " if length $default < 1;
        my $userInput;
        chomp($userInput=<STDIN>);
        $userInput = $default if length($userInput) == 0 && length $default > 0;
        $scriptArgs .= ' ' . $userInput;
      }
      $scriptArgs = trim($scriptArgs);
      #print "DEBUG 458: scriptArgs: $scriptArgs \$dir: $dir\n";
    }
    $runCmd = $runCmd . $dir . $file . ' ' . $scriptArgs;
  }
  else 
  {
    $runCmd = "sqlplus -s $cs \@";
    $runCmd .= $dir . $file;
  }

  my $prntCmd;
  if ( $outputType =~ /STDOUT/i ) 
  {
    #check for args / process args RUN_OPTS_START 
    my $reportName = $+ if $file =~ /(\w+)\.\w?/;
    $reportName.="_" . $ENV{CONTEXT_NAME} . "_" . (strftime "%Y-%m-%d_%H%M%S", localtime) . ".html";
     #printf "DEBUG: Running $file using command: $runCmd\n";
    
    $prntCmd = $runCmd;
    $prntCmd =~ s/(?<=\s).+?\/.+?(?=\s\@)/\*\*\*\*\/\*\*\*\*/;
    $main::logr->wlSO("\nINFO: runSQL(): Running: $prntCmd\n\n");
    
    my $status = system("$runCmd 2>&1 | tee output/$reportName");
    $main::logr->wlSO("\nINFO: Analyzer exited with status: $status \n\n   INFO: Done Running $file \n\n");
    #system("mv $reportName ./output/") if -f $reportName;
    $main::logr->wl("Report File: output/$reportName");
    printf BOLD WHITE ON_BLUE "  Report File: output/$reportName";
    printf "\n\n   Press [Enter] to Continue:";
    <STDIN>;
  }
  elsif ( $outputType =~ /^UTL/i )
  {
    $prntCmd = $runCmd;
    $prntCmd =~ s/(?<=\s).+?\/.+?(?=\s\@)/\*\*\*\*\/\*\*\*\*/;
    $main::logr->wl("\nINFO: runSQL(): Running: $prntCmd\n");
    my $status = system($runCmd);
    $main::logr->wlSO("\nINFO: Analyzer exited with status: $status \n");
    printf "\n  Press [Enter] to Continue:";
    <STDIN>;
  }
}

##### 
# Version Checking Subs 
##### 
# +---------------------------+
# | sub: compVersions
# +---------------------------+
# | Desc: 
# +---------------------------+
# | Args: 
# +---------------------------+
# | Returns: 
# +---------------------------+
sub compVersions
{
  my ($newFile, $existingFile) = @_;
  
  #kick rocks if nothing passed in 
  return 1 if ! $newFile && ! $existingFile;
  
  my $majorNew = $+ if $newFile =~ /(\d+?)\.\d+?/;
  my $minorNew = $+ if $newFile =~ /\d+?\.(\d+)$/;
  my $majorExisting = $+ if $existingFile =~ /(\d+?)\.\d+?/;
  my $minorExisting = $+ if $existingFile =~ /\d+?\.(\d+)$/;
  if ($majorNew > $majorExisting) 
    {
      #file is higher/newer 
      return(0, 'replace');
    }
  elsif ($minorNew > $minorExisting && $majorNew == $majorExisting)
    {
        return(0, 'replace');
    }
  elsif ($minorNew == $minorExisting && $majorNew == $majorExisting)
    {
      return(0, 'same');
    }
  else
    {
      return(0, 'existing_higher');
    }
    
  #we did not return yet, so we were unable to compare versions 
  return(1);
}

# +---------------------------+
# | sub: versCheckDBToFile
# +---------------------------+
# | Desc: takes a package-creation SQL file and 
# | checks to see if the package in the DB is > == < the file 
# +---------------------------+
# | Args: full path to SQL file which creates a package. 
# +---------------------------+
# | Returns: 
# | "0" = load
# | "1" = don't load 
# | "2" = unable to compare (versions not found.. etc..)  
# | "3" = No compare .. SQL file 
# +---------------------------+
sub versCheckDBToFile
{
  my ($file) = @_;
  my $isPkg = checkObjectCreates($file);
  my ($status, $inst);
  
  if (uc($isPkg) eq 'PACKAGE')
  {
    ($status, $inst) = getFilePkgVer($file, 1);
  # --If 1 fails, no point in trying anything else. 
    if ($status == 0) 
    {
      my $dbVer;
      #we have a file version 'VER', package name 'NAME', db object_name, 
      ($status, $dbVer) = getDBPkgVer($$inst{$file}->{'NAME'});
      if ($status == 0) 
      {
        my $checkResult;
        ($status, $checkResult) = compVersions($$inst{$file}->{'VER'},$dbVer);
        
        return(0) if $checkResult eq 'replace';
        return(1) if $checkResult eq 'existing_higher';
        return(1) if $checkResult eq 'same';
      }
      elsif ($status == 2) 
      {
        #the package does not exist;
        return (0);
      }
      else 
      {
        print "ERROR: Failed to get version from database for: $$inst{$file}->{'NAME'} \n";
        return(2);
      }
    }
    else 
    {
      print "ERROR: Failed to get version from file: $file \n";
      return(2);
    }
  }#end checking for a package ver 
  else 
  {
    #if isPkg eq 'W' (wrapper) or 'S' (anon sql block) then we should tell
    #the calling sub there was nothing to compare but that was expected. 
    return(3);
  }
  
}#end versCheckDBToFile 


# +---------------------------+
# | sub:  getFilePkgVer
# +---------------------------+
# | Desc: 
# +---------------------------+
# | Args: $file = file to get version from 
# | $mode = 1 if we need to check for a package body specifically 
# +---------------------------+
# | Returns: 
# +---------------------------+
sub getFilePkgVer 
{
  my ($file, $mode) = @_;
  my %instAnalyzers;
  my $cs = $main::connStrg->getConnStrg();
  my $appsUser = $+ if $cs =~ /(\w+?)\//;
  
    #added for AutoUpdate 
  if (length($main::bundleLoc) > 0) 
  {
    chdir($main::bundleLoc . "/MENU");
  }
  
  open (my $fh, '<', $file ) || die "Cannot open $file : $! \n";
  if ($mode == 1)
  {
    while (my $line = <$fh>)
    {
      $line = clean($line);
      next unless $line =~ /^\s*create\s.*?package\sbody/i;
      until ((defined $objectName && defined $ver) || eof($fh))
      {
        $ver = $+ if $line =~ /(\d{1,3}\.\d{1,3})/;
        $objectName = $+ if $line =~ /^\s*create\s.*?package\sbody\s*\w*\.*(\w*)/i;
        $line = <$fh>;
      }
      $instAnalyzers{$file}->{'FILE'}=$file; #file where the create statement was found 
      $instAnalyzers{$file}->{'NAME'}=uc($objectName);
      $instAnalyzers{$file}->{'VER'}=$ver if defined $ver;
    }
  }
  else 
  {
    while (my $line = <$fh>)
    {
      $line = clean($line);
      # $Id: AP_PCLOSE_DETECT_PKG.sql,v 120.14 2015/02/23 19:48:10 alumpe Exp $ 
      $line = <$fh> until eof($fh) || $line =~ /create/i || $line =~ /\$Id:|\$Header:/;
      if ($line =~ /^\s*create\s.*(package\sbody|table|view|function|package)/i)
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
          $line =~ /^\s*create\s.*(package\sbody|table|view|function|package)/i;
          $objectType = $+;
          if (! defined $objectType)
          {
            warn "   getFilePkgVer(): WARNING: The Database Object Created by the following file could not be determined:\n   $file \n   ACTION: Manually open/view the file to determine if there are \n   database objects created, then drop those objects manually.\n";
            print "  Press [Enter] to Continue:";
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
          $objectName=uc($objectName);
          my $statement = "drop " . $objectType . " $appsUser\." . $objectName . ';';
          
          my $dup = 'N';
          for my $ids (keys %instAnalyzers)
          {
            $dup = 'Y' if ($instAnalyzers{$ids}->{'NAME'} eq $objectName && $instAnalyzers{$ids}->{'TYPE'} eq $objectType);
          }
          if ($dup ne 'Y') 
          {
        
            $instAnalyzers{$file}->{'FILE'}=$file; #file where the create statement was found 
            $instAnalyzers{$file}->{'DROP'}=$statement;
            $instAnalyzers{$file}->{'NAME'}=$objectName;
            $instAnalyzers{$file}->{'TYPE'}=$objectType;
          }
        }
      }
      if ($line =~ /\$Id:|\$Header:/) 
      {
        my $ver = $+ if $line =~ /(\d{1,3}\.\d{1,3})/;
        $instAnalyzers{$file}->{'VER'}=$ver if defined $ver;
      }
    }
  }#end else 
  close $fh;

  if ($instAnalyzers{$file}->{'VER'} =~ /\d{3}\.\d{1,3}/)
  {
    return(0, \%instAnalyzers);
  }
  else  
  {
    return 1;
  }
}

# +---------------------------+
# | sub: getDBPkgVer 
# +---------------------------+
# | Desc: 
# +---------------------------+  
# | Args: 
# +---------------------------+
# | Returns: 0 = "found version" 
# | 1 = "
# | 2 = " 
# +---------------------------+
sub getDBPkgVer
{
  my ($pkg) = @_;
  my $cs = $main::connStrg->getConnStrg();
  my $ver;
  
  #added for AutoUpdate 
  if (length($main::bundleLoc) > 0) 
  {
    chdir($main::bundleLoc . "/MENU");
  }
  
  #create the select and put it into a tmp file 
  open (my $fh, '>', 'sql/getHeader.sql' ) || die "getDBPkgVer(): Cannot open \'sql/getHeader.sql\' $! \n";
  
  $pkg=uc($pkg);
  
  print $fh qq(
SET HEAD OFF;
SET VERIFY OFF;
SPOOL sql/header.lst;
select text from user_source where name = \'$pkg\' and line < 5;
SPOOL OFF;
exit;
  );
  close $fh;

  my $status;
  if (-f 'sql/getHeader.sql') 
  {
    $status = system("sqlplus -s $cs \@sql/getHeader.sql > /dev/null");
    print "ERROR: getDBPkgVer(): SQL*PLUS connection failed. Unable to compare package versions. Press [Enter] to Continue:" if $status != 0;
    <STDIN> if $status != 0;
  
    open (my $fh1, '<', 'sql/header.lst' ) || die "Cannot open $file $! \n";
    my @spool = <$fh1>;
    close $fh1;
  
    #if the spool file contains less than 10 lines
    #we did not get any rows selected. 
    #we have to do this because if the DB lang is not english
    #we cannot depend on the message being "no rows selected". 
    return(2) if $#spool < 10;
  
  for my $i (0..$#spool) 
  {
    next unless ($spool[$i] =~ /^PACKAGE\sBODY/);
    until ($i == $#spool || $ver =~ /\d{1,3}\.\d{1,3}/) 
    {
      $ver = $+ if $spool[$i] =~ /\$Id\:.+?(\d{1,3}\.\d{1,3})/;
      $ver = $+ if $spool[$i] =~ /\$Header\:.+?(\d{1,3}\.\d{1,3})/;
      $i++;
    }

    last if $ver =~ /\d{1,3}\.\d{1,3}/;
  }
  
    if ($ver =~ /\d{1,3}\.\d{1,3}/)
    {
      return(0, $ver);
    } 
    else 
    {
      return(1);
    }  

  }
}

# +---------------------------+
# | sub: versionCheckFiles
# +---------------------------+
# | Desc:  
# +---------------------------+
# | Args: full path to analyzer SQL file 
# | 
# +---------------------------+
# | Returns: 
# | "0" = copy the file, version is higher than PROD_TOP/sql 
# | "1" = don't copy, the version is lower (or equal) than PROD_TOP/sql  
# | "2" = unable to compare (versions not found.. etc..) 
# +---------------------------+
sub versionCheckFiles
{
  my ($file) = @_;
  
  #open the $file passed, check for a version 
  #get the line "REM PROD_TOP: " to check 
  #if the file exists in PROD_TOP/sql and if so, check the version 
  
  open (my $fh, '<', $file ) || die "versionCheckFiles(): Cannot open $file $! \n";
  my @a = <$fh>;
  close $fh;
  my ($prodTop) = grep(/PROD_TOP:/, @a);
  $prodTop =~ s/^REM\s+?PROD_TOP:\s*//g;
  chomp($prodTop);
  my $newVer;
  ($newVer) = grep(/\$Id:/,@a);
  ($newVer) = grep(/\$Header:/,@a) if ! $newVer;
  $newVer = $+ if $newVer =~ /(\d{1,3}\.\d{1,3})/;
  my $fp = $ENV{$prodTop} . '/sql/' . basename($file);
  #if the file does not exist, return now (advise the calling sub to copy the file) 
  return (0) if ! -f $fp;
  
  undef @a;
  open (my $fh1, '<', $fp ) || die "versionCheckFiles(): Cannot open $file $! \n";
  @a = <$fh1>;
  close $fh1;
  
  my $existingVer;
  ($existingVer) = grep(/\$Id:/,@a);
  ($existingVer) = grep(/\$Header:/,@a) if ! $existingVer;
  $existingVer = $+ if $existingVer =~ /(\d{1,3}\.\d{1,3})/;
  my ($status, $action) = compVersions($newVer, $existingVer);
  if ($status == 0) 
  {
    #print "action: $action \n";
    return(0) if $action eq 'replace' || $action eq 'same';
    return(1) if $action eq 'existing_higher';
  }
  else 
  {
    print "ERROR: Failed to get version from:\n $file \nor $fp \n";
    return(2);
  }
  
}#end versionCheckFiles

# +---------------------------+
# | sub: getFileVer 
# +---------------------------+
# | Desc: gets the first instance of $Id: or $Header: from a given file 
# +---------------------------+
# | Args: single, full path to file. 
# +---------------------------+
# | Returns: the version or "1" if failed, returns 2 if the file doesn't exist 
# | "1" usually means that the file version couldn't be detected, whereas 2 is always "did not exist" 
# +---------------------------+

sub getFileVer
{
  my ($file) = @_;
  if (-e $file) 
  {
    open (my $fh, '<', $file ) || die "getFileVer(): Cannot open $file $! \n";
    @a = <$fh>;
    close $fh;
  }
  else
  {
    $file = basename($file);
    my $analyzer = analyzer MENU::Analyzer($file);
    my $file2 = $analyzer->getCPFile;
    if (length($file2) > 1) 
    {
      #account for CP_FILE param 
      #$DB::single = 1;
      $file = basename($file);
      #my $dir = dirname($file);
      $file = $analyzer->getCPFile;
      my $prodTop = $analyzer->getProdTop;
      $file = $ENV{$prodTop} . '/sql/' . $file2;
      if (-e $file) 
      {
        open (my $fh, '<', $file ) || die "getFileVer(): Cannot open $file $! \n";
        @a = <$fh>;
        close $fh;
      }
    }
    else 
    {
      #There are cases where the file attempting to be checked 
      #will not have a bundle header and will not be found 
      #under $PROD_TOP/sql .. so we cannot have an accurate version
      #check, we have a "no_file" situation. 
      return(2);
    }
  } 
  
  my $ver;
  ($ver) = grep(/\$Id:/,@a);
  ($ver) = grep(/\$Header:/,@a) if ! $ver;
  $ver = $+ if $ver =~ /(\d{1,3}\.\d{1,3})/;
  if ($ver =~ /(\d{1,3}\.\d{1,3})/) 
  {
    return ($ver);
  }
  else
  {
    return 1;
  }
}

# +---------------------------+
# | sub:  showNewAnalyzers
# +---------------------------+
# | Desc: prints the README.txt lines to 
# | show the new Analyzers in the bundle 
# +---------------------------+
# | Args: none 
# +---------------------------+
# | Returns: nothing 
# +---------------------------+
sub showNewAnalyzers 
{
  cls();
  print BOLD WHITE ON_BLUE "\n", "  New Analyzers in this Bundle: ", RESET, "\n";
  open (my $fh, '<', 'README.txt' ) || die "showNewAnalyzers(): Cannot open README.txt $! \n";
  while (my $line = <$fh>) 
  {
    next until $line =~ /^New Analyzers/;
    $line = <$fh> for (1..2);
    until ($line =~ /^\=/)
    {
      print "  $line";
      $line = <$fh>;
    }
  }
  close $fh;
  print "  Press [Enter] to Continue:";
  <STDIN>;
  cls();
  return();
}

# +---------------------------+
# | sub: prnt2LogSTDOUT
# +---------------------------+
# | Desc: Print to main log and STDOUT 
# | stubbed 6:58 PM 4/13/2018
# +---------------------------+
# | Args: 
# +---------------------------+
# | Returns: 
# +---------------------------+
# sub prnt2LogSTDOUT
# {
  # $| = 1;
  # open (my $fh, '>>', $main::log) || return();
  
  # my @arr = @_;
  # foreach my $line (@arr)
  # {
    # $line =~ s/^\s{1,10}//;
    # print $fh $line;
  # }
  ##print $fh "@_";
  # print "@_";
  # close($fh);
# }

# +---------------------------+
# | sub: prnt2Log
# +---------------------------+
# | Desc: prints only to log 
# | stubbed 6:58 PM 4/13/2018 
# +---------------------------+
# | Args: 
# +---------------------------+
# | Returns: 
# +---------------------------+
# sub prnt2Log
# {
  # $| = 1;
  # open (my $fh, '>>', $main::log) || return();
  # print $fh "@_";
  # close($fh);
# }

# +---------------------------+
# | sub: exitLog 
# +---------------------------+
# | Desc: shows the log location and exits;
# | stubbed 7:01 PM 4/13/2018
# +---------------------------+
# | Args: 
# +---------------------------+
# | Returns: 
# +---------------------------+
# sub exitLog
# {
  # open (my $fh, '>>', $main::log ) || die "$main::logr->exitLog(): Cannot open $main::log $! \n";
  # print $fh "\n\n*****Menu.pl session end:", (strftime "%H:%M:%S %Y-%m-%d", localtime), "*****\n\n";
  # print "\n\n   INFO: Menu.pl Log: $main::log \n\n";
  # exit;
# }

# +--------------------------------------------------------------------------+
# | sub: cls 
# +--------------------------------------------------------------------------+
# | Desc: clear screen 
# +--------------------------------------------------------------------------+
# | Args: nebytiye
# +--------------------------------------------------------------------------+
# | Returns: nada
# +--------------------------------------------------------------------------+
sub cls 
{
  system("clear");
}#END: cls 


return 1;

__END__
# +===========================================================================+
# |
# | HISTORY
# | 200.0 Creation (13-NOV-2014) 
# | 200.1: Added version checking subs (22-MAY-2015) 
# | 200.2: Removed all usage of UNIX "ls" in favor for Perl opendir() to read dir content
# | 200.3: Updated sqlplus calls to remove "-l" arg 
# |  --Added new sql connection test sub 
# | 200.4: Updated displayFiles() sub to only look at .sql files 
# | 200.5: 
# | --> Updated all /dev/null redirects to "command > /dev/null" 
# |     This works universally on ksh/bash 
# | 200.6: 
# | --> Updated displayFiles() sub to only show .sql files in the menu 
# | 200.7: 
# | --> AutoUpdate Changes: 
# |       displayDirs() changed menu structure 
# |       added "chdir" to some subs to give orientation to the sub 
# | 200.8: 
# | --> Added getAppsCreds() to process apps credentials more cleanly 
# | 200.9: 
# | --> Updated logging to Logger.pm 
# | 200.10 
# | --> "lgr" fix ("lgr" should be "logr") typo-bug
# | 200.11 
# | --> update for Hybrid XML reading 
# | 200.12 
# | --> Fixed issue where a dir inside analyzers/SQL will force "displayDirs()" 
# |     to run instead of display files. (Brought on by ADOP Analyzer) 
# | 200.13
# | --> Fixed checkObjectCreates() sub. If file does not exist, just keep 
# |     going in case of a bulk load, we should not "die" 
# | 200.14
# | --> Call checkPrereq() to check for prerequisite before running analyzer
# +===========================================================================+
