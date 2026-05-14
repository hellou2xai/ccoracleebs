# DCipsa.ctl:486:Collects Oracle Communications IP Service Activator Information
# $Id: DCipsa.ctl,v 1.7 2013/12/18 13:31:17 RDA Exp $
# ARCS: $Header: /home/cvs/cvs/RDA_8/src/scripting/lib/collect/CGBU/DCipsa.ctl,v 1.7 2013/12/18 13:31:17 RDA Exp $
#
# Change History
# 20131217  KRA  Fix spell.

=head1 NAME

CGBU:DCipsa - Collect Oracle Communications IP Service Activator Information

=head1 DESCRIPTION

This module collects Oracle Communications IPSA-related information.

The following reports can be generated and are regrouped under
C<IP Service Activator>:

=head1 REPORTS

=cut

echo tput('bold'),'Processing CGBU.IPSA module ...',tput('off')

# Initialization
var $DEEPLOG    = ${B_DO_DEEPLOG:false}
var $IPSA_DIR   = ${D_HOME:''}
var $TAIL       = ${N_TAIL:10000}
var $TAIL_AUDIT = ${N_AUDIT_TAIL:2000}
var $TAIL_DEEP  = ${N_DEEPLOG_TAIL:40000}

var $IPSA_AUDITS  = catDir($IPSA_DIR,'AuditTrails')
var $IPSA_CONFIGS = catDir($IPSA_DIR,'Config')
var $IPSA_LIBS    = catDir($IPSA_DIR,'lib')
var $IPSA_LOGS    = catDir($IPSA_DIR,'logs')

var $PKGINFO = findCommand('pkginfo')

var $TOC  = '%TOC%'
var $TOC2 = '%TOC2%'
var $TOC3 = '%TOC3%'
var $TOP  = '[[#Top][Back to top]]'
toc '1:IP Service Activator'

# Load the common macros
run RDA:library()

# -----------------------------------------------------------------------------

# Generates thread and severity level analysis of log files
macro analyze_log
{var ($fil,\@uid,$rpt,$lnk,$typ) = @arg
 import $TOC3,$TOP
 keep $TOC3,$TOP

 report $rpt
 write '---+!! From: ',encode($fil)
 write $TOC3
 loop $uid (@uid)
 {next !match($uid,'^[^\.]')
  write '---+ ',$typ,': ',replace($uid,'\*','&#42;',true)
  write '<verbatim>'
  loop $lin (grepLastFile(verbatim(concat('|',$uid,'|'))))
   write $lin
  write '</verbatim>'
  write $TOP
 }
 toc '4:[[',getFile(),'][rda_report][',$lnk,']]'
}

macro get_logs
{var (\%tb_typ,$dir,\@typ) = @arg

 loop $typ (@typ)
 {loop $log (reverse(grepDir($dir,concat($typ,'\.log'),'n')))
  {if match($log,'\.log$')
    var $tb_typ{$typ} = join('\001',$log,$tb_typ{$typ})
   else
    var $tb_typ{$typ} = join('\001',$tb_typ{$typ},$log)
  }
 }
}

# Get the list of unique values of a particular token
macro get_unique_identifiers
{var (\@tbl,$off,$max) = @arg

 loop $lin (grepLastFile('\|'))
 {var @tbl = split('\|',$lin,$max)
  var $uid{$tbl[$off]} = 0
 }
 var @tbl = keys(%uid)
}

macro get_unique_identifiers2
{var (\@tbl1,\@tbl2,$off1,$off2,$max) = @arg

 loop $lin (grepLastFile('\|'))
 {var @tbl = split('\|',$lin,$max)
  var $uid1{$tbl[$off1]} = 0
  var $uid2{$tbl[$off2]} = 0
 }
 var @tbl1 = keys(%uid1)
 var @tbl2 = keys(%uid2)
}

# Pre-process a log file
macro process_log
{# Create a temporary file
 var $tmp = createTemp('ipsa')

 # Process each line of the log file
 loop $lin (getLines())
 {var ($cur1,$cur2,$cur3,$cur4) = split('\|',$lin,4)

  if expr('<',index($cur1,'....'),0)
   var $prv1 = $cur1
  else
   var $cur1 = $prv1

  if expr('<',index($cur2,'....'),0)
   var $prv2 = $cur2
  else
   var $cur2 = $prv2

  if expr('<',index($cur3,'....'),0)
   var $prv3 = $cur3
  else
   var $cur3 = $prv3

  call writeTemp('ipsa',join('|',$cur1,$cur2,$cur3,$cur4))
 }
 call closeTemp('ipsa')

 # Load the result
 call loadFile($tmp)
 call unlinkTemp('ipsa')
}

# Report file statistics fro a group of files
macro stat_files
{var $fmt = '%a %b %d %Y %H:%M'
 loop $fil (@arg)
  write '|',encode($fil),'| ',getSize($fil),'|',getLastAccess($fil,$fmt),' |',\
                                                getLastChange($fil,$fmt),' |',\
                                                getLastModify($fil,$fmt),' |'
 return $out
}

# List directory content recursively
macro stat_tree
{var ($dir) = @arg
 import $TOP

 prefix
 {
 }
 call statDir('n',$dir)
 if hasOutput(true)
  write $TOP

 loop $pth (grepDir($dir,'^\.+$','npv'))
 {if ?testFile('dr',$pth)
  {next ?testFile('l',$pth)
   call stat_tree($pth)
  }
 }
}

# -----------------------------------------------------------------------------

=head2 components - Installed Components

Lists installed components.

=cut

debug ' Inside IPSA module, checking installed IPSA software'
report components
prefix
{write '---+ Components'
 write '|*Component*|*Type*|*Location*|*Version*|*Status*|'
}
loop $lin (grepCommand(concat($IPSA_DIR,'/bin/ListComponents -list'),':'))
{var $dot = index($lin,'.')
 var $nam = substr($lin,0,$dot)

 var $pos = index($lin,'@')
 incr $pos
 var $lgt = index($lin,'[')
 decr $lgt,$pos
 var $loc = substr($lin,$pos,$lgt)

 var $pos = index($lin,'.')
 incr $pos
 var $lgt = index($lin,'@')
 decr $lgt,$pos
 var $typ = substr($lin,$pos,$lgt)

 var $sta = 'Down'
 var $pos = index($lin,'>')
 if compare('ge',$pos,'0')
 {incr $pos
  var $lgt = index($lin,'=')
  decr $lgt,$pos
  var $sta = substr($lin,$pos,$lgt)
 }

 var $pos = rindex($lin,'[')
 incr $pos
 var $lgt = rindex($lin,']')
 decr $lgt,$pos
 var $ver = substr($lin,$pos,$lgt)

 write '|',$nam,' |',$typ,' |',$loc,'|',$ver,' |',$sta,'|'
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Installed Components]]'

=head2 variables - IPSA Variables

Collects system variables relevant to Oracle Communication IP Service Activator.

=cut

debug ' Inside IPSA module, getting list of IPSA environmental variables'
report variables
title '---+!! IPSA Variables (not available in all version of IPSA)'
title $TOC
prefix
{write '---+ ORCHcore Variables'
 write '|*ORCHcore variable*|*Value*|'
}
if length($IPSA_DIR)
 write '|ORCHESTREAM_DIR|',$IPSA_DIR,' |'
if grepCommand('pkgparam ORCHcore NAMING_SERVICE_PORT_NUMBER','.*')
 write '|NAMING_SERVICE_PORT_NUMBER|',last,' |'
if grepCommand('pkgparam ORCHcore NAMING_SERVICE_LOCATION','.*')
 write '|NAMING_SERVICE_LOCATION|',last,' |'
if grepCommand('pkgparam ORCHcore ADD_ORCH_USER','.*')
 write '|ADD_ORCH_USER|',last,' |'
if grepCommand('pkgparam ORCHcore ADD_ORCH_GROUP','.*')
 write '|ADD_ORCH_GROUP|',last,' |'
if grepCommand('pkgparam ORCHcore HOME_DIR','.*')
 write '|HOME_DIR|',encode(last),' |'
if grepCommand('pkgparam ORCHcore AUTOMATIC_STARTUP_REQUIRED','.*')
 write '|AUTOMATIC_STARTUP_REQUIRED|',last,' |'
if hasOutput(true)
 write $TOP

prefix
{write '---+ ORCHplcy Variables'
 write '|*Variable*|*Value*|'
}
if grepCommand('pkgparam ORCHplcy SERIAL_NUMBER','.*')
 write '|SERIAL_NUMBER|',last,' |'
if hasOutput(true)
 write $TOP

prefix
{write '---+ ORCHodbc Variables'
 write '|*Variable*|*Value*|'
}
if grepCommand('pkgparam ORCHodbc DATABASE_SOURCE_NAME','.*')
 write '|DATABASE_SOURCE_NAME|',last,' |'
if grepCommand('pkgparam ORCHodbc DATABASE_UID','.*')
 write '|DATABASE_UID|',last,' |'
if grepCommand('pkgparam ORCHodbc DATABASE_PASSWORD','.*')
 write '|DATABASE_PASSWORD|',last,' |'
if grepCommand('pkgparam ORCHodbc DATABASE_SERVICE_NAME','.*')
 write '|DATABASE_SERVICE_NAME|',last,' |'
if grepCommand('pkgparam ORCHodbc ORACLE_HOME','.*')
 write '|ORACLE_HOME|',encode(last),' |'
if grepCommand('pkgparam ORCHodbc ORACLE_SID','.*')
 write '|ORACLE_SID|',last,' |'
if grepCommand('pkgparam ORCHodbc DATABASE_SERVER_NAME','.*')
 write '|DATABASE_SERVER_NAME|',last,' |'
if grepCommand('pkgparam ORCHodbc DATABASE_SERVER_PORT','.*')
 write '|DATABASE_SERVER_PORT|',last,' |'
if hasOutput(true)
 write $TOP

if $PKGINFO
{prefix
 {write '---+ IPSA Variables Information'
  write 'Using: pkginfo | grep ORCH'
  write '<verbatim>'
 }
 var @ORCH_LIST = grepCommand($PKGINFO,'ORCH')
 loop $lin (last)
  write $lin
 if hasOutput(true)
  write $TOP
}
if isCreated()
 toc '2:[[',getFile(),'][rda_report][IPSA Variables]]'

=head2 system_packages - System Package Information

Gathers the system package information.

=cut

debug ' Inside IPSA module, getting full list system packages'
if $PKGINFO
{report system_packages
 prefix
 {write '---+ System Package Information'
  write '---## Using: pkginfo -i -l'
 }
 call writeCommand(concat($PKGINFO,' -i -l'))
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][System Package Information]]'
}

=head2 ipsa_packages - IPSA Package Information

Gathers the IPSA specific package information.

=cut

debug ' Inside IPSA module, getting list of IPSA packages'
var $cmd = findCommand('pkgparam')
if and($PKGINFO,defined($cmd),@ORCH_LIST)
{report ipsa_packages
 title '---+!! pkgparam all ORCH* Packages'
 title $TOC2
 loop $pkg (@ORCH_LIST)
 {var $var = match($pkg,'(ORCH.{0,16})')
  prefix
  {write '---+ ',$var
   write '|*Parameter*|*Value*|'
  }
  loop $lin (grepCommand(concat($cmd,' -v ',quote($var)),'.*'))
   write '|',key($lin),' |',value($lin),' |'
  if hasOutput(true)
   write $TOP
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][IPSA Package Information]]'
}

=head2 miscellaneous - Miscellaneous Information

Gathers miscellaneous information.

=cut

debug ' Inside IPSA module, getting miscellaneous information'
report miscellaneous
title '---+!! Miscellaneous Information'
title $TOC

if ?findCommand('prtdiag')
{var $cmd = last
 prefix
 {write '---+ prtdiag'
  write '---## Using: prtdiag -v'
 }
 call writeCommand(concat($cmd,' -v'))
 if hasOutput(true)
  write $TOP
}

if ?findCommand('prtconf')
{var $cmd = last
 prefix
 {write '---+ prtconf'
  write '---## Using: prtconf -v'
 }
 call writeCommand(concat($cmd,' -v'))
 if hasOutput(true)
  write $TOP
}

if ?findCommand('sysdef')
{var $cmd = last
 prefix
 {write '---+ sysdef'
  write '---## Using: sysdef -v'
 }
 call writeCommand($cmd)
 if hasOutput(true)
  write $TOP
}

var %pid = ()
if ?findCommand('ps')
{loop $lin (grepCommand(concat(last,' -ef'),'orchadm'))
 {if match($lin,'bin')
   var $pid{field('\s* \s*',1,$lin)} = substr($lin,index($lin,$IPSA_DIR))
 }

 prefix
  write '---+ PFiles of IPSA Processes'
 loop $pid (keys(%pid))
 {write '---++ PID:',$pid,' - ',$pid{$pid}
  call writeCommand(concat('pfiles ',$pid))
  write $TOP
 }
 if !hasOutput()
  write 'No information available'

 prefix
  write '---+ PLimit of IPSA Processes'
 loop $pid (@pid)
 {write '---++ PID:',$pid,' - ',$pid{$pid}
  call writeCommand(concat('plimit ',$pid))
  write $TOP
 }
 if !hasOutput()
  write 'No information available'
}
if isCreated()
 toc '2:[[',getFile(),'][rda_report][Miscellaneous Information]]'

=head2 audit_trails - Audit Trails

Gathers the last lines of audit trails.

=cut

debug ' Inside IPSA module, retrieving audit tails'
report audit_trails
prefix
{write '---+!! Audit Trails'
 write '---## Last ',$TAIL_AUDIT,' Lines',
 write '---## Recursively Searched from: ',encode($IPSA_AUDITS)
 write $TOC
}
loop $fil (grepDir($IPSA_AUDITS,'\.log','dr'))
{if ?testFile('fT',$fil)
 {write '---+',encode($fil)
  call writeTail($fil,$TAIL_AUDIT)
  write $TOP
 }
}
if isCreated(true)
toc '2:[[',getFile(),'][rda_report][Audit Trails]]'

=head2 config_files - Configuration Files

Gathers configuration files.

=cut

debug ' Inside IPSA module, retrieving IPSA configuration files'
report config_files
prefix
{write '---+!! Configuration Files'
 write '---## Recursively Searched from: ',encode($IPSA_CONFIGS)
 write $TOC2
}
loop $fil (grepDir($IPSA_CONFIGS,'.*','dr'))
{if ?testFile('fT',$fil)
 {write '---+ ',encode($fil)
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Configuration Files]]'

=head2 inventory_files - Inventory Files

Gathers inventory files.

=cut

debug ' Inside IPSA module, retrieving IPSA inventory files'
report inventory_files
var $dir = catDir($IPSA_DIR,'inventory')
prefix
{write '---+!! Inventory Files'
 write '---## Recursively Searched from: ',encode($dir)
 write $TOC2
}
loop $fil (grepDir($dir,'.*','dr'))
{if ?testFile('fT',$fil)
 {write '---+ ',encode($fil)
  call writeFile($fil)
  write $TOP
 }
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Inventory Files]]'

=head2 lib_files - Library Files

Lists library files and some related statistics.

=cut

debug ' Inside IPSA module, getting list of library files'
report lib_files
prefix
{write '---+!! Library Files'
 write '---## Recursively Searched from: ',encode($IPSA_LIBS)
 write '|*Library File*| *Size*|*Last Access*|*Last Change*|*Last Modify*|'
}
call stat_files(grepDir($IPSA_LIBS,'.*','dr'))
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Library Files]]'

=head2 all_directories - Full Directory Listing

Lists the content of the Oracle Communications IPSA directory structure.

=cut

debug ' Inside IPSA module, listing IPSA directory structure'
report all_directories
title '---+ Oracle Communications IPSA Directory Structure Content'
title '---## Recursively Searched from ',encode($IPSA_DIR)
call stat_tree($IPSA_DIR)
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Full Directory Listing]]'

=head2 core_analysis - Core Files

Analyzes core files.

=cut

if ?findCommand('pstack')
{var $cmd = last
 if grepDir($IPSA_LOGS,'core','p')
 {var @fil = last

  debug ' Inside IPSA module,analyzing core files'
  report core_analysis
  title '---# core.* Files'
  title '---## Recursively Searched from: ',encode($IPSA_DIR)
  title '---## Using pstack'
  title $TOC

  loop $fil (grepDir($IPSA_LOGS,'core','np'))
  {prefix
    write '---+',encode($fil)
   call writeCommand(concat($cmd,' ',quote($fil)))
   if hasOutput(true)
    write $TOP
  }
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Core Files]]'
 }
}

=head2 profile_extractor - Profile Extractor

Gathers results from the Profile Extractor tool.

=cut

debug ' Inside IPSA module, printing results from profile extractor tool'
report profile_extractor
title '---# Profile Extractor Result Files'
title '---## *.LST files Recursively Searched from: ',encode($IPSA_DIR)
title $TOC
loop $fil (grepDir($IPSA_DIR,'.*\.LST','np'))
{prefix
  write '---+',encode($fil),' (Unformatted)'
 call writeFile($fil)
 if hasOutput(true)
  write $TOP
}
if isCreated(true)
 toc '2:[[',getFile(),'][rda_report][Profile Extractor]]'

=head2 Log Files

Lists the contents of IPSA log files and analyzes them when requested.

=cut

debug ' Inside IPSA module, displaying IPSA log files'
if grepDir($IPSA_LOGS,'\.log','np')
{var @log = last

 report standard_log_analysis
 title '---+!! Log Files'
 title '---## Last ',$TAIL,' Lines',
 title $TOC
 loop $log (@log)
 {prefix
   write '---+ ',encode($log)
  call writeTail($log,$TAIL)
  if hasOutput(true)
   write $TOP
 }
 if isCreated(true)
  toc '2:[[',getFile(),'][rda_report][Log Files]]'

 # Analyze the log files on request
 if $DEEPLOG
 {debug ' Inside IPSA module, performing deep log file analysis'
  report deep_log_analysis
  title '---+ Deep Log File Analysis'
  title '|*Log File*| *Size*|*Last Access*|*Last Change*|*Last Modify*|'
  call stat_files(@log)
  if isCreated(true)
   toc '2:[[',getFile(),'][rda_report][Deep Log File Analysis]]'

  # Identify log files matching the following types
  var (@uid1,@uid2,%typ) = ()
  var @typ = ('cman',\
              'integration_manager',\
              'networkprocessor',\
              'orchcm',\
              'orchns',\
              'policy_server',\
              'system_log',\
              'transaction_monitor',\
              'upgradetool')
  call get_logs(\%typ,$IPSA_LOGS,\@typ)

  # Certain log types require specialized preprocessing
  #call preprocess_log_file($tmp,'cman')

  # Report the log files
  loop $typ (keys(%typ))
  {var $max = 0
   decr $max,$TAIL_DEEP
   loop $log (split('\001',$typ{$typ}))
   {var $pth = catFile($IPSA_LOGS,$log)

    # Load the file
    next !loadFile($pth,$max)
    incr $max,getLastLength()

    # Start a report on this log file
    debug ' Inside IPSA modules, performing deep analysis of ',$log
    report concat('l_',$log)
    write '---+!! Data Extracted from: ',encode($pth)
    call writeLastFile()
    write $TOP
    toc '3:[[',getFile(),'][rda_report][',encode($log),']]'

    # Only certain log files can be parsed for threads and log severity levels
    if match($typ,'cman')
    {call process_log()
     call get_unique_identifiers2(\@uid1,\@uid2,1,2,4)
     call analyze_log($pth,\@uid1,concat('l_',$log,'_threads'),\
                      'Threads','Thread')
     call analyze_log($pth,\@uid2,concat('l_',$log,'_severity'),\
                      'Severity Levels','Severity Level')
    }
    elsif match($typ,'integration_manager')
    {call get_unique_identifiers2(\@uid1,\@uid2,1,2,4)
     call analyze_log($pth,\@uid1,concat('l_',$log,'_threads'),\
                      'Threads','Thread')
     call analyze_log($pth,\@uid2,concat('l_',$log,'_severity'),\
                      'Severity Levels','Severity Level')
    }
    elsif match($typ,'networkprocessor')
    {call get_unique_identifiers2(\@uid1,\@uid2,3,2,5)
     call analyze_log($pth,\@uid1,concat('l_',$log,'_threads'),\
                      'Threads','Thread')
     call analyze_log($pth,\@uid2,concat('l_',$log,'_severity'),\
                      'Severity Levels','Severity Level')
    }
    elsif match($typ,'policy_server')
    {call get_unique_identifiers2(\@uid1,\@uid2,1,2,4)
     call analyze_log($pth,\@uid1,concat('l_',$log,'_threads'),\
                      'Threads','Thread')
     call analyze_log($pth,\@uid2,concat('l_',$log,'_severity'),\
                      'Severity Levels','Severity Level')
    }
    elsif match($typ,'system_log')
    {call get_unique_identifiers2(\@uid1,\@uid2,1,2,4)
     call analyze_log($pth,\@uid1,concat('l_',$log,'_threads'),\
                      'Threads','Thread')
     call analyze_log($pth,\@uid2,concat('l_',$log,'_severity'),\
                      'Severity Levels','Severity Level')
    }
    elsif match($typ,'transaction_monitor')
    {call get_unique_identifiers2(\@uid1,\@uid2,3,2,5)
     call analyze_log($pth,\@uid1,concat('l_',$log,'_threads'),\
                      'Threads','Thread')
     call analyze_log($pth,\@uid2,concat('l_',$log,'_severity'),\
                      'Severity Levels','Severity Level')
    }
    elsif match($typ,'upgradetool')
    {call get_unique_identifiers(\@uid1,2,4)
     call analyze_log($pth,\@uid1,concat('l_',$log,'_severity'),\
                      'Severity Levels','Severity Level')
    }

    # Switch to the next type
    break expr('>=',$max,0)
   }
  }
 }
}

=head1 SEE ALSO

L<RDA:library|collect::RDA:library>

=head1 COPYRIGHT NOTICE

Copyright (c) 2002, 2024, Oracle and/or its affiliates. All rights reserved.

=head1 TRADEMARK NOTICE

Oracle and Java are registered trademarks of Oracle and/or its
affiliates. Other names may be trademarks of their respective owners.

=cut
